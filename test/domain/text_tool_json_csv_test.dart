import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/controllers/text_tool_controller.dart';
import 'package:nekocalc/features/tools/presentation/text_tool_strings.dart';
import 'package:nekocalc/l10n/app_language.dart';

void main() {
  const controller = TextToolController();

  test('json and csv tools return validation insights', () {
    final json = controller.calculate(
      strings: _strings,
      toolId: 'json_format',
      input:
          '\ufeff{"name":"NekoCalc","tools":["json","csv"],"meta":{"ok":true,"none":null}}',
    );
    final csv = controller.calculate(
      strings: _strings,
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
      strings: _strings,
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
      strings: _strings,
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
      strings: _strings,
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
      strings: _strings,
      toolId: 'csv_json',
      input: '''
{"user":{"id":1,"name":"Neko"},"score":98}
{"user":{"id":2,"name":"Calc"},"tags":["json","csv"],"active":true}
''',
    );
    final jsonLike = controller.calculate(
      strings: _strings,
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
      strings: _strings,
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
      strings: _strings,
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
      strings: _strings,
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
      strings: _strings,
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
      strings: _strings,
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
      strings: _strings,
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
      strings: _strings,
      toolId: 'json_format',
      input: r'"{\"name\":\"NekoCalc\",\"items\":[1,2],\"ok\":true}"',
    );
    final log = controller.calculate(
      strings: _strings,
      toolId: 'json_format',
      input:
          r'INFO payload="{\"name\":\"NekoCalc\",\"nested\":{\"ok\":true}}" status=200',
    );
    final singleLineJsonLike = controller.calculate(
      strings: _strings,
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
      strings: _strings,
      toolId: 'json_format',
      input: '''
Here is the payload:
```json
{"name":"NekoCalc","ok":true}
```
''',
    );
    final assignment = controller.calculate(
      strings: _strings,
      toolId: 'json_format',
      input: '''
const payload = {
  name: 'NekoCalc',
  nested: { ok: true, },
};
''',
    );
    final log = controller.calculate(
      strings: _strings,
      toolId: 'json_format',
      input: 'INFO response payload={"items":[{"id":1},{"id":2}],"ok":true};',
    );
    final trailingLog = controller.calculate(
      strings: _strings,
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
      strings: _strings,
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
      strings: _strings,
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
      strings: _strings,
      toolId: 'csv_json',
      input: 'name;score\nNeko;98\nCalc;100',
    );
    final pipe = controller.calculate(
      strings: _strings,
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
      strings: _strings,
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
      strings: _strings,
      toolId: 'csv_json',
      input: '''
time,temp,pressure
units,s,degC,kPa
1,20,100
2,25,110
''',
    );
    final markdown = controller.calculate(
      strings: _strings,
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
      strings: _strings,
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
      strings: _strings,
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
      strings: _strings,
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
}

/// 中文：这一族测试钉的是**中文下表里的字**，所以表要显式取中文那一份——`calculate` 的
///       `strings` 是必填的，正是在这里把它变成"漏传就编译不过"。
/// English: These tests pin the **Chinese entries in the table**, so the table is the Chinese one
///          explicitly — `calculate`'s `strings` is required, and this is where that turns into
///          "forget it and the build fails".
final _strings = TextToolStrings.forLanguage(AppLanguage.zh);
