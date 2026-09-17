import 'package:flutter/foundation.dart';

import 'widgets/math_expression_view.dart';

/// 中文：**结果行的形态**——同一份结果用哪一种写法出现在 `=` 后面。HiPER 的 `x⇔E` 管的就是这一维
///       （它的手册把「结果格式」与「数字记法」分成两维，`x⇔E` 是前者、`FSE` 是后者），
///       `d/c` 则是其中的分数那一格。
///
///       **HiPER 那一颗键是开菜单，不是走一圈**：厂商站点自己的 FAQ 写死了
///       「press the `x⇔E` key. It **opens the Select Result Format menu**」，手册 v12.0 p.10
///       也写「press `x⇔E` and **choose** one of the following formats」。那个菜单的六条菜单项
///       在帮助文本里就是 `rfMenu.*`（`Decimal` / `Expression` / `Fraction` / `Mixed number` /
///       `Degrees, mins, secs` / `Polar coordinates`），标题 `rfMenu.title` = 'Select Result
///       Format'。本应用画成**循环**，是因为这六格里只有三格印得出来（十进制、表达式、分数；
///       带分数、度分秒、极坐标都没有印法）——循环与菜单的差别见 [ResultPresentation.next]。
/// English: **What the result line shows** — which spelling of one result appears after the `=`.
///          This is the dimension HiPER's `x⇔E` owns (its manual splits "result format" from
///          "number notation": `x⇔E` is the first, `FSE` the second), and `d/c` is the fraction
///          cell inside it.
///
///          **HiPER's key opens a menu, it does not walk a cycle**: the vendor's own FAQ fixes it —
///          "press the `x⇔E` key. It **opens the Select Result Format menu**" — and manual v12.0
///          p.10 says "press `x⇔E` and **choose** one of the following formats". That menu's six
///          entries are `rfMenu.*` in the help text (`Decimal` / `Expression` / `Fraction` /
///          `Mixed number` / `Degrees, mins, secs` / `Polar coordinates`), its title
///          `rfMenu.title` = 'Select Result Format'. This app draws a **cycle** instead because
///          only three of the six can be printed here (decimal, expression, fraction; there is no
///          mixed-number, DMS-result or polar printer) — the difference is spelled out in
///          [ResultPresentation.next].
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
  ///       - [dms]：`DMS`。HiPER 的 sexagesimal 格式，`D°M'S` / `x⇔E` 那一格。
  ///       - [decimal]：**不点灯**——HiPER 那一格本来就没有灯（四盏灯对五种格式）。
  ///
  ///       **来源与取法**（本机实测取回，不是记忆）：上面两串取自 HiPER **自己的**帮助文本，
  ///       经项目公开的翻译 API 取回。**v12.0 手册 PDF 本轮也从厂商站点取到了**
  ///       （`https://hiperlabs.eu/assets/raw/hipercalc-manual-12.0.pdf`，55 页，落到 `/tmp`），
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
  ///          - [dms]: `DMS`. HiPER's sexagesimal format, the `D°M'S` / `x⇔E` cell.
  ///          - [decimal]: **lights nothing** — that HiPER cell has no lamp (four lamps, five formats).
  ///
  ///          **Source and how it was fetched** (measured on this machine just now, not remembered):
  ///          the two strings above come from HiPER's **own** help text, through the project's public
  ///          translation API. The **v12.0 manual PDF was also fetched this round from the vendor's
  ///          own site** (`https://hiperlabs.eu/assets/raw/hipercalc-manual-12.0.pdf`, 55 pages,
  ///          landed in `/tmp`) and checked sentence by sentence: its "RESULT FORMAT" section on
  ///          p.7 carries the first string above verbatim, with the same four lamp names.
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
        ResultForm.dms => 'DMS',
        ResultForm.decimal => '',
      };
}

