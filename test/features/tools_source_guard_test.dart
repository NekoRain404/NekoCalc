import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../shared/source_scan.dart';

/// 中文：**工具子树那条源码护栏。** 它问的是「`lib/features/tools/presentation` 里还有没有没走
///       `ToolsStrings` / `DataFitStrings` 的界面文案」，与 `tools_strings_test.dart` 里那些
///       「表里的字对不对」的断言是两件事，所以本轮它连同它那一把尺子（`_stripComments` /
///       `_stringLiterals`）与那份逐条带理由的豁免表一起搬到了这个文件。
///
///       **覆盖范围一个字没变。** 扫描的目录仍旧是 `lib/features/tools/presentation`（递归、全部
///       `.dart`），跳过的仍旧只有九张文案表的名字，判据仍旧是 `containsWideOrFullwidth`，豁免的
///       仍旧只有 `_punctuationOnlyLiterals` 里那四条——两个文件里的这条测试**逐字相同**，只是
///       换了住址；搬完之后它扫到的文件一个不少（新加的三个文件也照扫，而它们不含界面文案）。
///
/// English: **the tools subtree's source guard.** It asks "is there interface copy left in
///          `lib/features/tools/presentation` that never went through `ToolsStrings` /
///          `DataFitStrings`", which is a different question from the "are the table's words right"
///          assertions in `tools_strings_test.dart`, so this round moved it here together with its
///          ruler (`_stripComments` / `_stringLiterals`) and the exemption table that carries a
///          reason per entry.
///
///          **The coverage did not change by one character.** The directory scanned is still
///          `lib/features/tools/presentation` (recursive, every `.dart`), the only names skipped are
///          still the nine copy tables, the ruler is still `containsWideOrFullwidth`, and the only
///          exemptions are still the four literals in `_punctuationOnlyLiterals` — this test is
///          **character for character** what it was, with a new address; after the move it scans
///          every file it scanned before (the three files added this round are scanned too, and they
///          hold no interface copy).
void main() {
  test('工具子树源码里除了两张文案表再没有中文字符串字面量', () {
    final directory = Directory('lib/features/tools/presentation');
    expect(directory.existsSync(), isTrue, reason: '测试的工作目录应当是包的根目录');

    final offenders = <String>[];
    for (final entity in directory.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final name = entity.uri.pathSegments.last;
      // 中文：文案表自己就是汉字住的地方，跳过它们。文本工具那一族有七张
      //       （门面 + 识别组 + 统计 + 数据组 + 编解码组 + Web 格式组 + 时间戳），
      //       它们和这两张一样是本目录里的"汉字之家"。
      //       **这一串只加表名，不给非表文件开口子**：`text_tool_detail_screen.dart` 之类的
      //       界面文件仍然照扫不误。
      // English: the tables are where the Chinese is *supposed* to live; skip them. The text-tool
      //          family has seven (facade + recognition + statistics + data + codec + web-format +
      //          timestamps) and they are "Chinese homes" in this directory just like these two.
      //          **Only table names go on this list, never a screen file**: interface files such as
      //          `text_tool_detail_screen.dart` are still scanned like everything else.
      if (name == 'tools_strings.dart' ||
          name == 'data_fit_strings.dart' ||
          name == 'text_tool_strings.dart' ||
          name == 'text_tool_text_strings.dart' ||
          name == 'text_tool_stats_strings.dart' ||
          name == 'text_tool_data_strings.dart' ||
          name == 'text_tool_codec_strings.dart' ||
          name == 'text_tool_web_strings.dart' ||
          name == 'text_tool_timestamp_strings.dart') {
        continue;
      }
      final source = _stripComments(entity.readAsStringSync());
      for (final literal in _stringLiterals(source)) {
        if (!containsWideOrFullwidth(literal)) continue;
        if (_punctuationOnlyLiterals.contains(literal)) continue;
        offenders.add('${entity.path}: $literal');
      }
    }

    expect(offenders, isEmpty,
        reason:
            '这些界面字面量还没走 ToolsStrings / DataFitStrings：\n${offenders.join('\n')}');
  });
}

