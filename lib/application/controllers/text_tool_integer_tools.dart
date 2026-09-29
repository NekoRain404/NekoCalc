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
    // 中文：**`base <n>` 是"任意进制"的入口**，而它是这一轮新加的——在此之前这个工具只会印
    //       二/八/十/十六四种。写法沿用应用自己的那个词（`base`），与 `romand` 那一行同一个位置。
    //
    //       ⚠️ **越界要如实拒绝，不许回退成别的进制**：`base 37` 若被当成 `base 16` 印出来，
    //       用户拿到的是一个看着像答案的错值。判据与 `convertToBase` 那一处是同一条（`2..36`），
    //       这里只是把话说出来。
    // English: **`base <n>` is the entry for "any base"**, added this round — before it this tool only
    //          printed binary/octal/decimal/hex. The spelling follows the app's own word (`base`) and
    //          sits in the same place as the Roman line.
    //
    //          ⚠️ **Out of range must be refused, never rounded into another base**: if `base 37` were
    //          printed as base 16 the user would get a wrong value that looks like an answer. The
    //          judgement is the same one as in `convertToBase` (`2..36`); this only says it out loud.
    final target = _extractTargetRadix(input);
    if (target != null && (target.$1 < 2 || target.$1 > 36)) {
      throw FormatException(strings.arbitraryBaseOutOfRange);
    }
    final parsed = _parseIntDetailed(strings, target?.$2 ?? input);
    final value = parsed.value;
    return TextToolOutput(
      value.toString(),
      strings.baseLines(
        _formatIntegerBase(value, 2),
        _formatIntegerBase(value, 8),
        value.toString(),
        _formatIntegerBase(value, 16),
        // 中文：**罗马数字走自己那一份纯函数，不走引擎。** 引擎的 `roman()` 在边界上会给出
        //       看着像答案的错值（`roman(10000)` 把输入原样还回来、`roman(-1)` 回 `"-I"`），
        //       见 `roman_numeral.dart` 的文件头。`1..3999` 之外回 `null`，这里照常印一句话。
        // English: **Roman numerals use our own pure function, not the engine.** The engine's `roman()`
        //          yields plausible-looking wrong values at the boundaries (`roman(10000)` hands the input
        //          back, `roman(-1)` gives `"-I"`); see `roman_numeral.dart`'s head. Outside `1..3999` it
        //          returns `null` and a sentence is printed as usual.
        toRoman(value),
        // 中文：**用户点名要的那个进制**（输入里写了 `base <n>` 才有）。换算是纯函数，
        //       见 `base_conversion.dart`——那里也是 `2..36` 这条判据的出处。
        // English: **the base the user named** (present only when the input says `base <n>`). The
        //          conversion is a pure function, see `base_conversion.dart` — which is also where the
        //          `2..36` judgement comes from.
        target == null
            ? null
            : strings.arbitraryBaseLine(
                target.$1,
                convertToBase(value.toString(), target.$1)!.digits,
              ),
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

/// 中文：**从输入里摘下 `base <n>`**，返回 `(目标进制, 摘掉之后剩下的输入)`；没有就回 `null`。
///
///       只认这一个写法，而且**只认一次**：`255 base 7` 与 `0xFF base 16` 都要能用。
///       大小写不敏感（`BASE 7` 也收），与这个工具已有的那些前缀/后缀同一条宽松度。
/// English: **lift `base <n>` out of the input**, returning `(target radix, the rest)`; `null` when
///          absent.
///
///          One spelling only, and **only once**: both `255 base 7` and `0xFF base 16` have to work.
///          Case-insensitive (`BASE 7` too), the same looseness as this tool's existing
///          prefixes and suffixes.
(int, String)? _extractTargetRadix(String input) {
  final match = RegExp(r'base\s*(\d+)', caseSensitive: false).firstMatch(input);
  if (match == null) return null;
  final radix = int.tryParse(match.group(1)!);
  if (radix == null) return null;
  final rest = (input.substring(0, match.start) + input.substring(match.end)).trim();
  return (radix, rest);
}
