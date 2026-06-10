part of 'text_tool_controller.dart';

extension _TextToolUrlQueryTools on TextToolController {
  TextToolOutput _urlCodec(String input) {
    final decoded = _tryDecodeUrlText(input);
    if (decoded != null) {
      return TextToolOutput(
        decoded.value,
        [
          '模式: ${decoded.mode}',
          '原长度: ${input.length}',
          '结果长度: ${decoded.value.length}',
          '长度变化: ${_signedLengthDelta(decoded.value.length - input.length)}',
          if (decoded.queryParameterCount > 0)
            'Query 参数: ${decoded.queryParameterCount} 个',
          if (decoded.percentTripletCount > 0)
            '百分号编码片段: ${decoded.percentTripletCount} 个',
        ].join('\n'),
        insights: [
          if (decoded.sourceDescription != null)
            '已从${decoded.sourceDescription}中提取 URL。',
          '检测到百分号编码，已按${decoded.mode}解码。',
          if (decoded.decodedPlus) 'Query 中的 + 已按空格处理。',
          if (decoded.queryParameterCount > 0) 'Query 参数数量按 & 分隔估算，重复键未在此处合并。',
        ],
      );
    }
    final encoded = _encodeUrlText(input);
    return TextToolOutput(
      encoded.value,
      [
        '模式: ${encoded.mode}',
        '原长度: ${input.length}',
        '结果长度: ${encoded.value.length}',
        '长度变化: ${_signedLengthDelta(encoded.value.length - input.length)}',
        if (encoded.queryParameterCount > 0)
          'Query 参数: ${encoded.queryParameterCount} 个',
        if (encoded.percentTripletCount > 0)
          '百分号编码片段: ${encoded.percentTripletCount} 个',
      ].join('\n'),
      insights: [
        if (encoded.sourceDescription != null)
          '已从${encoded.sourceDescription}中提取 URL。',
        '未检测到百分号编码，已按${encoded.mode}编码。',
        if (encoded.encodedQuery) '已保留 URL 结构，仅编码 query 键和值。',
        if (encoded.queryParameterCount > 0) 'Query 参数数量按 & 分隔估算，重复键未在此处合并。',
      ],
    );
  }

  TextToolOutput _queryParams(String input) {
    final parsed = _parseQueryInput(input);
    final params = parsed.params;
    if (params.isEmpty) return const TextToolOutput('无参数', '没有解析到 query 参数。');
    final totalValues =
        params.values.fold<int>(0, (sum, values) => sum + values.length);
    final jsonObject = {
      for (final entry in params.entries)
        entry.key: entry.value.length == 1 ? entry.value.single : entry.value,
    };
    final jsonText = const JsonEncoder.withIndent('  ').convert(jsonObject);
    final table = params.entries.map((entry) {
      final value = entry.value.isEmpty
          ? ''
          : entry.value.length == 1
              ? entry.value.single
              : entry.value.join(', ');
      return '${entry.key} = $value';
    }).join('\n');
    final repeatedKeys = params.entries
        .where((entry) => entry.value.length > 1)
        .map((entry) => '${entry.key}(${entry.value.length})')
        .toList();
    return TextToolOutput(
      '$totalValues 个参数',
      '$table\n\nJSON:\n$jsonText',
      insights: [
        parsed.description,
        if (parsed.host != null) '主机: ${parsed.host}',
        if (parsed.path != null) '路径: ${parsed.path}',
        '已解析 $totalValues 个 query 参数，${params.length} 个唯一键。',
        if (repeatedKeys.isNotEmpty) '重复键: ${repeatedKeys.join(', ')}。',
        if (parsed.usedSemicolonSeparators) '已兼容分号分隔的表单参数。',
        if (parsed.usedLineSeparators) '已兼容换行分隔的表单参数。',
        if (parsed.fragment != null) '片段: ${parsed.fragment}',
      ],
    );
  }

