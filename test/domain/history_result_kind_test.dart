import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/data/models/history_item.dart';
import 'package:nekocalc/features/tools/presentation/tool_result_label_strings.dart';
import 'package:nekocalc/l10n/app_language.dart';

/// 中文：**`result_kind` 这一列的判据本身。** 这一列说明历史 `result` 里那句载荷"该怎么读"，
///       四个消费者共用同一个分类器：迁移回填、备份导入、写库、显示。所以这里量的是**那一个判据**，
///       而不是某一个消费者。
/// English: **the verdict behind the `result_kind` column.** That column says how to read the payload
///          in a history `result`, and four consumers share one classifier: the migration backfill,
///          backup import, the write path, and the display. So this measures **that one verdict**
///          rather than any single consumer.
void main() {
  group('分类器：唯一一处判据', () {
    test('没有 tool_id → number（计算器那条中性数值）', () {
      expect(
        classifyHistoryResult(toolId: null, result: '42'),
        HistoryResultKind.number,
      );
      expect(
        classifyHistoryResult(toolId: '   ', result: '0.893997'),
        HistoryResultKind.number,
      );
    });

    test('有 tool_id 且载荷带 `标签: 值` → tool', () {
      expect(
        classifyHistoryResult(toolId: 'ohms_law', result: '电压 V: 20V'),
        HistoryResultKind.tool,
      );
    });

    test('有 tool_id 但载荷不是 `标签: 值` → opaque', () {
      expect(
        classifyHistoryResult(toolId: 'json_format', result: '纯文本结果'),
        HistoryResultKind.opaque,
      );
      expect(
        classifyHistoryResult(toolId: 'data_fit', result: 'y = 2x\nR² = 0.99'),
        HistoryResultKind.opaque,
      );
    });

    test('自由文本里恰好含 `: ` 时会被判成 tool——但这是**良性的**', () {
      // 中文：分类器是形状判据，不认得"这是 JSON"。一段 JSON 里 `"a": 1` 正好含 `: `，于是被判成
      //       `tool`。**这不会画错**：显示侧按第一个 `: ` 切开后拿 `{\n  "a"` 去查标签表，查不到
      //       原样返回，拼回来与原文逐字节相同（见 `history_result_display_test.dart`）。
      //       写路径对文本工具与数据拟合**显式写 opaque**，所以新行根本不会走到这里；这条只管
      //       迁移回填老行时的兜底，而兜底的结果是"原样显示"。
      // English: the classifier is a shape verdict and does not know "this is JSON". A JSON payload's
      //          `"a": 1` does contain `: `, so it is judged `tool`. **That does not draw wrong**: the
      //          display splits on the first `: `, looks up `{\n  "a"`, misses, returns it, and
      //          reassembles byte-for-byte the original (see `history_result_display_test.dart`). The
      //          write path writes `opaque` **explicitly** for text tools and data fits, so a new row
      //          never lands here; this only covers the migration backfill of old rows, and the
      //          backfill's result is "shown as it stands".
      expect(
        classifyHistoryResult(toolId: 'json_format', result: '{\n  "a": 1\n}'),
        HistoryResultKind.tool,
      );
    });

    test('判据用的是 `: `（冒号加空格），不是裸冒号', () {
      // 中文：`: ` 与写入侧 `'$label: ${result.valueWithUnit}'` 逐字节对齐；裸 `:` 不算。
      // English: `: ` is byte-aligned with the writing side's `'$label: ${result.valueWithUnit}'`;
      //          a bare `:` does not count.
      expect(
        classifyHistoryResult(toolId: 'x', result: '比例 1:2'),
        HistoryResultKind.opaque,
      );
      expect(
        classifyHistoryResult(toolId: 'x', result: '比例: 2'),
        HistoryResultKind.tool,
      );
    });

    test('存储往返：三个 kind 都是稳定字符串', () {
      for (final kind in HistoryResultKind.values) {
        expect(historyResultKindFromStorage(historyResultKindToStorage(kind)),
            kind);
      }
    });

    test('认不出的存储值一律回落 opaque（原样显示是安全兜底）', () {
      expect(historyResultKindFromStorage(''), HistoryResultKind.opaque);
      expect(historyResultKindFromStorage('未来的形状'), HistoryResultKind.opaque);
      expect(historyResultKindFromStorage(null), HistoryResultKind.opaque);
    });
  });

  group('显示侧按第一个 `: ` 切开无歧义', () {
    test('英文标签表每一键里没有一条含 `: `', () {
      // 中文：**这是显示侧那个 `indexOf(': ')` 成立的前提。** 只要有一条键带 `: `，切开就会
      //       落在键里面，标签与值都会错位——这条断言就是那道前提本身。
      // English: **this is the premise that makes the display's `indexOf(': ')` valid.** A single key
      //          containing `: ` would split inside the key and misplace both label and value; this
      //          assertion *is* that premise.
      final offenders = ToolResultLabelStrings.toolResultLabelsEn.labels.keys
          .where((key) => key.contains(': '))
          .toList();
      expect(offenders, isEmpty,
          reason: '这些标签键含 `: `，按第一个 `: ` 切开会有歧义：\n${offenders.join('\n')}');
      expect(ToolResultLabelStrings.toolResultLabelsEn.labels.length, 712,
          reason: '英文结果标签表应当是 712 条（上一轮 713：`proportion` 并进 `scale_ratio`，'
              '它独有的 `x差值` 随工具删除）');
    });

    test('已知标签在英文下翻译、在中文下原样', () {
      expect(ToolResultLabelStrings.forLanguage(AppLanguage.en).label('电压 V'),
          'Voltage V');
      expect(ToolResultLabelStrings.forLanguage(AppLanguage.en).label('功率'),
          'Power');
      // 中文：中文表是空的（键就是中文），查不到原样返回——默认语言下显示逐字节不变。
      // English: the Chinese table is empty (the key *is* the Chinese), and a miss returns its
      //          argument — so under the default language the display does not move by a byte.
      expect(ToolResultLabelStrings.forLanguage(AppLanguage.zh).label('电压 V'), '电压 V');
    });
  });
}
