part of 'text_tool_controller.dart';

const String _integerTokenPattern =
    r'[+\-]?(?:0x[0-9a-f][0-9a-f_,]*[ul]*|[#\$][0-9a-f][0-9a-f_,]*|[0-9a-f][0-9a-f_,]*h|0b[01][01_,]*[ul]*|[01][01_,]*b|0o[0-7][0-7_,]*[ul]*|[0-7][0-7_,]*o|[0-9][0-9_,]*(?:d|[ul]+)?)';

// 中文：**这一组没有一条中文字面量是判据。** `_integerTokenPattern` 上面那条正则才是判据
//       （十六进制字面量怎么算一个 token），它是纯 ASCII；`radixLabel` 与 `notation`
//       只被插进 `_ParsedInteger.description`，反向不参与任何分支。这一点与时间戳那一组
//       正好相反——那边 `unit == '纳秒'` 是判据，所以那三个词留在原地。
// English: **Not one Chinese literal in this group is a branch condition.** The condition is the
//          `_integerTokenPattern` regular expression above (what counts as one hexadecimal token)
//          and it is pure ASCII; `radixLabel` and `notation` are only interpolated into
//          `_ParsedInteger.description` and never branch on the way back. That is the exact opposite
//          of the timestamp group, where `unit == '纳秒'` is a condition and so those three words
//          stay where they are.
extension _TextToolIntegerTools on TextToolController {
  TextToolOutput _baseConvert(TextToolCodecStrings strings, String input) {
    final parsed = _parseIntDetailed(strings, input);
    final value = parsed.value;
    return TextToolOutput(
      value.toString(),
      strings.baseLines(
        _formatIntegerBase(value, 2),
        _formatIntegerBase(value, 8),
        value.toString(),
        _formatIntegerBase(value, 16),
      ),
      insights: [
        parsed.description(strings),
        strings.significantBits(_integerBitLength(value)),
        if (value < 0) strings.negativeShownAsSigned,
      ],
    );
  }

