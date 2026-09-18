part of 'text_tool_controller.dart';

const Map<String, int> _monthNumbers = {
  'jan': 1,
  'january': 1,
  'feb': 2,
  'february': 2,
  'mar': 3,
  'march': 3,
  'apr': 4,
  'april': 4,
  'may': 5,
  'jun': 6,
  'june': 6,
  'jul': 7,
  'july': 7,
  'aug': 8,
  'august': 8,
  'sep': 9,
  'sept': 9,
  'september': 9,
  'oct': 10,
  'october': 10,
  'nov': 11,
  'november': 11,
  'dec': 12,
  'december': 12,
};

// 中文：**这一族的分界值得逐个点出来**，因为同一批汉字在这里既是文案又是判据：
//       - `纳秒` / `微秒` / `毫秒` 出现在 `_timestampMillisFromUnit` 的 `unit == '纳秒'` 里，
//         也出现在下面那条带单位的正则里——**两处都是判据，刻意不翻**；
//       - `现在` / `北京时间` / `中国标准时间` / `东八区` 比的是用户敲进来的说法，
//         以及 `(?:北京时间|中国标准时间|东八区)` 这条正则匹配的也是用户输入——**刻意不翻**；
//       - 其余（十来句识别说明、`JSON 字段` / `标签文本` 两个来源名、正文各行、相对时间量词、
//         星期名、三句错误）都是给人看的字，进了 `TextToolTimestampStrings`。
//       最容易被搞混的一对是 `$n 天` / `$n 小时`（量词，进表）与 `纳秒` / `微秒` / `毫秒`
//       （判据，不进表）：它们长得一样，身份不一样。
// English: **This family's boundary is worth spelling out item by item**, because the same
//          characters are copy in one place and a branch condition in another:
//          - `纳秒` / `微秒` / `毫秒` appear in `unit == '纳秒'` inside `_timestampMillisFromUnit` and
//            in the unit regular expression below — **both are conditions and both stay**;
//          - `现在` / `北京时间` / `中国标准时间` / `东八区` compare what the user typed, and the
//            `(?:北京时间|中国标准时间|东八区)` pattern matches user input too — **both stay**;
//          - everything else (a dozen recognition notes, the two provenance names `JSON 字段` /
//            `标签文本`, the detail lines, the relative-time measure words, the weekday names and
//            three errors) is for the reader and went into `TextToolTimestampStrings`.
//          The pair most easily confused is `$n 天` / `$n 小时` (measure words, in the table) versus
//          `纳秒` / `微秒` / `毫秒` (conditions, not in the table): they look alike, they are not the
//          same thing.
extension _TextToolTimestampTools on TextToolController {
  TextToolOutput _timestamp(TextToolTimestampStrings strings, String input) {
    final parsed = _parseTimestampInput(strings, input);
    final millis = parsed.millisecondsSinceEpoch;
    final local = DateTime.fromMillisecondsSinceEpoch(millis);
    final utc = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
    return TextToolOutput(
      local.toString(),
      [
        strings.localTime('$local'),
        'UTC: $utc',
        strings.isoLocal(local.toIso8601String()),
        'ISO UTC: ${utc.toIso8601String()}',
        strings.secondStamp('${(millis / 1000).round()}'),
        strings.millisecondStamp('$millis'),
        strings.weekdayLine(strings.weekday(local.weekday)),
        strings.dayOfYear(_dayOfYear(local)),
      ].join('\n'),
      insights: [
        parsed.description,
        strings.timeZoneOffset(
            '${local.timeZoneOffset.inHours >= 0 ? '+' : ''}${local.timeZoneOffset.inHours}'),
        _relativeTimeInsight(strings, local),
      ],
    );
  }

