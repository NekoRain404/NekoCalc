import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/features/tools/presentation/text_tool_strings.dart';

/// 中文：时间戳那张表的第 1、2 条护栏——**逐条写出中文原文，再两侧比一遍**。
///       第 3 条（源码扫描）与两条屏幕用例在 `text_tool_strings_test.dart` 里，那一份带着扫描器，
///       这一份不需要再抄一遍：扫描器扫的是**文件**，而这里多出来的只是**表条目**。
///       文件头的完整理由见 `text_tool_strings.dart`。
///
///       **这一张最该盯紧的是"判据与文案长得一样"。** `现在` / `北京时间` /
///       `中国标准时间` / `东八区` / `纳秒` / `微秒` / `毫秒` 这七个词**不在这张表里**——
///       它们在控制器里比的是用户输入（`normalized == '现在'`、`unit == '毫秒'`），
///       是判据不是文案。`text_tool_strings_test.dart` 的豁免表把它们一条条点出来了。
///       容易看混的是量词那一组：表里的 `$n 天` / `$n 小时` / `$n 分钟` / `$n 秒`
///       与判据那三个词（`纳秒` / `微秒` / `毫秒`）**不是同一批字**——
///       量词进表，单位词留下，这条分界正是靠这个区别站住的。
/// English: Clauses 1 and 2 of the guard rails for the timestamp table — **every Chinese entry
///          written out, then both sides compared**. Clause 3 (the source scan) and the two screen
///          cases live in `text_tool_strings_test.dart`, which carries the scanner; this file does not
///          need a second copy of it, because the scanner scans **files** while what is new here is
///          only **table entries**. The full reasoning is on `text_tool_strings.dart`'s file head.
///
///          **The thing to watch hardest on this table is "a condition and copy look identical".**
///          The seven words `现在` / `北京时间` / `中国标准时间` / `东八区` / `纳秒` / `微秒` /
///          `毫秒` are **not in this table** — in the controller they are compared against what the
///          user typed (`normalized == '现在'`, `unit == '毫秒'`), which makes them conditions rather
///          than copy. The exemption table in `text_tool_strings_test.dart` names them one by one.
///          What appears here are the measure words 「天」/「小时」/「分钟」/「秒」, a **different
///          set of characters** from those three unit words — which is exactly why that boundary
///          holds.
void main() {
  final timestampZh = TextToolStrings.textToolZh.timestamp;
  final timestampEn = TextToolStrings.textToolEn.timestamp;

  test('时间戳中文表与迁移前源码里那些字逐字节相同', () {
    // —— 输入识别：哪一种时间 ——
    expect(timestampZh.now, '输入识别为当前时间。');
    expect(timestampZh.fractionalSeconds, '输入识别为小数秒时间戳。');
    expect(timestampZh.unitNanos, '输入识别为带单位的纳秒时间戳。');
    expect(timestampZh.unitMicros, '输入识别为带单位的微秒时间戳。');
    expect(timestampZh.unitMillis, '输入识别为带单位的毫秒时间戳。');
    expect(timestampZh.unitSeconds, '输入识别为带单位的秒级时间戳。');
    expect(timestampZh.numericNanos, '输入识别为纳秒级时间戳。');
    expect(timestampZh.numericMicros, '输入识别为微秒级时间戳。');
    expect(timestampZh.numericMillis, '输入识别为毫秒级时间戳。');
    expect(timestampZh.numericSeconds, '输入识别为秒级时间戳。');
    expect(timestampZh.dateTimeText, '输入识别为日期时间文本。');
    expect(timestampZh.localDateTime, '输入识别为本地日期时间。');
    expect(timestampZh.compactLocalDateTime, '输入识别为紧凑本地日期时间。');
    // —— 输入识别：值从哪儿来 ——
    expect(timestampZh.sourceJsonField, 'JSON 字段');
    expect(timestampZh.sourceLabelText, '标签文本');
    expect(timestampZh.extractedFrom('输入识别为毫秒级时间戳。', 'JSON 字段'),
        '输入识别为毫秒级时间戳。 已从JSON 字段中提取时间值。');
    // —— 正文各行 ——
    expect(timestampZh.localTime('2026-06-08 09:30:00.000'),
        '本地时间: 2026-06-08 09:30:00.000');
    expect(timestampZh.isoLocal('2026-06-08T09:30:00.000'),
        'ISO 本地: 2026-06-08T09:30:00.000');
    expect(timestampZh.secondStamp('1749375000'), '秒级时间戳: 1749375000');
    expect(timestampZh.millisecondStamp('1749375000000'), '毫秒时间戳: 1749375000000');
    expect(timestampZh.weekdayLine('一'), '星期: 一');
    expect(timestampZh.dayOfYear(159), '年内第 159 天');
    expect(timestampZh.timeZoneOffset('+8'), '时区偏移: +8 小时。');
    expect(timestampZh.weekday(1), '一');
    expect(timestampZh.weekday(7), '日');
    // —— 相对时间 ——
    expect(timestampZh.relativePast('3 天'), '相对当前时间: 约 3 天 前。');
    expect(timestampZh.relativeFuture('3 天'), '相对当前时间: 约 3 天 后。');
    expect(timestampZh.durationDays(3), '3 天');
    expect(timestampZh.durationHours(3), '3 小时');
    expect(timestampZh.durationMinutes(3), '3 分钟');
    expect(timestampZh.durationSeconds(3), '3 秒');
    // —— 错误 ——
    expect(timestampZh.emptyTimestampInput, '请输入时间戳、日期时间或 now');
    expect(timestampZh.needTimestampInput,
        '请输入时间戳、ISO 日期、yyyy-MM-dd HH:mm:ss 或 20260608093000');
    expect(timestampZh.compactInvalid, '紧凑日期时间无效。');
  });

  test('时间戳的英文侧都没有汉字、没有空串，而且真的换了', () {
    final pairs = <String, List<String>>{
      'now': [timestampZh.now, timestampEn.now],
      'fractionalSeconds': [
        timestampZh.fractionalSeconds,
        timestampEn.fractionalSeconds
      ],
      'unitNanos': [timestampZh.unitNanos, timestampEn.unitNanos],
      'unitMicros': [timestampZh.unitMicros, timestampEn.unitMicros],
      'unitMillis': [timestampZh.unitMillis, timestampEn.unitMillis],
      'unitSeconds': [timestampZh.unitSeconds, timestampEn.unitSeconds],
      'numericNanos': [timestampZh.numericNanos, timestampEn.numericNanos],
      'numericMicros': [timestampZh.numericMicros, timestampEn.numericMicros],
      'numericMillis': [timestampZh.numericMillis, timestampEn.numericMillis],
      'numericSeconds': [
        timestampZh.numericSeconds,
        timestampEn.numericSeconds
      ],
      'dateTimeText': [timestampZh.dateTimeText, timestampEn.dateTimeText],
      'localDateTime': [timestampZh.localDateTime, timestampEn.localDateTime],
      'compactLocalDateTime': [
        timestampZh.compactLocalDateTime,
        timestampEn.compactLocalDateTime
      ],
      'sourceJsonField': [
        timestampZh.sourceJsonField,
        timestampEn.sourceJsonField
      ],
      'sourceLabelText': [
        timestampZh.sourceLabelText,
        timestampEn.sourceLabelText
      ],
      'extractedFrom': [
        timestampZh.extractedFrom('A', 'B'),
        timestampEn.extractedFrom('A', 'B')
      ],
      'localTime': [timestampZh.localTime('X'), timestampEn.localTime('X')],
      'isoLocal': [timestampZh.isoLocal('X'), timestampEn.isoLocal('X')],
      'secondStamp': [
        timestampZh.secondStamp('X'),
        timestampEn.secondStamp('X')
      ],
      'millisecondStamp': [
        timestampZh.millisecondStamp('X'),
        timestampEn.millisecondStamp('X')
      ],
      'weekdayLine': [
        timestampZh.weekdayLine('X'),
        timestampEn.weekdayLine('X')
      ],
      'dayOfYear': [timestampZh.dayOfYear(159), timestampEn.dayOfYear(159)],
      'timeZoneOffset': [
        timestampZh.timeZoneOffset('+8'),
        timestampEn.timeZoneOffset('+8')
      ],
      'weekdayMonday': [timestampZh.weekday(1), timestampEn.weekday(1)],
      'weekdaySunday': [timestampZh.weekday(7), timestampEn.weekday(7)],
      'relativePast': [
        timestampZh.relativePast('X'),
        timestampEn.relativePast('X')
      ],
      'relativeFuture': [
        timestampZh.relativeFuture('X'),
        timestampEn.relativeFuture('X')
      ],
      'durationDays': [timestampZh.durationDays(3), timestampEn.durationDays(3)],
      'durationHours': [
        timestampZh.durationHours(3),
        timestampEn.durationHours(3)
      ],
      'durationMinutes': [
        timestampZh.durationMinutes(3),
        timestampEn.durationMinutes(3)
      ],
      'durationSeconds': [
        timestampZh.durationSeconds(3),
        timestampEn.durationSeconds(3)
      ],
      'emptyTimestampInput': [
        timestampZh.emptyTimestampInput,
        timestampEn.emptyTimestampInput
      ],
      'needTimestampInput': [
        timestampZh.needTimestampInput,
        timestampEn.needTimestampInput
      ],
      'compactInvalid': [timestampZh.compactInvalid, timestampEn.compactInvalid],
    };

    // 中文：**这一张没有"两侧相同"的条目。** 即使是最短的两条（`JSON 字段` / `标签文本`）
    //       在英文里也换成了 `a JSON field` / `labelled text`。
    // English: **Nothing in this table is identical on both sides.** Even the two shortest entries
    //          (`JSON 字段` / `标签文本`) become `a JSON field` / `labelled text` in English.
    for (final entry in pairs.entries) {
      expect(entry.value[0].trim(), isNotEmpty, reason: '${entry.key} 中文侧是空的');
      expect(entry.value[1].trim(), isNotEmpty, reason: '${entry.key} 英文侧是空的');
      expect(_containsCjk(entry.value[1]), isFalse,
          reason: '${entry.key} 英文侧还有汉字：${entry.value[1]}');
      expect(entry.value[0], isNot(entry.value[1]),
          reason: '「${entry.value[0]}」在英文表里没换');
    }
    // 中文：34 个键对应 33 个字段——`weekday` 被比了两次（周一与周日），因为它的中文侧是
    //       七个单字组成的数组，只抽一个看不出整组对不对。
    // English: 34 keys over 33 fields — `weekday` is compared twice (Monday and Sunday) because its
    //          Chinese side is an array of seven single characters and sampling one would not show
    //          whether the whole run is right.
    expect(pairs.length, 34,
        reason: '时间戳 33 个字段（识别说明 13 + 来源 2 + 拼句 1 + 正文 7 + 相对时间 6 + 错误 3 '
            '+ 星期名 1），加上 weekday 的第二次比对，漏一条这里就会少一条');
  });
}

/// 中文：CJK 统一表意文字区（含扩展 A）。够用了：本项目的界面文案都落在这里。
/// English: The CJK Unified Ideographs block (plus Extension A) — enough, since this project's UI
///          copy lives there.
bool _containsCjk(String text) {
  for (final rune in text.runes) {
    if ((rune >= 0x4E00 && rune <= 0x9FFF) ||
        (rune >= 0x3400 && rune <= 0x4DBF)) {
      return true;
    }
  }
  return false;
}
