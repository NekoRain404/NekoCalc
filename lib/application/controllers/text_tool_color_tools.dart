part of 'text_tool_controller.dart';

extension _TextToolColorTools on TextToolController {
  TextToolOutput _colorConvert(String input) {
    final color = _parseColor(input);
    final alpha = color.alpha;
    final hex = '#${_hex8(color.red)}${_hex8(color.green)}${_hex8(color.blue)}';
    final argb =
        '#${_hex8(alpha)}${_hex8(color.red)}${_hex8(color.green)}${_hex8(color.blue)}';
    final alphaRatio = alpha / 255;
    return TextToolOutput(
      alpha == 255
          ? 'rgb(${color.red}, ${color.green}, ${color.blue})'
          : 'rgba(${color.red}, ${color.green}, ${color.blue}, ${alphaRatio.toStringAsFixed(3)})',
      [
        'HEX: $hex',
        'ARGB: $argb',
        'RGB: ${color.red}, ${color.green}, ${color.blue}',
        'Alpha: $alpha (${(alphaRatio * 100).toStringAsFixed(1)}%)',
        'HSL: ${_hslString(color)}',
      ].join('\n'),
      insights: [
        color.source,
        if (alpha < 255) '包含透明度，复制到不支持 alpha 的场景时请使用 HEX RGB。',
      ],
    );
  }

  _ParsedColor _parseColor(String input) {
    final raw = input.trim();
    if (raw.isEmpty) throw const FormatException('请输入颜色值');
    final namedHex = _namedColorHex(raw);
    if (namedHex != null) {
      final parsed = _parseHexColor(namedHex);
      if (parsed != null) {
        return _ParsedColor(
          red: parsed.red,
          green: parsed.green,
          blue: parsed.blue,
          alpha: parsed.alpha,
          source: '输入识别为 CSS 命名颜色 ${raw.toLowerCase()}。',
        );
      }
    }
    final rgbMatch =
        RegExp(r'rgba?\(([^)]+)\)', caseSensitive: false).firstMatch(raw);
    if (rgbMatch != null) {
      final parts = _splitCssColorFunctionBody(rgbMatch.group(1)!);
      if (parts.length >= 3) {
        final r = _parseColorChannel(parts[0]);
        final g = _parseColorChannel(parts[1]);
        final b = _parseColorChannel(parts[2]);
        final a = parts.length >= 4 ? _parseAlphaChannel(parts[3]) : 255;
        if (r != null && g != null && b != null && a != null) {
          return _ParsedColor(
            red: r,
            green: g,
            blue: b,
            alpha: a,
            source: parts.length >= 4 ? '输入识别为 RGBA 颜色。' : '输入识别为 RGB 颜色。',
          );
        }
      }
    }
    final hslMatch =
        RegExp(r'hsla?\(([^)]+)\)', caseSensitive: false).firstMatch(raw);
    if (hslMatch != null) {
      final parsed = _parseHslColor(hslMatch.group(1)!);
      if (parsed != null) return parsed;
    }
    final labeledChannels = _parseLabeledColorChannels(raw);
    if (labeledChannels != null) return labeledChannels;
    final tupleChannels = _parseColorChannelTuple(raw);
    if (tupleChannels != null) return tupleChannels;
    final hashHexMatch = RegExp(r'#([0-9a-fA-F]{3,8})\b').firstMatch(raw);
    final prefixedHexMatch =
        RegExp(r'\b0x([0-9a-fA-F]{6}|[0-9a-fA-F]{8})\b').firstMatch(raw);
    final cssHexLabelMatch = RegExp(
      r'(?:\b(?:hex|color|colour)|颜色|色值)\s*[:=]\s*([0-9a-fA-F]{3,8})\b',
      caseSensitive: false,
    ).firstMatch(raw);
    final bareHexMatch = RegExp(r'^[0-9a-fA-F]{3,8}$').firstMatch(raw);
    final hex = hashHexMatch?.group(1) ??
        prefixedHexMatch?.group(1) ??
        cssHexLabelMatch?.group(1) ??
        bareHexMatch?.group(0);
    if (hex != null) {
      final parsed = _parseHexColor(hex);
      if (parsed != null) {
        final source = _hexColorSource(raw, hex, parsed.source);
        return _ParsedColor(
          red: parsed.red,
          green: parsed.green,
          blue: parsed.blue,
          alpha: parsed.alpha,
          source: source,
        );
      }
    }
    throw const FormatException(
        '请输入 HEX、RGB、RGBA、HSL、Color(0xAARRGGBB) 或 CSS 命名色，例如 #5B47FF、rgb(91,71,255)、hsl(250 100% 60%)');
  }

