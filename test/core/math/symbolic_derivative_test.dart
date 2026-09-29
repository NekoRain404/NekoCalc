import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/core/math/symbolic_derivative.dart';

/// 中文：**符号求导的测试。**
///
///       **这一组就是全部证据，不必等真机。** 它整条不碰引擎（引擎不给推导过程），
///       与 `convertToBase` / `toRoman` 同一条判据：能绕开引擎时，单测的证明力比真机强。
///
///       ⚠️ **期望值里有很大一部分是"法则本身的样子"，而不是化简后的答案。**
///       `2x·1 + x²·0` 那种输出**不是错**——它就是乘法法则写出来之后的样子。
///       这一版**不做化简**（见 `symbolic_derivative.dart` 文件头：该化到什么程度没有唯一答案）。
///       所以断言写的是**法则的形状**，不是"最简形式"。
/// English: **the symbolic-derivative tests.**
///
///          **This group is the whole proof; no device is needed.** It does not touch the engine at all
///          (the engine does not give its working) — the same judgement as `convertToBase` / `toRoman`:
///          when the engine can be bypassed, unit tests prove more than a device.
///
///          ⚠️ **Much of the expected output is "what the rule looks like", not a simplified answer.**
///          Output such as `2x·1 + x²·0` **is not wrong** — it is what the product rule reads like once
///          written out. This version **does no simplification** (see `symbolic_derivative.dart`'s head:
///          there is no single answer to "how far to simplify"). So the assertions describe the **shape
///          of the rule**, not a "simplest form".
void main() {
  group('基本法则', () {
    test('常数与变量', () {
      final constant = differentiate('7', 'x');
      expect(constant.derivative, '0');
      expect(constant.refusal, isNull);

      final self = differentiate('x', 'x');
      expect(self.derivative, '1');

      // 中文：**对别的字母求导是 0**，而它记的法则与"常数"不是同一条——
      //       屏幕上那句话不一样（"这是常量" vs "它不含 x"）。
      // English: **differentiating with respect to a different letter gives 0**, and it records a
      //          different rule from "constant" — the sentence on screen differs.
      final other = differentiate('y', 'x');
      expect(other.derivative, '0');
      expect(other.steps.single.rule, DerivativeRules.other);
    });

    test('常量名（`pi`）对谁求导都是 0', () {
      expect(differentiate('pi', 'x').derivative, '0');
      expect(differentiate('pi', 'x').steps.single.rule, DerivativeRules.constant);
    });

    test('和与差：各项分别求导，法则记一次', () {
      final result = differentiate('x + 3', 'x');
      // `x` → 1，`3` → 0，和本身 → `1 + 0`。
      expect(result.steps.map((s) => s.expression).toList(),
          ['1', '0', '1 + 0']);
      expect(result.derivative, '1 + 0');
      expect(result.steps.last.rule, DerivativeRules.sum);
    });

    test('幂法则：指数是常数', () {
      final result = differentiate('x^2', 'x');
      // 中文：写成 `2·x^1·(1)` 是**故意的**——`n·u^(n-1)·u'` 是幂法则的完整样子，
      //       把 `·1` 省掉、把 `x^1` 写成 `x` 都属于化简，那不在这一版里。
      // English: writing `2·x^1·(1)` is **deliberate** — `n·u^(n-1)·u'` is the power rule in full, and
      //          dropping `·1` or unwriting `x^1` is simplification, which this version does not do.
      expect(result.steps.last.rule, DerivativeRules.power);
      expect(result.derivative, '2·x^1·(1)');
    });

    test('指数是 1 时幂法则退化成直接求导（不印 `1·x^0·(1)`）', () {
      // 中文：**这是一处刻意的例外。** `x^1` 的导数是 `1`，硬套幂法则会印出
      //       `1·x^0·(1)`——那不是"法则的样子"，那是一条没有任何信息量的式子。
      // English: **a deliberate exception.** The derivative of `x^1` is `1`, and forcing the power rule
      //          through would print `1·x^0·(1)` — which is not "what the rule looks like" but a line
      //          carrying no information at all.
      final result = differentiate('x^1', 'x');
      expect(result.derivative, '1');
    });

    test("乘法法则：两半都在", () {
      final result = differentiate('x * x', 'x');
      expect(result.steps.last.rule, DerivativeRules.product);
      // 左边 `x` 的导数 1、右边 `x` 的导数 1，两半各是 `u·v'` 与 `u'·v` 的位置。
      expect(result.derivative, contains('·1'));
      expect(result.derivative, contains('+'));
    });

    test('隐式乘法与显式乘法是同一条法则', () {
      // `2x` 在树里是隐式乘法——**两种写法不许有两条法则**。
      final implicit = differentiate('2x', 'x');
      final explicit = differentiate('2 * x', 'x');
      expect(implicit.steps.last.rule, DerivativeRules.product);
      expect(explicit.steps.last.rule, DerivativeRules.product);
    });

    test('负号提到外面', () {
      final result = differentiate('-x', 'x');
      expect(result.steps.last.rule, DerivativeRules.negate);
      expect(result.derivative, '-(1)');
    });
  });

  group('⚠️ 表外的节点：停下并说明，绝不悄悄跳过', () {
    test('⚠️ 表外的函数：停下，不许猜', () {
      // 中文：**导数写错的函数比"不支持的函数"坏得多**——前者会印出一条看上去很完整的假推导。
      //       所以 `asin`/`abs`/`log` 这些**不在表里**，不是忘了，是**没有量过**。
      //       `x!` 更直接：阶乘没有初等导数。
      // English: **a wrong derivative is far worse than an unsupported function** — the former prints a
      //          plausible-looking, complete, fake derivation. So `asin`, `abs` and `log` are **not in the
      //          table**: not forgotten, but **not measured**. `x!` is plainer still: the factorial has no
      //          elementary derivative.
      for (final source in <String>['acosh(x)', 'erf(x)', 'x!']) {
        final result = differentiate(source, 'x');
        expect(result.derivative, isNull, reason: '`$source` 算不了就不许给结果');
        expect(result.refusal, isNotNull, reason: '`$source` 必须说明为什么停下');
      }
    });

    test('二元函数不在链式法则的适用范围里：停下', () {
      // 中文：`atan2(y, x)` 有两个实参——**不许把第一个当整体**。
      final result = differentiate('atan2(1, x)', 'x');
      expect(result.derivative, isNull);
      expect(result.refusal, isNotNull);
    });

    test('链式法则：外层与内层**两层都看得见**', () {
      final result = differentiate('sin(x)', 'x');
      expect(result.steps.last.rule, DerivativeRules.chain);
      // `sin` 的外层导数是 `cos(u)`，内层是 `1`。
      expect(result.derivative, 'cos(x)·(1)');
    });

    test('链式法则套幂法则：内层那一步先写出来', () {
      // 中文：`sin(x^2)` 应该先出现内层的幂法则，再出现外层的链式法则——
      //       **顺序就是推导的顺序**，用户照着读得下去。
      // English: `sin(x^2)` shows the inner power rule first and the outer chain rule after — **the order
      //          is the order of the derivation**, so it can be read straight through.
      final result = differentiate('sin(x^2)', 'x');
      expect(result.refusal, isNull);
      final rules = result.steps.map((s) => s.rule).toList();
      expect(rules.contains(DerivativeRules.power), isTrue);
      expect(rules.contains(DerivativeRules.chain), isTrue);
      expect(rules.indexOf(DerivativeRules.power),
          lessThan(rules.indexOf(DerivativeRules.chain)),
          reason: '内层先算：$rules');
      expect(result.derivative, contains('cos(x^2)'));
      expect(result.derivative, contains('2·x^1'), reason: '指数不空格：x^2 不是 x ^ 2');
    });

    test('⚠️ 量过的八条：期望值来自引擎，不是照定义抄的', () {
      // 中文：**宿主 `qalc` 5.12.0 的 `diff(f(x), x)` 逐条对过**（第十八节）。
      //       引擎印出来的是 `1 / sqrt(1 - x^2)` 那种写法，这里写的是应用自己的写法，
      //       但**系数与形状一一对应**——比如 `log10` 的 `0.4342944819032518` 就是 `1/ln 10`。
      // English: **checked one by one against host `qalc` 5.12.0's `diff(f(x), x)`** (section 十八). The
      //          engine prints forms like `1 / sqrt(1 - x^2)` while these are the app's spelling, but the
      //          coefficients and shapes correspond one to one — `log10`'s `0.4342944819032518` is `1/ln 10`.
      const expected = <String, String>{
        'asin(x)': '1/sqrt(1-x^2)·(1)',
        'acos(x)': '-1/sqrt(1-x^2)·(1)',
        'atan(x)': '1/(x^2+1)·(1)',
        'log10(x)': '1/(x·ln(10))·(1)',
        'log2(x)': '1/(x·ln(2))·(1)',
        'sinh(x)': 'cosh(x)·(1)',
        'cosh(x)': 'sinh(x)·(1)',
        'tanh(x)': '1-tanh(x)^2·(1)',
      };
      expected.forEach((source, derivative) {
        final result = differentiate(source, 'x');
        expect(result.refusal, isNull, reason: '`$source` 应当在表里');
        expect(result.derivative, derivative, reason: '`$source`');
        expect(result.steps.last.rule, DerivativeRules.chain);
      });
    });

    test('⚠️ `abs` 与 `log` 刻意不在表里，各有各的理由', () {
      // 中文：**这一条钉的是"拒绝"，而不是"忘了"。** 两条理由都是量过之后才敢下的：
      //       `abs` 的导数是 `x/|x|`，在 0 处没有定义，而**这个工具没有地方说这句话**
      //       （每一步只有"式子"与"法则"两栏）——印出来就是一条**在 0 点上骗人的**推导；
      //       `log` 则是**两边定义不同**（引擎的是自然对数），那种拼写本仓一律拒绝。
      // English: **this pins "refused", not "forgotten".** Both reasons follow measurement: `abs`'s
      //          derivative is `x/|x|`, undefined at 0, and **this tool has nowhere to say so** (a step
      //          carries only "the expression" and "the rule") — printing it would be a derivation that
      //          **lies at the point 0**; `log` is a spelling **the two sides define differently** (the
      //          engine's is the natural log) and such spellings are always refused here.
      for (final source in <String>['abs(x)', 'log(x)']) {
        final result = differentiate(source, 'x');
        expect(result.derivative, isNull, reason: '`$source` 不该被求导');
        expect(result.refusal, isNotNull);
      }
    });

    test('六个表内函数各一条，形状与定义一致', () {
      // 中文：**这六条的期望值是定义给的，不是量出来的**——`sin`/`cos` 的导数、
      //       `ln` 与 `exp` 互逆、`sqrt` 是 `u^(1/2)` 的特例。所以这里钉的是**形状**：
      //       外层写成什么、以及"内层乘在外面"这件事。
      // English: **these six expectations come from the definitions, not from measurement** — the
      //          derivatives of `sin`/`cos`, `ln` and `exp` being inverses, `sqrt` as the `u^(1/2)` case.
      //          So what is pinned here is the **shape**: what the outer factor is written as, and the fact
      //          that the inner one multiplies it.
      const expected = <String, String>{
        'sin(x)': 'cos(x)·(1)',
        'cos(x)': '-sin(x)·(1)',
        'tan(x)': '1/cos(x)^2·(1)',
        'ln(x)': '1/x·(1)',
        'exp(x)': 'exp(x)·(1)',
        'sqrt(x)': '1/(2·sqrt(x))·(1)',
      };
      expected.forEach((source, derivative) {
        final result = differentiate(source, 'x');
        expect(result.derivative, derivative, reason: '`$source`');
        expect(result.steps.last.rule, DerivativeRules.chain);
      });
    });

    test('指数里含变量：幂法则不适用，如实停下', () {
      // 中文：`x^x` 要走**对数求导法**，那是另一条规则。**硬套幂法则会给出一个错值**：
      //       `x·x^0·(1)`——它看着像答案，而 `x^x` 的导数不是它。
      // English: `x^x` needs **logarithmic differentiation**, a different rule. **Forcing the power rule
      //          through would produce a wrong value**: `x·x^0·(1)` — which looks like an answer and is
      //          not the derivative of `x^x`.
      final result = differentiate('x^x', 'x');
      expect(result.derivative, isNull);
      expect(result.refusal, isNotNull);
    });

    test('⚠️ 读了一半的式子要拒绝：`2+` 不是 `2`', () {
      // 中文：**这一条是本轮唯一一处"先没查清、后查清"的地方。**
      //
      //       现象：`2+` **不是**解析错误——`ExpressionAstParser` 给的是一棵能求导出 `0` 的树，
      //       于是屏幕上会出现一个看着像答案的 `0`（**读了一半当成读完了**）。
      //
      //       我先猜了两条判据（"根节点没覆盖整句"、"空的数字字面量"），**两条都无效**，
      //       而当时不知道为什么。把它打印出来才看见真相：
      //
      //       ```
      //       Bin(+, Number("2")[0,1), ParseErrorNode("")[2,2))[0,2)
      //       ```
      //
      //       ——**解析错误嵌在里面**，而**根节点照样覆盖整句**；`2` 也不是空字面量。
      //       真正管用的判据一直就在手边：**`hasParseError`**（`expr_node.dart` 里那个，
      //       与 `canExpress` 用的是同一个谓词）。
      //
      //       👉 **教训**：判据查不出来时，**先把结构打出来**，别接着猜——
      //       两条猜出来的判据一起失效，正是因为它们都在猜"错误长在哪儿"。
      // English: **the round's one "unsettled then settled" point.**
      //
      //          Symptom: `2+` is **not** a parse error — `ExpressionAstParser` hands back a tree that
      //          differentiates to `0`, putting a `0` that looks like an answer on screen (**half read,
      //          taken for the whole**).
      //
      //          Two judgements were guessed first ("the root does not span the sentence", "an empty
      //          numeric literal"); **both were useless**, and at the time it was not clear why. Printing
      //          it out showed the truth:
      //
      //          ```
      //          Bin(+, Number("2")[0,1), ParseErrorNode("")[2,2))[0,2)
      //          ```
      //
      //          — the **parse error is nested inside** while the **root still spans the whole sentence**,
      //          and `2` is not an empty literal. The judgement that works was to hand all along:
      //          **`hasParseError`** (in `expr_node.dart`, the same predicate `canExpress` uses).
      //
      //          👉 **The lesson**: when a judgement cannot see something, **print the structure first** —
      //          do not keep guessing. Both guesses failed because both guessed *where the error lives*.
      for (final source in <String>['2+', 'x+', '2*']) {
        final result = differentiate(source, 'x');
        expect(result.derivative, isNull, reason: '`$source` 不该被求导');
        expect(result.refusal, isNotNull);
        expect(result.steps, isEmpty, reason: '`$source` 连完整的树都没有，谈不上步骤');
      }
    });

    test('空输入：只说读不出，没有步骤可说', () {
      // 中文：空串会被解析器读成**一个常量**（于是求导得 `0`），而"没输入"与"输入了一个常数"
      //       是两件事——后者是答案，前者不是。所以这一条挡在 `differentiate` 的门口。
      // English: an empty string is read by the parser as **a constant** (so the derivative comes out
      //          `0`), while "nothing typed" and "a constant typed" are two different things — the second
      //          is an answer and the first is not. So this is caught at `differentiate`'s door.
      final result = differentiate('', 'x');
      expect(result.derivative, isNull);
      expect(result.refusal, isNotNull);
      expect(result.steps, isEmpty, reason: '连树都没有，谈不上步骤');
    });

    test('空输入：只说读不出，没有步骤可说', () {
      // 中文：空串会被解析器读成**一个常量**（于是求导得 `0`），而"没输入"与"输入了一个常数"
      //       是两件事——后者是答案，前者不是。所以这一条挡在 `differentiate` 的门口。
      // English: an empty string is read by the parser as **a constant** (so the derivative comes out
      //          `0`), while "nothing typed" and "a constant typed" are two different things — the second
      //          is an answer and the first is not. So this is caught at `differentiate`'s door.
      final result = differentiate('', 'x');
      expect(result.derivative, isNull);
      expect(result.refusal, isNotNull);
      expect(result.steps, isEmpty, reason: '连树都没有，谈不上步骤');
    });
    test('停下时，前面的步骤照旧给出来——用户看得见走到哪一步', () {
      // 中文：**这一条是"停下"与"什么都不给"的区别。** `x + acosh(x)` 里 `x` 那一半是算得出来的，
      //       推导应当把那一半写出来，再说后面那个算不了——**而不是整条清空**。
      //       （整条清空也安全，但用户会以为"这个式子完全算不了"。）
      // English: **this is the difference between "stopping" and "giving nothing".** In `x + acosh(x)` the
      //          `x` half is computable; the derivation should show that half and then say the rest
      //          cannot be done — **not wipe the whole thing**. (Wiping is also safe, but the user would
      //          conclude the whole expression is unsupported.)
      final result = differentiate('x + acosh(x)', 'x');
      expect(result.refusal, isNotNull);
      expect(result.derivative, isNull);
      expect(result.steps, isNotEmpty, reason: '左边那一半是算出来的，要看得见');
      expect(result.steps.first.expression, '1');
    });
  });

  group('整体形状', () {
    test('走通时：最后一步就是导数本身，且没有 refusal', () {
      // 中文：**两条判据不会同时成立**（见类型上那段注释）：走通 ⇒ `refusal` 为空；
      //       停下 ⇒ `derivative` 为空。
      final result = differentiate('3x + 2', 'x');
      expect(result.refusal, isNull);
      expect(result.derivative, result.steps.last.expression);
    });

    test('括号不是一步：它不改变任何东西', () {
      // 中文：给括号记一条法则只会让推导看着更长，而且那条法则没有任何内容。
      final withGroup = differentiate('(x)', 'x');
      expect(withGroup.steps.length, 1);
      expect(withGroup.derivative, '1');
    });

    test('法则名是判据不是文案：它们是稳定的 ASCII 令牌', () {
      // 中文：界面上那句话由文案表拼，**判据这一层不许跟着语言走**。
      for (final rule in <String>[
        DerivativeRules.constant,
        DerivativeRules.self,
        DerivativeRules.other,
        DerivativeRules.sum,
        DerivativeRules.negate,
        DerivativeRules.product,
        DerivativeRules.power,
        DerivativeRules.chain,
      ]) {
        expect(RegExp(r'^[a-z]+$').hasMatch(rule), isTrue,
            reason: '`$rule` 不是纯 ASCII 小写令牌');
      }
    });
  });

  group('收拾（恒等式）：只去掉乘 1、加 0、一次方', () {
    test('乘法法则那一串收拾成人会写的样子', () {
      final result = differentiate('x^2', 'x');
      expect(result.derivative, '2·x^1·(1)', reason: '推导里保留法则的样子');
      // 中文：**结果是 `2·x` 而不是 `2x`，这是刻意的。** 把 `·` 去掉是**排版决定**
      //       （"2x 还是 2·x"没有唯一答案），而这一版只做**恒等式**。界线就在这里。
      // English: **the result is `2·x` and not `2x`, deliberately.** Dropping the `·` is a **typographic
      //          decision** ("2x or 2·x" has no single answer) while this version only does **identities**.
      //          That is where the line is.
      expect(result.simplified, '2·x', reason: '收拾过的那个给人用');
    });

    test('链式法则的 `·(1)` 也收拾掉', () {
      expect(differentiate('sin(x)', 'x').simplified, 'cos(x)');
      expect(differentiate('ln(x)', 'x').simplified, '1/x');
    });

    test('和里那个 ` + 0` 收拾掉', () {
      expect(differentiate('x + 3', 'x').simplified, '1');
    });

    test('⚠️ 边界：`x^12` 不许被吃成 `x^2`', () {
      // 中文：**这一条是那些边界存在的理由。** `^1` 那条规则如果不带"后面不许跟数字"，
      //       `x^12` 会被吃成 `x^2`——一个**看着很像但完全不同**的答案。
      // English: **this is why the boundaries exist.** Without "^1 may not be followed by a digit",
      //          `x^12` would be eaten down to `x^2` — an answer that **looks similar and is entirely
      //          different**.
      expect(simplifyDerivative('x^12'), 'x^12');
      expect(simplifyDerivative('x^1'), 'x');
      expect(simplifyDerivative('x^1+x^12'), 'x+x^12');
    });

    test('⚠️ 边界：`21·x` 不许被吃成 `2·x`', () {
      expect(simplifyDerivative('21·x'), '21·x');
      expect(simplifyDerivative('1·x'), 'x');
      expect(simplifyDerivative('10·1'), '10');
    });

    test('⚠️ 边界：` + 0` 不许吃掉 ` + 0.5` 的 0', () {
      expect(simplifyDerivative('1 + 0.5'), '1 + 0.5');
      expect(simplifyDerivative('1 + 0'), '1');
      expect(simplifyDerivative('10 + 0'), '10');
    });

    test('反例：它**不做**真正的化简', () {
      // 中文：**这条钉的是界线，不是能力。** 合并同类项、重新排序、展开括号都要做取舍
      //       （"该化到什么程度没有唯一答案"），所以这一版**一件都不做**——
      //       下面这些原样出来，**这正是设计意图**。
      // English: **this pins the boundary, not a shortcoming.** Collecting like terms, reordering and
      //          expanding brackets all involve judgement ("how far to simplify has no single answer"), so
      //          this version does **none** of them — the forms below come back unchanged, **by design**.
      expect(simplifyDerivative('x + x'), 'x + x');
      expect(simplifyDerivative('2 + 3'), '2 + 3');
      expect(simplifyDerivative('x·1·y'), 'x·y');  // `·` 留着：那是排版决定，不是恒等式
    });

    test('收拾之后仍然读得通：没有半截运算符', () {
      // 中文：**去掉一个因子之后不许留下悬空的 `·` 或 `+`。** 这是收拾最容易出的形态错。
      // English: **removing a factor must not leave a dangling `·` or `+`** — the likeliest shape error
      //          in tidying.
      for (final source in <String>['x^2', 'x * x', 'x + 3', 'sin(x)', '3x + 2', 'x - 5']) {
        final simplified = differentiate(source, 'x').simplified!;
        expect(simplified, isNot(endsWith('·')), reason: '`$source` → `$simplified`');
        expect(simplified, isNot(endsWith('+')), reason: '`$source` → `$simplified`');
        expect(simplified, isNot(startsWith('·')), reason: '`$source` → `$simplified`');
        expect(simplified, isNot(contains('··')), reason: '`$source` → `$simplified`');
      }
    });
  });
}
