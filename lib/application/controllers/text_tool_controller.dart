import 'dart:convert';
import 'dart:math' as math;

import '../../core/math/expression_parser.dart';

class TextToolController {
  const TextToolController();

  TextToolOutput calculate({
    required String toolId,
    required String input,
    String formula = 'a * b + c',
    String a = '12',
    String b = '3',
    String c = '5',
  }) {
    try {
      final trimmed = input.trim();
      return switch (toolId) {
        'base_convert' => _baseConvert(trimmed),
        'timestamp' => _timestamp(trimmed),
        'color_convert' => _colorConvert(trimmed),
        'base64' => _base64(trimmed),
        'url_codec' => _urlCodec(trimmed),
        'json_format' => _jsonFormat(trimmed),
        'ascii_unicode' => _asciiUnicode(input),
        'bitwise' => _bitwise(trimmed),
        'checksum' => _checksum(input),
        'uuid' => _uuid(),
        'jwt_decode' => _jwtDecode(trimmed),
        'query_params' => _queryParams(trimmed),
        'html_entities' => _htmlEntities(input),
        'regex_test' => _regexTest(input),
        'text_stats' => _textStats(input),
        'csv_json' => _csvJson(input),
        'fnv_crc' => _fnvCrc(input),
        'custom_formula' => _customFormula(formula: formula, a: a, b: b, c: c),
        _ => const TextToolOutput('不支持的文本工具', '请从工具中心打开已登记的编程与数据工具。'),
      };
    } catch (error) {
      return TextToolOutput('输入无效', error.toString());
    }
  }

  TextToolOutput _baseConvert(String input) {
    final normalized = input.toLowerCase().replaceAll(' ', '');
    final value = normalized.startsWith('0x')
        ? int.parse(normalized.substring(2), radix: 16)
        : normalized.startsWith('0b')
            ? int.parse(normalized.substring(2), radix: 2)
            : int.parse(normalized);
    return TextToolOutput(
      value.toString(),
      '二进制: ${value.toRadixString(2)}\n八进制: ${value.toRadixString(8)}\n十进制: $value\n十六进制: ${value.toRadixString(16).toUpperCase()}',
    );
  }

  TextToolOutput _timestamp(String input) {
    final raw = int.parse(input);
    final millis = raw > 9999999999 ? raw : raw * 1000;
    final local = DateTime.fromMillisecondsSinceEpoch(millis);
    final utc = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
    return TextToolOutput(
      local.toString(),
      '本地时间: $local\nUTC: $utc\n秒级时间戳: ${(millis / 1000).round()}\n毫秒时间戳: $millis',
    );
  }

  TextToolOutput _colorConvert(String input) {
    final hex = input.replaceAll('#', '');
    if (hex.length != 6) throw const FormatException('请输入 6 位 HEX，例如 #5B47FF');
    final value = int.parse(hex, radix: 16);
    final r = (value >> 16) & 0xff;
    final g = (value >> 8) & 0xff;
    final b = value & 0xff;
    return TextToolOutput('rgb($r, $g, $b)', 'HEX: #${hex.toUpperCase()}\nRGB: $r, $g, $b\nARGB: 255, $r, $g, $b');
  }

  TextToolOutput _base64(String input) {
    try {
      final decoded = utf8.decode(base64.decode(input));
      return TextToolOutput(decoded, '检测为 Base64 输入，已解码为 UTF-8 文本。');
    } catch (_) {
      final encoded = base64.encode(utf8.encode(input));
      return TextToolOutput(encoded, '检测为普通文本，已编码为 Base64。');
    }
  }

  TextToolOutput _jsonFormat(String input) {
    final decoded = json.decode(input);
    const encoder = JsonEncoder.withIndent('  ');
    return TextToolOutput('JSON 有效', encoder.convert(decoded));
  }

  TextToolOutput _urlCodec(String input) {
    if (input.contains('%')) {
      return TextToolOutput(Uri.decodeComponent(input), '检测为 URL 编码文本，已执行 decodeComponent。');
    }
    return TextToolOutput(Uri.encodeComponent(input), '检测为普通文本，已执行 encodeComponent。');
  }

