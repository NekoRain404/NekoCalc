import 'package:flutter/widgets.dart';

import '../../../l10n/app_language.dart';

/// 中文：时间戳工具的界面文案表。**为什么控制器要接表进来**与**哪些中文刻意不翻**，
///       两条理由都写在 `text_tool_strings.dart` 的文件头上，这里不重抄；
///       下面写的是这一族**独有**的分界。
///
///       **这一条链上每一层都在产出中文**，所以表要装的是整条链：`_parseTimestampInput`
///       辨认出"这是哪一种时间"（当前时间 / 小数秒 / 带单位 / 秒级 / 毫秒级 / 微秒级 / 纳秒级 /
///       日期时间文本 / 本地日期时间 / 紧凑本地日期时间），`_extractTimestampInput` 说明
///       "值是从哪儿抠出来的"（JSON 字段 / 标签文本），`_timestampDescription` 再把两者拼成
///       `输入识别为毫秒级时间戳。 已从JSON 字段中提取时间值。`。**拼法住在表里**：
///       中英文之间不只是换词，"已从…中提取时间值"那句的位置与断句都跟着变。
///
///       **时间单位的说法分两处，它们不是同一件事：**
///       - `纳秒` / `微秒` / `毫秒` 三个词在 `_timestampMillisFromUnit` 里是**判据**
///         （`unit == '纳秒'`），翻掉它们，用户敲 `100 毫秒` 就再也认不出来 —— **刻意不翻**。
///       - `_relativeTimeInsight` 里 `$n 天` / `$n 小时` / `$n 分钟` / `$n 秒` 是**给人看的
///         量词**，在表里。
///       同一批汉字在两个位置上是两种东西，这一条正是本轮最需要写清楚的分界。
///
///       **另外五条刻意不翻，全部是输入文法**（它们匹配的是用户可能敲进来的中文）：
///       - `r'^([+-]?\d+(?:\.\d+)?)\s*(ns|纳秒|us|µs|μs|微秒|ms|毫秒|s|sec|秒)$'`：带单位的时间戳；
///       - `r'^(\d{4})[年/-](\d{1,2})[月/-](\d{1,2})(?:日)?…$'`：`2026年6月8日 9:30`
///         这类中文日期写法；
///       - `(?:北京时间|中国标准时间|东八区)`：中文时区标签，先改写成 `+08:00` 再解析；
///       - 以及两条从 JSON / 带标签文本里抠时间值的 `(?:…|过期时间|时间|日期)\s*[:=]`。
///
///       **还有三条是与输入比较的判据**：`normalized == '现在'` 与
///       `normalized == '北京时间' || '中国标准时间' || '东八区'`——它们比的是**用户敲进来的说法**，
///       不是我们要显示的句子。判据与文案长得一样，是这一族最容易搞混的地方。
/// English: The copy table for the timestamp tool. **Why the controller takes a table as an
///          argument** is written on `text_tool_strings.dart`'s file head and not copied again here.
///
///          **Every layer of this chain produces Chinese**, so the table has to hold the whole chain:
///          `_parseTimestampInput` works out *which kind of time* this is (now / fractional seconds /
///          with a unit / seconds / milliseconds / microseconds / nanoseconds / date-and-time text /
///          local date and time / compact local date and time), `_extractTimestampInput` says *where
///          the value was dug out from* (a JSON field / labelled text), and `_timestampDescription`
///          joins the two into `Recognised a millisecond timestamp. The time value was extracted from
///          a JSON field.` **The way they are joined lives in the table**: between Chinese and
///          English it is not just the words that change but where that second sentence sits and how
///          it is punctuated.
///
///          **The time units are spelled in two places and they are not the same thing:**
///          - `纳秒` / `微秒` / `毫秒` in `_timestampMillisFromUnit` are **branch conditions**
///            (`unit == '纳秒'`); translate them and `100 毫秒` stops being understood —
///            **deliberately untranslated**.
///          - `$n 天` / `$n 小时` / `$n 分钟` / `$n 秒` in `_relativeTimeInsight` are **measure words
///            for the reader**, and they are in the table.
///          The same characters in two positions are two different things, and that boundary is the
///          one thing this round most needs to spell out.
///
///          **Five other things deliberately untranslated, all input grammar** (they match Chinese the
///          user may well type):
///          - `r'^([+-]?\d+(?:\.\d+)?)\s*(ns|纳秒|us|µs|μs|微秒|ms|毫秒|s|sec|秒)$'` — timestamps with
///            a unit;
///          - `r'^(\d{4})[年/-](\d{1,2})[月/-](\d{1,2})(?:日)?…$'` — Chinese date spellings such as
///            `2026年6月8日 9:30`;
///          - `(?:北京时间|中国标准时间|东八区)` — Chinese time-zone labels, rewritten to `+08:00`
///            before parsing;
///          - the two `(?:…|过期时间|时间|日期)\s*[:=]` patterns that dig a time value out of JSON or
///            labelled text.
///
///          **Three more are branch conditions compared against input**: `normalized == '现在'` and
///          `normalized == '北京时间' || '中国标准时间' || '东八区'` compare **what the user typed**,
///          not a sentence we are about to display. Conditions and copy looking identical is the one
///          thing this family gets wrong most easily.
@immutable
class TextToolTimestampStrings {
  const TextToolTimestampStrings({
    // —— 输入识别：哪一种时间 ——
    required this.now,
    required this.fractionalSeconds,
    required this.unitNanos,
    required this.unitMicros,
    required this.unitMillis,
    required this.unitSeconds,
    required this.numericNanos,
    required this.numericMicros,
    required this.numericMillis,
    required this.numericSeconds,
    required this.dateTimeText,
    required this.localDateTime,
    required this.compactLocalDateTime,
    // —— 输入识别：值从哪儿来 ——
    required this.sourceJsonField,
    required this.sourceLabelText,
    required this.extractedFrom,
    // —— 正文各行 ——
    required this.localTime,
    required this.isoLocal,
    required this.secondStamp,
    required this.millisecondStamp,
    required this.weekdayLine,
    required this.dayOfYear,
    required this.timeZoneOffset,
    required this.weekday,
    // —— 相对时间 ——
    required this.relativePast,
    required this.relativeFuture,
    required this.durationDays,
    required this.durationHours,
    required this.durationMinutes,
    required this.durationSeconds,
    // —— 错误 ——
    required this.emptyTimestampInput,
    required this.needTimestampInput,
    required this.compactInvalid,
  });

