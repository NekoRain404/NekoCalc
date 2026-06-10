part of 'text_tool_controller.dart';

const String _integerTokenPattern =
    r'[+\-]?(?:0x[0-9a-f][0-9a-f_,]*[ul]*|[#\$][0-9a-f][0-9a-f_,]*|[0-9a-f][0-9a-f_,]*h|0b[01][01_,]*[ul]*|[01][01_,]*b|0o[0-7][0-7_,]*[ul]*|[0-7][0-7_,]*o|[0-9][0-9_,]*(?:d|[ul]+)?)';

extension _TextToolIntegerTools on TextToolController {
  TextToolOutput _baseConvert(String input) {
    final parsed = _parseIntDetailed(input);
    final value = parsed.value;
    return TextToolOutput(
      value.toString(),
      '二进制: ${_formatIntegerBase(value, 2)}\n八进制: ${_formatIntegerBase(value, 8)}\n十进制: $value\n十六进制: ${_formatIntegerBase(value, 16)}',
      insights: [
        parsed.description,
        '有效位数: ${_integerBitLength(value)} bit。',
        if (value < 0) '负数按数学符号展示；位运算会使用整数补码语义。',
      ],
    );
  }

  TextToolOutput _bitwise(String input) {
    final values = _extractParsedIntegers(input);
    if (values.length < 2) {
      throw const FormatException('请输入两个整数，例如 12 5 或 A=0xF0 B=0b1010');
    }
    final aInput = values[0];
    final bInput = values[1];
    final a = aInput.value;
    final b = bInput.value;
    return TextToolOutput(
      'AND = ${a & b}',
      [
        'A: $a  hex:${_formatPrefixedIntegerBase(a, 16, '0x')}  bin:${_formatIntegerBase(a, 2)}',
        'B: $b  hex:${_formatPrefixedIntegerBase(b, 16, '0x')}  bin:${_formatIntegerBase(b, 2)}',
        'AND: ${a & b}',
        'OR: ${a | b}',
        'XOR: ${a ^ b}',
        'NOT A: ${~a}',
        'A << 1: ${a << 1}',
        'A >> 1: ${a >> 1}',
      ].join('\n'),
      insights: [
        'A 识别为${aInput.radixLabel}，B 识别为${bInput.radixLabel}。',
        'A 位数: ${_integerBitLength(a)} bit，B 位数: ${_integerBitLength(b)} bit。',
        if (values.length > 2) '检测到多个整数，已使用前两个。',
        if (a < 0 || b < 0) '负数位运算使用整数补码语义。',
      ],
    );
  }

  _ParsedInteger _parseIntDetailed(String input) {
    final source = _normalizeAsciiLike(input).trim();
    final constant = _parseIntegerConstant(source);
    if (constant != null) return constant;
    final token = _compactIntegerSource(source);
    var body = token;
    var sign = 1;
    if (body.startsWith('+') || body.startsWith('-')) {
      sign = body.startsWith('-') ? -1 : 1;
      body = body.substring(1);
    }
    if (body.isEmpty) throw const FormatException('请输入整数');

    final suffix = _stripIntegerTypeSuffix(body);
    body = suffix.$1;
    final suffixNotation = suffix.$2;

    var radix = 10;
    var radixLabel = '十进制';
    var notation = '数字';
    if (body.startsWith('0x')) {
      radix = 16;
      radixLabel = '十六进制';
      notation = '0x 前缀';
      body = body.substring(2);
    } else if (body.startsWith('#')) {
      radix = 16;
      radixLabel = '十六进制';
      notation = '# 前缀';
      body = body.substring(1);
    } else if (body.startsWith(r'$')) {
      radix = 16;
      radixLabel = '十六进制';
      notation = r'$ 前缀';
      body = body.substring(1);
    } else if (body.endsWith('h') && body.length > 1) {
      radix = 16;
      radixLabel = '十六进制';
      notation = 'h 后缀';
      body = body.substring(0, body.length - 1);
    } else if (body.startsWith('0b')) {
      radix = 2;
      radixLabel = '二进制';
      notation = '0b 前缀';
      body = body.substring(2);
    } else if (body.endsWith('b') &&
        body.length > 1 &&
        RegExp(r'^[01]+b$').hasMatch(body)) {
      radix = 2;
      radixLabel = '二进制';
      notation = 'b 后缀';
      body = body.substring(0, body.length - 1);
    } else if (body.startsWith('0o')) {
      radix = 8;
      radixLabel = '八进制';
      notation = '0o 前缀';
      body = body.substring(2);
    } else if (body.endsWith('o') &&
        body.length > 1 &&
        RegExp(r'^[0-7]+o$').hasMatch(body)) {
      radix = 8;
      radixLabel = '八进制';
      notation = 'o 后缀';
      body = body.substring(0, body.length - 1);
    } else if (body.endsWith('d') &&
        body.length > 1 &&
        RegExp(r'^[0-9]+d$').hasMatch(body)) {
      notation = 'd 后缀';
      body = body.substring(0, body.length - 1);
    }

    if (!_validIntegerDigits(body, radix)) {
      throw FormatException('整数格式无效: $input');
    }
    return _ParsedInteger(
      value: int.parse(body, radix: radix) * sign,
      radix: radix,
      radixLabel: radixLabel,
      notation: suffixNotation == null ? notation : '$notation，$suffixNotation',
      token: source,
    );
  }