  TextToolOutput _asciiUnicode(String input) {
    final chars = input.runes.take(24).map((code) {
      final char = String.fromCharCode(code);
      final hex = code.toRadixString(16).toUpperCase().padLeft(4, '0');
      return '$char  dec:$code  U+$hex';
    }).join('\n');
    return TextToolOutput('${input.runes.length} 个码点', chars.isEmpty ? '请输入字符' : chars);
  }

  TextToolOutput _bitwise(String input) {
    final parts = input.split(RegExp(r'[\s,]+')).where((part) => part.isNotEmpty).toList();
    if (parts.length < 2) throw const FormatException('请输入两个整数，例如 12 5');
    final a = _parseInt(parts[0]);
    final b = _parseInt(parts[1]);
    return TextToolOutput(
      'AND = ${a & b}',
      [
        'A: $a  bin:${a.toRadixString(2)}',
        'B: $b  bin:${b.toRadixString(2)}',
        'AND: ${a & b}',
        'OR: ${a | b}',
        'XOR: ${a ^ b}',
        'NOT A: ${~a}',
        'A << 1: ${a << 1}',
        'A >> 1: ${a >> 1}',
      ].join('\n'),
    );
  }

  TextToolOutput _checksum(String input) {
    final bytes = utf8.encode(input);
    final sum = bytes.fold<int>(0, (total, byte) => (total + byte) & 0xff);
    final xor = bytes.fold<int>(0, (total, byte) => total ^ byte);
    return TextToolOutput(
      'SUM8 = 0x${sum.toRadixString(16).toUpperCase().padLeft(2, '0')}',
      '长度: ${bytes.length} bytes\nSUM8: $sum\nXOR8: $xor\nHEX: ${bytes.map((b) => b.toRadixString(16).toUpperCase().padLeft(2, '0')).join(' ')}',
    );
  }

  TextToolOutput _uuid() {
    final random = math.Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final uuid = '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    return TextToolOutput(uuid, 'UUID v4\n大写: ${uuid.toUpperCase()}\n无连字符: ${uuid.replaceAll('-', '')}');
  }

  TextToolOutput _jwtDecode(String input) {
    final parts = input.split('.');
    if (parts.length < 2) throw const FormatException('请输入 JWT，至少包含 header.payload');
    final header = _decodeBase64UrlJson(parts[0]);
    final payload = _decodeBase64UrlJson(parts[1]);
    final payloadMap = json.decode(payload);
    final exp = payloadMap is Map && payloadMap['exp'] is num
        ? DateTime.fromMillisecondsSinceEpoch((payloadMap['exp'] as num).toInt() * 1000).toLocal().toString()
        : '无';
    return TextToolOutput('JWT 已解析', 'Header:\n$header\n\nPayload:\n$payload\n\n过期时间: $exp\n签名段: ${parts.length > 2 ? '${parts[2].length} chars' : '无'}');
  }

  TextToolOutput _queryParams(String input) {
    final uri = input.contains('?') ? Uri.parse(input) : Uri.parse('https://local/?$input');
    final entries = uri.queryParameters.entries.toList();
    if (entries.isEmpty) return const TextToolOutput('无参数', '没有解析到 query 参数。');
    final jsonText = const JsonEncoder.withIndent('  ').convert(uri.queryParameters);
    final table = entries.map((entry) => '${entry.key} = ${entry.value}').join('\n');
    return TextToolOutput('${entries.length} 个参数', '$table\n\nJSON:\n$jsonText');
  }

  TextToolOutput _htmlEntities(String input) {
    const entities = {'&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'};
    if (input.contains('&lt;') || input.contains('&amp;') || input.contains('&quot;') || input.contains('&#39;')) {
      var decoded = input;
      for (final entry in entities.entries) {
        decoded = decoded.replaceAll(entry.value, entry.key);
      }
      return TextToolOutput(decoded, '检测为 HTML 实体文本，已解码。');
    }
    var encoded = input;
    for (final entry in entities.entries) {
      encoded = encoded.replaceAll(entry.key, entry.value);
    }
    return TextToolOutput(encoded, '检测为普通文本，已编码 HTML 实体。');
  }

