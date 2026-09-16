import 'keypad_definition.dart';

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
///       求和键为 `dis:sum`）。
/// English: `☐` in the plan marks "disabled" and is never part of a label. A disabled key
///          keeps HiPER's original text as its label, uses `KeyCategory.disabled`, and gets a
///          `dis:` prefixed id (`dis:matrix`, `dis:sum`, …).
///
/// 动作 id / Action ids:
/// 中文：`CalculatorController` 已有方法直接表达的动作不带前缀（`sin`、`backspace`、
///       `memoryAdd`…）；需要向表达式插入文本的用 `ins:` 前缀；禁用键用 `dis:` 前缀；
///       打开抽屉/工具箱/历史等页面级动作同样不带前缀（`drawer`、`openTools`…）。
/// English: Actions that map straight onto an existing `CalculatorController` method carry
///          no prefix (`sin`, `backspace`, `memoryAdd`, …); text insertions use `ins:`;
///          disabled keys use `dis:`; page-level actions (drawer, tools, history) also carry
///          no prefix (`drawer`, `openTools`, …).
const KeypadDefinition hiperKeypad = KeypadDefinition(<KeypadRow>[
  // 中文：行 1——SHIFT / MENU / 翻页（禁用）/ 退格 / 清空。HiPER 的最上一行没有标签横带。
  // English: Row 1 — SHIFT / MENU / page back and forward (disabled) / backspace / clear.
  //          HiPER's topmost row carries no label band.
  KeypadRow(
    keys: <KeypadKey>[
      KeypadKey(
        base: KeyVariant(label: 'SHIFT', id: 'shift'),
        category: KeyCategory.modifier,
      ),
      KeypadKey(
        base: KeyVariant(label: 'MENU', id: 'drawer'),
        category: KeyCategory.function,
      ),
      KeypadKey(
        base: KeyVariant(label: '◀', id: 'dis:pagePrev', enabled: false),
        category: KeyCategory.disabled,
      ),
      KeypadKey(
        base: KeyVariant(label: '▶', id: 'dis:pageNext', enabled: false),
        category: KeyCategory.disabled,
      ),
      KeypadKey(
        base: KeyVariant(label: '⌫', id: 'backspace'),
        category: KeyCategory.destructive,
      ),
      KeypadKey(
        base: KeyVariant(label: 'AC', id: 'clear'),
        category: KeyCategory.destructive,
      ),
    ],
    labels: <KeypadLabel?>[null, null, null, null, null, null],
  ),

  // 中文：行 2——DRG / x⇔E / 矩阵 / 求和 / 求积 / 相机。
  //       上方标签：DRG（循环 DEG↔RAD 的提示；HiPER 的 `▸` 只是装饰，而标签行里的实体键
  //       只有四个进制胶囊与 hyp 五个，所以这里是不可点的纯提示）、FSE（x⇔E 的 SHIFT 提示）、
  //       MTRX（矩阵键的 SHIFT 提示）、Π（Σ 的 SHIFT 提示）、d/dx（∫dx 的 SHIFT 提示），
  //       相机键上方无标签。
  // English: Row 2 — DRG / x⇔E / matrix / summation / product / camera.
  //          Band above: DRG (a hint about cycling DEG↔RAD; HiPER's `▸` is decoration and the
  //          only real band buttons are the four base pills plus hyp, so this one is a
  //          non-tappable hint), FSE (SHIFT hint of x⇔E), MTRX (hint of the matrix key),
  //          Π (hint of Σ), d/dx (hint of ∫dx); the camera key has no hint.
  KeypadRow(
    keys: <KeypadKey>[
      KeypadKey(
        base: KeyVariant(label: 'DRG', id: 'angleMode'),
        category: KeyCategory.function,
      ),
      KeypadKey(
        base: KeyVariant(label: 'x⇔E', id: 'dis:xchgE', enabled: false),
        category: KeyCategory.disabled,
      ),
      KeypadKey(
        base: KeyVariant(label: 'MTRX', id: 'dis:matrix', enabled: false),
        category: KeyCategory.disabled,
      ),
      KeypadKey(
        base: KeyVariant(label: 'Σ', id: 'dis:sum', enabled: false),
        category: KeyCategory.disabled,
      ),
      KeypadKey(
        base: KeyVariant(label: '∫dx', id: 'dis:integral', enabled: false),
        category: KeyCategory.disabled,
      ),
      KeypadKey(
        base: KeyVariant(label: '📷', id: 'dis:camera', enabled: false),
        category: KeyCategory.disabled,
      ),
    ],
    labels: <KeypadLabel?>[
      ShiftLabel('DRG'),
      ShiftLabel('FSE'),
      ShiftLabel('MTRX'),
      ShiftLabel('Π'),
      ShiftLabel('d/dx'),
      null,
    ],
  ),

  // 中文：行 3——π / sin / cos / tan / i（禁用）/ e。
  //       上方标签：hyp 实体修饰键（可直接点按，是可查证的刻意偏离）、sin⁻¹/cos⁻¹/tan⁻¹
  //       三个 SHIFT 提示，以及 ∠、logₓy 两个禁用键。
  //       sin/cos/tan 同时带 SHIFT 变体（asin/acos/atan）与 hyp 变体（sinh/cosh/tanh）。
  // English: Row 3 — π / sin / cos / tan / i (disabled) / e.
  //          Band above: the tappable `hyp` modifier key (a documented deviation from
  //          HiPER), the sin⁻¹/cos⁻¹/tan⁻¹ SHIFT hints, and the disabled ∠ and logₓy keys.
  //          sin/cos/tan carry both a SHIFT variant (asin/acos/atan) and a hyp variant
  //          (sinh/cosh/tanh).
  KeypadRow(
    keys: <KeypadKey>[
      KeypadKey(
        base: KeyVariant(label: 'π', id: 'ins:pi'),
        category: KeyCategory.function,
      ),
      KeypadKey(
        base: KeyVariant(label: 'sin', id: 'sin'),
        category: KeyCategory.function,
        shift: KeyVariant(label: 'sin⁻¹', id: 'asin'),
        hyp: KeyVariant(label: 'sinh', id: 'sinh'),
      ),
      KeypadKey(
        base: KeyVariant(label: 'cos', id: 'cos'),
        category: KeyCategory.function,
        shift: KeyVariant(label: 'cos⁻¹', id: 'acos'),
        hyp: KeyVariant(label: 'cosh', id: 'cosh'),
      ),
      KeypadKey(
        base: KeyVariant(label: 'tan', id: 'tan'),
        category: KeyCategory.function,
        shift: KeyVariant(label: 'tan⁻¹', id: 'atan'),
        hyp: KeyVariant(label: 'tanh', id: 'tanh'),
      ),
      KeypadKey(
        base: KeyVariant(label: 'i', id: 'dis:i', enabled: false),
        category: KeyCategory.disabled,
      ),
      KeypadKey(
        base: KeyVariant(label: 'e', id: 'ins:e'),
        category: KeyCategory.function,
      ),
    ],
    labels: <KeypadLabel?>[
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: 'hyp', id: 'hyp'),
          category: KeyCategory.modifier,
        ),
      ),
      ShiftLabel('sin⁻¹'),
      ShiftLabel('cos⁻¹'),
      ShiftLabel('tan⁻¹'),
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: '∠', id: 'dis:angle', enabled: false),
          category: KeyCategory.disabled,
        ),
      ),
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: 'logₓy', id: 'dis:logxy', enabled: false),
          category: KeyCategory.disabled,
        ),
      ),
    ],
  ),

  // 中文：行 4——倒数 / 平方 / 开方 / 幂 / 对数 / 自然对数。
  //       上方标签：lim 禁用键，以及 x³、∛x、ˣ√y、10ˣ、eˣ 五个 SHIFT 提示——它们分别落在
  //       下方对应主键的 `shift` 变体上。
  // English: Row 4 — reciprocal / square / square root / power / log / ln.
  //          Band above: the disabled lim key plus the x³, ∛x, ˣ√y, 10ˣ, eˣ SHIFT hints,
  //          each of which also lives on the matching key below as its `shift` variant.
  KeypadRow(
    keys: <KeypadKey>[
      KeypadKey(
        base: KeyVariant(label: 'x⁻¹', id: 'ins:^-1'),
        category: KeyCategory.function,
      ),
      KeypadKey(
        base: KeyVariant(label: 'x²', id: 'ins:^2'),
        category: KeyCategory.function,
        shift: KeyVariant(label: 'x³', id: 'ins:^3'),
      ),
      KeypadKey(
        base: KeyVariant(label: '√x', id: 'sqrt'),
        category: KeyCategory.function,
        shift: KeyVariant(label: '∛x', id: 'cbrt'),
      ),
      KeypadKey(
        base: KeyVariant(label: 'xʸ', id: 'ins:^'),
        category: KeyCategory.function,
        shift: KeyVariant(label: 'ˣ√y', id: 'root'),
      ),
      KeypadKey(
        base: KeyVariant(label: 'log', id: 'log'),
        category: KeyCategory.function,
        shift: KeyVariant(label: '10ˣ', id: 'ins:10^'),
      ),
      KeypadKey(
        base: KeyVariant(label: 'ln', id: 'ln'),
        category: KeyCategory.function,
        shift: KeyVariant(label: 'eˣ', id: 'ins:e^'),
      ),
    ],
    labels: <KeypadLabel?>[
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: 'lim', id: 'dis:lim', enabled: false),
          category: KeyCategory.disabled,
        ),
      ),
      ShiftLabel('x³'),
      ShiftLabel('∛x'),
      ShiftLabel('ˣ√y'),
      ShiftLabel('10ˣ'),
      ShiftLabel('eˣ'),
    ],
  ),

  // 中文：行 5——度分秒 / 分数 / X / XY,M（均禁用）/ 记忆读取 / 记忆写入。
  //       上方标签：STAT、a b/c、Y 三个禁用键，HISTORY（打开抽屉的历史入口），
  //       M+、M−（记忆加减，`x→M` 与现有 `memoryAdd` 语义一致）。
  // English: Row 5 — D°M'S / d/c / X / XY,M (all disabled) / memory recall / memory store.
  //          Band above: the disabled STAT, a b/c and Y keys, HISTORY (the drawer's history
  //          entry), and M+ / M− (memory add and subtract; `x→M` reuses `memoryAdd`).
  KeypadRow(
    keys: <KeypadKey>[
      KeypadKey(
        base: KeyVariant(label: "D°M'S", id: 'dis:dms', enabled: false),
        category: KeyCategory.disabled,
      ),
      KeypadKey(
        base: KeyVariant(label: 'd/c', id: 'dis:dc', enabled: false),
        category: KeyCategory.disabled,
      ),
      KeypadKey(
        base: KeyVariant(label: 'X', id: 'dis:x', enabled: false),
        category: KeyCategory.disabled,
      ),
      KeypadKey(
        base: KeyVariant(label: 'XY,M', id: 'dis:xym', enabled: false),
        category: KeyCategory.disabled,
      ),
      KeypadKey(
        base: KeyVariant(label: 'MR', id: 'memoryRecall'),
        category: KeyCategory.variable,
      ),
      KeypadKey(
        base: KeyVariant(label: 'x→M', id: 'memoryStore'),
        category: KeyCategory.variable,
      ),
    ],
    labels: <KeypadLabel?>[
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: 'STAT', id: 'dis:stat', enabled: false),
          category: KeyCategory.disabled,
        ),
      ),
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: 'a b/c', id: 'dis:abc', enabled: false),
          category: KeyCategory.disabled,
        ),
      ),
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: 'Y', id: 'dis:y', enabled: false),
          category: KeyCategory.disabled,
        ),
      ),
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: 'HISTORY', id: 'openHistory'),
          category: KeyCategory.function,
        ),
      ),
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: 'M+', id: 'memoryAdd'),
          category: KeyCategory.variable,
        ),
      ),
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: 'M−', id: 'memorySubtract'),
          category: KeyCategory.variable,
        ),
      ),
    ],
  ),

  // 中文：行 6——数字 7 8 9 与括号。HiPER 在这里收窄为 5 列，标签横带只有 4 格，末格补 null。
  //       上方标签：CPLX 禁用键，∞（`ins:inf`）、%（`ins:%`）、mod。
  // English: Row 6 — digits 7 8 9 and parentheses. HiPER narrows to five columns here, so the
  //          band above holds only four cells and the last slot is padded with null: the disabled
  //          CPLX key plus ∞ (`ins:inf`), % (`ins:%`) and mod.
  KeypadRow(
    keys: <KeypadKey>[
      KeypadKey(
          base: KeyVariant(label: '7', id: '7'), category: KeyCategory.digit),
      KeypadKey(
          base: KeyVariant(label: '8', id: '8'), category: KeyCategory.digit),
      KeypadKey(
          base: KeyVariant(label: '9', id: '9'), category: KeyCategory.digit),
      KeypadKey(
          base: KeyVariant(label: '(', id: '('),
          category: KeyCategory.operator),
      KeypadKey(
          base: KeyVariant(label: ')', id: ')'),
          category: KeyCategory.operator),
    ],
    labels: <KeypadLabel?>[
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: 'CPLX', id: 'dis:cplx', enabled: false),
          category: KeyCategory.disabled,
        ),
      ),
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: '∞', id: 'ins:inf'),
          category: KeyCategory.function,
        ),
      ),
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: '%', id: 'ins:%'),
          category: KeyCategory.function,
        ),
      ),
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: 'mod', id: 'mod'),
          category: KeyCategory.function,
        ),
      ),
      null,
    ],
  ),

  // 中文：行 7——数字 4 5 6 与乘除。id 用解析器友好的 `*`、`/`，键面仍显示 `×`、`÷`。
  //       上方标签：n!、nCr、nPr 三个函数键，加上 BIN、OCT 两个进制胶囊
  //       （label 不含 HiPER 的 `▸` 装饰）。
  // English: Row 7 — digits 4 5 6 with multiply and divide. The ids stay parser-friendly
  //          (`*`, `/`) while the faces show `×` and `÷`.
  //          Band above: the n!, nCr, nPr function keys plus the BIN and OCT base pills
  //          (labels drop HiPER's decorative `▸`).
  KeypadRow(
    keys: <KeypadKey>[
      KeypadKey(
          base: KeyVariant(label: '4', id: '4'), category: KeyCategory.digit),
      KeypadKey(
          base: KeyVariant(label: '5', id: '5'), category: KeyCategory.digit),
      KeypadKey(
          base: KeyVariant(label: '6', id: '6'), category: KeyCategory.digit),
      KeypadKey(
          base: KeyVariant(label: '×', id: '*'),
          category: KeyCategory.operator),
      KeypadKey(
          base: KeyVariant(label: '÷', id: '/'),
          category: KeyCategory.operator),
    ],
    labels: <KeypadLabel?>[
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: 'n!', id: 'fact'),
          category: KeyCategory.function,
        ),
      ),
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: 'nCr', id: 'nCr'),
          category: KeyCategory.function,
        ),
      ),
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: 'nPr', id: 'nPr'),
          category: KeyCategory.function,
        ),
      ),
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: 'BIN', id: 'baseBin'),
          category: KeyCategory.pill,
        ),
      ),
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: 'OCT', id: 'baseOct'),
          category: KeyCategory.pill,
        ),
      ),
    ],
  ),

  // 中文：行 8——数字 1 2 3 与加减。`−` 的 id 是解析器用的 `-`。
  //       上方标签：CNST（常数分类）、CONV（单位换算）、abs，以及 DEC、HEX 两个进制胶囊。
  // English: Row 8 — digits 1 2 3 with plus and minus; the `−` face carries the parser's
  //          `-` id. Band above: CNST (constant category), CONV (unit conversion), abs, and
  //          the DEC and HEX base pills.
  KeypadRow(
    keys: <KeypadKey>[
      KeypadKey(
          base: KeyVariant(label: '1', id: '1'), category: KeyCategory.digit),
      KeypadKey(
          base: KeyVariant(label: '2', id: '2'), category: KeyCategory.digit),
      KeypadKey(
          base: KeyVariant(label: '3', id: '3'), category: KeyCategory.digit),
      KeypadKey(
          base: KeyVariant(label: '+', id: '+'),
          category: KeyCategory.operator),
      KeypadKey(
          base: KeyVariant(label: '−', id: '-'),
          category: KeyCategory.operator),
    ],
    labels: <KeypadLabel?>[
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: 'CNST', id: 'openConstants'),
          category: KeyCategory.function,
        ),
      ),
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: 'CONV', id: 'openUnits'),
          category: KeyCategory.function,
        ),
      ),
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: 'abs', id: 'abs'),
          category: KeyCategory.function,
        ),
      ),
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: 'DEC', id: 'baseDec'),
          category: KeyCategory.pill,
        ),
      ),
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: 'HEX', id: 'baseHex'),
          category: KeyCategory.pill,
        ),
      ),
    ],
  ),

  // 中文：行 9——0 / 小数点 / 正负号 / EXP / 等号。
  //       `EXP` 走 `ins:exp` 而不是计划书写的 `ins:e`：`ins:e` 已被上一行的 `e` 常量占用，
  //       两者同 id 会撞上「键的 id 全局唯一」。
  //       上方标签：OTHER（打开工具箱）、ran# 与 EXP SI 与 =,＜＞ 三个禁用键、Ans。
  // English: Row 9 — 0 / decimal point / sign toggle / EXP / equals.
  //          `EXP` uses `ins:exp` rather than the plan's `ins:e`, which the `e` constant on
  //          the row above already owns — the collision would break the global id-uniqueness
  //          invariant.
  //          Band above: OTHER (opens the tools), the disabled ran#, EXP SI and =,＜＞ keys,
  //          and Ans.
  KeypadRow(
    keys: <KeypadKey>[
      KeypadKey(
          base: KeyVariant(label: '0', id: '0'), category: KeyCategory.digit),
      KeypadKey(
          base: KeyVariant(label: '.', id: '.'), category: KeyCategory.digit),
      KeypadKey(
        base: KeyVariant(label: '+/−', id: 'negate'),
        category: KeyCategory.function,
      ),
      KeypadKey(
        base: KeyVariant(label: 'EXP', id: 'ins:exp'),
        category: KeyCategory.function,
      ),
      KeypadKey(
        base: KeyVariant(label: '✓', id: 'equals'),
        category: KeyCategory.accent,
      ),
    ],
    labels: <KeypadLabel?>[
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: 'OTHER', id: 'openTools'),
          category: KeyCategory.function,
        ),
      ),
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: 'ran#', id: 'dis:ran', enabled: false),
          category: KeyCategory.disabled,
        ),
      ),
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: 'Ans', id: 'ans'),
          category: KeyCategory.function,
        ),
      ),
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: 'EXP SI', id: 'dis:expsi', enabled: false),
          category: KeyCategory.disabled,
        ),
      ),
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: '=,＜＞', id: 'dis:compare', enabled: false),
          category: KeyCategory.disabled,
        ),
      ),
    ],
  ),
]);
