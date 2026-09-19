import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/application/controllers/tool_detail_controller.dart';
import 'package:nekocalc/application/controllers/tool_search_engine.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/repositories/history_repository.dart';
import 'package:nekocalc/data/repositories/notes_repository.dart';
import 'package:nekocalc/data/repositories/tool_usage_repository.dart';
import 'package:nekocalc/domain/entities/tool_definition.dart';
import 'package:nekocalc/domain/usecases/tool_catalog.dart';
import 'package:nekocalc/features/tools/presentation/tool_detail_screen.dart';
import 'package:nekocalc/features/tools/presentation/tool_result_label_strings.dart';
import 'package:nekocalc/features/tools/presentation/tool_result_label_strings_electronics.dart';
import 'package:nekocalc/features/tools/presentation/tool_result_label_strings_finance.dart';
import 'package:nekocalc/features/tools/presentation/tool_result_label_strings_math.dart';
import 'package:nekocalc/features/tools/presentation/tool_result_label_strings_mechanical.dart';
import 'package:nekocalc/features/tools/presentation/tool_result_label_strings_science.dart';
import 'package:nekocalc/features/tools/presentation/tool_widgets.dart';
import 'package:nekocalc/l10n/app_language.dart';

import '../shared/source_scan.dart';

/// 中文：**结果标签表的六条护栏**，形状与工具子树另外几张表相同：
///       1) **默认态逐字节不变**：中文下每个标签都必须原样返回，中文表那一个 map **必须是空的**。
///       2) **英文表覆盖所有该翻的标签**：源码里每个**带汉字**的结果标签都有条目，非空、无汉字、
///          **没有一条等于它的键**（相等就是没翻）。
///       3) **没有死条目**：每个键都必须在源码里真的出现（键是字串，抄错一个字符就会变成一条
///          永远查不到的条目）；六个分类文件**互不相交**，合并后正好 715 条。
///       4) **数学记号逐字符活着**：中文按 CJK 与全角断开，凡**非 CJK 的连续段**都要在英文里
///          原样找得到（尺子是 `test/shared/source_scan.dart` 里那把，不是手写清单）。
///       5) **屏幕上真的换了**：详情页的结果卡与主结果框，两种语言各是各的。
///       6) **检索没动**：`result.label` 不进检索，表也只被显示读——域层与控制器层一个文件都不许
///          提到它，而中文词照旧找得到工具。
///
///       **标签是位置参数，不是具名参数。** 提取用的是
///       `ToolResult(...)` / `.number(...)` / `.invalid(...)` 后面第一个字符串字面量，
///       **不是** `label:` —— 按 `label:` 去数会数到 0。
///
/// English: **the six guard rails for the result-label table**, the same shape as the tools subtree's
///          other tables: (1) **the default state is byte-identical** — in Chinese every label comes
///          back unchanged and the Chinese map **must be empty**; (2) **the English table covers
///          everything that needs translating** — every **Han-bearing** result label in the sources has
///          an entry, none empty, none holding a Han character, and **not one equal to its key**;
///          (3) **no dead entries** — every key must really occur in the sources (a one-character typo
///          in a key makes an entry that can never be found), the six category files are **disjoint**,
///          and the merge is exactly 715; (4) **the mathematical notation survives character for
///          character** — the Chinese is cut at CJK and full-width boundaries and every **non-CJK run**
///          must be found verbatim in the English (the ruler is the one in
///          `test/shared/source_scan.dart`, not a hand-written list); (5) **the screen really changed** —
///          the detail page's result card and primary-result box are each language's own; (6) **search
///          did not move** — `result.label` never entered search and the table is read for display only,
///          so no file in the domain or controller layers may mention it, and Chinese words still find
///          their tools.
///
///          **The label is a positional argument, not a named one.** Extraction takes the first string
///          literal after `ToolResult(...)` / `.number(...)` / `.invalid(...)`, **not** `label:` —
///          counting on `label:` counts zero.
void main() {
  final sites = _labelSites();
  final en = ToolResultLabelStrings.forLanguage(AppLanguage.en);
  final zh = ToolResultLabelStrings.forLanguage(AppLanguage.zh);

  test('中文表是空的（键就是中文），每个标签在中文下逐字节原样返回', () {
    // 中文：**两个数是"遍历没跑空"的证据**——数错了比断言写错更危险。
    // English: **both numbers are the proof the walk was not vacuous** — a mis-count is more dangerous
    //          than a wrong assertion.
    expect(sites.fileCount, 17, reason: 'calculate_tool*.dart 一共 17 个文件');
    expect(sites.siteCount, 1774,
        reason: '源码里第一个位置参数是字面量的构造处一共 1774 处，少了说明扫描没跑对');
    expect(sites.allLiterals.length, 794, reason: '去重后全部字面量标签 794 条');
    expect(sites.labels.length, 715, reason: '去重后带汉字的结果标签一共 715 条');
    expect(zh.labels, isEmpty,
        reason: '中文表必须是空的——键就是屏幕上那句中文，写一份只会多出 715 条"值等于键"的行');
    for (final label in sites.labels) {
      expect(zh.label(label), label,
          reason: '「$label」在中文下不是原样返回——默认语言的那份必须逐字节不变');
    }
  });

  test('英文表：带汉字的标签一条不漏、非空、无汉字、没有一条等于它的键', () {
    final missing = <String>[];
    var identical = 0;
    for (final source in sites.labels) {
      final value = en.labels[source];
      if (value == null) {
        missing.add('「$source」在英文表里没有条目');
        continue;
      }
      expect(value, isNotEmpty, reason: '「$source」的英文是空串');
      // 中文：**判据是"有没有汉字"**——与兄弟表英文那一侧同一条理由：记号（`Ω`、`℃`、`·`）不在
      //       其列，英文那一侧本来就该留着它们。
      // English: **the criterion is "does it hold a Han character"** — the same reason as the sibling
      //          tables' English side: notation (`Ω`, `℃`, `·`) is not in that class and belongs there.
      expect(_han.hasMatch(value), isFalse,
          reason: '「$source」的英文里有汉字：$value');
      if (value == source) identical++;
    }
    expect(missing, isEmpty, reason: missing.join('\n'));
    expect(identical, 0, reason: '有 $identical 条英文与中文一字不差——那些行根本没翻');
  });

  test('没有死条目：每个键都在源码里出现；六个文件互不相交，合并正好 715 条', () {
    // 中文：**"死条目"是这张表最可能的坏法**：键抄错一个字符就永远查不到，而屏幕上看不出来
    //       （回落成中文，与"本来就该是中文"长得一模一样）。
    // English: **a dead entry is the likeliest way for this table to go wrong**: a one-character typo in
    //          a key is never looked up, and on screen it is invisible (it falls back to Chinese, which
    //          looks exactly like "this one was meant to stay Chinese").
    for (final entry in en.labels.entries) {
      expect(sites.allLiterals, contains(entry.key),
          reason: '死条目：「${entry.key}」在 calculate_tool*.dart 里根本不出现');
    }
    // 中文：**六个文件互不相交**——合并用的是常量展开，Dart 对常量 map 的重复键是编译期错误，
    //       所以这条不是"约定"而是"写不出来"；这里把它当成断言再钉一次，顺便钉住条数。
    // English: **the six files are disjoint** — the merge is a constant spread and Dart makes a duplicate
    //          key in a constant map a compile-time error, so this is "cannot be written" rather than "a
    //          convention". Pinned again as an assertion here, together with the counts.
    final parts = <String, Map<String, String>>{
      'shared': toolResultLabelsSharedEn,
      'math': toolResultLabelsMathEn,
      'electronics': toolResultLabelsElectronicsEn,
      'mechanical': toolResultLabelsMechanicalEn,
      'finance': toolResultLabelsFinanceEn,
      'science': toolResultLabelsScienceEn,
    };
    var total = 0;
    final seen = <String, String>{};
    for (final part in parts.entries) {
      total += part.value.length;
      for (final key in part.value.keys) {
        expect(seen.containsKey(key), isFalse,
            reason: '「$key」同时出现在 ${seen[key]} 与 ${part.key} 里');
        seen[key] = part.key;
      }
    }
    expect(total, 715, reason: '六个文件合起来应当是 715 条，现在是 $total');
    expect(en.labels.length, 715, reason: '合并后应当是 715 条，现在是 ${en.labels.length}');
    // 中文：**六个文件的大小是分类的规模**，写下来是为了让"某次编辑把一半条目搬错文件"当场露出来。
    // English: **the six files' sizes are the categories' sizes**; writing them down makes "an edit moved
    //          half the entries into the wrong file" show up at once.
    expect(toolResultLabelsSharedEn.length, 20);
    expect(toolResultLabelsMathEn.length, 106);
    expect(toolResultLabelsElectronicsEn.length, 221);
    expect(toolResultLabelsMechanicalEn.length, 137);
    expect(toolResultLabelsFinanceEn.length, 107);
    expect(toolResultLabelsScienceEn.length, 124);
  });

  test('数学记号逐字符活着：中文里每一段非 CJK 的字串都必须在英文里原样找得到', () {
    var checked = 0;
    final missing = <String>[];
    for (final source in sites.labels) {
      final target = en.labels[source];
      if (target == null) continue;
      for (final run in notationRuns(source)) {
        checked++;
        if (!target.contains(run)) {
          missing.add('记号「$run」\n    中文 $source\n    英文 $target');
        }
      }
    }
    // 中文：**132 是本轮实测的记号段数**，数的是**不同标签**上的出现处。这把尺子认的是
    //       `notationRuns`，改中文时它自己跟着变；下面这个数只做"断言没空转"的证据。
    // English: **132 is this round's measured run count** over **distinct labels**. The ruler is
    //          `notationRuns`, which follows the Chinese when it changes; the number below only proves
    //          the loop ran.
    expect(checked, 132, reason: '记号段数变了（$checked）：中文改过，或者遍历没跑全');
    expect(missing, isEmpty,
        reason: '这些记号在英文里没了——记号是语言无关的，必须逐字符活着：\n${missing.join('\n')}');
  });

  testWidgets('详情页：结果卡与主结果框两种语言各是各的，英文下这两处没有汉字', (tester) async {
    final zhReadings = await _pumpDetail(tester, AppLanguage.zh, 'battery_life');
    final enReadings = await _pumpDetail(tester, AppLanguage.en, 'battery_life');

    // 中文：**两处落点都要有东西，否则下面几条断言是空转。**
    // English: **both landing places need content, or the assertions below are vacuous.**
    expect(zhReadings.cells, isNotEmpty, reason: '结果卡上一格都没渲染出来');
    expect(enReadings.cells, isNotEmpty, reason: '英文结果卡上一格都没渲染出来');
    expect(zhReadings.cells.length, enReadings.cells.length,
        reason: '两种语言渲染出来的结果格数不同：${zhReadings.cells.length} 对 '
            '${enReadings.cells.length}');
    expect(zhReadings.primaryRendered, isNotNull, reason: '中文主结果框没渲染出来');
    expect(enReadings.primaryRendered, isNotNull, reason: '英文主结果框没渲染出来');
    expect(zhReadings.primaryRendered, zhReadings.primaryLabel());

    // 中文：**中文那一侧逐字节还是 `result.label` 本身**——`DetailMetric` 自己带着目录里那句，
    //       屏幕上那一格必须就是它。
    // English: **the Chinese side is still `result.label` itself, byte for byte** — the `DetailMetric`
    //          carries the catalogue's sentence, and the cell on screen must be exactly that.
    for (final reading in zhReadings.cells) {
      expect(reading.rendered, reading.source,
          reason: '中文结果卡上「${reading.source}」被改成了「${reading.rendered}」');
    }
    // 中文：**英文那一侧逐格是表里那句；中文那句带汉字时，屏幕上那一格就不许再有汉字。**
    // English: **on the English side every cell is the table's sentence; where the Chinese carries a Han
    //          character, the rendered cell may not.**
    var translatedCells = 0;
    for (final reading in enReadings.cells) {
      final expected = en.label(reading.source);
      expect(reading.rendered, expected,
          reason: '英文结果卡上「${reading.source}」渲染成了「${reading.rendered}」，'
              '表里写的是「$expected」');
      if (!_han.hasMatch(reading.source)) continue;
      translatedCells++;
      expect(_han.hasMatch(reading.rendered), isFalse,
          reason: '英文结果卡上还有汉字：${reading.rendered}');
      expect(reading.rendered, isNot(reading.source),
          reason: '英文结果卡上「${reading.source}」还是中文');
    }
    expect(translatedCells, greaterThan(0), reason: '一格带汉字的结果标签都没有，这条断言会空转');
    expect(enReadings.primaryRendered, en.label(enReadings.primaryLabel()),
        reason: '英文主结果框上那句不是表里那一句');
    expect(_han.hasMatch(enReadings.primaryRendered!), isFalse,
        reason: '英文主结果框上还有汉字：${enReadings.primaryRendered}');
  });

  test('检索没动：域层与控制器层一个文件都不提这张表，中文词照旧找得到工具', () {
    // 中文：**这条问的是"表有没有被接进不该接的地方"**——`result.label` 本来就不在检索字段里，
    //       本表只被显示读。域层（目录、计算）与控制器层（检索、详情）提到它就说明它越界了。
    // English: **this asks whether the table has been wired somewhere it does not belong** —
    //          `result.label` was never a search field and this table is read for display only. A
    //          mention in the domain layer (catalogue, calculators) or the controller layer (search,
    //          detail) means it has crossed the line.
    final offenders = <String>[];
    for (final directory in <Directory>[
      Directory('lib/domain'),
      Directory('lib/application/controllers'),
    ]) {
      expect(directory.existsSync(), isTrue, reason: '测试的工作目录应当是包的根目录');
      for (final entity in directory.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.readAsStringSync().contains('ToolResultLabelStrings')) {
          offenders.add(entity.path);
        }
      }
    }
    expect(offenders, isEmpty,
        reason: '这些非显示层文件提到了 ToolResultLabelStrings（本表只被显示读）：\n'
            '${offenders.join('\n')}');
    // 中文：**行为上再钉一次**：按中文的关键词仍然找得到工具，命中文本仍然是目录里那句中文。
    //       这一条不碰分数（分数没有测试钉住），只钉"中文还找得到"与"命中还是中文"。
    // English: **and once more behaviourally**: Chinese keywords still find their tools and the matched
    //          text is still the catalogue's Chinese. This does not touch the scores (no test pins them)
    //          — only "Chinese still finds it" and "the match is still Chinese".
    final hits = ToolSearch.searchTools('续航');
    expect(hits.map((result) => result.tool.id), contains('battery_life'),
        reason: '中文关键词「续航」找不到 battery_life 了');
    final ranked = ToolSearch.rankTool(
        toolById('battery_life')!, '续航', const <String>['续航']);
    expect(ranked.score, greaterThan(0), reason: '「续航」对 battery_life 的分数是 0');
    expect(_han.hasMatch(ranked.matchText), isTrue,
        reason: '命中文本不是中文了：${ranked.matchText}');
  });
}