  // —— 输入识别：哪一种时间 ——
  final String now;
  final String fractionalSeconds;
  final String unitNanos;
  final String unitMicros;
  final String unitMillis;
  final String unitSeconds;
  final String numericNanos;
  final String numericMicros;
  final String numericMillis;
  final String numericSeconds;
  final String dateTimeText;
  final String localDateTime;
  final String compactLocalDateTime;

  // —— 输入识别：值从哪儿来 ——
  /// 中文：值是从 JSON 字段里抠出来的。它会被插进 [extractedFrom]，所以它在英文里是
  ///       `a JSON field`——**带冠词的短语，不是句子**，冠词归表管。
  /// English: The value was dug out of a JSON field. It is interpolated into [extractedFrom], so in
  ///          English it reads `a JSON field` — **a phrase with its article, not a sentence**; the
  ///          article belongs to the table.
  final String sourceJsonField;
  final String sourceLabelText;

  /// 中文：把识别说明与来源拼成整句。**注意中文这一侧 `$base` 后面直接接句号再空一格**，
  ///       与迁移前逐字节相同。
  /// English: Joins the recognition note and the provenance into one sentence. **Note that on the
  ///          Chinese side `$base` is followed straight away by its full stop and a space**,
  ///          byte-identical to the source before translation.
  final String Function(String base, String source) extractedFrom;

  // —— 正文各行 ——
  final String Function(String value) localTime;
  final String Function(String value) isoLocal;
  final String Function(String value) secondStamp;
  final String Function(String value) millisecondStamp;
  final String Function(String weekday) weekdayLine;
  final String Function(int day) dayOfYear;

  /// 中文：`$hours` 是**带符号**的（`+8` / `-5`），签号由调用方拼好再进来。
  /// English: `$hours` arrives **already signed** (`+8` / `-5`); the caller builds the sign.
  final String Function(String hours) timeZoneOffset;

  /// 中文：星期几。位置与 `DateTime.weekday` 对齐（1 = 周一 … 7 = 周日），判断住在控制器里。
  /// English: The weekday name, aligned with `DateTime.weekday` (1 = Monday … 7 = Sunday); the
  ///          indexing stays in the controller.
  final String Function(int weekday) weekday;

  // —— 相对时间 ——
  final String Function(String amount) relativePast;
  final String Function(String amount) relativeFuture;
  final String Function(int count) durationDays;
  final String Function(int count) durationHours;
  final String Function(int count) durationMinutes;
  final String Function(int count) durationSeconds;

  // —— 错误 ——
  final String emptyTimestampInput;
  final String needTimestampInput;
  final String compactInvalid;

  static TextToolTimestampStrings of(BuildContext context) {
    return forLanguage(AppLanguage.of(context));
  }

