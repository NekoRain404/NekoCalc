import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/core/math/ast/expression_ast_parser.dart';
import 'package:nekocalc/core/math/engine_expression.dart';
import 'package:nekocalc/core/math/expression_parser.dart';

/// 中文：**翻译器的输入。** 修复轮 7 的复审在这里找到了两个 medium：翻译器吃的是**页面上的原文**，
///       而 `ExpressionParser` 会在求值之前对那份原文做两处**它看不见**的改写——
///
///       - `_replacePercent`：`X%` 写成 `(X)/100`，那个 `/100` 落在**整个外层项**的末尾
///         （`2^3%` = `2^(3)/100`）；语法树的 `PostfixNode('%')` 却绑在**原子**上，
///         于是翻译写出 `((2)^(((3)/100)))`——引擎读**原文**本来是对的（实测 0.08），
///         **误读是翻译自己引进的**（1.021012125707193）。
///       - `_normalizeGroupedNumberSeparators`：逗号是不是千分位由应用自己的实参个数表回答；
///         语法树没有这条规则，每一个逗号都是实参分隔符，于是 `round(1,024)` 被译成两个实参，
///         引擎答 `1`（应用给 1024）。
///
///       本文件钉住修复轮 8 的输入改动：**翻译器与 `ExpressionParser` 看到的是同一个字符串**。
///       这里钉的是**形态**（问了引擎哪一个字符串）；引擎答出来的**值**上屏那一条在
///       `test/domain/calculator_engine_translation_test.dart`（那里有实测的引擎原文）。
///
///       末尾两组钉住另外两件同属「这一层的边界」的事：**标识符**（表外的一律拒绝，别名折到表里的
///       键上）与**运算符**（白名单，且它必须能被测试到——`engineExpressionForNode` 就是为此存在）。
/// English: **the translator's input.** Fix round 7's review found two mediums here: the translator was
///          fed the **page's raw text**, while `ExpressionParser` makes two rewrites of that text before
///          evaluating, and the translator could not see either —
///
///          - `_replacePercent`: `X%` is written `(X)/100` with the `/100` at the end of the **whole
///            enclosing term** (`2^3%` = `2^(3)/100`), while the syntax tree's `PostfixNode('%')` binds to
///            the **atom**; the translation therefore wrote `((2)^(((3)/100)))` — the engine's own
///            reading of the **raw** text was right (measured 0.08) and **the misreading was the
///            translation's own** (1.021012125707193).
///          - `_normalizeGroupedNumberSeparators`: whether a comma is a thousands separator is answered
///            by this app's own arity table; the syntax tree has no such rule and every comma is an
///            argument separator, so `round(1,024)` was translated as two arguments and the engine
///            answered `1` where this app answers 1024.
///
///          This file pins fix round 8's input change: **the translator and `ExpressionParser` see one
///          string**. What is pinned here is the **shape** (which string the engine is asked); the value
///          that reaches the screen is pinned in
///          `test/domain/calculator_engine_translation_test.dart` (with measured engine text).
///
///          The last two groups pin two more things from the same layer: **identifiers** (anything
///          outside the table is refused; alias spellings fold onto the table's canonical keys) and
///          **operators** (a whitelist, and it has to be testable — which is what
///          `engineExpressionForNode` exists for).
void main() {
  String translated(String source) {
    final result = engineExpressionFor(source);
    expect(result, isA<TranslatedExpression>(),
        reason: '`$source` 本该翻译得了：$result');
    return (result as TranslatedExpression).text;
  }

  String refusal(String source) {
    final result = engineExpressionFor(source);
    expect(result, isA<UntranslatableExpression>(),
        reason: '`$source` 本该翻译不了');
    return (result as UntranslatableExpression).reason;
  }

  group('翻译器与 ExpressionParser 看的是同一个字符串', () {
    test('翻译器的输入就是解析器构造函数里那一份 text', () {
      // 中文：**这是「同一份输入」可以直接测的那一面。** `ExpressionParser(source).text` 是求值器
      //       真正会看到的那份文本；把**它**再喂给翻译器，得到的结果必须与直接喂原文相同——
      //       等价于说翻译器内部做的就是 `normalizeExpressionInput`。若有人把它改回原文
      //       （修复轮 7 的写法），下面这些式子里凡是归一化会改写文本的都会红。
      // English: **the directly testable face of "one input".** `ExpressionParser(source).text` is the
      //          text the evaluator really sees; feeding **that** to the translator has to give the same
      //          result as feeding the raw source — which is the same as saying the translator runs
      //          `normalizeExpressionInput` internally. Reverting it to the raw source (fix round 7's
      //          form) turns every row below whose text normalisation rewrites red.
      for (final source in <String>[
        '2^3%',
        '3%^2',
        'round(1,024)',
        'sqrt(1,024)',
        'lg(1024)',
        '√4',
        '1/3000000000pi',
        '2 pi',
        '45°',
      ]) {
        final parserText = ExpressionParser(source, degreeMode: false).text;
        expect(
          engineExpressionFor(source).toString(),
          engineExpressionFor(parserText).toString(),
          reason: '$source：翻译器与解析器看到的不是同一份（解析器那份是 `$parserText`）',
        );
      }
    });
  });

  group('%：/100 落在整个外层项的末尾——三种形状', () {
    // 中文：三条都来自修复轮 7 复审的表（`2^3%` / `3%^2` / `9^50%`），值是应用自己的解析器给的：
    //       0.08 / 0.0003 / 5.153775207320113E45。翻译后的字符串把括号写足，引擎只能按这个结构读。
    // English: all three come from fix round 7's review table (`2^3%` / `3%^2` / `9^50%`), and the
    //          values are this app's own: 0.08 / 0.0003 / 5.153775207320113E45. The translated string
    //          spells the brackets out so the engine can only read that structure.
    test('2^3%：`/100` 在幂之外', () {
      expect(translated('2^3%'), '((((2)^((3))))/(100))');
    });

    test('3%^2：底数先除以 100，再取平方', () {
      expect(translated('3%^2'), '(((3))/(((100)^(2))))');
    });

    test('9^50%：指数是 50/100，不是 50% 这个后缀', () {
      expect(translated('9^50%'), '((((9)^((50))))/(100))');
    });

    test('2^50% 与 100/50%：另外两种形状', () {
      // 中文：`2^50%` 与 1a 同族；`100/50%` 是**另一位**的分歧（复审 §3 的 `/` 族）——
      //       应用读 `100/(50)/100` = 0.02，翻译后引擎读同一个结构。
      // English: `2^50%` is the same family as 1a; `100/50%` is the **other** direction (the `/` family
      //          in the review's §3) — this app reads `100/(50)/100` = 0.02, and after the translation
      //          the engine reads the same structure.
      expect(translated('2^50%'), '((((2)^((50))))/(100))');
      expect(translated('100/50%'), '((((100)/((50))))/(100))');
    });

    test('归一化之后仍然裸露的 % 一律拒绝，不替应用发明含义', () {
      // 中文：`_replacePercent` 只展开「数字或括号组」后面的 `%`，所以 `pi%`/`3!%` 这类到了语法树里
      //       还是后缀——而**应用自己的解析器读不懂它们**（`_parsePostfix` 只吃 `!`，`parse()` 会抛
      //       「存在无法识别的内容」）。修复轮 7 在这里写 `((text)/100)`，那是替应用发明一个它没有的
      //       含义；现在与其它翻译不了的构造同一条路：回落旧解析器，它给出的正是同一句错误。
      // English: `_replacePercent` only expands a `%` after a number or a bracketed group, so `pi%` /
      //          `3!%` reach the tree as a postfix — and **this app's own parser cannot read them**
      //          (`_parsePostfix` consumes only `!`, and `parse()` throws "unexpected content"). Fix
      //          round 7 wrote `((text)/100)` there, inventing a meaning this app does not have; it now
      //          takes the same route as every other untranslatable construct — the legacy parser
      //          answers, with exactly that error.
      for (final source in <String>['pi%', '3!%', 'e%']) {
        expect(refusal(source), contains('裸露的 `%`'), reason: source);
      }
    });
  });

  group('分组逗号：单参调用不再变成两个实参', () {
    // 中文：修复轮 7 复审的表里，这一族在屏幕上是 `1`（`round`）与二元素向量（其余）。
    //       逗号由应用自己的实参个数表决定，归一化之后才进语法树，所以翻译器现在看得见那个决定。
    // English: in fix round 7's review table this family showed `1` (`round`) and a two-element vector
    //          (the rest). The comma is decided by this app's own arity table and normalisation runs
    //          before the tree is built, so the translator now sees that decision.
    test('单参调用：逗号是千分位', () {
      expect(translated('round(1,024)'), 'round(1024)');
      expect(translated('log2(1,024)'), 'log2(1024)');
      expect(translated('sqrt(1,024)'), 'sqrt(1024)');
      expect(translated('abs(1,024)'), 'abs(1024)');
      expect(translated('ln(1,024)'), 'ln(1024)');
      expect(translated('ceil(1,024)'), 'ceil(1024)');
      expect(translated('floor(1,024)'), 'floor(1024)');
      expect(translated('cbrt(1,024)'), 'cbrt(1024)');
    });

    test('多实参调用：同一个形状，逗号是分隔符', () {
      // 中文：**同一个形状，正确的读法相反**（`expression_parser.dart` 的 `_multiArgumentFunctions`
      //       就是为这一条存在的）：`atan2` 接两个实参，所以 `atan2(7,100)` 的逗号是分隔符。
      // English: **the same shape with the opposite correct reading** (which is what
      //          `_multiArgumentFunctions` in `expression_parser.dart` exists for): `atan2` takes two,
      //          so the comma in `atan2(7,100)` separates.
      expect(translated('atan2(7,100)'), 'atan2(7,100)');
      expect(translated('atan2(1,1)'), 'atan2(1,1)');
      // 中文：可变形参的名字同理——`min` 收一个以上，所以 `min(1,024,3)` 的逗号是**分隔符**，
      //       剥离它反而会改变这个式子的意思（应用读三个实参、引擎也读三个：两边都是 `1`）。
      //       这条同时是否命题的例子：**不是「有逗号就剥」**，剥不剥由名字决定。
      // English: variadic names are the same — `min` takes one or more, so the commas in
      //          `min(1,024,3)` are **separators** and stripping them would change what the expression
      //          means (the app reads three arguments and so does the engine: `1` on both sides). This
      //          is also the counterexample: it is **not** "strip every comma" — the name decides.
      expect(translated('min(1,024,3)'), 'min(1,024,3)');
    });
  });

  group('标识符层：表外的一律拒绝，别名折到表里的键上', () {
    test('未知标识符不送去让引擎猜', () {
      // 中文：引擎不认识一个拼法时**不报错**——它把那个词拆成符号（`npr` → `n·p·r`），于是答案描述
      //       的是另一件事。所以表外的拼法在这里就停下，回落旧解析器（硬性边界 1）。
      // English: when the engine does not know a spelling it **does not error** — it takes the word apart
      //          into symbols (`npr` → `n·p·r`), so its answer is about something else. A spelling
      //          outside the table therefore stops here and the legacy parser answers (hard boundary 1).
      for (final source in <String>['f(2)', 'nosuch(2)', 'foo(1,2)']) {
        expect(refusal(source), contains('不在应用词汇表里'), reason: source);
      }
    });

    test('别名拼法折到表里的规范名（同一张表）', () {
      // 中文：`ExpressionParser` 接受 `lg`/`log10`/`c`/`p`/`arcsin`/`arccos`/`arctan`，它们都不在
      //       词表的键里（键是规范名）。折叠用的就是解析器自己那张别名表，所以「`lg` 是什么」
      //       在整个应用里只有一处答案。
      // English: `ExpressionParser` accepts `lg`/`log10`/`c`/`p`/`arcsin`/`arccos`/`arctan`, none of
      //          which are keys in the table (the keys are canonical names). The fold is the parser's own
      //          alias table, so "what `lg` is" has exactly one answer in this app.
      expect(translated('arcsin(0.5)'), 'asin(0.5)');
      expect(translated('arccos(0.5)'), 'acos(0.5)');
      expect(translated('arctan(1)'), 'atan(1)');
      expect(translated('log(100)'), 'log10(100)');
      // 中文：`lg`/`log10` 的别名是 `log`，而 `log` 接两个实参（`logₓy` 那颗键），所以
      //       `lg(1,024)` 与 `log(1,024)` 是**同一个式子**、同一个答案。
      // English: `lg`/`log10` alias `log`, and `log` takes two arguments (the `logₓy` key), so
      //          `lg(1,024)` and `log(1,024)` are **one and the same expression** with one answer.
      expect(translated('lg(1,024)'), 'log10(1,024)');
      expect(translated('lg(1,024)'), translated('log(1,024)'));
      expect(translated('c(5,2)'), 'binomial(5,2)');
    });

    test('没有引擎写法、引擎答案也不可用的名字仍然拒绝', () {
      // 中文：`npr`/`mod`/`deg`/`rad`/`phi`/`inf`——两列都是「不可用」，所以翻译这一步就停下。
      // English: `npr`/`mod`/`deg`/`rad`/`phi`/`inf` — unusable in both columns, so the translation
      //          stops here.
      for (final source in <String>['npr(2,1)', 'mod(7,-3)', 'deg(pi)', 'rad(30)']) {
        expect(refusal(source), contains('没有引擎写法'), reason: source);
      }
    });
  });

  group('运算符白名单（只能从节点构造测到，所以 engineExpressionForNode 存在）', () {
    // 中文：`ExpressionAstParser` 今天只会产出 `+`/`-` 一元与 `+ - *` 独立运算符，所以从源码出发
    //       走不到白名单的拒绝分支——**测不到的守卫等于没有守卫**。这一组直接构造节点。
    // English: `ExpressionAstParser` produces only `+`/`-` unary and `+ - *` standalone operators today,
    //          so nothing reaches the refusal branch from source — and **a guard nothing tests is not a
    //          guard**. This group builds the nodes directly.
    const number = NumberNode('1', start: 1, end: 2);

    test('已知的一元运算符照译，未知的拒绝', () {
      for (final op in <String>['+', '-']) {
        final node = UnaryNode(op, number, start: 0, end: 2);
        expect((engineExpressionForNode(node) as TranslatedExpression).text,
            '$op(1)');
      }
      const unknown = UnaryNode('~', number, start: 0, end: 2);
      expect(engineExpressionForNode(unknown), isA<UntranslatableExpression>());
      expect((engineExpressionForNode(unknown) as UntranslatableExpression).reason,
          contains('未知一元运算符'));
    });

    test('已知的独立运算符照译，未知的拒绝', () {
      for (final op in <String>['+', '-', '*']) {
        final node = OperatorNode(op, start: 0, end: 1);
        expect((engineExpressionForNode(node) as TranslatedExpression).text, op);
      }
      const unknown = OperatorNode('~', start: 0, end: 1);
      expect(engineExpressionForNode(unknown), isA<UntranslatableExpression>());
      expect((engineExpressionForNode(unknown) as UntranslatableExpression).reason,
          contains('未知运算符'));
    });

    test('未知后缀运算符同样拒绝', () {
      const unknown = PostfixNode('?', number, start: 0, end: 2);
      expect(engineExpressionForNode(unknown), isA<UntranslatableExpression>());
      expect((engineExpressionForNode(unknown) as UntranslatableExpression).reason,
          contains('未知后缀运算符'));
      expect(
          (engineExpressionForNode(
                  const PostfixNode('!', number, start: 0, end: 2))
              as TranslatedExpression)
              .text,
          'factorial(1)');
    });
  });

  group('这条输入改动没有动别的构造', () {
    test('三个活错值的翻译形态没有变', () {
      // 中文：修复轮 7 修掉的三个活错值问引擎的字符串，必须逐字节不变（本轮的改动在它们之前）。
      // English: the strings the three live wrong values fix round 7 repaired ask the engine have to
      //          stay byte-for-byte identical (this round's change is upstream of them).
      expect(translated('123456789012345678-123456789012345677'),
          '((123456789012345678)-(123456789012345677))');
      expect(translated('2^53+1-2^53'), '((((((2)^(53)))+(1)))-(((2)^(53))))');
      expect(translated('(10^16+1)-10^16'),
          '(((((((10)^(16)))+(1))))-(((10)^(16))))');
      expect(translated('1/3000000000pi'), '((((1)/(3000000000)))*(pi))');
      expect(translated('tan(1e12)'), 'tan(1e12)');
      expect(translated('2^2000'), '((2)^(2000))');
      expect(translated('sqrt(8)'), 'sqrt(8)');
    });
  });
}