/// 中文：**放宽判据之后新露出来的四条，逐条带理由**（判据见 `test/shared/source_scan.dart`）。
///       没有一条是句子：一条是 `data_fit_tool_screen.dart` 里那张"粘贴全角数字也能认"的
///       **示例数据**，另外三条是三处 `·`——**分隔符**，两处夹在插值之间，一处自成一条。
///       **别把界面文案加进这个表**：入选条件是上面这些理由，不是方便。
/// English: **the four literals the widened ruler newly exposes, each with its reason** (the ruler is
///          in `test/shared/source_scan.dart`). Not one is a sentence: one is the **sample data** of
///          `data_fit_tool_screen.dart`'s "full-width digits are recognised too" example, the other
///          three are the separator `·` — two between interpolations, one standing alone. **Do not
///          add interface copy to this set**: the reasons above qualify an entry, not convenience.

const Set<String> _punctuationOnlyLiterals = <String>{
  // 中文：**照抄源码里那两个字面量的原文**——`\n` 与 `$` 都得原样留着（扫描器取的就是
  //       引号之间的原文），所以这三条是 raw 字符串。
  // English: **spelled exactly as they stand in the source** — the `\n` and the `$` have to stay
  //          literal (the scanner yields the raw text between the quotes), hence raw strings.
  r'x,y\n１,５０％\n２,１００％\n３,１.５\n４,２.０',
  r'${tool.description} · $matchLabel',
  r'${category.title} · $count',
  ' · ',
};

/// 中文：去掉 `//` 与 `/* */` 注释，**但保留字符串字面量原样**——注释里会出现引号
///       （本项目的中文注释就常写 `'关闭'`），先按引号整体跳过，注释才不会被截错。
/// English: Strips `//` and `/* */` comments while **copying string literals verbatim**: this
///          project's Chinese comments quote literals such as `'关闭'`, so quotes are skipped as whole
///          units first; otherwise the comment stripper would cut in the wrong place.
String _stripComments(String source) {
  final out = StringBuffer();
  var i = 0;
  while (i < source.length) {
    final ch = source[i];
    if (ch == "'" || ch == '"') {
      final quote = ch;
      // 中文：三引号原样成块跳过。
      // English: Triple quotes are skipped as a block.
      final triple = source.startsWith(quote * 3, i);
      final delimiter = triple ? quote * 3 : quote;
      out.write(delimiter);
      i += delimiter.length;
      while (i < source.length) {
        if (source[i] == r'\') {
          out.write(source.substring(i, i + 2));
          i += 2;
          continue;
        }
        if (source.startsWith(delimiter, i)) {
          out.write(delimiter);
          i += delimiter.length;
          break;
        }
        out.write(source[i]);
        i++;
      }
      continue;
    }
    if (ch == '/' && i + 1 < source.length && source[i + 1] == '/') {
      while (i < source.length && source[i] != '\n') {
        i++;
      }
      continue;
    }
    if (ch == '/' && i + 1 < source.length && source[i + 1] == '*') {
      i += 2;
      while (i + 1 < source.length &&
          !(source[i] == '*' && source[i + 1] == '/')) {
        i++;
      }
      i += 2;
      continue;
    }
    out.write(ch);
    i++;
  }
  return out.toString();
}

/// 中文：取出源码里所有单/双引号字符串字面量的内容。
/// English: Extracts the contents of every single- and double-quoted string literal in the source.
Iterable<String> _stringLiterals(String source) sync* {
  var i = 0;
  while (i < source.length) {
    final ch = source[i];
    if (ch != "'" && ch != '"') {
      i++;
      continue;
    }
    final quote = ch;
    final triple = source.startsWith(quote * 3, i);
    final delimiter = triple ? quote * 3 : quote;
    i += delimiter.length;
    final buffer = StringBuffer();
    while (i < source.length) {
      if (source[i] == r'\') {
        buffer.write(source.substring(i, i + 2));
        i += 2;
        continue;
      }
      if (source.startsWith(delimiter, i)) {
        i += delimiter.length;
        break;
      }
      buffer.write(source[i]);
      i++;
    }
    yield buffer.toString();
  }
}
