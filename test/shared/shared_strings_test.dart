import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/l10n/app_language.dart';
import 'package:nekocalc/shared/presentation/app_drawer.dart';
import 'package:nekocalc/shared/presentation/shared_strings.dart';

/// 中文：外壳与抽屉文案表的三条护栏，形状与设置页 / 计算页那两张表的护栏相同。
///       1) 中文表的每一条都要与翻译前源码里那一句**逐字节相同**——默认语言是中文，所以屏幕上
///          每一个字都得和接入多语言之前一模一样。
///       2) 英文表里不许出现汉字、也不许出现空串。
///       3) `lib/shared/presentation` 里（除了这张表本身）不许再留中文字符串字面量。
///
///       **第 3 条有两处明写的例外**，都在下面 `_nonUiLiterals` 上，理由各自写在它旁边：
///       调试断言的那句话，以及 `CalcTheme.name` 的六个主题名。
/// English: Three guard rails for the shell and drawer table, the same shape as the settings and
///          calculator tables' guards. (1) Every Chinese entry must be **byte-identical** to the
///          sentence in the source before translation — the default language is Chinese, so every
///          character on screen has to read exactly as it did before i18n existed. (2) The English
///          table must hold no CJK and no empty string. (3) No Chinese string literal may remain in
///          `lib/shared/presentation` other than this table.
///
///          **Clause 3 has two stated exceptions**, both on `_nonUiLiterals` below with their reasons
///          beside them: the debug assertion's sentence and the six `CalcTheme.name` theme names.
void main() {
  final zh = SharedStrings.forLanguage(AppLanguage.zh);
  final en = SharedStrings.forLanguage(AppLanguage.en);

  test('中文表与迁移前源码里那些字逐字节相同', () {
    // —— 外壳 ☰ 与抽屉 ——
    expect(zh.openNavigationTooltip, '打开导航');
    expect(zh.navCalculator, '计算');
    expect(zh.navTools, '工具');
    expect(zh.navGraph, '图形');
    expect(zh.navNotes, '笔记');
    expect(zh.navSettings, '设置');

    // 中文：而英文侧真的换了——否则上面那些"逐字节相同"只是把中文抄了两遍。
    // English: and the English side really differs, otherwise the byte-identical checks above would
    //          just be the Chinese copied out twice.
    for (final pair in <List<String>>[
      [zh.openNavigationTooltip, en.openNavigationTooltip],
      [zh.navCalculator, en.navCalculator],
      [zh.navTools, en.navTools],
      [zh.navGraph, en.navGraph],
      [zh.navNotes, en.navNotes],
      [zh.navSettings, en.navSettings],
    ]) {
      expect(pair[0], isNot(pair[1]), reason: '「${pair[0]}」在英文表里没换');
    }
  });

  test('英文表里没有汉字，也没有空串', () {
    final copy = <String, String>{
      'openNavigationTooltip': en.openNavigationTooltip,
      'navCalculator': en.navCalculator,
      'navTools': en.navTools,
      'navGraph': en.navGraph,
      'navNotes': en.navNotes,
      'navSettings': en.navSettings,
    };
    for (final entry in copy.entries) {
      expect(entry.value.trim(), isNotEmpty, reason: '${entry.key} 是空的');
      expect(_containsCjk(entry.value), isFalse,
          reason: '${entry.key} 英文表里还有汉字：${entry.value}');
    }
    // 中文：中文侧同样不许有空串——空串在屏幕上是"这一格什么都没有"，最难发现的一类漏翻。
    // English: the Chinese side must hold no empty string either: on screen it renders as a blank
    //          cell, the hardest kind of missing copy to notice.
    expect(zh.navSettings.trim(), isNotEmpty);
  });

  test('外壳与抽屉源码里除了文案表再没有中文字符串字面量', () {
    final directory = Directory('lib/shared/presentation');
    expect(directory.existsSync(), isTrue, reason: '测试的工作目录应当是包的根目录');

    final offenders = <String>[];
    for (final entity in directory.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final name = entity.uri.pathSegments.last;
      // 中文：文案表自己就是汉字住的地方，跳过它。
      // English: the table is where the Chinese is *supposed* to live; skip it.
      if (name == 'shared_strings.dart') continue;
      final source = _stripComments(entity.readAsStringSync());
      for (final literal in _stringLiterals(source)) {
        if (!_containsCjk(literal)) continue;
        if (_nonUiLiterals[name]?.contains(literal) ?? false) continue;
        offenders.add('${entity.path}: $literal');
      }
    }

    expect(offenders, isEmpty,
        reason: '这些界面字面量还没走 SharedStrings：\n${offenders.join('\n')}');
  });

  testWidgets('没有装作用域时抽屉仍渲染中文（默认态不变）', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: _drawer),
    ));
    expect(find.text('计算'), findsOneWidget);
    expect(find.text('工具'), findsOneWidget);
    expect(find.text('图形'), findsOneWidget);
    expect(find.text('笔记'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });

  testWidgets('装上 AppLanguageScope(en) 之后同一个抽屉渲染英文', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: AppLanguageScope(
        language: AppLanguage.en,
        child: Scaffold(body: _drawer),
      ),
    ));
    expect(find.text('Calculator'), findsOneWidget);
    expect(find.text('Tools'), findsOneWidget);
    expect(find.text('Graph'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('计算'), findsNothing);
    expect(find.text('设置'), findsNothing);
  });
}

