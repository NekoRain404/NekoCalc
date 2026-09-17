part of 'text_tool_controller.dart';

extension _TextToolUrlCodecTools on TextToolController {
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
}
