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
    //       2. **旧解析器算不对中间态**：`12°34` 今天是 `7.12`（`degangle(12)*34` 的隐式乘法），
    //          `12°34′56″` 直接 FormatException——按出来的每一串都会先经过这些中间态。
    //       3. **（本条已失效，原样留着记录）`°` 在 DEG 下曾经是活的错值**：`sin 30°` 在 RAD 下
    //          0.5、在 DEG 下 0.009138——解析器把它改写成 `rad(30)`，而 DEG 的三角函数再把实参乘
    //          一次 π/180。**这一条本轮修好了**：`°` 现在归一化写成内部名字 `degangle(30)`，值按
    //          当前角度单位给（DEG 下 30、RAD 下 0.5235987755982988），两种模式下 `sin(30°)` 都是
    //          0.5（设备 `d87f1aa3` 实测，参考 `qalc` 5.12.0 两个角度模式都是 0.5）。
    //          它因此**不再是**这颗键不做的理由；上面两条仍然是，而且都是输入文法本身的问题
    //          （排版与中间态），与 `°` 的含义无关。
    //       要照搬输入那一半，仍得同时给两个地方（语法树、TeX 生成）加一套度分秒字面量语法，
    //       而且按到一半的 `12°34` 必须先有一个说得通的值——*`°` 在 DEG 下是什么意思*这一半本轮
    //       已经定了，但「度分秒字面量」那一半没有。
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
    //             (an implicit multiplication with `degangle(12)`), and `12°34′56″` throws outright —
    //             every string the key can build passes through states like those.
    //          3. **(this one has lapsed and is kept as a record) `°` used to be a live wrong value
    //             under DEG**: `sin 30°` was 0.5 under RAD and 0.009138 under DEG — the parser rewrote
    //             it to `rad(30)` and DEG's trig multiplied the argument by π/180 again. **That was
    //             fixed this round**: `°` now normalises to the internal name `degangle(30)` and takes
    //             its value from the current angle unit (30 under DEG, 0.5235987755982988 under RAD),
    //             so `sin(30°)` is 0.5 in both modes (measured on device `d87f1aa3`; the reference
    //             `qalc` 5.12.0 answers 0.5 in both angle modes). It is therefore **no longer** a
    //             reason for this key not to exist; the two above still are, and both belong to the
    //             entry grammar itself (typesetting and intermediate states) rather than to what `°`
    //             means.
    //          Copying the entry half would still mean adding a degrees-minutes-seconds literal to two
    //          places at once (the syntax tree, the TeX emitter), and a half-typed `12°34` would need
    //          a defensible value first — *what `°` means under DEG* was settled this round, but the
    //          "degrees-minutes-seconds literal" half was not. The result half **can be done correctly
    //          today**: the engine really does print degrees-minutes-seconds (`BASE_SEXAGESIMAL`, see
    //          the note on `printOptions`; the previous round's "the engine has no DMS conversion" is
    //          **measurably wrong** — it is called *sexagesimal*, so `grep -rni dms` was never going
    //          to find it), and it prints **one already evaluated structure**, so the value is digit
    //          for digit the same, in the same shape as `d/c`. **Whoever presses this key presses
    //          HiPER's `DMS` result-format cell** — the only thing HiPER writes DMS on, on screen —
    //          which on HiPER lives on the `REDMS` key a custom keyboard can carry.
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
