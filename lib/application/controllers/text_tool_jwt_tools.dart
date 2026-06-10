part of 'text_tool_controller.dart';

extension _TextToolJwtTools on TextToolController {
  TextToolOutput _jwtDecode(String input) {
    final extracted = _extractJwtToken(input);
    final parts = extracted.token.split('.');
    if (parts.length < 2 || parts.length > 3) {
      throw const FormatException('请输入 JWT，至少包含 header.payload');
    }
    final headerMap = _decodeBase64UrlObject(parts[0], 'header');
    final payloadMap = _decodeBase64UrlObject(parts[1], 'payload');
    final header = const JsonEncoder.withIndent('  ').convert(headerMap);
    final payload = const JsonEncoder.withIndent('  ').convert(payloadMap);
    final claimLines = _jwtClaimSummary(payloadMap);
    return TextToolOutput(
      'JWT 已解析',
      [
        'Header:\n$header',
        '',
        'Payload:\n$payload',
        '',
        if (claimLines.isNotEmpty) 'Claims:\n${claimLines.join('\n')}',
        if (claimLines.isNotEmpty) '',
        '签名段: ${parts.length > 2 && parts[2].isNotEmpty ? '${parts[2].length} chars' : '无'}',
      ].join('\n'),
      insights: [
        if (extracted.description != null) extracted.description!,
        ..._jwtInsights(headerMap, payloadMap, parts),
      ],
    );
  }

  Object? _decodeBase64UrlObject(String part, String label) {
    final normalized = base64Url.normalize(part);
    final decoded = utf8.decode(base64Url.decode(normalized));
    final jsonObject = json.decode(decoded);
    if (jsonObject is! Map<String, dynamic>) {
      throw FormatException('JWT $label 必须是 JSON object');
    }
    return jsonObject;
  }

  _ExtractedJwtToken _extractJwtToken(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) throw const FormatException('请输入 JWT');
    if (_wholeJwtTokenPattern.hasMatch(trimmed)) {
      return _ExtractedJwtToken(token: trimmed);
    }

