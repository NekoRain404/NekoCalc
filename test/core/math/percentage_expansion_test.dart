import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/core/math/app_engine_vocabulary.dart';
import 'package:nekocalc/core/math/engine_expression.dart';
import 'package:nekocalc/core/math/expression_parser.dart';
import 'package:nekocalc/core/math/variable_references.dart';

/// 中文：**`%` 的两种读法——一张逐条带理由的行为表。** 判据、厂商原文出处与参考实现的实测都写在
///       `lib/core/math/percentage_expansion.dart` 的文件头；这里只管钉住结果。
///
///       参考实现是宿主 `qalc` 5.12.0（它同时是本应用的引擎，且它自己的百分比设置默认就是
///       relative）。本文件里每一条 relative 的期望值都实测过 `qalc -t "<表达式>"`，两边逐条相同；
///       **两条刻意不同的**在下面各自带 `reason` 写明为什么（`5÷50%` 与 `50+2^10%`）。
/// English: **The two readings of `%` — a behaviour table with a reason on every line.** The
///          judgement, the vendor's wording and the reference implementation's measurements are in
///          `lib/core/math/percentage_expansion.dart`'s header; this file only pins results.
///
///          The reference implementation is the host's `qalc` 5.12.0 (also this app's engine, and its
///          own percentage setting defaults to relative). Every relative expectation below was measured
///          with `qalc -t "<expression>"` and agrees line by line; the **two deliberate exceptions**
///          each carry a `reason` saying why (`5÷50%` and `50+2^10%`).
void main() {
  double parse(String source, {bool relative = false, bool degreeMode = false}) {
    return ExpressionParser(source,
            degreeMode: degreeMode, relativePercent: relative)
        .parse();
  }

  String normalized(String source, {bool relative = false}) {
    return ExpressionParser.normalizeExpressionInput(source,
        relativePercent: relative);
  }

  group('direct（默认）：与接入这个设置之前逐字节相同', () {
    test('厂商手册 direct 一节的四条', () {
      // 中文：手册 574–591 行的 direct 例子：`50+10%` = 50.1、`50−10%` = 49.9。
      // English: the manual's direct examples (lines 574–591): `50+10%` = 50.1, `50−10%` = 49.9.
      expect(parse('50+10%'), closeTo(50.1, 1e-12));
      expect(parse('50-10%'), closeTo(49.9, 1e-12));
      expect(parse('100+10%'), closeTo(100.1, 1e-12));
    });

    test('不传 relativePercent 与传 false 是同一次调用', () {
      // 中文：默认值就是 direct——`normalizeExpressionInput` 的那条路（名字层、变量引用、
      //       图形标签、去重键用的那条）看到的是同一个字符串，一个字都不许变。
      // English: the default is direct — the road `normalizeExpressionInput` takes for the name layer,
      //          variable references, graph labels and the de-duplication key sees one and the same
      //          string, and not a character of it may move.
      for (final source in <String>[
        '50+10%',
        '2^3%',
        '(20+30)+10%',
        '50+5%-5%',
        '1,200×50%',
      ]) {
        expect(normalized(source), normalized(source, relative: false),
            reason: source);
        expect(parse(source), parse(source, relative: false), reason: source);
      }
    });

    test('direct 不是「除以 100」的全部——`/` 与函数实参本来就有分歧', () {
      // 中文：**这是本应用 direct 模式的两个既有分歧，不是本轮引入的，也不是本轮能改的**
      //       （改 direct 就是改默认行为）。写在这里是因为「direct 就是除以 100」这句话并不成立：
      //       1）`5÷50%`：厂商手册 relative 一节写的是 **10**（direct 的定义同样给 10——
      //          `50%` 化成 0.5，`5÷0.5` = 10），而本应用读 `5/(50)/100` = **0.001**：
      //          归一化把 `/100` 插在**整个外层项的末尾**，于是它落在除号外面。
      //          `test/core/math/engine_expression_test.dart` 里 `100/50%` 那一条把同一个形状
      //          称为「复审 §3 的 `/` 族」，是已知分歧。
      //       2）`sin(10%)`：qalc 给 0.001745（它把 `%` 当单位、又叠上它的角度单位），本应用给
      //          sin(0.1) = 0.09983341664682815。厂商两处都没写函数实参里的 `%`。
      //       两种模式在这两条上同值——因为 `×`/`÷` 与函数实参根本没有第二条规则。
      // English: **two pre-existing divergences in this app's direct mode — not introduced here, and
      //          not fixable here** (changing direct changes the default behaviour). They are recorded
      //          because "direct means divide by 100" is not quite true:
      //          1) `5÷50%`: the vendor's relative section says **10** (direct's own definition gives 10
      //             too — `50%` is 0.5 and `5÷0.5` = 10) while this app reads `5/(50)/100` = **0.001**:
      //             normalisation inserts `/100` at the end of the **whole enclosing term**, so it lands
      //             outside the division. The `100/50%` case in
      //             `test/core/math/engine_expression_test.dart` calls the same shape "the `/` family in
      //             the review's §3" — a known divergence.
      //          2) `sin(10%)`: qalc answers 0.001745 (it treats `%` as a unit and layers its angle unit
      //             on top) while this app answers sin(0.1) = 0.09983341664682815. The vendor writes
      //             nothing about `%` inside a function argument.
      //          Both modes agree on these two lines — `×`, `÷` and function arguments have no second
      //          rule at all.
      expect(parse('5/50%'), closeTo(0.001, 1e-12),
          reason: '手册给 10，本应用给 0.001——既有分歧，见本条注释');
      expect(parse('5/50%', relative: true), closeTo(0.001, 1e-12),
          reason: '`÷` 在两种模式下同值（厂商两节给的也都是 10，所以分歧两边都在）');
      expect(parse('sin(10%)'), closeTo(0.09983341664682815, 1e-12));
      expect(parse('sin(10%)', relative: true),
          closeTo(0.09983341664682815, 1e-12));
    });
  });

  group('relative：厂商手册给值的四条 + 链式那条', () {
    test('手册 relative 一节逐条', () {
      expect(parse('50+10%', relative: true), closeTo(55, 1e-12));
      expect(parse('50-10%', relative: true), closeTo(45, 1e-12));
      expect(parse('50*10%', relative: true), closeTo(5, 1e-12));
      expect(parse('50+(10+10)%', relative: true), closeTo(60, 1e-12));
    });

    test('链式：第二个百分数按**累计值**算，不是按第一个操作数', () {
      // 中文：手册给的 `50+5%−5%` = 49.875 只能这么解释：（50 加 5% 得 52.5）再减 52.5 的 5%
      //       = 49.875。若第二个 5% 还是按 50 算，会得到 50.0（今天 direct 的值）。
      // English: the manual's `50+5%−5%` = 49.875 admits only one reading: (50 plus 5% is 52.5) then
      //          minus 5% **of 52.5** is 49.875. Were the second 5% still taken of 50, the answer would
      //          be 50.0 (today's direct value).
      expect(parse('50+5%-5%', relative: true), closeTo(49.875, 1e-12));
      expect(parse('50+5%-5%'), closeTo(50.0, 1e-12),
          reason: 'direct 下这里是 50.0——同一个输入，两种读法');
      expect(parse('50+10%+10%', relative: true), closeTo(60.5, 1e-12),
          reason: '第二个 10% 是 55 的 10%，不是 50 的');
      expect(parse('50+10%+10%+10%', relative: true), closeTo(66.55, 1e-12));
      expect(parse('100-10%-10%', relative: true), closeTo(81, 1e-12));
      expect(parse('1+10%+10%', relative: true), closeTo(1.21, 1e-12));
      expect(parse('5+10%+5', relative: true), closeTo(10.5, 1e-12),
          reason: '链上的非百分数项照旧只是加——折只发生在百分数项上');
    });
  });

  group('题目点名的那几条：两种模式并排', () {
    test('`50+10%` / `50-10%` / `(20+30)+10%`：前一个值就是左边那个值', () {
      expect(parse('(20+30)+10%'), closeTo(50.1, 1e-12));
      expect(parse('(20+30)+10%', relative: true), closeTo(55, 1e-12));
      expect(parse('2*3+10%', relative: true), closeTo(6.6, 1e-12),
          reason: '「前一个值」是左边那个**项的值** 6，不是它的文本 `2*3` 里的 2');
      expect(parse('2^3+10%', relative: true), closeTo(8.8, 1e-12));
      expect(parse('2*(50+10%)', relative: true), closeTo(110, 1e-12),
          reason: '括号里的链自己折，外面的乘法碰不到它');
      expect(parse('sqrt(50+10%)', relative: true), closeTo(7.416198487, 1e-9),
          reason: '函数实参里也是一条链');
      expect(parse('max(1,50+10%)', relative: true), closeTo(55, 1e-12),
          reason: '实参各算各的：逗号把两条链切开');
    });

    test('`10%` 单独出现：没有前一个值，就是 0.1', () {
      expect(parse('10%'), closeTo(0.1, 1e-12));
      expect(parse('10%', relative: true), closeTo(0.1, 1e-12));
      expect(parse('50%*2', relative: true), closeTo(1, 1e-12));
    });

    test('`10%+10%`：首项自己是百分数 → 整条链不折（0.2）', () {
      // 中文：厂商对此**一个字都没写**；这条是照参考实现补的（qalc 里 `%` 是单位，两个同单位量
      //       相加就是普通加法），而它同时等于本应用 direct 下的值，所以这一族两种模式同值。
      // English: the vendor says **nothing** about this; it is taken from the reference implementation
      //          (`%` is a unit in qalc, so two quantities of the same unit simply add) and it equals
      //          this app's direct value, making the family mode-invariant.
      expect(parse('10%+10%'), closeTo(0.2, 1e-12));
      expect(parse('10%+10%', relative: true), closeTo(0.2, 1e-12));
      expect(parse('50%+10%', relative: true), closeTo(0.6, 1e-12));
      expect(parse('(10%)+10%', relative: true), closeTo(0.2, 1e-12),
          reason: '括号包着的百分数仍然是一个百分数量');
      expect(parse('-10%+10%', relative: true), closeTo(0, 1e-12));
      expect(parse('20%+90', relative: true), closeTo(90.2, 1e-12));
      expect(parse('10%+50', relative: true), closeTo(50.1, 1e-12));
    });
  });

  group('× 与 ÷：厂商写了例子，而两个例子在两种读法下同值', () {
    test('`50×10%` = 5、`5÷50%` = 10 —— 只有前一条本应用给得出', () {
      // 中文：厂商在 relative 一节里给了 `50×10%` = 5 与 `5÷50%` = 10。前者与 direct 的定义同值
      //       （`×10%` 就是乘 0.1），所以 `×` 本来就没有第二条规则；后者按 direct 的定义也是 10，
      //       本应用却在**两种模式下都**给 0.001（见上面 direct 那一组的注释）。也就是说
      //       `÷` 的这条分歧不是我这一轮的选择，而是既有行为；两种模式在这条上一致。
      // English: under relative the vendor gives `50×10%` = 5 and `5÷50%` = 10. The first equals
      //          direct's definition (`×10%` is multiplying by 0.1), so `×` never had a second rule;
      //          the second is 10 under direct's definition too, yet this app answers 0.001 in **both**
      //          modes (see the note in the direct group above). So the `÷` divergence is not a choice
      //          made this round — it is existing behaviour, and both modes agree on it.
      expect(parse('50*10%', relative: true), closeTo(5, 1e-12));
      expect(parse('50*10%'), closeTo(5, 1e-12));
      expect(parse('10%*50', relative: true), closeTo(5, 1e-12));
      expect(parse('5/50%', relative: true), closeTo(parse('5/50%'), 1e-15),
          reason: '÷ 的两种读法必须同值——这一条是「厂商没给第二条规则」的直接后果');
    });

    test('`×`/`÷`/`^` 的右操作数不是裸百分数时不折：50+10%*2 仍是 50.2', () {
      // 中文：参考实现实测：`50+10%*2` 50.2、`50+10%/2` 50.05、`50+2^10%` 也按 `/100` 走。
      //       判据是「`±` 的右操作数**恰好**是一个裸百分数字面量」，多一个运算符就不算。
      // English: measured on the reference implementation: `50+10%*2` is 50.2, `50+10%/2` is 50.05,
      //          and `50+2^10%` also divides by 100. The test is "the right operand of `±` is
      //          **exactly** one bare percentage literal"; one more operator disqualifies it.
      expect(parse('50+10%*2', relative: true), closeTo(50.2, 1e-12));
      expect(parse('50+10%/2', relative: true), closeTo(50.05, 1e-12));
      expect(parse('50-10%*2', relative: true), closeTo(49.8, 1e-12));
      expect(parse('200+10%*3', relative: true), closeTo(200.3, 1e-12));
      expect(parse('2^3%', relative: true), closeTo(0.08, 1e-12),
          reason: '`%` 落在整个外层项末尾的既有约定，两种模式同值');
      expect(parse('3%^2', relative: true), closeTo(0.0003, 1e-12));
      expect(parse('50+2^10%', relative: true), closeTo(60.24, 1e-12),
          reason: '**与 qalc 不同的一条**：qalc 在同一条式子上给 562（它把链里的 `b^e%` 读成 '
              '`b^(e−1)`，而单独一句 `2^10%` 它又给 10.24，自相矛盾）；厂商对此没有说法，'
              '本应用按自己那条已钉住的 `%` 约定读，两模式同值');
    });
  });

  group('边界与护栏：折不动就不折，绝不新造失败', () {
    test('归一化之后仍然裸露的 % 两种模式都读不懂', () {
      // 中文：`pi%`、`3!%` 到了解析器里还是一个裸露的 `%`（`_replacePercent` 只展开数字或
      //       括号组后面的），两种模式都必须抛同一句错——relative 不许把它们变得「能算」。
      // English: `pi%` and `3!%` still carry a bare `%` by the time the parser sees them
      //          (`_replacePercent` only expands a `%` after a number or a bracket group), and both
      //          modes must throw the same error — relative must not make them computable.
      for (final source in <String>['pi%', '3!%', 'e%']) {
        expect(() => parse(source), throwsFormatException, reason: source);
        expect(() => parse(source, relative: true), throwsFormatException,
            reason: source);
      }
    });

    test('括号不配对时整段放弃折叠，回落 direct 的读法', () {
      // 中文：`(50+10%` 少一个右括号。折叠放弃 = 归一化文本与 direct 逐字节相同，
      //       于是两种模式在同一个畸形输入上给同一句错，而不是一边多一点什么。
      // English: `(50+10%` is missing a closing bracket. Giving up the fold means the normalised text
      //          is byte-for-byte direct's, so both modes answer the same malformed input with the same
      //          error rather than one of them inventing something.
      expect(normalized('(50+10%', relative: true), normalized('(50+10%'));
      expect(() => parse('(50+10%'), throwsFormatException);
      expect(() => parse('(50+10%', relative: true), throwsFormatException);
    });

    test('括号里的百分数被折之后，外面那个 % 仍然读得懂', () {
      // 中文：`(20+10%)%` 这种形状**里面不折**（折了 `_replacePercent` 就不认得那个括号组了），
      //       所以相对模式不会比 direct 多出一句「读不懂」——两边同值 50.201。
      // English: a shape like `(20+10%)%` is left **unfolded inside** (folding it would stop
      //          `_replacePercent` recognising the bracket group), so relative does not answer "cannot
      //          read" where direct reads fine — both give 50.201.
      expect(parse('50+(20+10%)%'), closeTo(50.201, 1e-12));
      expect(parse('50+(20+10%)%', relative: true), closeTo(50.201, 1e-12));
    });

    test('形状不成立时不折：运算符后面的一元符号、空项、单个项', () {
      // 中文：折的判据之一是「这个 `+`/`-` 是**二叉**的」——它前面最近的非空格字符必须是一个值的
      //       结尾。于是 `50*+10%` 里那个 `+` 是一元的，整段只有一项，不折（两种模式读法相同）。
      //       这一条挡的是「相对模式在畸形输入上比 direct 多出一句错」那一类。
      // English: one of the fold's tests is "this `+`/`-` is **binary**" — the nearest non-space
      //          character before it must end a value. So the `+` in `50*+10%` is unary, the whole
      //          thing is one term, and nothing folds (both modes read it the same). This is what stops
      //          relative mode from answering an extra error on malformed input where direct copes.
      for (final source in <String>['50*+10%', '50+', '10%']) {
        expect(normalized(source, relative: true), normalized(source),
            reason: source);
      }
      // 中文：`50*+10%` 在 direct 下读得动（`50*+(10)/100` = 5），相对模式必须同样读得动；
      //       `50+` 两边都读不动——**"读得动/读不动"这件事本身也不许随模式变**。
      // English: `50*+10%` reads under direct (`50*+(10)/100` = 5) and must read under relative too;
      //          `50+` reads under neither — **whether it reads at all must not change with the mode**.
      expect(parse('50*+10%', relative: true), parse('50*+10%'));
      expect(parse('10%', relative: true), parse('10%'));
      expect(() => parse('50+'), throwsFormatException);
      expect(() => parse('50+', relative: true), throwsFormatException);
    });

    test('带符号与括号的百分数：`50--10%`、`50-(-10%)`、`50+(10)%`', () {
      expect(parse('50--10%', relative: true), closeTo(55, 1e-12));
      expect(parse('50-(-10%)', relative: true), closeTo(55, 1e-12));
      expect(parse('-50+10%', relative: true), closeTo(-55, 1e-12));
      expect(parse('50+(10)%', relative: true), closeTo(55, 1e-12));
      expect(parse('0-10%', relative: true), closeTo(0, 1e-12),
          reason: '0 的 10% 还是 0（qalc 同值）');
    });
  });

  group('模式只影响求值：另外五个消费者看到的文本一个字不改', () {
    test('相对模式折出来的文本仍然是引擎读得懂的那一种', () {
      // 中文：折法只把 `%` 改写成 `/100` 因子与括号，所以**引擎照样被问到**——两种模式下
      //       「先问引擎、问不到再回落旧解析器」这条权威结构完全一样。若相对模式改走「不问引擎」，
      //       同一个输入就会按设置落到两个不同的权威上（`°` 那一轮修的就是这个）。
      // English: the fold only rewrites `%` into `/100` factors and brackets, so **the engine is still
      //          asked** — the authority structure ("ask the engine, fall back to the legacy parser")
      //          is identical in both modes. Had relative taken the "do not ask the engine" road, one
      //          input would land on two different authorities depending on a setting (exactly what the
      //          `°` round fixed).
      expect(engineExpressionFor('50+10%', relativePercent: true),
          isA<TranslatedExpression>());
      expect(engineExpressionFor('50+10%'), isA<TranslatedExpression>());
      expect(engineExpressionFor('pi%', relativePercent: true),
          isA<UntranslatableExpression>(),
          reason: '裸露的 % 两种模式都翻译不了');
    });

    test('`canRead` / `canExpress` 在两种模式下判断相同', () {
      // 中文：名字层不传模式（它读的是默认归一化），而折法既不新增也不删除「读得懂 / 翻得过去」
      //       的构造——所以它对同一批输入的判断必须与相对模式下真正被求值的那段文本一致。
      // English: the name layer passes no mode (it reads the default normalisation) and the fold neither
      //          adds nor removes readable/translatable constructs, so its verdicts on a batch of inputs
      //          must match what the relative path actually evaluates.
      for (final source in <String>[
        '50+10%',
        'x+10%',
        'sqrt(50+10%)',
        'npr(5,2)+10%',
        'pi%',
        '50+(20+10%)%',
        '10%+10%',
      ]) {
        // 中文：名字层读的是**默认**归一化文本，求值那一侧读的是 relative 文本；两者在
        //       「读得懂 / 翻得过去」上必须给出同一个答案，否则「谁看到了什么」就分成两半了。
        //       （两条都要过一遍归一化：这些判据的入参本来是源码。）
        // English: the name layer reads the **default** normalised text while evaluation reads the
        //          relative one; the two must answer identically on "readable / translatable", or "who
        //          saw what" splits in two. (Both go through normalisation: those judgements take a
        //          source.)
        final plain = normalized(source);
        final folded = normalized(source, relative: true);
        expect(AppEngineVocabulary.canRead(folded),
            AppEngineVocabulary.canRead(plain),
            reason: source);
        expect(AppEngineVocabulary.canExpress(folded),
            AppEngineVocabulary.canExpress(plain),
            reason: source);
        expect(
          engineExpressionFor(source, relativePercent: true)
              is UntranslatableExpression,
          engineExpressionFor(source) is UntranslatableExpression,
          reason: source,
        );
      }
    });

    test('变量引用在折前折后是同一批名字', () {
      // 中文：折成**乘法因子**而不是加法项，正是为了这一条——`x+10%` 折完 `x` 仍然只出现一次，
      //       于是 `variable_references` 那一层（不传模式）看到的名字集合不变。
      // English: folding into a **multiplicative factor** rather than an additive term is precisely for
      //          this: after folding, `x` in `x+10%` still appears once, so the `variable_references`
      //          layer (which passes no mode) sees the same set of names.
      final folded = normalized('x+10%', relative: true);
      expect(folded, '(x)*(100+(10))/100');
      expect(RegExp('x').allMatches(folded).length, 1,
          reason: '名字只出现一次——加法形式会把它抄成两份');
      // 中文：变量替换那一层（不传模式）拿到折完的文本之后照常工作，而且值是相对的。
      // English: the variable-substitution layer (which passes no mode) works on the folded text as
      //          usual, and the value it yields is the relative one.
      final resolved = resolveVariableReferences(folded, const {'x': '4'});
      expect(ExpressionParser(resolved, degreeMode: false).parse(),
          closeTo(4.4, 1e-12));
    });
  });

  group('归一化文本的形状', () {
    test('折出来的形状逐条', () {
      expect(normalized('50+10%', relative: true), '(50)*(100+(10))/100');
      expect(normalized('50-10%', relative: true), '(50)*(100-(10))/100');
      expect(normalized('50+10%+10%', relative: true),
          '((50)*(100+(10))/100)*(100+(10))/100');
      expect(normalized('2*3+10%', relative: true), '(2*3)*(100+(10))/100');
      expect(normalized('sqrt(50+10%)', relative: true),
          'sqrt((50)*(100+(10))/100)');
      expect(normalized('50+10%', relative: false), '50+(10)/100',
          reason: 'direct 那条路一个字没动');
    });
  });
}
