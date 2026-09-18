part of 'hiper_keypad.dart';

/// 中文：键盘上半个区域里**横带只放不可点提示的那三行**——行 1（整条横带是空位）、行 2、行 4——
///       以及这五行的**行序表** `_functionRows`。
///
///       **这条缝按什么切：按横带里那一格是不是一颗按钮。** 规格书第 17 行写着「矮行不是按钮，
///       是下面那行主键的 SHIFT 功能标签」，并把唯一的例外点名为四个进制胶囊。本文件里的三行
///       **没有例外**；有例外的那两行（行 3 的 `hyp`，行 5 的 `STAT`/`a b/c`/`Y`/`HISTORY`/
///       `M+`/`M−`）住在同目录的 `hiper_keypad_band_key_rows.dart`，那里每一条 `InlineKey`
///       都必须能指出自己的出处。
///
///       为什么这条缝对后面几轮也对：最近五轮修的全是这条线上的东西（`FSE`、`∠`、`logₓy`、
///       `lim`，以及本轮的 `DRG`/`MTRX`），而没有例外的那几行正是它们住的地方；带按钮的两行
///       要动就得连 `InlineKey` 背后的动作一起动，是另一类改动。分开之后，两边各自的读者明确。
///
///       行序只由 `_functionRows` 一处说了算：五个行名分别定义在本文件与
///       `hiper_keypad_band_key_rows.dart`，**缺一个或改一个名字都是编译错误**——这条缝由
///       编译器守着，不靠注释。
///
/// English: the three rows of the keypad's upper region **whose band holds nothing but
///          non-tappable hints** — row 1 (its whole band is empty), rows 2 and 4 — plus the
///          **row-order table** `_functionRows`.
///
///          **What the seam is cut by: whether a band cell is a button.** Line 17 of the spec says
///          the short row is not a row of buttons but the SHIFT function labels of the row below,
///          and names the only exception as the four base pills. The three rows in this file have
///          **no exception**; the two that do (row 3's `hyp`, row 5's `STAT`/`a b/c`/`Y`/`HISTORY`/
///          `M+`/`M−`) live in `hiper_keypad_band_key_rows.dart` beside this file, where every
///          `InlineKey` has to be able to point at its source.
///
///          Why the seam stays right for the rounds ahead: the last five rounds fixed things on
///          exactly that line (`FSE`, `∠`, `logₓy`, `lim`), and the
///          rows with no exception are where they live; changing the two rows that carry buttons
///          means changing the action behind an `InlineKey` too, which is a different kind of
///          change. Split apart, each side has one clear reader.
///
///          The row order is decided in one place only, `_functionRows`: the five row names are
///          defined in this file and in `hiper_keypad_band_key_rows.dart`, and **a missing or
///          renamed one is a compile error** — the compiler guards this seam, not a comment.
const List<KeypadRow> _functionRows = <KeypadRow>[
  _modifierRow,
  _angleAndAggregateRow,
  _trigonometryRow,
  _powerAndLogRow,
  _formatAndMemoryRow,
];

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
const KeypadRow _modifierRow = KeypadRow(
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
);

  // 中文：行 2——DRG / x⇔E / 矩阵 / 求和 / 求积 / 相机。
  //       上方标签：DRG（循环 DEG↔RAD 的提示；HiPER 的 `▸` 只是装饰，而标签行里的实体键
  //       只有四个进制胶囊与 hyp 五个，所以这里是不可点的纯提示）、FSE（**`x⇔E` 的 SHIFT 提示，
  //       已接上**——上一轮它被做成横带里一颗可点的 `InlineKey`，本轮按来源退回提示，理由见下面
  //       `x⇔E` 那颗键上的长注释。那一维在 HiPER 上有五档——Normal / Fixed / Scientific /
  //       Engineering / Engineering SI，**本应用只接得上三档**（Normal / Scientific / Engineering），
  //       缺的两档与理由写在 `calculator_controller_notation.dart` 的文件头上，缺就是缺。上方的键
  //       `x⇔E` 的**基准**管的是结果**形式**那一维，SHIFT 才是记法——两维不是一件事）、
  //       MTRX（矩阵键的 SHIFT 提示，已接上）、Π（Σ 的 SHIFT 提示，已接上）、d/dx（∫dx 的 SHIFT 提示，
  //       **已接上**：SHIFT 态下按 `∫dx` 插的是 `diff(x^2,x)`，实参顺序是引擎自己的，不是 HiPER
  //       手册那套——两槽而不是四槽的理由在 `calculator_key_dispatch.dart` 的 `ins:diff` 那一段）、
  //       相机键上方无标签。**📷 本身仍未点亮，理由来自 HiPER
  //       自己的字符串**：`command.name.CAMERA` = "Expression recognition"；`cameraWindow.policy.info`
  //       写明选区图像**会被发往服务器**、由第三方模型 Pix2Text 识别（`recognitionWindow.pix2text`），
  //       `cameraWindow.proVersion` 说这是 Pro 专属。本机没有可分发的识别器，本机 OCR 只会产出
  //       **看似正确、实则错误**的表达式，故保持禁用（见相机键报告 camera-key-report.md）。
  // English: Row 2 — DRG / x⇔E / matrix / summation / product / camera.
  //          Band above: DRG (a hint about cycling DEG↔RAD; HiPER's `▸` is decoration and the
  //          only real band buttons are the four base pills plus hyp, so this one is a
  //          non-tappable hint), FSE (**the SHIFT hint of `x⇔E`, wired** — the previous round made it
  //          a tappable `InlineKey` in this band; this round puts it back to a hint per the sources,
  //          and the reasoning is on the `x⇔E` key's long note below. On HiPER that dimension has five
  //          positions — Normal / Fixed / Scientific / Engineering / Engineering SI — and **this app
  //          can only reach three** (Normal / Scientific / Engineering); the two that are missing, and
  //          why, are on the file head of `calculator_controller_notation.dart`. Missing is missing.
  //          The **base** action of the key under it, `x⇔E`, owns the result **form** dimension; the
  //          notation dimension sits on SHIFT — two different things), MTRX (hint of the matrix key),
  //          Π (hint of Σ, now wired), d/dx (hint of ∫dx, **now wired**: under SHIFT the `∫dx` key
  //          inserts `diff(x^2,x)`, in the engine's own argument order rather than the manual's — the
  //          note on `ins:diff` in `calculator_key_dispatch.dart` says why two slots and not four);
  //          the camera key has no hint. **📷 itself stays unlit, on HiPER's own
  //          strings**: `command.name.CAMERA` is "Expression recognition"; `cameraWindow.policy.info`
  //          says the cropped image **is sent to a server** for the third-party Pix2Text model to
  //          recognize (`recognitionWindow.pix2text`), and `cameraWindow.proVersion` marks it
  //          Pro-only. No such recognizer exists here, and a local OCR would only yield a
  //          **plausible but wrong** expression — so it stays disabled (see camera-key-report.md).

