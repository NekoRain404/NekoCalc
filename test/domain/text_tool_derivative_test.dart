import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/controllers/text_tool_controller.dart';
import 'package:nekocalc/features/tools/presentation/text_tool_strings.dart';
import 'package:nekocalc/l10n/app_language.dart';

/// 中文：**求导分步工具的测试。** 它不依赖引擎（规则在 `symbolic_derivative.dart` 里自己写），
///       所以这些断言就是全部证据，不必等真机——与日期、不确定度那两个工具同一条判据。
///
///       ⚠️ **断言写的是"法则的样子"，不是化简后的答案。** `2·x^1·(1)` 不是错，
///       它就是幂法则写出来的样子（该化到什么程度没有唯一答案）。
/// English: **the derivative-steps tool's tests.** It does not depend on the engine (the rules are
///          written out in `symbolic_derivative.dart`), so these assertions are the whole proof and no
///          device is needed — the same judgement as the date and uncertainty tools.
///
///          ⚠️ **The assertions describe "what the rule looks like", not a simplified answer.**
///          `2·x^1·(1)` is not wrong; it is what the power rule reads like.
TextToolOutput _run(String input, {AppLanguage language = AppLanguage.zh}) {
  return const TextToolController().calculate(
    toolId: 'derive_steps',
    strings: TextToolStrings.forLanguage(language),
    input: input,
  );
}