  String _hexColorSource(String raw, String hex, String fallback) {
    if (RegExp(r'\bColor\s*\(', caseSensitive: false).hasMatch(raw)) {
      return '输入识别为 Flutter/Android Color(0xAARRGGBB) 色值。';
    }
    if (RegExp(r'\b0x', caseSensitive: false).hasMatch(raw)) {
      return hex.length == 8 ? '输入识别为 0xAARRGGBB 色值。' : '输入识别为 0xRRGGBB 色值。';
    }
    if (RegExp(r'(?:\b(?:hex|color|colour)|颜色|色值)\s*[:=]', caseSensitive: false)
        .hasMatch(raw)) {
      return '输入识别为带标签 HEX 色值。';
    }
    return fallback;
  }

  List<String> _splitCssColorFunctionBody(String body) {
    return body
        .replaceAll(',', ' ')
        .replaceAll('/', ' ')
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList();
  }

  _ParsedColor? _parseHexColor(String hex) {
    final normalized = hex.length == 3 || hex.length == 4
        ? hex.split('').map((char) => '$char$char').join()
        : hex;
    if (normalized.length == 6) {
      final value = int.tryParse(normalized, radix: 16);
      if (value == null) return null;
      return _ParsedColor(
        red: (value >> 16) & 0xff,
        green: (value >> 8) & 0xff,
        blue: value & 0xff,
        alpha: 255,
        source: hex.length == 3 ? '输入识别为 3 位 HEX 颜色。' : '输入识别为 6 位 HEX 颜色。',
      );
    }
    if (normalized.length == 8) {
      final value = int.tryParse(normalized, radix: 16);
      if (value == null) return null;
      return _ParsedColor(
        red: (value >> 16) & 0xff,
        green: (value >> 8) & 0xff,
        blue: value & 0xff,
        alpha: (value >> 24) & 0xff,
        source:
            hex.length == 4 ? '输入识别为 4 位 ARGB HEX 颜色。' : '输入识别为 ARGB HEX 颜色。',
      );
    }
    return null;
  }

  _ParsedColor? _parseHslColor(String body) {
    final normalized = body.replaceAll(',', ' ').replaceAll('/', ' ');
    final parts = normalized
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList();
    if (parts.length < 3) return null;
    final hue = _parseCssHue(parts[0]);
    final saturation = _parsePercentRatio(parts[1]);
    final lightness = _parsePercentRatio(parts[2]);
    final alpha = parts.length >= 4 ? _parseAlphaChannel(parts[3]) : 255;
    if (hue == null ||
        saturation == null ||
        lightness == null ||
        alpha == null) {
      return null;
    }
    final rgb = _hslToRgb(hue, saturation, lightness);
    return _ParsedColor(
      red: rgb.$1,
      green: rgb.$2,
      blue: rgb.$3,
      alpha: alpha,
      source: parts.length >= 4 ? '输入识别为 HSLA 颜色。' : '输入识别为 HSL 颜色。',
    );
  }

