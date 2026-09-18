import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/controllers/text_tool_controller.dart';
import 'package:nekocalc/features/tools/presentation/text_tool_strings.dart';
import 'package:nekocalc/l10n/app_language.dart';

void main() {
  const controller = TextToolController();

  test('query params preserve duplicate keys and bare query input', () {
    final url = controller.calculate(
      strings: _strings,
      toolId: 'query_params',
      input: 'https://example.com/search?q=cat&q=dog&page=1#top',
    );
    final bare = controller.calculate(
      strings: _strings,
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
      strings: _strings,
      toolId: 'query_params',
      input: 'GET /api/search?q=Neko+Calc&tag=a%2Fb HTTP/1.1\nHost: local',
    );
    final form = controller.calculate(
      strings: _strings,
      toolId: 'query_params',
      input: 'a=1;b=two+words;empty',
    );
    final fragment = controller.calculate(
      strings: _strings,
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
      strings: _strings,
      toolId: 'query_params',
      input: '''
q=Neko+Calc
tag=a%2Fb
empty=
flag
''',
    );
    final encodedNewline = controller.calculate(
      strings: _strings,
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
      strings: _strings,
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
      strings: _strings,
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
      strings: _strings,
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
      strings: _strings,
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
      strings: _strings,
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
      strings: _strings,
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
      strings: _strings,
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
      strings: _strings,
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
      strings: _strings,
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
      strings: _strings,
      toolId: 'regex_test',
      input: r'''
pattern: /(?<word>[a-z]+)-(?<num>\d+)/i
text: ABC-42
no-match
xyz-7
''',
    );
    final chinese = controller.calculate(
      strings: _strings,
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
      strings: _strings,
      toolId: 'regex_test',
      input: 'a.*c\nflags: s\na\nb\nc',
    );
    final global = controller.calculate(
      strings: _strings,
      toolId: 'regex_test',
      input: '/abc/g\nabc abc',
    );
    final invalid = controller.calculate(
      strings: _strings,
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
      strings: _strings,
      toolId: 'jwt_decode',
      input: 'eyJhbGciOiJub25lIn0.eyJleHAiOjEwLCJpYXQiOjF9.signature',
    );
    final rich = controller.calculate(
      strings: _strings,
      toolId: 'jwt_decode',
      input: sampleToken,
    );
    final bearer = controller.calculate(
      strings: _strings,
      toolId: 'jwt_decode',
      input: 'Authorization: Bearer $sampleToken',
    );
    final labeled = controller.calculate(
      strings: _strings,
      toolId: 'jwt_decode',
      input: 'access_token="$sampleToken"',
    );
    final invalid = controller.calculate(
        strings: _strings, toolId: 'json_format', input: '{bad');

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
      strings: _strings,
      toolId: 'jwt_decode',
      input: 'https://example.com/callback?code=ok&id_token=$encodedToken',
    );
    final cookie = controller.calculate(
      strings: _strings,
      toolId: 'jwt_decode',
      input: 'Cookie: theme=dark; access_token=$sampleToken; Path=/',
    );
    final json = controller.calculate(
      strings: _strings,
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
      strings: _strings,
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

/// 中文：这一族测试钉的是**中文下表里的字**，所以表要显式取中文那一份——`calculate` 的
///       `strings` 是必填的，正是在这里把它变成"漏传就编译不过"。
/// English: These tests pin the **Chinese entries in the table**, so the table is the Chinese one
///          explicitly — `calculate`'s `strings` is required, and this is where that turns into
///          "forget it and the build fails".
final _strings = TextToolStrings.forLanguage(AppLanguage.zh);
