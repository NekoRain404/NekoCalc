/// 中文：**历史 `result` 列里那句载荷该怎么读。** 这一列今天存两种东西：计算器那条中性数值
///       （`42`、`0.893997`），以及工具那条 `标签: 值`。`result_kind` 说明"这一行属于哪一种"，
///       显示侧据此决定要不要把标签换成当前语言。
///
///       **载荷本身不动，只加一列说明怎么读**——所以中性行（数值）逐字节不变，工具行的
///       `标签: 值` 也照旧，只是标签在英文界面下过 [ToolResultLabelStrings] 重渲染。
///
///       **为什么不用 JSON 令牌。** 令牌要改所有写路径、备份格式与 [HistoryItem]，迁移还得把旧
///       文本解析成 JSON；而"这一列不再是人能读的"是净损失。分类只有三种，一列足够。
/// English: **how to read the payload in the history `result` column.** That column holds two
///          things today: the calculator's neutral number (`42`, `0.893997`) and the tools'
///          `label: value`. `result_kind` says which one this row is, so the display side can decide
///          whether the label needs re-rendering into the active language.
///
///          **The payload itself does not move; only a column saying how to read it is added** — so
///          a neutral row (a number) is byte-identical and a tool row's `label: value` is unchanged,
///          with only the label re-rendered through [ToolResultLabelStrings] in the English
///          interface.
///
///          **Why not a JSON token.** A token would change every write path, the backup format and
///          [HistoryItem], and the migration would have to parse the old text into JSON; and "this
///          column is no longer human-readable" is a net loss. Three kinds fit in one column.
enum HistoryResultKind {
  /// 中文：计算器数值，**已经是语言中性的**（`formatNumber` 的输出；错误与占位句根本不入库）。
  /// English: A calculator number, **already language-neutral** (the output of `formatNumber`;
  ///          error and placeholder sentences never reach history at all).
  number,

  /// 中文：工具行，载荷是 `标签: 值`。标签是 [ToolResultLabelStrings] 的键（键就是中文标签）。
  /// English: A tool row whose payload is `label: value`. The label is a key of
  ///          [ToolResultLabelStrings] (the key *is* the Chinese label).
  tool,

  /// 中文：**认得出来但重渲染不了**——文本工具的自由文本、数据拟合的本地化小结。原样显示。
  /// English: **recognisable but not re-renderable** — a text tool's free text, a data fit's
  ///          localised summary. Shown as it stands.
  opaque,
}

/// 中文：把存进库的那一格读回枚举。**认不出的一律当 [HistoryResultKind.opaque]**——原样显示是
///       安全的兜底。
/// English: Reads the stored cell back into the enum. **Anything unrecognised becomes
///          [HistoryResultKind.opaque]** — showing it as it stands is the safe fallback.
HistoryResultKind historyResultKindFromStorage(String? raw) {
  for (final kind in HistoryResultKind.values) {
    if (kind.name == raw) return kind;
  }
  return HistoryResultKind.opaque;
}

/// 中文：写进库的那一格。**用 `enum.name`**，这样加一种 kind 时这里的 `switch` 会编译不过。
/// English: The cell written to the database. **`enum.name`** is used, so adding a kind breaks the
///          `switch` here.
String historyResultKindToStorage(HistoryResultKind kind) {
  return switch (kind) {
    HistoryResultKind.number => 'number',
    HistoryResultKind.tool => 'tool',
    HistoryResultKind.opaque => 'opaque',
  };
}

/// 中文：**唯一一处分类判据。** 四个消费者共用它：迁移回填、备份导入（老备份缺列时）、
///       [AppDatabase.addHistory] 写库、以及测试。
///
///       - 没有 `tool_id` → [HistoryResultKind.number]（计算器那条路）。
///       - 有 `tool_id` 且载荷带 `标签: 值` → [HistoryResultKind.tool]。
///       - 其余 → [HistoryResultKind.opaque]。
///
///       **"带 `标签: 值`"判据用 `': '`（冒号加空格）**，与写入侧 `'$label: ${result.valueWithUnit}'`
///       逐字节对齐；工具标签表 715 条键里没有一条含 `': '`（实测），所以显示侧按第一个
///       `': '` 切开无歧义。文本工具与数据拟合的载荷**不保证**是这个形状，那两个调用点显式写
///       [HistoryResultKind.opaque]，不靠这条判据去猜。
/// English: **the one classification verdict.** Four consumers share it: the migration backfill,
///          backup import (when an old backup lacks the column), [AppDatabase.addHistory]'s write,
///          and the tests.
///
///          - No `tool_id` → [HistoryResultKind.number] (the calculator path).
///          - A `tool_id` with a `label: value` payload → [HistoryResultKind.tool].
///          - Anything else → [HistoryResultKind.opaque].
///
///          **The `label: value` test uses `': '` (colon plus space)**, byte-aligned with the
///          writing side's `'$label: ${result.valueWithUnit}'`; none of the tool label table's 715
///          keys contains `': '` (measured), so splitting on the first `': '` on the display side is
///          unambiguous. A text tool's or data fit's payload is **not guaranteed** to have that
///          shape, so those two call sites write [HistoryResultKind.opaque] explicitly rather than
///          asking this verdict to guess.
HistoryResultKind classifyHistoryResult({
  String? toolId,
  required String result,
}) {
  final normalizedToolId = toolId?.trim();
  if (normalizedToolId == null || normalizedToolId.isEmpty) {
    return HistoryResultKind.number;
  }
  return result.contains(': ') ? HistoryResultKind.tool : HistoryResultKind.opaque;
}

class HistoryItem {
  const HistoryItem({
    required this.id,
    required this.expression,
    required this.result,
    required this.resultKind,
    required this.createdAt,
    this.toolId,
  });

  final int id;
  final String expression;
  final String result;

  /// 中文：`result` 里那句载荷怎么读。理由见 [HistoryResultKind]。
  /// English: how to read the payload in [result]. Reasons on [HistoryResultKind].
  final HistoryResultKind resultKind;
  final String? toolId;
  final DateTime createdAt;

  factory HistoryItem.fromMap(Map<String, Object?> map) {
    final result = map['result'] as String;
    final toolId = map['tool_id'] as String?;
    // 中文：**列在就用列，列不在（或还是空的）就现场分类。** 迁移会把旧行回填，备份导入会补上，
    //       但读路径不假定一定有人补过——空的 `result_kind` 一律当成"还没分类"，用同一个分类器
    //       现算。`opaque` 是**显式写下的**值，不会被这条兜底覆盖。
    // English: **use the column when it is there, classify on the spot when it is absent (or still
    //          empty).** The migration backfills old rows and backup import fills them in, but the
    //          read path does not assume anyone did: an empty `result_kind` always means "not
    //          classified yet" and goes through the same classifier. `opaque` is a value written
    //          **explicitly** and is not overwritten by this fallback.
    final rawKind = map['result_kind'];
    final resultKind = rawKind is String && rawKind.isNotEmpty
        ? historyResultKindFromStorage(rawKind)
        : classifyHistoryResult(toolId: toolId, result: result);
    return HistoryItem(
      id: map['id'] as int,
      expression: map['expression'] as String,
      result: result,
      resultKind: resultKind,
      toolId: toolId,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}