/// 中文：**某一份结果有哪几种形态可显示**，以及每种形态各自画什么。它是这个文件里唯一做判断的地方，
///       结果行与主屏都读它，不各写一份。
///
///       「排不排得出来」不在这里新判：它问的是 `MathExpressionView.typesetsTex`——渲染器自己那一个
///       解析器，也就是既有的共享判据（结果行判精确形式用的就是它）。这里**没有第二条**。
///
///       两条既有的门槛原样沿用，一个字没改：
///       - 与十进制读数**逐字符相同**的写法不算（`2+2` 的 LaTeX 就是 `4`，再来一个 `≈ 4` 只是把
///         同一个数写两遍）；
///       - 排不出来的写法不算（`\num{…}` 这类）。
///
///       分数那一格多一条「与精确写法相同就不算」：`√8` 的分数写法就是 `2\times \sqrt{2}`，与精确
///       写法逐字符相同，多一格没有意义。
/// English: **which forms of a given result can be shown**, and what each one draws. This is the one
///          place in this file that makes a judgement; the result line and the screen both read it
///          rather than each keeping a copy.
///
///          "Does it typeset" is not judged afresh here: it asks `MathExpressionView.typesetsTex` —
///          the renderer's own parser, i.e. the existing shared judgement (the one the result line
///          already uses for the exact form). There is **no second one**.
///
///          Both existing gates are used unchanged, not one character altered:
///          - a spelling **identical to the decimal reading** does not count (the LaTeX for `2+2` is
///            `4`, and another `≈ 4` beside it writes the same number twice);
///          - a spelling that does not typeset does not count (`\num{…}` and friends).
///
///          The fraction cell adds one clause — "identical to the exact spelling does not count":
///          `√8`'s fraction spelling *is* `2\times \sqrt{2}`, character for character the exact one,
///          so a cell for it would mean nothing.
@immutable
class ResultPresentation {
  const ResultPresentation._({
    required this.exactTex,
    required this.fractionTex,
    required this.dmsTex,
    required this.hasDecimal,
    required this.cycle,
  });

