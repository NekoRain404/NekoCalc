part of 'hiper_keypad.dart';

/// 中文：键盘上半个区域里**横带里放了真按钮的那两行**——行 3 与行 5。那条缝为什么在那里、
///       为什么这样切：见 `hiper_keypad_function_rows.dart` 的文件头。行序由那里的
///       `_functionRows` 决定，本文件只提供两行的内容。
///
///       这两行与 HiPER 的差别**不是「还没修」，是记录在案的取舍**：
///       - 行 3 的 `hyp`：HiPER 上它是 `π` 的第二功能，本应用做成可直接点按的修饰键
///         （立项裁定；出处与代价写在行 3 的注释里，也在
///         `docs/superpowers/plans/2026-09-16-hiper-keypad-and-main-screen.md:95`）。
///       - 行 5 的 `STAT`/`a b/c`/`Y`/`HISTORY`/`M+`/`M−`：按设计就是一键入口的横带键，
///         理由逐条写在行 5 的注释里。
///       所以本文件里每一条 `InlineKey` 都得指得出出处；指不出的那个形状（提示被做成按钮）
///       正是最近五轮一直在撤的东西。
///
/// English: the two rows of the keypad's upper region **whose band carries real buttons** —
///          rows 3 and 5. Why the seam is where it is, and why it is cut that way: see the file
///          head of `hiper_keypad_function_rows.dart`. The row order is decided by `_functionRows`
///          there; this file only supplies the two rows' content.
///
///          The difference between these rows and HiPER is **not "not fixed yet" but a recorded
///          trade-off**:
///          - row 3's `hyp`: on HiPER it is `π`'s second function; this app made it a directly
///            tappable modifier key (a decision taken when the keypad was designed — its source and
///            its price are in row 3's own note and in
///            `docs/superpowers/plans/2026-09-16-hiper-keypad-and-main-screen.md:95`).
///          - row 5's `STAT`/`a b/c`/`Y`/`HISTORY`/`M+`/`M−`: by design one-tap band keys, each
///            with its reason spelled out in row 5's own note.
///          So every `InlineKey` in this file has to be able to point at its source; the shape
///          that cannot (a hint turned into a button) is what the last five rounds have been
///          taking back out.