  _UrlCodecResult? _tryDecodeUrlText(String input) {
    final source = _extractUrlCodecSource(input);
    final text = source.value;
    if (!_shouldDecodeUrlCodecText(text)) return null;
    try {
      if (_looksLikeAbsoluteUrl(text)) {
        return _UrlCodecResult(
          value: _decodeUrlPreservingQuery(text),
          mode: '完整 URL',
          decodedPlus: _rawUrlQuery(text)?.contains('+') ?? false,
          encodedQuery: _rawUrlQuery(text)?.isNotEmpty ?? false,
          queryParameterCount: _countQueryParameters(_rawUrlQuery(text)),
          percentTripletCount: _countPercentTriplets(text),
          sourceDescription: source.description,
        );
      }
      if (_looksLikeRelativeUrl(text)) {
        return _UrlCodecResult(
          value: _decodeUrlPreservingQuery(text),
          mode: '相对 URL',
          decodedPlus: _rawUrlQuery(text)?.contains('+') ?? false,
          encodedQuery: _rawUrlQuery(text)?.isNotEmpty ?? false,
          queryParameterCount: _countQueryParameters(_rawUrlQuery(text)),
          percentTripletCount: _countPercentTriplets(text),
          sourceDescription: source.description,
        );
      }
      if (_looksLikeQueryString(text)) {
        return _UrlCodecResult(
          value: _decodeQueryText(text),
          mode: 'query string',
          decodedPlus: text.contains('+'),
          encodedQuery: true,
          queryParameterCount: _countQueryParameters(text),
          percentTripletCount: _countPercentTriplets(text),
          sourceDescription: source.description,
        );
      }
      return _UrlCodecResult(
        value: Uri.decodeComponent(text),
        mode: 'URL 组件',
        decodedPlus: false,
        encodedQuery: false,
        queryParameterCount: 0,
        percentTripletCount: _countPercentTriplets(text),
        sourceDescription: source.description,
      );
    } on FormatException {
      throw const FormatException('URL 百分号编码不完整或无效。');
    }
  }

  bool _shouldDecodeUrlCodecText(String input) {
    if (RegExp(r'%[0-9a-fA-F]{2}').hasMatch(input)) return true;
    if (_looksLikeAbsoluteUrl(input) || _looksLikeRelativeUrl(input)) {
      return _rawUrlQuery(input)?.contains('+') ?? false;
    }
    return _looksLikeQueryString(input) && input.contains('+');
  }

  _UrlCodecResult _encodeUrlText(String input) {
    final source = _extractUrlCodecSource(input);
    final text = source.value;
    if (_looksLikeAbsoluteUrl(text)) {
      final uri = Uri.parse(text);
      if (uri.query.isEmpty) {
        return _UrlCodecResult(
          value: Uri.encodeFull(text),
          mode: '完整 URL',
          decodedPlus: false,
          encodedQuery: false,
          queryParameterCount: 0,
          percentTripletCount: _countPercentTriplets(Uri.encodeFull(text)),
          sourceDescription: source.description,
        );
      }
      return _UrlCodecResult(
        value: _encodeUrlQuery(uri),
        mode: '完整 URL',
        decodedPlus: false,
        encodedQuery: true,
        queryParameterCount: _countQueryParameters(uri.query),
        percentTripletCount: _countPercentTriplets(_encodeUrlQuery(uri)),
        sourceDescription: source.description,
      );
    }
    if (_looksLikeRelativeUrl(text)) {
      final uri = Uri.parse(text);
      final encoded = _encodeUrlQuery(uri);
      return _UrlCodecResult(
        value: encoded,
        mode: '相对 URL',
        decodedPlus: false,
        encodedQuery: uri.query.isNotEmpty,
        queryParameterCount: _countQueryParameters(uri.query),
        percentTripletCount: _countPercentTriplets(encoded),
        sourceDescription: source.description,
      );
    }
    if (_looksLikeQueryString(text)) {
      final encoded = _encodeQueryText(text);
      return _UrlCodecResult(
        value: encoded,
        mode: 'query string',
        decodedPlus: false,
        encodedQuery: true,
        queryParameterCount: _countQueryParameters(text),
        percentTripletCount: _countPercentTriplets(encoded),
        sourceDescription: source.description,
      );
    }
    final encoded = Uri.encodeComponent(text);
    return _UrlCodecResult(
      value: encoded,
      mode: 'URL 组件',
      decodedPlus: false,
      encodedQuery: false,
      queryParameterCount: 0,
      percentTripletCount: _countPercentTriplets(encoded),
      sourceDescription: source.description,
    );
  }