  _ParsedTimestamp _parseTimestampInput(
    TextToolTimestampStrings strings,
    String input,
  ) {
    final extracted = _extractTimestampInput(strings, input);
    final normalized = extracted.value;
    if (normalized.isEmpty) {
      throw FormatException(strings.emptyTimestampInput);
    }
    if (normalized.toLowerCase() == 'now' || normalized == '现在') {
      return _ParsedTimestamp(
        millisecondsSinceEpoch: DateTime.now().millisecondsSinceEpoch,
        description: _timestampDescription(strings, strings.now, extracted),
      );
    }
    final unitMatch = RegExp(
      r'^([+-]?\d+(?:\.\d+)?)\s*(ns|纳秒|us|µs|μs|微秒|ms|毫秒|s|sec|秒)$',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (unitMatch != null) {
      final value = double.parse(unitMatch.group(1)!);
      final unit = unitMatch.group(2)!.toLowerCase();
      final (millis, description) =
          _timestampMillisFromUnit(strings, value, unit);
      return _ParsedTimestamp(
        millisecondsSinceEpoch: millis,
        description: _timestampDescription(
          strings,
          description,
          extracted,
        ),
      );
    }
    final decimalSeconds = double.tryParse(normalized);
    if (decimalSeconds != null && normalized.contains('.')) {
      return _ParsedTimestamp(
        millisecondsSinceEpoch: (decimalSeconds * 1000).round(),
        description: _timestampDescription(
          strings,
          strings.fractionalSeconds,
          extracted,
        ),
      );
    }
    final numeric = int.tryParse(normalized);
    if (numeric != null) {
      final compact = _parseCompactTimestamp(strings, normalized);
      if (compact != null) {
        return _ParsedTimestamp(
          millisecondsSinceEpoch: compact.millisecondsSinceEpoch,
          description: _timestampDescription(
            strings,
            compact.description,
            extracted,
          ),
        );
      }
      final inferred = _timestampMillisFromNumeric(strings, normalized, numeric);
      return _ParsedTimestamp(
        millisecondsSinceEpoch: inferred.$1,
        description: _timestampDescription(strings, inferred.$2, extracted),
      );
    }
    final dateTime = _tryParseDateTimeText(normalized);
    if (dateTime != null) {
      return _ParsedTimestamp(
        millisecondsSinceEpoch: dateTime.toLocal().millisecondsSinceEpoch,
        description:
            _timestampDescription(strings, strings.dateTimeText, extracted),
      );
    }
    final common = RegExp(
      r'^(\d{4})[年/-](\d{1,2})[月/-](\d{1,2})(?:日)?(?:\s+(\d{1,2})(?:[时:：](\d{1,2})(?:[分:：](\d{1,2}))?)?(?:秒)?)?$',
    ).firstMatch(normalized);
    if (common != null) {
      int part(int index, [int fallback = 0]) =>
          int.tryParse(common.group(index) ?? '') ?? fallback;
      final value = DateTime(
        part(1),
        part(2, 1),
        part(3, 1),
        part(4),
        part(5),
        part(6),
      );
      return _ParsedTimestamp(
        millisecondsSinceEpoch: value.millisecondsSinceEpoch,
        description:
            _timestampDescription(strings, strings.localDateTime, extracted),
      );
    }
    throw FormatException(strings.needTimestampInput);
  }

  (int, String) _timestampMillisFromUnit(
    TextToolTimestampStrings strings,
    double value,
    String unit,
  ) {
    // 中文：`unit` 比的是**用户输入里的单位词**（`纳秒` / `微秒` / `毫秒` 三个中文词在这里是判据）。
    // English: `unit` is compared against **the unit word in the user's input** (`纳秒` / `微秒` /
    //          `毫秒` are branch conditions here).
    if (unit == 'ns' || unit == '纳秒') {
      return ((value / 1000000).round(), strings.unitNanos);
    }
    if (unit == 'us' || unit == 'µs' || unit == 'μs' || unit == '微秒') {
      return ((value / 1000).round(), strings.unitMicros);
    }
    if (unit == 'ms' || unit == '毫秒') {
      return (value.round(), strings.unitMillis);
    }
    return ((value * 1000).round(), strings.unitSeconds);
  }

  (int, String) _timestampMillisFromNumeric(
    TextToolTimestampStrings strings,
    String input,
    int value,
  ) {
    final digits = input.startsWith('-') || input.startsWith('+')
        ? input.substring(1)
        : input;
    final length = digits.length;
    final absValue = value.abs();
    if (length >= 19) {
      return ((value / 1000000).round(), strings.numericNanos);
    }
    if (length >= 16) {
      return ((value / 1000).round(), strings.numericMicros);
    }
    if (absValue > 9999999999) {
      return (value, strings.numericMillis);
    }
    return (value * 1000, strings.numericSeconds);
  }

  _TimestampInputCandidate _extractTimestampInput(
    TextToolTimestampStrings strings,
    String input,
  ) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return const _TimestampInputCandidate('');

    try {
      final decoded = json.decode(trimmed);
      final found = _findTimestampInJson(decoded);
      if (found != null) {
        return _TimestampInputCandidate(found, strings.sourceJsonField);
      }
    } catch (_) {
      // Not JSON; continue with plain text extraction.
    }

    final labeledRfc = RegExp(
      r'(?:timestamp|time|date|datetime|created_at|updated_at|expires_at|过期时间|时间|日期)\s*[:=]\s*["“”]?((?:mon|tue|wed|thu|fri|sat|sun)[a-z]*,\s*[^\n\r"”]+)',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (labeledRfc != null) {
      return _TimestampInputCandidate(
          labeledRfc.group(1)!.trim(), strings.sourceLabelText);
    }
    final labeled = RegExp(
      r'(?:timestamp|time|date|datetime|created_at|updated_at|expires_at|过期时间|时间|日期)\s*[:=]\s*["“”]?([^",，\n\r]+)',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (labeled != null) {
      return _TimestampInputCandidate(
          labeled.group(1)!.trim(), strings.sourceLabelText);
    }
    return _TimestampInputCandidate(trimmed);
  }

  String? _findTimestampInJson(Object? value) {
    const preferredKeys = {
      'timestamp',
      'time',
      'date',
      'datetime',
      'created_at',
      'updated_at',
      'expires_at',
      'exp',
      'iat',
      'nbf',
    };
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString().toLowerCase();
        if (!preferredKeys.contains(key)) continue;
        final candidate = entry.value;
        if (candidate is num || candidate is String) return '$candidate';
      }
      for (final child in value.values) {
        final found = _findTimestampInJson(child);
        if (found != null) return found;
      }
    } else if (value is List) {
      for (final child in value) {
        final found = _findTimestampInJson(child);
        if (found != null) return found;
      }
    }
    return null;
  }

