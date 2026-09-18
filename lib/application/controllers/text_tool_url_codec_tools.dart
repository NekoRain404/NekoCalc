part of 'text_tool_controller.dart';

// 中文：`mode` 与 `sourceDescription` 是**描述符**，不是判据——它们只被插进下面这几句输出里，
//       反向不参与任何 `==` / `switch`。所以它们与 `radixLabel` 同形：解析阶段从表里取一句
//       定好的话存进字段，输出阶段只负责拼。`query string` 那一格两侧逐字节相同，
//       它照样进表——表管的是"这一格由谁供给"，不是"这一格有没有汉字"。
// English: `mode` and `sourceDescription` are **descriptors**, not branch conditions — they are only
//          interpolated into the output below and never branch in an `==` or a `switch`. So they
//          have the same shape as `radixLabel`: the parse stage reads a settled sentence out of the
//          table into the field, and the output stage only joins. The `query string` slot reads the
//          same on both sides and still goes through the table: a table decides **who supplies the
//          slot**, not whether the slot contains Chinese.
extension _TextToolUrlCodecTools on TextToolController {
  TextToolOutput _urlCodec(TextToolWebStrings strings, String input) {
    final decoded = _tryDecodeUrlText(strings, input);
    if (decoded != null) {
      return TextToolOutput(
        decoded.value,
        [
          strings.modeLabel(decoded.mode),
          strings.originalLength(input.length),
          strings.resultLength(decoded.value.length),
          strings.lengthDelta(
              _signedLengthDelta(decoded.value.length - input.length)),
          if (decoded.queryParameterCount > 0)
            strings.queryParameterCount(decoded.queryParameterCount),
          if (decoded.percentTripletCount > 0)
            strings.percentTripletCount(decoded.percentTripletCount),
        ].join('\n'),
        insights: [
          if (decoded.sourceDescription != null)
            strings.extractedFrom(decoded.sourceDescription!),
          strings.decodedByMode(decoded.mode),
          if (decoded.decodedPlus) strings.plusAsSpace,
          if (decoded.queryParameterCount > 0) strings.queryCountEstimated,
        ],
      );
    }
    final encoded = _encodeUrlText(strings, input);
    return TextToolOutput(
      encoded.value,
      [
        strings.modeLabel(encoded.mode),
        strings.originalLength(input.length),
        strings.resultLength(encoded.value.length),
        strings.lengthDelta(
            _signedLengthDelta(encoded.value.length - input.length)),
        if (encoded.queryParameterCount > 0)
          strings.queryParameterCount(encoded.queryParameterCount),
        if (encoded.percentTripletCount > 0)
          strings.percentTripletCount(encoded.percentTripletCount),
      ].join('\n'),
      insights: [
        if (encoded.sourceDescription != null)
          strings.extractedFrom(encoded.sourceDescription!),
        strings.encodedByMode(encoded.mode),
        if (encoded.encodedQuery) strings.queryKeysEncoded,
        if (encoded.queryParameterCount > 0) strings.queryCountEstimated,
      ],
    );
  }

  _UrlCodecResult? _tryDecodeUrlText(TextToolWebStrings strings, String input) {
    final source = _extractUrlCodecSource(strings, input);
    final text = source.value;
    if (!_shouldDecodeUrlCodecText(text)) return null;
    try {
      if (_looksLikeAbsoluteUrl(text)) {
        return _UrlCodecResult(
          value: _decodeUrlPreservingQuery(text),
          mode: strings.modeFullUrl,
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
          mode: strings.modeRelativeUrl,
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
          mode: strings.modeQueryString,
          decodedPlus: text.contains('+'),
          encodedQuery: true,
          queryParameterCount: _countQueryParameters(text),
          percentTripletCount: _countPercentTriplets(text),
          sourceDescription: source.description,
        );
      }
      return _UrlCodecResult(
        value: Uri.decodeComponent(text),
        mode: strings.modeUrlComponent,
        decodedPlus: false,
        encodedQuery: false,
        queryParameterCount: 0,
        percentTripletCount: _countPercentTriplets(text),
        sourceDescription: source.description,
      );
    } on FormatException {
      throw FormatException(strings.invalidPercentEncoding);
    }
  }

  bool _shouldDecodeUrlCodecText(String input) {
    if (RegExp(r'%[0-9a-fA-F]{2}').hasMatch(input)) return true;
    if (_looksLikeAbsoluteUrl(input) || _looksLikeRelativeUrl(input)) {
      return _rawUrlQuery(input)?.contains('+') ?? false;
    }
    return _looksLikeQueryString(input) && input.contains('+');
  }

  _UrlCodecResult _encodeUrlText(TextToolWebStrings strings, String input) {
    final source = _extractUrlCodecSource(strings, input);
    final text = source.value;
    if (_looksLikeAbsoluteUrl(text)) {
      final uri = Uri.parse(text);
      if (uri.query.isEmpty) {
        return _UrlCodecResult(
          value: Uri.encodeFull(text),
          mode: strings.modeFullUrl,
          decodedPlus: false,
          encodedQuery: false,
          queryParameterCount: 0,
          percentTripletCount: _countPercentTriplets(Uri.encodeFull(text)),
          sourceDescription: source.description,
        );
      }
      return _UrlCodecResult(
        value: _encodeUrlQuery(uri),
        mode: strings.modeFullUrl,
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
        mode: strings.modeRelativeUrl,
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
        mode: strings.modeQueryString,
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
      mode: strings.modeUrlComponent,
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

  _UrlCodecSource _extractUrlCodecSource(
    TextToolWebStrings strings,
    String input,
  ) {
    final curlUrl = _extractCurlUrl(input);
    if (curlUrl != null) {
      return _UrlCodecSource(curlUrl, strings.sourceCurlCommand);
    }
    final requestTarget = _extractHttpRequestTarget(input);
    if (requestTarget != null) {
      return _UrlCodecSource(requestTarget, strings.sourceHttpRequestLine);
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
