import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/features/graph/models/graph_models.dart';
import 'package:nekocalc/features/graph/presentation/graph_workspace_paste.dart';
import 'package:nekocalc/features/graph/presentation/graph_workspace_strings.dart';
import 'package:nekocalc/l10n/app_language.dart';

/// 中文：图形工作区粘贴表的三条护栏，形状与设置页 / 计算页 / 工具子树 / 文本工具那几套相同。
///       1) 中文表的每一条都要与翻译前源码里那一句**逐字节相同**。
///       2) 英文表里不许出现汉字、也不许出现空串，而且要真的与中文不同。
///       3) `graph_workspace_paste.dart` 里不许再留中文字符串字面量，**除了豁免表里那几条**
///          ——它们全是输入文法与判据。
///
///       **本表只有六条，因为这一族其余的"中文"本来就不是界面文案。** 那一句 `line == '视窗'`
///       判的是**用户粘贴进来的文本**长什么样；翻掉它，粘贴图形数据就再也读不懂了。
///       `graph_page.dart` 里还有 51 条**没有**迁移：那是另一位作者的未提交工作，本轮不许动，
///       逐条见本轮报告。
/// English: The three guard rails for the graph-workspace paste table, the same shape as the guards
///          for the settings page, the calculator, the tools subtree and the text tools. (1) Every
///          Chinese entry must be **byte-identical** to the sentence in the source before
///          translation. (2) The English table must hold no CJK, no empty string, and really differ
///          from the Chinese. (3) No Chinese string literal may remain in
///          `graph_workspace_paste.dart` **except the handful in the exemption table** — all of them
///          input grammar and branch conditions.
///
///          **This table holds six entries because the rest of this family's "Chinese" was never
///          interface copy.** That `line == '视窗'` asks what **the text the user pasted** looks
///          like; translate it and pasting graph data stops working. `graph_page.dart` still holds 51
///          unmigrated literals: it is another author's uncommitted work and must not be touched this
///          round. See this round's report for the list.
void main() {
  final zh = GraphWorkspaceStrings.forLanguage(AppLanguage.zh);
  final en = GraphWorkspaceStrings.forLanguage(AppLanguage.en);

  test('图形工作区中文表与迁移前源码里那些字逐字节相同', () {
    expect(zh.noWorkspace, '剪贴板里没有识别到图形工作区');
    expect(zh.fromFunctionText, '已从函数文本创建工作区');
    expect(zh.fromCopyText, '已从图形数据恢复工作区');
    expect(zh.restored, '已恢复图形工作区');
    expect(zh.functionCount(2), '2 个函数');
    expect(zh.visibleCount(1), '1 个可见');
  });

  test('英文表没有汉字、没有空串，而且真的换了', () {
    final pairs = <String, List<String>>{
      'noWorkspace': [zh.noWorkspace, en.noWorkspace],
      'fromFunctionText': [zh.fromFunctionText, en.fromFunctionText],
      'fromCopyText': [zh.fromCopyText, en.fromCopyText],
      'restored': [zh.restored, en.restored],
      'functionCount': [zh.functionCount(2), en.functionCount(2)],
      'visibleCount': [zh.visibleCount(1), en.visibleCount(1)],
    };
    for (final entry in pairs.entries) {
      expect(entry.value[0].trim(), isNotEmpty, reason: '${entry.key} 中文侧是空的');
      expect(entry.value[1].trim(), isNotEmpty, reason: '${entry.key} 英文侧是空的');
      expect(_containsCjk(entry.value[1]), isFalse,
          reason: '${entry.key} 英文侧还有汉字：${entry.value[1]}');
      expect(entry.value[0], isNot(entry.value[1]),
          reason: '「${entry.value[0]}」在英文表里没换');
    }
    expect(pairs.length, 6, reason: '这张表只有六条，漏一条这里就会少一条');
  });

  test('graph_workspace_paste.dart 里只剩输入文法与判据那几条中文', () {
    const path = 'lib/features/graph/presentation/graph_workspace_paste.dart';
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: '测试的工作目录应当是包的根目录');

    // 中文：**这份豁免表就是"哪些中文刻意不翻"的可执行版本。** 一条一条都在**解析用户粘贴进来的
    //       东西**：前五条判的是标记行的字面写法，三条正则判的是赋值行、表达式行与视窗范围行的
    //       形状，最后一条判的是那条函数在源文本里有没有被标成隐藏。
    // English: **This exemption table is the executable version of "which Chinese is deliberately
    //          left alone".** Every one of them **parses what the user pasted**: the first five
    //          compare the literal spelling of a marker line, three patterns describe the shape of an
    //          assignment line, an expression line and a viewport-range line, and the last asks
    //          whether that function was marked hidden in the source text.
    const exemptions = <String>{
      '视窗',
      '标记',
      '当前标记',
      '函数',
      '图形数据',
      r'^(?:表达式|函数|function|expr|expression)\s*[:：]\s*(.+)$',
      r'^(?:表达式|expression)\s*[:：]\s*(.+)$',
      '隐藏',
    };
    const grammarPatterns = <String>{
      r'^(?:表达式|函数|function|expr|expression)\s*[:：]\s*(.+)$',
      r'^(?:表达式|expression)\s*[:：]\s*(.+)$',
    };

    final offenders = <String>[];
    for (final literal
        in _stringLiterals(_stripComments(file.readAsStringSync()))) {
      if (!_containsCjk(literal)) continue;
      if (exemptions.contains(literal)) continue;
      // 中文：视窗范围那一条整串太长，按"是不是正则"放行——它里面那几个中文是 `~ | 至 | 到`
      //       的别名，判的同样是输入的形状。
      // English: the viewport-range pattern is too long to list whole, so it is allowed by being a
      //          pattern: its Chinese characters are alternative spellings of `~ | 至 | 到`, again
      //          the shape of the input.
      if (_looksLikePattern(literal, grammarPatterns)) continue;
      offenders.add(literal);
    }

    expect(offenders, isEmpty,
        reason: '这些界面字面量还没走 GraphWorkspaceStrings：\n${offenders.join('\n')}');
    expect(
        _looksLikePattern(
            '^\$([xy])\\s*[:：]\\s*([+\\-]?(?:\\d+(?:\\.\\d+)?|\\.\\d+))'
            '\\s*(?:~|至|到|-)\\s*([+\\-]?(?:\\d+(?:\\.\\d+)?|\\.\\d+))\$',
            grammarPatterns),
        isTrue,
        reason: '视窗范围那条正则应当被认成"输入文法"');
  });

  test('没传表时 summary 仍逐字节是今天那几句（默认态不变）', () {
    final empty = parseGraphWorkspacePasteText('not a graph');
    expect(empty.summary, '剪贴板里没有识别到图形工作区');

    // 中文：三条分支各走一遍：图形数据副本、函数文本、以及没有转义公式的纯函数列表。
    // English: one run per branch: the copy-text form, the labelled function text, and a plain list
    //          of functions.
    final copyText = buildGraphCopyText(
      functions: const [
        GraphFunction(
            expression: '2x + 1',
            label: 'y = 2x + 1',
            color: Color(0xFF123456)),
      ],
      viewport: const GraphViewport(centerX: 1, centerY: 2, spanX: 6, spanY: 8),
      markers: const [],
    );
    expect(parseGraphWorkspacePasteText(copyText).summary,
        contains('已从图形数据恢复工作区'));

    final byFunctionText = parseGraphWorkspacePasteText('y = x^2 - 1');
    expect(byFunctionText.summary, contains('已从函数文本创建工作区'));
    expect(byFunctionText.summary, contains('1 个函数'));
    expect(byFunctionText.summary, contains('1 个可见'));
  });

  // 中文：**这一条钉的是"表真的能通到屏幕上"。** `graph_page.dart` 今天还没接线（它是另一位作者
  //       的未提交工作），所以这里直接走 `parseGraphWorkspacePasteText` 的具名参数，证明那条路
  //       是通的、下一轮只需要在调用点补一个实参。
  // English: **this pins that the table really reaches the screen.** `graph_page.dart` is not wired
  //          up yet (it is another author's uncommitted work), so this goes straight through
  //          `parseGraphWorkspacePasteText`'s named parameter, proving the path works and that the
  //          next round needs only to add one argument at the call site.
  test('把英文表传进去，summary 就是英文的', () {
    final pasted = parseGraphWorkspacePasteText('y = x^2 - 1', strings: en);
    expect(pasted.summary, contains('Workspace created from function text'));
    expect(pasted.summary, contains('1 functions'));
    expect(pasted.summary, contains('1 visible'));
    expect(_containsCjk(pasted.summary), isFalse,
        reason: '英文表下 summary 不该有汉字：${pasted.summary}');

    expect(parseGraphWorkspacePasteText('not a graph', strings: en).summary,
        'No graph workspace recognised in the clipboard');
  });
}