const Widget _drawer = AppDrawer(
  selectedIndex: AppDrawer.calculatorDestination,
  onSelect: _noopInt,
  onOpenSettings: _noop,
);

void _noop() {}

void _noopInt(int _) {}

/// 中文：**不是界面文案**的那几条字面量，逐文件列出。
///       - `app_shell.dart`：调试断言的句子。它只在 debug 构建里、按键带了一个不认识的目的地时
///         才会被抛出来，形状与 `calculator_key_dispatch.dart` 里的那句逐字相同。它不翻——
///         把它翻成英文，读日志的人反而要按界面语言去猜。
///       - `calc_theme.dart`：`CalcTheme.name` 的六个主题名。它们是 `const`，进不了
///         `SharedStrings`（`static final`）；屏幕上那三个名字自上一轮起由
///         `SettingsStrings.themeLabel(themeId)` 提供，中文侧与它们逐字节相同，由
///         `settings_strings_test.dart` 逐套主题钉住。所以它们**不再上屏**，只作为那条断言的
///         参照物留着。
///       **别把界面文案加进这个表**：上面的理由才是入选条件，不是"省事"。
/// English: **never user-facing** literals, listed per file.
///          - `app_shell.dart`: the debug assertion's sentence. It is thrown only in debug builds, when
///            a key carries an unrecognised destination, and its shape is item-for-item the one in
///            `calculator_key_dispatch.dart`. It is not translated — rendering it in one language
///            would only make whoever reads the log guess at the interface language.
///          - `calc_theme.dart`: the six `CalcTheme.name` theme names. They are `const` and cannot go
///            into `SharedStrings` (a `static final` table); since the previous round the three
///            on-screen names come from `SettingsStrings.themeLabel(themeId)`, whose Chinese side is
///            byte-identical to them and is pinned theme by theme in `settings_strings_test.dart`. So
///            they **no longer reach the screen** and survive only as that assertion's reference.
///          **Do not add UI copy to this map**: the reason above is what qualifies an entry, not
///          convenience.
const Map<String, Set<String>> _nonUiLiterals = <String, Set<String>>{
  'app_shell.dart': <String>{
    r'未知的导航目的地 / unknown navigation destination: $destination',
  },
  'calc_theme.dart': <String>{
    '玫瑰奶霜',
    '薰衣草雾',
    '蜜桃砂糖',
    '玫瑰奶霜 深色',
    '薰衣草雾 深色',
    '蜜桃砂糖 深色',
  },
};

/// 中文：CJK 统一表意文字区（含扩展 A）。够用了：本项目的界面文案都落在这里。
/// English: The CJK Unified Ideographs block (plus Extension A) — enough, since this project's UI
///          copy lives there.
bool _containsCjk(String text) {
  for (final rune in text.runes) {
    if ((rune >= 0x4E00 && rune <= 0x9FFF) ||
        (rune >= 0x3400 && rune <= 0x4DBF)) {
      return true;
    }
  }
  return false;
}

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