  _ParsedColor? _parseLabeledColorChannels(String input) {
    final matches = RegExp(
      r'\b(?:red|green|blue|alpha|r|g|b|a)\s*[:=]\s*([+-]?\d+(?:\.\d+)?%?)',
      caseSensitive: false,
    ).allMatches(input).toList();
    if (matches.length < 3) return null;

    final values = <String, String>{};
    for (final match in matches) {
      final keyMatch =
          RegExp(r'^\s*(red|green|blue|alpha|r|g|b|a)\b', caseSensitive: false)
              .firstMatch(match.group(0)!);
      final key = keyMatch?.group(1)?.toLowerCase();
      if (key != null) values[key] = match.group(1)!;
    }

    String? pick(String short, String long) => values[short] ?? values[long];
    final r = _parseColorChannel(pick('r', 'red') ?? '');
    final g = _parseColorChannel(pick('g', 'green') ?? '');
    final b = _parseColorChannel(pick('b', 'blue') ?? '');
    final alphaText = pick('a', 'alpha');
    final a = alphaText == null ? 255 : _parseAlphaChannel(alphaText);
    if (r == null || g == null || b == null || a == null) return null;
    return _ParsedColor(
      red: r,
      green: g,
      blue: b,
      alpha: a,
      source: alphaText == null ? '输入识别为标签式 RGB 颜色。' : '输入识别为标签式 RGBA 颜色。',
    );
  }

