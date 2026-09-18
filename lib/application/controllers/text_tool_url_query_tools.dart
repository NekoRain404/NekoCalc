part of 'text_tool_controller.dart';

// 中文：`_ParsedQueryInput.description` 有十八种来路（完整 URL、HTTP 请求行、curl 的各种
//       `-d/--data` 与 `--url-query` 组合……）。它们**全是界面文案，一条判据也没有**：
//       每个调用点先按输入的形状挑好一句，再存进字段；`description` 从不被比较，只被显示。
//       所以这里的改法是"把表顺着参数递下去"，挑哪一句的逻辑一个字都没动。
// English: `_ParsedQueryInput.description` has eighteen provenances (a full URL, an HTTP request
//          line, the various `-d/--data` and `--url-query` combinations of curl …). **They are all
//          interface copy and not one of them is a branch condition**: each call site picks a
//          sentence according to the shape of the input and stores it in the field; `description` is
//          never compared, only shown. So the change here is "hand the table down through the
//          parameters", and the logic that picks which sentence is untouched.
extension _TextToolUrlQueryTools on TextToolController {
  TextToolOutput _queryParams(TextToolWebStrings strings, String input) {
    final parsed = _parseQueryInput(strings, input);
    final params = parsed.params;
    if (params.isEmpty) {
      return TextToolOutput(strings.noParameters, strings.noParametersDetail);
    }
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
      strings.parameterCount(totalValues),
      '$table\n\nJSON:\n$jsonText',
      insights: [
        parsed.description,
        if (parsed.host != null) strings.hostLine(parsed.host!),
        if (parsed.path != null) strings.pathLine(parsed.path!),
        strings.parsedSummary(totalValues, params.length),
        if (repeatedKeys.isNotEmpty)
          strings.repeatedKeys(repeatedKeys.join(', ')),
        if (parsed.usedSemicolonSeparators) strings.semicolonSeparators,
        if (parsed.usedLineSeparators) strings.lineSeparators,
        if (parsed.fragment != null) strings.fragmentLine(parsed.fragment!),
      ],
    );
  }

  _ParsedQueryInput _parseQueryInput(TextToolWebStrings strings, String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return _ParsedQueryInput(
        params: const {},
        description: strings.emptyInput,
        usedSemicolonSeparators: false,
        usedLineSeparators: false,
      );
    }

    final curl = _parseCurlQueryInput(strings, trimmed);
    if (curl != null) return curl;

    final requestTarget = _extractHttpRequestTarget(trimmed);
    final source = requestTarget ?? trimmed;
    final fromRequestLine = requestTarget != null;

    if (_looksLikeAbsoluteUrl(source)) {
      final uri = Uri.parse(source);
      return _queryInputFromUri(
        strings,
        uri,
        description: fromRequestLine
            ? strings.inputFullUrlInRequestLine
            : strings.inputFullUrl,
      );
    }

    if (source.contains('?')) {
      final uri = Uri.parse(source);
      return _queryInputFromUri(
        strings,
        uri,
        description: fromRequestLine
            ? strings.inputRequestLine
            : strings.inputRelativeUrl,
      );
    }

    return _queryInputFromQuery(
      source.startsWith('?') ? source.substring(1) : source,
      description: fromRequestLine
          ? strings.inputRequestLine
          : strings.inputQueryStringOrForm,
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

  _ParsedQueryInput? _parseCurlQueryInput(
    TextToolWebStrings strings,
    String input,
  ) {
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
        effectiveUrl == null ? null : _parseUrlQuerySource(strings, effectiveUrl);
    final parsedData = dataParts.isEmpty || sendsDataAsQuery
        ? null
        : _queryInputFromQuery(
            dataParts.join('&'),
            description: strings.inputCurlFormFields,
          );
    if (parsedUrl == null && parsedData == null) {
      return _ParsedQueryInput(
        params: const {},
        description: strings.inputCurlNoQueryFound,
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
            ? strings.inputCurlMergedUrlQueryAndGet
            : urlQueryParts.isNotEmpty
                ? parsedData != null
                    ? strings.inputCurlMergedUrlQueryAndData
                    : strings.inputCurlMergedUrlQuery
                : sendsDataAsQuery && dataParts.isNotEmpty && parsedUrl != null
                    ? strings.inputCurlGetMergedData
                    : parsedUrl != null && parsedData != null
                        ? strings.inputCurlMergedQueryAndData
                        : parsedData != null
                            ? strings.inputCurlFormFields
                            : strings.inputCurlUrl;
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

  _ParsedQueryInput? _parseUrlQuerySource(
    TextToolWebStrings strings,
    String source,
  ) {
    if (_looksLikeAbsoluteUrl(source)) {
      return _queryInputFromUri(
        strings,
        Uri.parse(source),
        description: strings.inputCurlFullUrl,
      );
    }
    if (source.contains('?')) {
      return _queryInputFromUri(
        strings,
        Uri.parse(source),
        description: strings.inputCurlRelativeUrl,
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
    TextToolWebStrings strings,
    Uri uri, {
    required String description,
  }) {
    var query = uri.query;
    var resolvedDescription = description;
    if (query.isEmpty) {
      final fragmentQuery = _queryFromFragment(uri.fragment);
      if (fragmentQuery != null) {
        query = fragmentQuery;
        resolvedDescription = strings.inputUrlFragmentQuery;
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
