import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/features/calculator/presentation/calculator_strings.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/dataset_sheet.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/unit_picker_sheet.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/variable_picker_sheet.dart';
import 'package:nekocalc/l10n/app_language.dart';

/// 中文：计算页文案表的三条护栏，形状与设置页那张表的护栏（`settings_strings_test.dart`）相同。
///       1) 中文表的每一条都要与翻译前源码里那一句**逐字节相同**——默认语言是中文，所以屏幕上
///          每一个字都得和接入多语言之前一模一样。逐条写出来而不是抽查几条：这一份就是"默认态
///          不变"的**证据本身**，抽查漏掉的那一条正好是将来会漂的那一条。
///       2) 英文表里不许出现汉字、也不许出现空串。
///       3) 计算页源码里（除了这张表本身）不许再留中文字符串字面量。
///
///       **第 3 条有两处明写的例外**，都在下面 `_skipFiles` / `_nonUiLiterals` 上，理由各自写在
///       它们旁边：`inline_expression_editor.dart` 是**用户未提交的改动**（本轮一个字都没动），
///       以及那条调试断言的句子（用户永远看不到）。除了这两处，扫描是"一个中文字面量都不许有"。
/// English: Three guard rails for the calculator page's copy table, the same shape as the settings
///          table's (`settings_strings_test.dart`). (1) Every Chinese entry must be **byte-identical**
///          to the sentence that was in the source before translation — the default language is
///          Chinese, so every character on screen has to read exactly as it did before i18n existed.
///          Written out one by one rather than sampled: this list **is** the evidence for "the default
///          state does not change", and the one entry a spot check skips is the one that drifts.
///          (2) The English table must hold no CJK and no empty string. (3) No Chinese string literal
///          may remain in the calculator page's sources other than this table.
///
///          **Clause 3 has two stated exceptions**, both on `_skipFiles` / `_nonUiLiterals` below with
///          their reasons beside them: `inline_expression_editor.dart` is **the user's uncommitted
///          work** (not one character of it was touched this round) and the debug assertion's sentence
///          (never reaches a user). Everything else is scanned with "not one Chinese literal".
void main() {
  final zh = CalculatorStrings.forLanguage(AppLanguage.zh);
  final en = CalculatorStrings.forLanguage(AppLanguage.en);

  test('中文表与迁移前源码里那些字逐字节相同', () {
    // —— 主屏显示区 ——
    expect(zh.openNavigationTooltip, '打开导航');
    // —— `More...` 动作面板 ——
    expect(zh.actionEditExpression, '编辑表达式');
    expect(zh.actionBackspace, '退格');
    expect(zh.actionUndo, '撤销');
    expect(zh.actionRedo, '重做');
    expect(zh.actionCopyResult, '复制结果');
    expect(zh.actionContinueWith, '继续使用');
    expect(zh.actionSaveNote, '保存笔记');
    expect(zh.actionMoveToStart, '移到开头');
    expect(zh.actionMoveToEnd, '移到末尾');
    expect(zh.actionSettings, '设置');
    expect(zh.cursorLeftTooltip, '光标左移（长按按表达式块左移后连续移动）');
    expect(zh.cursorRightTooltip, '光标右移（长按按表达式块右移后连续移动）');
    expect(zh.detailsCopied, '已复制计算详情');
    expect(zh.detailsCopyFailed, '无法复制计算详情');
    expect(zh.clipboardReadFailed, '无法读取剪贴板');
    // —— `CONV` 单位面板 ——
    expect(zh.unitSearchHint, '搜索单位（米、km、mile…）');
    expect(zh.unitSheetHint, '点一个单位插进表达式；两个单位之间点「to」');
    expect(zh.noMatchingUnits, '没有匹配的单位');
    // —— `X` 变量面板 ——
    expect(zh.variableSheetTitle, '变量');
    expect(zh.noStorableValue, '当前没有可存入的数值（结果没有十进制形态，或者不是有限数）');
    expect(zh.currentValueReading('4'), '当前值 4');
    expect(zh.unassigned, '未赋值');
    expect(zh.insertVariable('x'), '插入 x');
    expect(zh.storeCurrentValue, '存入当前值');
    expect(zh.clearBinding, '清除');
    // —— 数据集编辑面板 ——
    expect(zh.datasetSheetTitle, '统计数据集');
    expect(zh.datasetEmptyReading('1,2,3,4'), '数据集是空的，插入的调用用起手数据 1,2,3,4。');
    expect(zh.datasetValuesReading(3), '数据集 3 个值；插入的调用用它们，按现在的顺序。');
    expect(zh.noDatasetValues, '还没有值');
    expect(zh.noAddableValue, '当前没有可加入的数值（结果没有十进制形态，或者不是有限数）');
    expect(zh.addCurrentResultReading('5'), '加入当前结果 5');
    expect(zh.addCurrentResult, '加入当前结果');
    expect(zh.clearDataset, '清空');
    expect(zh.removeValueTooltip, '去掉这个值');
    // —— `STAT` 统计面板 ——
    expect(zh.datasetSheetButton, '数据集…');
    expect(zh.datasetCallEmpty('1,2,3,4'), '数据集空，插入起手数据 1,2,3,4');
    expect(zh.datasetCallValues(3, '5, 12, 13'), '数据集 3 个：5, 12, 13');
    expect(
      zh.statisticsHint,
      '插入的是完整调用；实参来自数据集，数据集为空时用起手数据，'
      '插入之后那串数仍可在内联编辑器里改（逗号可以打）。'
      'stdev/var 按样本（n−1）算；pearson/covar 按总体（n）算。',
    );
    expect(zh.twoVariableRowTitle, '两变量');
    expect(zh.datasetAsTwoRows('pearson(matrix(2,3,5,12,13,1,2,3))'),
        '数据集读成两行：pearson(matrix(2,3,5,12,13,1,2,3))');
    expect(zh.fitRowTitle, '拟合');
    expect(zh.regressionGraphButton, '回归图…');
    // —— 回归图面板 ——
    expect(zh.curveRowTitle, '曲线');
    expect(zh.curveLoading, '正在向引擎要这条曲线的点…');
    expect(
      zh.curveReading('linearfit(x,y)', 121, 8),
      'linearfit(x,y) 的曲线：'
      '引擎在 121 个取样位置上给了值；'
      '数据集里 8 个点也在图上',
    );
    // —— `x⇔E` 结果格式菜单 ——
    expect(zh.resultFormatDefaultLabel, '默认');
    expect(
        zh.resultFormatDefaultNote, '本应用自己的一行（精确写法 + ≈ 十进制读数）；HiPER 的菜单里没有这一项');
    expect(
      zh.resultFormatPolarNote,
      '本应用没有极坐标印法：引擎那一份是求值选项（会改值），而且印出来的是 '
      'r(cos θ + i sin θ)，不是 HiPER 那一格 r∠θ',
    );
    expect(
        zh.resultFormatSubtitle, '结果行的写法。灰掉的项按不下去：不是这一份结果没有这一格，就是本应用今天印不出这一格');
    expect(
      zh.resultFormatGapNotFromEngine('分数写法'),
      '本应用没有它的分数写法：这一份结果不是引擎算的，而这一格只有引擎印得出来',
    );
    expect(
      zh.resultFormatGapTypesettingOff('分数写法'),
      '本应用今天印不出它的分数写法：表达式显示设成了「数学表达式」，'
      '结果行不排任何写法、边打边算也不问引擎',
    );
    expect(zh.spellingExact, '精确写法');
    expect(zh.spellingFraction, '分数写法');
    expect(zh.spellingMixed, '带分数写法');
    expect(zh.spellingDms, '度分秒写法');
    expect(zh.spellingAuto, '写法');
    // —— 通用 ——
    expect(zh.close, '关闭');

    // 中文：而英文侧真的换了——否则上面那些"逐字节相同"只是把中文抄了两遍。
    // English: and the English side really differs, otherwise the byte-identical checks above would
    //          just be the Chinese copied out twice.
    for (final pair in <List<String>>[
      [zh.openNavigationTooltip, en.openNavigationTooltip],
      [zh.actionEditExpression, en.actionEditExpression],
      [zh.actionBackspace, en.actionBackspace],
      [zh.actionUndo, en.actionUndo],
      [zh.actionRedo, en.actionRedo],
      [zh.actionCopyResult, en.actionCopyResult],
      [zh.actionContinueWith, en.actionContinueWith],
      [zh.actionSaveNote, en.actionSaveNote],
      [zh.actionMoveToStart, en.actionMoveToStart],
      [zh.actionMoveToEnd, en.actionMoveToEnd],
      [zh.actionSettings, en.actionSettings],
      [zh.cursorLeftTooltip, en.cursorLeftTooltip],
      [zh.cursorRightTooltip, en.cursorRightTooltip],
      [zh.detailsCopied, en.detailsCopied],
      [zh.detailsCopyFailed, en.detailsCopyFailed],
      [zh.clipboardReadFailed, en.clipboardReadFailed],
      [zh.unitSearchHint, en.unitSearchHint],
      [zh.unitSheetHint, en.unitSheetHint],
      [zh.noMatchingUnits, en.noMatchingUnits],
      [zh.variableSheetTitle, en.variableSheetTitle],
      [zh.noStorableValue, en.noStorableValue],
      [zh.currentValueReading('4'), en.currentValueReading('4')],
      [zh.unassigned, en.unassigned],
      [zh.insertVariable('x'), en.insertVariable('x')],
      [zh.storeCurrentValue, en.storeCurrentValue],
      [zh.clearBinding, en.clearBinding],
      [zh.datasetSheetTitle, en.datasetSheetTitle],
      [zh.datasetEmptyReading('1,2,3,4'), en.datasetEmptyReading('1,2,3,4')],
      [zh.datasetValuesReading(3), en.datasetValuesReading(3)],
      [zh.noDatasetValues, en.noDatasetValues],
      [zh.noAddableValue, en.noAddableValue],
      [zh.addCurrentResultReading('5'), en.addCurrentResultReading('5')],
      [zh.addCurrentResult, en.addCurrentResult],
      [zh.clearDataset, en.clearDataset],
      [zh.removeValueTooltip, en.removeValueTooltip],
      [zh.datasetSheetButton, en.datasetSheetButton],
      [zh.datasetCallEmpty('1,2,3,4'), en.datasetCallEmpty('1,2,3,4')],
      [
        zh.datasetCallValues(3, '5, 12, 13'),
        en.datasetCallValues(3, '5, 12, 13')
      ],
      [zh.statisticsHint, en.statisticsHint],
      [zh.twoVariableRowTitle, en.twoVariableRowTitle],
      [zh.datasetAsTwoRows('pearson(x)'), en.datasetAsTwoRows('pearson(x)')],
      [zh.fitRowTitle, en.fitRowTitle],
      [zh.regressionGraphButton, en.regressionGraphButton],
      [zh.curveRowTitle, en.curveRowTitle],
      [zh.curveLoading, en.curveLoading],
      [zh.curveReading('f', 1, 2), en.curveReading('f', 1, 2)],
      [zh.resultFormatDefaultLabel, en.resultFormatDefaultLabel],
      [zh.resultFormatDefaultNote, en.resultFormatDefaultNote],
      [zh.resultFormatPolarNote, en.resultFormatPolarNote],
      [zh.resultFormatSubtitle, en.resultFormatSubtitle],
      [
        zh.resultFormatGapNotFromEngine('spelling'),
        en.resultFormatGapNotFromEngine('spelling')
      ],
      [
        zh.resultFormatGapTypesettingOff('spelling'),
        en.resultFormatGapTypesettingOff('spelling')
      ],
      [zh.spellingExact, en.spellingExact],
      [zh.spellingFraction, en.spellingFraction],
      [zh.spellingMixed, en.spellingMixed],
      [zh.spellingDms, en.spellingDms],
      [zh.spellingAuto, en.spellingAuto],
      [zh.close, en.close],
    ]) {
      expect(pair[0], isNot(pair[1]), reason: '「${pair[0]}」在英文表里没换');
    }
  });

  test('英文表里没有汉字，也没有空串', () {
    final copy = <String, String>{
      'openNavigationTooltip': en.openNavigationTooltip,
      'actionEditExpression': en.actionEditExpression,
      'actionBackspace': en.actionBackspace,
      'actionUndo': en.actionUndo,
      'actionRedo': en.actionRedo,
      'actionCopyResult': en.actionCopyResult,
      'actionContinueWith': en.actionContinueWith,
      'actionSaveNote': en.actionSaveNote,
      'actionMoveToStart': en.actionMoveToStart,
      'actionMoveToEnd': en.actionMoveToEnd,
      'actionSettings': en.actionSettings,
      'cursorLeftTooltip': en.cursorLeftTooltip,
      'cursorRightTooltip': en.cursorRightTooltip,
      'detailsCopied': en.detailsCopied,
      'detailsCopyFailed': en.detailsCopyFailed,
      'clipboardReadFailed': en.clipboardReadFailed,
      'unitSearchHint': en.unitSearchHint,
      'unitSheetHint': en.unitSheetHint,
      'noMatchingUnits': en.noMatchingUnits,
      'variableSheetTitle': en.variableSheetTitle,
      'noStorableValue': en.noStorableValue,
      'currentValueReading': en.currentValueReading('4'),
      'unassigned': en.unassigned,
      'insertVariable': en.insertVariable('x'),
      'storeCurrentValue': en.storeCurrentValue,
      'clearBinding': en.clearBinding,
      'datasetSheetTitle': en.datasetSheetTitle,
      'datasetEmptyReading': en.datasetEmptyReading('1,2,3,4'),
      'datasetValuesReading': en.datasetValuesReading(3),
      'noDatasetValues': en.noDatasetValues,
      'noAddableValue': en.noAddableValue,
      'addCurrentResultReading': en.addCurrentResultReading('5'),
      'addCurrentResult': en.addCurrentResult,
      'clearDataset': en.clearDataset,
      'removeValueTooltip': en.removeValueTooltip,
      'datasetSheetButton': en.datasetSheetButton,
      'datasetCallEmpty': en.datasetCallEmpty('1,2,3,4'),
      'datasetCallValues': en.datasetCallValues(3, '5, 12, 13'),
      'statisticsHint': en.statisticsHint,
      'twoVariableRowTitle': en.twoVariableRowTitle,
      'datasetAsTwoRows': en.datasetAsTwoRows('pearson(x)'),
      'fitRowTitle': en.fitRowTitle,
      'regressionGraphButton': en.regressionGraphButton,
      'curveRowTitle': en.curveRowTitle,
      'curveLoading': en.curveLoading,
      'curveReading': en.curveReading('f', 1, 2),
      'resultFormatDefaultLabel': en.resultFormatDefaultLabel,
      'resultFormatDefaultNote': en.resultFormatDefaultNote,
      'resultFormatPolarNote': en.resultFormatPolarNote,
      'resultFormatSubtitle': en.resultFormatSubtitle,
      'resultFormatGapNotFromEngine':
          en.resultFormatGapNotFromEngine('spelling'),
      'resultFormatGapTypesettingOff':
          en.resultFormatGapTypesettingOff('spelling'),
      'spellingExact': en.spellingExact,
      'spellingFraction': en.spellingFraction,
      'spellingMixed': en.spellingMixed,
      'spellingDms': en.spellingDms,
      'spellingAuto': en.spellingAuto,
      'close': en.close,
    };
    for (final entry in copy.entries) {
      expect(entry.value.trim(), isNotEmpty, reason: '${entry.key} 是空的');
      expect(_containsCjk(entry.value), isFalse,
          reason: '${entry.key} 英文表里还有汉字：${entry.value}');
    }
    // 中文：中文侧同样不许有空串——空串在屏幕上是"这一格什么都没有"，最难发现的一类漏翻。
    // English: the Chinese side must hold no empty string either: on screen it renders as a blank
    //          cell, the hardest kind of missing copy to notice.
    expect(zh.statisticsHint.trim(), isNotEmpty);
    expect(zh.resultFormatSubtitle.trim(), isNotEmpty);
  });

  test('计算页源码里除了文案表再没有中文字符串字面量', () {
    final directory = Directory('lib/features/calculator/presentation');
    expect(directory.existsSync(), isTrue, reason: '测试的工作目录应当是包的根目录');

    final offenders = <String>[];
    for (final entity in directory.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final name = entity.uri.pathSegments.last;
      // 中文：文案表自己就是汉字住的地方，跳过它。
      // English: the table is where the Chinese is *supposed* to live; skip it.
      if (name == 'calculator_strings.dart') continue;
      // 中文：**用户未提交的那个文件**——本轮一个字都没动，所以它里面那两条（「粘贴计算详情」/
      //       「复制计算详情」）仍在源码里。这是**已知的残留**，不是漏翻；等用户那笔改动落地后，
      //       这一条应当撤掉，那时它会被下面这条扫描逼着走表。
      // English: **the user's uncommitted file** — not one character of it was touched this round, so
      //          its two strings (「粘贴计算详情」/「复制计算详情」) are still in the source. That is a
      //          **known remainder**, not a missed translation; once the user's change lands, this line
      //          should be removed and the scan below will then push them through the table.
      if (name == 'inline_expression_editor.dart') continue;
      final source = _stripComments(entity.readAsStringSync());
      for (final literal in _stringLiterals(source)) {
        if (!_containsCjk(literal)) continue;
        if (_nonUiLiterals.contains(literal)) continue;
        offenders.add('${entity.path}: $literal');
      }
    }

    expect(offenders, isEmpty,
        reason: '这些界面字面量还没走 CalculatorStrings：\n${offenders.join('\n')}');
  });

  testWidgets('没有装作用域时仍然渲染中文（默认态不变）', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: UnitPickerSheet(onInsert: _noopString)),
    ));
    expect(find.text('搜索单位（米、km、mile…）'), findsOneWidget);
    expect(find.text('点一个单位插进表达式；两个单位之间点「to」'), findsOneWidget);
  });

  testWidgets('装上 AppLanguageScope(en) 之后同一个面板渲染英文', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: AppLanguageScope(
        language: AppLanguage.en,
        child: Scaffold(body: UnitPickerSheet(onInsert: _noopString)),
      ),
    ));
    expect(find.text('Search units (m, km, mile…)'), findsOneWidget);
    expect(find.text('Tap a unit to insert it; tap "to" between the two units'),
        findsOneWidget);
    expect(find.text('搜索单位（米、km、mile…）'), findsNothing);
  });

  testWidgets('数据集面板与变量面板同样跟着语言走', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: AppLanguageScope(
        language: AppLanguage.en,
        child: Scaffold(
          body: Column(children: <Widget>[
            DatasetSheet(
              values: <String>[],
              storableValue: null,
              callArguments: '1,2,3,4',
              onAdd: _noNullable,
              onRemove: _noopInt,
              onClear: _noop,
            ),
            VariablePickerSheet(
              readings: <VariableReading>[
                VariableReading(name: 'x', value: null),
              ],
              storableValue: null,
              onInsert: _noopString,
              onAssign: _noopString,
              onClear: _noopString,
            ),
          ]),
        ),
      ),
    ));
    expect(find.text('Statistics dataset'), findsOneWidget);
    expect(find.text('No values yet'), findsOneWidget);
    expect(find.text('Variables'), findsOneWidget);
    expect(find.text('Unassigned'), findsOneWidget);
    expect(find.text('统计数据集'), findsNothing);
    expect(find.text('未赋值'), findsNothing);
  });
}

void _noop() {}

void _noopString(String _) {}

void _noopInt(int _) {}

String? _noNullable() => null;

/// 中文：**不是界面文案**的那一条字面量：调试断言的句子。它只在 debug 构建里、用户按到一颗没接住
///       的键时才会被抛出来，形状与 `app_shell.dart:176` 那句逐字相同（那个文件不在本扫描范围里）。
///       它不翻——把它翻成英文，读日志的人反而要按界面语言去猜。
/// English: **never user-facing**: the debug assertion's sentence. It is thrown only in debug builds,
///          when a key nothing accepts is pressed, and its shape is item-for-item the one at
///          `app_shell.dart:176` (a file this scan does not cover). It is not translated — rendering it
///          in one language would only make whoever reads the log guess at the interface language.
///          **Do not add UI copy to this set**: the reason above is what qualifies an entry, not
///          convenience.
const Set<String> _nonUiLiterals = <String>{
  r'未派发的按键 id / undispatched key id: $key',
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