const KeypadRow _angleAndAggregateRow = KeypadRow(
  keys: <KeypadKey>[
    KeypadKey(
      base: KeyVariant(label: 'DRG', id: 'angleMode'),
      category: KeyCategory.function,
    ),
    // 中文：**`FSE` 是这一颗键的 SHIFT 功能**——不是横带里独立的键。上一轮把它做成了横带里
    //       一颗可点的 `InlineKey`，那是错的，本轮按来源改回来。三条来源，各自独立：
    //
    //       1. **真机截图**（本机 `~/Downloads/04_媒体/Screenshot_2026-05-12-13-11-45-205_cz.hipercalc.p.jpg`，
    //          裁出第 2 行的那一块是 `/tmp/hiper_row2.png`）：`FSE` 印在 `x⇔E` **正上方、水平居中对齐**；
    //          同一张图上 `▸DRG`/`MTRX`/`Π`/`d/dx`/`CNST` 也各自压在 `DRG`/矩阵/`Σ`/`∫dx`/`CONV` 上方。
    //       2. **HiPER 自己写了这条规则**（`/tmp/hiper_en.po`，`quickTour.page.SECOND_FUNCTION.text2`）：
    //          *"The key's second function is displayed in the label above."* —— 键上方的标签
    //          **就是**那颗键的第二功能。同一条 `text` 还说第二功能要靠 `SHIFT` 键进入。
    //          手册同页写着 "Symbols of these secondary functions are displayed above their keys"。
    //       3. **两条命令是分开的**：`command.name.CHANGE_EXPR` = "Result Format"（`x⇔E` 的基准，
    //          `resultFormat.info2` 说 "press `<key:CHANGE_EXPR>` key or tap on the result"），
    //          `command.name.FSE` = "Number Notation"。`id` 相邻但**是两个命令**。
    //
    //       所以这里挂的是 `shift`，键面文字与横带里那条提示都是 `FSE`——`Π`/`MTRX`/`d/dx`
    //       同一种形状，也同一条不变式：**横带那一格是纯提示、不可点**，一个动作只有一个 id 入口。
    //       上一轮 `d/dx` 那组测试把这条不变式写成了断言（`calculator_ddiff_key_test.dart`），
    //       `FSE` 现在受同一条约束。
    //
    //       **基准动作逐字节未动**：`resultForm`，结果**形式**那一维（`x⇔E` 的循环）。`FSE` 是
    //       另一维——数字**记法**。HiPER 手册自己就把这两段分成 "RESULT FORMAT" 与 "NOTATIONS" 两节。
    // English: **`FSE` is a SHIFT function of this key** — not a key of its own in the band. The
    //          previous round made it a tappable `InlineKey` in the band; that was wrong and this
    //          round puts it back where the sources put it. Three independent sources:
    //
    //          1. **The device screenshot** (on this machine, the crop of its row 2 is
    //             `/tmp/hiper_row2.png`): `FSE` is printed **directly above `x⇔E`, horizontally
    //             centred on it**; the same shot puts `▸DRG`/`MTRX`/`Π`/`d/dx`/`CNST` over
    //             `DRG`/matrix/`Σ`/`∫dx`/`CONV` the same way.
    //          2. **HiPER states the rule itself** (`/tmp/hiper_en.po`,
    //             `quickTour.page.SECOND_FUNCTION.text2`): *"The key's second function is displayed
    //             in the label above."* The label above a key **is** that key's second function, and
    //             the sibling string says the `SHIFT` key is how you reach it. The manual's own page
    //             says "Symbols of these secondary functions are displayed above their keys".
    //          3. **Two separate commands**: `command.name.CHANGE_EXPR` = "Result Format" (the base
    //             of `x⇔E`; `resultFormat.info2` says "press `<key:CHANGE_EXPR>` key or tap on the
    //             result") and `command.name.FSE` = "Number Notation" — adjacent ids, **two commands**.
    //
    //          So the variant goes on `shift`, with `FSE` as both the variant's face and the band's
    //          hint — the shape `Π`/`MTRX`/`d/dx` already have, and the same invariant with it: **the
    //          band cell is a plain hint and is not tappable**, one action has exactly one id
    //          entrance. The `d/dx` group wrote that invariant down as an assertion
    //          (`calculator_ddiff_key_test.dart`); `FSE` is under it now too.
    //
    //          **The base action has not moved by a byte**: `resultForm`, the result **form**
    //          dimension. `FSE` is another dimension — number **notation**. HiPER's manual splits
    //          them into its own two sections, "RESULT FORMAT" and "NOTATIONS".
    KeypadKey(
      base: KeyVariant(label: 'x⇔E', id: 'resultForm'),
      category: KeyCategory.function,
      shift: KeyVariant(label: 'FSE', id: 'notationCycle'),
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
      shift: KeyVariant(label: 'd/dx', id: 'ins:diff'),
    ),
    KeypadKey(
      base: KeyVariant(label: '📷', id: 'dis:camera', enabled: false),
      category: KeyCategory.disabled,
    ),
  ],
  labels: <KeypadLabel?>[
    ShiftLabel('DRG'),
    // 中文：**`FSE` 是一句提示，不是一颗键**——它压在 `x⇔E` 正上方，而那正是 HiPER
    //       自己给第二功能定的位置（`quickTour.page.SECOND_FUNCTION.text2`：
    //       *"The key's second function is displayed in the label above."*）。动作挂在上面那颗键的
    //       `shift` 上，见它的注释。**上一轮这里是 `InlineKey`**，那是主会话 brief 让「把它接成一个
    //       真控件」的结果——本轮按来源退回。同一个动作不能有两个 id 入口（键 id 全局唯一），
    //       这条不变式在 `calculator_ddiff_key_test.dart` 里已经是断言，`FSE` 与它同一形状。
    //       横带里真正的键是四个进制胶囊（手册第 1791 行："Press ►BIN , ►OCT , ►DEC and ►HEX keys"，
    //       真机图上它们也戴着胶囊底色）与 `hyp`（手册第 701 行："press hyp key"）。
    // English: **`FSE` is a hint, not a key** — it sits directly above `x⇔E`, which is exactly where
    //          HiPER puts a second function (`quickTour.page.SECOND_FUNCTION.text2`: *"The key's
    //          second function is displayed in the label above."*). The action hangs on the `shift`
    //          variant of the key above it; see that key's note. **This cell was an `InlineKey` last
    //          round**, the result of a brief that asked for it to be "wired as a real control"; this
    //          round it goes back to what the sources say. One action must not have two id entrances
    //          (key ids are globally unique) — the `d/dx` group already made that invariant an
    //          assertion, and `FSE` has the same shape. The band's real keys are the four base pills
    //          (manual line 1791: "Press ►BIN , ►OCT , ►DEC and ►HEX keys", and on the real screenshot
    //          they wear a capsule background) and `hyp` (manual line 701: "press hyp key").
    ShiftLabel('FSE'),
    ShiftLabel('MTRX'),
    ShiftLabel('Π'),
    ShiftLabel('d/dx'),
    null,
  ],
);