    final bearer = RegExp(
      r'(?:^|\bAuthorization\s*:\s*)Bearer\s+(' + _jwtTokenSourcePattern + r')',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (bearer != null) {
      return _ExtractedJwtToken(
        token: bearer.group(1)!,
        description: '已从 Bearer/Authorization 文本中提取 JWT。',
      );
    }

    final jsonToken = _extractJwtFromJson(trimmed);
    if (jsonToken != null) return jsonToken;

    final cookieToken = _extractJwtFromCookie(trimmed);
    if (cookieToken != null) return cookieToken;

    final urlToken = _extractJwtFromUrlQuery(trimmed, requireUrlLike: true);
    if (urlToken != null) return urlToken;

    final labeled = RegExp(
      '\\b(?:jwt|token|access_token|id_token)\\b\\s*[:=]\\s*["\\\']?($_jwtTokenSourcePattern)',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (labeled != null) {
      return _ExtractedJwtToken(
        token: labeled.group(1)!,
        description: '已从 token 字段中提取 JWT。',
      );
    }

    final queryToken = _extractJwtFromUrlQuery(trimmed, requireUrlLike: false);
    if (queryToken != null) return queryToken;

    final embedded = _jwtTokenPattern.firstMatch(trimmed);
    if (embedded != null) {
      return _ExtractedJwtToken(
        token: embedded.group(0)!,
        description: '已从粘贴文本中提取 JWT。',
      );
    }

    return _ExtractedJwtToken(token: trimmed);
  }

  _ExtractedJwtToken? _extractJwtFromJson(String input) {
    try {
      final parsed = _parseJsonInput(input);
      final token = _findJwtInStructuredValue(parsed.value);
      if (token == null) return null;
      return _ExtractedJwtToken(
        token: token,
        description: '已从 JSON 字段中提取 JWT。',
      );
    } catch (_) {
      return null;
    }
  }

  _ExtractedJwtToken? _extractJwtFromCookie(String input) {
    final lines = const LineSplitter().convert(input);
    final cookieHeaderPattern = RegExp(
      r'^\s*(?:Cookie|Set-Cookie)\s*:\s*(.+)$',
      caseSensitive: false,
    );
    RegExpMatch? cookieHeader;
    for (final line in lines) {
      cookieHeader = cookieHeaderPattern.firstMatch(line);
      if (cookieHeader != null) break;
    }
    final source = cookieHeader?.group(1) ?? input.trim();
    if (cookieHeader == null) {
      final looksCookieLike = source.contains(';') &&
          source.contains('=') &&
          !source.contains('?') &&
          !_looksLikeAbsoluteUrl(source) &&
          !_looksLikeRelativeUrl(source);
      if (!looksCookieLike) return null;
    }

    final fields = <String, List<String>>{};
    for (final part in source.split(';')) {
      final trimmed = part.trim();
      final equalsIndex = trimmed.indexOf('=');
      if (equalsIndex <= 0) continue;
      final key = trimmed.substring(0, equalsIndex).trim();
      final value = trimmed.substring(equalsIndex + 1).trim();
      fields.putIfAbsent(key, () => <String>[]).add(value);
    }
    final token = _findJwtInFieldMap(fields);
    if (token == null) return null;
    return _ExtractedJwtToken(
      token: token,
      description: '已从 Cookie 字段中提取 JWT。',
    );
  }

  _ExtractedJwtToken? _extractJwtFromUrlQuery(
    String input, {
    required bool requireUrlLike,
  }) {
    final trimmed = input.trim();
    final requestTarget = _extractHttpRequestTarget(trimmed);
    final source = requestTarget ?? trimmed;
    final urlLike = requestTarget != null ||
        _looksLikeAbsoluteUrl(source) ||
        _looksLikeRelativeUrl(source) ||
        source.startsWith('?');
    if (requireUrlLike) {
      if (!urlLike) return null;
    } else if (!urlLike && !_looksLikeQueryString(source)) {
      return null;
    }

    try {
      final parsed = _parseQueryInput(source);
      final token = _findJwtInFieldMap(parsed.params);
      if (token == null) return null;
      return _ExtractedJwtToken(
        token: token,
        description: '已从 URL query 参数中提取 JWT。',
      );
    } catch (_) {
      return null;
    }
  }

  String? _findJwtInStructuredValue(Object? value) {
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString();
        if (!_isJwtFieldKey(key)) continue;
        final token = _jwtTokenFromValue(entry.value);
        if (token != null) return token;
      }
      for (final entry in value.entries) {
        final token = _findJwtInStructuredValue(entry.value);
        if (token != null) return token;
      }
    } else if (value is List) {
      for (final child in value) {
        final token = _findJwtInStructuredValue(child);
        if (token != null) return token;
      }
    } else {
      return _jwtTokenFromValue(value);
    }
    return null;
  }

  String? _findJwtInFieldMap(Map<String, List<String>> fields) {
    for (final entry in fields.entries) {
      if (!_isJwtFieldKey(entry.key)) continue;
      for (final value in entry.value) {
        final token = _jwtTokenFromValue(value);
        if (token != null) return token;
      }
    }
    for (final values in fields.values) {
      for (final value in values) {
        final token = _jwtTokenFromValue(value);
        if (token != null) return token;
      }
    }
    return null;
  }

  String? _jwtTokenFromValue(Object? value) {
    if (value is! String) return null;
    final normalized = _normalizeJwtTokenValue(value);
    final bearer = RegExp(
      r'\bBearer\s+(' + _jwtTokenSourcePattern + r')',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (bearer != null) return bearer.group(1);
    if (_wholeJwtTokenPattern.hasMatch(normalized)) return normalized;
    return _jwtTokenPattern.firstMatch(normalized)?.group(0);
  }

  String _normalizeJwtTokenValue(String value) {
    var normalized = value.trim();
    normalized = normalized.replaceFirst(RegExp(r'''^[\s"'`]+'''), '');
    normalized = normalized.replaceFirst(RegExp(r'''[\s"'`,;]+$'''), '');
    try {
      normalized = Uri.decodeQueryComponent(normalized);
    } catch (_) {
      // Keep the original value if percent encoding is partial.
    }
    return normalized.trim();
  }

  bool _isJwtFieldKey(String key) {
    final normalized = key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return normalized == 'jwt' ||
        normalized == 'token' ||
        normalized == 'authorization' ||
        normalized == 'bearer' ||
        normalized.contains('jwt') ||
        normalized.endsWith('token') ||
        normalized.endsWith('_token');
  }

  List<String> _jwtClaimSummary(Object? payloadMap) {
    if (payloadMap is! Map) return const [];
    final lines = <String>[];
    for (final key in ['iss', 'sub', 'aud', 'jti']) {
      final value = payloadMap[key];
      if (value != null) lines.add('$key: ${_jwtClaimValue(value)}');
    }
    for (final key in [
      'scope',
      'scp',
      'role',
      'roles',
      'permissions',
      'groups'
    ]) {
      final values = _jwtClaimListValue(payloadMap[key]);
      if (values.isNotEmpty) lines.add('$key: ${values.join(', ')}');
    }
    for (final key in ['iat', 'nbf', 'exp']) {
      final value = payloadMap[key];
      if (value is num) {
        lines.add('$key: ${_formatJwtTimestamp(value)}');
      }
    }
    return lines;
  }

  String _jwtClaimValue(Object? value) {
    if (value is List) return value.join(', ');
    return value.toString();
  }

  List<String> _jwtClaimListValue(Object? value) {
    if (value == null) return const [];
    if (value is String) {
      return value
          .split(RegExp(r'[\s,]+'))
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toList();
    }
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((part) => part.isNotEmpty)
          .toList();
    }
    return [value.toString()];
  }

  String _formatJwtTimestamp(num seconds) {
    final local =
        DateTime.fromMillisecondsSinceEpoch(seconds.toInt() * 1000).toLocal();
    final utc = DateTime.fromMillisecondsSinceEpoch(seconds.toInt() * 1000,
        isUtc: true);
    return '$local | UTC ${utc.toIso8601String()} (${seconds.toInt()})';
  }

  List<String> _jwtInsights(
    Object? headerMap,
    Object? payloadMap,
    List<String> parts,
  ) {
    final insights = <String>[
      parts.length > 2 && parts[2].isNotEmpty
          ? '包含签名段，但未在本地校验签名。'
          : '缺少签名段，仅能查看内容。',
    ];
    if (headerMap is Map) {
      final alg = headerMap['alg'];
      final typ = headerMap['typ'];
      if (alg != null) insights.add('算法 alg: $alg。');
      if (typ != null) insights.add('类型 typ: $typ。');
      if (alg is String && alg.toLowerCase() == 'none') {
        insights.add('alg=none，Token 不包含加密签名。');
      }
      final kid = headerMap['kid'];
      if (kid != null) insights.add('包含密钥 ID kid: $kid。');
    }
    if (payloadMap is Map) {
      final now = DateTime.now();
      final exp = payloadMap['exp'];
      if (exp is num) {
        final expiresAt = DateTime.fromMillisecondsSinceEpoch(
          exp.toInt() * 1000,
        ).toLocal();
        insights.add(expiresAt.isBefore(now) ? 'Token 已过期。' : 'Token 尚未过期。');
      } else {
        insights.add('缺少过期时间 exp。');
      }
      final nbf = payloadMap['nbf'];
      if (nbf is num) {
        final notBefore = DateTime.fromMillisecondsSinceEpoch(
          nbf.toInt() * 1000,
        ).toLocal();
        insights
            .add(notBefore.isAfter(now) ? 'Token 尚未生效。' : 'Token 已到 nbf 生效时间。');
      }
      if (payloadMap['iat'] is num) insights.add('包含签发时间 iat。');
      if (payloadMap['aud'] != null) insights.add('包含受众 aud。');
      if (payloadMap['iss'] != null) insights.add('包含签发者 iss。');
      if (payloadMap['sub'] != null) insights.add('包含主题 sub。');
    }
    return insights;
  }
}

const String _jwtTokenSourcePattern =
    r'[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+(?:\.[A-Za-z0-9_-]*)?';

final RegExp _jwtTokenPattern = RegExp(
  r'(?<![A-Za-z0-9_-])' + _jwtTokenSourcePattern + r'(?![A-Za-z0-9_-])',
);
final RegExp _wholeJwtTokenPattern = RegExp(
  r'^' + _jwtTokenSourcePattern + r'$',
);
