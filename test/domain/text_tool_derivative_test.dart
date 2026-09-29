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
      expect(out.primary, '2·x^1·(1)');
      expect(out.detail, contains('幂法则'));
      expect(out.detail, contains('2·x^1·(1)'));
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
      // 中文：**这一条是"停下"与"什么都不给"的区别。** `x + sin(x)` 里 `x` 那一半算得出来，
      //       推导必须把那一半写出来再说后面算不了——否则用户会以为整个式子都不支持。
      // English: **this is the difference between "stopping" and "giving nothing".** In `x + sin(x)` the
      //          `x` half is computable and the derivation must show it before saying the rest cannot be
      //          done — otherwise the user concludes the whole expression is unsupported.
      final out = _run('x + sin(x)');
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

    test('对 x 求导是工具定的：`y` 是常量', () {
      // 中文：**变量不由用户写**——猜错变量会给出一个看着像答案的错值
      //       （对 `y` 求导与对 `x` 求导结果完全不同）。所以工具写死 `x`。
      // English: **the variable is not the user's to write** — guessing wrong gives a wrong value that
      //          looks like an answer (differentiating with respect to `y` and to `x` differ entirely). So
      //          the tool fixes `x`.
      final out = _run('y');
      expect(out.hasError, isFalse);
      expect(out.primary, '0');
      expect(out.detail, contains('不含要求导的那个变量'));
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
      expect(en.primary, '2·x^1·(1)', reason: '算式是数据，两种语言原样出');
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