// 中文：行 4——倒数 / 平方 / 开方 / 幂 / 对数 / 自然对数。
//       上方标签：**六格全是 SHIFT 提示**，各自落在下方对应主键的 `shift` 变体上——
//       `lim`（`x⁻¹`）、x³（`x²`）、∛x（`√x`）、ˣ√y（`xʸ`）、10ˣ（`log₁₀`）、eˣ（`ln`）。
//
//       **`lim` 本轮从可点的 `InlineKey` 退回提示**（与上一轮 `FSE`、上上轮 `∠`/`logₓy` 同一类偏差、
//       同一种改法）。它是这一类里的最后一格，来源如下（都是本机可查的）：
//
//       1. **本行六格在真机截图上一一对齐下方六键**（1440×3200 原图
//          `~/Downloads/04_媒体/Screenshot_2026-05-12-13-11-45-205_cz.hipercalc.p.jpg`，
//          横带 `y=1653..1744`、主键 `y=1745..1868`，按像素量列的横向中心）：
//          横带 `lim/x³/∛x/ˣ√y/10ˣ/eˣ` = `130.0 / 363.0 / 602.0 / 838.0 / 1079.0 / 1313.5`，
//          主键 `x⁻¹/x²/√x/xʸ/log₁₀/ln` = `126.0 / 364.0 / 600.5 / 841.5 / 1078.0 / 1313.5`。
//          列宽 238 px，六对差值最大 5.5 px。
//       2. **本行已有五格在本应用里就是 `shift` 变体**（x³/∛x/ˣ√y/10ˣ/eˣ）——也就是说「这条横带是
//          SHIFT 带」不是外来的推断，本应用自己已经这么认了五格；`lim` 是第六格。
//       3. **本项目自己的规格书写着同一件事**，而且它把唯一的例外点名了
//          （`docs/superpowers/specs/2026-09-16-hiper-keypad-and-main-screen-design.md`，第 17 行）：
//          「**核心机制：矮行不是按钮，是下面那行主键的 SHIFT 功能标签**……**唯一例外**：
//          `▸BIN` `▸OCT` `▸DEC` `▸HEX` 是**真按钮**（白色胶囊），被特意放进标签行。」
//          它的 ASCII 键盘图把 `lim` 画在第 4 行 SHIFT 标签行、`x⁻¹` 正上方。
//       4. **HiPER 自己给这个位置下了定义**：`quickTour.page.SECOND_FUNCTION.text2` = "The key's
//          second function is displayed in the label above."；手册 §SHIFT（`hipercalc-manual.txt:517`）
//          "Symbols of these secondary functions are displayed above their keys."
//       5. **手册把 `lim` 叫作 "key" 不说明任何事**：同一份手册第 692 行写着 "use sin-1 , cos-1 and
//          tan-1 **keys**"——那三颗就是本行上方的横带格。第 1138 行 "Press the `lim` key" 用的是
//          同一套措辞；帮助串里 `<key:LIMIT>` 与 `<key:ASIN>` 的形状也完全一样。
//          `command.name.LIMIT` = "Limit"（另有 `LIMIT_MENU` = "Limit Menu"）与 `FSE`/`CHANGE_EXPR`
//          一样只是命令表里的一行，命令表里有没有它**不决定**它有没有自己的键。
//       6. **视觉上它也不是键**：同一张图上戴白色胶囊的横带格只有 `►BIN`/`►OCT`/`►DEC`/`►HEX`；
//          `lim` 与它旁边五格一样是平排文字。
//
//       **它插的东西一个字未动**：`ins:limit` 仍是 `limit(sin(x)/x,0,x)`（键盘上没有逗号键，半条
//       调用补不完，所以插完整调用）。引擎认它——宿主 libqalculate 5.12.0 实测 `limit(sin(x)/x,0,x)`
//       = `1`（RAD）/ `0.01745329252`（DEG，即 π/180，度制下正是这个值），翻译层原样透传成
//       `limit(((sin(x))/(x)),0,x)`；应用自己的旧解析器读不了它（抛 `FormatException`），所以引擎
//       缺席时**报错而不是猜一个值**。**基准动作 `ins:^-1` 逐字节未动。**
// English: Row 4 — reciprocal / square / square root / power / log / ln.
//          Band above: **all six cells are SHIFT hints**, each living on the matching key below as
//          its `shift` variant — `lim` (`x⁻¹`), x³ (`x²`), ∛x (`√x`), ˣ√y (`xʸ`), 10ˣ (`log₁₀`),
//          eˣ (`ln`).
//
//          **`lim` goes back from a tappable `InlineKey` to a hint this round** (the same class of
//          deviation, and the same fix, as `FSE` last round and `∠`/`logₓy` the round before). It is
//          the last cell in that class. The sources, all reachable on this machine:
//
//          1. **All six cells of this row line up one-to-one with the six keys below** on the device
//             screenshot (the 1440×3200 original cited above; band `y=1653..1744`, keys
//             `y=1745..1868`, measured as pixel column centres): band
//             `lim/x³/∛x/ˣ√y/10ˣ/eˣ` = `130.0 / 363.0 / 602.0 / 838.0 / 1079.0 / 1313.5`, keys
//             `x⁻¹/x²/√x/xʸ/log₁₀/ln` = `126.0 / 364.0 / 600.5 / 841.5 / 1078.0 / 1313.5`.
//             Column width 238 px; the largest of the six gaps is 5.5 px.
//          2. **Five cells of this very row are already `shift` variants here** (x³/∛x/ˣ√y/10ˣ/eˣ) —
//             "this band is the SHIFT band" is not an outside inference; this app already agrees
//             about five of the six. `lim` is the sixth.
//          3. **This project's own spec says the same thing and names the only exception**
//             (line 17 of the spec cited above): the short row is not a row of buttons but the SHIFT
//             function labels of the keys below, and the **only** exception is `▸BIN`/`▸OCT`/`▸DEC`/
//             `▸HEX`, real buttons with a white capsule deliberately placed in the band. Its ASCII
//             layout draws `lim` in row 4's SHIFT label row, directly over `x⁻¹`.
//          4. **HiPER defines what that position means**: `quickTour.page.SECOND_FUNCTION.text2` =
//             "The key's second function is displayed in the label above.", and the manual's SHIFT
//             section (`hipercalc-manual.txt:517`) "Symbols of these secondary functions are
//             displayed above their keys."
//          5. **The manual calling `lim` a "key" decides nothing**: line 692 of the same manual says
//             "use sin-1 , cos-1 and tan-1 **keys**" — three band cells of this very row. Line 1138's
//             "Press the `lim` key" is the same wording, and the help markup `<key:LIMIT>` has
//             exactly the shape of `<key:ASIN>`. `command.name.LIMIT` = "Limit" (plus `LIMIT_MENU` =
//             "Limit Menu") is one row of the command catalogue, the same trap `FSE`/`CHANGE_EXPR`
//             set: a row there decides nothing about whether the thing has a key.
//          6. **Visually it is not a key either**: the only band cells wearing a white capsule in
//             that screenshot are `►BIN`/`►OCT`/`►DEC`/`►HEX`; `lim` is plain text like its five
//             neighbours.
//
//          **What it inserts has not moved a byte**: `ins:limit` is still `limit(sin(x)/x,0,x)` (the
//          keypad has no comma key, so half a call can never be completed and the key inserts a
//          whole one). The engine knows it — host libqalculate 5.12.0 measures `limit(sin(x)/x,0,x)`
//          = `1` under RAD and `0.01745329252` under DEG (π/180, which is the correct value in
//          degree mode) — and the translator passes it through verbatim as
//          `limit(((sin(x))/(x)),0,x)`. This app's own legacy parser cannot read it (it throws
//          `FormatException`), so with no engine answer the result is **an error rather than a
//          guessed value**. **The base action `ins:^-1` has not moved by a byte.**
const KeypadRow _powerAndLogRow = KeypadRow(
  keys: <KeypadKey>[
    // 中文：**`lim` 是这一颗键的第二功能**——不是横带里独立的键。上一轮它被做成横带里一颗可点的
    //       `InlineKey`，本轮按上面那六条来源改回来。挂上去的是 `shift`，键面文字与横带里那条提示
    //       都是 `lim`，与 `Π`/`MTRX`/`d/dx`/`FSE` 同一种形状，也同一条不变式：**横带那一格是纯
    //       提示、不可点**，一个动作只有一个 id 入口。
    // English: **`lim` is this key's second function** — not a key of its own in the band. Last
    //          round it was a tappable `InlineKey` there; this round puts it back per the six
    //          sources above. The variant goes on `shift`, with `lim` as both its face and the
    //          band's hint — the shape `Π`/`MTRX`/`d/dx`/`FSE` already have, and the same
    //          invariant with it: **the band cell is a plain hint and is not tappable**, one action
    //          has exactly one id entrance.
    KeypadKey(
      base: KeyVariant(label: 'x⁻¹', id: 'ins:^-1'),
      category: KeyCategory.function,
      shift: KeyVariant(label: 'lim', id: 'ins:limit'),
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
    // 中文：**`lim` 是一句提示，不是一颗键**——它压在 `x⁻¹` 正上方，而那正是 HiPER 自己给第二功能
    //       定的位置（`quickTour.page.SECOND_FUNCTION.text2`）。动作挂在下面那颗键的 `shift` 上，
    //       见它的注释。**上一轮这里是 `InlineKey`**，与 `FSE`/`∠`/`logₓy` 同一类偏差，本轮是这一类的
    //       最后一格。同一个动作不能有两个 id 入口（键 id 全局唯一）。
    // English: **`lim` is a hint, not a key** — it sits directly above `x⁻¹`, which is exactly where
    //          HiPER puts a second function (`quickTour.page.SECOND_FUNCTION.text2`). The action
    //          hangs on the `shift` variant of the key below; see that key's note. **This cell was
    //          an `InlineKey` last round**, the same class of deviation as `FSE`/`∠`/`logₓy`, and the
    //          last cell in that class. One action must not have two id entrances (key ids are
    //          globally unique).
    ShiftLabel('lim'),
    ShiftLabel('x³'),
    ShiftLabel('∛x'),
    ShiftLabel('ˣ√y'),
    ShiftLabel('10ˣ'),
    ShiftLabel('eˣ'),
  ],
);