  bool _looksLikeAbsoluteUrl(String input) {
    return RegExp(r'^[a-z][a-z0-9+.-]*://', caseSensitive: false)
        .hasMatch(input);
  }

  bool _looksLikeRelativeUrl(String input) {
    final questionIndex = input.indexOf('?');
    if (questionIndex <= 0 || questionIndex == input.length - 1) return false;
    final path = input.substring(0, questionIndex);
    final query = input.substring(questionIndex + 1);
    return !path.contains('=') && query.contains('=');
  }

  bool _looksLikeQueryString(String input) {
    if (input.startsWith('?')) return true;
    return input.contains('=') && !input.contains('://');
  }

  _UrlCodecSource _extractUrlCodecSource(String input) {
    final curlUrl = _extractCurlUrl(input);
    if (curlUrl != null) {
      return _UrlCodecSource(curlUrl, 'curl 命令');
    }
    final requestTarget = _extractHttpRequestTarget(input);
    if (requestTarget != null) {
      return _UrlCodecSource(requestTarget, 'HTTP 请求行');
    }
    return _UrlCodecSource(input, null);
  }

  String _decodeUrlPreservingQuery(String input) {
    final questionIndex = input.indexOf('?');
    if (questionIndex < 0) return Uri.decodeFull(input);
    final fragmentIndex = input.indexOf('#', questionIndex + 1);
    final queryEnd = fragmentIndex < 0 ? input.length : fragmentIndex;
    final prefix = Uri.decodeFull(input.substring(0, questionIndex));
    final query =
        _decodeQueryText(input.substring(questionIndex + 1, queryEnd));
    if (fragmentIndex < 0) return '$prefix?$query';
    final fragment = Uri.decodeFull(input.substring(fragmentIndex + 1));
    return '$prefix?$query#$fragment';
  }

  String _decodeQueryText(String input) {
    final hasPrefix = input.startsWith('?');
    final source = hasPrefix ? input.substring(1) : input;
    final decoded = source.split('&').map((part) {
      final index = part.indexOf('=');
      if (index < 0) return Uri.decodeQueryComponent(part);
      final key = Uri.decodeQueryComponent(part.substring(0, index));
      final value = Uri.decodeQueryComponent(part.substring(index + 1));
      return '$key=$value';
    }).join('&');
    return hasPrefix ? '?$decoded' : decoded;
  }

  String _encodeUrlQuery(Uri uri) {
    final query = uri.queryParametersAll.entries.expand((entry) {
      return entry.value.isEmpty
          ? [Uri.encodeQueryComponent(entry.key)]
          : entry.value.map((value) =>
              '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(value)}');
    }).join('&');
    return uri.replace(query: query).toString();
  }

  String _encodeQueryText(String input) {
    final hasPrefix = input.startsWith('?');
    final source = hasPrefix ? input.substring(1) : input;
    final encoded = source.split('&').map((part) {
      final index = part.indexOf('=');
      if (index < 0) return Uri.encodeQueryComponent(part);
      return '${Uri.encodeQueryComponent(part.substring(0, index))}=${Uri.encodeQueryComponent(part.substring(index + 1))}';
    }).join('&');
    return hasPrefix ? '?$encoded' : encoded;
  }

  String? _rawUrlQuery(String input) {
    final questionIndex = input.indexOf('?');
    if (questionIndex < 0) return null;
    final fragmentIndex = input.indexOf('#', questionIndex + 1);
    return input.substring(
      questionIndex + 1,
      fragmentIndex < 0 ? input.length : fragmentIndex,
    );
  }

