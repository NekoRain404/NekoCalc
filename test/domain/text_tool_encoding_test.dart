import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/controllers/text_tool_controller.dart';
import 'package:nekocalc/features/tools/presentation/text_tool_strings.dart';
import 'package:nekocalc/l10n/app_language.dart';

void main() {
  const controller = TextToolController();

  test('base64 tool still detects plain text and encoded text', () {
    final encoded = controller.calculate(
        strings: _strings, toolId: 'base64', input: 'NekoCalc');
    final decoded = controller.calculate(
        strings: _strings, toolId: 'base64', input: encoded.primary);

    expect(encoded.primary, 'TmVrb0NhbGM=');
    expect(encoded.detail, contains('标准 Base64'));
    expect(encoded.detail, contains('Base64URL: TmVrb0NhbGM'));
    expect(encoded.detail,
        contains('data:text/plain;charset=utf-8;base64,TmVrb0NhbGM='));
    expect(
        encoded.insights, contains('详情同时提供 URL-safe 写法和 text/plain data URL。'));
    expect(decoded.primary, 'NekoCalc');
    expect(decoded.detail, contains('字节数: 8'));
    expect(decoded.detail, contains('标准 Base64: TmVrb0NhbGM='));
    expect(decoded.detail, contains('Base64URL: TmVrb0NhbGM'));
    expect(decoded.insights.join('\n'), contains('检测为 Base64 输入'));
  });

  test('base64 tool supports data urls url safe payloads and wrapped text', () {
    final dataUrl = controller.calculate(
      strings: _strings,
      toolId: 'base64',
      input: 'data:text/plain;base64,SGVsbG8sIE5la29DYWxjIQ==',
    );
    final urlSafe = controller.calculate(
        strings: _strings, toolId: 'base64', input: '8J-RiA');
    final wrapped = controller.calculate(
      strings: _strings,
      toolId: 'base64',
      input: 'SGVs\nbG8=',
    );

    expect(dataUrl.primary, 'Hello, NekoCalc!');
    expect(dataUrl.detail, contains('MIME: text/plain'));
    expect(dataUrl.detail,
        contains('data URL: data:text/plain;base64,SGVsbG8sIE5la29DYWxjIQ=='));
    expect(dataUrl.insights.join('\n'), contains('data URL Base64'));
    expect(dataUrl.insights, contains('详情中已重建可复制的 data URL。'));

    expect(urlSafe.primary, '👈');
    expect(urlSafe.detail, contains('格式: Base64URL'));
    expect(urlSafe.detail, contains('标准 Base64: 8J+RiA=='));
    expect(urlSafe.insights, contains('已识别 URL-safe 字符集，详情同时给出标准 Base64。'));

    expect(wrapped.primary, 'Hello');
    expect(wrapped.insights, contains('已忽略输入中的空白和换行。'));
  });

  test('base64 tool extracts payloads from labeled text', () {
    final labeled = controller.calculate(
      strings: _strings,
      toolId: 'base64',
      input: 'base64: SGVsbG8=',
    );
    final json = controller.calculate(
      strings: _strings,
      toolId: 'base64',
      input: '{"payload":"TmVrb0NhbGM="}',
    );
    final log = controller.calculate(
      strings: _strings,
      toolId: 'base64',
      input: 'decoded payload=VGVzdA== status=ok',
    );

    expect(labeled.primary, 'Hello');
    expect(labeled.insights, contains('已从带标签文本中提取 Base64 payload 解码。'));

    expect(json.primary, 'NekoCalc');
    expect(json.insights, contains('已从带标签文本中提取 Base64 payload 解码。'));

    expect(log.primary, 'Test');
  });

  test('base64 tool extracts payloads from pem and markdown blocks', () {
    final pem = controller.calculate(
      strings: _strings,
      toolId: 'base64',
      input: '''
-----BEGIN MESSAGE-----
SGVsbG8sIE5la29DYWxjIQ==
-----END MESSAGE-----
''',
    );
    final markdown = controller.calculate(
      strings: _strings,
      toolId: 'base64',
      input: '''
```base64
TmVrb0NhbGM=
```
''',
    );

    expect(pem.primary, 'Hello, NekoCalc!');
    expect(pem.insights, contains('已从 PEM 块中提取 Base64 payload 解码。'));

    expect(markdown.primary, 'NekoCalc');
    expect(
      markdown.insights,
      contains('已从 Markdown 代码块中提取 Base64 payload 解码。'),
    );
  });

  test('url codec handles full urls query strings and encoded plus', () {
    final encodedUrl = controller.calculate(
      strings: _strings,
      toolId: 'url_codec',
      input: 'https://example.com/search?q=Neko Calc&lang=中文',
    );
    final decodedQuery = controller.calculate(
      strings: _strings,
      toolId: 'url_codec',
      input: 'q=Neko+Calc&lang=%E4%B8%AD%E6%96%87',
    );
    final component = controller.calculate(
      strings: _strings,
      toolId: 'url_codec',
      input: 'Neko Calc/中文',
    );
    final plusOnlyQuery = controller.calculate(
      strings: _strings,
      toolId: 'url_codec',
      input: 'q=Neko+Calc&tag=graph+tool',
    );
    final plusOnlyUrl = controller.calculate(
      strings: _strings,
      toolId: 'url_codec',
      input: 'https://example.com/search?q=Neko+Calc&tag=graph+tool',
    );

    expect(
      encodedUrl.primary,
      'https://example.com/search?q=Neko+Calc&lang=%E4%B8%AD%E6%96%87',
    );
    expect(encodedUrl.detail, contains('模式: 完整 URL'));
    expect(encodedUrl.detail, contains('长度变化:'));
    expect(encodedUrl.detail, contains('Query 参数: 2 个'));
    expect(encodedUrl.detail, contains('百分号编码片段:'));
    expect(encodedUrl.insights, contains('已保留 URL 结构，仅编码 query 键和值。'));
    expect(encodedUrl.insights, contains('Query 参数数量按 & 分隔估算，重复键未在此处合并。'));

    expect(decodedQuery.primary, 'q=Neko Calc&lang=中文');
    expect(decodedQuery.detail, contains('Query 参数: 2 个'));
    expect(decodedQuery.insights, contains('Query 中的 + 已按空格处理。'));

    expect(plusOnlyQuery.primary, 'q=Neko Calc&tag=graph tool');
    expect(plusOnlyQuery.insights, contains('Query 中的 + 已按空格处理。'));

    expect(
      plusOnlyUrl.primary,
      'https://example.com/search?q=Neko Calc&tag=graph tool',
    );
    expect(plusOnlyUrl.insights, contains('Query 中的 + 已按空格处理。'));

    expect(component.primary, 'Neko%20Calc%2F%E4%B8%AD%E6%96%87');
    expect(component.detail, contains('模式: URL 组件'));
    expect(component.detail, contains('百分号编码片段: 8 个'));
  });

  test('url codec extracts urls from request lines and curl commands', () {
    final request = controller.calculate(
      strings: _strings,
      toolId: 'url_codec',
      input: 'GET /search?q=Neko+Calc&lang=%E4%B8%AD%E6%96%87 HTTP/1.1',
    );
    final curl = controller.calculate(
      strings: _strings,
      toolId: 'url_codec',
      input:
          "curl 'https://example.com/search?q=Neko+Calc&lang=%E4%B8%AD%E6%96%87' -H 'Accept: application/json'",
    );
    final encodedRequest = controller.calculate(
      strings: _strings,
      toolId: 'url_codec',
      input: 'GET /search?q=Neko Calc&lang=中文 HTTP/1.1',
    );
    final encodedCurl = controller.calculate(
      strings: _strings,
      toolId: 'url_codec',
      input: "curl --url 'https://example.com/search?q=Neko Calc&lang=中文'",
    );
    final curlGet = controller.calculate(
      strings: _strings,
      toolId: 'url_codec',
      input:
          "curl -G 'https://example.com/search?page=1' --data-urlencode 'q=Neko Calc'",
    );
    final curlUrlQuery = controller.calculate(
      strings: _strings,
      toolId: 'url_codec',
      input:
          "curl --url 'https://example.com/search?page=1#top' --url-query 'q=Neko Calc' --url-query=lang=中文",
    );
    final curlAnsiQuoted = controller.calculate(
      strings: _strings,
      toolId: 'url_codec',
      input:
          r"curl $'https://example.com/search?q=Neko\x20Calc&lang=\u4e2d\u6587'",
    );

    expect(request.primary, '/search?q=Neko Calc&lang=中文');
    expect(request.detail, contains('模式: 相对 URL'));
    expect(request.insights.join('\n'), contains('HTTP 请求行'));
    expect(request.insights, contains('Query 中的 + 已按空格处理。'));

    expect(curl.primary, 'https://example.com/search?q=Neko Calc&lang=中文');
    expect(curl.insights.join('\n'), contains('curl 命令'));

    expect(
      encodedRequest.primary,
      '/search?q=Neko+Calc&lang=%E4%B8%AD%E6%96%87',
    );
    expect(encodedRequest.insights.join('\n'), contains('HTTP 请求行'));

    expect(
      encodedCurl.primary,
      'https://example.com/search?q=Neko+Calc&lang=%E4%B8%AD%E6%96%87',
    );
    expect(encodedCurl.insights.join('\n'), contains('curl 命令'));

    expect(curlGet.primary, 'https://example.com/search?page=1&q=Neko+Calc');
    expect(curlGet.insights.join('\n'), contains('curl 命令'));

    expect(
      curlUrlQuery.primary,
      'https://example.com/search?page=1&q=Neko+Calc&lang=%E4%B8%AD%E6%96%87#top',
    );
    expect(curlUrlQuery.insights.join('\n'), contains('curl 命令'));

    expect(
      curlAnsiQuoted.primary,
      'https://example.com/search?q=Neko+Calc&lang=%E4%B8%AD%E6%96%87',
    );
    expect(curlAnsiQuoted.insights.join('\n'), contains('curl 命令'));
  });

  test('url codec preserves leading question mark for query strings', () {
    final decoded = controller.calculate(
      strings: _strings,
      toolId: 'url_codec',
      input: '?q=Neko+Calc&lang=%E4%B8%AD%E6%96%87',
    );
    final encoded = controller.calculate(
      strings: _strings,
      toolId: 'url_codec',
      input: '?q=Neko Calc&lang=中文',
    );

    expect(decoded.primary, '?q=Neko Calc&lang=中文');
    expect(decoded.insights, contains('Query 中的 + 已按空格处理。'));
    expect(encoded.primary, '?q=Neko+Calc&lang=%E4%B8%AD%E6%96%87');
  });

  test('html entity codec handles numeric entities and keeps unknown ones', () {
    final decoded = controller.calculate(
      strings: _strings,
      toolId: 'html_entities',
      input:
          '&lt;span title=&quot;Neko&quot;&gt;&#x4E2D;&#25991;&nbsp;&unknown;</span>',
    );
    final encoded = controller.calculate(
      strings: _strings,
      toolId: 'html_entities',
      input: '<span title="Neko">中文 & tools</span>',
    );

    expect(decoded.primary, contains('<span title="Neko">中文'));
    expect(decoded.primary, contains('&unknown;'));
    expect(decoded.detail, contains('未知实体: 1'));
    expect(decoded.insights.join('\n'), contains('数字实体'));

    expect(
      encoded.primary,
      '&lt;span title=&quot;Neko&quot;&gt;中文 &amp; tools&lt;/span&gt;',
    );
    expect(encoded.insights.join('\n'), contains('不间断空格'));
  });

  test('html entity codec decodes common named entities', () {
    final decoded = controller.calculate(
      strings: _strings,
      toolId: 'html_entities',
      input:
          'Price &euro;9.99 &middot; Neko&rsquo;s &le; 10&Prime; &Alpha;&alpha; &unknown;',
    );

    expect(decoded.primary, 'Price €9.99 · Neko’s ≤ 10″ Αα &unknown;');
    expect(decoded.detail, contains('已解码 7 处实体'));
    expect(decoded.detail, contains('未知实体: 1'));
  });

  test('ascii unicode analyzes characters and decodes code point notation', () {
    final analyzed = controller.calculate(
      strings: _strings,
      toolId: 'ascii_unicode',
      input: 'A中👈',
    );
    final decoded = controller.calculate(
      strings: _strings,
      toolId: 'ascii_unicode',
      input: r'U+0041 \u4E2D \u{1F448} &#25991;',
    );
    final decimal = controller.calculate(
      strings: _strings,
      toolId: 'ascii_unicode',
      input: '65, 20013, 128072',
    );

    expect(analyzed.primary, '3 个码点');
    expect(analyzed.detail, contains('可见字符: 3'));
    expect(analyzed.detail, contains('UTF-16 code units: 4'));
    expect(analyzed.detail, contains('A  dec:65  U+0041'));
    expect(analyzed.detail, contains('👈  dec:128072  U+1F448'));
    expect(analyzed.detail, contains('UTF-16:D83D DC48'));
    expect(analyzed.detail, contains('UTF-32:1F448'));
    expect(analyzed.detail, contains('HTML:&#128072;/&#x1F448;'));
    expect(analyzed.insights.join('\n'), contains('UTF-8 字节'));
    expect(analyzed.insights, contains('字符分类: 中文/汉字 1，拉丁字母 1，标点/符号 1。'));

    expect(decoded.primary, 'A中👈文');
    expect(decoded.insights.join('\n'), contains('Unicode 码点/转义输入'));
    expect(decoded.insights, contains('字符分类: 中文/汉字 2，拉丁字母 1，标点/符号 1。'));

    expect(decimal.primary, 'A中👈');
    expect(decimal.detail, contains('U+1F448'));
  });

  test('ascii unicode reports invalid code points', () {
    final invalid = controller.calculate(
      strings: _strings,
      toolId: 'ascii_unicode',
      input: 'U+110000',
    );

    expect(invalid.primary, '输入无效');
    expect(invalid.detail, contains('Unicode 码点无效'));
    expect(invalid.insights, contains('请检查输入格式后重试。'));
  });

  test('checksum accepts text and hex byte input', () {
    final text = controller.calculate(
        strings: _strings, toolId: 'checksum', input: 'ABC');
    final hex = controller.calculate(
        strings: _strings, toolId: 'checksum', input: '41 42 43');
    final prefixedHex = controller.calculate(
      strings: _strings,
      toolId: 'checksum',
      input: 'const uint8_t data[] = {0x41, 0x42, 0x43};',
    );
    final decimal = controller.calculate(
      strings: _strings,
      toolId: 'checksum',
      input: '[65, 66, 67]',
    );
    final base64Bytes = controller.calculate(
      strings: _strings,
      toolId: 'checksum',
      input: 'base64: QUJD',
    );
    final dataUrlBytes = controller.calculate(
      strings: _strings,
      toolId: 'checksum',
      input: 'data:application/octet-stream;base64,QUJD',
    );

    expect(text.primary, 'SUM8 = 0xC6');
    expect(text.detail, contains('输入模式: UTF-8 文本'));
    expect(text.detail, contains('XOR8: 64 (0x40)'));

    expect(hex.primary, 'SUM8 = 0xC6');
    expect(hex.detail, contains('输入模式: 十六进制字节'));
    expect(hex.detail, contains('HEX: 41 42 43'));
    expect(hex.insights, contains('输入识别为十六进制字节序列。'));

    expect(prefixedHex.primary, 'SUM8 = 0xC6');
    expect(prefixedHex.detail, contains('输入模式: 十六进制字节'));
    expect(prefixedHex.insights.join('\n'), contains('十六进制字节数组'));

    expect(decimal.primary, 'SUM8 = 0xC6');
    expect(decimal.detail, contains('输入模式: 十进制字节'));
    expect(decimal.detail, contains('HEX: 41 42 43'));
    expect(decimal.insights, contains('输入识别为十进制字节列表。'));

    expect(base64Bytes.primary, 'SUM8 = 0xC6');
    expect(base64Bytes.detail, contains('输入模式: Base64 字节'));
    expect(base64Bytes.detail, contains('HEX: 41 42 43'));
    expect(
      base64Bytes.insights,
      contains('已从带标签文本中提取 Base64 payload 解码。'),
    );

    expect(dataUrlBytes.primary, 'SUM8 = 0xC6');
    expect(dataUrlBytes.detail, contains('输入模式: Base64 字节'));
    expect(dataUrlBytes.insights,
        contains('检测为 data URL Base64 输入，已提取 payload 解码。'));
  });

  test('fnv crc accepts hex bytes and reports invalid byte text', () {
    final text = controller.calculate(
        strings: _strings, toolId: 'fnv_crc', input: '123456789');
    final hex = controller.calculate(
      strings: _strings,
      toolId: 'fnv_crc',
      input: r'\x31 \x32 \x33 \x34 \x35 \x36 \x37 \x38 \x39',
    );
    final base64Bytes = controller.calculate(
      strings: _strings,
      toolId: 'fnv_crc',
      input: 'base64: MTIzNDU2Nzg5',
    );
    final invalid = controller.calculate(
        strings: _strings, toolId: 'checksum', input: '0xABC');
    final outOfRange = controller.calculate(
      strings: _strings,
      toolId: 'checksum',
      input: '[65, 256]',
    );

    expect(text.primary, 'CRC32 = 0xCBF43926');
    expect(text.detail, contains('FNV-1a 32: 0xBB86B11C'));

    expect(hex.primary, 'CRC32 = 0xCBF43926');
    expect(hex.detail, contains('输入模式: 十六进制字节'));
    expect(hex.insights, contains('输入识别为十六进制字节序列。'));

    expect(base64Bytes.primary, 'CRC32 = 0xCBF43926');
    expect(base64Bytes.detail, contains('输入模式: Base64 字节'));
    expect(base64Bytes.detail, contains('HEX: 31 32 33 34 35 36 37 38 39'));

    expect(invalid.primary, '输入无效');
    expect(invalid.detail, contains('十六进制字节需要偶数个数字'));

    expect(outOfRange.primary, '输入无效');
    expect(outOfRange.detail, contains('十进制字节超出 0-255 范围'));
  });

  test('uuid tool generates v4 uuids and normalizes pasted values', () {
    final generated =
        controller.calculate(strings: _strings, toolId: 'uuid', input: '');
    final parsed = controller.calculate(
      strings: _strings,
      toolId: 'uuid',
      input: '{550E8400E29B41D4A716446655440000}',
    );

    expect(
      generated.primary,
      matches(RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')),
    );
    expect(generated.detail, contains('版本: 4（随机）'));
    expect(generated.detail, contains('Variant: RFC 4122 / RFC 9562'));
    expect(generated.insights, contains('已离线生成随机 UUID v4。'));

    expect(parsed.primary, '550e8400-e29b-41d4-a716-446655440000');
    expect(parsed.detail, contains('无连字符: 550e8400e29b41d4a716446655440000'));
    expect(parsed.detail,
        contains('URN: urn:uuid:550e8400-e29b-41d4-a716-446655440000'));
    expect(parsed.insights, contains('输入 UUID 有效，已标准化。'));
  });

  test('uuid tool extracts guid json and byte array inputs', () {
    final guid = controller.calculate(
      strings: _strings,
      toolId: 'uuid',
      input: 'Guid("550E8400-E29B-41D4-A716-446655440000")',
    );
    final json = controller.calculate(
      strings: _strings,
      toolId: 'uuid',
      input: '{"requestId":"ignore","uuid":"550e8400e29b41d4a716446655440000"}',
    );
    final bytes = controller.calculate(
      strings: _strings,
      toolId: 'uuid',
      input:
          'new byte[] { 0x55, 0x0e, 0x84, 0x00, 0xe2, 0x9b, 0x41, 0xd4, 0xa7, 0x16, 0x44, 0x66, 0x55, 0x44, 0x00, 0x00 }',
    );

    expect(guid.primary, '550e8400-e29b-41d4-a716-446655440000');
    expect(guid.insights, contains('已从Guid/UUID 调用中提取 UUID。'));

    expect(json.primary, '550e8400-e29b-41d4-a716-446655440000');
    expect(json.insights, contains('已从JSON 字段中提取 UUID。'));

    expect(bytes.primary, '550e8400-e29b-41d4-a716-446655440000');
    expect(bytes.insights, contains('已从字节数组中提取 UUID。'));
  });

  test('uuid tool rejects invalid uuid text', () {
    final invalid = controller.calculate(
      strings: _strings,
      toolId: 'uuid',
      input: '550e8400-e29b41d4-a716-446655440000',
    );

    expect(invalid.primary, '输入无效');
    expect(invalid.detail, contains('UUID 连字符位置应为 8-4-4-4-12'));
  });
}

/// 中文：这一族测试钉的是**中文下表里的字**，所以表要显式取中文那一份——`calculate` 的
///       `strings` 是必填的，正是在这里把它变成"漏传就编译不过"。
/// English: These tests pin the **Chinese entries in the table**, so the table is the Chinese one
///          explicitly — `calculate`'s `strings` is required, and this is where that turns into
///          "forget it and the build fails".
final _strings = TextToolStrings.forLanguage(AppLanguage.zh);
