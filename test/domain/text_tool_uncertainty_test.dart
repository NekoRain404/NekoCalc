import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/controllers/text_tool_controller.dart';
import 'package:nekocalc/features/tools/presentation/text_tool_strings.dart';
import 'package:nekocalc/l10n/app_language.dart';

/// 中文：**不确定度传播工具的测试。** 它不依赖引擎，所以这些断言就是全部证据，不必等真机。
/// English: **the uncertainty tool's tests.** It does not depend on the engine, so these assertions are
///          the whole proof — no device needed.
TextToolOutput _run(String input, {AppLanguage language = AppLanguage.zh}) {
  return const TextToolController().calculate(
    toolId: 'uncertainty',
    strings: TextToolStrings.forLanguage(language),
    input: input,
  );
}

void main() {
  group('不确定度传播', () {
    test('两项：和与差是平方和开方，积与商是相对值的平方和开方', () {
      // 0.3² + 0.1² = 0.10 → √0.10 = 0.316228（六位有效）
      // (0.3/12.5)² + (0.1/4.2)² = 0.001142893… → √ = 0.0338067… → 3.38067%
      final out = _run('12.5 ± 0.3\n4.2 ± 0.1');
      expect(out.hasError, isFalse);
      expect(out.primary, '± 0.316228');
      expect(out.insights, contains('和与差 · ± 0.316228'));
      expect(out.insights, contains('积与商 · 3.38067%'));
    });

    test('主要来源：报的是贡献占比最大的那一项', () {
      // 0.09 对 0.01 → 90% 对 10%，第一项占绝对多数。
      final out = _run('12.5 ± 0.3\n4.2 ± 0.1');
      expect(out.insights, contains('主要来源 · 第 1 项 · 90%'));

      // 中文：**把大的放到第二项，它就该报到第二项。** 这一条防的是"下标写死成 0"。
      // English: **put the large one second and it must name the second term.** This guards against an
      //          index hard-wired to 0.
      expect(_run('4.2 ± 0.1\n12.5 ± 0.3').insights,
          contains('主要来源 · 第 2 项 · 90%'));
    });

    test('三项：平方和按三项算，占比也按三项算', () {
      // 0.1² + 0.2² + 0.2² = 0.09 → √ = 0.3
      final out = _run('10 ± 0.1\n20 ± 0.2\n30 ± 0.2');
      expect(out.primary, '± 0.3');
      // 0.01 / 0.09 = 11.111…% ； 0.04 / 0.09 = 44.444…%
      expect(out.insights, contains('主要来源 · 第 2 项 · 44.4444%'));
    });

    test('写法宽容：`+-`、`+/-`、逗号分行都收', () {
      const expected = '± 0.316228';
      for (final input in <String>[
        '12.5 ± 0.3\n4.2 ± 0.1',
        '12.5 +- 0.3\n4.2 +- 0.1',
        '12.5 +/- 0.3\n4.2 +/- 0.1',
        '12.5±0.3\n4.2±0.1',
        '12.5 ± 0.3，4.2 ± 0.1',
      ]) {
        expect(_run(input).primary, expected, reason: '`$input` 没被认出来');
      }
    });

    test('⚠️ 负的不确定度必须被拒绝，不能被 √(Δ²) 悄悄抹成正数', () {
      // 中文：**这是本工具最容易骗人的地方。** `Δ = -0.3` 没有物理意义，而平方和开方会把负号
      //       吃掉、算出一个和 `0.3` 一模一样的正数——用户看不出任何异常。
      // English: **this is where the tool most easily lies.** `Δ = -0.3` has no physical meaning, and
      //          quadrature eats the sign and produces a positive number identical to `0.3`'s — with
      //          nothing on screen to show it happened.
      final out = _run('12.5 ± -0.3\n4.2 ± 0.1');
      expect(out.hasError, isTrue, reason: '负的不确定度应当被拒绝');
      expect(out.primary, contains('读不出'));
    });

    test('读不出就如实拒绝，并给出例子', () {
      for (final input in <String>['', '西红柿炒蛋', '12.5', '12.5 ± abc', '± 0.3']) {
        expect(_run(input).hasError, isTrue, reason: '`$input` 应当被拒绝');
      }
      expect(_run('').primary, contains('请输入'));
      expect(_run('西红柿炒蛋').primary, contains('读不出'));
      expect(_run('西红柿炒蛋').detail, contains('例如'));
    });

    test('只给一项：说清"没有可传播的合成"，并给这一项自己的相对不确定度', () {
      final out = _run('12.5 ± 0.3');
      expect(out.hasError, isTrue, reason: '一项没有合成可言，这一支是错误不是结果');
      expect(out.primary, '12.5 ± 0.3');
      expect(out.detail, contains('只有一项'));
      expect(out.insights, contains('相对不确定度 · 2.4%'));
    });

    test('英文侧一个汉字都没有，数值原样出', () {
      final han = RegExp(r'[一-鿿]');
      for (final input in <String>[
        '12.5 ± 0.3\n4.2 ± 0.1',
        '12.5 ± 0.3',
        '',
        '西红柿炒蛋',
      ]) {
        final out = _run(input, language: AppLanguage.en);
        for (final line in <String>[out.primary, out.detail, ...out.insights]) {
          expect(han.hasMatch(line), isFalse, reason: '英文侧还有汉字：`$line`');
        }
      }
      expect(_run('12.5 ± 0.3\n4.2 ± 0.1', language: AppLanguage.en).primary,
          '± 0.316228');
    });

    test('两种语言同一个答案，只有话说得不一样', () {
      final zh = _run('12.5 ± 0.3\n4.2 ± 0.1');
      final en = _run('12.5 ± 0.3\n4.2 ± 0.1', language: AppLanguage.en);
      expect(zh.primary, en.primary);
      expect(zh.hasError, en.hasError);
      expect(zh.insights.length, en.insights.length);
      expect(zh.detail, isNot(en.detail));
    });

    test('值为 0 时相对不确定度没有定义，但不许把整条结果变成 NaN', () {
      // 0 ± 0.1 与 5 ± 0.1：绝对项照算（√0.02 = 0.141421），相对项回 0 而不是 NaN 或 ∞。
      final out = _run('0 ± 0.1\n5 ± 0.1');
      expect(out.hasError, isFalse);
      expect(out.primary, '± 0.141421');
      expect(out.primary, isNot(contains('NaN')));
      expect(out.insights.join(' '), isNot(contains('NaN')));
    });
  });
}