  /// 中文：把识别说明与来源拼成整句。**拼法在表里**（`extractedFrom`）：中文是「$base 已从…」，
  ///       英文是「$base The time value was extracted from …」——断句与语序都不同。
  /// English: Joins the recognition note with its provenance. **The shape lives in the table**
  ///          (`extractedFrom`): Chinese reads `$base 已从…` and English reads `$base The time value
  ///          was extracted from …` — different punctuation and different word order.
  String _timestampDescription(
    TextToolTimestampStrings strings,
    String base,
    _TimestampInputCandidate extracted,
  ) {
    return extracted.source == null
        ? base
        : strings.extractedFrom(base, extracted.source!);
  }

  _ParsedTimestamp? _parseCompactTimestamp(
    TextToolTimestampStrings strings,
    String input,
  ) {
    final match = RegExp(
      r'^(\d{4})(\d{2})(\d{2})(?:(\d{2})(\d{2})(?:(\d{2}))?)?$',
    ).firstMatch(input);
    if (match == null) return null;

    int part(int index, [int fallback = 0]) =>
        int.tryParse(match.group(index) ?? '') ?? fallback;
    final value = DateTime(
      part(1),
      part(2),
      part(3),
      part(4),
      part(5),
      part(6),
    );
    if (value.year != part(1) ||
        value.month != part(2) ||
        value.day != part(3) ||
        value.hour != part(4) ||
        value.minute != part(5) ||
        value.second != part(6)) {
      throw FormatException(strings.compactInvalid);
    }
    return _ParsedTimestamp(
      millisecondsSinceEpoch: value.millisecondsSinceEpoch,
      description: strings.compactLocalDateTime,
    );
  }

  DateTime? _tryParseDateTimeText(String input) {
    for (final candidate in _dateTimeParseCandidates(input)) {
      final parsed = DateTime.tryParse(candidate);
      if (parsed != null) return parsed;
    }
    return _tryParseRfcLikeDateTimeText(input);
  }