/// 中文：一次详情页读数：结果卡上每一格的"目录里那句"与"屏幕上那句"，外加主结果框那一句。
/// English: one detail-page reading: each result card cell's catalogue sentence and rendered sentence,
///          plus the primary box's rendered sentence.
class _ScreenReadings {
  _ScreenReadings(this.cells, this.tool, this.primaryRendered);

  final List<_CellReading> cells;
  final ToolDefinition tool;
  final String? primaryRendered;

  /// 中文：主结果框那一句在目录里是哪个标签——**从控制器问，不在测试里抄中文**。
  /// English: which catalogue label the primary box carries — **asked of the controller, never copied
  ///          into the test**.
  String primaryLabel() {
    final controller = _controllerFor(tool);
    return controller.primary!.label;
  }
}

class _CellReading {
  const _CellReading(this.source, this.rendered);

  final String source;
  final String rendered;
}

final RegExp _han = RegExp(r'[㐀-䶿一-鿿豈-﫿]');

ToolDetailController _controllerFor(ToolDefinition tool) {
  const db = _EmptyDatabase();
  return ToolDetailController(
    historyRepository: const HistoryRepository(db),
    notesRepository: const NotesRepository(db),
    toolUsageRepository: const ToolUsageRepository(db),
    tool: tool,
  );
}

