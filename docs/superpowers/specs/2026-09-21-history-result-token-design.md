# 计算历史改存语言无关令牌（做法 A）— 设计

**日期** 2026-09-21 ｜ **分支** `main` ｜ **状态** 已完成（`flutter analyze` 无问题，`flutter test` 1626 通过）

## 目的

`calculation_history.result` 今天存**渲染后的文本**：计算器存 `MathResult.displayText`，工具存
`标签: 值`。中文模式下建的历史切到英文仍是中文。本设计让历史**按当前语言重新渲染**，同时
**中性载荷逐字节不动**。

## 关键事实（已实测）

- 计算器**入库的都是中性数值**：`_calculateResult` 在 `!value.isFinite` 时先 `throw`，
  `formatNumber` 的 `'无效'` 分支到不了；错误与占位句**根本不入库**
  （`calculator_controller_evaluation.dart:125-141` 的 catch 分支直接 return，不保存）。
- 工具行的载荷是 `标签: 值`（`tool_detail_sentences.dart:311-312`），标签就是 `result.label`。
- 工具子树**已有** 715 条英文标签表 `ToolResultLabelStrings`，**键就是中文标签**
  （`tool_result_label_strings.dart`），查不到原样返回。
- **715 条键里没有一条含 `': '`**（实测），所以 `label: value` 按第一个 `': '` 切开无歧义。
- 工具行由 `tool_id` 标识；文本工具与数据拟合也带 `tool_id`，但载荷不是 `label: value`。
- `HistoryItem.fromMap` 硬转 `result` 为 `String`；`_normalizeHistoryRow` 与备份校验器都要求
  `result` 非空。

## 做法

**`result` 列里的载荷不动，新增一列 `result_kind` 说明"这一行怎么读"。**

### 1. Schema 与迁移

- `app_database.dart` 版本 **6 → 7**。
- 新库 `CREATE TABLE` 带 `result_kind TEXT NOT NULL DEFAULT ''`。
- 旧库 `ALTER TABLE ... ADD COLUMN result_kind TEXT NOT NULL DEFAULT ''`，写成
  `_addHistoryResultKindColumn`，照 `_addNoteUpdatedAtColumn` 的 `PRAGMA table_info` 幂等守卫。
- 迁移回填：逐行按分类器打标。

### 2. 分类器（唯一真相）

纯函数 `classifyHistoryResult({String? toolId, required String result}) → HistoryResultKind`：

| 条件 | kind |
|---|---|
| `toolId` 为空 | `number`（计算器数值，已中性） |
| `toolId` 非空且载荷带 `': '` | `tool`（`label: value`） |
| 其余 | `opaque` |

四个消费者共用：迁移回填、备份导入（老备份缺列时）、`addHistory` 写库、测试。
`saveCalculation` / `saveToolResult` 各加一个**可选** `HistoryResultKind? resultKind`（默认派生）；
文本工具与数据拟合两个调用点显式传 `opaque`（载荷不是 `label: value`）。

**形状判据是良性的**：一段自由文本若恰好含 `': '`（JSON 的 `"a": 1`）会被判成 `tool`，但显示侧
切开后查标签表查不到、原样拼回，输出与输入**逐字节相同**。所以分类器只需"足够好"，不追求精确。

### 3. 显示

表现层按 `item.resultKind`（顶层纯函数 `historyResultText(item, toolResultLabel)`，
`lib/features/notes/presentation/notes_page.dart`）：

- `number` → 原样（已中性）
- `tool` → 第一个 `': '` 切开，前缀过查表函数，值原样拼回
- `opaque` → 原样兜底

唯一显示点：`notes_page_sections.dart`。

**查表函数由外壳递进来**（`NotesPage.toolResultLabel`，`app_shell.dart` 传
`ToolResultLabelStrings.of(context).label`）：笔记页与工具页互不 import（仓库既有边界：`features/`
之间不互相依赖，`shared/presentation/app_shell.dart` 是唯一同时认得两边的地方）。

### 4. 备份

- 导出：`exportSnapshot` 全列查询，自动带上。
- 导入：`backup_snapshot_validator` 加**可选**文本校验；`_normalizeHistoryRow` 列缺失时用分类器补
  ——**老备份照收**。

### 5. 测试

- **真实 SQLite 的 v6→v7 迁移测试**（`test/data/app_database_v7_test.dart`，仓库里唯一跑真库的地方）：
  建 v6 库、塞两种行、升 v7、断言回填；另加写路径派生与导出→导入往返。经 `sqflite_common_ffi`
  走系统 `libsqlite3`（`pubspec.yaml` 的 `hooks.user_defines.sqlite3.source: system`），缺原生库
  时自行跳过。
- 分类器单测（`test/domain/history_result_kind_test.dart`），含"715 条键无一含 `': '`"这条前提。
- 显示纯函数单测（`test/features/history_result_display_test.dart`）+ 笔记页注入被接上的 widget 测试。
- 老备份兼容单测（`test/core/backup_history_result_kind_test.dart`）。
- `HistoryItem` 加 `required resultKind`，更新 23 处测试夹具（**不设默认值**，默认值会静默错分类）。

### 6. 一处开发依赖

`sqflite_common_ffi`（dev-only）自己的 `environment.sdk` 是 `^3.12.0`，高于本仓 `>=3.4.0`。
**故意不改那个下限**（它还决定 `dart format` 的短风格）。实际工具链是 Flutter 3.44 / Dart 3.12，
所以解析得动；这条依赖不进 App 构建图（`flutter pub deps` 已核）。

## 界外

- 复制/报告/笔记正文那份历史结果**保持原样**（沿用"复制出去的是数据"的既有立场）。
- `calculator_result` 设置三格、笔记正文本身：不动。
- **已知限制**：若引擎对带单位结果打印本地化单位名，那些行语言锁死，走 `opaque` 兜底
  （本机是假引擎，真机才能验）。
