import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/controllers/text_tool_controller.dart';
import 'package:nekocalc/features/tools/presentation/text_tool_strings.dart';
import 'package:nekocalc/l10n/app_language.dart';

/// 中文：**质因数分解工具的测试。** 它不依赖引擎（引擎分不动时会把输入退回来，见工具文件头），
///       所以这些断言就是全部证据，不必等真机。
///
///       ⚠️ **`123456` 那条是"与引擎逐项相同"**：宿主 `qalc` 5.12.0 的 `factor(123456)` 给
///       `[2 2 2 2 2 2 3 643]`，也就是 `2^6 × 3 × 643`；sympy 的 `factorint` 给同一个。
/// English: **the prime-factorisation tool's tests.** It does not depend on the engine (the engine hands
///          the input back when it cannot factor; see the tool's head), so these assertions are the whole
///          proof and no device is needed.
///
///          ⚠️ **The `123456` case is "identical to the engine term by term"**: host `qalc` 5.12.0's
///          `factor(123456)` gives `[2 2 2 2 2 2 3 643]`, i.e. `2^6 × 3 × 643`, and sympy's `factorint`
///          agrees.
TextToolOutput _run(String input, {AppLanguage language = AppLanguage.zh}) {
  return const TextToolController().calculate(
    toolId: 'prime_factor',
    strings: TextToolStrings.forLanguage(language),
    input: input,
  );
}

void main() {
  group('质因数分解', () {
    test('与引擎逐项相同的那个例子', () {
      final out = _run('123456');
      expect(out.hasError, isFalse);
      expect(out.primary, '2^6 × 3 × 643');
    });

    test('指数合并、质数升序，指数为 1 的不印 `^1`', () {
      expect(_run('720').primary, '2^4 × 3^2 × 5');
      expect(_run('97').primary, '97');
    });

    test('千分位分隔会去掉', () {
      expect(_run('1,000,000').primary, '2^6 × 5^6');
    });

    test('⚠️ 超出 64 位的值照样分解', () {
      // `2^64` 是一个 20 位十进制数，远超 64 位整数。
      expect(_run('2^64').hasError, isTrue, reason: '这里的输入只收十进制整数，不是表达式');
      expect(_run('18446744073709551616').primary, '2^64');
    });

    test('⚠️ `< 2` 与"读不出"是两件事', () {
      // 中文：**`1` 与 `0` 读懂了，只是它们没有质因数分解**——所以那句话说的是这个，
      //       不是"读不出"。两者在屏幕上给用户的信息完全不同。
      // English: **`1` and `0` were read; they simply have no prime factorisation** — so the sentence says
      //          that, not "unreadable". The two tell the user entirely different things.
      for (final input in <String>['1', '0']) {
        final out = _run(input);
        expect(out.hasError, isTrue);
        expect(out.primary, contains('没有质因数分解'));
      }
      final unreadable = _run('西红柿炒蛋');
      expect(unreadable.hasError, isTrue);
      expect(unreadable.primary, contains('读不出'));
      expect(unreadable.primary, isNot(contains('没有质因数分解')));
    });

    test('空输入与负数', () {
      expect(_run('').primary, contains('请输入'));
      expect(_run('-12').primary, contains('没有质因数分解'));
    });

    test('英文侧一个汉字都没有，数字原样出', () {
      final han = RegExp(r'[一-鿿]');
      for (final input in <String>['123456', '1', '西红柿炒蛋', '']) {
        final out = _run(input, language: AppLanguage.en);
        for (final line in <String>[out.primary, out.detail]) {
          expect(han.hasMatch(line), isFalse, reason: '英文侧还有汉字：`$line`');
        }
      }
      expect(_run('123456', language: AppLanguage.en).primary, '2^6 × 3 × 643',
          reason: '分解结果是数据，两种语言原样出');
    });
  });
}
