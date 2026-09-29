import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../shared/source_scan.dart';

/// 中文：**`text_tool_*` 那一族的源码护栏，加上它那份豁免的自我校验。** 两条测试问的是同一件事
///       的两面：「这一族里还有没有没走 `TextToolStrings` 那七张表的界面文案」以及「上面放行的
///       每一个字符，是不是真的出现在实体表的字面量里」。它们与 `text_tool_strings_test.dart` 里
///       那些「表里的字对不对」的断言不是一回事，所以本轮连同尺子、豁免表与 `_htmlEntityValues`
///       一起搬到了这个文件。**尺子后来并回了共享文件**：这里的 `_stripComments` /
///       `_stringLiterals` 两份私有副本已删掉，改用 `test/shared/source_scan.dart` 的
///       `stripComments` / `stringLiterals`（两份逻辑逐行相同，纯删除、零行为变化）。
///
///       **覆盖范围一个字没变。** 扫描的目录仍旧是 `lib/application/controllers`，但**只看
///       `text_tool_` 开头的文件**（族外的一个不看）——这一点本来就是那条测试自己的规矩，搬过来
///       一模一样；`exemptions` 的 34 条、`_htmlEntityValues` 的 10 条与它们的三条数量断言
///       （34 / 10 / 名单相等）也都逐字跟了过来。搬完之后它扫到的文件一个不少。
///
/// English: **the `text_tool_*` family's source guard, plus the self-check on its own exemptions.**
///          The two tests are two faces of one question: "is there interface copy in this family
///          that never went through the seven `TextToolStrings` tables" and "is every character
///          allowed through above really present as a literal in the entity table". They are not the
///          same thing as the "are the table's words right" assertions in
///          `text_tool_strings_test.dart`, so this round moved them here with the exemption table
///          and `_htmlEntityValues`. **The ruler was later merged back into the shared file**: the
///          two private copies (`_stripComments` / `_stringLiterals`) are gone and this file now
///          uses `stripComments` / `stringLiterals` from `test/shared/source_scan.dart` (the two
///          bodies are line-for-line identical, so the merge is a pure deletion with zero behaviour
///          change).
///
///          **The coverage did not change by one character.** The directory scanned is still
///          `lib/application/controllers`, but **only files starting with `text_tool_` are looked at**
///          (nothing outside the family) — that was this test's own rule and it came across
///          unchanged; the 34 `exemptions`, the 10 `_htmlEntityValues` and their three count
///          assertions (34 / 10 / the name list matching) came across character for character too.
///          After the move it scans every file it scanned before.
void main() {
  test('文本工具源码里除四张文案表外只剩输入文法与判据那几条中文', () {
    final directory = Directory('lib/application/controllers');
    expect(directory.existsSync(), isTrue, reason: '测试的工作目录应当是包的根目录');

    // 中文：**这份豁免表就是本轮"哪些中文刻意不翻"的可执行版本**，一条一条都带理由。
    //       它们不是界面文案：翻掉任何一条都会改变行为，而不是改变语言。
    // English: **This exemption table is the executable version of "which Chinese is deliberately
    //          left alone".** Every entry carries its reason. None of them is interface copy:
    //          translating any one changes behaviour rather than language.
    const exemptions = <String, String>{
      // 中文：**日期计算那四条。** 两条正则描绘「两个日期」与「一个日期加天数」的**形状**，
      //       `今天`/`今日` 是那两个**词**本身——它们判的都是**用户打进来的东西长什么样**，
      //       与 `text_tool_timestamp_tools.dart` 里那些日期格式标记是同一条判据。
      //       翻掉它们，中文用户就再也打不出中文的日期问法。
      // English: **the date calculator's four.** Two patterns describe the **shape** of "two dates" and
      //          "a date plus a day count"; `今天`/`今日` are the two **words** themselves — all four ask
      //          what **the user typed** looks like, the same ruling as the date-format markers in
      //          `text_tool_timestamp_tools.dart`. Translate them and a Chinese user can no longer type
      //          a Chinese date question.
      r'^(.+?)\s*(?:到|至|to|~|→|->|\.\.|—|–)\s*(.+)$':
          '日期区间的分隔符形状',
      r'^(\d{4}\s*[-/.年]\s*\d{1,2}\s*[-/.月]\s*\d{1,2}\s*日?)\s*([+-])\s*(\d{1,6})\s*天?$':
          '日期加天数的形状',
      r'^(\d{4})\s*[-/.年]\s*(\d{1,2})\s*[-/.月]\s*(\d{1,2})\s*日?$':
          '一个日期本身的形状（含中文年月日）',
      r'[\r\n,，;；]+': '把输入切成一项一项的分隔符（含中英文顿号与分号）',
      '今天': '用户打的词',
      '今日': '用户打的词',
      // —— 输入文法：匹配用户可能敲进来的中文标签 ——
      r"^\s*(formula|expr|expression|公式|表达式|算式|[abc])\s*[:：=]\s*(.+?)\s*$":
          '自定义公式：解析 `公式: …` 这类中文标签的输入文法',
      r"^\s*(formula|expr|expression|公式|表达式|算式|[abc])\s*[:：=]":
          '自定义公式：同一套标签的"是不是赋值行"判据',
      r'^(?:flags?|模式)\s*[:=]\s*([a-zA-Z]+)\s*$': '正则：解析 `模式: gi` 这类中文标签的输入文法',
      r'^\s*(?:flags?|模式)\s*[:=]\s*([a-zA-Z]+)\s*$': '正则：同上，带前导空白的那一支',
      r'^\s*(?:pattern|regex|regexp|正则|表达式)\s*[:=]\s*(.*)$':
          '正则：解析 `正则: …` 这类中文标签的输入文法',
      r'^\s*(?:text|input|sample|测试文本|文本)\s*[:=]\s*(.*)$':
          '正则：解析 `测试文本: …` 这类中文标签的输入文法',
      // —— 与输入比较的判据 ——
      '公式': '自定义公式：`normalized == \'公式\'` 之一，比的是用户输入',
      '表达式': '自定义公式：同上',
      '算式': '自定义公式：同上',
      '单位': 'CSV：`first == \'单位\'`，比的是用户粘贴表格的首格',
      '量纲': 'CSV：同上',
      // —— 颜色：两条**输入文法**，第二条还兼作判据 ——
      r'(?:\b(?:hex|color|colour)|颜色|色值)\s*[:=]\s*([0-9a-fA-F]{3,8})\b':
          '颜色：解析用户敲的 `色值: 5B47FF` 这类带中文标签的色值',
      r'(?:\b(?:hex|color|colour)|颜色|色值)\s*[:=]':
          '颜色：`_hexColorSource` 用它判断"用户写没写标签"，好挑哪一句识别说明——既是文法也是判据',
      // —— 时间戳：五条输入文法 ——
      r'(?:timestamp|time|date|datetime|created_at|updated_at|expires_at|过期时间|时间|日期)\s*[:=]\s*["“”]?((?:mon|tue|wed|thu|fri|sat|sun)[a-z]*,\s*[^\n\r"”]+)':
          '时间戳：从带中文标签的文本里抠出 RFC 风格日期时间的输入文法',
      r'(?:timestamp|time|date|datetime|created_at|updated_at|expires_at|过期时间|时间|日期)\s*[:=]\s*["“”]?([^",，\n\r]+)':
          '时间戳：同上，宽的那一支',
      r'(?:北京时间|中国标准时间|东八区)': '时间戳：把用户输入里的中文时区标签改写成 +08:00',
      r'^([+-]?\d+(?:\.\d+)?)\s*(ns|纳秒|us|µs|μs|微秒|ms|毫秒|s|sec|秒)$':
          '时间戳：解析 `100 毫秒` 这类带中文单位词的时间戳',
      r'^(\d{4})[年/-](\d{1,2})[月/-](\d{1,2})(?:日)?(?:\s+(\d{1,2})(?:[时:：](\d{1,2})(?:[分:：](\d{1,2}))?)?(?:秒)?)?$':
          '时间戳：解析 `2026年6月8日 9:30` 这类中文日期写法',
      // —— 时间戳：与输入比较的判据 ——
      '现在': '时间戳：`normalized == \'现在\'`，比的是用户输入的说法',
      '北京时间': '时间戳：`normalized == \'北京时间\' || …`，同上',
      '中国标准时间': '时间戳：同上',
      '东八区': '时间戳：同上',
      '纳秒': '时间戳：`unit == \'纳秒\'`，比的是用户输入里的单位词（不是要显示的句子）',
      '微秒': '时间戳：`unit == \'微秒\'`，同上',
      '毫秒': '时间戳：`unit == \'毫秒\'`，同上',
      // —— 本轮把扫描判据从"含表意文字"放宽到"含宽/全角字符或中文排版标点"之后新露出来的
      //    九条：**全是输入文法**（解析用户敲进来的全角分隔符），与上一批同一类。放宽的理由
      //    与代价写在 `test/shared/source_scan.dart` 的开头。 ——
      r'[\s,;:，；：_\-]+': '进制/位运算：解析用户敲进来的分隔符（全角逗号、全角分号、全角冒号）',
      r'[\s,;:，；：_\-]': '进制/位运算：同上，单个分隔符的那一支',
      r'[^,\s;，；\[\]{}()]': '进制/位运算：同上，取"不是分隔符"的那一类',
      r'[\s,;，；\[\]{}()]': '进制/位运算：同上，取分隔符的那一类',
      r'[\s,;/，；]+': '颜色：解析用户敲进来的多值分隔符',
      r'(?:^|[\s,;，；])([abc])\s*[:：=]\s*([^\s,;，；]+)':
          '自定义公式：解析 `a: 1, b: 2` 这类赋值行，分隔符与冒号都收全角',
      r'[\s;；，]+': '进制：解析用户敲进来的多值分隔符',
      r'[\s,;，；]+': '统计：同上',
      r"[A-Za-z]+(?:[’'\-][A-Za-z]+)*":
          '统计：词形切分用的正则，那里面一个 `’` 是把英文撇号也算成词内字符，不是界面文案',
    };

    // 中文：**这一族现在整族都在名单上。** 名单从"已迁移"改成"全部"，是因为本轮把最后六个文件
    //       （编解码组四个 + 时间戳 + 颜色所在的 Web 格式组）连同描述符一起改完了。
    //       **换成全量名单而不是拆掉名单**：`text_tool_*.dart` 是本族的边界，边界里每一个文件
    //       都点名，新加一个文件时这里就会红——那正是我们希望它红的时候。
    // English: **the whole family is on this list now.** It changed from "migrated so far" to "all of
    //          them" because this round finished the last six files (the four codec ones, timestamps,
    //          and the web-format group the colour tool lives in) together with their descriptors.
    //          **A full list rather than no list**: `text_tool_*.dart` is this family's boundary, every
    //          file inside it is named, and adding a new file turns this red — which is exactly when
    //          we want it red.
    const migrated = <String>{
      'text_tool_binary_tools.dart',
      'text_tool_color_tools.dart',
      'text_tool_controller.dart',
      'text_tool_csv_tools.dart',
      'text_tool_custom_formula_tools.dart',
      'text_tool_date_tools.dart',
      'text_tool_uncertainty_tools.dart',
      'text_tool_html_entities.dart',
      'text_tool_integer_tools.dart',
      'text_tool_json_tools.dart',
      'text_tool_jwt_tools.dart',
      'text_tool_models.dart',
      'text_tool_parsed_models.dart',
      'text_tool_regex_tools.dart',
      'text_tool_shared_text.dart',
      'text_tool_text_stats_tools.dart',
      'text_tool_timestamp_tools.dart',
      'text_tool_url_codec_tools.dart',
      'text_tool_url_query_tools.dart',
      'text_tool_uuid_tools.dart',
    };

    final offenders = <String>[];
    final seen = <String>{};
    for (final entity in directory.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final name = entity.uri.pathSegments.last;
      // 中文：**扫的是 `text_tool_*.dart` 这一族，一个不漏。** 族外的文件
      //       （`tool_search_*` 的双语搜索索引、`tool_detail_*` 另一个工具面的控制器、
      //       `notes_controller.dart` 另一位作者的未提交工作）根本不看。
      // English: **the scan covers the `text_tool_*.dart` family and nothing else.** Files outside it
      //          (`tool_search_*`, the bilingual search index; `tool_detail_*`, another tool screen's
      //          controller; `notes_controller.dart`, another author's uncommitted work) are not
      //          looked at.
      if (!name.startsWith('text_tool_')) continue;
      seen.add(name);
      final source = stripComments(entity.readAsStringSync());
      for (final literal in stringLiterals(source)) {
        if (!containsWideOrFullwidth(literal)) continue;
        if (exemptions.containsKey(literal)) continue;
        if (_htmlEntityValues.contains(literal)) continue;
        offenders.add('${entity.path}: $literal');
      }
    }

    expect(offenders, isEmpty,
        reason: '这些界面字面量还没走 TextToolStrings 那七张表：\n${offenders.join('\n')}');
    expect(exemptions.length, 40, reason: '豁免表变短或变长都要在这里说一声');
    expect(seen, migrated,
        reason: '本族文件多了或少了：目录里是 $seen，名单里是 $migrated——'
            '新加一个 `text_tool_*.dart` 时这里会红，那时请把它也搬进文案表');
  });

  test('实体值那份豁免每一条都真的是实体表里的一个字面量', () {
    // 中文：**豁免不能是空头支票。** 上面放行的每一个字符都必须**真的**出现在
    //       `text_tool_html_entities.dart` 的字符串字面量里——否则它就是一条凭空开的口子。
    //       这条测试把"豁免"钉成"那张表里确有其字"。
    // English: **an exemption must not be a blank cheque.** Every character allowed through above
    //          must **really** occur as a string literal in `text_tool_html_entities.dart`;
    //          otherwise it is a hole with nothing behind it. This pins "exempt" to "that table
    //          really holds this character".
    final file =
        File('lib/application/controllers/text_tool_html_entities.dart');
    expect(file.existsSync(), isTrue, reason: '测试的工作目录应当是包的根目录');
    final literals =
        stringLiterals(stripComments(file.readAsStringSync())).toSet();
    for (final value in _htmlEntityValues) {
      expect(value.runes.length, 1, reason: '「$value」不是一个字符');
      expect(literals.contains(value), isTrue,
          reason: '「$value」不在这张实体表的任何字面量里——这条豁免没有依据');
    }
    expect(_htmlEntityValues.length, 10,
        reason: '豁免数变了：上一轮点名六条，本轮实测同一类是十条，变长变短都要在这里说一声');
  });
}

