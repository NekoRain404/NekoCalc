import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/data/models/history_item.dart';
import 'package:nekocalc/features/notes/presentation/notes_page.dart';
import 'package:nekocalc/features/tools/presentation/tool_result_label_strings.dart';
import 'package:nekocalc/l10n/app_language.dart';

/// 中文：**显示侧那一行怎么画。** 生产里这个函数拿的是外壳递进来的
///       `ToolResultLabelStrings.of(context).label`；这里直接拿 `forLanguage(...)`，量的是同一个
///       函数。三件事：中性数值逐字节不动、工具标签换成当前语言、`opaque` 原样兜底。
/// English: **how the display draws one row.** In production this function receives the shell-supplied
///          `ToolResultLabelStrings.of(context).label`; here it takes `forLanguage(...)` directly,
///          measuring the same function. Three things: a neutral number does not move by a byte, a
///          tool label becomes the active language, and `opaque` falls back to what it was.
void main() {
  final en = ToolResultLabelStrings.forLanguage(AppLanguage.en).label;
  final zh = ToolResultLabelStrings.forLanguage(AppLanguage.zh).label;

  HistoryItem item(String result, HistoryResultKind kind, {String? toolId}) {
    return HistoryItem(
      id: 1,
      expression: 'expr',
      result: result,
      resultKind: kind,
      toolId: toolId,
      createdAt: DateTime(2026, 9, 21),
    );
  }

  group('number：中性数值逐字节不动', () {
    test('英文界面下数字一个字节都不动', () {
      expect(historyResultText(item('42', HistoryResultKind.number), en), '42');
      expect(historyResultText(item('0.893997', HistoryResultKind.number), en),
          '0.893997');
      expect(historyResultText(item('1.234e+10', HistoryResultKind.number), en),
          '1.234e+10');
    });
  });

  group('tool：标签换成当前语言，值原样', () {
    test('中文界面下工具行逐字节不动（中文表是空的）', () {
      expect(
        historyResultText(
            item('电压 V: 20V', HistoryResultKind.tool, toolId: 'ohms_law'), zh),
        '电压 V: 20V',
      );
    });

    test('英文界面下标签翻译、值一个字节不动', () {
      expect(
        historyResultText(
            item('电压 V: 20V', HistoryResultKind.tool, toolId: 'ohms_law'), en),
        'Voltage V: 20V',
      );
      expect(
        historyResultText(
            item('功率: 12.5 W', HistoryResultKind.tool, toolId: 'x'), en),
        'Power: 12.5 W',
      );
    });

    test('值本身含 `: ` 也只切第一个——标签后面的整段都是值', () {
      // 中文：写入侧 `'$label: ${result.valueWithUnit}'` 里值可能是 `1:2` 这种比例。
      // English: on the writing side `'$label: ${result.valueWithUnit}'` the value may be a ratio
      //          such as `1:2`.
      expect(
        historyResultText(
            item('比例: 1:2', HistoryResultKind.tool, toolId: 'x'), en),
        'Ratio: 1:2',
      );
    });

    test('查不到的标签原样返回（工具表里没有那一条）', () {
      expect(
        historyResultText(
            item('自定义量: 3', HistoryResultKind.tool, toolId: 'x'), en),
        '自定义量: 3',
      );
    });

    test('形状不符（没有 `: `）时原样兜底，不抛错', () {
      // 中文：老备份可能把一条形状不符的行显式标成 `tool`，这里是那条路的兜底。
      // English: an old backup may have explicitly marked a shape-mismatched row as `tool`; this is
      //          that path's fallback.
      expect(
        historyResultText(item('纯文本', HistoryResultKind.tool, toolId: 'x'), en),
        '纯文本',
      );
    });
  });

  group('opaque：原样显示（重渲染不了）', () {
    test('英文界面下自由文本一个字节不动', () {
      expect(
        historyResultText(
            item('{\n  "a": 1\n}', HistoryResultKind.opaque, toolId: 'json_format'),
            en),
        '{\n  "a": 1\n}',
      );
      // 中文：即使形状看起来像 `标签: 值`，`opaque` 也绝不切——那是显式写下的判断。
      // English: even when the shape looks like `label: value`, `opaque` is never split — that is an
      //          explicitly written verdict.
      expect(
        historyResultText(
            item('拟合: y=2x', HistoryResultKind.opaque, toolId: 'data_fit'), en),
        '拟合: y=2x',
      );
    });

    test('JSON 形状被误判成 tool 时也逐字节相同（切开→查不到→拼回）', () {
      // 中文：**这是"误判无害"的证据本身。** 分类器按形状把含 `: ` 的自由文本判成 `tool`，
      //       显示侧切出来查标签表查不到、原样拼回，输出与输入逐字节相同。
      // English: **this is the evidence that the misclassification is harmless.** The classifier calls
      //          free text containing `: ` a `tool` by shape; the display splits, misses the label
      //          table, reassembles, and the output is byte-identical to the input.
      expect(
        historyResultText(
            item('{\n  "a": 1\n}', HistoryResultKind.tool, toolId: 'json_format'),
            en),
        '{\n  "a": 1\n}',
      );
    });
  });

  group('switch 穷尽三种 kind', () {
    test('每一个 kind 都有确定的画法', () {
      for (final kind in HistoryResultKind.values) {
        expect(
          () => historyResultText(item('x', kind), en),
          returnsNormally,
          reason: '$kind 没有画法',
        );
      }
    });
  });
}
