import 'keypad_definition.dart';

part 'hiper_keypad_band_key_rows.dart';
part 'hiper_keypad_function_rows.dart';
part 'hiper_keypad_angle_matrix_row.dart';
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

/// 中文：**这张表住在五个文件里，有三条缝。** 第一条缝仍在「功能键区」与「数字区」之间：上半个
///       键区（第 1–5 行：修饰键与光标、DRG/MTRX/Σ/∫dx/相机、π 与三角函数、幂与对数、
///       度分秒/分数/变量/记忆）在 `hiper_keypad_function_rows.dart`；数字区（第 6–9 行：从
///       `7 8 9 ( )` 到 `0 . +/− EXP ✓`，也就是上面那段结构说明里被点名的那一块）在
///       `hiper_keypad_number_rows.dart`。这条缝不是按行数切的一刀：两半各自是一块**完整的键盘
///       区域**，缝的位置取自本文件自己的说法（「包括数字区」指的就是这两半），而**行的顺序仍由
///       这里决定**——两半只是内容，拼法与先后只此一处。
///
///       第二条缝在功能键区**内部**，落点是「横带里那一格是不是一颗按钮」（规格书第 17 行画的
///       就是这条线）：横带只有不可点提示的行（1、4）留在 `hiper_keypad_function_rows.dart`，
///       横带里放了 `InlineKey` 的两行（3、5）搬到 `hiper_keypad_band_key_rows.dart`。两处各自的
///       文件头都写了这条缝为什么对；**那个文件里的每一条 `InlineKey` 都得指得出出处**，因为
///       「提示被做成按钮」正是最近五轮一直在撤的形状。
///
///       第三条缝与第一条同源（**区域之间**）：行 2（`DRG`/`x⇔E`/`MTRX`/`Σ`/`Π`/📷）整行搬到
///       `hiper_keypad_angle_matrix_row.dart`。它本来和另两行横带只有提示的行住在一起，而最近两轮
///       的全部改动（`▸DRG`、`MTRX` 点亮，`FSE` 退回提示，📷 重新量过布局版本）都落在那六格上，
///       那一行的档案因此是另外两行合计的近两倍。理由在那里的文件头。
///
///       **拆分的动因是那条 800 行上限**：加 `d/dx`（`∫dx` 的 SHIFT 变体）时，还是单文件的它到了
///       801 行（实测）；本轮加 `DRG`/`MTRX` 两处挂载时，功能键区文件是 787 行、只剩 13 行余量。
///       两次拆的都是**数据**，缝落在区域之间或横带的性质之间，拆完每一半都有余量。
/// English: **The table lives in five files, with three seams.** The first seam still runs between the
///          function half and the number area: the upper half (rows 1–5: modifiers and cursor,
///          DRG/MTRX/Σ/∫dx/camera, π and trigonometry, powers and logarithms,
///          D°M'S/fraction/variables/memory) is in `hiper_keypad_function_rows.dart`; the number
///          area (rows 6–9, from `7 8 9 ( )` down to `0 . +/− EXP ✓` — the block the structure note
///          above names) is in `hiper_keypad_number_rows.dart`. The seam is not a cut made to hit a
///          line count: each half is one whole region of the keypad, the seam is where this file's
///          own structure note already draws it, and **the row order is still decided here** — the
///          halves are content, and their order and assembly live in this one place.
///
///          The second seam runs **inside** the function half, and its cut is "whether a band cell
///          is a button" (the line line 17 of the spec draws): the rows whose band holds nothing but
///          hints (1, 4) stay in `hiper_keypad_function_rows.dart`, and the two rows whose band
///          carries `InlineKey`s (3, 5) move to `hiper_keypad_band_key_rows.dart`. Each file head
///          says why that seam is right; **every `InlineKey` over there has to point at its
///          source**, because "a hint turned into a button" is the shape the last five rounds have
///          been taking back out.
///
///          The third seam is the first one's kin (**between regions**): row 2
///          (`DRG`/`x⇔E`/`MTRX`/`Σ`/`Π`/📷) moved whole to `hiper_keypad_angle_matrix_row.dart`. It
///          used to share a file with the other two hint-only-band rows, while the last two rounds'
///          entire work (`▸DRG` and `MTRX` lit, `FSE` demoted to a hint, the camera's layout version
///          re-measured) landed on its six cells — its dossier alone is nearly twice the other two
///          rows put together. The reasons are at that file's head.
///
///          **The reason for both splits is the 800-line cap**: adding `d/dx` (the SHIFT variant of
///          `∫dx`) took the single-file version to 801 lines (measured), and this round's two mounts
///          (`DRG`/`MTRX`) found the function-rows file at 787 lines with 13 to spare. Both times
///          what got split is the **data**, along a region boundary or along the nature of the band,
///          and each half now has room.
const KeypadDefinition hiperKeypad = KeypadDefinition(<KeypadRow>[
  ..._functionRows,
  ..._numberRows,
]);
