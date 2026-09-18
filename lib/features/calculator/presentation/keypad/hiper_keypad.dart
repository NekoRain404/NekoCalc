import 'keypad_definition.dart';

part 'hiper_keypad_function_rows.dart';
part 'hiper_keypad_number_rows.dart';

/// 中文：HiPER Calc Pro 的完整键位表——键盘的内容全在这里，渲染层只读不改。
/// English: The complete HiPER Calc Pro key table — the keypad's entire content lives
///          here; the rendering layer only reads it.
///
/// 行结构 / Row structure:
/// 中文：共 9 行，每行 = 一条主键条 + 打印在主键**上方**的标签横带（`labels[i]` 就是 `keys[i]`
///       上方那一格）。HiPER 屏幕上的 8 条矮横带全部是「它下面就那行主键」的标签带，包括数字区：
///       `n! nCr nPr →BIN →OCT` 在 `7 8 9 ( )` 之下、`4 5 6 × ÷` 之上，因此属于 `4 5 6 × ÷`。
///       第一行（SHIFT/MENU/◀/▶/⌫/AC）没有标签带，`labels` 全为 null；某格没有标签时同样填 null。
///       标签横带比主键条短的（如第 6 行 4 格对 5 键）在尾部补 null。
/// English: Nine rows, each one main key strip plus the label band printed **above** its keys
///          (`labels[i]` sits above `keys[i]`). All 8 short bands on HiPER's screen label the key
///          row *below* them, the number area included: `n! nCr nPr →BIN →OCT` sits under
///          `7 8 9 ( )` but above `4 5 6 × ÷`, so it belongs to `4 5 6 × ÷`. The first row
///          (SHIFT/MENU/◀/▶/⌫/AC) has no band at all — every slot is null, as is any slot whose
///          column has no band cell. Bands shorter than their key strip (row 6: four cells for
///          five keys) are padded with null.
///
/// 标签格里为什么不是主键 / Why band cells are not keys:
/// 中文：`sin⁻¹`、`x³`、`∛x`、`ˣ√y`、`10ˣ`、`eˣ` 这些格子是**下方主键的 SHIFT 变体**，
///       `asin`/`ins:^3`/`cbrt`/`root`/`ins:10^`/`ins:e^` 这些 id 已经被下方主键的 `shift` 占用，
///       若再当成 `keys` 里的键就会撞上「键的 id 全局唯一」。所以标签横带里只放 `ShiftLabel`
///       （纯提示）或 `InlineKey`（真按钮：`hyp`、四个进制胶囊，以及 HISTORY/OTHER/CNST/CONV/
///       M±/n!/nCr/nPr/abs/∞/%/mod/Ans 这些独立键位）。
/// English: Cells such as `sin⁻¹`, `x³`, `∛x`, `ˣ√y`, `10ˣ` and `eˣ` are the **SHIFT variants of
///          the key below them** — the ids `asin`/`ins:^3`/`cbrt`/`root`/`ins:10^`/`ins:e^` already
///          belong to that key's `shift` field, so listing them in `keys` would break the global
///          id-uniqueness invariant. Bands therefore hold only `ShiftLabel`s (plain hints) or
///          `InlineKey`s (real buttons: `hyp`, the four base pills, and the standalone band keys
///          HISTORY/OTHER/CNST/CONV/M±/n!/nCr/nPr/abs/∞/%/mod/Ans).
///
/// 禁用键 / Disabled keys:
/// 中文：计划书里的 `☐` 只是「禁用」记号，不属于 label。禁用键的 label 是 HiPER 原文，
///       分类为 `KeyCategory.disabled`，id 用 `dis:` 前缀加名字（矩阵键为 `dis:matrix`，
///       相机键为 `dis:camera`）。
/// English: `☐` in the plan marks "disabled" and is never part of a label. A disabled key
///          keeps HiPER's original text as its label, uses `KeyCategory.disabled`, and gets a
///          `dis:` prefixed id (`dis:matrix`, `dis:camera`, …).
///
/// 动作 id / Action ids:
/// 中文：`CalculatorController` 已有方法直接表达的动作不带前缀（`sin`、`backspace`、
///       `memoryAdd`…）；需要向表达式插入文本的用 `ins:` 前缀；禁用键用 `dis:` 前缀；
///       打开抽屉/工具箱/历史等页面级动作同样不带前缀（`drawer`、`openTools`…）。
/// English: Actions that map straight onto an existing `CalculatorController` method carry
///          no prefix (`sin`, `backspace`, `memoryAdd`, …); text insertions use `ins:`;
///          disabled keys use `dis:`; page-level actions (drawer, tools, history) also carry
///          no prefix (`drawer`, `openTools`, …).

/// 中文：**这张表住在三个文件里，缝在「功能键区」与「数字区」之间。** 上半个键区（第 1–5 行：
///       修饰键与光标、DRG/MTRX/Σ/∫dx/相机、π 与三角函数、幂与对数、度分秒/分数/变量/记忆）在
///       `hiper_keypad_function_rows.dart`；数字区（第 6–9 行：从 `7 8 9 ( )` 到 `0 . +/− EXP ✓`，
///       也就是上面那段结构说明里被点名的那一块）在 `hiper_keypad_number_rows.dart`。
///       这条缝不是按行数切的一刀：两半各自是一块**完整的键盘区域**，缝的位置取自本文件自己的
///       说法（「包括数字区」指的就是这两半），而**行的顺序仍由这里决定**——两半只是内容，
///       拼法与先后只此一处。
///
///       **拆分的动因是那条 800 行上限**：单文件的它是 799 行，离上限只差一行——下一颗键哪怕只多
///       一行 `shift:` 也会越过去。拆的是**数据**，缝落在区域之间，两半各自都有余量，下一颗键
///       不必再拆一次。
/// English: **The table lives in three files, and the seam runs between the function half and the
///          number area.** The upper half (rows 1–5: modifiers and cursor, DRG/MTRX/Σ/∫dx/camera,
///          π and trigonometry, powers and logarithms, D°M'S/fraction/variables/memory) is in
///          `hiper_keypad_function_rows.dart`; the number area (rows 6–9, from `7 8 9 ( )` down to
///          `0 . +/− EXP ✓` — the block the structure note above names) is in
///          `hiper_keypad_number_rows.dart`. The seam is not a cut made to hit a line count: each
///          half is one whole region of the keypad, the seam is where this file's own structure
///          note already draws it, and **the row order is still decided here** — the two halves are
///          content, and their order and assembly live in this one place.
///
///          **The reason for the split is the 800-line cap**: as one file it was 799 lines, one line
///          short of the limit — the next key would cross it even if all it added was a single
///          `shift:` line. What got split is the **data**, along a region boundary, and each half
///          now has room so the next key does not force another split.
const KeypadDefinition hiperKeypad = KeypadDefinition(<KeypadRow>[
  ..._functionRows,
  ..._numberRows,
]);
