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
///          exactly that line (`FSE`, `∠`, `logₓy`, `lim`, and this round's `DRG`/`MTRX`), and the
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
//       上方标签：▸DRG（**`▸DRG` 的 SHIFT 提示，已点亮**——HiPER 那一格是 `TO_DRG`
//       「换算角度单位」，与本行下方 `DRG` 那颗键的「切换角度单位」**是两个命令**：前者换算**当前
//       显示的那个数**、先问源单位与目标单位，后者换的是**模式**。本轮建起了前者：`openAngleConvert`
//       打开一个面板，选好源与目标之后把整条表达式换成 `<值> <源单位> to <目标单位>`。来源、理由与
//       被拒绝的 `grad` 写在下面 `DRG` 那颗键的长注释里），
//       FSE（**`x⇔E` 的 SHIFT 提示，已接上**——上一轮它被做成横带里一颗可点的 `InlineKey`，
//       本轮按来源退回提示，理由见下面 `x⇔E` 那颗键上的长注释。那一维在 HiPER 上有五档——
//       Normal / Fixed / Scientific / Engineering / Engineering SI，**本应用只接得上三档**
//       （Normal / Scientific / Engineering），缺的两档与理由写在
//       `calculator_controller_notation.dart` 的文件头上，缺就是缺。上方的键 `x⇔E` 的**基准**
//       管的是结果**形式**那一维，SHIFT 才是记法——两维不是一件事）、
//       MTRX（**矩阵键的 SHIFT 提示，本轮真的点亮了**——HiPER 那一格是 `MATRIX_MENU`
//       「矩阵与向量菜单」，本轮建起了这个菜单：`openMatrixMenu` 打开一个面板，面板里四项各插一条
//       围着 `matrix(2,2,1,2,3,4)` 的完整调用；同一份实测里也量出 `rank`/`trace`/`echelon` 三个
//       必须拒绝的名字，它们在面板里是灰的。来源、理由与被拒绝的那三个写在下面矩阵键的长注释里）、
//       Π（Σ 的 SHIFT 提示，已接上）、d/dx（∫dx 的 SHIFT 提示，
//       **已接上**：SHIFT 态下按 `∫dx` 插的是 `diff(x^2,x)`，实参顺序是引擎自己的，不是 HiPER
//       手册那套——两槽而不是四槽的理由在 `calculator_key_dispatch.dart` 的 `ins:diff` 那一段）、
//       相机键上方无标签。**📷 本身仍未点亮，理由来自 HiPER
//       自己的字符串**：`command.name.CAMERA` = "Expression recognition"；`cameraWindow.policy.info`
//       写明选区图像**会被发往服务器**、由第三方模型 Pix2Text 识别（`recognitionWindow.pix2text`），
//       `cameraWindow.proVersion` 说这是 Pro 专属。本机没有可分发的识别器，本机 OCR 只会产出
//       **看似正确、实则错误**的表达式，故保持禁用（见相机键报告 camera-key-report.md）。
//
//       **一处实测更正（本轮）：这一格跟的是厂商当前的默认键盘，不是本机那张截图——所以相机键留在原位。**
//       两张图都对，差的是**布局版本**：
//       1. **厂商官网的当前主屏截图**（`https://hiperlabs.eu/screenshots.html` →
//          `assets/img/01 calculator.png`，本轮自己下载、逐格读过）：第 2 行第 6 格是**相机键**
//          （上方无标签），而 `CNST`/`CONV` 落在 `1`/`2` 的横带上——与本表**逐格一致**。
//       2. **本机那张 1440×3200 真机截图**（`~/Downloads/04_媒体/…cz.hipercalc.p.jpg`）量到的是**另一个
//          布局**：第 6 格是 `CONV`、`CNST` 是它的第二功能（横带那一格），`1`/`2` 上方是 `gcd`/`lcm`。
//       3. **厂商自己的字符串把这件事说明白了**（`cameraWindow.cameraRevoked.info` /
//          `cameraWindow.permissionRevoked.text`）："If you want to use the former keyboard layout with
//          the `<key:CONST>` and `<key:CONV>` keys **in their original positions**, … select the
//          **Custom / Version 10 keyboard**."——本机截图那一版就是 Version 10；当前默认布局把
//          `CONST`/`CONV` 挪到 `1`/`2` 的横带、把原来那一格给了相机键。
//       所以**这颗 `📷` 不是本应用自加的**（本表的出处是规格书第 24 行那张从厂商官方手册 PDF v12.0
//       解出的网格），把它从这一格删掉会让本表与厂商**当前**键位出现新的偏差。**结论：留原位、仍禁用。**
//
//       **一处更正（更早一轮实测）**：本注释过去写着「HiPER 的 `▸` 只是装饰」。**那句话不成立**，
//       换掉它的是三条量出来的事实，写在各颗键的注释里：`▸` 是这个**换算家族**的名字的一部分
//       （厂商自己的更新日志把 `▸BASE` 写成一个函数名，U+25B8），不是「这是一颗按钮」的记号——
//       带它的 `►DRG` 与不带它的 `FSE`/`MTRX`/`Π`/`d/dx` 在截图上**逐像素同一种画法**
//       （字形核心 (159,161,168)、无胶囊底），而横带里每一颗**真按钮**都戴着胶囊底。
//       **本轮把 `▸` 按这个名字画进键面**：横带那一格与 `DRG` 的 SHIFT 键面都写 `▸DRG`，四个进制胶囊
//       写 `▸BIN`/`▸OCT`/`▸DEC`/`▸HEX`（依据与逐格读数在 `hiper_keypad_number_rows.dart` 行 7 那一段）。
//       这一处键面偏差到此关掉；`CONV`/`CNST` 不带 `▸`，两处都照厂商的写法。
// English: Row 2 — DRG / x⇔E / matrix / summation / product / camera.
//          Band above: ▸DRG (**the SHIFT hint of `DRG`, wired** — on HiPER that cell is
//          `TO_DRG`, "Convert Angular Units", which is **a different command** from the `DRG` key
//          below it in the same row: the former converts **the number currently displayed**, after
//          asking for a source and a target unit, while the latter switches the **mode**. This round
//          builds the former: `openAngleConvert` opens a sheet, and once a source and a target are
//          chosen it replaces the whole expression with `<value> <source unit> to <target unit>`.
//          The sources, the reasons and the refused `grad` are in the long note on the `DRG` key
//          below), FSE (**the SHIFT hint of `x⇔E`, wired** — the previous round made it a tappable
//          `InlineKey` in this band; this round puts it back to a hint per the sources, and the
//          reasoning is on the `x⇔E` key's long note below. On HiPER that dimension has five
//          positions — Normal / Fixed / Scientific / Engineering / Engineering SI — and **this app
//          can only reach three** (Normal / Scientific / Engineering); the two that are missing, and
//          why, are on the file head of `calculator_controller_notation.dart`. Missing is missing.
//          The **base** action of the key under it, `x⇔E`, owns the result **form** dimension; the
//          notation dimension sits on SHIFT — two different things), MTRX (**the matrix key's SHIFT
//          hint, really lit this round** — on HiPER that cell is `MATRIX_MENU`, "Matrix and Vector
//          Menu", and this round builds that menu: `openMatrixMenu` opens a sheet whose four entries
//          each insert a complete call around `matrix(2,2,1,2,3,4)`. The same set of measurements also
//          produced the three names that must be refused, `rank`/`trace`/`echelon`, which are the sheet's
//          grey rows. Sources, reasoning and those three are in the long note on the matrix key below),
//          Π (hint of Σ, now wired), d/dx (hint of ∫dx, **now
//          wired**: under SHIFT the `∫dx` key inserts `diff(x^2,x)`, in the engine's own argument
//          order rather than the manual's — the note on `ins:diff` in `calculator_key_dispatch.dart`
//          says why two slots and not four); the camera key has no hint. **📷 itself stays unlit, on
//          HiPER's own strings**: `command.name.CAMERA` is "Expression recognition";
//          `cameraWindow.policy.info` says the cropped image **is sent to a server** for the
//          third-party Pix2Text model to recognize (`recognitionWindow.pix2text`), and
//          `cameraWindow.proVersion` marks it Pro-only. No such recognizer exists here, and a local
//          OCR would only yield a **plausible but wrong** expression — so it stays disabled (see
//          camera-key-report.md).
//
//          **One measured correction (this round): this cell follows the vendor's *current* default
//          keyboard, not the device screenshot — so the camera key stays where it is.** Both pictures
//          are right; what differs is the **layout version**:
//          1. **The vendor's current main-screen screenshot** (`https://hiperlabs.eu/screenshots.html`
//             → `assets/img/01 calculator.png`, downloaded and read cell by cell this round): row 2's
//             sixth cell is the **camera key** (nothing above it), and `CNST`/`CONV` sit on the `1`/`2`
//             band cells — **cell for cell the same as this table**.
//          2. **The device screenshot on this machine** (the 1440×3200 file cited above) measured a
//             **different layout**: that cell is `CONV` with `CNST` as its second function, and `1`/`2`
//             carry `gcd`/`lcm` above them.
//          3. **The vendor's own strings settle it** (`cameraWindow.cameraRevoked.info` /
//             `cameraWindow.permissionRevoked.text`): "If you want to use the former keyboard layout
//             with the `<key:CONST>` and `<key:CONV>` keys **in their original positions**, … select
//             the **Custom / Version 10 keyboard**." The device screenshot is that Version 10 layout;
//             the current default moved `CONST`/`CONV` onto the `1`/`2` band and gave their old cell to
//             the camera key.
//          So **this `📷` was not added by this app** (the table's provenance is the grid on line 24 of
//          the spec, decoded from the vendor's official manual PDF v12.0), and deleting it from this
//          cell would open a **new** deviation from the vendor's current keypad. **Conclusion: it stays
//          in place, and stays disabled.**
//
//          **One correction (measured a round earlier)**: this note used to say "HiPER's `▸` is
//          decoration". **That sentence does not hold**, and three measured facts replace it (they
//          are written out on the keys themselves): `▸` is part of the **name of the conversion
//          family** (the vendor's own release note spells the name of one of them `▸BASE`, U+25B8) —
//          it is **not** a "this is a button" marker, because a cell carrying it (`►DRG`) and cells
//          that do not (`FSE`/`MTRX`/`Π`/`d/dx`) are drawn **pixel for pixel the same way** (glyph
//          core (159,161,168), no capsule), while every real band **button** wears a capsule.
//          **This round draws the `▸` that name asks for**: the band cell and the `DRG` key's SHIFT
//          face both read `▸DRG`, and the four base pills read `▸BIN`/`▸OCT`/`▸DEC`/`▸HEX` (the evidence
//          and the cell-by-cell readings are in the row-7 note of `hiper_keypad_number_rows.dart`).
//          That key-face deviation is closed; `CONV`/`CNST` carry no `▸` and are written as the vendor
//          writes them.
const KeypadRow _angleAndAggregateRow = KeypadRow(
  keys: <KeypadKey>[
    // 中文：**`DRG` 的 SHIFT 功能是 `TO_DRG`「换算角度单位」——与这颗键的基准不是同一个动作，
    //       本轮真的点亮了**（`openAngleConvert`）。下面按顺序说清楚三件事。
    //
    //       **一、HiPER 上它是 `DRG` 的第二功能，不是一颗独立的键。** 四条来源（上一轮量的，本轮
    //       一条都没动——它们是这一格**挂在这里**的理由，与它能不能点亮无关）：
    //       1. **位置**：1440×3200 原图（`~/Downloads/04_媒体/Screenshot_2026-05-12-13-11-45-205_cz.hipercalc.p.jpg`）
    //          第 2 行横带 `y=1225..1310`，六格字形列中心 `128.0 / 364.5 / 602.0 / 838.0 / 1075.5 /
    //          1311.5`，下方主键 `y=1314..1437` 的列中心 `127.5 / 364.0 / 601.0 / 838.0 / 1074.5 /
    //          1311.0`——**六格对六键，最大差 1.0 px**（列宽 238 px）。`►DRG` 与 `DRG` 差 **0.5 px**。
    //       2. **HiPER 自己给这个位置下了定义**：`quickTour.page.SECOND_FUNCTION.text2` = "The key's
    //          second function is displayed in the label above."；手册 §SHIFT（`hipercalc-manual.txt:517`）
    //          "Symbols of these secondary functions are displayed above their keys."。
    //       3. **画法**：横带里每一颗**真按钮**都戴浅色胶囊底（四个进制胶囊：字块占满整格宽，
    //          亮像素占比 0.21–0.61），每一格**第二功能记号**都是平排文字（亮像素占比 0.02–0.09）。
    //          `►DRG` 是平排文字（0.052），字形核心 **(159,161,168)**——与 `FSE`/`MTRX`/`Π`/`d/dx`/
    //          `CNST`/`hyp`/`sin⁻¹`/`logₓy`/`lim`/`x³`/`n!`/`gcd` **逐个像素同值**，也就是与所有
    //          已被认定的第二功能记号同一种画法。
    //       4. **`▸` 不是「这是一颗按钮」的记号。** 厂商自己的更新日志把这一族的名字写成
    //          **`▸BASE`（U+25B8）函数**（`/tmp/hiper_en.po` 第 8888 行："\\u25B8BASE function
    //          available in custom keyboards"），而同一族在**展开布局**里是 `►DEG`/`►RAD`/`►GRAD`
    //          三颗键——展开布局**没有 SHIFT 键、也没有第二功能**（手册 §SHIFT："Expanded and pocket
    //          layouts do not have SHIFT key and all functions are accessible by 'one click'"）。
    //          所以这个箭头属于**换算命令的名字**，不属于控件的种类。（**`►GRAD` 那颗键的拼法正是
    //          下面面板里灰掉的那一行**：引擎里的 `grad` 不是一个角，见第三条。）
    //
    //       **二、它是什么动作：`TO_DRG`，与 `DRG` 是两个命令。** `command.name.DRG` = "Switch
    //       Angular Units"（手册："Use DRG key (or DEG etc. in expanded layout) to switch among these
    //       units."、"Cycle by DRG until RAD angular unit is checked"），`command.name.TO_DRG` =
    //       "Convert Angular Units"，手册第 678 行把后者说全了：**"►DRG key in compact layout opens
    //       the menu to choose source and target angular units and converts the current display
    //       number."** ——一个换的是**模式**，一个换的是**当前显示的那个数**，并且要选源与目标。
    //       （`x⇔E`/`FSE` 是同一种「相邻两条命令」的形状，上一轮已核。）
    //
    //       **三、本轮点亮它靠的是什么，以及上一轮那两句错话。** 这个动作今天做得了，是因为翻译层
    //       开了一条**只有一个形状**的窄路（`engine_expression.dart` 的 `_angleConversion`：
    //       `<值> <角度单位> to <角度单位>`，两侧都是写出来的单位词），六个角度拼法逐个量过
    //       （表在 `app_unit_catalog.dart` 的 `kAngleUnits` 上）。面板、取舍与 `grad` 那一行灰格的
    //       凭据在 `calculator_page_angle_sheet.dart` 的文件头上。
    //
    //       **上一轮的注释在这里写着「源单位说不出来、反方向（→ 度）不存在」——本轮实测把这两句都
    //       改掉了，两处都留在这里免得下一轮再抄一遍：**
    //       - **「反方向不存在」是假的。** 引擎一直做得了 `90 rad to deg`（实测 = `5156.620156°`）；
    //         过去过不去的是**应用这一侧**（`deg` 不是可插入单位拼法），不是引擎做不到。
    //       - **「`90 to deg` 只是贴了个记号、值一个字节没变」只在 DEG 下成立。** 同一个输入在 RAD 下
    //         实测是 `5156.620156°`（引擎把 90 读成弧度）、在 GRA 下是 `90.00000000 d·°` 那一族。
    //         正确的说法是「**不写源单位时，源单位就是当前角度模式**」——`90 to rad` 在三档下分别是
    //         `1.570796327 rad` / `90 rad` / `1.413716694 rad`。**这正是本应用新面板永远把源单位写
    //         出来的理由**（写全了，答案与角度模式无关：`90 deg to rad` 三档同答）。
    //       - 那份「`degrees`/`radians` 过不去」的读数今天仍然成立（那两个拼法不在应用的单位表里），
    //         但它们**不是引擎读不懂**（实测 `90 degrees to rad` = `1.570796327 rad`），而是本应用
    //         没有给它们拼法——与 `zorkmid` 那一类同一条路。
    //
    //       **基准动作 `angleMode` 一格未动**：那颗键按下去仍然是 DEG↔RAD 的模式开关，不换算任何数，
    //       也不碰表达式（本文件下面那段与 `calculator_key_dispatch.dart` 的 `angleMode` case 都没动）。
    // English: **`DRG`'s SHIFT function is `TO_DRG`, "Convert Angular Units" — not the same action as
    //          this key's base, and really lit this round** (`openAngleConvert`). Three things, in
    //          order.
    //
    //          **1. On HiPER it is `DRG`'s second function, not a key of its own.** Four sources
    //          (measured last round and untouched by this one — they are why the cell is **mounted
    //          here**, which is independent of whether it can light up):
    //          1. **Position**: on the 1440×3200 original cited above, the six glyph column centres
    //             of row 2's band (`y=1225..1310`) are `128.0 / 364.5 / 602.0 / 838.0 / 1075.5 /
    //             1311.5` and those of the keys below (`y=1314..1437`) are `127.5 / 364.0 / 601.0 /
    //             838.0 / 1074.5 / 1311.0` — **six cells over six keys, largest gap 1.0 px** (column
    //             width 238 px). `►DRG` sits **0.5 px** from `DRG`.
    //          2. **HiPER defines what that position means**: `quickTour.page.SECOND_FUNCTION.text2` =
    //             "The key's second function is displayed in the label above."; the manual's SHIFT
    //             section (`hipercalc-manual.txt:517`) "Symbols of these secondary functions are
    //             displayed above their keys."
    //          3. **How it is drawn**: every real band **button** wears a light capsule (the four
    //             base pills: the glyph block spans the whole cell, light-pixel fraction 0.21–0.61),
    //             while every **second-function symbol** is plain text (0.02–0.09). `►DRG` is plain
    //             text (0.052) with glyph core **(159,161,168)** — the same value, pixel for pixel, as
    //             `FSE`/`MTRX`/`Π`/`d/dx`/`CNST`/`hyp`/`sin⁻¹`/`logₓy`/`lim`/`x³`/`n!`/`gcd`, i.e. the
    //             drawing every already-established second-function symbol has.
    //          4. **`▸` is not a "this is a button" marker.** The vendor's own release notes spell the
    //             family's name as the **`▸BASE` (U+25B8) function** (`/tmp/hiper_en.po` line 8888:
    //             "\\u25B8BASE function available in custom keyboards"), and the same family appears
    //             in the **expanded** layout as `►DEG`/`►RAD`/`►GRAD` keys — a layout that **has no
    //             SHIFT key and no second functions at all** (manual §SHIFT: "Expanded and pocket
    //             layouts do not have SHIFT key and all functions are accessible by 'one click'").
    //             The arrow belongs to the conversion commands' **names**, not to the kind of widget.
    //             (**`►GRAD`'s spelling is exactly the grey row in the sheet below**: `grad` is not an
    //             angle in the engine — see item 3.)
    //
    //          **2. What the action is: `TO_DRG`, a second command.** `command.name.DRG` = "Switch
    //          Angular Units" (the manual: "Use DRG key (or DEG etc. in expanded layout) to switch
    //          among these units." and "Cycle by DRG until RAD angular unit is checked"), while
    //          `command.name.TO_DRG` = "Convert Angular Units", which the manual states in full on
    //          line 678: **"►DRG key in compact layout opens the menu to choose source and target
    //          angular units and converts the current display number."** — one switches the **mode**,
    //          the other converts **the number currently displayed**, after asking for a source and a
    //          target. (`x⇔E`/`FSE` are the same "two neighbouring commands" shape, checked last
    //          round.)
    //
    //          **3. What lights it up this round, and the two false sentences that were here.** This
    //          action is reachable today because the translation opened a narrow path with **exactly
    //          one shape** (`_angleConversion` in `engine_expression.dart`:
    //          `<value> <angle unit> to <angle unit>`, both sides written-out unit words), with all six
    //          angle spellings measured (the table is on `kAngleUnits` in `app_unit_catalog.dart`). The
    //          sheet, the trade-offs and the evidence behind the grey `grad` row are in
    //          `calculator_page_angle_sheet.dart`'s file head.
    //
    //          **Last round's note said here that "the source unit cannot be stated" and "the other
    //          direction (→ degrees) does not exist" — this round's measurements replaced both, and
    //          both corrections stay here so the next round does not copy them again:**
    //          - **"the other direction does not exist" is false.** The engine has always done
    //            `90 rad to deg` (measured = `5156.620156°`); what did not exist was the spelling on
    //            **this app's** side (`deg` was not an insertable unit), not the engine's ability.
    //          - **"`90 to deg` merely attaches a symbol and the value does not move a byte" holds under
    //            DEG only.** The same input under RAD measures `5156.620156°` (the engine reads 90 as
    //            radians) and under GRA it is in the `90.00000000 d·°` family. The right sentence is
    //            "**with no source unit written, the source unit is the current angle mode**" —
    //            `90 to rad` is `1.570796327 rad` / `90 rad` / `1.413716694 rad` under the three modes.
    //            **That is exactly why this app's new sheet always writes the source unit out** (written
    //            out, the answer does not depend on the angle mode: `90 deg to rad` answers the same
    //            under all three).
    //          - The old reading that `degrees`/`radians` cannot get through still holds (those two
    //            spellings are not in this app's unit table), but they are **not** cases of the engine
    //            failing to read them (measured: `90 degrees to rad` = `1.570796327 rad`) — this app
    //            simply gives them no spelling, the same road as `zorkmid`.
    //
    //          **The base action `angleMode` has not moved a cell**: that key still switches the
    //          DEG↔RAD mode, converts no number and touches no expression (neither the note below this
    //          one nor the `angleMode` case in `calculator_key_dispatch.dart` was touched).
    KeypadKey(
      base: KeyVariant(label: 'DRG', id: 'angleMode'),
      category: KeyCategory.function,
      // 中文：**SHIFT 变体的键面补上 `▸`**：HiPER 把这个换算家族的名字写成 `▸DRG`（U+25B8，见本行
      //       上面那一段与 `hiper_keypad_number_rows.dart` 四个进制胶囊同一次更正），而本应用这一格
      //       过去写的是不带 `▸` 的 `DRG`——横带那条提示与这颗键的 SHIFT 键面是同一个名字，两处一起补。
      //       **基准 `angleMode` 的键面仍是 `DRG`**：HiPER 两颗键上写的也是不带 `▸` 的 `DRG`。
      // English: **the SHIFT variant's face gains the `▸`**: HiPER spells this conversion family's name
      //          `▸DRG` (U+25B8; see the note above this row and the same correction applied to the
      //          four base pills in `hiper_keypad_number_rows.dart`), while this app used to write a
      //          bare `DRG` here — the band hint and this key's SHIFT face are one and the same name,
      //          so both change together. **The base `angleMode` face stays `DRG`**: HiPER's two keys
      //          are written `DRG` without the arrow as well.
      shift: KeyVariant(label: '▸DRG', id: 'openAngleConvert', enabled: true),
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
    // 中文：**矩阵键的 SHIFT 功能是 `MATRIX_MENU`「矩阵与向量菜单」——与基准的「插入一个矩阵」
    //       不是同一个动作。本轮它从「挂上但禁用」变成**真的点亮**（`openMatrixMenu`）。**
    //       下面按顺序说清楚三件事。
    //
    //       **一、HiPER 上 `MTRX` 是这颗键的第二功能，不是一颗独立的键。** 与 `DRG` 那一格同样
    //       四条来源：位置（本格字形列中心 602.0，下方键面 601.0，差 1.0 px，与其它五格同一条
    //       1:1 对照）、`quickTour.page.SECOND_FUNCTION.text2` 那条通则、画法（平排文字，字形核心
    //       (159,161,168)、无胶囊底，与所有第二功能记号同值）、以及 `▸` 只属于换算命令的名字
    //       （见 `DRG` 那颗键的注释）。**HiPER 上这颗键的键面是矩阵图标 `[▦]`，不是 `MTRX`**——
    //       `MTRX` 是它上方那一格的字。
    //
    //       **二、它是什么动作：`MATRIX_MENU`，与 `MATRIX` 是两个命令。**
    //       `command.name.MATRIX` = "Matrix"，帮助原文："Press the `<key:MATRIX>` key to insert a
    //       matrix into an expression."；`command.name.MATRIX_MENU` = **"Matrix and Vector Menu"**，
    //       手册第 941 行："**Press the MTRX key to open a menu with matrix functions.**"，
    //       `quickTour.page.MATRIX.text2` = "Press the `<key:MATRIX_MENU>` key to see matrix
    //       operations."，厂商更新日志（9.1）另有一条："Matrix inverse added to MTRX menu"。
    //       一个把矩阵插进表达式，一个**打开一个矩阵函数的菜单**——本应用现在打开后者
    //       （面板在 `calculator_page_matrix_sheet.dart`，插入走主屏的 `_pressKey`）。
    //
    //       **三、这一格原来为什么禁用，以及本轮凭什么点亮。** 上一轮禁用是 fail closed，凭据是
    //       一份实测：菜单里会插的那类调用，**应用自己的翻译层**一条也过不去（词表里没有那些名字），
    //       而旧解析器连被包住的那半条也读不了（`ExpressionParser('matrix(2,2,1,2,3,4)')` 抛
    //       `FormatException: matrix needs 1 argument`）——所以从菜单里插出去的每一条都只会得到一条
    //       错误，得不到值。**本轮缺口补上了**：`det`/`transpose`/`inv`/`identity` 进了词表
    //       （名字与意思都在宿主上量过，整张表在 `app_engine_vocabulary_identifiers.dart`），
    //       引擎那一侧本来就不是瓶颈（`det(matrix(2,2,1,2,3,4))` = `−2`、`transpose(…)` =
    //       `[1  3; 2  4]`、`inv(…)` = `[−2  1; 1.5  −0.5]`、`identity(2)` = `[1  0; 0  1]`）。
    //
    //       **同一份实测里也量出了三个必须拒绝的名字**（`rank`/`trace`/`echelon`，成因两种：
    //       `rank` 是引擎里真有的函数却把矩阵原样还回来；`trace`/`echelon` 引擎里根本没有，
    //       于是词被拆成符号、印出来带单位）。它们**不进词表**，在面板里是**灰的**、旁边写着为什么。
    //
    //       **基准动作 `ins:matrix` 一格未动**（仍是 `matrix(2,2,1,2,3,4)`，引擎实测印成
    //       `[1  2; 3  4]`）。**本注释过去写的是「已接上」**，那在当时是一句不成立的话（代码里从来没有
    //       这个变体）；上一轮换成「挂上但禁用」，本轮才真的接上。
    //
    //       **这条拒绝写成了断言**：`test/features/calculator_drg_matrix_band_keys_test.dart` 与
    //       `test/features/calculator_matrix_menu_test.dart` 钉住上面两张表——哪一天引擎把那三个
    //       名字答对了，那些断言会变红。
    // English: **The matrix key's SHIFT function is `MATRIX_MENU`, "Matrix and Vector Menu" — not
    //          the same action as the base "insert a matrix". This round it goes from "mounted but
    //          disabled" to **really lit** (`openMatrixMenu`).** Three things, in order.
    //
    //          **1. On HiPER `MTRX` is this key's second function, not a key of its own.** The same
    //          four sources as the `DRG` cell: position (this cell's glyph column centre is 602.0
    //          against the key face's 601.0, a 1.0 px gap inside the same six-over-six 1:1 mapping),
    //          the `quickTour.page.SECOND_FUNCTION.text2` rule, the drawing (plain text, glyph core
    //          (159,161,168), no capsule — the same values every second-function symbol has), and the
    //          fact that `▸` belongs to the names of conversion commands only (see the `DRG` key's
    //          note). **On HiPER this key's face is the matrix icon `[▦]`, not `MTRX`** — `MTRX` is
    //          the text of the cell above it.
    //
    //          **2. What the action is: `MATRIX_MENU`, a second command.**
    //          `command.name.MATRIX` = "Matrix" (its help: "Press the `<key:MATRIX>` key to insert a
    //          matrix into an expression."), while `command.name.MATRIX_MENU` = **"Matrix and Vector
    //          Menu"**, manual line 941: "**Press the MTRX key to open a menu with matrix
    //          functions.**", `quickTour.page.MATRIX.text2` = "Press the `<key:MATRIX_MENU>` key to
    //          see matrix operations.", and the vendor's release notes (9.1) add "Matrix inverse
    //          added to MTRX menu". One inserts a matrix into the expression; the other **opens a menu
    //          of matrix functions** — and this app now opens the latter (the sheet is in
    //          `calculator_page_matrix_sheet.dart`, and insertion travels the screen's `_pressKey`).
    //
    //          **3. Why this cell was disabled before, and what lights it now.** Last round's disabled
    //          flag was fail closed, on a measurement: not one of the calls such a menu would insert
    //          got through **this app's own translation layer** (the vocabulary had none of those
    //          names), and the legacy parser cannot even read the wrapped half
    //          (`ExpressionParser('matrix(2,2,1,2,3,4)')` throws
    //          `FormatException: matrix needs 1 argument`) — so everything inserted from such a menu
    //          could only come back as an error, never as a value. **This round closes that gap**:
    //          `det`/`transpose`/`inv`/`identity` entered the vocabulary (name and meaning both
    //          measured on the host; the whole table is on `app_engine_vocabulary_identifiers.dart`),
    //          and the engine side was never the bottleneck (`det(matrix(2,2,1,2,3,4))` = `−2`,
    //          `transpose(…)` = `[1  3; 2  4]`, `inv(…)` = `[−2  1; 1.5  −0.5]`, `identity(2)` =
    //          `[1  0; 0  1]`).
    //
    //          **The same set of measurements also produced three names that must be refused**
    //          (`rank`/`trace`/`echelon`, from two causes: `rank` is a real engine function that hands
    //          the matrix straight back, while `trace`/`echelon` are not names the engine has at all,
    //          so the word is taken apart into symbols and prints with units). They **do not enter the
    //          vocabulary** and appear in the sheet **greyed**, with the reason on their own row.
    //
    //          **The base action `ins:matrix` has not moved a cell** (still `matrix(2,2,1,2,3,4)`, which
    //          the engine prints as `[1  2; 3  4]`). **This note used to read "已接上" ("wired")**, a
    //          sentence that was already false when it was written (the variant has never existed in the
    //          code); last round replaced it with "mounted but disabled", and this round really wires it.
    //
    //          **The refusal is written down as assertions**:
    //          `test/features/calculator_drg_matrix_band_keys_test.dart` and
    //          `test/features/calculator_matrix_menu_test.dart` pin both tables above — the day the
    //          engine answers those three names correctly, those assertions go red.
    KeypadKey(
      base: KeyVariant(label: 'MTRX', id: 'ins:matrix'),
      category: KeyCategory.function,
      shift: KeyVariant(label: 'MTRX', id: 'openMatrixMenu'),
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
    // 中文：横带里那一格的字是 **`▸DRG`**，带 U+25B8——`▸` 是这个换算家族名字的一部分（见
    //       `hiper_keypad_number_rows.dart` 四个进制胶囊上那一次更正），不是「这是一颗按钮」的记号。
    //       `CONV`/`CNST` 不带 `▸`（厂商当前截图里那两格逐字如此），本应用也照写。
    // English: the band cell reads **`▸DRG`**, with U+25B8 — the arrow is part of this conversion
    //          family's name (see the correction on the four base pills in
    //          `hiper_keypad_number_rows.dart`), not a "this is a button" marker. `CONV`/`CNST` carry
    //          no `▸` (verbatim from the vendor's current screenshot), and this app writes them so.
    ShiftLabel('▸DRG'),
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
    // 中文：键面照 HiPER 写 **`log₁₀`**（原来写 `log`）。两者**取值相同**——应用的 `log`
    //       本来就是常用对数，词表里 `'log': AppFunction(engineKnowsThisName: false,
    //       engineFunction: 'log10')` 把它映到引擎的 `log10`；而引擎自己的 `log` 是**自然对数**
    //       （宿主实测 `log(1000)` = 6.907755279），所以这一格**不能**少那层映射。
    //       改键面只是因为它显式，与 HiPER 一致，**判据与派发一字未动**。
    // English: the face reads **`log₁₀`** as HiPER writes it (it used to read `log`). The two are
    //          **the same value**: this app's `log` has always been the common logarithm —
    //          `'log': AppFunction(engineKnowsThisName: false, engineFunction: 'log10')` maps it onto
    //          the engine's `log10`, while the engine's own `log` is the **natural** one (host:
    //          `log(1000)` = 6.907755279), so that mapping must not be dropped. Only the face
    //          changed, because it is explicit and matches HiPER; **no judgement or dispatch moved**.
    KeypadKey(
      base: KeyVariant(label: 'log₁₀', id: 'log'),
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
