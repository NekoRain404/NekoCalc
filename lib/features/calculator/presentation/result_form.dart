import 'package:flutter/foundation.dart';

import 'widgets/math_expression_view.dart';

part 'result_presentation.dart';

/// 中文：**结果行的形态**——同一份结果用哪一种写法出现在 `=` 后面。HiPER 的 `x⇔E` 管的就是这一维
///       （它的手册把「结果格式」与「数字记法」分成两维：`x⇔E` 是前者、`FSE` 是后者），
///       `d/c` 则是其中的分数那一格。**`x⇔E` 打开菜单**（厂商 FAQ："It **opens the Select Result
///       Format menu**"；手册 v12.0 p.10："press `x⇔E` and **choose** one of the following
///       formats"），菜单本身在 `widgets/result_format_sheet.dart`。
///
///       **这个文件只回答一件事：一个形态叫什么、点哪盏灯。** 「这一份结果有哪几种画法、每种画
///       什么」是另一件事、另一个问题，住在同目录的 `result_presentation.dart`（本文件的 part）里。
///       两者分开是因为它们的**变化理由不同**：枚举只在 HiPER 多出一格或灯具改名时动，而
///       `ResultPresentation` 每一次求值都要重算一遍。从前它们在同一个文件里，845 行——越过本项目
///       那条 800 行的硬边界，这条缝就是那时找到的。
/// English: **What the result line shows** — which spelling of one result appears after the `=`. This
///          is the dimension HiPER's `x⇔E` owns (its manual splits "result format" from "number
///          notation": `x⇔E` the first, `FSE` the second), and `d/c` is the fraction cell inside it.
///          **`x⇔E` opens a menu** (vendor FAQ: "It **opens the Select Result Format menu**"; manual
///          v12.0 p.10: "press `x⇔E` and **choose** one of the following formats"); the menu itself is
///          `widgets/result_format_sheet.dart`.
///
///          **This file answers one question only: what a form is called, and which lamp it lights.**
///          "Which forms a given result can be drawn in, and what each draws" is another question and
///          lives in `result_presentation.dart` beside it (a part of this file). They are apart because
///          they change for different reasons: the enum moves only when HiPER gains a cell or renames a
///          lamp, while `ResultPresentation` is recomputed on every evaluation. They used to share one
///          845-line file — over this project's hard 800-line bound, which is where the seam was found.


enum ResultForm {
  /// 中文：默认——今天那一行。有精确形式时是「排版 + `≈` 近似值」，否则是纯十进制读数。
  ///       **它恒为初始态，也恒是回落态**：新结果上来、或当前形态对这个结果不存在时，都回到它。
  /// English: the default — today's line. With an exact form it is "typeset + `≈` approximation",
  ///          otherwise the plain decimal reading. **It is always the initial state and always the
  ///          fallback**: a new result, or a form this result does not have, lands back here.
  auto,

  /// 中文：只要引擎的精确写法（HiPER 的 `EXPR` 指示器）。
  /// English: the engine's exact spelling alone (HiPER's `EXPR` indicator).
  exact,

  /// 中文：只要**分数写法**（HiPER 结果格式系统里 `fraction` 那一格）。
  ///
  ///       **`d/c` 是两条分数命令里的「分数」那一颗，`a b/c`（它的 SHIFT）是另一颗**——它们是
  ///       **两条命令**（`command.name.FRACTION` = 'Fraction'、`command.name.MIXED_NUMBER`
  ///       = 'Mixed Number'），不是一颗键的两个状态。手册 v12.0 p.6 把两个**键帽字形**并排印着，
  ///       一个是 `□/□`（配「用这颗**输入分数**」），一个是 `□ □/□`（配「用这颗**输入带分数**」），
  ///       帮助文本把这两句分别绑在 `<key:FRACTION>` 与 `<key:MIXED_NUMBER>` 上。
  ///       **这是配对推断，不是字面命中**：手册印的是字形，不是 `d/c` / `a b/c` 这几个字母——
  ///       那几个字母是本应用沿用的 Casio 式键名（HiPER 自 10.5 起有「Casio style / Sharp
  ///       style」键名设置，见 `releaseNotes`）。命令表里只有这两条分数命令，配对没有第二种可能。
  ///       所以 `d/c` 既不是 Casio 的 `S⇔D`，也不是「假分数 ⇄ 带分数」的开关。
  /// English: the **fraction spelling** alone (the `fraction` cell of HiPER's result-format system).
  ///
  ///          **`d/c` is the "fraction" one of two fraction commands, and `a b/c` (its SHIFT) is the
  ///          other** — they are **two commands** (`command.name.FRACTION` = 'Fraction',
  ///          `command.name.MIXED_NUMBER` = 'Mixed Number'), not two states of one key. Manual v12.0
  ///          p.6 prints the two **key-cap glyphs** side by side, one `□/□` (with "use this to
  ///          **enter a fraction**") and one `□ □/□` (with "use this to **enter a mixed number**"),
  ///          and the help text binds those two sentences to `<key:FRACTION>` and
  ///          `<key:MIXED_NUMBER>` respectively.
  ///          **This is a pairing inference, not a literal string match**: the manual prints glyphs,
  ///          not the letters `d/c` / `a b/c` — those letters are the Casio-style key titles this app
  ///          borrows (HiPER has had a "Casio style / Sharp style" key-title setting since 10.5; see
  ///          `releaseNotes`). The command table holds exactly these two fraction commands, so the
  ///          pairing has no second candidate.
  ///          So `d/c` is neither Casio's `S⇔D` nor an "improper ⇄ mixed" toggle.
  fraction,