// 中文：行 3——π / sin / cos / tan / i / e。
//       上方标签：hyp（**唯一剩下的可点横带格，见下**）、sin⁻¹/cos⁻¹/tan⁻¹ 三个 SHIFT 提示，
//       以及 **∠ 与 logₓy 两个 SHIFT 提示**——后两格是上一轮从可点的 `InlineKey` 退回提示的，动作
//       分别挂到 `i` 与 `e` 的 `shift` 上（与更早一轮的 `FSE` 同一形状、同一类偏差）。
//       sin/cos/tan 同时带 SHIFT 变体（asin/acos/atan）与 hyp 变体（sinh/cosh/tanh）。
//
//       **`hyp` 按同一条通则本该是 `π` 的第二功能，本轮**没有**改它——有据的留手，不是漏看。**
//       HiPER 那一侧证据齐：`hyp` 量到第 1 列（中心 129.0，列中心 127.5），即 `π` 上方；本项目规格书
//       第 17 行写着 `π`→SHIFT→`hyp`，并把唯一例外点名为四个进制胶囊；计划书第 95 行写着「HiPER 把
//       `hyp` 放在 `π` 的 SHIFT 位上」。**所以它是立项时就写下的一条刻意偏离**，同段给出的理由是
//       「单层修饰机制即可覆盖」，并预先写下了判断有误的代价。不改的实测理由是它已经不是重挂而是
//       修饰态模型的重做：本应用修饰态单值（`KeypadModifier { none, shift, hyp }`），挂上去之后
//       `SHIFT,π` 进得了 hyp，但 `SHIFT,π,SHIFT,π` **仍在 hyp**——同一个手势退不出来，而计划书对它
//       的要求恰是「需再点一次退出」；且横带那颗键一撤，`_isActiveModifier` 就再没有键可亮。两条都要
//       改 `CalculatorPage` 的修饰态状态机，也就是改一颗**已经在工作**的键。**这条理由写成了断言**，
//       见 `test/features/calculator_lim_key_test.dart` 的最后一组。
//
//       **为什么这两格是提示而不是键**（三条来源，都是本轮自己量的）：
//
//       1. **真机截图上它们印在下方那颗键的正上方。** 在
//          `~/Downloads/04_媒体/Screenshot_2026-05-12-13-11-45-205_cz.hipercalc.p.jpg`（1440×3200）上
//          逐像素量列的横向中心：横带第三行 `hyp / sin⁻¹ / cos⁻¹ / tan⁻¹ / ∠ / logₓy` 的中心是
//          `129.0 / 362.0 / 599.5 / 835.5 / 1075.0 / 1316.5`，主键 `π / sin / cos / tan / i / e`
//          的中心是 `127.5 / 364.0 / 601.0 / 838.0 / 1074.5 / 1311.0`——六格六键一一对齐
//          （∠ 与 i 差 0.5 px，logₓy 与 e 差 5.5 px，两者都小于半格宽）。
//       2. **HiPER 给这个位置下了定义**：`quickTour.page.SECOND_FUNCTION.text2` = "The key's second
//          function is displayed in the label above."；手册 v12.0 §SHIFT 第 517–525 行
//          （`https://hiperlabs.eu/assets/raw/hipercalc-manual-12.0.pdf`）"Symbols of these secondary
//          functions are displayed above their keys."。**一个位置只有一种
//          含义**，它不可能既是提示又是独立按钮。
//       3. **厂商 FAQ 把这条规则逐字应用在同一行横带上**（`https://hiperlabs.eu/help.html`，本轮
//          联网核过原文）："To enter a number in polar coordinates, enter the radius, then
//          **press SHIFT and the i key** to insert the angle symbol ∠, and then enter the angle."
//          ——`∠` 就是 `i` 的第二功能，不是横带里独立的键。同一页把 `OTHER` 说成 "the secondary
//          function of the 0 key"，用的是同一套措辞。
//
//       动作本身在 HiPER 的命令表里都真实存在：`command.name.LOGX` = "Base-x Logarithm"
//       （手册第 17 页的例子里它的键面写作 `log` 带一个下标空槽：`log₄(256)` 的按键序列是
//       先按这颗键、再打底 `4`、再打数 `256`），`command.name.POLAR` = "Polar Coordinates"。
//       两条都是**命令**——但命令表里 `FSE`（`x⇔E` 的 SHIFT）与 `CHANGE_EXPR`（`x⇔E` 的基准）
//       同样各占一条，所以「是一条命令」不说明它有没有自己的键；位置由上面三条回答。
//
//       **`∠` 挂上去了但仍是禁用的——这是拒绝，不是没做。** 核实结果是：**引擎读得了 `∠`，
//       应用自己的两个解析器都读不了**。宿主 libqalculate 5.12.0 实测 `5∠45` =
//       `3.535533906 + 3.535533906i`、`1∠90` = `i`、`2∠0` = `2`；而应用这边
//       `ExpressionAstParser` 把 `5∠45` 判成 `ParseErrorNode`（LaTeX 降级成 `\text{5∠45}`），
//       `ExpressionParser` 抛 `FormatException: Unexpected token at 1`，翻译器因此回
//       「不能翻译：解析器读不懂 `5∠45`」并回落旧解析器——旧解析器同样读不懂。
//       也就是说 `∠` 插进表达式之后**得不到任何值，只会得到一条错误**，而表达式行上的
//       `\text{5∠45}` 是本项目认定的可见降级。屏幕上出现错值比报错更糟，所以这一格保持禁用：
//       按 HiPER 的位置挂到 `i` 的 SHIFT 上，但 `enabled: false`——SHIFT 态下这颗键变暗且不响应，
//       正是「这个动作在本应用里到不了」的诚实画法。
//
// English: Row 3 — π / sin / cos / tan / i / e.
//          Band above: `hyp` (**the one tappable band cell left — see below**), the
//          sin⁻¹/cos⁻¹/tan⁻¹ hints, and **the ∠ and logₓy hints** (those two went back to hints the
//          round before this one, their actions moving onto the `shift` of `i` and `e` — the shape
//          `FSE` took a round earlier; one class of deviation). sin/cos/tan carry both a SHIFT
//          variant (asin/acos/atan) and a hyp variant (sinh/cosh/tanh).
//
//          **By that rule `hyp` should be `π`'s second function; this round does not move it — a
//          grounded refusal, not an oversight.** The HiPER side is well evidenced (`hyp` measures to
//          column 1, centre 129.0 against the column centre 127.5; this project's spec writes
//          `π`→SHIFT→`hyp` on line 17 and names the only exception as the four base pills; its plan
//          says on line 95 that HiPER puts `hyp` at `π`'s SHIFT position). **So it is a deliberate
//          deviation written down when the keypad was designed**, whose stated reason was that a
//          single-layer modifier covers it, and which pre-registered the price of being wrong. The
//          measured reason it stays: this app's modifier state is single-valued
//          (`KeypadModifier { none, shift, hyp }`), and with `hyp` on `π`'s `shift`, `SHIFT,π` does
//          enter hyp but `SHIFT,π,SHIFT,π` **stays in hyp** — the same gesture cannot leave it,
//          while the plan requires exactly that ("left by pressing it once more"); and once the band
//          key is gone `_isActiveModifier` has no key left to light. Both fixes mean changing
//          `CalculatorPage`'s modifier state machine — changing a key that **already works**.
//          **That reason is written down as assertions**, in the last group of
//          `test/features/calculator_lim_key_test.dart`.
//
//          **Why these two cells are hints, not keys** (three sources, all measured this round):
//
//          1. **On the device screenshot they are printed directly above the key below them.** On
//             the file cited above (1440×3200), the measured horizontal centres of the row-3 band
//             `hyp / sin⁻¹ / cos⁻¹ / tan⁻¹ / ∠ / logₓy` are
//             `129.0 / 362.0 / 599.5 / 835.5 / 1075.0 / 1316.5` and those of the keys
//             `π / sin / cos / tan / i / e` are `127.5 / 364.0 / 601.0 / 838.0 / 1074.5 / 1311.0` —
//             six cells over six keys, one to one (∠ vs i differ by 0.5 px, logₓy vs e by 5.5 px,
//             both well under half a cell).
//          2. **HiPER defines what that position means**:
//             `quickTour.page.SECOND_FUNCTION.text2` = "The key's second function is displayed in
//             the label above.", and the manual's SHIFT section (`hipercalc-manual.txt:517-525`)
//             "Symbols of these secondary functions are displayed above their keys." **A position
//             has one meaning**; it cannot be both a hint and a standalone button.
//          3. **The vendor FAQ applies that rule verbatim to this very band** (hiperlabs.eu/help.html,
//             re-read online this round): "To enter a number in polar coordinates, enter the radius,
//             then **press SHIFT and the i key** to insert the angle symbol ∠, and then enter the
//             angle." — `∠` is `i`'s second function, not a key of its own. The same page calls
//             `OTHER` "the secondary function of the 0 key", the same wording.
//
//          Both actions really exist in HiPER's command catalogue: `command.name.LOGX` = "Base-x
//          Logarithm" (the manual's page 17 draws its face as `log` with an empty subscript slot:
//          the sequence for `log₄(256)` is that key, then the base `4`, then the number `256`) and
//          `command.name.POLAR` = "Polar Coordinates". Both are **commands** — but so are `FSE`
//          (`x⇔E`'s SHIFT) and `CHANGE_EXPR` (`x⇔E`'s base), so "it is a command" says nothing about
//          whether it has a key of its own; the three sources above answer that.
//
//          **`∠` is mounted but stays disabled — a refusal, not an omission.** What the check found:
//          **the engine can read `∠`; this app's own two parsers cannot.** Host libqalculate 5.12.0
//          measures `5∠45` = `3.535533906 + 3.535533906i`, `1∠90` = `i`, `2∠0` = `2`; on this side
//          `ExpressionAstParser` turns `5∠45` into a `ParseErrorNode` (LaTeX degraded to
//          `\text{5∠45}`), `ExpressionParser` throws `FormatException: Unexpected token at 1`, so the
//          translator answers "cannot translate: the parser cannot read `5∠45`" and falls back to the
//          legacy parser — which cannot read it either. Typing `∠` therefore yields no value at all,
//          only an error, and the `\text{5∠45}` on the expression line is what this project counts as
//          a visible degradation. A wrong value on screen is worse than an error, so this cell stays
//          disabled: mounted where HiPER has it (the SHIFT of `i`) but with `enabled: false`, which
//          makes the key dim and inert under SHIFT — the honest picture of "this action is out of
//          reach in this app".
const KeypadRow _trigonometryRow = KeypadRow(
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
      // 中文：`∠` = `POLAR`，HiPER 上它是 `i` 的第二功能（厂商 FAQ 原话：press SHIFT and the i key
      //       to insert the angle symbol ∠）。**仍然禁用**：引擎读得了它，应用的两个解析器都读不了
      //       （见本行上面那一段），插进表达式只会得到错误、得不到值。基准动作 `ins:i` 一格未动。
      // English: `∠` = `POLAR`, which on HiPER is `i`'s second function (the vendor FAQ's own words:
      //          press SHIFT and the i key to insert the angle symbol ∠). **Still disabled**: the
      //          engine reads it, this app's two parsers do not (see the note above this row), so
      //          typing it can only produce an error, never a value. The base `ins:i` has not moved.
      shift: KeyVariant(label: '∠', id: 'dis:angle', enabled: false),
    ),
    KeypadKey(
      base: KeyVariant(label: 'e', id: 'ins:e'),
      category: KeyCategory.function,
      // 中文：`logₓy` = `LOGX`，HiPER 上它是 `e` 的第二功能（位置与规则见上面那一段）。它插的
      //       `log(8,2)` 逐字节不变——宿主 libqalculate 5.12.0 实测 `log(8,2)` = `3`，即引擎的
      //       `log(数, 底)`：**第二个实参才是底**（`log(2,8)` = `0.3333333333`）。应用自己的解析器
      //       同样给 `3`，LaTeX 印 `\log_{2}(8)`——三者一致，这一次改动一个字都没碰它。
      // English: `logₓy` = `LOGX`, which on HiPER is `e`'s second function (position and rule in the
      //          note above). What it inserts is `log(8,2)`, byte for byte unchanged — host
      //          libqalculate 5.12.0 measures `log(8,2)` = `3`, i.e. the engine's
      //          `log(number, base)`: **the second argument is the base** (`log(2,8)` =
      //          `0.3333333333`). This app's own parser also gives `3` and its LaTeX prints
      //          `\log_{2}(8)` — all three agree, and this round touched none of it.
      shift: KeyVariant(label: 'logₓy', id: 'ins:logxy'),
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
    ShiftLabel('∠'),
    ShiftLabel('logₓy'),
  ],
);

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
const KeypadRow _formatAndMemoryRow = KeypadRow(
  keys: <KeypadKey>[
    // 中文：**`D°M'S` 是一颗输入键：它在光标处插一个度分秒分隔符**——`3` `D°M'S` `30` `D°M'S`
    //       `0` `D°M'S` 按出 `3°30′0″`，值 3.5。插哪一个记号（`°`/`′`/`″`）由
    //       `_sexagesimalSeparatorBefore` 一处判；这一格说的是**这颗键是哪一颗键**。
    //
    //       **厂商原文（手册 v12.0，`DEGREES, MINUTES, SECONDS` 一节，`pdftotext -layout`
    //       第 246–253 行，逐字）：**
    //
    //       > 「If you want to enter a number as degrees, minutes and seconds (a sexagesimal
    //       > number), use `D°M′S` key.」`3 D°M′S 30 D°M′S 0 D°M′S` → **`3.5`**
    //       > 「…key converts the result into degrees, minutes and seconds. **The key is not
    //       > present on built-in keyboards** but you can place it on your own keyboard.」
    //       > `3.5` → `3°30´ 0´´`
    //
    //       **那两句话说的是两颗不同的键，手册把这一节并排写在一起。** 第二句的主语那个记号
    //       `pdftotext` 抄不出来（它是一个按键图标），但同一句自己说了「**内置键盘上没有这一颗**，
    //       要自己摆到自定义键盘上」——所以**内置键盘上这一颗 `D°M'S` 只做第一件事：输入**。
    //       厂商字符串表也把两条命令分得清清楚楚（`command.name.DMS` = "Insert Degrees, Mins,
    //       Secs"、`command.name.REDMS` = "Display as Degrees, Mins, Secs"；完整原文记在上一轮的
    //       `.superpowers/backup/dms-report.md`）。第三件事是 `x⇔E`：结果格式菜单里那一格
    //       `Degrees, mins, secs`（`rfMenu.dms`）。
    //
    //       **所以上一轮把这一格接成「结果的度分秒写法」，做的是 `REDMS` 那颗键的事**——而那道
    //       转换从来不属于内置键盘这一格。本轮把两个角色各归其位：
    //       - **这一格**：输入（厂商的原样，见上）；
    //       - **结果那一半**：**留在 `x⇔E` 的菜单里**（`Degrees, mins, secs` 那一项），一个字节都
    //         没丢。那条路由 `ResultFormatSheet` + `ResultPresentation` 接到结果行上，测试钉在
    //         `calculator_result_format_menu_test.dart` 与 `calculator_dms_form_test.dart`。
    //
    //       **上一轮列的三条「不照搬输入那一半」的理由，逐条的下场：**
    //       1. **表达式行排不出 `°`**（`ExpressionAstParser` 整段降级成 `\text{30°}`）——**已修**：
    //          语法树多了一个度分秒字面量节点，TeX 排成 `3^\circ\,30'\,0''`（记号与结果行那一格
    //          同一份）。判据只有一份，写在 `sexagesimal_literal.dart`。
    //       2. **旧解析器算不对中间态**（那时 `12°34` 是 `7.12`）——**已修**：算子没变，变的是
    //          **归一化**按整段字面量读（`12°34` = 12.5666…，`12°34′56″` 不再抛异常）。按到一半的
    //          状态因此都有一个说得通的值，这一条的理由**不再成立**。
    //       3. **`°` 在 DEG 下曾经是活的错值**——两轮前（`cc6ce91`）就修好了，当时已标注为「已
    //          失效」；`30°` 单用今天仍是 DEG 下 30、RAD 下 0.5235987755982988，本轮**一个字节
    //          都没动它**（回归断言在 `expression_parser_test.dart`）。
    //
    //       **值从哪来**：`°` 那条路一直没变——归一化把字面量写成内部名字
    //       `degangle(度+分/60+秒/3600)`，交给应用自己的求值器，所以含 `°` 的表达式**一次都不送去
    //       让引擎猜**，两个角度模式的差异只由 `degangle` 那一支给。**中间态为什么不照参考实现的
    //       读法**（宿主 `qalc` 5.12.0 实测 `3°30` = `90°`、`3°30′0` = `0°`）写在
    //       `sexagesimal_literal.dart` 的文件头上——那是本轮**唯一**一处故意偏离参考实现的读法。
    // English: **`D°M'S` is an entry key: it inserts one sexagesimal separator at the caret** —
    //          `3` `D°M'S` `30` `D°M'S` `0` `D°M'S` builds `3°30′0″`, value 3.5. Which mark goes in
    //          (`°`/`′`/`″`) is judged in one place, `_sexagesimalSeparatorBefore`; what this cell
    //          documents is **which key this is**.
    //
    //          **The vendor lines** (manual v12.0, `DEGREES, MINUTES, SECONDS`, `pdftotext -layout`
    //          lines 246–253) are quoted verbatim above the Chinese note: the first names the `D°M′S`
    //          key and shows **entry** (`3 D°M′S 30 D°M′S 0 D°M′S` → `3.5`); the second is about a key
    //          whose own sentence says it is **not on built-in keyboards** (result conversion;
    //          `3.5` → `3°30´ 0´´`).
    //
    //          **Those two sentences name two different keys; the manual prints them side by side.**
    //          The mark that is the subject of the second one cannot be extracted by `pdftotext` (it
    //          is a key icon), but that sentence says it itself: **it is not on built-in keyboards;
    //          you place it on your own.** So the `D°M'S` cell on the built-in keypad does **the first
    //          thing only: entry**. The vendor's string table splits the two commands cleanly as well
    //          (`command.name.DMS` = "Insert Degrees, Mins, Secs", `command.name.REDMS` = "Display as
    //          Degrees, Mins, Secs"; the full text is recorded in last round's
    //          `.superpowers/backup/dms-report.md`). The third thing is `x⇔E`: the result format
    //          menu's `Degrees, mins, secs` cell (`rfMenu.dms`).
    //
    //          **So last round's wiring of this cell as "the result's DMS spelling" was doing the
    //          `REDMS` key's job** — a conversion that never belonged to this built-in cell. This
    //          round gives each role its own place: **this cell enters** (the vendor's own role) and
    //          **the result half stays in the `x⇔E` menu** (`Degrees, mins, secs`), with nothing
    //          lost — that road runs `ResultFormatSheet` + `ResultPresentation` into the result line,
    //          pinned by `calculator_result_format_menu_test.dart` and `calculator_dms_form_test.dart`.
    //
    //          **What became of last round's three reasons for not copying the entry half:**
    //          1. **the expression line could not typeset `°`** (`ExpressionAstParser` degraded the
    //             whole string to `\text{30°}`) — **fixed**: the syntax tree has a DMS literal node
    //             and the TeX is `3^\circ\,30'\,0''` (the marks the result line's cell uses, one copy
    //             of them). The judgement has one copy too, in `sexagesimal_literal.dart`.
    //          2. **the legacy parser misread the intermediate states** (`12°34` was `7.12`) —
    //             **fixed**: the evaluator did not change, **normalisation** did; it now reads the
    //             whole literal (`12°34` = 12.5666…, `12°34′56″` no longer throws). Every half-typed
    //             state therefore has a defensible value, so this reason **no longer holds**.
    //          3. **`°` used to be a live wrong value under DEG** — fixed two rounds earlier
    //             (`cc6ce91`) and already marked lapsed then. `30°` alone is still 30 under DEG and
    //             0.5235987755982988 under RAD, and **this round does not move a byte of it** (the
    //             regression assertions are in `expression_parser_test.dart`).
    //
    //          **Where the value comes from**: the `°` road is unchanged — normalisation writes the
    //          literal as the internal name `degangle(degrees+minutes/60+seconds/3600)` and hands it
    //          to this app's own evaluator, so an expression holding `°` is **never sent to the engine
    //          to guess at**, and the two angle modes differ only through `degangle`'s arm. **Why the
    //          intermediate states cannot follow the reference** (host `qalc` 5.12.0 measures `3°30`
    //          = `90°` and `3°30′0` = `0°`) is on `sexagesimal_literal.dart`'s header — the one place
    //          this round **deliberately** reads differently from the reference.
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
);