  int _countPercentTriplets(String input) {
    return RegExp(r'%[0-9a-fA-F]{2}').allMatches(input).length;
  }

  int _countQueryParameters(String? query) {
    if (query == null) return 0;
    final source = query.startsWith('?') ? query.substring(1) : query;
    if (source.isEmpty) return 0;
    return source.split('&').where((part) => part.isNotEmpty).length;
  }

  String _signedLengthDelta(int delta) {
    if (delta == 0) return '0';
    return delta > 0 ? '+$delta' : delta.toString();
  }

  _ParsedQueryInput _parseQueryInput(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return const _ParsedQueryInput(
        params: {},
        description: '输入为空。',
        usedSemicolonSeparators: false,
        usedLineSeparators: false,
      );
    }

    final curl = _parseCurlQueryInput(trimmed);
    if (curl != null) return curl;

    final requestTarget = _extractHttpRequestTarget(trimmed);
    final source = requestTarget ?? trimmed;
    final fromRequestLine = requestTarget != null;

    if (_looksLikeAbsoluteUrl(source)) {
      final uri = Uri.parse(source);
      return _queryInputFromUri(
        uri,
        description:
            fromRequestLine ? '输入识别为 HTTP 请求行中的完整 URL。' : '输入识别为完整 URL。',
      );
    }

    if (source.contains('?')) {
      final uri = Uri.parse(source);
      return _queryInputFromUri(
        uri,
        description: fromRequestLine ? '输入识别为 HTTP 请求行。' : '输入识别为相对 URL。',
      );
    }