  /// 中文：从结果的三形态算出来。四个入参逐字来自 `MathResult`（`displayText` / `displayTex` /
  ///       `fractionTex` / `decimalText`），**没有一个字是猜的**。
  /// English: computed from the result's forms. The four inputs come verbatim from `MathResult`
  ///          (`displayText` / `displayTex` / `fractionTex` / `decimalText`); **not one word is
  ///          guessed**.
  factory ResultPresentation.of({
    required String resultTex,
    required String fractionTex,
    required String resultDecimal,
    required bool naturalDisplay,
    String dmsText = '',
    bool degreesMode = false,
  }) {
    // 中文：后两个入参默认成「没有这一格」——既有调用方（组件测试、老代码）一个字不改就拿到与
    //       以前逐字符相同的那一行。它们的来路是 `MathResult.dmsText` 与当前角度模式。
    // English: the last two default to "no such cell" — existing callers (widget tests, older code)
    //          get the line they had before, character for character, without one edit. They come from
    //          `MathResult.dmsText` and the current angle mode.
    final decimal = resultDecimal.trim();
    final exactTex = _accepted(naturalDisplay, resultTex.trim(), decimal, const <String>[]);
    // 中文：`accepted` 的第三个实参是「已经收下的写法」——分数与精确写法相同就不算（见类注释）。
    // English: the third argument is "spellings already accepted" — a fraction identical to the
    //          exact spelling does not count (see the class note).
    final fraction = _accepted(
      naturalDisplay,
      fractionTex.trim(),
      decimal,
      <String>[exactTex],
    );
    final hasDecimal = decimal.isNotEmpty;

    // 中文：**形态的合并只按「画出来是不是同一行」判**，不按名字判。每种形态的签名是
    //       （要排版的 TeX，有没有 `≈` 那一半），纯文本读数不进签名——它是三种形态共同的降级文本。
    //       于是 `1/3` 的 `decimal` 形态（`0.333333`）与它的 `auto` 形态逐字符相同，被合并掉，
    //       循环里不会出现一次「按下去什么都没变」。
    //
    //       合并是**有意的**：HiPER 的手册列了五种形态，而其中两种（MIXED / POLAR）这台计算器
    //       印不出来（没有带分数印法，也没有极坐标印法），所以循环里只列得出三种；剩下的一种若与
    //       默认那一行画出来一模一样，它就不是一种形态，只是一个名字。
    //       （`DMS` 曾经也在这张「印不出来」的名单上，而那是**实测错误**，见下面 [dmsTex]。）
    // English: **forms are merged by "does it draw the same line", not by name.** Each form's
    //          signature is (the TeX to typeset, whether the `≈` half is drawn); the plain reading
    //          stays out of the signature because all of them degrade to it. So `1/3`'s `decimal`
    //          form (`0.333333`) is character-for-character its `auto` form and gets merged away —
    //          the cycle never contains a press that changes nothing.
    //
    //          The merging is **deliberate**: HiPER's manual lists five forms and two of them
    //          (MIXED / POLAR) this calculator cannot print (there is no mixed-number print and no
    //          polar print), so only three are listable here; and one of those, if it draws exactly
    //          the default line, is not a form but a name.
    //
    //          **`DMS` was on that list of unprintable ones and no longer is** — the previous round
    //          recorded "the engine has no degrees-minutes-seconds conversion"; that is measurably
    //          false (`grep -rni dms` misses it because the library calls it *sexagesimal*:
    //          `BASE_SEXAGESIMAL` in `includes.h:314`, `Number.cc:11254`). See [dmsTex].
    // 中文：**度分秒那一格**（`D°M'S` 那一颗键）。三条门槛，缺一不可，全部走上面那同一套既有判据：
    //       1. 引擎得给过这一串写法，而且它的**形状**得是三个十进制的度/分/秒段——`_dmsTex` 认不出
    //          形状就返回空串，这一格于是不存在。这一条挡的是实测过的三种降级：换算/结构化结果会
    //          把**里面每个数**都印成度分秒（`2°0′0″ × √(2°0′0″)`、`[1°0′0″  2°0′0″; …]`、
    //          `1°0′0″ / 0°0′0″`），超出 double 量程的值则回落成十进制加指数
    //          （`1.148130695274255E602`）——三种在形状这一关全部判不过。
    //       2. **只在 `DEG` 下存在**：这一串写法里的 `°` 是一句断言——「这个数是若干度」。应用自己的
    //          `°` 就是这个意思（`ExpressionParser` 把它改写成 `rad(…)`，即「度 → 弧度」），而 DEG
    //          模式下裸数字**本来就是度**（三角函数的实参按度解释），RAD 模式下则是弧度。把弧度值
    //          写成 `0°47′7.75″` 是一句**假话**——那不是同一个数的另一种写法，是换了一个单位，
    //          正好是 rule 7 要挡的那类改动。所以 RAD 下这一格不存在，那一颗键是**老实的空操作**。
    //       3. 排得出来、且不与十进制读数逐字符相同——既有的两条门槛（`_accepted`），一个字没改。
    //
    //       **它不进 `cycle`**（见 [ResultForm.dms]）：`x⇔E` 的行为因此一个字节都没变。它因此
    //       要在循环之前算好——`_signature` 每个形态的 TeX 都得看得见。
    // English: **the degrees-minutes-seconds cell** (the `D°M'S` key). Three gates, all of them the
    //          same existing judgements used above:
    //          1. the engine has to have handed over this spelling *and* its **shape** has to be three
    //             decimal degree/minute/second sections — `_dmsTex` returns an empty string when it
    //             does not recognise the shape, and the cell then does not exist. This gate stops the
    //             three degradations that were measured: a conversion/structured result prints
    //             **every number inside it** as DMS (`2°0′0″ × √(2°0′0″)`, `[1°0′0″  2°0′0″; …]`,
    //             `1°0′0″ / 0°0′0″`), and a value beyond double range falls back to a decimal with an
    //             exponent (`1.148130695274255E602`) — all three fail the shape check.
    //          2. **it exists only under `DEG`**: the `°` in this spelling is a claim — "this number is
    //             so many degrees". That is what the app's own `°` means (`ExpressionParser` rewrites
    //             it to `rad(…)`, i.e. degrees → radians), and under DEG a bare number **is** degrees
    //             (trig reads its argument in degrees) while under RAD it is radians. Writing a radian
    //             value as `0°47′7.75″` is a **false** statement — not another spelling of the same
    //             number but a change of unit, exactly the kind of change rule 7 exists to stop. So the
    //             cell does not exist under RAD, and that key is an **honest no-op** there.
    //          3. it typesets and is not character-for-character the decimal reading — the two existing
    //             gates (`_accepted`), not one character altered.
    //
    //          **It does not join `cycle`** (see [ResultForm.dms]): `x⇔E`'s behaviour is therefore
    //          unchanged, byte for byte. It is therefore computed before the loop, because every form's
    //          TeX has to be visible to `_signature`.
    final dms = _accepted(
      naturalDisplay,
      degreesMode ? _dmsTex(dmsText) : '',
      decimal,
      <String>[exactTex, fraction],
    );

    final autoSignature = _signature(ResultForm.auto, exactTex, fraction, dms, hasDecimal);
    final seen = <(String, bool)>{autoSignature};
    final cycle = <ResultForm>[];
    // 中文：**先按「这一种形态自己画不画得出东西」筛一遍，再按签名去重。** 两步缺一不可：少了第一步，
    //       一种没有 TeX 的形态会带着签名 `('', false)` 混进来（它既不等于默认形态的签名，也不等于
    //       精确形态的），于是 `√8` 会多出一格按下去什么都没变的「分数形态」；少了第二步，两种画出来
    //       一模一样的形态会各占一格（`1/3` 的十进制形态就是这种）。
    // English: **first filter by "can this form draw anything of its own", then de-duplicate by
    //          signature.** Both steps are needed: without the first, a form with no TeX sneaks in
    //          carrying the signature `('', false)` — equal to neither the default form's nor the
    //          exact form's — and `√8` gains a "fraction form" cell that changes nothing when pressed;
    //          without the second, two forms drawing identically each take a cell (`1/3`'s decimal form
    //          is that kind).
    for (final form in <ResultForm>[
      if (exactTex.isNotEmpty) ResultForm.exact,
      if (fraction.isNotEmpty) ResultForm.fraction,
      if (hasDecimal) ResultForm.decimal,
    ]) {
      if (seen.add(_signature(form, exactTex, fraction, dms, hasDecimal))) {
        cycle.add(form);
      }
    }

    return ResultPresentation._(
      exactTex: exactTex,
      fractionTex: fraction,
      dmsTex: dms,
      hasDecimal: hasDecimal,
      cycle: List<ResultForm>.unmodifiable(cycle),
    );
  }

