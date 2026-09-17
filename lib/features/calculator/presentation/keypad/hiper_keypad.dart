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
const KeypadDefinition hiperKeypad = KeypadDefinition(<KeypadRow>[
  // 中文：行 1——SHIFT / MENU / 光标左右 / 退格 / 清空。HiPER 的最上一行没有标签横带。
  //
  //       **`◀` `▶` 不是翻页键——它们是光标键。** 计划书写着「键盘翻页」，量了来源之后那句话是错的，
  //       这里按量到的做。四条证据（都在本机取回，见 `keypad_definition_test.dart` 的同名快照）：
  //
  //       1. **HiPER 的命令表里没有翻页这个动作。** 项目公开翻译 API 的 `command.name.*` 共 213 条，
  //          逐条读完**没有** `PAGE_LEFT`/`PAGE_RIGHT`/`NEXT_KEYBOARD`；与左右箭头有关的只有两条：
  //          `CHAR_LEFT` = "Move cursor one char left"、`CHAR_RIGHT` = "Move cursor one char right"。
  //       2. **HiPER 的帮助把它们说成光标键**（`help.expressions.contents`，Expression Mode）：
  //          "Use arrow keys `<key:CHAR_LEFT>` and `<key:CHAR_RIGHT>` or tap on the expression to
  //          navigate through parameters or through the whole expression." 同一份文本还写着
  //          "Keep `<key:CHAR_LEFT>`, `<key:CHAR_RIGHT>` and `<key:BACKSPACE>` keys pressed to repeat
  //          their operation."——**按住连发也是这两颗键的行为**。
  //       3. **真机截图**（`~/Downloads/04_媒体/Screenshot_2026-05-12-13-11-45-205_cz.hipercalc.p.jpg`）
  //          上 `◀` `▶` 用的是 `MENU` 那种可用灰，不是禁用态；同一张图上 `8 000 ÷ 5` 的末尾立着一根
  //          光标条——正是这两颗键要移动的东西。
  //       4. 帮助里唯一像「翻页」的两处都不是键盘翻页：`#key-table:MAIN#`/`#key-table:POW_LOG#` 等是
  //          **帮助页自己的表格分段**；`releaseNotes` 那句 "New key in custom keyboards: switch to
  //          another keyboard" 说的是**自定义键盘**可以带一颗切换键，内置键盘上没有这东西。
  //
  //       所以本表把它们接到控制器**已有**的两个方法上（`moveCursorLeft`/`moveCursorRight`，它们就是
  //       「移动一个字符」），键面文字与位置一格未动。
  //
  //       **没上这一轮的东西**：证据 2 里的「按住连发」键盘上没有。本应用有现成的连发实现
  //       （`calculator_page_repeat_button.dart`），但它挂在 `More...` 面板里；把连发做进键盘要动
  //       `CalculatorKeypad` 的手势层，而那一层由**全部 60 多颗键共用**——「不改已经能用的键」比这一点
  //       体面更重要。本轮的 `◀` `▶` 是**一下一格**，这是取舍的公开记录，不是「已经做完」。
  //
  // English: Row 1 — SHIFT / MENU / cursor left and right / backspace / clear. HiPER's topmost row
  //          carries no label band.
  //
  //          **`◀` `▶` are not page keys — they are cursor keys.** The plan says "keypad paging" and
  //          that sentence is wrong once the sources are measured; the measured thing is what got built.
  //
  //          1. **HiPER's command catalogue has no paging action.** Its 213 distinct `command.name.*`
  //             entries contain **no** `PAGE_LEFT`/`PAGE_RIGHT`/`NEXT_KEYBOARD`; the only left/right
  //             ones are `CHAR_LEFT` = "Move cursor one char left" and `CHAR_RIGHT` = "Move cursor one
  //             char right".
  //          2. **HiPER's help calls them cursor keys** (`help.expressions.contents`, Expression Mode):
  //             "Use arrow keys `<key:CHAR_LEFT>` and `<key:CHAR_RIGHT>` or tap on the expression to
  //             navigate through parameters or through the whole expression", and "Keep
  //             `<key:CHAR_LEFT>`, `<key:CHAR_RIGHT>` and `<key:BACKSPACE>` keys pressed to repeat their
  //             operation" — **hold-to-repeat is part of these keys' behaviour**.
  //          3. On the **real screenshot** cited above, `◀` and `▶` wear `MENU`'s enabled grey rather
  //             than a disabled treatment, and a caret stands at the end of `8 000 ÷ 5` — the very thing
  //             they move.
  //          4. The only paging-shaped help strings are not keypad paging: `#key-table:MAIN#` and
  //             friends are the **help page's own sections**, and "New key in custom keyboards: switch
  //             to another keyboard" is about **custom** keyboards, which the built-in one lacks.
  //
  //          So the table wires them to the two controller methods that already exist
  //          (`moveCursorLeft`/`moveCursorRight`, one character each); face text and grid position are
  //          untouched.
  //
  //          **What is not on this round**: the hold-to-repeat of evidence 2 is not on the keypad. This
  //          app owns a repeat implementation (`calculator_page_repeat_button.dart`) but it hangs inside
  //          the `More...` sheet; putting repeat on the keypad means touching `CalculatorKeypad`'s
  //          gesture layer, which **all 60-odd keys share** — "change no key that already works"
  //          outweighs the polish, so this round's `◀` `▶` are **one character per tap**. This is the
  //          trade-off on the record, not a claim the work is done.
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
      // 中文：**`◀` 从这一步起点亮**——向左移动光标一个字符（HiPER 的 `CHAR_LEFT`，
      //       见本行上面那一段来源）。它走控制器已有的 `moveCursorLeft()`，不新造动作。
      //       光标已经在最开头时它是一个空操作：那里没有可去的位置，屏幕上的光标本来就停在 0。
      // English: **`◀` lights up from this step on** — move the cursor one character left (HiPER's
      //          `CHAR_LEFT`; the sources are in the note above this row). It travels the controller's
      //          existing `moveCursorLeft()` rather than inventing an action. With the caret already at
      //          position 0 it is a no-op: there is nowhere to go, and the caret is visibly already
      //          there.
      KeypadKey(
        base: KeyVariant(label: '◀', id: 'cursorLeft'),
        category: KeyCategory.function,
      ),
      // 中文：**`▶` 同理**——向右移动光标一个字符（`CHAR_RIGHT`），走 `moveCursorRight()`。
      //       光标已经在末尾时同样是空操作。
      // English: **`▶` likewise** — move the cursor one character right (`CHAR_RIGHT`) through
      //          `moveCursorRight()`; with the caret already at the end it is a no-op too.
      KeypadKey(
        base: KeyVariant(label: '▶', id: 'cursorRight'),
        category: KeyCategory.function,
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
  //       只有四个进制胶囊与 hyp 五个，所以这里是不可点的纯提示）、FSE（**仍未接上的**提示：
  //       HiPER 上是「数字记法」那一维——Normal / Fixed / Scientific / Engineering / Engineering SI，
  //       而本应用没有这一维，所以它只是一条提示，不是承诺；上方的键 `x⇔E` 从这一步起点亮，管的是
  //       结果**形式**那一维，与 FSE 不是同一件事。SHIFT 态下按 `x⇔E` 走的是它自己的基准动作
  //       （`CalculatorKeypad._resolve` 写的：没有 shift 变体的键回落到基准），与 `d/dx` 同一种情形）、
  //       MTRX（矩阵键的 SHIFT 提示，已接上）、Π（Σ 的 SHIFT 提示，已接上）、d/dx（∫dx 的 SHIFT 提示，
  //       仍未接上：引擎算得出符号导数，但符号结果过不了提交路径的「必须是有限十进制」那道门，
  //       键点亮了也只会报错，见步骤 5 报告），相机键上方无标签。
  // English: Row 2 — DRG / x⇔E / matrix / summation / product / camera.
  //          Band above: DRG (a hint about cycling DEG↔RAD; HiPER's `▸` is decoration and the
  //          only real band buttons are the four base pills plus hyp, so this one is a
  //          non-tappable hint), FSE (**still unwired**: on HiPER it is the "number notation"
  //          dimension — Normal / Fixed / Scientific / Engineering / Engineering SI — and this app
  //          has no such dimension, so it is a hint rather than a promise; the key under it, `x⇔E`,
  //          lights up from this step on and owns the result **form** dimension instead, which is a
  //          different thing. Under SHIFT, `x⇔E` runs its own base action — as
  //          `CalculatorKeypad._resolve` says, a key without a shift variant falls back to the base —
  //          exactly the situation `d/dx` is in), MTRX (hint of the matrix key),
  //          Π (hint of Σ, now wired), d/dx (hint of ∫dx, still unwired: the engine can produce a
  //          symbolic derivative, but a symbolic result does not pass the submit path's "must be a
  //          finite decimal" gate, so lighting the key up would only produce errors — see the
  //          step 5 report); the camera key has no hint.
  KeypadRow(
    keys: <KeypadKey>[
      KeypadKey(
        base: KeyVariant(label: 'DRG', id: 'angleMode'),
        category: KeyCategory.function,
      ),
      KeypadKey(
        base: KeyVariant(label: 'x⇔E', id: 'resultForm'),
        category: KeyCategory.function,
      ),
      KeypadKey(
        base: KeyVariant(label: 'MTRX', id: 'ins:matrix'),
        category: KeyCategory.function,
      ),
      KeypadKey(
        base: KeyVariant(label: 'Σ', id: 'ins:sum'),
        category: KeyCategory.function,
        shift: KeyVariant(label: 'Π', id: 'ins:product'),
      ),
      KeypadKey(
        base: KeyVariant(label: '∫dx', id: 'ins:integrate'),
        category: KeyCategory.function,
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

  // 中文：行 3——π / sin / cos / tan / i / e。
  //       上方标签：hyp 实体修饰键（可直接点按，是可查证的刻意偏离）、sin⁻¹/cos⁻¹/tan⁻¹
  //       三个 SHIFT 提示、仍禁用的 ∠，以及 logₓy（已启用：它插的是引擎 `log(数, 底)` 的二元调用）。
  //       sin/cos/tan 同时带 SHIFT 变体（asin/acos/atan）与 hyp 变体（sinh/cosh/tanh）。
  // English: Row 3 — π / sin / cos / tan / i / e.
  //          Band above: the tappable `hyp` modifier key (a documented deviation from
  //          HiPER), the sin⁻¹/cos⁻¹/tan⁻¹ SHIFT hints, the still-disabled ∠, and an enabled
  //          logₓy — it inserts the engine's two-argument `log(number, base)` call.
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
        base: KeyVariant(label: 'i', id: 'ins:i'),
        category: KeyCategory.function,
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
          base: KeyVariant(label: 'logₓy', id: 'ins:logxy'),
          category: KeyCategory.function,
        ),
      ),
    ],
  ),

  // 中文：行 4——倒数 / 平方 / 开方 / 幂 / 对数 / 自然对数。
  //       上方标签：lim（已启用：插引擎的 `limit(` 调用），以及 x³、∛x、ˣ√y、10ˣ、eˣ 五个
  //       SHIFT 提示——它们分别落在下方对应主键的 `shift` 变体上。
  // English: Row 4 — reciprocal / square / square root / power / log / ln.
  //          Band above: an enabled lim (it inserts the engine's `limit(` call) plus the x³, ∛x,
  //          ˣ√y, 10ˣ, eˣ SHIFT hints, each of which also lives on the matching key below as its
  //          `shift` variant.
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
          base: KeyVariant(label: 'lim', id: 'ins:limit'),
          category: KeyCategory.function,
        ),
      ),
      ShiftLabel('x³'),
      ShiftLabel('∛x'),
      ShiftLabel('ˣ√y'),
      ShiftLabel('10ˣ'),
      ShiftLabel('eˣ'),
    ],
  ),

  // 中文：行 5——度分秒 / 分数 / X / XY,M（**只剩 `XY,M` 一条禁用**）/ 记忆读取 / 记忆写入。
  //       上方标签：**`STAT` 从这一步起点亮**（原来是一颗灰键 `dis:stat`），`a b/c` 仍是禁用键，
  //       `Y` 把 `y` 插进表达式，HISTORY（打开抽屉的历史入口），
  //       M+、M−（记忆累加与累减——它们与 `memoryAdd`/`memorySubtract` 语义一致）。
  //       注意 `x→M`：它**不是**累加，HiPER 上它是把当前值写进寄存器（替换）；主屏用
  //       「先清空再累加」实现它，见 `calculator_page.dart` 的 `memoryStore` case。
  //       **`d/c` 从这一步起点亮**：HiPER 的 `d/c` 是结果格式系统里分数那一格（它的手册把「结果
  //       格式」与「数字记法」分成两维：`x⇔E` 是前者、`FSE` 是后者，而 `d/c` 的 SHIFT 标签就是
  //       `a b/c`——带分数，正是同一格里的另一个取值），所以它做的就是把当前结果换成**分数写法**、
  //       再按一次换回十进制。分数写法由引擎对**同一个已求值结构**换一种 `number_fraction_format`
  //       印出来（见 `printOptions`），两份的值严格相等；引擎没答上来时它是空操作，不去猜一个分数。
  // English: Row 5 — D°M'S / d/c / X / XY,M (**only `XY,M` is still disabled**) / memory recall and
  //          memory store.
  //          Band above: **`STAT` lights up from this step on** (it used to be a grey `dis:stat`),
  //          `a b/c` is still disabled, `Y` inserts `y`, HISTORY (the drawer's history entry), and
  //          M+ / M− (memory accumulate and decrement — these two do match
  //          `memoryAdd`/`memorySubtract`). Note `x→M`: it is **not** an accumulate — on HiPER it
  //          writes the current value into the register (a replace); the screen implements that as
  //          "clear, then add", see the `memoryStore` case in `calculator_page.dart`.
  //          **`d/c` lights up from this step on**: HiPER's `d/c` is the fraction cell of the result
  //          format system (its manual splits "result format" from "number notation": `x⇔E` is the
  //          first, `FSE` the second, and `d/c`'s SHIFT label is `a b/c` — a mixed number, i.e. the
  //          other value in that same cell), so what it does is put the current result in its
  //          **fraction spelling** and put the decimal back on a second press. The fraction spelling
  //          is the engine printing **one already evaluated structure** under a different
  //          `number_fraction_format` (see `printOptions`), so the two carry strictly equal values;
  //          with no engine answer it is a no-op rather than a guessed fraction.
  KeypadRow(
    keys: <KeypadKey>[
      // 中文：**`D°M'S` 从这一步起点亮：它把当前结果换成度分秒写法**（`12°34′55.92″`），再按一次
      //       回到原来那一行。它与右边的 `d/c` 同一条路（结果格式那一维的又一格），只改**显示**。
      //
      //       **HiPER 那一颗键做的是「输入」，这里做的为什么是「显示」——依据与取舍都写在这里：**
      //
      //       HiPER 自己的帮助原文（HiPER Scientific Calculator 的翻译源串，本机可查：
      //       `weblate.a4tune.com` 的公开 API，`help.numbers.contents` 与 `quickTour.page.DMS.*`）
      //       把它分成了三件**互不相同**的事：
      //       - `DMS` 键："If you want to enter a number as degrees, minutes and seconds (a
      //         sexagesimal number), use <key:DMS> key." —— **输入**（命令名
      //         `command.name.DMS` = "Insert Degrees, Mins, Secs"）。
      //       - `REDMS` 键："<key:REDMS> key converts the result into degrees, minutes and seconds.
      //         The key is not present on built-in keyboards…" —— **结果转度分秒**，而它
      //         **不在内置键盘上**（命令名 `command.name.REDMS` = "Display as Degrees, Mins, Secs"）。
      //       - `CHANGE_EXPR`（就是 `x⇔E`）：切换结果格式，其中一档是 sexagesimal，指示器 `DMS`。
      //
      //       所以内置键盘上那一颗 `D°M'S` 在 HiPER 上是**输入键**，而不是结果格式键。本项目**没有**
      //       照搬输入那一半，理由是实测的三条，全部在应用这一侧：
      //       1. **表达式行排不出 `°`**：`ExpressionAstParser` 遇到 `°` 会整段降级成 `ParseErrorNode`，
      //          TeX 变成 `\text{30°}`（一段字面文本）。按一下键就让整行表达式不再排版，是可见的退化。
      //       2. **旧解析器算不对中间态**：`12°34` 今天是 `7.12`（`rad(12)*34` 的隐式乘法），
      //          `12°34′56″` 直接 FormatException——按出来的每一串都会先经过这些中间态。
      //       3. **`°` 在 DEG 下是活的错值**：`sin 30°` 在 RAD 下 = 0.5，在 DEG 下 = 0.009138
      //          （解析器把它改写成 `rad(30)`，而 DEG 的三角函数再把实参乘一次 π/180）。
      //          这颗键一旦上线，那条错值就从「粘贴才够得着」变成「按两下就够得着」。
      //       要照搬输入那一半，得同时给三个地方（求值器、语法树、TeX 生成）加一套度分秒字面量语法，
      //       并先判定 `°` 在 DEG 下到底该是什么意思——那是另一个工程，且每一步都可能悄悄印出一个错值。
      //       而结果这一半**今天就能做对**：引擎真的印得出度分秒（`BASE_SEXAGESIMAL`，见
      //       `printOptions` 那一段；上一轮记的「引擎没有度分秒换算」是**实测错误**——它叫
      //       sexagesimal，`grep -rni dms` 当然搜不到），而且印的是**同一个已求值结构**，
      //       所以值逐位相同，与 `d/c` 是同一个形状。**谁按这一颗键，谁按的就是 HiPER 的 `DMS`
      //       那一格结果格式**（HiPER 屏幕上唯一写着 DMS 的东西），而 HiPER 把它放在自定义键盘上的
      //       那一颗 `REDMS` 做的事。
      // English: **`D°M'S` lights up from this step on: it switches the current result to its
      //          degrees-minutes-seconds spelling** (`12°34′55.92″`), and a second press returns to
      //          the line it had. It travels the same road as `d/c` beside it (another cell of the
      //          result-format dimension) and changes **display only**.
      //
      //          **HiPER's key inserts; why this one displays — the evidence and the trade-off:**
      //
      //          HiPER's own help text (the app's translation source strings, reachable from this
      //          machine: the public API at `weblate.a4tune.com`, `help.numbers.contents` and
      //          `quickTour.page.DMS.*`) splits it into three **different** things:
      //          - the `DMS` key: "If you want to enter a number as degrees, minutes and seconds (a
      //            sexagesimal number), use <key:DMS> key." — **entry** (command name
      //            `command.name.DMS` = "Insert Degrees, Mins, Secs").
      //          - the `REDMS` key: "<key:REDMS> key converts the result into degrees, minutes and
      //            seconds. The key is not present on built-in keyboards…" — **converting a result**,
      //            and it is **not on the built-in keypad** (its command name is
      //            `command.name.REDMS` = "Display as Degrees, Mins, Secs").
      //          - `CHANGE_EXPR` (that is `x⇔E`): cycles the result format, one stop of which is
      //            sexagesimal, with the `DMS` indicator.
      //
      //          So the `D°M'S` cell on HiPER's built-in keypad is an **entry** key, not a result
      //          format key. This project did **not** copy the entry half, for three reasons that were
      //          all measured on the app side:
      //          1. **the expression line cannot typeset `°`**: `ExpressionAstParser` degrades the whole
      //             string to a `ParseErrorNode` and the TeX becomes `\text{30°}`, a literal text blob.
      //             One press would stop the entire expression line from being typeset — a visible
      //             degradation.
      //          2. **the legacy parser misreads the intermediate states**: `12°34` is `7.12` today
      //             (an implicit multiplication with `rad(12)`), and `12°34′56″` throws outright —
      //             every string the key can build passes through states like those.
      //          3. **`°` is a live wrong value under DEG**: `sin 30°` is 0.5 under RAD and 0.009138
      //             under DEG (the parser rewrites it to `rad(30)`, and DEG's trig multiplies the
      //             argument by π/180 again). Shipping that key would move that wrong value from
      //             "only reachable by pasting" to "two taps away".
      //          Copying the entry half would mean adding a degrees-minutes-seconds literal to three
      //          places at once (the evaluator, the syntax tree, the TeX emitter) and first deciding
      //          what `°` is supposed to mean under DEG — a project of its own, and every step of it
      //          can quietly print a wrong value. The result half **can be done correctly today**: the
      //          engine really does print degrees-minutes-seconds (`BASE_SEXAGESIMAL`, see the note on
      //          `printOptions`; the previous round's "the engine has no DMS conversion" is **measurably
      //          wrong** — it is called *sexagesimal*, so `grep -rni dms` was never going to find it),
      //          and it prints **one already evaluated structure**, so the value is digit for digit the
      //          same, in the same shape as `d/c`. **Whoever presses this key presses HiPER's `DMS`
      //          result-format cell** — the only thing HiPER writes DMS on, on screen — which on HiPER
      //          lives on the `REDMS` key a custom keyboard can carry.
      KeypadKey(
        base: KeyVariant(label: "D°M'S", id: 'dmsForm'),
        category: KeyCategory.function,
      ),
      KeypadKey(
        base: KeyVariant(label: 'd/c', id: 'fractionForm'),
        category: KeyCategory.function,
      ),
      // 中文：**`X` 从这一步起点亮，它打开变量面板**（原来是一颗灰键 `dis:x`）。为什么是「打开
      //       面板」而不是「直接插入 `x`」：键盘上没有字母键，值总得有个入口，而一个只能插入字母的
      //       键只会产出**永远答不出来的表达式**（`2x` 永远是符号式）。面板的形状与 `CONV` 那颗键
      //       完全一致——键盘产不出的记号由一颗键打开的面板送进表达式。
      //       为什么 `Y` 不是同一颗键：键 id 全局唯一（`keypad_definition_test.dart` 逐格守着），
      //       而横带里那几颗本来就是**一下就能按到的快捷入口**（`HISTORY`/`M+`/`M−`），所以
      //       `Y` 保持横带的用法：一下把 `y` 插进表达式；两个变量的赋值都在 `X` 的面板里。
      // English: **the `X` key lights up from this step on and opens the variable sheet** (it used to
      //          be a grey `dis:x`). Why "open a sheet" rather than "insert `x` directly": the keypad
      //          has no letter keys, a value needs an entrance somewhere, and a key that can only
      //          insert the letter produces **permanently unanswerable expressions** (`2x` stays
      //          symbolic forever). The shape is exactly what `CONV` does — a token the keypad cannot
      //          produce is delivered into the expression by a sheet a key opens.
      //          Why `Y` is not the same key: key ids are globally unique (guarded cell by cell in
      //          `keypad_definition_test.dart`), and the band's own cells are **one-tap shortcuts**
      //          (`HISTORY`/`M+`/`M−`), so `Y` keeps the band's convention — one tap inserts `y`;
      //          both variables are assigned from `X`'s sheet.
      KeypadKey(
        base: KeyVariant(label: 'X', id: 'openVariables'),
        category: KeyCategory.variable,
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
      // 中文：**`STAT` 打开统计面板。** 为什么是「打开面板」而不是「一下插一个数」：HiPER 的
      //       `STAT` 背后是一台**统计编辑器**（输入一串数，再要众数/标准差/回归），而键盘上既没有
      //       逗号键、也没有字母键，那串数与那几个函数名都只能由面板送进表达式——与 `CONV`/`X`
      //       同一种做法，也与 `Σ`/`Π`/`∫dx` 那几颗「插完整调用」的键同一条理由。
      //       面板插入的是**完整**调用（`mean(1,2,3,4)`），插完就关：面板盖住键盘，留着它挡住
      //       下一步输入，而半条调用（`mean(`）在没有逗号键的键盘上永远补不完。
      // English: **`STAT` opens the statistics sheet.** Why "open a sheet" rather than "insert a
      //          number": what sits behind HiPER's `STAT` is a **statistics editor** (enter a run of
      //          numbers, then ask for the mean, the standard deviation, a regression), and the keypad
      //          has neither a comma key nor letter keys, so both the run of numbers and those
      //          function names can only reach the expression through a sheet — the `CONV`/`X` shape,
      //          and the same reason the `Σ`/`Π`/`∫dx` keys insert **complete** calls.
      //          The sheet inserts a complete call (`mean(1,2,3,4)`) and closes on the press: it covers
      //          the keypad otherwise, and half a call (`mean(`) can never be completed on a keypad
      //          with no comma key.
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: 'STAT', id: 'openStatistics'),
          category: KeyCategory.function,
        ),
      ),
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: 'a b/c', id: 'dis:abc', enabled: false),
          category: KeyCategory.disabled,
        ),
      ),
      // 中文：`Y` 与 `X` 是一对，但用法不同（见上面 `X` 那一段）：它把 `y` 一下插进表达式，
      //       与 `i`、`π` 那颗键同一种做法（`ins:` 前缀 = 插入这段文本）。赋值在 `X` 的面板里，
      //       两个变量都在那儿。
      // English: `Y` is `X`'s companion, with a different job (see the `X` note above): one tap
      //          inserts `y`, exactly as the `i` and `π` keys do (`ins:` means "insert this text").
      //          Assignment lives in `X`'s sheet, which covers both variables.
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: 'Y', id: 'ins:y'),
          category: KeyCategory.variable,
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
  //       上方标签：**`CPLX` 从这一步起点亮**（原来是一颗灰键 `dis:cplx`），以及 ∞（`ins:inf`）、
  //       %（`ins:%`）、mod。
  // English: Row 6 — digits 7 8 9 and parentheses. HiPER narrows to five columns here, so the
  //          band above holds only four cells and the last slot is padded with null: **`CPLX` lights
  //          up from this step on** (it used to be a grey `dis:cplx`), plus ∞ (`ins:inf`), `%`
  //          (`ins:%`) and mod.
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
      // 中文：**`CPLX` 打开复数面板——它是一个入口，不是一个模式。** 这一步先量后定，量出来的是：
      //       复数**能力早就在**（引擎的 `EvaluationOptions.setAllow_complex(true)` 一直接着，
      //       实测 `sqrt(-4)` = `2i`、`(3+4i)(1-i)` = `7 + i`、`abs(3+4i)` = `5`），所以「打开复数
      //       模式」会是一颗**把已经开着的东西再打开一次**的键，它的指示灯会是一句假话。
      //       真正缺的只有**入口**：共轭、辐角、实部、虚部这四个函数键盘上没有键，而它们都要括号
      //       与实参——键盘给不出来，面板可以（与 `CONV`/`X` 同一种做法）。
      //       面板插入的是一次**一元函数**调用（`conj`/`arg`/`re`/`im` 走 `applyUnaryFunction`，
      //       与 `sin`/`abs`/`sqrt` 逐字同一条路），所以光标位置、撤销栈、边打边算全都照旧。
      // English: **`CPLX` opens the complex sheet — it is an entrance, not a mode.** This was measured
      //          before it was decided: the complex **capability has been there all along** (the
      //          engine's `EvaluationOptions.setAllow_complex(true)` is set, and `sqrt(-4)` = `2i`,
      //          `(3+4i)(1-i)` = `7 + i`, `abs(3+4i)` = `5` all measure correctly), so "turn complex
      //          mode on" would be a key that switches on what is already on, and its indicator lamp
      //          would be a lie. What is genuinely missing is the **entrance**: the four functions
      //          conjugate / argument / real part / imaginary part have no key, and each needs brackets
      //          and an argument — the keypad cannot supply that, a sheet can (the `CONV`/`X` shape).
      //          The sheet inserts a **unary function** call (`conj`/`arg`/`re`/`im` go through
      //          `applyUnaryFunction`, byte for byte the path `sin`/`abs`/`sqrt` take), so cursor
      //          position, the undo stack and as-you-type evaluation all behave as before.
      InlineKey(
        KeypadKey(
          base: KeyVariant(label: 'CPLX', id: 'openComplex'),
          category: KeyCategory.function,
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
  //       上方标签：OTHER（打开工具箱）、ran#（已启用：插引擎的 `rand()`）、禁用的 EXP SI 与
  //       =,＜＞、Ans。
  // English: Row 9 — 0 / decimal point / sign toggle / EXP / equals.
  //          `EXP` uses `ins:exp` rather than the plan's `ins:e`, which the `e` constant on
  //          the row above already owns — the collision would break the global id-uniqueness
  //          invariant.
  //          Band above: OTHER (opens the tools), an enabled ran# (it inserts the engine's
  //          `rand()`), the disabled EXP SI and =,＜＞, and Ans.
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
          base: KeyVariant(label: 'ran#', id: 'ins:rand'),
          category: KeyCategory.function,
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