  /// 中文：只要**带分数写法**（HiPER 结果格式菜单里 `Mixed number` 那一格：一个整数部分加一个真
  ///       分数）。**这是本应用与 `d/c` 那颗键无关的一格**：`d/c` 是「分数」（假分数），带分数是另
  ///       一格，`rfMenu.mixedNumber` = 'Mixed number' 与 `rfMenu.fraction` = 'Fraction' 在 HiPER
  ///       的菜单里是两条并列的菜单项。
  ///
  ///       **来源是引擎自己的第三个印法，不是本应用算出来的**：`number_fraction_format` 取
  ///       `FRACTION_COMBINED`（库的注释：'Display as an integer and a fraction (ex. 3 + 1/2)'），
  ///       与 [exact]、[fraction] 是**同一个已求值结构的又一次打印**——`10/4` 印成
  ///       `2 + \frac{1}{2}`、`100/7` 印成 `14 + \frac{2}{7}`（宿主 `qalc` 5.12.0 实测，与本 AAR
  ///       同版本同选项）。所以它与那两格的值严格相等，见 `MathResult.mixedTex`。
  ///
  ///       **引擎把它印成一个加法**（`2 + \frac{1}{2}`），不是 HiPER 那种并排的 `2 1/2`；值一样、
  ///       意思一样，写法不同，这一点记在 `MathResult.mixedTex` 上。
  ///
  ///       **它不点 `MIXED` 以外的灯**：见 [indicator]。
  /// English: the **mixed-number spelling** alone (HiPER's `Mixed number` cell in the result format
  ///          menu: a whole part plus a proper fraction). **It is a cell of its own, unrelated to the
  ///          `d/c` key**: `d/c` is the *fraction* (an improper one) and the mixed number is another
  ///          cell — `rfMenu.mixedNumber` = 'Mixed number' and `rfMenu.fraction` = 'Fraction' are two
  ///          side-by-side entries in HiPER's menu.
  ///
  ///          **The source is the engine's own third print, not arithmetic done here**:
  ///          `number_fraction_format` set to `FRACTION_COMBINED` (the library's note: 'Display as an
  ///          integer and a fraction (ex. 3 + 1/2)') — one more print of **the same evaluated
  ///          structure** as [exact] and [fraction]. `10/4` prints `2 + \frac{1}{2}` and `100/7`
  ///          prints `14 + \frac{2}{7}` (host `qalc` 5.12.0, the version this AAR bundles and the same
  ///          options), so its value is strictly equal to theirs — see `MathResult.mixedTex`.
  ///
  ///          **The engine prints it as an addition** (`2 + \frac{1}{2}`), not as HiPER's juxtaposed
  ///          `2 1/2`: same value, same meaning, different spelling; that is recorded on
  ///          `MathResult.mixedTex`.
  ///
  ///          **It lights `MIXED` and nothing else** — see [indicator].
  mixed,