  /// 中文：这一份结果可以排出来的精确写法；空串表示这一次没有。
  /// English: the exact spelling this result can typeset; empty when there is none this time.
  final String exactTex;

  /// 中文：这一份结果可以排出来的**分数**写法；空串表示这一次没有（引擎缺席、`d/c` 那一格没有
  ///       可显示的东西、或分数写法与精确写法相同）。
  /// English: the **fraction** spelling this result can typeset; empty when there is none this time
  ///          (no engine, nothing distinct to show for the `d/c` cell, or a fraction spelling
  ///          identical to the exact one).
  final String fractionTex;

  /// 中文：这一份结果可以排出来的**度分秒**写法（`12^\circ\,34'\,55.92''`）；空串表示这一次没有
  ///       这一格：没有引擎答案、引擎那一串的形状认不出来、不是 `DEG` 模式、或它与十进制读数
  ///       逐字符相同（`_accepted` 里那几条既有门槛）。
  ///
  ///       它由引擎那一串**改写**而来（`_dmsTex`）：**数字一个都不是 Dart 算的**，只在三个十进制
  ///       段之间插上 `^\circ` / `'` / `''` 这三个记号，并把 U+2212 减号换成 ASCII 的 `-`。形状
  ///       认不出来就整格不要——这条路上没有「差不多能排」这一档。
  ///
  ///       注意它与 [fractionTex] 的来路不同：分数那一份来自**精确**结构，这一份来自**近似**结构
  ///       （也就是 [ResultPresentation.hasDecimal] 那一份的同一个结构）。理由见
  ///       `MathResult.dmsText`：精确结构上度分秒会把每个数都印成度分秒。
  /// English: the **DMS** spelling this result can typeset (`12^\circ\,34'\,55.92''`); an empty string
  ///          means there is no such cell this time: no engine answer, an engine string whose shape is
  ///          not recognised, not in `DEG` mode, or a string identical to the decimal reading (the
  ///          existing gates inside `_accepted`).
  ///
  ///          It is **rewritten** from the engine's string (`_dmsTex`): **not one digit is computed in
  ///          Dart** — the three `^\circ` / `'` / `''` marks are inserted between three decimal
  ///          sections and a U+2212 minus becomes an ASCII `-`. An unrecognised shape loses the whole
  ///          cell; there is no "close enough to typeset" step on this path.
  ///
  ///          Note that it is sourced differently from [fractionTex]: the fraction comes from the
  ///          **exact** structure, this one from the **approximated** structure (the same one
  ///          [ResultPresentation.hasDecimal] comes from). The reason is in `MathResult.dmsText`: on
  ///          the exact structure a DMS render turns every number into degrees-minutes-seconds.
  final String dmsTex;

  /// 中文：这一次有没有十进制读数——它就是既有的 `showApproximation` 那条不变式（结果行的 `≈`
  ///       那一半只在有十进制读数时存在）。它在这里被算了一次，结果行读它，而不是各自再判一遍。
  /// English: whether there is a decimal reading this time — the existing `showApproximation`
  ///          invariant (the result line's `≈` half exists only when there is one). It is computed
  ///          once here and read by the result line rather than judged again in each place.
  final bool hasDecimal;

