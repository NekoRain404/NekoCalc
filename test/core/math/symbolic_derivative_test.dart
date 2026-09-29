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
    test('函数调用这一版不做（链式法则留给下一版）', () {
      for (final source in <String>['sin(x)', 'ln(x)', 'x!']) {
        final result = differentiate(source, 'x');
        expect(result.derivative, isNull, reason: '`$source` 算不了就不许给结果');
        expect(result.refusal, isNotNull, reason: '`$source` 必须说明为什么停下');
      }
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
      // 中文：**这一条是"停下"与"什么都不给"的区别。** `x + sin(x)` 里 `x` 那一半是算得出来的，
      //       推导应当把那一半写出来，再说后面那个算不了——**而不是整条清空**。
      //       （整条清空也安全，但用户会以为"这个式子完全算不了"。）
      // English: **this is the difference between "stopping" and "giving nothing".** In `x + sin(x)` the
      //          `x` half is computable; the derivation should show that half and then say the rest
      //          cannot be done — **not wipe the whole thing**. (Wiping is also safe, but the user would
      //          conclude the whole expression is unsupported.)
      final result = differentiate('x + sin(x)', 'x');
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
}
