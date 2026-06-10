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

extension _TextToolTimestampTools on TextToolController {
  TextToolOutput _timestamp(String input) {
    final parsed = _parseTimestampInput(input);
    final millis = parsed.millisecondsSinceEpoch;
    final local = DateTime.fromMillisecondsSinceEpoch(millis);
    final utc = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
    return TextToolOutput(
      local.toString(),
      [
        '本地时间: $local',
        'UTC: $utc',
        'ISO 本地: ${local.toIso8601String()}',
        'ISO UTC: ${utc.toIso8601String()}',
        '秒级时间戳: ${(millis / 1000).round()}',
        '毫秒时间戳: $millis',
        '星期: ${_weekdayLabel(local.weekday)}',
        '年内第 ${_dayOfYear(local)} 天',
      ].join('\n'),
      insights: [
        parsed.description,
        '时区偏移: ${local.timeZoneOffset.inHours >= 0 ? '+' : ''}${local.timeZoneOffset.inHours} 小时。',
        _relativeTimeInsight(local),
      ],
    );
  }

  _ParsedTimestamp _parseTimestampInput(String input) {
    final extracted = _extractTimestampInput(input);
    final normalized = extracted.value;
    if (normalized.isEmpty) {
      throw const FormatException('请输入时间戳、日期时间或 now');
    }
    if (normalized.toLowerCase() == 'now' || normalized == '现在') {
      return _ParsedTimestamp(
        millisecondsSinceEpoch: DateTime.now().millisecondsSinceEpoch,
        description: _timestampDescription('输入识别为当前时间。', extracted),
      );
    }
    final unitMatch = RegExp(
      r'^([+-]?\d+(?:\.\d+)?)\s*(ns|纳秒|us|µs|μs|微秒|ms|毫秒|s|sec|秒)$',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (unitMatch != null) {
      final value = double.parse(unitMatch.group(1)!);
      final unit = unitMatch.group(2)!.toLowerCase();
      final (millis, description) = _timestampMillisFromUnit(value, unit);
      return _ParsedTimestamp(
        millisecondsSinceEpoch: millis,
        description: _timestampDescription(
          description,
          extracted,
        ),
      );
    }
    final decimalSeconds = double.tryParse(normalized);
    if (decimalSeconds != null && normalized.contains('.')) {
      return _ParsedTimestamp(
        millisecondsSinceEpoch: (decimalSeconds * 1000).round(),
        description: _timestampDescription('输入识别为小数秒时间戳。', extracted),
      );
    }
    final numeric = int.tryParse(normalized);
    if (numeric != null) {
      final compact = _parseCompactTimestamp(normalized);
      if (compact != null) {
        return _ParsedTimestamp(
          millisecondsSinceEpoch: compact.millisecondsSinceEpoch,
          description: _timestampDescription(compact.description, extracted),
        );
      }
      final inferred = _timestampMillisFromNumeric(normalized, numeric);
      return _ParsedTimestamp(
        millisecondsSinceEpoch: inferred.$1,
        description: _timestampDescription(inferred.$2, extracted),
      );
    }
    final dateTime = _tryParseDateTimeText(normalized);
    if (dateTime != null) {
      return _ParsedTimestamp(
        millisecondsSinceEpoch: dateTime.toLocal().millisecondsSinceEpoch,
        description: _timestampDescription('输入识别为日期时间文本。', extracted),
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
        description: _timestampDescription('输入识别为本地日期时间。', extracted),
      );
    }
    throw const FormatException(
      '请输入时间戳、ISO 日期、yyyy-MM-dd HH:mm:ss 或 20260608093000',
    );
  }

  (int, String) _timestampMillisFromUnit(double value, String unit) {
    if (unit == 'ns' || unit == '纳秒') {
      return ((value / 1000000).round(), '输入识别为带单位的纳秒时间戳。');
    }
    if (unit == 'us' || unit == 'µs' || unit == 'μs' || unit == '微秒') {
      return ((value / 1000).round(), '输入识别为带单位的微秒时间戳。');
    }
    if (unit == 'ms' || unit == '毫秒') {
      return (value.round(), '输入识别为带单位的毫秒时间戳。');
    }
    return ((value * 1000).round(), '输入识别为带单位的秒级时间戳。');
  }

  (int, String) _timestampMillisFromNumeric(String input, int value) {
    final digits = input.startsWith('-') || input.startsWith('+')
        ? input.substring(1)
        : input;
    final length = digits.length;
    final absValue = value.abs();
    if (length >= 19) {
      return ((value / 1000000).round(), '输入识别为纳秒级时间戳。');
    }
    if (length >= 16) {
      return ((value / 1000).round(), '输入识别为微秒级时间戳。');
    }
    if (absValue > 9999999999) {
      return (value, '输入识别为毫秒级时间戳。');
    }
    return (value * 1000, '输入识别为秒级时间戳。');
  }

  _TimestampInputCandidate _extractTimestampInput(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return const _TimestampInputCandidate('');

    try {
      final decoded = json.decode(trimmed);
      final found = _findTimestampInJson(decoded);
      if (found != null) return _TimestampInputCandidate(found, 'JSON 字段');
    } catch (_) {
      // Not JSON; continue with plain text extraction.
    }

    final labeledRfc = RegExp(
      r'(?:timestamp|time|date|datetime|created_at|updated_at|expires_at|过期时间|时间|日期)\s*[:=]\s*["“”]?((?:mon|tue|wed|thu|fri|sat|sun)[a-z]*,\s*[^\n\r"”]+)',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (labeledRfc != null) {
      return _TimestampInputCandidate(labeledRfc.group(1)!.trim(), '标签文本');
    }
    final labeled = RegExp(
      r'(?:timestamp|time|date|datetime|created_at|updated_at|expires_at|过期时间|时间|日期)\s*[:=]\s*["“”]?([^",，\n\r]+)',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (labeled != null) {
      return _TimestampInputCandidate(labeled.group(1)!.trim(), '标签文本');
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

  String _timestampDescription(
    String base,
    _TimestampInputCandidate extracted,
  ) {
    return extracted.source == null
        ? base
        : '$base 已从${extracted.source}中提取时间值。';
  }

  _ParsedTimestamp? _parseCompactTimestamp(String input) {
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
      throw const FormatException('紧凑日期时间无效。');
    }
    return _ParsedTimestamp(
      millisecondsSinceEpoch: value.millisecondsSinceEpoch,
      description: '输入识别为紧凑本地日期时间。',
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

  String _weekdayLabel(int weekday) {
    return const ['一', '二', '三', '四', '五', '六', '日'][weekday - 1];
  }

  int _dayOfYear(DateTime value) {
    return value.difference(DateTime(value.year)).inDays + 1;
  }

  String _relativeTimeInsight(DateTime value) {
    final diff = value.difference(DateTime.now());
    final past = diff.isNegative;
    final abs = diff.abs();
    final amount = abs.inDays >= 1
        ? '${abs.inDays} 天'
        : abs.inHours >= 1
            ? '${abs.inHours} 小时'
            : abs.inMinutes >= 1
                ? '${abs.inMinutes} 分钟'
                : '${abs.inSeconds} 秒';
    return past ? '相对当前时间: 约 $amount 前。' : '相对当前时间: 约 $amount 后。';
  }
}