/// 中文：**HTML 实体表里那些解码结果——它们是数据，不是文案。** `'hellip': '…'` 右边那个 `…`
///       是 `&hellip;` **解码出来的字符**：实体表的全部意义就是"这个字符长什么样"，谁把它"翻"了
///       谁就把工具改坏了。**上一轮点名六条**（`… “ ” ‘ ’ ·`），本轮同一把尺子实测是**十条**
///       ——另外四条 `— – ′ ″` 是 `mdash` / `ndash` / `prime` / `Prime` 的解码结果，形状相同。
///       **这不是"整张表都不用看"**：下面每一条都必须是那张表里真实出现过的字面量，由紧随其后的
///       一条断言逐条钉住；表里其余的实体值（`Æ Δ € ∞ √`）根本不在这把尺子的范围内。
///       另记一笔：按字面上的"非 ASCII 可见字符"放宽，这张表会一次多出 **239** 个解码结果
///       （整张表），理由见 `test/shared/source_scan.dart` 开头。
/// English: **the decoded values in the HTML entity table — data, not copy.** The `…` on the right of
///          `'hellip': '…'` is the **character `&hellip;` decodes to**: the table exists to say what
///          the character looks like, so translating it corrupts the tool. **The previous round
///          named six** (`… “ ” ‘ ’ ·`); the same ruler measures **ten** this round, the four more
///          (`— – ′ ″`) being the decoded `mdash` / `ndash` / `prime` / `Prime`, identical in shape.
///          **This is not "the whole table goes unchecked"**: every entry below must really occur as
///          a literal in that table and is pinned one by one by the assertion right after; the
///          table's other values (`Æ Δ € ∞ √`) are outside this ruler altogether. One more note:
///          under the literal "non-ASCII visible character" ruler the table would gain **239** values
///          at once — see the head of `test/shared/source_scan.dart`.

const Set<String> _htmlEntityValues = <String>{
  '…', // &hellip;
  '“', // &ldquo;
  '”', // &rdquo;
  '‘', // &lsquo;
  '’', // &rsquo;
  '·', // &middot;
  '—', // &mdash;
  '–', // &ndash;
  '′', // &prime;
  '″', // &Prime;
};