  /// 中文：**除默认形态之外**那些画出来真的不一样的形态，按 `exact → fraction → decimal` 的顺序。
  ///       空表表示这一份结果只有一行可画（例如 `2+2`：精确写法就是那串十进制，没有第二种）。
  /// English: the forms **other than the default** that genuinely draw differently, in the order
  ///          `exact → fraction → decimal`. An empty list means this result has only one line to
  ///          draw (e.g. `2+2`: the exact spelling *is* that decimal, so there is no second one).
  final List<ResultForm> cycle;

  /// 中文：这个结果有没有分数写法——`d/c` 那一颗键据此判断自己有没有事可做。
  /// English: whether this result has a fraction spelling — what the `d/c` key asks before doing
  ///          anything at all.
  bool get hasFraction => fractionTex.isNotEmpty;

  /// 中文：这个结果有没有度分秒写法——`D°M'S` 那一颗键据此判断自己有没有事可做。
  /// English: whether this result has a DMS spelling — what the `D°M'S` key asks before doing
  ///          anything at all.
  bool get hasDms => dmsTex.isNotEmpty;

  /// 中文：**把请求的形态落到这个结果上**。请求的那一种在这个结果上不存在时一律回落到
  ///       [ResultForm.auto]——**这是这条路径的 fail-closed**：换了一个结果之后，上一份结果上选的
  ///       形态不会留下来把新结果的某一段画成空白或画成另一个数，屏幕上永远是这一份结果自己那一行。
  /// English: **resolve a requested form against this result.** A form this result does not have
  ///          always falls back to [ResultForm.auto] — **this is where the path fails closed**:
  ///          after the result changes, a form chosen for the previous one can never survive to draw
  ///          part of the new result blank or draw a different number; the screen always shows a
  ///          line belonging to this result.
  ResultForm resolve(ResultForm requested) {
    if (requested == ResultForm.auto) return ResultForm.auto;
    // 中文：`dms` **不在 `cycle` 里**（它由 `D°M'S` 直接开关，见 [ResultForm.dms]），所以它单独问
    //       一句——判据仍然是**同一个**：这一份结果有没有这一格。别的形态照旧只认 `cycle`。
    // English: `dms` **is not in `cycle`** (the `D°M'S` key switches it directly; see
    //          [ResultForm.dms]), so it is asked about on its own — by the same judgement: does this
    //          result have that cell. Every other form still goes through `cycle` alone.
    if (requested == ResultForm.dms) return hasDms ? requested : ResultForm.auto;
    return cycle.contains(requested) ? requested : ResultForm.auto;
  }

  /// 中文：从 [current] 走到**下一个画出来不一样的形态**，走完一圈回到 [ResultForm.auto]。
  ///       `current` 不在循环里（包括就是 `auto`）时回到循环的第一个。循环为空时恒为 `auto`
  ///       ——这一份结果只有一行可画，那颗键于是是空操作，而不是假装换了点什么。
  ///
  ///       **这一步与 HiPER 的形状不同，是有意的、也是记下来的**：HiPER 那一边 `x⇔E` 打开的是
  ///       「Select Result Format」菜单（六格：十进制 / 表达式 / 分数 / 带分数 / 度分秒 / 极坐标），
  ///       本应用画成循环，因为六格里只有三格印得出来。**没有来源说 HiPER 是循环**，
  ///       所以这里不假称自己是 HiPER 的循环——它是本应用对那一维的一次画法选择。
  /// English: advance from [current] to the **next form that draws differently**, wrapping back to
  ///          [ResultForm.auto]. A `current` outside the cycle (including `auto` itself) goes to the
  ///          cycle's first entry. An empty cycle is always `auto` — this result has one line to
  ///          draw, so that key is a no-op rather than pretending something changed.
  ///
  ///          **This shape differs from HiPER's, deliberately and on the record**: HiPER's `x⇔E`
  ///          opens the "Select Result Format" menu (six cells: decimal / expression / fraction /
  ///          mixed number / DMS / polar), while this app draws a cycle because only three of the
  ///          six can be printed here. **No source says HiPER cycles**, so nothing here claims to be
  ///          HiPER's cycle — it is a drawing decision for that one dimension.
  ResultForm next(ResultForm current) {
    if (cycle.isEmpty) return ResultForm.auto;
    final index = cycle.indexOf(current);
    if (index < 0) return cycle.first;
    return index + 1 < cycle.length ? cycle[index + 1] : ResultForm.auto;
  }