  /// 中文：只要**度分秒写法**（HiPER 结果格式系统里 `DMS` 那一格：`12°34′55.92″`）。
  ///
  ///       **它不在 [ResultPresentation.cycle] 里，这是本应用的画法选择**——**不是因为 HiPER 那一格
  ///       不在这套结果格式里**，恰恰相反：`rfMenu.dms` = 'Degrees, mins, secs' 正是那个菜单的六格
  ///       之一（见文件头）。本应用把它单独交给 `D°M'S` 那一颗键，是因为这一格在这里**有自己的
  ///       印法也有自己的键**，加进循环会**改掉一颗已经工作的键的行为**（本项目不许做的事）。
  ///       （另一处不再成立的说法：HiPER 内置键盘上那颗 `D°M'S` 在 HiPER 自己是**输入键**
  ///       （`command.name.DMS` = 'Insert Degrees, Mins, Secs'），换结果格式的是 `REDMS`——
  ///       手册 p.7 明说它「不在内置键盘上」。见 `hiper_keypad.dart` 里同一件事的记法。）
  ///       两颗键共用的只有「当前是哪一格」这一个状态（[ResultPresentation.resolve] 一处收口）。
  ///       English: the **degrees-minutes-seconds spelling** alone (HiPER's `DMS` cell in the result
  ///              format system: `12°34′55.92″`).
  ///
  ///              **It is not in [ResultPresentation.cycle], and that is this app's drawing choice**
  ///              — **not because HiPER's cell is outside the result-format system**; the opposite:
  ///              `rfMenu.dms` = 'Degrees, mins, secs' is one of that menu's six entries (see the file
  ///              header). This app hands it to the `D°M'S` key alone because here that cell **has its
  ///              own printer and its own key**, and adding it to the cycle would **change the
  ///              behaviour of a key that already works** (something this project does not do).
  ///              (A second claim that no longer holds: HiPER's built-in `D°M'S` is an **entry** key
  ///              on HiPER itself (`command.name.DMS` = 'Insert Degrees, Mins, Secs'); the one that
  ///              changes the result format is `REDMS`, which manual p.7 says "is not present on
  ///              built-in keyboards". See the same record in `hiper_keypad.dart`.)
  ///              All the two keys share is the single "which cell is current" state, funnelled
  ///              through one place ([ResultPresentation.resolve]).
  dms,

  /// 中文：只要十进制读数（HiPER 的 `FIX` / `SCI` 那一侧，也就是没有 `EXPR` 指示器时的默认）。
  /// English: the decimal reading alone (HiPER's `FIX` / `SCI` side — what it shows with no `EXPR`
  ///          indicator lit).
  decimal;

