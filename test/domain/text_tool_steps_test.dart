import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/controllers/text_tool_controller.dart';
import 'package:nekocalc/features/tools/presentation/text_tool_strings.dart';
import 'package:nekocalc/l10n/app_language.dart';

/// 中文：**算术分步工具的测试。** 它不依赖引擎，所以这些断言就是全部证据。
/// English: **the arithmetic-stepper tool's tests.** It does not depend on the engine, so these assertions
///          are the whole proof.
TextToolOutput _run(String input, {AppLanguage language = AppLanguage.zh}) {
  return const TextToolController().calculate(
    toolId: 'arithmetic_steps',
    strings: TextToolStrings.forLanguage(language),
    input: input,
  );
}

void main() {
  group('算术分步', () {
    test('结果行是值，详情里是每一步（含抬头）', () {
      final out = _run('1 + 2 * 3');
      expect(out.hasError, isFalse);
      expect(out.primary, '7');
      expect(out.detail, contains('每一步'));
      expect(out.detail, contains('1 + 6'));
    });

    test('括号优先、同级从左到右', () {
      expect(_run('(1 + 2) * 3').detail, contains('3 * 3'));
      expect(_run('8 / 4 / 2').detail, contains('2 / 2'));
    });

    test('⚠️ 不支持的一律说清楚，而不是给一个数', () {
      // 中文：**变量、函数、后缀都不在这一版**——而它们**读得出**，所以那句话说的是
      //       「这一版只做四则运算与整数次幂」，不是「读不出」。
      // English: **variables, calls and postfixes are outside this version** — and they **are readable**, so
      //          the sentence says "this version covers arithmetic and integer powers only", not
      //          "unreadable".
      for (final input in <String>['x + 1', 'sin(1)', '3!', '2^0.5']) {
        final out = _run(input);
        expect(out.hasError, isTrue, reason: '`$input` 这一版不做');
        expect(out.primary, contains('只做四则运算'));
        expect(out.primary, isNot(contains('读不出')));
      }
    });

    test('空输入说的是另一件事', () {
      expect(_run('').primary, contains('请输入'));
      expect(_run('').primary, isNot(contains('只做四则运算')));
    });

    test('英文侧一个汉字都没有，算式原样出', () {
      final han = RegExp(r'[一-鿿]');
      for (final input in <String>['1 + 2 * 3', 'x + 1', '']) {
        final out = _run(input, language: AppLanguage.en);
        for (final line in <String>[out.primary, out.detail]) {
          expect(han.hasMatch(line), isFalse, reason: '英文侧还有汉字：`$line`');
        }
      }
      final en = _run('1 + 2 * 3', language: AppLanguage.en);
      expect(en.primary, '7');
      expect(en.detail, contains('Steps'));
      expect(en.detail, contains('1 + 6'), reason: '算式是数据，两种语言原样出');
    });
  });
}