  /// 中文：**标准写法 ⇄ 十进制读数**——`d/c` 那一颗键。标准写法优先取**分数**（`1/3`、`10/4` 的
  ///       `\frac{5}{2}`），这一次没有分数写法时退回引擎的精确写法（`√8` 的 `2\times \sqrt{2}`），
  ///       两者都没有时这颗键是空操作（`2+2`：精确写法就是那串十进制，没有第二种写法）。
  ///
  ///       **「有分数取分数、没分数取表达式」不是本项目的放宽，它就是 HiPER 这一格的定义。**
  ///       HiPER 把这一格叫 `detailGroup.EXPRESSION.title` = **'Result as fraction or
  ///       expression'**（「作为分数**或表达式**的结果」），而手册 v12.0 给这一格举的例子正是
  ///       一个分数——p.11「Expression: `2√3 / 5`」。所以只切分数的版本比 HiPER **窄**，
  ///       而且在 `√8`、`√2`、`π` 这些结果上按下去什么都不发生：一颗看起来坏掉的键。
  ///       （早先这里写的是「Casio 的 `S⇔D` 走的就是这条更宽的路」——**那个类比是错的归因**，
  ///       `d/c` 在 HiPER 上不是 `S⇔D`；宽的那条路 HiPER 自己就有名字，就是上面这一格。）
  ///
  ///       **第二次按回到十进制这一步没有来源**：HiPER 的帮助只说「Pressing fraction keys, when
  ///       a result of calculation is displayed, converts the result to a fraction or mixed number」
  ///       ——方向有了，来回有没有**没说**，手册 p.6 的 FRACTIONS 段只讲输入、一个字都没提结果。
  ///       留成一次开关是为了让这颗键能自己走回来（`x⇔E` 那边也能回到十进制）。
  /// English: **standard spelling ⇄ decimal reading** — the `d/c` key. The standard spelling prefers
  ///          the **fraction** (`1/3`, `10/4`'s `\frac{5}{2}`) and falls back to the engine's exact
  ///          spelling when this result has no fraction (`√8`'s `2\times \sqrt{2}`); with neither,
  ///          the key is a no-op (`2+2`: the exact spelling *is* that decimal, so there is no second
  ///          spelling).
  ///
  ///          **"Fraction when there is one, otherwise the expression" is not this project widening
  ///          the key — it is the definition of HiPER's cell.** HiPER calls this cell
  ///          `detailGroup.EXPRESSION.title` = **'Result as fraction or expression'**, and manual
  ///          v12.0's own example for it is a fraction — p.11 "Expression: `2√3 / 5`". So a
  ///          fractions-only version would be **narrower** than HiPER, and would do nothing at all on
  ///          `√8`, `√2` or `π`: a key that looks broken. (This note used to say "Casio's `S⇔D` takes
  ///          this same wider route" — **that analogy is a misattribution**: `d/c` is not `S⇔D` on
  ///          HiPER, and the wider route has HiPER's own name, the cell above.)
  ///
  ///          **The second press, returning to the decimal, has no source**: HiPER's help says only
  ///          "Pressing fraction keys, when a result of calculation is displayed, converts the result
  ///          to a fraction or mixed number" — the direction is given, the way back is **not stated**,
  ///          and the FRACTIONS section of manual p.6 is about entry only and says nothing about a
  ///          result. It is kept as a toggle so the key can walk itself back (`x⇔E` reaches the
  ///          decimal too).
  /// 中文：**度分秒 ⇄ 默认那一行**——`D°M'S` 那一颗键。它是一次开关而不是循环里的一格：
  ///       按下去换成度分秒写法，再按一次回到默认（与 `d/c` 那颗键同一种手感）。这一份结果**没有**
  ///       度分秒写法时（引擎没答、RAD 模式、形状认不出来、串与读数相同）它是**空操作**——不是
  ///       假装换了点什么，也不是去猜一个。
  ///
  ///       它一次只跨一步，**不经过 `x⇔E` 的循环**：那一维是 `x⇔E` 的，长它一格就动了那颗键的行为。
  /// English: **degrees-minutes-seconds ⇄ the default line** — the `D°M'S` key. It is a toggle rather
  ///          than a cell in the cycle: a press switches to the DMS spelling, a second press returns
  ///          to the default (the same feel as the `d/c` key). When this result has **no** DMS spelling
  ///          (no engine answer, RAD mode, an unrecognised shape, a string equal to the reading) it is
  ///          a **no-op** — it neither pretends something changed nor invents one.
  ///
  ///          It steps one cell and **never goes through `x⇔E`'s cycle**: that dimension belongs to
  ///          `x⇔E`, and lengthening it would move a key that already works.
  ResultForm toggleDms(ResultForm current) {
    if (!hasDms) return current; // 这一次没有这一格：空操作
    return current == ResultForm.dms ? ResultForm.auto : ResultForm.dms;
  }

