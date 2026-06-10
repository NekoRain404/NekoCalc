import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/controllers/text_tool_controller.dart';

void main() {
  const controller = TextToolController();

  test('text tool output builds reusable copy text and status summaries', () {
    final output = controller.calculate(toolId: 'base64', input: 'NekoCalc');

    expect(output.hasError, isFalse);
    expect(output.statusTitle, '结果可复用');
    expect(output.statusMessage, contains('主结果 12 字符'));
    expect(output.statusMessage, contains('详细结果'));
    expect(output.statusMessage, contains('校核提示'));
    expect(output.primaryCopyText, 'TmVrb0NhbGM=');
    expect(output.detailCopyText, contains('Base64URL: TmVrb0NhbGM'));

    final copyText = output.copyText(title: 'Base64', input: 'NekoCalc');
    expect(copyText, startsWith('Base64'));
    expect(copyText, contains('输入:\nNekoCalc'));
    expect(copyText, contains('状态: 结果可复用'));
    expect(copyText, contains('主结果:\nTmVrb0NhbGM='));
    expect(copyText, contains('详细结果:'));
    expect(copyText, contains('校核:'));
  });

  test('text tool output reports invalid state without hiding detail', () {
    final output = controller.calculate(toolId: 'json_format', input: '{bad');

    expect(output.hasError, isTrue);
    expect(output.statusTitle, '输入需要修正');
    expect(output.statusMessage, contains('FormatException'));
    expect(output.primaryCopyText, '输入无效');
    expect(output.detailCopyText, contains('FormatException'));

    final copyText = output.copyText(title: 'JSON 格式化', input: '{bad');
    expect(copyText, contains('状态: 输入需要修正'));
    expect(copyText, contains('主结果:\n输入无效'));
    expect(copyText, contains('详细结果:'));
  });

  test('custom formula accepts pasted numeric variants', () {
    final output = controller.calculate(
      toolId: 'custom_formula',
      input: '',
      formula: 'a * b + c',
      a: '1,200',
      b: '2',
      c: '5％',
    );

    expect(output.primary, '2400.05');
    expect(output.detail, contains('a = 1200'));
    expect(output.detail, contains('展开公式: 1200 * 2 + 0.05'));
    expect(output.insights.join('\n'), contains('公式使用变量: [a, b, c]'));
  });

  test('custom formula extracts formula and variables from pasted text', () {
    final output = controller.calculate(
      toolId: 'custom_formula',
      input: '''
formula: a^2 + sqrt(b) - c
a = 4
b = 81
c = 3
''',
      formula: 'a + b + c',
      a: '1',
      b: '2',
      c: '3',
    );

    expect(output.primary, '22');
    expect(output.detail, contains('公式: a^2 + sqrt(b) - c'));
    expect(output.detail, contains('展开公式: 4^2 + sqrt(81) - 3'));
    expect(output.detail, contains('a = 4'));
    expect(output.detail, contains('来源: 输入文本 "4"'));
    expect(output.insights, contains('已从输入文本中提取公式。'));
    expect(output.insights, contains('已从输入文本中提取变量: a, b, c。'));
    expect(output.insights.join('\n'), contains('公式使用变量: [a, b, c]'));
  });

  test('custom formula paste draft reuses shared field extraction', () {
    final draft = TextToolController.customFormulaDraftFromPastedText(
      input: '''
a: 4; b: 81; c: 3
a^2 + sqrt(b) - c
''',
      currentFormula: 'a + b + c',
      currentA: '1',
      currentB: '2',
      currentC: '3',
    );

    expect(draft.toolId, 'custom_formula');
    expect(draft.input, contains('a: 4; b: 81; c: 3'));
    expect(draft.formula, 'a^2 + sqrt(b) - c');
    expect(draft.a, '4');
    expect(draft.b, '81');
    expect(draft.c, '3');

    final variableOnlyDraft =
        TextToolController.customFormulaDraftFromPastedText(
      input: 'a=8, b=13',
      currentFormula: 'max(a, b)',
      currentA: '1',
      currentB: '2',
      currentC: '3',
    );
    expect(variableOnlyDraft.formula, 'max(a, b)');
    expect(variableOnlyDraft.a, '8');
    expect(variableOnlyDraft.b, '13');
    expect(variableOnlyDraft.c, '3');
  });

  test('custom formula avoids replacing letters inside function names', () {
    final output = controller.calculate(
      toolId: 'custom_formula',
      input: '',
      formula: 'abs(a) + max(b, c)',
      a: '-5',
      b: '3',
      c: '7',
    );

    expect(output.primary, '12');
    expect(output.detail, contains('展开公式: abs(-5) + max(3, 7)'));
  });

  test('text tool drafts round trip and stay isolated by tool id', () {
    const draft = TextToolDraft(
      toolId: 'custom_formula',
      input: '',
      formula: 'a^2 + b - c',
      a: '4k',
      b: '2',
      c: '1',
    );

    final encoded = TextToolController.encodeDraft(draft);
    final restored = TextToolController.decodeDraft(
      toolId: 'custom_formula',
      raw: encoded,
    );

    expect(
        TextToolController.draftSettingKey('base64'), 'text_tool_draft_base64');
    expect(restored, isNotNull);
    expect(restored!.toolId, 'custom_formula');
    expect(restored.formula, 'a^2 + b - c');
    expect(restored.a, '4k');
    expect(restored.b, '2');
    expect(restored.c, '1');
    expect(
      TextToolController.decodeDraft(toolId: 'base64', raw: encoded),
      isNull,
    );
    expect(
        TextToolController.decodeDraft(toolId: 'base64', raw: 'bad'), isNull);

    final partial = TextToolController.decodeDraft(
      toolId: 'base64',
      raw: '{"toolId":"base64","values":{}}',
    );
    expect(partial, isNotNull);
    expect(partial!.input, isEmpty);
    expect(partial.formula, TextToolController.defaultFormula);
    expect(partial.a, TextToolController.defaultA);
  });

  test('custom formula reports invalid variable input', () {
    final output = controller.calculate(
      toolId: 'custom_formula',
      input: '',
      formula: 'a + b',
      a: 'bad value',
      b: '2',
      c: '0',
    );

    expect(output.primary, '输入无效');
    expect(output.detail, contains('变量 a:'));
    expect(output.detail, contains('无法解析数值或表达式'));
    expect(output.insights, contains('请检查输入格式后重试。'));
  });

  test('custom formula reports non finite formula results', () {
    final output = controller.calculate(
      toolId: 'custom_formula',
      input: '',
      formula: 'a / b',
      a: '1',
      b: '0',
      c: '0',
    );

    expect(output.primary, '输入无效');
    expect(output.detail, contains('公式结果不是有限数值'));
  });

  test('base converter accepts common pasted integer variants', () {
    final hashHex = controller.calculate(toolId: 'base_convert', input: '#FF');
    final suffixHex =
        controller.calculate(toolId: 'base_convert', input: 'FFh');
    final fullWidthDecimal =
        controller.calculate(toolId: 'base_convert', input: '１_０２４');
    final octal = controller.calculate(toolId: 'base_convert', input: '0o755');

    expect(hashHex.primary, '255');
    expect(hashHex.detail, contains('十六进制: FF'));
    expect(hashHex.insights.join('\n'), contains('十六进制'));

    expect(suffixHex.primary, '255');
    expect(suffixHex.insights.join('\n'), contains('h 后缀'));

    expect(fullWidthDecimal.primary, '1024');
    expect(fullWidthDecimal.detail, contains('二进制: 10000000000'));

    expect(octal.primary, '493');
    expect(octal.insights.join('\n'), contains('八进制'));
  });

  test('base converter accepts programming suffixes and constants', () {
    final unsignedHex =
        controller.calculate(toolId: 'base_convert', input: '0xFFu');
    final longDecimal =
        controller.calculate(toolId: 'base_convert', input: '255L');
    final binary =
        controller.calculate(toolId: 'base_convert', input: '0b1010_0001UL');
    final constant = controller.calculate(
      toolId: 'base_convert',
      input: 'Integer.MAX_VALUE',
    );

    expect(unsignedHex.primary, '255');
    expect(unsignedHex.insights.join('\n'), contains('U 类型后缀'));

    expect(longDecimal.primary, '255');
    expect(longDecimal.insights.join('\n'), contains('L 类型后缀'));

    expect(binary.primary, '161');
    expect(binary.detail, contains('十六进制: A1'));
    expect(binary.insights.join('\n'), contains('UL 类型后缀'));

    expect(constant.primary, '2147483647');
    expect(constant.insights, contains('输入识别为十进制（编程语言常量）: Integer.MAX_VALUE。'));
  });

  test('bitwise accepts labeled integer variants', () {
    final output = controller.calculate(
      toolId: 'bitwise',
      input: 'A=0xF0, B=0b1010',
    );
    final constants = controller.calculate(
      toolId: 'bitwise',
      input: 'A=Integer.MAX_VALUE, B=0x0Fu',
    );

    expect(output.primary, 'AND = 0');
    expect(output.detail, contains('A: 240  hex:0xF0'));
    expect(output.detail, contains('B: 10  hex:0xA'));
    expect(output.detail, contains('OR: 250'));
    expect(output.detail, contains('XOR: 250'));
    expect(output.insights.join('\n'), contains('A 识别为十六进制'));
    expect(output.insights.join('\n'), contains('B 识别为二进制'));

    expect(constants.primary, 'AND = 15');
    expect(constants.detail, contains('A: 2147483647'));
    expect(constants.detail, contains('B: 15'));
  });

  test('integer tools report actionable invalid input', () {
    final base = controller.calculate(toolId: 'base_convert', input: '0b102');
    final bitwise = controller.calculate(toolId: 'bitwise', input: 'A=0xF0');
    final suffix =
        controller.calculate(toolId: 'base_convert', input: '0xFFuu');

    expect(base.primary, '输入无效');
    expect(base.detail, contains('整数格式无效'));
    expect(base.insights, contains('请检查输入格式后重试。'));

    expect(bitwise.primary, '输入无效');
    expect(bitwise.detail, contains('请输入两个整数'));

    expect(suffix.primary, '输入无效');
    expect(suffix.detail, contains('整数格式无效'));
  });

  test('base64 tool still detects plain text and encoded text', () {
    final encoded = controller.calculate(toolId: 'base64', input: 'NekoCalc');
    final decoded =
        controller.calculate(toolId: 'base64', input: encoded.primary);

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
      toolId: 'base64',
      input: 'data:text/plain;base64,SGVsbG8sIE5la29DYWxjIQ==',
    );
    final urlSafe = controller.calculate(toolId: 'base64', input: '8J-RiA');
    final wrapped = controller.calculate(
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
      toolId: 'base64',
      input: 'base64: SGVsbG8=',
    );
    final json = controller.calculate(
      toolId: 'base64',
      input: '{"payload":"TmVrb0NhbGM="}',
    );
    final log = controller.calculate(
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
      toolId: 'base64',
      input: '''
-----BEGIN MESSAGE-----
SGVsbG8sIE5la29DYWxjIQ==
-----END MESSAGE-----
''',
    );
    final markdown = controller.calculate(
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
      toolId: 'url_codec',
      input: 'https://example.com/search?q=Neko Calc&lang=中文',
    );
    final decodedQuery = controller.calculate(
      toolId: 'url_codec',
      input: 'q=Neko+Calc&lang=%E4%B8%AD%E6%96%87',
    );
    final component = controller.calculate(
      toolId: 'url_codec',
      input: 'Neko Calc/中文',
    );
    final plusOnlyQuery = controller.calculate(
      toolId: 'url_codec',
      input: 'q=Neko+Calc&tag=graph+tool',
    );
    final plusOnlyUrl = controller.calculate(
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
      toolId: 'url_codec',
      input: 'GET /search?q=Neko+Calc&lang=%E4%B8%AD%E6%96%87 HTTP/1.1',
    );
    final curl = controller.calculate(
      toolId: 'url_codec',
      input:
          "curl 'https://example.com/search?q=Neko+Calc&lang=%E4%B8%AD%E6%96%87' -H 'Accept: application/json'",
    );
    final encodedRequest = controller.calculate(
      toolId: 'url_codec',
      input: 'GET /search?q=Neko Calc&lang=中文 HTTP/1.1',
    );
    final encodedCurl = controller.calculate(
      toolId: 'url_codec',
      input: "curl --url 'https://example.com/search?q=Neko Calc&lang=中文'",
    );
    final curlGet = controller.calculate(
      toolId: 'url_codec',
      input:
          "curl -G 'https://example.com/search?page=1' --data-urlencode 'q=Neko Calc'",
    );
    final curlUrlQuery = controller.calculate(
      toolId: 'url_codec',
      input:
          "curl --url 'https://example.com/search?page=1#top' --url-query 'q=Neko Calc' --url-query=lang=中文",
    );
    final curlAnsiQuoted = controller.calculate(
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
      toolId: 'url_codec',
      input: '?q=Neko+Calc&lang=%E4%B8%AD%E6%96%87',
    );
    final encoded = controller.calculate(
      toolId: 'url_codec',
      input: '?q=Neko Calc&lang=中文',
    );

    expect(decoded.primary, '?q=Neko Calc&lang=中文');
    expect(decoded.insights, contains('Query 中的 + 已按空格处理。'));
    expect(encoded.primary, '?q=Neko+Calc&lang=%E4%B8%AD%E6%96%87');
  });

  test('html entity codec handles numeric entities and keeps unknown ones', () {
    final decoded = controller.calculate(
      toolId: 'html_entities',
      input:
          '&lt;span title=&quot;Neko&quot;&gt;&#x4E2D;&#25991;&nbsp;&unknown;</span>',
    );
    final encoded = controller.calculate(
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
      toolId: 'ascii_unicode',
      input: 'A中👈',
    );
    final decoded = controller.calculate(
      toolId: 'ascii_unicode',
      input: r'U+0041 \u4E2D \u{1F448} &#25991;',
    );
    final decimal = controller.calculate(
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
      toolId: 'ascii_unicode',
      input: 'U+110000',
    );

    expect(invalid.primary, '输入无效');
    expect(invalid.detail, contains('Unicode 码点无效'));
    expect(invalid.insights, contains('请检查输入格式后重试。'));
  });

  test('checksum accepts text and hex byte input', () {
    final text = controller.calculate(toolId: 'checksum', input: 'ABC');
    final hex = controller.calculate(toolId: 'checksum', input: '41 42 43');
    final prefixedHex = controller.calculate(
      toolId: 'checksum',
      input: 'const uint8_t data[] = {0x41, 0x42, 0x43};',
    );
    final decimal = controller.calculate(
      toolId: 'checksum',
      input: '[65, 66, 67]',
    );
    final base64Bytes = controller.calculate(
      toolId: 'checksum',
      input: 'base64: QUJD',
    );
    final dataUrlBytes = controller.calculate(
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
    final text = controller.calculate(toolId: 'fnv_crc', input: '123456789');
    final hex = controller.calculate(
      toolId: 'fnv_crc',
      input: r'\x31 \x32 \x33 \x34 \x35 \x36 \x37 \x38 \x39',
    );
    final base64Bytes = controller.calculate(
      toolId: 'fnv_crc',
      input: 'base64: MTIzNDU2Nzg5',
    );
    final invalid = controller.calculate(toolId: 'checksum', input: '0xABC');
    final outOfRange = controller.calculate(
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
    final generated = controller.calculate(toolId: 'uuid', input: '');
    final parsed = controller.calculate(
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
      toolId: 'uuid',
      input: 'Guid("550E8400-E29B-41D4-A716-446655440000")',
    );
    final json = controller.calculate(
      toolId: 'uuid',
      input: '{"requestId":"ignore","uuid":"550e8400e29b41d4a716446655440000"}',
    );
    final bytes = controller.calculate(
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
      toolId: 'uuid',
      input: '550e8400-e29b41d4-a716-446655440000',
    );

    expect(invalid.primary, '输入无效');
    expect(invalid.detail, contains('UUID 连字符位置应为 8-4-4-4-12'));
  });

  test('color converter accepts shorthand rgba and argb hex', () {
    final shortHex =
        controller.calculate(toolId: 'color_convert', input: '#5bf');
    final rgba = controller.calculate(
        toolId: 'color_convert', input: 'rgba(91, 71, 255, 0.5)');
    final cssRgb = controller.calculate(
        toolId: 'color_convert', input: 'rgb(91 71 255 / 50%)');
    final percentRgb = controller.calculate(
        toolId: 'color_convert', input: 'rgb(100% 0% 50%)');
    final argb =
        controller.calculate(toolId: 'color_convert', input: '#805B47FF');
    final prefixedArgb =
        controller.calculate(toolId: 'color_convert', input: '0xff5b47ff');

    expect(shortHex.primary, 'rgb(85, 187, 255)');
    expect(shortHex.detail, contains('HEX: #55BBFF'));
    expect(shortHex.detail, contains('HSL:'));
    expect(shortHex.insights, contains('输入识别为 3 位 HEX 颜色。'));

    expect(rgba.primary, contains('rgba(91, 71, 255'));
    expect(rgba.detail, contains('ARGB: #805B47FF'));
    expect(rgba.insights.join('\n'), contains('包含透明度'));

    expect(cssRgb.primary, contains('rgba(91, 71, 255'));
    expect(cssRgb.detail, contains('Alpha: 128'));
    expect(cssRgb.insights, contains('输入识别为 RGBA 颜色。'));

    expect(percentRgb.primary, 'rgb(255, 0, 128)');
    expect(percentRgb.detail, contains('HEX: #FF0080'));

    expect(argb.primary, contains('rgba(91, 71, 255'));
    expect(argb.detail, contains('Alpha: 128'));
    expect(argb.insights, contains('输入识别为 ARGB HEX 颜色。'));

    expect(prefixedArgb.primary, 'rgb(91, 71, 255)');
    expect(prefixedArgb.detail, contains('ARGB: #FF5B47FF'));
  });

  test('color converter accepts mobile and labeled color formats', () {
    final flutterColor = controller.calculate(
      toolId: 'color_convert',
      input: 'Color(0x805B47FF)',
    );
    final argbTuple = controller.calculate(
      toolId: 'color_convert',
      input: 'ARGB: 128, 91, 71, 255',
    );
    final labeledRgb = controller.calculate(
      toolId: 'color_convert',
      input: 'r=91 g=71 b=255 a=50%',
    );
    final labeledHex = controller.calculate(
      toolId: 'color_convert',
      input: '色值: 5B47FF',
    );

    expect(flutterColor.primary, contains('rgba(91, 71, 255'));
    expect(flutterColor.detail, contains('ARGB: #805B47FF'));
    expect(flutterColor.insights,
        contains('输入识别为 Flutter/Android Color(0xAARRGGBB) 色值。'));

    expect(argbTuple.primary, contains('rgba(91, 71, 255'));
    expect(argbTuple.detail, contains('Alpha: 128'));
    expect(argbTuple.insights, contains('输入识别为 ARGB 通道列表。'));

    expect(labeledRgb.primary, contains('rgba(91, 71, 255'));
    expect(labeledRgb.detail, contains('Alpha: 128'));
    expect(labeledRgb.insights, contains('输入识别为标签式 RGBA 颜色。'));

    expect(labeledHex.primary, 'rgb(91, 71, 255)');
    expect(labeledHex.detail, contains('HEX: #5B47FF'));
    expect(labeledHex.insights, contains('输入识别为带标签 HEX 色值。'));
  });

  test('color converter accepts hsl hsla and named colors', () {
    final hsl = controller.calculate(
      toolId: 'color_convert',
      input: 'hsl(250, 100%, 60%)',
    );
    final hsla = controller.calculate(
      toolId: 'color_convert',
      input: 'hsl(250 100% 60% / 50%)',
    );
    final turnHue = controller.calculate(
      toolId: 'color_convert',
      input: 'hsl(0.5turn 100% 50%)',
    );
    final radHue = controller.calculate(
      toolId: 'color_convert',
      input: 'hsl(3.141592653589793rad 100% 50%)',
    );
    final gradHue = controller.calculate(
      toolId: 'color_convert',
      input: 'hsl(200grad 100% 50%)',
    );
    final named = controller.calculate(
      toolId: 'color_convert',
      input: 'rebeccapurple',
    );
    final transparent = controller.calculate(
      toolId: 'color_convert',
      input: 'transparent',
    );
    final dodgerBlue = controller.calculate(
      toolId: 'color_convert',
      input: 'dodgerblue',
    );
    final slateGray = controller.calculate(
      toolId: 'color_convert',
      input: 'slategrey',
    );

    expect(hsl.primary, 'rgb(85, 51, 255)');
    expect(hsl.detail, contains('HEX: #5533FF'));
    expect(hsl.insights, contains('输入识别为 HSL 颜色。'));

    expect(hsla.primary, contains('rgba(85, 51, 255'));
    expect(hsla.detail, contains('Alpha: 128'));
    expect(hsla.insights, contains('输入识别为 HSLA 颜色。'));

    expect(turnHue.primary, 'rgb(0, 255, 255)');
    expect(radHue.primary, 'rgb(0, 255, 255)');
    expect(gradHue.primary, 'rgb(0, 255, 255)');

    expect(named.primary, 'rgb(102, 51, 153)');
    expect(named.detail, contains('HEX: #663399'));
    expect(named.insights, contains('输入识别为 CSS 命名颜色 rebeccapurple。'));

    expect(transparent.primary, contains('rgba(0, 0, 0'));
    expect(transparent.detail, contains('Alpha: 0'));

    expect(dodgerBlue.primary, 'rgb(30, 144, 255)');
    expect(dodgerBlue.detail, contains('HEX: #1E90FF'));
    expect(dodgerBlue.insights, contains('输入识别为 CSS 命名颜色 dodgerblue。'));

    expect(slateGray.primary, 'rgb(112, 128, 144)');
    expect(slateGray.detail, contains('HEX: #708090'));
    expect(slateGray.insights, contains('输入识别为 CSS 命名颜色 slategrey。'));
  });

  test('timestamp converter accepts iso and local date strings', () {
    final iso = controller.calculate(
      toolId: 'timestamp',
      input: '2026-06-08T09:30:00Z',
    );
    final local = controller.calculate(
      toolId: 'timestamp',
      input: '2026/06/08 09:30:00',
    );
    final decimalSeconds = controller.calculate(
      toolId: 'timestamp',
      input: '1700000000.123s',
    );
    final millis = controller.calculate(
      toolId: 'timestamp',
      input: '1700000000123ms',
    );
    final chinese = controller.calculate(
      toolId: 'timestamp',
      input: '2026年6月8日 09:30:00',
    );

    expect(iso.primary, contains('2026'));
    expect(iso.detail, contains('秒级时间戳:'));
    expect(iso.detail, contains('ISO UTC:'));
    expect(iso.detail, contains('星期:'));
    expect(iso.detail, contains('年内第'));
    expect(iso.insights, contains('输入识别为日期时间文本。'));

    expect(local.primary, contains('2026-06-08'));
    expect(local.insights, contains('输入识别为本地日期时间。'));

    expect(decimalSeconds.detail, contains('毫秒时间戳: 1700000000123'));
    expect(decimalSeconds.insights, contains('输入识别为带单位的秒级时间戳。'));
    expect(millis.detail, contains('毫秒时间戳: 1700000000123'));
    expect(millis.insights, contains('输入识别为带单位的毫秒时间戳。'));
    expect(chinese.primary, contains('2026-06-08'));
    expect(chinese.insights, contains('输入识别为本地日期时间。'));
  });

  test('timestamp converter accepts pasted labeled and compact variants', () {
    final offset = controller.calculate(
      toolId: 'timestamp',
      input: '2026-06-08 09:30:00 +0800',
    );
    final compactDateTime = controller.calculate(
      toolId: 'timestamp',
      input: '20260608093000',
    );
    final compactDate = controller.calculate(
      toolId: 'timestamp',
      input: '20260608',
    );
    final labeled = controller.calculate(
      toolId: 'timestamp',
      input: 'created_at: 2026年6月8日 09时30分05秒',
    );
    final json = controller.calculate(
      toolId: 'timestamp',
      input: '{"event":"login","timestamp":"1700000000.123s"}',
    );

    expect(offset.detail, contains('ISO UTC: 2026-06-08T01:30:00.000Z'));
    expect(offset.insights, contains('输入识别为日期时间文本。'));

    expect(compactDateTime.primary, contains('2026-06-08'));
    expect(compactDateTime.detail, contains('09:30:00'));
    expect(compactDateTime.insights, contains('输入识别为紧凑本地日期时间。'));

    expect(compactDate.primary, contains('2026-06-08'));
    expect(compactDate.detail, contains('00:00:00'));

    expect(labeled.primary, contains('2026-06-08'));
    expect(labeled.detail, contains('09:30:05'));
    expect(labeled.insights.join('\n'), contains('标签文本'));

    expect(json.detail, contains('毫秒时间戳: 1700000000123'));
    expect(json.insights.join('\n'), contains('JSON 字段'));
  });

  test('timestamp converter accepts rfc and named timezone date strings', () {
    final rfc = controller.calculate(
      toolId: 'timestamp',
      input: 'Mon, 08 Jun 2026 09:30:00 GMT',
    );
    final labeledHeader = controller.calculate(
      toolId: 'timestamp',
      input: 'Date: Mon, 08 Jun 2026 09:30:00 GMT',
    );
    final gmtSuffix = controller.calculate(
      toolId: 'timestamp',
      input: '2026-06-08 09:30:00 GMT',
    );
    final beijingPrefix = controller.calculate(
      toolId: 'timestamp',
      input: '北京时间 2026-06-08 09:30:00',
    );
    final englishMonthOffset = controller.calculate(
      toolId: 'timestamp',
      input: '08 Jun 2026 09:30:00 +0800',
    );

    expect(rfc.detail, contains('ISO UTC: 2026-06-08T09:30:00.000Z'));
    expect(rfc.insights, contains('输入识别为日期时间文本。'));

    expect(labeledHeader.detail, contains('ISO UTC: 2026-06-08T09:30:00.000Z'));
    expect(labeledHeader.insights.join('\n'), contains('标签文本'));

    expect(gmtSuffix.detail, contains('ISO UTC: 2026-06-08T09:30:00.000Z'));

    expect(beijingPrefix.detail, contains('ISO UTC: 2026-06-08T01:30:00.000Z'));

    expect(englishMonthOffset.detail,
        contains('ISO UTC: 2026-06-08T01:30:00.000Z'));
  });

  test('timestamp converter accepts microsecond and nanosecond epochs', () {
    final micro = controller.calculate(
      toolId: 'timestamp',
      input: '1700000000123456',
    );
    final nano = controller.calculate(
      toolId: 'timestamp',
      input: '1700000000123456789',
    );
    final explicitMicro = controller.calculate(
      toolId: 'timestamp',
      input: '1700000000123456us',
    );
    final explicitNano = controller.calculate(
      toolId: 'timestamp',
      input: '1700000000123456789ns',
    );

    expect(micro.detail, contains('毫秒时间戳: 1700000000123'));
    expect(micro.insights, contains('输入识别为微秒级时间戳。'));

    expect(nano.detail, contains('毫秒时间戳: 1700000000123'));
    expect(nano.insights, contains('输入识别为纳秒级时间戳。'));

    expect(explicitMicro.detail, contains('毫秒时间戳: 1700000000123'));
    expect(explicitMicro.insights, contains('输入识别为带单位的微秒时间戳。'));

    expect(explicitNano.detail, contains('毫秒时间戳: 1700000000123'));
    expect(explicitNano.insights, contains('输入识别为带单位的纳秒时间戳。'));
  });

  test('json and csv tools return validation insights', () {
    final json = controller.calculate(
      toolId: 'json_format',
      input:
          '\ufeff{"name":"NekoCalc","tools":["json","csv"],"meta":{"ok":true,"none":null}}',
    );
    final csv = controller.calculate(
      toolId: 'csv_json',
      input: 'name,category\nNekoCalc,calculator\nGraph',
    );

    expect(json.insights, contains('顶层类型: Object，键数量: 3。'));
    expect(json.insights.join('\n'), contains('Object 2，Array 1，标量 5'));
    expect(json.insights.join('\n'), contains('总键数: 5，最大深度: 3'));
    expect(json.insights.join('\n'), contains('包含 null 值: 1'));
    expect(csv.insights.join('\n'), contains('列数: 2'));
    expect(csv.insights.join('\n'), contains('第 3 行列数与表头不一致'));
  });

  test('csv json tool converts json arrays and objects to csv', () {
    final array = controller.calculate(
      toolId: 'csv_json',
      input: jsonEncode([
        {
          'name': 'Neko, Calc',
          'count': 2,
          'tags': ['json', 'csv'],
        },
        {
          'name': 'Graph "Tool"',
          'note': 'line 1\nline 2',
          'enabled': true,
        },
      ]),
    );
    final object = controller.calculate(
      toolId: 'csv_json',
      input: '{"name":"NekoCalc","ok":true}',
    );

    expect(array.primary, '2 行');
    expect(array.detail.split('\n').first, 'name,count,tags,note,enabled');
    expect(array.detail, contains('"Neko, Calc",2,"[""json"",""csv""]",,'));
    expect(array.detail, contains('"Graph ""Tool""",,,"line 1\nline 2",true'));
    expect(array.insights, contains('输入识别为 JSON，已转换为 CSV。'));
    expect(array.insights, contains('嵌套对象/数组已按 JSON 文本写入单元格。'));

    expect(object.primary, '1 行');
    expect(object.detail, 'name,ok\nNekoCalc,true');
    expect(object.insights, contains('顶层对象已作为 1 行数据处理。'));
  });

  test('csv json tool flattens nested json object fields', () {
    final output = controller.calculate(
      toolId: 'csv_json',
      input: jsonEncode([
        {
          'user': {
            'id': 1,
            'profile': {'name': 'Neko'},
          },
          'metrics': {'score': 98},
          'tags': ['calc', 'json'],
        },
        {
          'user': {
            'id': 2,
            'profile': {'name': 'Graph'},
          },
          'metrics': {'score': 100},
          'active': true,
        },
      ]),
    );

    final lines = output.detail.split('\n');

    expect(output.primary, '2 行');
    expect(lines.first, 'user.id,user.profile.name,metrics.score,tags,active');
    expect(lines[1], '1,Neko,98,"[""calc"",""json""]",');
    expect(lines[2], '2,Graph,100,,true');
    expect(output.insights, contains('嵌套对象已展开为点号列名。'));
    expect(output.insights, contains('嵌套对象/数组已按 JSON 文本写入单元格。'));
  });

  test('csv json tool converts json lines and json-like arrays to csv', () {
    final jsonLines = controller.calculate(
      toolId: 'csv_json',
      input: '''
{"user":{"id":1,"name":"Neko"},"score":98}
{"user":{"id":2,"name":"Calc"},"tags":["json","csv"],"active":true}
''',
    );
    final jsonLike = controller.calculate(
      toolId: 'csv_json',
      input: '''
[
  {id: 1, name: 'Neko',},
  {id: 2, name: 'Calc', active: true,},
]
''',
    );

    final jsonLinesRows = jsonLines.detail.split('\n');
    final jsonLikeRows = jsonLike.detail.split('\n');

    expect(jsonLines.primary, '2 行');
    expect(jsonLinesRows.first, 'user.id,user.name,score,tags,active');
    expect(jsonLinesRows[1], '1,Neko,98,,');
    expect(jsonLinesRows[2], '2,Calc,,"[""json"",""csv""]",true');
    expect(jsonLines.insights, contains('输入识别为 JSON，已转换为 CSV。'));
    expect(
      jsonLines.insights,
      contains('输入识别为 JSON Lines / NDJSON，已按多行记录转换。'),
    );
    expect(jsonLines.insights, contains('嵌套对象已展开为点号列名。'));

    expect(jsonLike.primary, '2 行');
    expect(jsonLikeRows.first, 'id,name,active');
    expect(jsonLikeRows[1], '1,Neko,');
    expect(jsonLikeRows[2], '2,Calc,true');
    expect(
      jsonLike.insights,
      contains('已兼容 JS 风格对象：注释、未加引号键、单引号或尾逗号已规范化。'),
    );
  });

  test('csv json tool accepts commented json lines', () {
    final output = controller.calculate(
      toolId: 'csv_json',
      input: '''
# exported from dev log
{id: 1, name: 'Neko', url: 'https://example.com/a//b'}, // first row
// skipped comment
{id: 2, name: 'Calc', active: true,}, /* trailing note */
''',
    );

    final lines = output.detail.split('\n');

    expect(output.primary, '2 行');
    expect(lines.first, 'id,name,url,active');
    expect(lines[1], '1,Neko,https://example.com/a//b,');
    expect(lines[2], '2,Calc,,true');
    expect(
      output.insights,
      contains('输入识别为 JSON Lines / NDJSON，已按多行记录转换。'),
    );
    expect(
      output.insights,
      contains('已兼容 JS 风格对象：注释、未加引号键、单引号或尾逗号已规范化。'),
    );
  });

  test('csv json tool extracts json lines from prefixed logs', () {
    final output = controller.calculate(
      toolId: 'csv_json',
      input: '''
2026-06-09T08:00:00Z INFO payload={"id":1,"name":"Neko","url":"https://example.com/a//b"} status=200
2026-06-09T08:00:01Z INFO payload={id:2,name:'Calc',active:true,} status=200
''',
    );

    final lines = output.detail.split('\n');

    expect(output.primary, '2 行');
    expect(lines.first, 'id,name,url,active');
    expect(lines[1], '1,Neko,https://example.com/a//b,');
    expect(lines[2], '2,Calc,,true');
    expect(
      output.insights,
      contains('输入识别为 JSON Lines / NDJSON，已按多行记录转换。'),
    );
    expect(
      output.insights,
      contains('已兼容 JS 风格对象：注释、未加引号键、单引号或尾逗号已规范化。'),
    );
  });

  test('json formatter accepts json lines input', () {
    final output = controller.calculate(
      toolId: 'json_format',
      input: '{"id":1,"name":"A"}\n{"id":2,"name":"B"}',
    );

    final rows = jsonDecode(output.detail) as List;

    expect(output.primary, 'JSON Lines 有效');
    expect(rows.length, 2);
    expect(rows.last['name'], 'B');
    expect(output.insights, contains('输入识别为 JSON Lines / NDJSON，已转换为数组。'));
    expect(output.insights, contains('顶层类型: Array，元素数量: 2。'));
  });

  test('json formatter accepts commented json lines input', () {
    final output = controller.calculate(
      toolId: 'json_format',
      input: '''
# exported from dev log
{id: 1, name: 'Neko', url: 'https://example.com/a//b'}, // first row
// skipped comment
{id: 2, name: 'Calc', active: true,}, /* trailing note */
''',
    );

    final rows = jsonDecode(output.detail) as List;

    expect(output.primary, 'JSON Lines 有效');
    expect(rows.length, 2);
    expect(rows.first['url'], 'https://example.com/a//b');
    expect(rows.last['active'], true);
    expect(output.insights, contains('输入识别为 JSON Lines / NDJSON，已转换为数组。'));
    expect(
      output.insights,
      contains('已兼容 JS 风格对象：注释、未加引号键、单引号或尾逗号已规范化。'),
    );
  });

  test('json formatter extracts json lines from prefixed logs', () {
    final output = controller.calculate(
      toolId: 'json_format',
      input: '''
2026-06-09T08:00:00Z INFO payload={"id":1,"name":"Neko","url":"https://example.com/a//b"} status=200
2026-06-09T08:00:01Z INFO payload={id:2,name:'Calc',active:true,} status=200
''',
    );

    final rows = jsonDecode(output.detail) as List;

    expect(output.primary, 'JSON Lines 有效');
    expect(rows.length, 2);
    expect(rows.first['url'], 'https://example.com/a//b');
    expect(rows.last['active'], true);
    expect(output.insights, contains('输入识别为 JSON Lines / NDJSON，已转换为数组。'));
    expect(
      output.insights,
      contains('已兼容 JS 风格对象：注释、未加引号键、单引号或尾逗号已规范化。'),
    );
  });

  test('json formatter accepts common json-like object input', () {
    final output = controller.calculate(
      toolId: 'json_format',
      input: '''
{
  // copied from a config file
  name: 'NekoCalc',
  version: '1.0',
  flags: ['json', 'csv',],
  nested: {
    enabled: true,
  },
}
''',
    );

    final object = jsonDecode(output.detail) as Map<String, dynamic>;

    expect(output.primary, 'JSON 有效');
    expect(object['name'], 'NekoCalc');
    expect(object['flags'], ['json', 'csv']);
    expect(object['nested'], {'enabled': true});
    expect(
      output.insights,
      contains('已兼容 JS 风格对象：注释、未加引号键、单引号或尾逗号已规范化。'),
    );
  });

  test('json formatter unwraps escaped json strings from logs', () {
    final escaped = controller.calculate(
      toolId: 'json_format',
      input: r'"{\"name\":\"NekoCalc\",\"items\":[1,2],\"ok\":true}"',
    );
    final log = controller.calculate(
      toolId: 'json_format',
      input:
          r'INFO payload="{\"name\":\"NekoCalc\",\"nested\":{\"ok\":true}}" status=200',
    );
    final singleLineJsonLike = controller.calculate(
      toolId: 'json_format',
      input: "payload = {name: 'NekoCalc', flags: ['json',],};",
    );

    final escapedObject = jsonDecode(escaped.detail) as Map<String, dynamic>;
    final logObject = jsonDecode(log.detail) as Map<String, dynamic>;
    final jsonLikeObject =
        jsonDecode(singleLineJsonLike.detail) as Map<String, dynamic>;

    expect(escapedObject['items'], [1, 2]);
    expect(escaped.insights, contains('已从转义 JSON 字符串中提取 JSON。'));

    expect(logObject['nested'], {'ok': true});
    expect(log.insights, contains('已从转义 JSON 字符串中提取 JSON。'));

    expect(jsonLikeObject['flags'], ['json']);
    expect(
      singleLineJsonLike.insights,
      contains('已兼容 JS 风格对象：注释、未加引号键、单引号或尾逗号已规范化。'),
    );
  });

  test('json formatter extracts json from markdown code and pasted logs', () {
    final markdown = controller.calculate(
      toolId: 'json_format',
      input: '''
Here is the payload:
```json
{"name":"NekoCalc","ok":true}
```
''',
    );
    final assignment = controller.calculate(
      toolId: 'json_format',
      input: '''
const payload = {
  name: 'NekoCalc',
  nested: { ok: true, },
};
''',
    );
    final log = controller.calculate(
      toolId: 'json_format',
      input: 'INFO response payload={"items":[{"id":1},{"id":2}],"ok":true};',
    );
    final trailingLog = controller.calculate(
      toolId: 'json_format',
      input:
          '2026-06-09T08:00:00Z INFO payload={"name":"NekoCalc","ok":true} status=200 duration_ms=8',
    );

    final markdownObject = jsonDecode(markdown.detail) as Map<String, dynamic>;
    final assignmentObject =
        jsonDecode(assignment.detail) as Map<String, dynamic>;
    final logObject = jsonDecode(log.detail) as Map<String, dynamic>;
    final trailingLogObject =
        jsonDecode(trailingLog.detail) as Map<String, dynamic>;

    expect(markdownObject['name'], 'NekoCalc');
    expect(markdown.insights, contains('已从Markdown 代码块中提取 JSON。'));

    expect(assignmentObject['nested'], {'ok': true});
    expect(assignment.insights, contains('已从粘贴文本中提取 JSON。'));
    expect(
      assignment.insights,
      contains('已兼容 JS 风格对象：注释、未加引号键、单引号或尾逗号已规范化。'),
    );

    expect((logObject['items'] as List).length, 2);
    expect(log.insights, contains('已从粘贴文本中提取 JSON。'));

    expect(trailingLogObject['name'], 'NekoCalc');
    expect(trailingLogObject['ok'], isTrue);
    expect(trailingLog.insights, contains('已从粘贴文本中提取 JSON。'));
  });

  test('csv tool preserves quoted commas quotes and multiline fields', () {
    final csv = controller.calculate(
      toolId: 'csv_json',
      input: 'name,note\n"Neko, Calc","line 1\nline 2"\nGraph,"x=""2"""',
    );

    final rows = jsonDecode(csv.detail) as List;

    expect(csv.primary, '2 行');
    expect(rows.first['name'], 'Neko, Calc');
    expect(rows.first['note'], 'line 1\nline 2');
    expect(rows.last['note'], 'x="2"');
    expect(csv.insights.join('\n'), contains('已处理 3 个带引号字段'));
    expect(csv.insights.join('\n'), contains('已保留 1 个包含换行的字段'));
  });

  test('csv tool normalizes duplicate headers and keeps extra columns', () {
    final csv = controller.calculate(
      toolId: 'csv_json',
      input: 'name,name\nA,B,C',
    );

    final rows = jsonDecode(csv.detail) as List;

    expect(rows.single['name'], 'A');
    expect(rows.single['name_2'], 'B');
    expect(rows.single['extra_1'], 'C');
    expect(csv.insights.join('\n'), contains('第 2 行列数与表头不一致'));
  });

  test('csv tool detects semicolon and pipe delimiters', () {
    final semicolon = controller.calculate(
      toolId: 'csv_json',
      input: 'name;score\nNeko;98\nCalc;100',
    );
    final pipe = controller.calculate(
      toolId: 'csv_json',
      input: 'name|note\nNeko|"line|kept"\nCalc|ok',
    );

    final semicolonRows = jsonDecode(semicolon.detail) as List;
    final pipeRows = jsonDecode(pipe.detail) as List;

    expect(semicolonRows.first['name'], 'Neko');
    expect(semicolonRows.last['score'], '100');
    expect(semicolon.insights.join('\n'), contains('分隔符: 分号'));

    expect(pipeRows.first['note'], 'line|kept');
    expect(pipeRows.last['name'], 'Calc');
    expect(pipe.insights.join('\n'), contains('分隔符: 竖线'));
    expect(pipe.insights.join('\n'), contains('已处理 1 个带引号字段'));
  });

  test('csv tool skips spreadsheet metadata comments and bom', () {
    final csv = controller.calculate(
      toolId: 'csv_json',
      input:
          '\ufeff# exported from spreadsheet\nsep=;\nname;score\nNeko;98\nCalc;100',
    );

    final rows = jsonDecode(csv.detail) as List;

    expect(csv.primary, '2 行');
    expect(rows.first['name'], 'Neko');
    expect(rows.first['score'], '98');
    expect(rows.last['name'], 'Calc');
    expect(csv.insights.join('\n'), contains('分隔符: 分号'));
    expect(csv.insights.join('\n'), contains('已跳过 2 行 CSV 元数据或注释'));
  });

  test('csv tool skips unit descriptor rows after headers', () {
    final csv = controller.calculate(
      toolId: 'csv_json',
      input: '''
time,temp,pressure
units,s,degC,kPa
1,20,100
2,25,110
''',
    );
    final markdown = controller.calculate(
      toolId: 'csv_json',
      input: '''
| time | 温度 | 压力 |
| 单位 | ℃ | kPa |
| --- | ---: | ---: |
| 1 | 20 | 100 |
| 2 | 25 | 110 |
''',
    );

    final csvRows = jsonDecode(csv.detail) as List;
    final markdownRows = jsonDecode(markdown.detail) as List;

    expect(csv.primary, '2 行');
    expect(csvRows.first['time'], '1');
    expect(csvRows.first['temp'], '20');
    expect(csvRows.last['pressure'], '110');
    expect(csv.insights.join('\n'), contains('已跳过 1 行 CSV 元数据或注释'));

    expect(markdown.primary, '2 行');
    expect(markdownRows.first['time'], '1');
    expect(markdownRows.first['温度'], '20');
    expect(markdownRows.last['压力'], '110');
    expect(markdown.insights.join('\n'), contains('已跳过 1 行 CSV 元数据或注释'));
    expect(markdown.insights.join('\n'), contains('已跳过 1 行 Markdown 表格分隔线'));
  });

  test('csv tool accepts markdown pipe tables', () {
    final markdown = controller.calculate(
      toolId: 'csv_json',
      input: '''
| name | score | note |
| :--- | ---: | :---: |
| Neko | 98 | ok |
| Calc | 100 | done |
''',
    );

    final rows = jsonDecode(markdown.detail) as List;

    expect(markdown.primary, '2 行');
    expect(rows.first['name'], 'Neko');
    expect(rows.first['score'], '98');
    expect(rows.last['note'], 'done');
    expect(markdown.insights.join('\n'), contains('分隔符: 竖线'));
    expect(markdown.insights.join('\n'), contains('已跳过 1 行 Markdown 表格分隔线'));
  });

  test('csv tool accepts copied sql ascii tables', () {
    final psql = controller.calculate(
      toolId: 'csv_json',
      input: '''
 name | score | note
------+-------+------
 Neko | 98    | ok
 Calc | 100   | done
(2 rows)
''',
    );
    final mysql = controller.calculate(
      toolId: 'csv_json',
      input: '''
+------+-------+
| name | score |
+------+-------+
| Neko | 98    |
| Calc | 100   |
+------+-------+
2 rows in set (0.00 sec)
''',
    );

    final psqlRows = jsonDecode(psql.detail) as List;
    final mysqlRows = jsonDecode(mysql.detail) as List;

    expect(psql.primary, '2 行');
    expect(psqlRows.first['name'], 'Neko');
    expect(psqlRows.first['score'], '98');
    expect(psqlRows.last['note'], 'done');
    expect(psql.insights.join('\n'), contains('分隔符: 竖线'));
    expect(psql.insights.join('\n'), contains('已跳过 2 行 SQL/ASCII 表格边框或尾行'));

    expect(mysql.primary, '2 行');
    expect(mysqlRows.first['name'], 'Neko');
    expect(mysqlRows.last['score'], '100');
    expect(mysql.insights.join('\n'), contains('已跳过 4 行 SQL/ASCII 表格边框或尾行'));
  });

  test('query params preserve duplicate keys and bare query input', () {
    final url = controller.calculate(
      toolId: 'query_params',
      input: 'https://example.com/search?q=cat&q=dog&page=1#top',
    );
    final bare = controller.calculate(
      toolId: 'query_params',
      input: '?a=1&a=2&empty=',
    );

    final urlJson = jsonDecode(url.detail.split('JSON:\n').last) as Map;
    final bareJson = jsonDecode(bare.detail.split('JSON:\n').last) as Map;

    expect(url.primary, '3 个参数');
    expect(urlJson['q'], ['cat', 'dog']);
    expect(urlJson['page'], '1');
    expect(url.insights, contains('重复键: q(2)。'));
    expect(url.insights, contains('片段: top'));
    expect(bare.primary, '3 个参数');
    expect(bareJson['a'], ['1', '2']);
    expect(bareJson['empty'], '');
  });

  test('query params accept request lines semicolons and fragment queries', () {
    final request = controller.calculate(
      toolId: 'query_params',
      input: 'GET /api/search?q=Neko+Calc&tag=a%2Fb HTTP/1.1\nHost: local',
    );
    final form = controller.calculate(
      toolId: 'query_params',
      input: 'a=1;b=two+words;empty',
    );
    final fragment = controller.calculate(
      toolId: 'query_params',
      input: 'https://example.com/#/tools?tab=text&id=query_params',
    );

    final requestJson = jsonDecode(request.detail.split('JSON:\n').last) as Map;
    final formJson = jsonDecode(form.detail.split('JSON:\n').last) as Map;
    final fragmentJson =
        jsonDecode(fragment.detail.split('JSON:\n').last) as Map;

    expect(requestJson['q'], 'Neko Calc');
    expect(requestJson['tag'], 'a/b');
    expect(request.insights, contains('输入识别为 HTTP 请求行。'));

    expect(form.primary, '3 个参数');
    expect(formJson['b'], 'two words');
    expect(formJson['empty'], '');
    expect(form.insights, contains('已兼容分号分隔的表单参数。'));

    expect(fragmentJson['tab'], 'text');
    expect(fragmentJson['id'], 'query_params');
    expect(fragment.insights, contains('输入识别为 URL 片段中的 query。'));
  });

  test('query params accepts newline separated form fields', () {
    final output = controller.calculate(
      toolId: 'query_params',
      input: '''
q=Neko+Calc
tag=a%2Fb
empty=
flag
''',
    );
    final encodedNewline = controller.calculate(
      toolId: 'query_params',
      input: 'note=line1%0Aline2&tag=kept',
    );

    final object = jsonDecode(output.detail.split('JSON:\n').last) as Map;
    final encodedObject =
        jsonDecode(encodedNewline.detail.split('JSON:\n').last) as Map;

    expect(output.primary, '4 个参数');
    expect(object['q'], 'Neko Calc');
    expect(object['tag'], 'a/b');
    expect(object['empty'], '');
    expect(object['flag'], '');
    expect(output.insights, contains('已兼容换行分隔的表单参数。'));

    expect(encodedObject['note'], 'line1\nline2');
    expect(encodedObject['tag'], 'kept');
    expect(
      encodedNewline.insights,
      isNot(contains('已兼容换行分隔的表单参数。')),
    );
  });

  test('query params accepts curl commands with url and data fields', () {
    final output = controller.calculate(
      toolId: 'query_params',
      input: r'''
curl 'https://example.com/api/search?page=1&q=Neko+Calc' \
  -H 'Authorization: Bearer token' \
  --data-urlencode 'q=Graph Tool' \
  -d 'tag=a%2Fb&empty=' \
  --data-raw 'debug=true'
''',
    );

    final object = jsonDecode(output.detail.split('JSON:\n').last) as Map;

    expect(output.primary, '6 个参数');
    expect(object['page'], '1');
    expect(object['q'], ['Neko Calc', 'Graph Tool']);
    expect(object['tag'], 'a/b');
    expect(object['empty'], '');
    expect(object['debug'], 'true');
    expect(
      output.insights,
      contains('输入识别为 curl 命令，已合并 URL query 与 -d/--data 表单参数。'),
    );
    expect(output.insights, contains('主机: example.com'));
    expect(output.insights, contains('重复键: q(2)。'));
  });

  test('query params treats curl get data as query parameters', () {
    final output = controller.calculate(
      toolId: 'query_params',
      input: r'''
curl --get 'https://example.com/api/search?page=1#top' \
  --data-urlencode 'q=Neko Calc' \
  -d 'tag=a%2Fb&empty='
''',
    );

    final object = jsonDecode(output.detail.split('JSON:\n').last) as Map;

    expect(output.primary, '4 个参数');
    expect(object['page'], '1');
    expect(object['q'], 'Neko Calc');
    expect(object['tag'], 'a/b');
    expect(object['empty'], '');
    expect(
      output.insights,
      contains('输入识别为 curl -G/--get 命令，已将 --data 参数合并为 URL query。'),
    );
    expect(output.insights, contains('片段: top'));
  });

  test('query params accepts curl url-query options', () {
    final output = controller.calculate(
      toolId: 'query_params',
      input: r'''
curl --url 'https://example.com/api/search?page=1#top' \
  --url-query 'q=Neko Calc' \
  --url-query=lang=%E4%B8%AD%E6%96%87 \
  -d 'debug=true'
''',
    );

    final object = jsonDecode(output.detail.split('JSON:\n').last) as Map;

    expect(output.primary, '4 个参数');
    expect(object['page'], '1');
    expect(object['q'], 'Neko Calc');
    expect(object['lang'], '中文');
    expect(object['debug'], 'true');
    expect(
      output.insights,
      contains('输入识别为 curl 命令，已合并 --url-query 与 -d/--data 表单参数。'),
    );
    expect(output.insights, contains('片段: top'));
  });

  test('query params accepts bash ansi quoted curl values', () {
    final output = controller.calculate(
      toolId: 'query_params',
      input: r'''
curl $'https://example.com/api/search?page=1&q=Neko\x20Calc' \
  --url-query $'lang=\u4e2d\u6587' \
  --data-urlencode $'tag=a\x2fb'
''',
    );

    final object = jsonDecode(output.detail.split('JSON:\n').last) as Map;

    expect(output.primary, '4 个参数');
    expect(object['page'], '1');
    expect(object['q'], 'Neko Calc');
    expect(object['lang'], '中文');
    expect(object['tag'], 'a/b');
    expect(
      output.insights,
      contains('输入识别为 curl 命令，已合并 --url-query 与 -d/--data 表单参数。'),
    );
  });

  test('query params accepts multiline curl data fields', () {
    final output = controller.calculate(
      toolId: 'query_params',
      input: '''
curl 'https://example.com/api/search?page=1' \\
  -d 'q=Neko+Calc
tag=a%2Fb
empty='
''',
    );

    final object = jsonDecode(output.detail.split('JSON:\n').last) as Map;

    expect(output.primary, '4 个参数');
    expect(object['page'], '1');
    expect(object['q'], 'Neko Calc');
    expect(object['tag'], 'a/b');
    expect(object['empty'], '');
    expect(output.insights, contains('已兼容换行分隔的表单参数。'));
  });

  test('text stats counts non whitespace characters', () {
    final stats = controller.calculate(
      toolId: 'text_stats',
      input: 'A B\n\t中\n\nHi 42!',
    );

    expect(stats.detail, contains('字符数: 14'));
    expect(stats.detail, contains('英文词: 3'));
    expect(stats.detail, contains('数字片段: 1'));
    expect(stats.detail, contains('非空行: 3'));
    expect(stats.detail, contains('空行: 1'));
    expect(stats.detail, contains('段落: 2'));
    expect(stats.detail, contains('去空白字符: 8'));
    expect(stats.detail, contains('最长行: 6 字符'));
    expect(stats.detail, contains('平均非空行长: 3.67 字符'));
    expect(stats.detail, contains('中文字符: 1'));
    expect(stats.detail, contains('拉丁字母: 4'));
    expect(stats.detail, contains('数字: 2'));
    expect(stats.detail, contains('空白字符: 6'));
    expect(stats.detail, contains('标点/符号: 1'));
    expect(stats.insights, contains('文本包含中英文混排。'));
    expect(stats.insights, contains('检测到 2 个非空段落。'));
    expect(stats.insights, contains('包含 1 个空行。'));
  });

  test('text stats counts grapheme clusters separately from code points', () {
    final stats = controller.calculate(
      toolId: 'text_stats',
      input: '👨‍👩‍👧‍👦 é\n🇨🇳',
    );

    expect(stats.primary, '5 字符');
    expect(stats.detail, contains('字符数: 5'));
    expect(stats.detail, contains('Unicode 码点: 13'));
    expect(stats.detail, contains('去空白字符: 3'));
    expect(stats.detail, contains('去空白码点: 11'));
    expect(stats.detail, contains('最长行: 3 字符'));
    expect(stats.detail, contains('平均非空行长: 2.00 字符'));
    expect(stats.insights, contains('已按 Unicode 可见字符聚合组合符号和 emoji。'));
  });

  test('text stats reports trailing whitespace lines', () {
    final stats = controller.calculate(
      toolId: 'text_stats',
      input: 'alpha  \n中文\t\n42',
    );

    expect(stats.detail, contains('行数: 3'));
    expect(stats.detail, contains('非空行: 3'));
    expect(stats.detail, contains('行尾空白: 2 行'));
    expect(stats.insights, contains('检测到 2 行行尾空白。'));
  });

  test('regex tool supports slash flags and capture groups', () {
    final output = controller.calculate(
      toolId: 'regex_test',
      input: r'/([a-z]+)-(?<num>\d+)/i' '\nABC-42\nno-match',
    );

    expect(output.primary, '1 个匹配');
    expect(output.detail, contains('[0, 6) ABC-42'));
    expect(output.detail, contains('group 1: ABC'));
    expect(output.detail, contains('num: 42'));
    expect(output.insights, contains('Flags: i'));
    expect(output.insights, contains('包含捕获组，详情中已列出 group 值。'));
  });

  test('regex tool accepts labeled pattern flags and text blocks', () {
    final labeled = controller.calculate(
      toolId: 'regex_test',
      input: r'''
pattern: /(?<word>[a-z]+)-(?<num>\d+)/i
text: ABC-42
no-match
xyz-7
''',
    );
    final chinese = controller.calculate(
      toolId: 'regex_test',
      input: '正则: 猫.狗\n模式: s\n文本: 猫\n狗',
    );

    expect(labeled.primary, '2 个匹配');
    expect(labeled.detail, contains('word: ABC'));
    expect(labeled.detail, contains('num: 7'));
    expect(labeled.insights, contains('Flags: i'));
    expect(labeled.insights, contains('已识别 pattern/text 标签格式。'));

    expect(chinese.primary, '1 个匹配');
    expect(chinese.detail, contains('猫\n狗'));
    expect(chinese.insights, contains('Flags: s'));
    expect(chinese.insights, contains('已识别 pattern/text 标签格式。'));
  });

  test('regex tool supports explicit flags line and reports bad flags', () {
    final dotAll = controller.calculate(
      toolId: 'regex_test',
      input: 'a.*c\nflags: s\na\nb\nc',
    );
    final global = controller.calculate(
      toolId: 'regex_test',
      input: '/abc/g\nabc abc',
    );
    final invalid = controller.calculate(
      toolId: 'regex_test',
      input: '/abc/y\nabc',
    );

    expect(dotAll.primary, '1 个匹配');
    expect(dotAll.detail, contains('a\nb\nc'));
    expect(dotAll.insights, contains('Flags: s'));

    expect(global.primary, '2 个匹配');
    expect(global.detail, contains('[0, 3) abc'));
    expect(global.detail, contains('[4, 7) abc'));
    expect(global.insights, contains('Flags: g'));
    expect(global.insights, contains('已兼容 g/global 标志；本工具默认列出所有匹配。'));

    expect(invalid.primary, '输入无效');
    expect(invalid.detail, contains('正则 flags 仅支持 g、i、m、s、u'));
  });

  test('jwt and invalid input expose actionable insights', () {
    const sampleToken =
        'eyJhbGciOiJub25lIiwidHlwIjoiSldUIiwia2lkIjoibG9jYWwifQ.eyJpc3MiOiJOZWtvQ2FsYyIsInN1YiI6InVzZXItMSIsImF1ZCI6WyJhcHAiLCJ0ZXN0Il0sImV4cCI6NDEwMjQ0NDgwMCwibmJmIjoxMCwiaWF0IjoxMH0.';
    final expired = controller.calculate(
      toolId: 'jwt_decode',
      input: 'eyJhbGciOiJub25lIn0.eyJleHAiOjEwLCJpYXQiOjF9.signature',
    );
    final rich = controller.calculate(
      toolId: 'jwt_decode',
      input: sampleToken,
    );
    final bearer = controller.calculate(
      toolId: 'jwt_decode',
      input: 'Authorization: Bearer $sampleToken',
    );
    final labeled = controller.calculate(
      toolId: 'jwt_decode',
      input: 'access_token="$sampleToken"',
    );
    final invalid = controller.calculate(toolId: 'json_format', input: '{bad');

    expect(expired.insights, contains('Token 已过期。'));
    expect(expired.insights, contains('包含签发时间 iat。'));
    expect(expired.detail, contains('Claims:'));
    expect(expired.detail, contains('exp:'));

    expect(rich.primary, 'JWT 已解析');
    expect(rich.detail, contains('"kid": "local"'));
    expect(rich.detail, contains('iss: NekoCalc'));
    expect(rich.detail, contains('aud: app, test'));
    expect(rich.detail, contains('签名段: 无'));
    expect(rich.insights, contains('算法 alg: none。'));
    expect(rich.insights, contains('类型 typ: JWT。'));
    expect(rich.insights, contains('alg=none，Token 不包含加密签名。'));
    expect(rich.insights, contains('包含签发者 iss。'));
    expect(rich.insights, contains('包含主题 sub。'));

    expect(bearer.primary, 'JWT 已解析');
    expect(bearer.detail, contains('iss: NekoCalc'));
    expect(bearer.insights, contains('已从 Bearer/Authorization 文本中提取 JWT。'));

    expect(labeled.primary, 'JWT 已解析');
    expect(labeled.detail, contains('sub: user-1'));
    expect(labeled.insights, contains('已从 token 字段中提取 JWT。'));

    expect(invalid.primary, '输入无效');
    expect(invalid.insights, contains('请检查输入格式后重试。'));
  });

  test('jwt decoder extracts tokens from url cookie and json fields', () {
    const sampleToken =
        'eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0.eyJpc3MiOiJOZWtvQ2FsYyIsInN1YiI6ImNsaWVudCIsImV4cCI6NDEwMjQ0NDgwMH0.';
    final encodedToken = sampleToken.replaceAll('.', '%2E');
    final url = controller.calculate(
      toolId: 'jwt_decode',
      input: 'https://example.com/callback?code=ok&id_token=$encodedToken',
    );
    final cookie = controller.calculate(
      toolId: 'jwt_decode',
      input: 'Cookie: theme=dark; access_token=$sampleToken; Path=/',
    );
    final json = controller.calculate(
      toolId: 'jwt_decode',
      input: '{"data":{"authorization":"Bearer $sampleToken"}}',
    );

    expect(url.primary, 'JWT 已解析');
    expect(url.detail, contains('sub: client'));
    expect(url.insights, contains('已从 URL query 参数中提取 JWT。'));

    expect(cookie.primary, 'JWT 已解析');
    expect(cookie.detail, contains('iss: NekoCalc'));
    expect(cookie.insights, contains('已从 Cookie 字段中提取 JWT。'));

    expect(json.primary, 'JWT 已解析');
    expect(json.detail, contains('sub: client'));
    expect(json.insights, contains('已从 JSON 字段中提取 JWT。'));
  });

  test('jwt decoder summarizes permission and time claims readably', () {
    const sampleToken =
        'eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0.eyJpc3MiOiJOZWtvQ2FsYyIsInN1YiI6InVzZXItMiIsInNjb3BlIjoicmVhZDpjYWxjIHdyaXRlOm5vdGVzIiwicm9sZXMiOlsiYWRtaW4iLCJlZGl0b3IiXSwicGVybWlzc2lvbnMiOlsiZ3JhcGg6dmlldyJdLCJleHAiOjQxMDI0NDQ4MDAsImlhdCI6MTcwMDAwMDAwMH0.';
    final decoded = controller.calculate(
      toolId: 'jwt_decode',
      input: sampleToken,
    );

    expect(decoded.primary, 'JWT 已解析');
    expect(decoded.detail, contains('scope: read:calc, write:notes'));
    expect(decoded.detail, contains('roles: admin, editor'));
    expect(decoded.detail, contains('permissions: graph:view'));
    expect(decoded.detail, contains('exp:'));
    expect(decoded.detail, contains('UTC 2100-01-01T00:00:00.000Z'));
    expect(decoded.detail, contains('iat:'));
    expect(decoded.detail, contains('UTC 2023-11-14T22:13:20.000Z'));
  });
}
