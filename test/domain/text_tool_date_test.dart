import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/controllers/text_tool_controller.dart';
import 'package:nekocalc/features/tools/presentation/text_tool_strings.dart';
import 'package:nekocalc/l10n/app_language.dart';

/// 中文：**日期计算工具的测试。** 「今天」是注入进来的（`DateTime(2026, 9, 20)`），
///       所以每一条断言都是确定的，没有一个依赖跑测试那天是星期几。
/// English: **the date calculator's tests.** "Today" is injected (`DateTime(2026, 9, 20)`), so every
///          assertion is deterministic and none depends on which weekday the test happens to run.
TextToolOutput _run(String input, {AppLanguage language = AppLanguage.zh}) {
  return const TextToolController().calculate(
    toolId: 'date_calc',
    strings: TextToolStrings.forLanguage(language),
    input: input,
    today: DateTime(2026, 9, 20),
  );
}

void main() {
  group('日期计算', () {
    test('两个日期：相差天数按绝对值给，方向写在详情里', () {
      final forward = _run('2026-01-01 到 2026-09-20');
      expect(forward.primary, '262 天');
      expect(forward.detail, '2026-01-01 到 2026-09-20');
      expect(forward.hasError, isFalse);

      // 中文：**反过来问，天数一样多。** `262` 是绝对值，不是有符号数——
      //       "相差多少天"问的是距离，与谁在前无关。
      // English: **asked the other way round, the count is the same.** `262` is a magnitude and not a
      //          signed number: "how many days apart" asks for a distance, which does not care which
      //          date comes first.
      final backward = _run('2026-09-20 到 2026-01-01');
      expect(backward.primary, '262 天');
      expect(backward.detail, '2026-01-01 到 2026-09-20',
          reason: '详情里应当按先后排好序');
    });

    test('两个日期：周与年月日两条换算都在', () {
      final out = _run('2026-01-01 到 2026-09-20');
      expect(out.insights, contains('37 周 3 天'));
      expect(out.insights, contains('0 年 8 个月 19 天'));
    });

    test('同一个日期：说同一天，不是 0 天的距离', () {
      final out = _run('2026-09-20 到 2026-09-20');
      expect(out.primary, '0 天');
      expect(out.detail, contains('同一天'));
    });

    test('单个日期：给星期、年内天数与 ISO 周', () {
      // 2026-09-20 是星期日；年内第 263 天；ISO 周 38。
      final out = _run('2026-09-20');
      expect(out.primary, '2026-09-20 这一天');
      expect(out.detail, contains('星期日'));
      expect(out.insights, contains('年内第几天 · 263'));
      expect(out.insights, contains('ISO 周 · 38'));
      expect(out.insights, contains('闰年 · 否'));
    });

    test('ISO 周在年初年末都对：这是最容易错一周的地方', () {
      // 中文：**ISO 8601 的周从星期一开始，第一周必须含星期四。**
      //       直接 `dayOfYear / 7` 的写法会在年初年末各错一周，所以这两头各钉一条。
      // English: **ISO 8601 weeks start on Monday and week 1 must hold a Thursday.** The `dayOfYear / 7`
      //          shortcut is off by one week at both ends of the year, so both ends are pinned.
      expect(_run('2026-01-01').insights, contains('ISO 周 · 1'),
          reason: '2026-01-01 是星期四，属于第 1 周');
      expect(_run('2027-01-01').insights, contains('ISO 周 · 53'),
          reason: '2027-01-01 是星期五，按 ISO 属于上一年的第 53 周');
      expect(_run('2026-12-31').insights, contains('ISO 周 · 53'));
    });

    test('加减天数：正负都收，跨年也对', () {
      expect(_run('2026-09-20 + 30').primary, '2026-10-20');
      expect(_run('2026-09-20 - 30').primary, '2026-08-21');
      expect(_run('2026-12-31 + 1').primary, '2027-01-01');
      expect(_run('2026-03-01 - 1').primary, '2026-02-28',
          reason: '2026 不是闰年，二月只有 28 天');
    });

    test('今天起算：`今天` / `today` / `now` 与裸的 `+30` 是同一条路', () {
      for (final input in <String>['今天 + 30', 'today + 30', 'now + 30', '+30']) {
        expect(_run(input).primary, '2026-10-20', reason: '`$input` 没走到今天起算');
      }
      expect(_run('今天 - 1').primary, '2026-09-19');
    });

    test('写法宽容：补零、年月日、斜杠、点号都是同一天', () {
      for (final input in <String>[
        '2026-09-20',
        '2026-9-20',
        '2026/09/20',
        '2026.09.20',
        '2026年9月20日',
      ]) {
        expect(_run(input).primary, '2026-09-20 这一天', reason: '`$input` 没被认出来');
      }
    });

    test('不在日历上的那一天要被拒绝，不是悄悄滚到下个月', () {
      // 中文：**这是本工具最容易骗人的地方。** `DateTime(2026, 2, 30)` 不会报错，
      //       它会**滚到 3 月 2 日**——不校验的话，用户问二月三十号，拿到的是三月二号的答案。
      // English: **this is where a date tool most easily lies.** `DateTime(2026, 2, 30)` does not throw;
      //          it **rolls over to 2 March**. Without the check, a user asking about 30 February gets
      //          2 March's answer.
      for (final input in <String>['2026-02-30', '2026-13-01', '2025-02-29']) {
        final out = _run(input);
        expect(out.hasError, isTrue, reason: '`$input` 不是真实的一天，应当被拒绝');
        expect(out.primary, '这一天不在日历上');
      }
      expect(_run('2024-02-29').hasError, isFalse, reason: '2024 是闰年，2-29 是真的');
    });

    test('读不出意图时如实拒绝，并给出例子', () {
      final empty = _run('');
      expect(empty.hasError, isTrue);
      expect(empty.primary, '请输入一个日期，或两个日期');

      final nonsense = _run('西红柿炒蛋');
      expect(nonsense.hasError, isTrue);
      expect(nonsense.primary, '读不出这是一个什么日期问题');
      expect(nonsense.detail, contains('例如'));
    });

    test('英文侧一个汉字都没有，日期本身原样出', () {
      // 中文：**日期是数据不是文案。** 英文界面上 `2026-09-20` 仍是 `2026-09-20`，
      //       换掉的只有我们自己的那几句。
      // English: **a date is data, not copy.** An English screen still reads `2026-09-20`; only our own
      //          sentences change.
      final han = RegExp(r'[一-鿿]');
      for (final input in <String>[
        '2026-01-01 到 2026-09-20',
        '2026-09-20',
        '2026-09-20 + 30',
        '今天 + 30',
        '不是日期',
        '',
      ]) {
        final out = _run(input, language: AppLanguage.en);
        for (final line in <String>[out.primary, out.detail, ...out.insights]) {
          expect(han.hasMatch(line), isFalse, reason: '英文侧还有汉字：`$line`');
        }
      }
      expect(_run('2026-09-20', language: AppLanguage.en).primary,
          'the day 2026-09-20');
    });

    test('两种语言给的是同一个答案，只是话说得不一样', () {
      final zh = _run('2026-01-01 到 2026-09-20');
      final en = _run('2026-01-01 到 2026-09-20', language: AppLanguage.en);
      expect(zh.primary, '262 天');
      expect(en.primary, '262 days');
      expect(zh.hasError, en.hasError);
      expect(zh.insights.length, en.insights.length);
    });
  });
}