  _ParsedInteger? _parseIntegerConstant(String source) {
    final normalized = source
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('::', '.')
        .toLowerCase();
    final constants = <String, int>{
      'integer.max_value': 2147483647,
      'integer.min_value': -2147483648,
      'int.max_value': 2147483647,
      'int.min_value': -2147483648,
      'int32.max_value': 2147483647,
      'int32.min_value': -2147483648,
      'long.max_value': 9223372036854775807,
      'long.min_value': -9223372036854775808,
      'int64.max_value': 9223372036854775807,
      'int64.min_value': -9223372036854775808,
      'number.max_safe_integer': 9007199254740991,
      'number.min_safe_integer': -9007199254740991,
    };
    final value = constants[normalized];
    if (value == null) return null;
    return _ParsedInteger(
      value: value,
      radix: 10,
      radixLabel: '十进制',
      notation: '编程语言常量',
      token: source,
    );
  }

  (String, String?) _stripIntegerTypeSuffix(String body) {
    final match = RegExp(r'^(.*?)(u?ll|llu|ul|lu|u|l)$', caseSensitive: false)
        .firstMatch(body);
    if (match == null) return (body, null);
    final stripped = match.group(1)!;
    if (stripped.isEmpty) return (body, null);
    return (stripped, '${match.group(2)!.toUpperCase()} 类型后缀');
  }

  _ParsedInteger? _tryParseIntDetailed(String input) {
    try {
      return _parseIntDetailed(input);
    } on FormatException {
      return null;
    }
  }

  List<_ParsedInteger> _extractParsedIntegers(String input) {
    final normalized = _normalizeAsciiLike(input);
    final labeled = _extractLabeledIntegers(normalized);
    if (labeled.containsKey('a') && labeled.containsKey('b')) {
      return [labeled['a']!, labeled['b']!];
    }

    final values = <_ParsedInteger>[];
    final tokenRegex = RegExp(
      '(?:^|[^A-Za-z0-9_#\\\$])($_integerTokenPattern)(?![A-Za-z0-9_.])',
      caseSensitive: false,
    );

    void collect(String source) {
      var segment = source.trim();
      if (segment.isEmpty) return;
      segment = segment.replaceFirst(
        RegExp(r'^[A-Za-z_][A-Za-z0-9_ -]*\s*[:=]\s*'),
        '',
      );
      if (segment.isEmpty) return;

      final parsed = _tryParseIntDetailed(segment);
      if (parsed != null) {
        values.add(parsed);
        return;
      }

      if (segment.contains(',')) {
        for (final part in segment.split(',')) {
          collect(part);
        }
        return;
      }

      for (final match in tokenRegex.allMatches(segment)) {
        final token = match.group(1);
        if (token == null) continue;
        final extracted = _tryParseIntDetailed(token);
        if (extracted != null) values.add(extracted);
      }
    }

    for (final segment in normalized.split(RegExp(r'[\s;；，]+'))) {
      collect(segment);
    }
    return values;
  }

  Map<String, _ParsedInteger> _extractLabeledIntegers(String input) {
    final result = <String, _ParsedInteger>{};
    final labelRegex = RegExp(
      '(?:^|[^A-Za-z0-9_])([ab])\\s*[:=]\\s*($_integerTokenPattern)(?![A-Za-z0-9_.])',
      caseSensitive: false,
    );
    for (final match in labelRegex.allMatches(input)) {
      final label = match.group(1)?.toLowerCase();
      final token = match.group(2)?.replaceFirst(RegExp(r'[,;]+$'), '');
      if (label == null || token == null || result.containsKey(label)) {
        continue;
      }
      final parsed = _tryParseIntDetailed(token);
      if (parsed != null) result[label] = parsed;
    }
    return result;
  }

  String _compactIntegerSource(String input) {
    final compact = input.replaceAll(RegExp(r'\s+'), '');
    if (compact.isEmpty) throw const FormatException('请输入整数');
    if (compact.contains(',') && !_integerCommasAreGrouped(compact)) {
      throw const FormatException('整数千位分隔符格式不正确');
    }
    return compact.replaceAll('_', '').replaceAll(',', '').toLowerCase();
  }

  bool _integerCommasAreGrouped(String input) {
    var body = input.replaceAll('_', '').toLowerCase();
    if (body.startsWith('+') || body.startsWith('-')) body = body.substring(1);
    if (body.endsWith('d') && body.length > 1) {
      body = body.substring(0, body.length - 1);
    }
    if (body.startsWith('0x') ||
        body.startsWith('0b') ||
        body.startsWith('0o') ||
        body.startsWith('#') ||
        body.startsWith(r'$') ||
        body.endsWith('h') ||
        body.endsWith('b') ||
        body.endsWith('o')) {
      return false;
    }
    return RegExp(r'^[0-9]{1,3}(,[0-9]{3})+$').hasMatch(body);
  }

  bool _validIntegerDigits(String input, int radix) {
    if (input.isEmpty) return false;
    return switch (radix) {
      2 => RegExp(r'^[01]+$').hasMatch(input),
      8 => RegExp(r'^[0-7]+$').hasMatch(input),
      10 => RegExp(r'^[0-9]+$').hasMatch(input),
      16 => RegExp(r'^[0-9a-f]+$').hasMatch(input),
      _ => false,
    };
  }

  int _integerBitLength(int value) {
    if (value == 0) return 1;
    return value.abs().toRadixString(2).length;
  }

  String _formatIntegerBase(int value, int radix) {
    final text = value.abs().toRadixString(radix);
    final normalized = radix == 16 ? text.toUpperCase() : text;
    return value < 0 ? '-$normalized' : normalized;
  }

  String _formatPrefixedIntegerBase(int value, int radix, String prefix) {
    final body = _formatIntegerBase(value.abs(), radix);
    return value < 0 ? '-$prefix$body' : '$prefix$body';
  }
}