    return _queryInputFromQuery(
      source.startsWith('?') ? source.substring(1) : source,
      description:
          fromRequestLine ? '输入识别为 HTTP 请求行。' : '输入识别为 query string / 表单正文。',
    );
  }

  String? _extractHttpRequestTarget(String input) {
    final firstLine = const LineSplitter()
        .convert(input)
        .firstWhere((line) => line.trim().isNotEmpty, orElse: () => '')
        .trim();
    final match = RegExp(
      r'^(GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS|TRACE|CONNECT)\s+(.+?)(?:\s+HTTP/\d(?:\.\d)?)?$',
      caseSensitive: false,
    ).firstMatch(firstLine);
    return match?.group(2)?.trim();
  }

  _ParsedQueryInput? _parseCurlQueryInput(String input) {
    final tokens = _tokenizeShellWords(input);
    if (!_isCurlCommand(tokens)) return null;

    String? url;
    final dataParts = <String>[];
    final urlQueryParts = <String>[];
    var sendsDataAsQuery = false;
    for (var i = 1; i < tokens.length; i++) {
      final token = tokens[i];
      if (token == '--') continue;
      if (_isCurlGetOption(token)) {
        sendsDataAsQuery = true;
        continue;
      }
      if (token == '--url' && i + 1 < tokens.length) {
        url = tokens[++i];
        continue;
      }
      if (token.startsWith('--url=')) {
        url = token.substring('--url='.length);
        continue;
      }

      final attachedUrlQuery = _curlAttachedUrlQueryValue(token);
      if (attachedUrlQuery != null) {
        _addCurlDataPart(urlQueryParts, attachedUrlQuery);
        continue;
      }
      if (_isCurlUrlQueryOption(token)) {
        if (i + 1 < tokens.length) {
          _addCurlDataPart(urlQueryParts, tokens[++i]);
        }
        continue;
      }

      final attachedData = _curlAttachedDataValue(token);
      if (attachedData != null) {
        _addCurlDataPart(dataParts, attachedData);
        continue;
      }
      if (_isCurlDataOption(token)) {
        if (i + 1 < tokens.length) _addCurlDataPart(dataParts, tokens[++i]);
        continue;
      }
      if (_curlOptionConsumesValue(token)) {
        if (i + 1 < tokens.length) i++;
        continue;
      }
      if (!token.startsWith('-') &&
          url == null &&
          (_looksLikeAbsoluteUrl(token) || token.contains('?'))) {
        url = token;
      }
    }

    final queryParts = [
      ...urlQueryParts,
      if (sendsDataAsQuery) ...dataParts,
    ];
    final effectiveUrl =
        url == null ? null : _appendQueryPartsToUrl(url, queryParts);
    final parsedUrl =
        effectiveUrl == null ? null : _parseUrlQuerySource(effectiveUrl);
    final parsedData = dataParts.isEmpty || sendsDataAsQuery
        ? null
        : _queryInputFromQuery(
            dataParts.join('&'),
            description: '输入识别为 curl 命令中的表单参数。',
          );
    if (parsedUrl == null && parsedData == null) {
      return const _ParsedQueryInput(
        params: {},
        description: '输入识别为 curl 命令，但未找到 URL query 或表单参数。',
        usedSemicolonSeparators: false,
        usedLineSeparators: false,
      );
    }

    final params = <String, List<String>>{};
    for (final source
        in [parsedUrl, parsedData].whereType<_ParsedQueryInput>()) {
      for (final entry in source.params.entries) {
        params.putIfAbsent(entry.key, () => <String>[]).addAll(entry.value);
      }
    }
    final description =
        urlQueryParts.isNotEmpty && sendsDataAsQuery && dataParts.isNotEmpty
            ? '输入识别为 curl 命令，已合并 --url-query 与 -G/--get 参数。'
            : urlQueryParts.isNotEmpty
                ? parsedData != null
                    ? '输入识别为 curl 命令，已合并 --url-query 与 -d/--data 表单参数。'
                    : '输入识别为 curl 命令，已合并 --url-query 参数。'
                : sendsDataAsQuery && dataParts.isNotEmpty && parsedUrl != null
                    ? '输入识别为 curl -G/--get 命令，已将 --data 参数合并为 URL query。'
                    : parsedUrl != null && parsedData != null
                        ? '输入识别为 curl 命令，已合并 URL query 与 -d/--data 表单参数。'
                        : parsedData != null
                            ? '输入识别为 curl 命令中的表单参数。'
                            : '输入识别为 curl 命令中的 URL。';
    return _ParsedQueryInput(
      params: params,
      description: description,
      host: parsedUrl?.host,
      path: parsedUrl?.path,
      fragment: parsedUrl?.fragment,
      usedSemicolonSeparators: (parsedUrl?.usedSemicolonSeparators ?? false) ||
          (parsedData?.usedSemicolonSeparators ?? false),
      usedLineSeparators: (parsedUrl?.usedLineSeparators ?? false) ||
          (parsedData?.usedLineSeparators ?? false),
    );
  }

  _ParsedQueryInput? _parseUrlQuerySource(String source) {
    if (_looksLikeAbsoluteUrl(source)) {
      return _queryInputFromUri(
        Uri.parse(source),
        description: '输入识别为 curl 命令中的完整 URL。',
      );
    }
    if (source.contains('?')) {
      return _queryInputFromUri(
        Uri.parse(source),
        description: '输入识别为 curl 命令中的相对 URL。',
      );
    }
    return null;
  }

  String? _extractCurlUrl(String input) {
    final tokens = _tokenizeShellWords(input);
    if (!_isCurlCommand(tokens)) return null;

    String? url;
    final dataParts = <String>[];
    final urlQueryParts = <String>[];
    var sendsDataAsQuery = false;
    for (var i = 1; i < tokens.length; i++) {
      final token = tokens[i];
      if (token == '--') continue;
      if (_isCurlGetOption(token)) {
        sendsDataAsQuery = true;
        continue;
      }
      if (token == '--url' && i + 1 < tokens.length) {
        url = tokens[++i];
        continue;
      }
      if (token.startsWith('--url=')) {
        url = token.substring('--url='.length);
        continue;
      }
      final attachedUrlQuery = _curlAttachedUrlQueryValue(token);
      if (attachedUrlQuery != null) {
        _addCurlDataPart(urlQueryParts, attachedUrlQuery);
        continue;
      }
      if (_isCurlUrlQueryOption(token)) {
        if (i + 1 < tokens.length) {
          _addCurlDataPart(urlQueryParts, tokens[++i]);
        }
        continue;
      }
      final attachedData = _curlAttachedDataValue(token);
      if (attachedData != null) {
        _addCurlDataPart(dataParts, attachedData);
        continue;
      }
      if (_isCurlDataOption(token)) {
        if (i + 1 < tokens.length) _addCurlDataPart(dataParts, tokens[++i]);
        continue;
      }
      if (_curlOptionConsumesValue(token)) {
        if (i + 1 < tokens.length) i++;
        continue;
      }
      if (!token.startsWith('-') &&
          (_looksLikeAbsoluteUrl(token) || _looksLikeRelativeUrl(token))) {
        url ??= token;
      }
    }
    if (url == null) return null;
    final queryParts = [
      ...urlQueryParts,
      if (sendsDataAsQuery) ...dataParts,
    ];
    return _appendQueryPartsToUrl(url, queryParts);
  }

  bool _isCurlCommand(List<String> tokens) {
    if (tokens.isEmpty) return false;
    final command = tokens.first.split('/').last.toLowerCase();
    return command == 'curl' || command == 'curl.exe';
  }

  List<String> _tokenizeShellWords(String input) {
    final normalized = input.replaceAll(RegExp(r'\\\r?\n'), ' ');
    final tokens = <String>[];
    final buffer = StringBuffer();
    String? quote;
    var ansiCQuote = false;

    void finishToken() {
      if (buffer.isEmpty) return;
      tokens.add(buffer.toString());
      buffer.clear();
    }

    for (var i = 0; i < normalized.length; i++) {
      final char = normalized[i];
      if (quote == null && char.trim().isEmpty) {
        finishToken();
        continue;
      }
      if (quote == null &&
          char == r'$' &&
          i + 1 < normalized.length &&
          normalized[i + 1] == "'") {
        quote = "'";
        ansiCQuote = true;
        i++;
        continue;
      }
      if (quote == null && (char == "'" || char == '"')) {
        quote = char;
        ansiCQuote = false;
        continue;
      }
      if (quote == char) {
        quote = null;
        ansiCQuote = false;
        continue;
      }
      if (ansiCQuote && char == r'\') {
        final decoded = _decodeShellAnsiEscape(normalized, i);
        buffer.write(decoded.$1);
        i = decoded.$2;
        continue;
      }
      if (char == r'\' && quote != "'") {
        if (i + 1 < normalized.length) {
          buffer.write(normalized[++i]);
        }
        continue;
      }
      buffer.write(char);
    }
    finishToken();
    return tokens;
  }

  (String, int) _decodeShellAnsiEscape(String input, int slashIndex) {
    if (slashIndex + 1 >= input.length) return (r'\', slashIndex);
    final next = input[slashIndex + 1];
    return switch (next) {
      'a' => (String.fromCharCode(0x07), slashIndex + 1),
      'b' => (String.fromCharCode(0x08), slashIndex + 1),
      'e' || 'E' => (String.fromCharCode(0x1b), slashIndex + 1),
      'f' => ('\f', slashIndex + 1),
      'n' => ('\n', slashIndex + 1),
      'r' => ('\r', slashIndex + 1),
      't' => ('\t', slashIndex + 1),
      'v' => (String.fromCharCode(0x0b), slashIndex + 1),
      r'\' => (r'\', slashIndex + 1),
      "'" => ("'", slashIndex + 1),
      '"' => ('"', slashIndex + 1),
      '?' => ('?', slashIndex + 1),
      'x' => _decodeShellAnsiCodeEscape(
          input,
          slashIndex,
          prefixLength: 2,
          maxDigits: 2,
          radix: 16,
        ),
      'u' => _decodeShellAnsiCodeEscape(
          input,
          slashIndex,
          prefixLength: 2,
          maxDigits: 4,
          minDigits: 4,
          radix: 16,
        ),
      'U' => _decodeShellAnsiCodeEscape(
          input,
          slashIndex,
          prefixLength: 2,
          maxDigits: 8,
          minDigits: 8,
          radix: 16,
        ),
      _ when _isRadixDigit(next.codeUnitAt(0), 8) => _decodeShellAnsiCodeEscape(
          input,
          slashIndex,
          prefixLength: 1,
          maxDigits: 3,
          radix: 8,
        ),
      _ => (next, slashIndex + 1),
    };
  }

  (String, int) _decodeShellAnsiCodeEscape(
    String input,
    int slashIndex, {
    required int prefixLength,
    required int maxDigits,
    required int radix,
    int minDigits = 1,
  }) {
    final start = slashIndex + prefixLength;
    var end = start;
    while (end < input.length &&
        end < start + maxDigits &&
        _isRadixDigit(input.codeUnitAt(end), radix)) {
      end++;
    }
    if (end - start < minDigits) {
      return (input.substring(slashIndex, start), start - 1);
    }
    final value = int.parse(input.substring(start, end), radix: radix);
    if (value > 0x10ffff) {
      return (input.substring(slashIndex, end), end - 1);
    }
    return (String.fromCharCode(value), end - 1);
  }

  bool _isRadixDigit(int codeUnit, int radix) {
    if (codeUnit >= 0x30 && codeUnit <= 0x39) {
      return codeUnit - 0x30 < radix;
    }
    if (radix <= 10) return false;
    final lower = codeUnit | 0x20;
    return lower >= 0x61 && lower < 0x61 + radix - 10;
  }

  bool _isCurlDataOption(String option) {
    return const {
      '-d',
      '--data',
      '--data-raw',
      '--data-binary',
      '--data-ascii',
      '--data-urlencode',
    }.contains(option);
  }

  bool _isCurlGetOption(String option) {
    return option == '-G' || option == '--get';
  }

  bool _isCurlUrlQueryOption(String option) {
    return option == '--url-query';
  }

  String? _curlAttachedUrlQueryValue(String option) {
    if (option.startsWith('--url-query=')) {
      return option.substring('--url-query='.length);
    }
    return null;
  }

  String? _curlAttachedDataValue(String option) {
    for (final name in const [
      '--data',
      '--data-raw',
      '--data-binary',
      '--data-ascii',
      '--data-urlencode',
    ]) {
      if (option.startsWith('$name=')) {
        return option.substring(name.length + 1);
      }
    }
    if (option.startsWith('-d') && option.length > 2) {
      return option.substring(2);
    }
    return null;
  }

  void _addCurlDataPart(List<String> dataParts, String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty ||
        trimmed.startsWith('@') ||
        trimmed.startsWith('{') ||
        trimmed.startsWith('[') ||
        !trimmed.contains('=')) {
      return;
    }
    dataParts.add(trimmed.replaceFirst(RegExp(r'^\?+'), ''));
  }

  String _appendQueryPartsToUrl(String url, List<String> dataParts) {
    if (dataParts.isEmpty) return url;
    final query = dataParts.join('&');
    final fragmentIndex = url.indexOf('#');
    final head = fragmentIndex < 0 ? url : url.substring(0, fragmentIndex);
    final fragment = fragmentIndex < 0 ? '' : url.substring(fragmentIndex);
    final separator = head.contains('?')
        ? head.endsWith('?') || head.endsWith('&')
            ? ''
            : '&'
        : '?';
    return '$head$separator$query$fragment';
  }

  bool _curlOptionConsumesValue(String option) {
    return const {
      '-X',
      '--request',
      '-H',
      '--header',
      '-A',
      '--user-agent',
      '-u',
      '--user',
      '-b',
      '--cookie',
      '-o',
      '--output',
      '-x',
      '--proxy',
      '--connect-timeout',
      '--max-time',
    }.contains(option);
  }

  _ParsedQueryInput _queryInputFromUri(
    Uri uri, {
    required String description,
  }) {
    var query = uri.query;
    var resolvedDescription = description;
    if (query.isEmpty) {
      final fragmentQuery = _queryFromFragment(uri.fragment);
      if (fragmentQuery != null) {
        query = fragmentQuery;
        resolvedDescription = '输入识别为 URL 片段中的 query。';
      }
    }
    return _queryInputFromQuery(
      query,
      description: resolvedDescription,
      host: uri.host.isEmpty ? null : uri.host,
      path: uri.path.isEmpty ? null : uri.path,
      fragment: uri.fragment.isEmpty ? null : uri.fragment,
    );
  }

  String? _queryFromFragment(String fragment) {
    final index = fragment.indexOf('?');
    if (index < 0 || index == fragment.length - 1) return null;
    return fragment.substring(index + 1);
  }

  _ParsedQueryInput _queryInputFromQuery(
    String query, {
    required String description,
    String? host,
    String? path,
    String? fragment,
  }) {
    final normalized = query.trim().replaceFirst(RegExp(r'^\?+'), '');
    final useSemicolons = _shouldTreatSemicolonAsQuerySeparator(normalized);
    final useLines = _shouldTreatLinesAsQuerySeparator(normalized);
    final pairSource = useLines
        ? normalized
            .split(RegExp(r'\r?\n+'))
            .map((line) => line.trim())
            .join('&')
        : useSemicolons
            ? normalized.replaceAll(';', '&')
            : normalized;
    final params = <String, List<String>>{};
    for (final part in pairSource.split('&')) {
      if (part.isEmpty) continue;
      final equalsIndex = part.indexOf('=');
      final rawKey = equalsIndex < 0 ? part : part.substring(0, equalsIndex);
      final rawValue = equalsIndex < 0 ? '' : part.substring(equalsIndex + 1);
      final key = Uri.decodeQueryComponent(rawKey);
      final value = Uri.decodeQueryComponent(rawValue);
      params.putIfAbsent(key, () => <String>[]).add(value);
    }
    return _ParsedQueryInput(
      params: params,
      description: description,
      host: host,
      path: path,
      fragment: fragment,
      usedSemicolonSeparators: useSemicolons,
      usedLineSeparators: useLines,
    );
  }

  bool _shouldTreatLinesAsQuerySeparator(String query) {
    if (!query.contains('\n') && !query.contains('\r')) return false;
    final lines = const LineSplitter()
        .convert(query)
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.length < 2 || !lines.first.contains('=')) return false;
    return lines.skip(1).any((line) => line.contains('=')) &&
        lines.every((line) {
          final equalsIndex = line.indexOf('=');
          if (equalsIndex < 0) return _looksLikeQueryKey(line);
          final ampIndex = line.indexOf('&');
          return equalsIndex > 0 && (ampIndex < 0 || equalsIndex < ampIndex);
        });
  }

  bool _looksLikeQueryKey(String value) {
    return RegExp(r'^[A-Za-z0-9_.~%+\-\[\]]+$').hasMatch(value);
  }

  bool _shouldTreatSemicolonAsQuerySeparator(String query) {
    if (!query.contains(';')) return false;
    final segments = query.split(';');
    if (segments.length < 2 || !segments.first.contains('=')) return false;
    final tail = segments.skip(1).toList();
    final hasAnotherKeyValue = tail.any((segment) {
      final equalsIndex = segment.indexOf('=');
      final ampIndex = segment.indexOf('&');
      return equalsIndex > 0 && (ampIndex < 0 || equalsIndex < ampIndex);
    });
    if (!hasAnotherKeyValue) return false;
    return tail.every((segment) {
      if (segment.trim().isEmpty) return false;
      final equalsIndex = segment.indexOf('=');
      if (equalsIndex < 0) return true;
      final ampIndex = segment.indexOf('&');
      return ampIndex < 0 || equalsIndex < ampIndex;
    });
  }
}