  static TextToolTimestampStrings forLanguage(AppLanguage language) {
    return switch (language) {
      AppLanguage.zh => timestampZh,
      AppLanguage.en => timestampEn,
    };
  }

  static final TextToolTimestampStrings timestampZh = TextToolTimestampStrings(
    now: '输入识别为当前时间。',
    fractionalSeconds: '输入识别为小数秒时间戳。',
    unitNanos: '输入识别为带单位的纳秒时间戳。',
    unitMicros: '输入识别为带单位的微秒时间戳。',
    unitMillis: '输入识别为带单位的毫秒时间戳。',
    unitSeconds: '输入识别为带单位的秒级时间戳。',
    numericNanos: '输入识别为纳秒级时间戳。',
    numericMicros: '输入识别为微秒级时间戳。',
    numericMillis: '输入识别为毫秒级时间戳。',
    numericSeconds: '输入识别为秒级时间戳。',
    dateTimeText: '输入识别为日期时间文本。',
    localDateTime: '输入识别为本地日期时间。',
    compactLocalDateTime: '输入识别为紧凑本地日期时间。',
    sourceJsonField: 'JSON 字段',
    sourceLabelText: '标签文本',
    extractedFrom: (base, source) => '$base 已从$source中提取时间值。',
    localTime: (value) => '本地时间: $value',
    isoLocal: (value) => 'ISO 本地: $value',
    secondStamp: (value) => '秒级时间戳: $value',
    millisecondStamp: (value) => '毫秒时间戳: $value',
    weekdayLine: (weekday) => '星期: $weekday',
    dayOfYear: (day) => '年内第 $day 天',
    timeZoneOffset: (hours) => '时区偏移: $hours 小时。',
    weekday: (weekday) =>
        const ['一', '二', '三', '四', '五', '六', '日'][weekday - 1],
    relativePast: (amount) => '相对当前时间: 约 $amount 前。',
    relativeFuture: (amount) => '相对当前时间: 约 $amount 后。',
    durationDays: (count) => '$count 天',
    durationHours: (count) => '$count 小时',
    durationMinutes: (count) => '$count 分钟',
    durationSeconds: (count) => '$count 秒',
    emptyTimestampInput: '请输入时间戳、日期时间或 now',
    needTimestampInput:
        '请输入时间戳、ISO 日期、yyyy-MM-dd HH:mm:ss 或 20260608093000',
    compactInvalid: '紧凑日期时间无效。',
  );

  static final TextToolTimestampStrings timestampEn = TextToolTimestampStrings(
    now: 'Recognised the current time.',
    fractionalSeconds: 'Recognised a fractional-second timestamp.',
    unitNanos: 'Recognised a nanosecond timestamp with a unit.',
    unitMicros: 'Recognised a microsecond timestamp with a unit.',
    unitMillis: 'Recognised a millisecond timestamp with a unit.',
    unitSeconds: 'Recognised a second-resolution timestamp with a unit.',
    numericNanos: 'Recognised a nanosecond timestamp.',
    numericMicros: 'Recognised a microsecond timestamp.',
    numericMillis: 'Recognised a millisecond timestamp.',
    numericSeconds: 'Recognised a second-resolution timestamp.',
    dateTimeText: 'Recognised date-and-time text.',
    localDateTime: 'Recognised a local date and time.',
    compactLocalDateTime: 'Recognised a compact local date and time.',
    sourceJsonField: 'a JSON field',
    sourceLabelText: 'labelled text',
    extractedFrom: (base, source) => '$base The time value was extracted from $source.',
    localTime: (value) => 'Local time: $value',
    isoLocal: (value) => 'ISO local: $value',
    secondStamp: (value) => 'Second-resolution timestamp: $value',
    millisecondStamp: (value) => 'Millisecond timestamp: $value',
    weekdayLine: (weekday) => 'Weekday: $weekday',
    dayOfYear: (day) => 'Day $day of the year',
    timeZoneOffset: (hours) => 'Time zone offset: $hours hours.',
    weekday: (weekday) =>
        const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday - 1],
    relativePast: (amount) => 'Relative to now: about $amount ago.',
    relativeFuture: (amount) => 'Relative to now: in about $amount.',
    durationDays: (count) => '$count days',
    durationHours: (count) => '$count hours',
    durationMinutes: (count) => '$count minutes',
    durationSeconds: (count) => '$count seconds',
    emptyTimestampInput: 'Enter a timestamp, a date and time, or now',
    needTimestampInput:
        'Enter a timestamp, an ISO date, yyyy-MM-dd HH:mm:ss or 20260608093000',
    compactInvalid: 'The compact date and time is not valid.',
  );
}