  List<String> _dateTimeParseCandidates(String input) {
    final localized = _normalizeChineseTimeZoneLabel(input.trim());
    final normalized = localized.replaceFirstMapped(
        RegExp(r'\s+(?:UTC|GMT)([+-]\d{1,2})(?::?(\d{2}))?$',
            caseSensitive: false), (match) {
      final hour = int.parse(match.group(1)!);
      final minute = int.tryParse(match.group(2) ?? '0') ?? 0;
      final sign = hour < 0 ? '-' : '+';
      return '$sign${hour.abs().toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    });
    final namedUtc = normalized.replaceFirstMapped(
      RegExp(r'\s+(?:UTC|GMT|Z)$', caseSensitive: false),
      (_) => 'Z',
    );
    final spacedOffset = namedUtc.replaceFirstMapped(
      RegExp(r'\s+([+-]\d{2})(\d{2})$'),
      (match) => '${match.group(1)}:${match.group(2)}',
    );
    final compactOffset = namedUtc.replaceFirstMapped(
      RegExp(r'([T\s]\d{1,2}:\d{2}(?::\d{2}(?:\.\d+)?)?)([+-]\d{2})(\d{2})$'),
      (match) => '${match.group(1)}${match.group(2)}:${match.group(3)}',
    );
    return {
      input,
      input.replaceFirst(' ', 'T'),
      localized,
      localized.replaceFirst(' ', 'T'),
      normalized,
      normalized.replaceFirst(' ', 'T'),
      namedUtc,
      namedUtc.replaceFirst(' ', 'T'),
      spacedOffset,
      spacedOffset.replaceFirst(' ', 'T'),
      compactOffset,
      compactOffset.replaceFirst(' ', 'T'),
    }.toList();
  }

  String _normalizeChineseTimeZoneLabel(String input) {
    final label = RegExp(r'(?:北京时间|中国标准时间|东八区)');
    if (!label.hasMatch(input)) return input;
    final withoutLabel = input.replaceAll(label, '').trim();
    if (_hasExplicitTimeZoneSuffix(withoutLabel)) return withoutLabel;
    return '$withoutLabel +08:00';
  }

  bool _hasExplicitTimeZoneSuffix(String input) {
    return RegExp(
      r'(?:Z|UTC|GMT|[+-]\d{2}:?\d{2})$',
      caseSensitive: false,
    ).hasMatch(input.trim());
  }

  DateTime? _tryParseRfcLikeDateTimeText(String input) {
    final normalized = _normalizeChineseTimeZoneLabel(input)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .replaceFirst(
          RegExp(r'^(?:mon|tue|wed|thu|fri|sat|sun)[a-z]*,\s*',
              caseSensitive: false),
          '',
        );
    final match = RegExp(
      r'^(\d{1,2})\s+([a-z]{3,9})\s+(\d{4})(?:\s+(\d{1,2}):(\d{2})(?::(\d{2})(?:\.(\d{1,9}))?)?)?(?:\s+(.+))?$',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (match == null) return null;

    final day = int.tryParse(match.group(1)!);
    final month = _monthNumbers[match.group(2)!.toLowerCase()];
    final year = int.tryParse(match.group(3)!);
    if (day == null || month == null || year == null) return null;

    final hour = int.tryParse(match.group(4) ?? '0') ?? 0;
    final minute = int.tryParse(match.group(5) ?? '0') ?? 0;
    final second = int.tryParse(match.group(6) ?? '0') ?? 0;
    final micros = _parseFractionalSecondMicros(match.group(7));
    if (micros == null) return null;

    final zoneText = match.group(8)?.trim();
    final hasZone = zoneText != null && zoneText.isNotEmpty;
    final offset = _parseDateTimeZoneOffset(zoneText);
    if (hasZone && offset == null) return null;

    return _buildDateTime(
      year: year,
      month: month,
      day: day,
      hour: hour,
      minute: minute,
      second: second,
      millisecond: micros ~/ 1000,
      microsecond: micros % 1000,
      offset: offset,
    );
  }

  int? _parseFractionalSecondMicros(String? fraction) {
    if (fraction == null || fraction.isEmpty) return 0;
    final normalized = fraction.padRight(6, '0').substring(0, 6);
    return int.tryParse(normalized);
  }

  Duration? _parseDateTimeZoneOffset(String? zoneText) {
    if (zoneText == null || zoneText.trim().isEmpty) return null;
    final normalized = zoneText
        .trim()
        .replaceFirst(RegExp(r'\s*\(.+\)$'), '')
        .trim()
        .toUpperCase();
    if (normalized == 'Z' || normalized == 'UTC' || normalized == 'GMT') {
      return Duration.zero;
    }
    if (normalized == '北京时间' || normalized == '中国标准时间' || normalized == '东八区') {
      return const Duration(hours: 8);
    }
    final match = RegExp(r'^(?:UTC|GMT)?([+-]\d{1,2})(?::?(\d{2}))?$')
        .firstMatch(normalized);
    if (match == null) return null;
    final hour = int.parse(match.group(1)!);
    final minute = int.tryParse(match.group(2) ?? '0') ?? 0;
    if (hour.abs() > 23 || minute > 59) return null;
    final sign = hour < 0 ? -1 : 1;
    return Duration(hours: hour, minutes: sign * minute);
  }

  DateTime? _buildDateTime({
    required int year,
    required int month,
    required int day,
    required int hour,
    required int minute,
    required int second,
    required int millisecond,
    required int microsecond,
    required Duration? offset,
  }) {
    final base = offset == null
        ? DateTime(
            year, month, day, hour, minute, second, millisecond, microsecond)
        : DateTime.utc(
            year, month, day, hour, minute, second, millisecond, microsecond);
    if (base.year != year ||
        base.month != month ||
        base.day != day ||
        base.hour != hour ||
        base.minute != minute ||
        base.second != second ||
        base.millisecond != millisecond ||
        base.microsecond != microsecond) {
      return null;
    }
    return offset == null ? base : base.subtract(offset);
  }

  int _dayOfYear(DateTime value) {
    return value.difference(DateTime(value.year)).inDays + 1;
  }

  String _relativeTimeInsight(
    TextToolTimestampStrings strings,
    DateTime value,
  ) {
    final diff = value.difference(DateTime.now());
    final past = diff.isNegative;
    final abs = diff.abs();
    final amount = abs.inDays >= 1
        ? strings.durationDays(abs.inDays)
        : abs.inHours >= 1
            ? strings.durationHours(abs.inHours)
            : abs.inMinutes >= 1
                ? strings.durationMinutes(abs.inMinutes)
                : strings.durationSeconds(abs.inSeconds);
    return past
        ? strings.relativePast(amount)
        : strings.relativeFuture(amount);
  }
}