  _ParsedColor? _parseColorChannelTuple(String input) {
    final tupleMatch = RegExp(
      r'\b(argb|rgba|rgb)\s*[:=]\s*\(?\s*([^)]+?)\s*\)?$',
      caseSensitive: false,
    ).firstMatch(input.trim());
    if (tupleMatch == null) return null;
    final mode = tupleMatch.group(1)!.toLowerCase();
    final parts = tupleMatch
        .group(2)!
        .split(RegExp(r'[\s,;/，；]+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.length < 3) return null;

    int? r;
    int? g;
    int? b;
    var a = 255;
    if (mode == 'argb') {
      if (parts.length < 4) return null;
      a = _parseAlphaChannel(parts[0]) ?? -1;
      r = _parseColorChannel(parts[1]);
      g = _parseColorChannel(parts[2]);
      b = _parseColorChannel(parts[3]);
    } else {
      r = _parseColorChannel(parts[0]);
      g = _parseColorChannel(parts[1]);
      b = _parseColorChannel(parts[2]);
      if (parts.length >= 4) a = _parseAlphaChannel(parts[3]) ?? -1;
    }
    if (r == null || g == null || b == null || a < 0) return null;
    return _ParsedColor(
      red: r,
      green: g,
      blue: b,
      alpha: a,
      source: mode == 'argb'
          ? '输入识别为 ARGB 通道列表。'
          : parts.length >= 4
              ? '输入识别为 RGBA 通道列表。'
              : '输入识别为 RGB 通道列表。',
    );
  }

  double? _parsePercentRatio(String input) {
    if (!input.endsWith('%')) return null;
    final value = double.tryParse(input.substring(0, input.length - 1));
    return value == null ? null : (value / 100).clamp(0.0, 1.0);
  }

  double? _parseCssHue(String input) {
    final normalized = input.trim().toLowerCase();
    if (normalized.endsWith('turn')) {
      final value =
          double.tryParse(normalized.substring(0, normalized.length - 4));
      return value == null ? null : value * 360;
    }
    if (normalized.endsWith('grad')) {
      final value =
          double.tryParse(normalized.substring(0, normalized.length - 4));
      return value == null ? null : value * 0.9;
    }
    if (normalized.endsWith('rad')) {
      final value =
          double.tryParse(normalized.substring(0, normalized.length - 3));
      return value == null ? null : value * 180 / math.pi;
    }
    if (normalized.endsWith('deg')) {
      return double.tryParse(normalized.substring(0, normalized.length - 3));
    }
    return double.tryParse(normalized);
  }

  (int, int, int) _hslToRgb(double hue, double saturation, double lightness) {
    final h = ((hue % 360) + 360) % 360 / 360;
    double channel(double p, double q, double t) {
      var value = t;
      if (value < 0) value += 1;
      if (value > 1) value -= 1;
      if (value < 1 / 6) return p + (q - p) * 6 * value;
      if (value < 1 / 2) return q;
      if (value < 2 / 3) return p + (q - p) * (2 / 3 - value) * 6;
      return p;
    }

    if (saturation == 0) {
      final gray = (lightness * 255).round().clamp(0, 255);
      return (gray, gray, gray);
    }
    final q = lightness < 0.5
        ? lightness * (1 + saturation)
        : lightness + saturation - lightness * saturation;
    final p = 2 * lightness - q;
    return (
      (channel(p, q, h + 1 / 3) * 255).round().clamp(0, 255),
      (channel(p, q, h) * 255).round().clamp(0, 255),
      (channel(p, q, h - 1 / 3) * 255).round().clamp(0, 255),
    );
  }

  String? _namedColorHex(String input) {
    return const {
      'aliceblue': 'F0F8FF',
      'antiquewhite': 'FAEBD7',
      'aqua': '00FFFF',
      'aquamarine': '7FFFD4',
      'azure': 'F0FFFF',
      'beige': 'F5F5DC',
      'bisque': 'FFE4C4',
      'black': '000000',
      'blanchedalmond': 'FFEBCD',
      'blue': '0000FF',
      'blueviolet': '8A2BE2',
      'brown': 'A52A2A',
      'burlywood': 'DEB887',
      'cadetblue': '5F9EA0',
      'chartreuse': '7FFF00',
      'chocolate': 'D2691E',
      'coral': 'FF7F50',
      'cornflowerblue': '6495ED',
      'cornsilk': 'FFF8DC',
      'crimson': 'DC143C',
      'cyan': '00FFFF',
      'darkblue': '00008B',
      'darkcyan': '008B8B',
      'darkgoldenrod': 'B8860B',
      'darkgray': 'A9A9A9',
      'darkgreen': '006400',
      'darkgrey': 'A9A9A9',
      'darkkhaki': 'BDB76B',
      'darkmagenta': '8B008B',
      'darkolivegreen': '556B2F',
      'darkorange': 'FF8C00',
      'darkorchid': '9932CC',
      'darkred': '8B0000',
      'darksalmon': 'E9967A',
      'darkseagreen': '8FBC8F',
      'darkslateblue': '483D8B',
      'darkslategray': '2F4F4F',
      'darkslategrey': '2F4F4F',
      'darkturquoise': '00CED1',
      'darkviolet': '9400D3',
      'deeppink': 'FF1493',
      'deepskyblue': '00BFFF',
      'dimgray': '696969',
      'dimgrey': '696969',
      'dodgerblue': '1E90FF',
      'firebrick': 'B22222',
      'floralwhite': 'FFFAF0',
      'forestgreen': '228B22',
      'fuchsia': 'FF00FF',
      'gainsboro': 'DCDCDC',
      'ghostwhite': 'F8F8FF',
      'gold': 'FFD700',
      'goldenrod': 'DAA520',
      'gray': '808080',
      'green': '008000',
      'greenyellow': 'ADFF2F',
      'grey': '808080',
      'honeydew': 'F0FFF0',
      'hotpink': 'FF69B4',
      'indianred': 'CD5C5C',
      'indigo': '4B0082',
      'ivory': 'FFFFF0',
      'khaki': 'F0E68C',
      'lavender': 'E6E6FA',
      'lavenderblush': 'FFF0F5',
      'lawngreen': '7CFC00',
      'lemonchiffon': 'FFFACD',
      'lightblue': 'ADD8E6',
      'lightcoral': 'F08080',
      'lightcyan': 'E0FFFF',
      'lightgoldenrodyellow': 'FAFAD2',
      'lightgray': 'D3D3D3',
      'lightgreen': '90EE90',
      'lightgrey': 'D3D3D3',
      'lightpink': 'FFB6C1',
      'lightsalmon': 'FFA07A',
      'lightseagreen': '20B2AA',
      'lightskyblue': '87CEFA',
      'lightslategray': '778899',
      'lightslategrey': '778899',
      'lightsteelblue': 'B0C4DE',
      'lightyellow': 'FFFFE0',
      'lime': '00FF00',
      'limegreen': '32CD32',
      'linen': 'FAF0E6',
      'magenta': 'FF00FF',
      'maroon': '800000',
      'mediumaquamarine': '66CDAA',
      'mediumblue': '0000CD',
      'mediumorchid': 'BA55D3',
      'mediumpurple': '9370DB',
      'mediumseagreen': '3CB371',
      'mediumslateblue': '7B68EE',
      'mediumspringgreen': '00FA9A',
      'mediumturquoise': '48D1CC',
      'mediumvioletred': 'C71585',
      'midnightblue': '191970',
      'mintcream': 'F5FFFA',
      'mistyrose': 'FFE4E1',
      'moccasin': 'FFE4B5',
      'navajowhite': 'FFDEAD',
      'navy': '000080',
      'oldlace': 'FDF5E6',
      'olive': '808000',
      'olivedrab': '6B8E23',
      'orange': 'FFA500',
      'orangered': 'FF4500',
      'orchid': 'DA70D6',
      'palegoldenrod': 'EEE8AA',
      'palegreen': '98FB98',
      'paleturquoise': 'AFEEEE',
      'palevioletred': 'DB7093',
      'papayawhip': 'FFEFD5',
      'peachpuff': 'FFDAB9',
      'peru': 'CD853F',
      'pink': 'FFC0CB',
      'plum': 'DDA0DD',
      'powderblue': 'B0E0E6',
      'purple': '800080',
      'rebeccapurple': '663399',
      'red': 'FF0000',
      'rosybrown': 'BC8F8F',
      'royalblue': '4169E1',
      'saddlebrown': '8B4513',
      'salmon': 'FA8072',
      'sandybrown': 'F4A460',
      'seagreen': '2E8B57',
      'seashell': 'FFF5EE',
      'sienna': 'A0522D',
      'silver': 'C0C0C0',
      'skyblue': '87CEEB',
      'slateblue': '6A5ACD',
      'slategray': '708090',
      'slategrey': '708090',
      'snow': 'FFFAFA',
      'springgreen': '00FF7F',
      'steelblue': '4682B4',
      'tan': 'D2B48C',
      'teal': '008080',
      'thistle': 'D8BFD8',
      'tomato': 'FF6347',
      'transparent': '00000000',
      'turquoise': '40E0D0',
      'violet': 'EE82EE',
      'wheat': 'F5DEB3',
      'white': 'FFFFFF',
      'whitesmoke': 'F5F5F5',
      'yellow': 'FFFF00',
      'yellowgreen': '9ACD32',
    }[input.trim().toLowerCase()];
  }

  int? _parseColorChannel(String input) {
    if (input.endsWith('%')) {
      final value = double.tryParse(input.substring(0, input.length - 1));
      return value == null ? null : (value / 100 * 255).round().clamp(0, 255);
    }
    final value = double.tryParse(input);
    return value?.round().clamp(0, 255);
  }

  int? _parseAlphaChannel(String input) {
    if (input.endsWith('%')) {
      final value = double.tryParse(input.substring(0, input.length - 1));
      return value == null ? null : (value / 100 * 255).round().clamp(0, 255);
    }
    final value = double.tryParse(input);
    return value == null
        ? null
        : value <= 1
            ? (value * 255).round().clamp(0, 255)
            : value.round().clamp(0, 255);
  }

  String _hslString(_ParsedColor color) {
    final r = color.red / 255;
    final g = color.green / 255;
    final b = color.blue / 255;
    final maxValue = math.max(r, math.max(g, b));
    final minValue = math.min(r, math.min(g, b));
    final lightness = (maxValue + minValue) / 2;
    var hue = 0.0;
    var saturation = 0.0;
    if (maxValue != minValue) {
      final delta = maxValue - minValue;
      saturation = lightness > 0.5
          ? delta / (2 - maxValue - minValue)
          : delta / (maxValue + minValue);
      if (maxValue == r) {
        hue = (g - b) / delta + (g < b ? 6 : 0);
      } else if (maxValue == g) {
        hue = (b - r) / delta + 2;
      } else {
        hue = (r - g) / delta + 4;
      }
      hue *= 60;
    }
    return '${hue.round()}°, ${(saturation * 100).toStringAsFixed(1)}%, ${(lightness * 100).toStringAsFixed(1)}%';
  }

  String _hex8(int value) {
    return value.clamp(0, 255).toRadixString(16).toUpperCase().padLeft(2, '0');
  }
}