  TextToolOutput _regexTest(String input) {
    final lines = const LineSplitter().convert(input);
    if (lines.length < 2) throw const FormatException('第一行输入正则，后续行输入测试文本。');
    final pattern = lines.first;
    final text = lines.skip(1).join('\n');
    final regex = RegExp(pattern, multiLine: true);
    final matches = regex.allMatches(text).toList();
    final detail = matches.take(50).map((match) => '[${match.start}, ${match.end}) ${match.group(0)}').join('\n');
    return TextToolOutput('${matches.length} 个匹配', detail.isEmpty ? '没有匹配项' : detail);
  }

  TextToolOutput _textStats(String input) {
    final runes = input.runes.length;
    final words = RegExp(r'[\w\u4e00-\u9fa5]+').allMatches(input).length;
    final lines = input.isEmpty ? 0 : const LineSplitter().convert(input).length;
    final bytes = utf8.encode(input).length;
    return TextToolOutput('$runes 字符', '字符数: $runes\n词/片段: $words\n行数: $lines\nUTF-8 字节: $bytes\n去空白字符: ${input.replaceAll(RegExp(r'\\s+'), '').runes.length}');
  }

  TextToolOutput _csvJson(String input) {
    final lines = const LineSplitter().convert(input).where((line) => line.trim().isNotEmpty).toList();
    if (lines.length < 2) throw const FormatException('至少需要表头和一行数据。');
    final delimiter = lines.first.contains('\t') ? '\t' : ',';
    final headers = _splitDelimited(lines.first, delimiter);
    final rows = lines.skip(1).map((line) {
      final cells = _splitDelimited(line, delimiter);
      return {
        for (var i = 0; i < headers.length; i++) headers[i]: i < cells.length ? cells[i] : '',
      };
    }).toList();
    return TextToolOutput('${rows.length} 行', const JsonEncoder.withIndent('  ').convert(rows));
  }

  TextToolOutput _fnvCrc(String input) {
    final bytes = utf8.encode(input);
    var fnv = 0x811c9dc5;
    var crc = 0xffffffff;
    for (final byte in bytes) {
      fnv ^= byte;
      fnv = (fnv * 0x01000193) & 0xffffffff;
      crc ^= byte;
      for (var i = 0; i < 8; i++) {
        crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
      }
    }
    crc = crc ^ 0xffffffff;
    return TextToolOutput('CRC32 = ${_hex32(crc)}', 'FNV-1a 32: ${_hex32(fnv)}\nCRC32: ${_hex32(crc)}\n长度: ${bytes.length} bytes');
  }

  int _parseInt(String input) {
    final normalized = input.toLowerCase();
    if (normalized.startsWith('0x')) return int.parse(normalized.substring(2), radix: 16);
    if (normalized.startsWith('0b')) return int.parse(normalized.substring(2), radix: 2);
    return int.parse(normalized);
  }

  String _decodeBase64UrlJson(String part) {
    final normalized = base64Url.normalize(part);
    final decoded = utf8.decode(base64Url.decode(normalized));
    final jsonObject = json.decode(decoded);
    return const JsonEncoder.withIndent('  ').convert(jsonObject);
  }

  List<String> _splitDelimited(String line, String delimiter) {
    return line.split(delimiter).map((cell) => cell.trim().replaceAll(RegExp(r'^"|"$'), '')).toList();
  }

  String _hex32(int value) => '0x${(value & 0xffffffff).toRadixString(16).toUpperCase().padLeft(8, '0')}';

  TextToolOutput _customFormula({
    required String formula,
    required String a,
    required String b,
    required String c,
  }) {
    final av = double.tryParse(a) ?? 0;
    final bv = double.tryParse(b) ?? 0;
    final cv = double.tryParse(c) ?? 0;
    final expression = formula
        .replaceAll(RegExp(r'\ba\b'), av.toString())
        .replaceAll(RegExp(r'\bb\b'), bv.toString())
        .replaceAll(RegExp(r'\bc\b'), cv.toString());
    final result = ExpressionParser(expression, degreeMode: true).parse();
    return TextToolOutput(result.toString(), '展开公式: $expression\n变量: a=$av, b=$bv, c=$cv');
  }
}

class TextToolOutput {
  const TextToolOutput(this.primary, this.detail);

  final String primary;
  final String detail;
}
