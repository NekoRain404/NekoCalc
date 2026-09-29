import 'package:flutter/widgets.dart';

import '../../../l10n/app_language.dart';

/// 中文：**日期计算工具的文案表。** 与其余几张文本工具表同形（为什么手写分表、为什么
///       `static final` 而不是 `const`，见 `settings_strings.dart` 的文件头）。
///
///       表里**没有**日期本身的写法：`2026-09-20` 是**数据**，两种语言都原样出。
///       这与 `numeric_input_strings.dart` 里 `unitLabel`（用户打的字）是同一条判据。
/// English: **the date calculator's copy table.** Same shape as the other text-tool tables (why these are
///          hand-written rather than ARB, and why `static final` rather than `const`, is on
///          `settings_strings.dart`'s head).
///
///          The table holds **no date spellings**: `2026-09-20` is **data** and comes back verbatim in
///          both languages — the same ruling that keeps `unitLabel` (what the user typed) untranslated in
///          `numeric_input_strings.dart`.
@immutable
class TextToolDateStrings {
  const TextToolDateStrings({
    required this.emptyInput,
    required this.unrecognized,
    required this.invalidDate,
    required this.sameDay,
    required this.weekdayLabel,
    required this.dayOfYearLabel,
    required this.isoWeekLabel,
    required this.leapYearLabel,
    required this.yes,
    required this.no,
    required this.hint,
    required this.weekdayNames,
    required this.arrow,
    required this.readAsDate,
    required this.between,
    required this.shifted,
    required this.dayCount,
    required this.weekCount,
    required this.monthDayCount,
    required this.resultDate,
  });

  /// 中文：**空输入。** 与其余文本工具同一条判据（`inputIssueEmpty` 那一族）。
  /// English: **empty input**, the same ruling as the rest of the text tools.
  final String emptyInput;

  /// 中文：读不出「这是一个什么日期问题」。**这是一条如实的拒绝**，不是"再猜猜看"。
  /// English: cannot tell what date question this is. **An honest refusal**, not a "let me guess again".
  final String unrecognized;

  final String invalidDate;

  final String sameDay;
  final String weekdayLabel;
  final String dayOfYearLabel;
  final String isoWeekLabel;
  final String leapYearLabel;
  final String yes;
  final String no;
  final String hint;

  /// 中文：**星期几的七个名字，星期一到星期日。** 它按语言取，所以它在表里——而控制器那边
  ///       只做 `weekday - 1` 取下标（`DateTime.weekday` 就是 1=周一）。
  /// English: **the seven weekday names, Monday through Sunday.** Language-dependent, so they live here;
  ///          the controller only does `weekday - 1` (`DateTime.weekday` is 1 = Monday).
  final List<String> weekdayNames;

  final String Function(String from, String to) arrow;

  /// 中文：下面这几条是**带槽的句子**，槽里填的是**日期与天数**——它们都是数据，两种语言原样出。
  /// English: the entries below are **sentences with slots**, and the slots carry **dates and day
  ///          counts** — data, which comes back verbatim in both languages.
  final String Function(String date) readAsDate;
  final String Function(String from, String to) between;
  final String Function(String date, int days) shifted;
  final String Function(int days) dayCount;
  final String Function(int weeks, int days) weekCount;
  final String Function(int years, int months, int days) monthDayCount;
  final String Function(String date) resultDate;

  static TextToolDateStrings of(BuildContext context) =>
      forLanguage(AppLanguage.of(context));

  /// 中文：与 [of] 同一张分派表。**`switch` 穷尽 `AppLanguage`**——加一门语言这里编译不过。
  /// English: the same dispatch as [of]. The **`switch` exhausts `AppLanguage`**, so adding a language
  ///          breaks the build here.
  static TextToolDateStrings forLanguage(AppLanguage language) => switch (language) {
    AppLanguage.zh => textToolDateZh,
    AppLanguage.en => textToolDateEn,
  };

  static final TextToolDateStrings textToolDateZh = TextToolDateStrings(
    emptyInput: '请输入一个日期，或两个日期',
    unrecognized: '读不出这是一个什么日期问题',
    invalidDate: '这一天不在日历上',
    sameDay: '同一天',
    weekdayLabel: '星期',
    dayOfYearLabel: '年内第几天',
    isoWeekLabel: 'ISO 周',
    leapYearLabel: '闰年',
    yes: '是',
    no: '否',
    hint: '例如：2026-09-20 ／ 2026-01-01 到 2026-09-20 ／ 今天 + 30',
    weekdayNames: const ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'],
    arrow: (from, to) => '$from → $to',
    readAsDate: (date) => '$date 这一天',
    between: (from, to) => '$from 到 $to',
    shifted: (date, days) => '$date ${days >= 0 ? '+' : '−'} ${days.abs()} 天',
    dayCount: (days) => '$days 天',
    weekCount: (weeks, days) =>
        days == 0 ? '$weeks 周' : '$weeks 周 $days 天',
    monthDayCount: (years, months, days) =>
        '$years 年 $months 个月 $days 天',
    resultDate: (date) => date,
  );

  static final TextToolDateStrings textToolDateEn = TextToolDateStrings(
    emptyInput: 'Enter a date, or two dates',
    unrecognized: 'Cannot tell what date question this is',
    invalidDate: 'That day is not on the calendar',
    sameDay: 'the same day',
    weekdayLabel: 'Weekday',
    dayOfYearLabel: 'Day of year',
    isoWeekLabel: 'ISO week',
    leapYearLabel: 'Leap year',
    yes: 'yes',
    no: 'no',
    hint: 'For example: 2026-09-20 / 2026-01-01 to 2026-09-20 / today + 30',
    weekdayNames: const [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
    ],
    arrow: (from, to) => '$from → $to',
    readAsDate: (date) => 'the day $date',
    between: (from, to) => '$from to $to',
    shifted: (date, days) => '$date ${days >= 0 ? '+' : '−'} ${days.abs()} days',
    dayCount: (days) => '$days days',
    weekCount: (weeks, days) =>
        days == 0 ? '$weeks weeks' : '$weeks weeks $days days',
    monthDayCount: (years, months, days) =>
        '$years y $months m $days d',
    resultDate: (date) => date,
  );
}