/// 中文：**详情页读数。** 结果卡那几格用 `DetailMetric` 自己带的 `result.label` 去找屏幕上那一格；
///       主结果框不是 `DetailMetric`，所以按控制器里那条 primary 的标签去找。
/// English: **the detail-page reading.** The result-card cells are located by the `result.label` the
///          `DetailMetric` widget itself carries; the primary box is not a `DetailMetric`, so it is
///          located through the primary entry the controller reports.
Future<_ScreenReadings> _pumpDetail(
    WidgetTester tester, AppLanguage language, String toolId) async {
  // 中文：**详情页上那条已知的 12px 溢出会照常发生**——它在本轮之前就在，与本轮无关
  //       （`tool_field_strings_test.dart` 里那条护栏逐字认得它）。这里把它单独放行，
  //       **别的异常仍然让这条测试当场变红**。
  // English: **the detail page's known 12px overflow still happens** — it predates this round and has
  //          nothing to do with it (`tool_field_strings_test.dart`'s guard recognises it word for
  //          word). It is let through here on its own, and **anything else still turns this test red**.
  final errors = _DetailErrors()..install();
  // 中文：**先换一棵空树再渲染这一屏**——`ToolDetailScreen` 的 `State` 在 `initState` 里建控制器，
  //       同一个元素位置换成另一个工具时 `initState` 不再跑（真机上每次都是新 push 一屏，碰不到）。
  // English: **swap in an empty tree before rendering** — `ToolDetailScreen`'s State builds its
  //          controllers in `initState`, which does not run again when the same element position is
  //          given another tool (on a device each screen arrives through its own push, so it never
  //          happens there).
  await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
  await tester.pump();
  tester.view.physicalSize = const Size(360 * 3, 2200 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final tool = toolById(toolId)!;
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: AppLanguageScope(
        language: language,
        child: ToolDetailScreen(
            db: const _EmptyDatabase(),
            tool: tool,
            settings: AppSettings.fallback),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  // 中文：**先把处理器还回去，再断言**——测试框架在 `FlutterError.onError` 被接管时收到未处理的
  //       错误会直接断言失败并挂到超时，所以读出读数之后立刻还原。
  // English: **hand the handler back before asserting** — with `FlutterError.onError` overridden an
  //          unhandled error makes the framework assert outright and hang to its timeout, so it is
  //          restored as soon as the readings are taken.
  errors.restore();
  errors.expectNothingElse();

  final table = ToolResultLabelStrings.forLanguage(language);
  final cells = <_CellReading>[];
  for (final element in find.byType(DetailMetric).evaluate()) {
    final metric = element.widget as DetailMetric;
    final source = metric.result.label;
    cells.add(_CellReading(
        source, _renderedOrNull(tester, table.label(source)) ?? ''));
  }
  final primary = _controllerFor(tool).primary!;
  return _ScreenReadings(
      cells, tool, _renderedOrNull(tester, table.label(primary.label)));
}

/// 中文：屏幕上有没有这一格文字（`Text` 的原文逐字节相同）。找不到返回 `null`，好让断言自己红。
/// English: whether a cell with exactly this text is on screen (`Text`'s data, byte for byte). `null`
///          when it is not, so the assertion goes red on its own.
String? _renderedOrNull(WidgetTester tester, String text) {
  for (final element in find.byType(Text).evaluate()) {
    final widget = element.widget as Text;
    if (widget.data == text) return widget.data;
  }
  return null;
}

/// 中文：源码里那些结果标签。**取的是位置参数**（见 `main` 上面那段）。
/// English: the result labels in the sources. **The positional argument is what is taken** (see the note
///          above `main`).
class _LabelSites {
  const _LabelSites(
      this.labels, this.allLiterals, this.siteCount, this.fileCount);

  /// 中文：去重后**带汉字**的标签，715 条。
  /// English: the de-duplicated **Han-bearing** labels, 715 of them.
  final Set<String> labels;

  /// 中文：去重后**全部**字面量标签，794 条（含 79 条整条都是记号的）。
  /// English: every de-duplicated literal label, 794 of them (including the 79 that are notation end to
  /// end).
  final Set<String> allLiterals;

  /// 中文：构造处数，1774（第一个实参是形参的那 10 处不算）。
  /// English: the number of construction sites, 1774 (the 10 whose first argument is a parameter are not
  /// counted).
  final int siteCount;

  /// 中文：扫过的文件数，17（`calculate_tool*.dart` 全族）。
  /// English: how many files were scanned, 17 (the whole `calculate_tool*.dart` family).
  final int fileCount;
}

/// 中文：`ToolResult(` / `.number(` / `.invalid(` 后面第一个字符串字面量。
///       **只扫 `lib/domain/usecases/calculate_tool*.dart`**——1784 个构造处里有 1779 个在这里，
///       剩下 5 个是 `tool_definition.dart` 里的类型定义本身，没有标签。
///       `[ToolResult.number]` 这种注释里的链接不带 `(`，所以匹配不到；条数断言是这条前提的守卫。
/// English: the first string literal after `ToolResult(` / `.number(` / `.invalid(`. **Only
///          `lib/domain/usecases/calculate_tool*.dart` is scanned** — 1779 of the 1784 sites are there and
///          the other 5 are the type definition itself in `tool_definition.dart`, which carries no
///          label. A comment link such as `[ToolResult.number]` has no `(` after it and cannot match;
///          the site-count assertion is what guards that assumption.
_LabelSites _labelSites() {
  final pattern = RegExp(r"ToolResult(?:\.(?:number|invalid))?\(\s*'([^']*)'");
  final labels = <String>{};
  final all = <String>{};
  var count = 0;
  final files = Directory('lib/domain/usecases')
      .listSync()
      .whereType<File>()
      .where((file) =>
          file.path.endsWith('.dart') &&
          file.uri.pathSegments.last.startsWith('calculate_tool'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in files) {
    for (final match in pattern.allMatches(file.readAsStringSync())) {
      final literal = match.group(1)!;
      count++;
      all.add(literal);
      if (_han.hasMatch(literal)) labels.add(literal);
    }
  }
  return _LabelSites(labels, all, count, files.length);
}

/// 中文：**详情页上那条已知的 12px 溢出**，逐字与 `tool_field_strings_test.dart` 里那条相同
///       （同一个 widget、同一句消息）。**别把它当成"这一屏可以随便报错"**：放行的只有这一条，
///       别的错误进 [others]，[expectNothingElse] 一红就是这条测试失败。
/// English: **the detail page's known 12px overflow**, word for word the one in
///          `tool_field_strings_test.dart` (same widget, same message). **This is not "this screen may
///          throw"**: exactly one error is let through, everything else lands in [others], and
///          [expectNothingElse] failing is this test failing.
class _DetailErrors {
  int knownOverflows = 0;
  final List<String> others = <String>[];
  void Function(FlutterErrorDetails)? _previous;

  void install() {
    _previous = FlutterError.onError;
    FlutterError.onError = _collect;
    addTearDown(restore);
  }

  void restore() {
    final previous = _previous;
    if (previous == null) return;
    FlutterError.onError = previous;
    _previous = null;
  }

  void _collect(FlutterErrorDetails details) {
    final text = details.exceptionAsString();
    // 中文：**认到具体是哪个 widget 为止**——`context` / `library` / `summary` 都只有一句"渲染时
    //       溢出"，认不出是谁；widget 的创建链在 `informationCollector` 里，把它取出来才对得上。
    // English: **recognised down to which widget** — `context` / `library` / `summary` carry no more
    //          than an "overflowed during layout"; the widget's creator chain lives in
    //          `informationCollector` and has to be pulled out to identify the culprit.
    final information = details.informationCollector
            ?.call()
            .map((node) => node.toString())
            .join('\n') ??
        '';
    if (text.contains('A RenderFlex overflowed by 12 pixels on the bottom') &&
        information.contains('DetailMetric')) {
      knownOverflows++;
      return;
    }
    others.add('$text\n$information');
  }

  void expectNothingElse() {
    expect(others, isEmpty, reason: '详情页上出现了这条已知溢出之外的异常：${others.join('；')}');
    expect(knownOverflows, greaterThan(0),
        reason: '那条已知溢出一条都没出现——溢出没了要么是好事（那就把这段拆掉），'
            '要么是这屏根本没渲染出来');
  }
}

/// 中文：详情页只读设置与历史，这两样在这个假库里给空值就够，其余走 `noSuchMethod`。
/// English: the detail page reads settings and history; empty values are enough here and everything else
///          goes through `noSuchMethod`.
class _EmptyDatabase implements AppDatabase {
  const _EmptyDatabase();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<Map<String, String>> settings() async => const {};

  @override
  Future<void> setSettings(Map<String, String> values) async {}

  @override
  Future<void> setSetting(String key, String value) async {}

  @override
  Future<Set<String>> favoriteToolIds() async => const {};

  @override
  Future<void> setFavorite(String toolId, bool favorite) async {}

  @override
  Future<void> markRecent(String toolId) async {}

  @override
  Future<List<String>> recentToolIds({int limit = 8}) async => const [];
}