void main() {
  group('求导分步', () {
    test('幂法则：结果与"用了哪条法则"都写出来', () {
      final out = _run('x^2');
      expect(out.hasError, isFalse);
      // 中文：**结果行是收拾过的那个（`2·x`），推导里保留法则的样子（`2·x^1·(1)`）。**
      //       两个都要：只给推导，用户得自己收拾；只给结果，"用了哪条法则"就没了。
      // English: **the result line carries the tidied form (`2·x`) while the derivation keeps what the
      //          rule looks like (`2·x^1·(1)`).** Both are needed: with only the derivation the user does
      //          the tidying, with only the result the "which rule" is gone.
      expect(out.primary, '2·x');
      expect(out.detail, contains('幂法则'));
      expect(out.detail, contains('2·x^1·(1)'), reason: '推导里那一步照旧是法则的样子');
      expect(out.detail, contains('= 2·x'), reason: '末尾多一行收拾过的');
    });

    test('和：每一步一行，最后的和法则也写出来', () {
      final out = _run('x + 3');
      expect(out.hasError, isFalse);
      expect(out.detail, contains('1. 1'));
      expect(out.detail, contains('2. 0'));
      expect(out.detail, contains('和的导数等于各项导数之和'));
    });

    test('乘法法则：两半都在', () {
      final out = _run('x * x');
      expect(out.hasError, isFalse);
      expect(out.detail, contains('乘法法则'));
    });

    test('⚠️ 不会的那一步：如实停下，**前面几步照旧给出来**', () {
      // 中文：**这一条是"停下"与"什么都不给"的区别。** `x + acosh(x)` 里 `x` 那一半算得出来，
      //       推导必须把那一半写出来再说后面算不了——否则用户会以为整个式子都不支持。
      //       （`acosh` 的导数**没有量过**，所以它不在表里；`sin` 在表里，见下一条。）
      // English: **this is the difference between "stopping" and "giving nothing".** In `x + acosh(x)` the
      //          `x` half is computable and the derivation must show it before saying the rest cannot be
      //          done — otherwise the user concludes the whole expression is unsupported. (`acosh`'s
      //          derivative was **never measured**, so it is not in the table; `sin` is — see below.)
      final out = _run('x + acosh(x)');
      expect(out.hasError, isTrue, reason: '没走完就不算答案');
      expect(out.detail, contains('1. 1'), reason: '左边那一半要看得见');
      expect(out.detail, contains('这一步还不会算'));
    });

    test('读不出的式子：只说读不出，并给例子', () {
      for (final input in <String>['', '2+', 'x+']) {
        final out = _run(input);
        expect(out.hasError, isTrue, reason: '`$input` 应当被拒绝');
      }
      expect(_run('').primary, contains('请输入'));
      expect(_run('2+').primary, contains('读不出'));
      expect(_run('2+').detail, contains('例如'));
    });

    test('链式法则：`sin(x^2)` 两层都看得见，且内层先出现', () {
      final out = _run('sin(x^2)');
      expect(out.hasError, isFalse);
      expect(out.primary, contains('cos(x^2)'), reason: '指数不空格：x^2 不是 x ^ 2');
      final detail = out.detail;
      expect(detail, contains('幂法则'));
      expect(detail, contains('链式法则'));
      expect(detail.indexOf('幂法则'), lessThan(detail.indexOf('链式法则')),
          reason: '内层那一步先写出来：\n$detail');
    });

    test('⚠️ 表外的函数：停下，且**说明是哪一步**不算', () {
      // 中文：**导数写错的函数比"不支持的函数"坏得多**——前者会印出一条看上去很完整的假推导。
      //       `abs` 与 `log` 是**量过之后刻意不留**的（0 处不可导；两边定义不同），
      //       `acosh` 则纯粹是没有量过。三种情况都停在同一个地方。
      // English: **a wrong derivative is far worse than an unsupported function** — the former prints a
      //          plausible-looking, complete, fake derivation. `abs` and `log` are **deliberately absent
      //          after measurement** (not differentiable at 0; the two sides define it differently) while
      //          `acosh` simply **was never measured**. All three stop in the same place.
      for (final input in <String>['acosh(x)', 'erf(x)']) {
        final out = _run(input);
        expect(out.hasError, isTrue, reason: '`$input` 算不了');
        expect(out.detail, contains('这一步还不会算'));
      }
    });

    test('⚠️ 变量可以点名：`diff(y^2, y)` 与裸式子走同一条路', () {
      // 中文：**`diff(x^2,x)` 正是应用自己的写法**——`d/dx` 那颗键（`∫dx` 的 SHIFT 变体）
      //       插的就是它（两个槽，引擎自己的实参顺序）。所以用户手里拿到的原文必须能用。
      // English: **`diff(x^2,x)` is this app's own spelling** — the `d/dx` key (the SHIFT variant of `∫dx`)
      //          inserts exactly that (two slots, the engine's own argument order). So the text the user
      //          already has has to work.
      final named = _run('diff(y^2, y)');
      expect(named.hasError, isFalse);
      expect(named.primary, '2·y', reason: '对 y 求导');
      expect(named.insights.join(), contains('对 y 求导'), reason: '屏幕上要说清是对谁求的');

      // 另一种写法（同一件事的另一半）也收。
      final operator = _run('d/dy(y^2)');
      expect(operator.primary, '2·y');

      // 不点名时退回 `x`，并且**说明**是对 x 求的。
      final bare = _run('x^2');
      expect(bare.primary, '2·x');
      expect(bare.insights.join(), contains('对 x 求导'));
    });

    test('⚠️ 用 `abs` 时，边界那句话**必须在屏幕上**', () {
      // 中文：**判据读的是步骤里的法则令牌**（`chain_caveat`），不是回读印出来的句子。
      //       `x/|x|` 在 0 处没有定义——不说这句话，那条推导在 0 点上就是骗人的。
      // English: **the judgement reads the rule token in the steps** (`chain_caveat`), not the printed
      //          sentence. `x/|x|` is undefined at 0; without the sentence the derivation lies at that point.
      final out = _run('abs(x)');
      expect(out.hasError, isFalse);
      expect(out.insights.join(), contains('不可导'));
      expect(_run('sin(x)').insights.join(), isNot(contains('不可导')),
          reason: '没用 `abs` 就不该出现那句话');
    });

    test('对 x 求导时 `y` 是常量', () {
      // 中文：**变量不由用户写**——猜错变量会给出一个看着像答案的错值
      //       （对 `y` 求导与对 `x` 求导结果完全不同）。所以工具写死 `x`。
      // English: **the variable is not the user's to write** — guessing wrong gives a wrong value that
      //          looks like an answer (differentiating with respect to `y` and to `x` differ entirely). So
      //          the tool fixes `x`.
      final out = _run('y');
      expect(out.hasError, isFalse);
      expect(out.primary, '0');
      expect(out.detail, contains('不含要求导的那个变量'));
      expect(out.insights.join(), contains('对 x 求导'));
    });

    test('收拾过的那一行只在**与最后一步不同**时才印', () {
      // 中文：相同的时候再印一遍等于说两遍同一件事。
      // English: printing it when identical would say the same thing twice.
      // 中文：**要挑一个"收拾完还是它自己"的案例**——`-x` 的导数是 `-(1)`，恒等式那几条
      //       一条都碰不到它。（`sin(x)` **不是**这样的例子：它的 `cos(x)·(1)` 会被收拾成 `cos(x)`，
      //       所以那一行**应当**印出来——我第一版就拿它当反例，错了。）
      // English: **pick a case the tidying leaves alone** — `-x` derives to `-(1)` and none of the identity
      //          rules touch it. (`sin(x)` is **not** such a case: its `cos(x)·(1)` tidies to `cos(x)`, so
      //          that line **should** print — my first version used it as the counter-example and was
      //          wrong.)
      final unchanged = _run('-x');
      expect(unchanged.detail, contains('-(1)'));
      expect(unchanged.detail, isNot(contains('= ')), reason: '收拾完还是它自己就不印');
      expect(unchanged.primary, '-(1)');
    });

    test('英文侧一个汉字都没有，算式原样出', () {
      final han = RegExp(r'[一-鿿]');
      for (final input in <String>['x^2', 'x + 3', 'x + sin(x)', '', '2+']) {
        final out = _run(input, language: AppLanguage.en);
        for (final line in <String>[out.primary, out.detail]) {
          expect(han.hasMatch(line), isFalse, reason: '英文侧还有汉字：`$line`');
        }
      }
      final en = _run('x^2', language: AppLanguage.en);
      expect(en.primary, '2·x', reason: '算式是数据，两种语言原样出');
      expect(en.detail, contains('the power rule'));
    });

    test('两种语言同一个答案，只有法则那句话不一样', () {
      final zh = _run('x^2');
      final en = _run('x^2', language: AppLanguage.en);
      expect(zh.primary, en.primary);
      expect(zh.hasError, en.hasError);
      expect(zh.detail, isNot(en.detail));
    });
  });
}