  ResultForm toggleStandard(ResultForm current) {
    final standard = cycle.contains(ResultForm.fraction)
        ? ResultForm.fraction
        : (cycle.contains(ResultForm.exact) ? ResultForm.exact : null);
    if (standard == null) return current; // 这一次没有第二种写法：空操作
    return current == standard ? ResultForm.auto : standard;
  }

  /// 中文：某一种形态要排版的 TeX；空串表示这一段不排版（画纯文本读数）。默认形态要排的就是**精确
  ///       写法**（它画「精确 + `≈` 十进制」，没有精确写法时整行纯文本），十进制形态则一段都不排。
  /// English: the TeX a form typesets; an empty string means that stretch is not typeset (the plain
  ///          reading is drawn instead). The default form typesets the **exact spelling** (it draws
  ///          "exact + `≈` decimal", and the plain reading throughout when there is none), while the
  ///          decimal form typesets nothing.
  String texFor(ResultForm form) => switch (form) {
        ResultForm.auto || ResultForm.exact => exactTex,
        ResultForm.fraction => fractionTex,
        ResultForm.dms => dmsTex,
        ResultForm.decimal => '',
      };

  /// 中文：某一种形态要不要画 `≈` 那一半。**只有默认形态画**，而它还要满足既有的那条不变式
  ///       （有十进制读数，且左边真的排出了东西）——少了后者就是「同一个数写两遍」。
  /// English: whether a form draws the `≈` half. **Only the default form does**, and it still has to
  ///          satisfy the existing invariant (there is a decimal reading *and* the left side really
  ///          typeset) — without the second, the same number is written twice.
  bool showsApproximation(ResultForm form) =>
      form == ResultForm.auto && hasDecimal && exactTex.isNotEmpty;

  /// 中文：（要排版的 TeX，有没有 `≈`）——两个形态画出来一样就当同一个。见上面合并那一段。
  ///       **每一种形态各自的 TeX 都要参与**：分数形态排的是 [fractionTex]、度分秒形态排的是
  ///       [dmsTex]，都不是空串；写错这一格会让两种形态撞成同一个签名，于是其中一种被悄悄合并掉
  ///       （这个坑踩过一次）。
  ///
  ///       [ResultForm.dms] 进不了 `cycle`，所以这一格今天不会被比到；它仍然写全，因为它是这个
  ///       函数**唯一**的落点约定——留一个 `_` 兜底就等于把「签名必须逐形态写对」这条约定废掉。
  /// English: (the TeX to typeset, whether the `≈` is drawn) — two forms drawing this alike count as
  ///          one. See the merging note above. **Every form's own TeX takes part**: the fraction form
  ///          typesets [fractionTex] and the DMS form [dmsTex], never an empty string; getting this
  ///          cell wrong makes two forms share a signature so one is silently merged away (a pit this
  ///          fell into once).
  ///
  ///          [ResultForm.dms] cannot reach `cycle`, so this cell is not compared today; it is still
  ///          written out because it is this function's one agreed landing place — leaving a `_`
  ///          catch-all would void the very "every form's signature is spelled out" rule.
  static (String, bool) _signature(
    ResultForm form,
    String exactTex,
    String fractionTex,
    String dmsTex,
    bool hasDecimal,
  ) =>
      switch (form) {
        ResultForm.auto => (exactTex, hasDecimal && exactTex.isNotEmpty),
        ResultForm.exact => (exactTex, false),
        ResultForm.fraction => (fractionTex, false),
        ResultForm.dms => (dmsTex, false),
        ResultForm.decimal => (const ('', false)),
      };