  /// 中文：**这一格在 HiPER 屏上那盏指示灯的字面**；空串表示这一格不点灯。
  ///
  ///       判据是「**当前画出来的那一格**」（也就是已经 `resolve` 过的结果），不是结果的种类、也
  ///       不是「有没有精确写法」——HiPER 自己的帮助文本把这件事说死了：
  ///
  ///       > Tap on the result or press `<key:CHANGE_EXPR>` key to change the result format to
  ///       > decimal, expression, mixed number, sexagesimal number or polar coordinates.
  ///       > **Selected format is indicated by** `<ind:EXPR>`, `<ind:MIXED>`, `<ind:DMS>` and
  ///       > `<ind:POLAR>` **indicators on the display**.
  ///
  ///       两句都是 `help.numbers.contents`，取得方式见本节末尾。第一句给的是**结果格式**的五种
  ///       取值（`x⇔E` = `CHANGE_EXPR` 换的就是它）；第二句说明点灯的是**选中的格式**，
  ///       而**五种格式只有四盏灯**——`decimal` 那一格不点灯。指示器名只有这四个，一台计算器
  ///       印不出 `POLAR`（本应用没有极坐标印法）就少一盏，而不是拿别的名字顶上。
  ///
  ///       逐格的理由：
  ///       - [auto]：**不点灯**。它是本应用自己那一行（`2√2 ≈ 2.828427`，或没有精确写法时的
  ///         `4`），HiPER 没有这种「精确写法 + `≈` 读数」同行的形态，五种格式里没有一种是它，
  ///         所以任何字面都是假话。`2+2` 的 `4` 尤其——给它点 `EXPR` 正是这个项目不许的那种谎。
  ///       - [exact]：`EXPR`。结果行画的**就是**引擎的精确写法（HiPER 的 expression 格式，
  ///         `resultFormat.info2` 说它「uses fractions, square roots, polar coordinates, etc.」）。
  ///         这一格存在的前提本身就挡住了「`EXPR` 点在一个纯数字上」：与十进制读数逐字符相同的
  ///         写法在 `_accepted` 里已经被丢掉（`2+2` 根本没有这一格）。
  ///       - [fraction]：**不点灯**。HiPER 唯一以分数命名的那盏是 `MIXED`（mixed number），
  ///         而本应用印的是**假分数**——`10/4` 印成 `\frac{5}{2}`，实测记在
  ///         `QalculateOptions.kt:158`，全应用没有任何一处印带分数。把 `\frac{5}{2}` 标成
  ///         `MIXED` 是一句**关于画面上那个东西的假话**，所以宁可沉默。
  ///         （「fraction 与 mixed number 是两格」现在**有据**：`rfMenu` 的六条菜单项
  ///         （`Decimal` / `Expression` / `Fraction` / `Mixed number` / `Degrees, mins, secs` /
  ///         `Polar coordinates`）与手册 v12.0 p.6 的两个键帽字形（分数、带分数）都这么说。但手册
  ///         p.7 的灯仍然只有 `EXPR` `MIXED` `DMS` `POLAR` 四盏，**没有一盏以分数命名**——所以这一格
  ///         不点灯，是来源说它没有灯，而不是来源说不清。）
  ///       - [mixed]：**`MIXED`**。那四盏灯里唯一以分数命名的一盏命名的**就是这一格**
  ///         （`rfMenu.mixedNumber` = 'Mixed number'）。本应用从前**印不出带分数**，所以这盏灯一直
  ///         没有主人——上面 [fraction] 那一条记的正是「宁可沉默」；本轮引擎那一份印法接上之后，
  ///         灯与格才对上：只有真的画出 `2 + \frac{1}{2}` 时才点 `MIXED`。
  ///       - [dms]：`DMS`。HiPER 的 sexagesimal 格式，`D°M'S` / `x⇔E` 那一格。
  ///       - [decimal]：**不点灯**——HiPER 那一格本来就没有灯（四盏灯对五种格式）。
  ///
  ///       **来源与取法**（本机实测取回，不是记忆）：上面两串取自 HiPER **自己的**帮助文本，
  ///       经项目公开的翻译 API 取回。**v12.0 手册 PDF 本轮也从厂商站点取到了**
  ///       （`https://hiperlabs.eu/assets/raw/hipercalc-manual-12.0.pdf`，今天仍可取回；`pdfinfo`
  ///       报 55 页——`file` 对它误报 8 页，别信那一行；`pdftotext -layout` 之后「RESULT FORMAT」
  ///       在第 265 行。当时下载到本机 `/tmp` 的那一份已不存在，**要核就重新取这个 URL**），
  ///       逐句对过：p.7 的「RESULT FORMAT」段与上面第一句同文，四盏灯的名字也相同。
  ///
  ///       ```
  ///       $ curl -sS "https://weblate.a4tune.com/api/units/?q=help.numbers\
  ///       &project=hiper-scientific-calculator&format=json"
  ///       [help.numbers.contents] Selected format is indicated by <ind:EXPR>, <ind:MIXED>,
  ///                               <ind:DMS> and <ind:POLAR> indicators on the display.
  ///       ```
  ///
  ///       同一份文本还确定了**这些灯在哪一行**：`DEG`/`RAD`/`GRAD` 与 `M` 用的是同一个
  ///       `<ind:…>` 家族，且 `help.memory.contents` 把放它们的叫「the top indicator line」——
  ///       也就是本应用的状态行（角度 chip、`M` 徽标、进制读数已经在的那一行），不是另起一行。
  ///       所以本应用把它画在状态行上，与 `DEG`/`M`/`HEX` 同排，而不是给显示区加第二行——加一行会
  ///       动 `calculator_display.dart` 里那份按真实字体度量量出来的高度契约。
  ///
  ///       **它不在这条路上产生任何值**：它只把已经 `resolve` 好的那一格念出名字，不参与求值，
  ///       不进 `MathResult`，也不进控制器（见 `CalculatorDisplay` 的那一格）。
  /// English: **the word HiPER lights for this cell**; an empty string means this cell lights nothing.
  ///
  ///          The judgement is "**which cell is drawn right now**" (i.e. the already-`resolve`d
  ///          form) — not the result's kind, and not "does an exact spelling exist". HiPER's own help
  ///          text settles it:
  ///
  ///          > Tap on the result or press `<key:CHANGE_EXPR>` key to change the result format to
  ///          > decimal, expression, mixed number, sexagesimal number or polar coordinates.
  ///          > **Selected format is indicated by** `<ind:EXPR>`, `<ind:MIXED>`, `<ind:DMS>` and
  ///          > `<ind:POLAR>` **indicators on the display**.
  ///
  ///          Both are `help.numbers.contents` (how they were fetched is at the end of this note).
  ///          The first gives the **result format**'s five values (what `x⇔E` = `CHANGE_EXPR`
  ///          switches); the second says what lights is the **selected format**, and that **five
  ///          formats share four lamps** — the `decimal` cell lights nothing. Those four names are
  ///          the only ones there are: a calculator that cannot print `POLAR` (this app has no polar
  ///          print) has one lamp fewer, not a different name.
  ///
  ///          Cell by cell:
  ///          - [auto]: **lights nothing**. It is this app's own line (`2√2 ≈ 2.828427`, or `4` when
  ///            there is no exact form); HiPER has no such form — an exact spelling and an `≈`
  ///            reading on one line — so none of the five formats is it, and any word would be false.
  ///            `2+2`'s `4` above all: lighting `EXPR` over it is exactly the lie this project bans.
  ///          - [exact]: `EXPR`. The line draws the engine's exact spelling, which *is* HiPER's
  ///            expression format (`resultFormat.info2`: it "uses fractions, square roots, polar
  ///            coordinates, etc."). The cell's own precondition already stops "`EXPR` over a bare
  ///            number": a spelling character-for-character equal to the decimal reading is discarded
  ///            in `_accepted` (`2+2` has no such cell at all).
  ///          - [fraction]: **lights nothing**. HiPER's only fraction-named lamp is `MIXED` (mixed
  ///            number), while this app prints an **improper** fraction — `10/4` prints `\frac{5}{2}`,
  ///            measured in `QalculateOptions.kt:158`; nothing in the app prints a mixed number.
  ///            Labelling `\frac{5}{2}` `MIXED` is a **false sentence about what is on the screen**,
  ///            so silence wins.
  ///            (An older help variant lists the formats as "decimal, **fraction**, mixed number or
  ///            sexagesimal number", naming `<ind:FRAC>` instead of `<ind:EXPR>` and dropping polar.
  ///            That variant is **stale**: `hiper.pot` still carries it beside the current sentence,
  ///            but manual v12.0 p.7 — the vendor's own current text — uses the five-format wording
  ///            and the `EXPR`/`MIXED`/`DMS`/`POLAR` lamps. Either way **not one of the lamps is named
  ///            after a fraction**, so this cell lights nothing — the sources say it has no lamp,
  ///            not that they are unclear.)
  ///          - [mixed]: **`MIXED`**. The one of those four lamps named after a fraction names exactly
  ///            **this cell** (`rfMenu.mixedNumber` = 'Mixed number'). This app used to be **unable to
  ///            print a mixed number**, so that lamp had no owner — which is what the [fraction] note
  ///            above records as "silence wins"; now that the engine's print is wired in, lamp and cell
  ///            finally correspond: `MIXED` lights only when `2 + \frac{1}{2}` is really drawn.
  ///          - [dms]: `DMS`. HiPER's sexagesimal format, the `D°M'S` / `x⇔E` cell.
  ///          - [decimal]: **lights nothing** — that HiPER cell has no lamp (four lamps, five formats).
  ///
  ///          **Source and how it was fetched** (measured on this machine just now, not remembered):
  ///          the two strings above come from HiPER's **own** help text, through the project's public
  ///          translation API. The **v12.0 manual PDF was also fetched this round from the vendor's
  ///          own site** (`https://hiperlabs.eu/assets/raw/hipercalc-manual-12.0.pdf`, still
  ///          fetchable today; `pdfinfo` reports 55 pages where `file` misreports 8, and after
  ///          `pdftotext -layout` "RESULT FORMAT" is at line 265 — the copy downloaded to this
  ///          machine's `/tmp` that round is gone, so **re-fetch the URL to check it**) and checked
  ///          sentence by sentence: its "RESULT FORMAT" section on p.7 carries the first string
  ///          above verbatim, with the same four lamp names.
  ///
  ///          ```
  ///          $ curl -sS "https://weblate.a4tune.com/api/units/?q=help.numbers\
  ///          &project=hiper-scientific-calculator&format=json"
  ///          [help.numbers.contents] Selected format is indicated by <ind:EXPR>, <ind:MIXED>,
  ///                                  <ind:DMS> and <ind:POLAR> indicators on the display.
  ///          ```
  ///
  ///          The same text fixes **which line those lamps live on**: `DEG`/`RAD`/`GRAD` and `M` are
  ///          the same `<ind:…>` family, and `help.memory.contents` calls where they sit "the top
  ///          indicator line" — this app's status row (where the angle chip, the `M` badge and the
  ///          base read-out already are), not a new line. So this app draws it on the status row
  ///          beside `DEG`/`M`/`HEX` rather than adding a second line to the display — a second line
  ///          would move the height contract `calculator_display.dart` measured against real font
  ///          metrics.
  ///
  ///          **It produces no value on this path**: it only speaks the name of a cell already
  ///          resolved, takes no part in evaluation, and enters neither `MathResult` nor the
  ///          controller (see that cell in `CalculatorDisplay`).
  String get indicator => switch (this) {
        ResultForm.auto => '',
        ResultForm.exact => 'EXPR',
        ResultForm.fraction => '',
        ResultForm.mixed => 'MIXED',
        ResultForm.dms => 'DMS',
        ResultForm.decimal => '',
      };
}