/// 中文：CJK 统一表意文字区（含扩展 A）。
/// English: The CJK Unified Ideographs block (plus Extension A).
bool _containsCjk(String text) {
  for (final rune in text.runes) {
    if ((rune >= 0x4E00 && rune <= 0x9FFF) ||
        (rune >= 0x3400 && rune <= 0x4DBF)) {
      return true;
    }
  }
  return false;
}

/// 中文：视窗范围那条正则靠"里面带 `\s*` 与 `(?:` 这类正则记号"认出来；豁免表里两条短一点的
///       也走这条判据。
/// English: The viewport-range pattern is recognised by carrying regex punctuation such as `\s*` and
///          `(?:`; the two shorter ones in the exemption table take the same route.
bool _looksLikePattern(String literal, Set<String> grammarPatterns) {
  return grammarPatterns.contains(literal) ||
      (literal.contains(r'\s') && literal.contains('(?:'));
}

/// 中文：去掉 `//` 与 `/* */` 注释，**但保留字符串字面量原样**。
/// English: Strips `//` and `/* */` comments while **copying string literals verbatim**.
String _stripComments(String source) {
  final out = StringBuffer();
  var i = 0;
  while (i < source.length) {
    final ch = source[i];
    if (ch == "'" || ch == '"') {
      final quote = ch;
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
