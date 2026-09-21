import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/features/graph/models/graph_strings.dart';
import 'package:nekocalc/features/graph/presentation/graph_page.dart';
import 'package:nekocalc/l10n/app_language.dart';

import '../shared/source_scan.dart';

/// 中文：**graph 整棵子树的护栏，形状与设置页 / 计算页 / 工具子树 / 笔记页 / 文本工具那几套相同。**
///       1) 中文表的每一条都要与迁移前源码里那一句**逐字节相同**——默认语言是中文，所以屏幕上每
///          一个字都得和接入多语言之前一模一样。逐条写出来而不是抽查几条：这一份就是"默认态不变"
///          的**证据本身**，抽查漏掉的那一条正好是将来会漂的那一条。
///       2) 英文表里不许出现汉字、也不许出现空串；除**语言无关**的少数几条外，还得真的与中文不同。
///       3) `lib/features/graph/` 子树里（除了这张表本身）不许再留界面中文字符串字面量，
///          **除了豁免表里那几条**——它们全是输入文法与判据，翻掉它们粘贴就坏了。
///       4) 英文表真的能通到屏幕上：装上 `AppLanguageScope(en)` 渲染整页，看到的是英文。
///
///       **为什么第 3 条要扫整棵子树而不是一个文件。** 迁移前这一族的中文分两处：粘贴结果那张
///       六条的表，以及页面里 51 条直接写死的中文；模型层（预览句、标记 `kind`/`info`、复制文本的
///       小节名）也各写各的。本轮把两处合成一张 `graph_strings.dart`，所以护栏也升级成"整棵子树
///       一处都不许漏"——**按文件白名单扫描正是当初让那 51 条溜过去的原因。**
///
///       **豁免表就是"哪些中文刻意不翻"的可执行版本。** 它们全在**解析用户粘贴进来的文本**：
///       标记行的字面写法（`视窗` / `标记` / `当前标记` / `函数` / `图形数据` / `隐藏`）、赋值行 /
///       表达式行 / 视窗范围行的形状（三条正则）、剥列表符号的文法（两条正则，`、` 是"中文顿号也
///       算编号符号"的记号）、以及一个 ` · ` 分隔符。模型层那五个单字/全角标点（`（ ） ， ： ＝`）
///       是**表达式归一化文法**——用户写全角括号也得认。
/// English: **the guard rails for the whole graph subtree, the same shape as the guards for the
///          settings page, the calculator, the tools subtree, the notes page and the text tools.**
///          (1) Every Chinese entry must be **byte-identical** to the sentence in the source before
///          translation — the default language is Chinese, so every character on screen has to read
///          exactly as it did before i18n existed. Written out one by one rather than sampled: this
///          list **is** the evidence for "the default state does not change", and the one entry a spot
///          check skips is the one that drifts. (2) The English table must hold no CJK, no empty
///          string, and — apart from the few **language-neutral** entries — really differ from the
///          Chinese. (3) No Chinese string literal may remain anywhere under `lib/features/graph/`
///          (except the table itself) **besides the handful in the exemption table** — all of them
///          input grammar and branch conditions that break pasting if translated. (4) The English
///          table really reaches the screen: render the whole page under `AppLanguageScope(en)` and
///          read English.
///
///          **Why rail 3 scans the whole subtree rather than one file.** Before this round the family's
///          Chinese lived in two places: the six-entry paste-result table and 51 literals written
///          straight into the page, plus whatever the models layer wrote (the preview sentence, the
///          marker `kind`/`info`, the copy text's section names). This round merges both into one
///          `graph_strings.dart`, so the guard is upgraded to "not one literal left anywhere in the
///          subtree" — **a per-file allow-list is exactly what let those 51 slip through.**
///
///          **The exemption table is the executable version of "which Chinese is deliberately left
///          alone".** Every one of them **parses what the user pasted**: the literal spelling of a
///          marker line (`视窗` / `标记` / `当前标记` / `函数` / `图形数据` / `隐藏`), the shape of an
///          assignment line, an expression line and a viewport-range line (three patterns), the
///          grammar that strips list markers (two patterns; `、` is one of that grammar's marks, "a
///          Chinese enumeration comma counts as a numbering mark too"), and one ` · ` separator. The
///          models layer's five single characters / fullwidth marks (`（ ） ， ： ＝`) are the
///          **expression-normalisation grammar** — a user writing a fullwidth bracket still has to be
///          understood.
void main() {
  final zh = GraphStrings.graphZh;
  final en = GraphStrings.graphEn;

  // 中文：**这张表就是"默认态不变"的证据。** 每一行：字段名、中文表里的值、英文表里的值、迁移前
  //       源码里的那一句（钉死的原句）。第二项与第四项必须逐字节相同。
  // English: **this table is the evidence for "the default state does not change".** Each row:
  //          field name, the value in the Chinese table, the value in the English table, and the
  //          sentence from the source before migration (the pinned original). Items two and four must
  //          be byte-identical.
  final entries = <_Entry>[
    _Entry('pageTitle', zh.pageTitle, en.pageTitle, '图形'),
    _Entry('pasteTooltip', zh.pasteTooltip, en.pasteTooltip, '粘贴图形数据'),
    _Entry('copyTooltip', zh.copyTooltip, en.copyTooltip, '复制图形数据'),
    _Entry('exportPngTooltip', zh.exportPngTooltip, en.exportPngTooltip,
        '导出图形 PNG'),
    _Entry('addFunction', zh.addFunction, en.addFunction, '添加函数'),
    _Entry('addConfirm', zh.addConfirm, en.addConfirm, '添加'),
    _Entry('editFunction', zh.editFunction, en.editFunction, '编辑函数'),
    _Entry('saveConfirm', zh.saveConfirm, en.saveConfirm, '保存'),
    _Entry('deleteFunction', zh.deleteFunction, en.deleteFunction, '删除函数'),
    _Entry('functionActions', zh.functionActions, en.functionActions, '函数操作'),
    _Entry('reset', zh.reset, en.reset, '重置'),
    _Entry('fit', zh.fit, en.fit, '适配'),
    _Entry('zoomIn', zh.zoomIn, en.zoomIn, '放大'),
    _Entry('zoomOut', zh.zoomOut, en.zoomOut, '缩小'),
    _Entry('zerosButton', zh.zerosButton, en.zerosButton, '零点'),
    _Entry('intersectionsButton', zh.intersectionsButton,
        en.intersectionsButton, '交点'),
    _Entry('extremesButton', zh.extremesButton, en.extremesButton, '极值'),
    _Entry('panHint', zh.panHint, en.panHint, '拖动画布平移，双指缩放'),
    _Entry('addedFunction', zh.addedFunction('x'), en.addedFunction('x'),
        '已添加 y = x'),
    _Entry('shownFunction', zh.shownFunction('y = x'),
        en.shownFunction('y = x'), '已显示 y = x'),
    _Entry('hiddenFunction', zh.hiddenFunction('y = x'),
        en.hiddenFunction('y = x'), '已隐藏 y = x'),
    _Entry('updatedFunction', zh.updatedFunction('x'), en.updatedFunction('x'),
        '已更新 y = x'),
    _Entry('deletedFunction', zh.deletedFunction('y = x'),
        en.deletedFunction('y = x'), '已删除 y = x'),
    _Entry('viewReset', zh.viewReset, en.viewReset, '视图已重置'),
    _Entry('invalidWorkspace', zh.invalidWorkspace, en.invalidWorkspace,
        '图形工作区数据无效，已恢复默认视图'),
    _Entry('restoredWorkspace', zh.restoredWorkspace, en.restoredWorkspace,
        '已恢复上次图形工作区'),
    _Entry('viewRange', zh.viewRange('1.0', '2.0'), en.viewRange('1.0', '2.0'),
        '视图范围 x: 1.0 ~ 2.0'),
    _Entry('panRange', zh.panRange('1.0', '2.0'), en.panRange('1.0', '2.0'),
        'x: 1.0 ~ 2.0'),
    _Entry('zoomed', zh.zoomed('1.00'), en.zoomed('1.00'), '缩放 1.00x'),
    _Entry('noVisibleFunction', zh.noVisibleFunction, en.noVisibleFunction,
        '没有可见函数可适配'),
    _Entry('notEnoughSamples', zh.notEnoughSamples, en.notEnoughSamples,
        '当前视图没有足够的有效采样点'),
    _Entry('fittedVisible', zh.fittedVisible, en.fittedVisible, '已适配当前可见曲线'),
    _Entry('sampleNone', zh.sampleNone('1.000000'), en.sampleNone('1.000000'),
        'x = 1.000000 处没有可见有效函数值'),
    _Entry('sampleDone', zh.sampleDone('1.000000', 2),
        en.sampleDone('1.000000', 2), 'x = 1.000000，已取样 2 条曲线'),
    _Entry('noZeros', zh.noZeros, en.noZeros, '当前视图未找到零点'),
    _Entry(
        'foundZeros', zh.foundZeros(2), en.foundZeros(2), '找到 2 个零点，点击高亮点查看详情'),
    _Entry(
        'noIntersections', zh.noIntersections, en.noIntersections, '当前视图未找到交点'),
    _Entry('foundIntersections', zh.foundIntersections(2),
        en.foundIntersections(2), '找到 2 个交点，点击高亮点查看详情'),
    _Entry('noExtremes', zh.noExtremes, en.noExtremes, '当前视图没有有效极值采样'),
    _Entry('foundExtremes', zh.foundExtremes(2), en.foundExtremes(2),
        '找到 2 个极值点，点击高亮点查看详情'),
    _Entry(
        'copiedGraphData', zh.copiedGraphData, en.copiedGraphData, '已复制图形数据'),
    _Entry('savedPng', zh.savedPng, en.savedPng, '图形已保存为 PNG'),
    _Entry('cancelledSave', zh.cancelledSave, en.cancelledSave, '已取消保存图形'),
    _Entry('exportFailed', zh.exportFailed('boom'), en.exportFailed('boom'),
        '导出图形失败：boom'),
    _Entry('copiedMarker', zh.copiedMarker, en.copiedMarker, '已复制当前标记'),
    _Entry('centeredOn', zh.centeredOn('y = x zero'),
        en.centeredOn('y = x zero'), '已居中到 y = x zero'),
    _Entry('previousMarker', zh.previousMarker, en.previousMarker, '上一个标记'),
    _Entry('nextMarker', zh.nextMarker, en.nextMarker, '下一个标记'),
    _Entry('copyMarker', zh.copyMarker, en.copyMarker, '复制标记'),
    _Entry('centerOnMarker', zh.centerOnMarker, en.centerOnMarker, '居中到标记'),
    _Entry('hide', zh.hide, en.hide, '隐藏'),
    _Entry('show', zh.show, en.show, '显示'),
    _Entry('expressionHint', zh.expressionHint, en.expressionHint,
        '例如 sin(x)、2x + 1、y = x^2 - 3x + 2'),
    _Entry('cancel', zh.cancel, en.cancel, '取消'),
    _Entry(
        'enterExpression', zh.enterExpression, en.enterExpression, '请输入函数表达式'),
    _Entry('willPlot', zh.willPlot('y = x', 5), en.willPlot('y = x', 5),
        '将绘制 y = x，有效采样 5/5'),
    _Entry('cannotCompute', zh.cannotCompute, en.cannotCompute,
        '表达式无法计算，请检查函数名、括号或变量 x'),
    _Entry('graphDataTitle', zh.graphDataTitle, en.graphDataTitle, '图形数据'),
    _Entry('functionsSection', zh.functionsSection, en.functionsSection, '函数'),
    _Entry('none', zh.none, en.none, '无'),
    _Entry('expressionLine', zh.expressionLine('x^2'), en.expressionLine('x^2'),
        '   表达式: x^2'),
    _Entry('viewportSection', zh.viewportSection, en.viewportSection, '视窗'),
    _Entry('currentMarkerSection', zh.currentMarkerSection,
        en.currentMarkerSection, '当前标记'),
    _Entry('markersSection', zh.markersSection, en.markersSection, '标记'),
    _Entry('sampleKind', zh.sampleKind, en.sampleKind, '取样'),
    _Entry('zeroKind', zh.zeroKind, en.zeroKind, '零点'),
    _Entry('overlapKind', zh.overlapKind, en.overlapKind, '重合'),
    _Entry('intersectionKind', zh.intersectionKind, en.intersectionKind, '交点'),
    _Entry('minimumKind', zh.minimumKind, en.minimumKind, '极小值'),
    _Entry('maximumKind', zh.maximumKind, en.maximumKind, '极大值'),
    _Entry('overlapsAxis', zh.overlapsAxis('y = 0'), en.overlapsAxis('y = 0'),
        'y = 0 与 x 轴重合\n当前视图内所有 x 都是零点'),
    _Entry('zeroAt', zh.zeroAt('y = x', '0.000000'),
        en.zeroAt('y = x', '0.000000'), 'y = x 零点\nx = 0.000000\ny = 0'),
    _Entry('overlapText', zh.overlapText('a', 'b'), en.overlapText('a', 'b'),
        'a\nb\n两条曲线在当前视图内重合'),
    _Entry('intersectionText', zh.intersectionText('a', 'b', '1', '2'),
        en.intersectionText('a', 'b', '1', '2'), 'a\nb\n交点 x = 1, y = 2'),
    _Entry(
        'extremumText',
        zh.extremumText('y = x', '极小值', '1', '2'),
        en.extremumText('y = x', 'minimum', '1', '2'),
        'y = x 极小值\nx = 1\ny = 2'),
    _Entry('noWorkspace', zh.noWorkspace, en.noWorkspace, '剪贴板里没有识别到图形工作区'),
    _Entry('fromFunctionText', zh.fromFunctionText, en.fromFunctionText,
        '已从函数文本创建工作区'),
    _Entry('fromCopyText', zh.fromCopyText, en.fromCopyText, '已从图形数据恢复工作区'),
    _Entry('workspaceRestored', zh.workspaceRestored, en.workspaceRestored,
        '已恢复图形工作区'),
    _Entry('functionCount', zh.functionCount(2), en.functionCount(2), '2 个函数'),
    _Entry('visibleCount', zh.visibleCount(1), en.visibleCount(1), '1 个可见'),
  ];

  test('图形子树中文表的每一条都与迁移前源码逐字节相同', () {
    final wrong = <String>[];
    for (final entry in entries) {
      if (entry.zh != entry.pinnedZh) {
        wrong.add('${entry.name}：表里是「${entry.zh}」，源码里是「${entry.pinnedZh}」');
      }
    }
    expect(wrong, isEmpty, reason: '默认态变了：\n${wrong.join('\n')}');
    expect(entries, hasLength(81), reason: '这张表有 81 格；改表却忘了在这里加一行，这条就会响');
  });

  test('英文表没有汉字、没有空串，而且除语言无关项外真的换了', () {
    // 中文：`panRange` 是**语言无关**的一格：中文界面与英文界面都显示 `x: 1.0 ~ 2.0`。
    //       这一格刻意不翻，写在这里免得护栏把它当成"忘了翻"。
    // English: `panRange` is a **language-neutral** entry: both the Chinese and the English interface
    //          show `x: 1.0 ~ 2.0`. It is deliberately untranslated and listed here so the guard does
    //          not read it as a missed translation.
    const languageNeutral = <String>{'panRange'};

    for (final entry in entries) {
      expect(entry.zh.trim(), isNotEmpty, reason: '${entry.name} 中文侧是空的');
      expect(entry.en.trim(), isNotEmpty, reason: '${entry.name} 英文侧是空的');
      expect(_containsCjk(entry.en), isFalse,
          reason: '${entry.name} 英文侧还有汉字：${entry.en}');
      if (!languageNeutral.contains(entry.name)) {
        expect(entry.zh, isNot(entry.en),
            reason: '${entry.name} 在英文表里没换：「${entry.en}」');
      }
    }
  });

  test('graph 子树里除表本身外，只剩输入文法与判据那几条中文', () {
    const root = 'lib/features/graph';
    const tablePath = 'lib/features/graph/models/graph_strings.dart';
    final rootDir = Directory(root);
    expect(rootDir.existsSync(), isTrue, reason: '测试的工作目录应当是包的根目录');

    // 中文：**这份豁免表就是"哪些中文刻意不翻"的可执行版本。** 三条一组：
    //       - 粘贴解析器判标记行字面写法的六个词与一个分隔符；
    //       - 模型层做**表达式归一化**的五个单字/全角标点——用户写全角括号也得认；
    //       - 其余的正则走 `_looksLikePattern`（带 `\s*` 与 `(?:` 的一律认成文法）。
    // English: **this exemption table is the executable version of "which Chinese is deliberately
    //          left alone".** Three groups: the paste parser's six marker-line words plus one
    //          separator; the models layer's five single characters / fullwidth marks used for
    //          **expression normalisation** (a user writing a fullwidth bracket still has to be
    //          understood); the remaining patterns go through `_looksLikePattern` (anything carrying
    //          `\s*` and `(?:` counts as grammar).
    const exemptions = <String>{
      // —— 粘贴解析器判标记行 / 分隔符 ——
      '视窗',
      '标记',
      '当前标记',
      '函数',
      '图形数据',
      '隐藏',
      ' · ',
      // 中文：**剥列表符号的输入文法**——`、` 是"中文顿号也算编号符号"的记号，判的是用户粘进来的
      //       形状。短的那条没有 `(?:`，走不到 `_looksLikePattern`，所以逐条列出来。
      // English: **the input grammar that strips list markers** — `、` is the mark meaning "a Chinese
      //          enumeration comma counts as a numbering mark too", parsing the shape of what the user
      //          pasted. The short one has no `(?:`, so `_looksLikePattern` does not catch it; it is
      //          listed here explicitly.
      r'^\d+[.)、]',
      // —— 模型层表达式归一化 ——
      '（',
      '）',
      '，',
      '：',
      '＝',
    };

    final offenders = <String>[];
    for (final entity in rootDir.listSync(recursive: true)) {
      if (entity is! File) continue;
      final path = entity.path.replaceAll('\\', '/');
      if (!path.endsWith('.dart')) continue;
      if (path == tablePath) continue;
      for (final literal
          in stringLiterals(stripComments(entity.readAsStringSync()))) {
        if (!containsWideOrFullwidth(literal)) continue;
        if (exemptions.contains(literal)) continue;
        if (_looksLikePattern(literal)) continue;
        offenders.add('$path: $literal');
      }
    }

    expect(offenders, isEmpty,
        reason: '这些界面字面量还没走 GraphStrings：\n${offenders.join('\n')}');
  });

  testWidgets('装上 AppLanguageScope(en) 之后整页渲染英文', (tester) async {
    final settingsCompleter = Completer<Map<String, String>>()..complete({});
    final db = _FakeGraphDatabase(settingsCompleter);

    await tester.pumpWidget(MaterialApp(
      home: AppLanguageScope(
        language: AppLanguage.en,
        child: Scaffold(
          body: GraphPage(db: db, restoreState: true),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // 中文：**先看顶上那一行**（页面标题与三个工具按钮），再上滑看底下的动作按钮——整页比屏幕高。
    // English: **check the top row first** (the page title and three tool buttons), then scroll down
    //          for the action buttons — the page is taller than the screen.
    expect(find.text('Graph'), findsOneWidget);
    expect(find.byTooltip('Paste graph data'), findsOneWidget);
    expect(find.byTooltip('Copy graph data'), findsOneWidget);
    expect(find.byTooltip('Add function'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(find.text('Zoom in'), findsOneWidget);
    expect(find.text('Zeros'), findsOneWidget);
    expect(find.text('Intersections'), findsOneWidget);
    expect(find.text('Extrema'), findsOneWidget);
  });

  test('把英文表传进粘贴解析，summary 与工作区都是英文的', () {
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

class _Entry {
  const _Entry(this.name, this.zh, this.en, this.pinnedZh);

  final String name;
  final String zh;
  final String en;
  final String pinnedZh;
}

class _FakeGraphDatabase implements AppDatabase {
  _FakeGraphDatabase(this._settingsCompleter);

  final Completer<Map<String, String>> _settingsCompleter;
  final savedSettings = <String, String>{};

  @override
  Future<Map<String, String>> settings() async {
    return _settingsCompleter.future;
  }

  @override
  Future<void> setSetting(String key, String value) async {
    savedSettings[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

/// 中文：带 `\s*` 与 `(?:` 这类正则记号的一律认成"输入文法"，不必逐条列进豁免表。
/// English: Anything carrying regex punctuation such as `\s*` and `(?:` counts as "input grammar"
///          and need not be listed in the exemption table one by one.
bool _looksLikePattern(String literal) {
  return literal.contains(r'\s') && literal.contains('(?:');
}