  TextToolOutput _bitwise(TextToolCodecStrings strings, String input) {
    final values = _extractParsedIntegers(strings, input);
    if (values.length < 2) {
      throw FormatException(strings.twoIntegersNeeded);
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
        strings.recognisedAB(aInput.radixLabel, bInput.radixLabel),
        strings.bitLengthAB(_integerBitLength(a), _integerBitLength(b)),
        if (values.length > 2) strings.extraIntegersIgnored,
        if (a < 0 || b < 0) strings.negativeBitwiseTwosComplement,
      ],
    );
  }

  _ParsedInteger _parseIntDetailed(TextToolCodecStrings strings, String input) {
    final source = _normalizeAsciiLike(input).trim();
    final constant = _parseIntegerConstant(strings, source);
    if (constant != null) return constant;
    final token = _compactIntegerSource(strings, source);
    var body = token;
    var sign = 1;
    if (body.startsWith('+') || body.startsWith('-')) {
      sign = body.startsWith('-') ? -1 : 1;
      body = body.substring(1);
    }
    if (body.isEmpty) throw FormatException(strings.integerNeeded);

    final suffix = _stripIntegerTypeSuffix(strings, body);
    body = suffix.$1;
    final suffixNotation = suffix.$2;

    var radix = 10;
    var radixLabel = strings.radixDecimal;
    var notation = strings.notationPlainDigits;
    if (body.startsWith('0x')) {
      radix = 16;
      radixLabel = strings.radixHexadecimal;
      notation = strings.notationHexPrefix0x;
      body = body.substring(2);
    } else if (body.startsWith('#')) {
      radix = 16;
      radixLabel = strings.radixHexadecimal;
      notation = strings.notationHexPrefixHash;
      body = body.substring(1);
    } else if (body.startsWith(r'$')) {
      radix = 16;
      radixLabel = strings.radixHexadecimal;
      notation = strings.notationHexPrefixDollar;
      body = body.substring(1);
    } else if (body.endsWith('h') && body.length > 1) {
      radix = 16;
      radixLabel = strings.radixHexadecimal;
      notation = strings.notationHexSuffixH;
      body = body.substring(0, body.length - 1);
    } else if (body.startsWith('0b')) {
      radix = 2;
      radixLabel = strings.radixBinary;
      notation = strings.notationBinaryPrefix0b;
      body = body.substring(2);
    } else if (body.endsWith('b') &&
        body.length > 1 &&
        RegExp(r'^[01]+b$').hasMatch(body)) {
      radix = 2;
      radixLabel = strings.radixBinary;
      notation = strings.notationBinarySuffixB;
      body = body.substring(0, body.length - 1);
    } else if (body.startsWith('0o')) {
      radix = 8;
      radixLabel = strings.radixOctal;
      notation = strings.notationOctalPrefix0o;
      body = body.substring(2);
    } else if (body.endsWith('o') &&
        body.length > 1 &&
        RegExp(r'^[0-7]+o$').hasMatch(body)) {
      radix = 8;
      radixLabel = strings.radixOctal;
      notation = strings.notationOctalSuffixO;
      body = body.substring(0, body.length - 1);
    } else if (body.endsWith('d') &&
        body.length > 1 &&
        RegExp(r'^[0-9]+d$').hasMatch(body)) {
      notation = strings.notationDecimalSuffixD;
      body = body.substring(0, body.length - 1);
    }

    if (!_validIntegerDigits(body, radix)) {
      throw FormatException(strings.invalidIntegerFormat(input));
    }
    return _ParsedInteger(
      value: int.parse(body, radix: radix) * sign,
      radix: radix,
      radixLabel: radixLabel,
      notation: suffixNotation == null
          ? notation
          : strings.notationWithSuffix(notation, suffixNotation),
      token: source,
    );
  }

  _ParsedInteger? _parseIntegerConstant(
    TextToolCodecStrings strings,
    String source,
  ) {
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
      radixLabel: strings.radixDecimal,
      notation: strings.notationProgrammingConstant,
      token: source,
    );
  }

  (String, String?) _stripIntegerTypeSuffix(
    TextToolCodecStrings strings,
    String body,
  ) {
    final match = RegExp(r'^(.*?)(u?ll|llu|ul|lu|u|l)$', caseSensitive: false)
        .firstMatch(body);
    if (match == null) return (body, null);
    final stripped = match.group(1)!;
    if (stripped.isEmpty) return (body, null);
    return (stripped, strings.typeSuffix(match.group(2)!.toUpperCase()));
  }

  _ParsedInteger? _tryParseIntDetailed(
    TextToolCodecStrings strings,
    String input,
  ) {
    try {
      return _parseIntDetailed(strings, input);
    } on FormatException {
      return null;
    }
  }

  List<_ParsedInteger> _extractParsedIntegers(
    TextToolCodecStrings strings,
    String input,
  ) {
    final normalized = _normalizeAsciiLike(input);
    final labeled = _extractLabeledIntegers(strings, normalized);
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

      final parsed = _tryParseIntDetailed(strings, segment);
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
        final extracted = _tryParseIntDetailed(strings, token);
        if (extracted != null) values.add(extracted);
      }
    }

    for (final segment in normalized.split(RegExp(r'[\s;；，]+'))) {
      collect(segment);
    }
    return values;
  }

  Map<String, _ParsedInteger> _extractLabeledIntegers(
    TextToolCodecStrings strings,
    String input,
  ) {
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
      final parsed = _tryParseIntDetailed(strings, token);
      if (parsed != null) result[label] = parsed;
    }
    return result;
  }

  String _compactIntegerSource(TextToolCodecStrings strings, String input) {
    final compact = input.replaceAll(RegExp(r'\s+'), '');
    if (compact.isEmpty) throw FormatException(strings.integerNeeded);
    if (compact.contains(',') && !_integerCommasAreGrouped(compact)) {
      throw FormatException(strings.invalidThousandsSeparator);
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