  /// 中文：一段 TeX 收不收——三条既有门槛，位置与含义都没变（见类注释）。`already` 是已经收下的
  ///       写法，用来挡「与上一种写法逐字符相同」。四格（精确、分数、度分秒）都走这一个函数，
  ///       **没有第二份判据**。
  ///
  ///       注意 `fraction` 与 `dms` 这两格**不额外要求值相等**：它们与十进制那一份来自同一个
  ///       已求值结构（`printOptions`），值本来就相等；这里判的是**写法**，不是值。
  /// English: whether a piece of TeX is accepted — the three existing gates, unchanged in place or
  ///          meaning (see the class note). `already` holds the spellings already accepted, which is
  ///          what rejects "character-for-character the previous spelling". All four cells (exact,
  ///          fraction, DMS) go through this one function; there is **no second copy** of the test.
  ///
  ///          Note the `fraction` and `dms` cells ask for **no extra value check**: they and the
  ///          decimal half come from one evaluated structure (`printOptions`) and already carry equal
  ///          values; what is judged here is the *spelling*, not the value.
  /// 中文：引擎那串度分秒写法 → 能排版的 TeX。**只搬记号，不动数字**：三个十进制段原样留下，
  ///       `°` 换成 `^\circ`、`′` 换成 `'`、`″` 换成 `''`，段与段之间补一个 `\,`；U+2212 减号换成
  ///       ASCII 的 `-`（与 `QalculateMathEngine` 洗十进制那一份用的是同一条规矩）。
  ///
  ///       **认不出来就整格不要**（返回空串），这是这条路的 fail-closed：引擎那串只要不是「符号 +
  ///       整数度 + 整数分 + 十进制秒」这个形状，就一个字符也不猜。实测要挡的形状有这些（宿主
  ///       `qalc` 5.12.0，与 App 同版本、同选项）：`2°0′0″ × √(2°0′0″)`（精确结构的无理数）、
  ///       `[1°0′0″  2°0′0″; …]`（矩阵）、`1°0′0″ / 0°0′0″`（无穷）、
  ///       `1.148130695274255E602`（超出 double 量程时回落成十进制）。
  ///
  ///       为什么不用引擎的 LaTeX 那一份：同一个数在 `TAG_TYPE_LATEX` 下印成
  ///       `\text{12o34'55.92"}`，度符号是字母 `o`——一段字面文本，正是这个项目说的「排不出来」。
  ///       所以这一份走终端印法（真 `°′″`），TeX 在这里拼。
  /// English: the engine's DMS string → typesettable TeX. **Marks are moved, digits are not touched**:
  ///          the three decimal sections stay as they are, `°` becomes `^\circ`, `′` becomes `'`, `″`
  ///          becomes `''`, a `\,` goes between sections, and a U+2212 minus becomes an ASCII `-` (the
  ///          same rule `QalculateMathEngine` applies while washing the decimal).
  ///
  ///          **An unrecognised shape loses the whole cell** (an empty string is returned), which is
  ///          this path's fail-closed behaviour: unless the engine's string is exactly "sign + integer
  ///          degrees + integer minutes + decimal seconds", not one character is guessed. The shapes
  ///          that has to stop, measured (host `qalc` 5.12.0, the app's version and options):
  ///          `2°0′0″ × √(2°0′0″)` (an irrational on the exact structure), `[1°0′0″  2°0′0″; …]`
  ///          (a matrix), `1°0′0″ / 0°0′0″` (infinity), `1.148130695274254E602` (beyond double range,
  ///          where the engine falls back to a decimal).
  ///
  ///          Why not the engine's LaTeX render: the same number prints as `\text{12o34'55.92"}`
  ///          under `TAG_TYPE_LATEX`, with the letter `o` for a degree sign — a literal text blob,
  ///          exactly what this project calls "cannot typeset". So this one uses the terminal render
  ///          (real `°′″`) and the TeX is assembled here.
  static String _dmsTex(String text) {
    final match = _dmsShape.firstMatch(text.replaceAll('−', '-').trim());
    if (match == null) return '';
    const degree = '^\\circ';
    const prime = "'";
    const doublePrime = "''";
    final sign = match.group(1)!;
    return '$sign${match.group(2)}$degree\\,${match.group(3)}$prime\\,'
        '${match.group(4)}$doublePrime';
  }

  /// 中文：引擎那串度分秒的形状：`[符号]度°分′秒″`，三段都是十进制数（秒可以有小数）。
  ///       `_dmsTex` 唯一的判据，所以它写在一处、注释也写在一处。
  /// English: the shape of the engine's DMS string: `[sign]degrees°minutes′seconds″`, three decimal
  ///          sections (seconds may be fractional). It is `_dmsTex`'s only test, so it is written in
  ///          one place and documented in one place.
  static final RegExp _dmsShape = RegExp(r'^([+-]?)(\d+)°(\d+)′(\d+(?:\.\d+)?)″$');

  static String _accepted(
    bool naturalDisplay,
    String candidate,
    String decimal,
    List<String> already,
  ) {
    if (!naturalDisplay) return '';
    if (candidate.isEmpty) return '';
    if (candidate == decimal) return '';
    if (already.contains(candidate)) return '';
    if (!MathExpressionView.typesetsTex(candidate)) return '';
    return candidate;
  }
}
