part of 'result_form.dart';

/// 中文：**菜单里那一格今天为什么灰着。** 它是一句关于**本应用**的话，不是关于结果的话——
///       而菜单从前那句「灰掉的那一项是这一份结果画不出来的」把两者当成了一件事，于是引擎没参与
///       求值的时候它是一句假话：那一份结果画得出 `5/2`，只是本应用没有问过引擎。
///
///       - [none]：没有特别的话要说。**两种情形都落在这里**——这一格亮着；或者它灰着而这一份结果
///         本来就没有这一格（`√8` 的分数印法与精确印法逐字符相同就是这一种，`2+2` 只有一种画法
///         也是）。后一种里「这一份结果画不出来的」是**真的**，菜单标题那句管的正是它。
///       - [engineNotAsked]：**这一份结果不是引擎算的**，所以那几种只有引擎印得出来的写法
///         （精确 / 分数 / 带分数 / 度分秒）本应用手上一个都没有。引擎不参与有两条来路：引擎
///         缺席、超时、答不上来（回落旧解析器）；以及 kill switch 拨到 `数学表达式`
///         （`kEngineBackedLiveExpressionDisplay`）——那一条**只管边打边算**，按 `=` 的提交路径
///         照旧问引擎。
///       - [typesettingOff]：**结果行此刻不排任何写法**——`表达式显示` 设成 `数学表达式` 时，
///         `_accepted` 对每一种写法都返回空串（那是这个设置本来的含义）。这一格里就算引擎已经把
///         写法给了（按 `=` 那条路会给），屏幕上也不会排它。
///
///       **两种原因同时成立时取 [typesettingOff]**：`数学表达式` 之下，那几格**不管引擎答没答**
///       都排不出来，所以拨回设置的提示才是对症的那一句（`= ` 那条路会问引擎，却仍然画不出来）。
/// English: **why that cell of the menu is grey today.** It is a sentence about **this app**, not about
///          the result — the menu's old line ("the greyed entry is one this result cannot be drawn in")
///          treated the two as one thing, and so it was false whenever the engine took no part: that
///          result *can* be drawn as `5/2`, the app simply never asked the engine.
///
///          - [none]: nothing special to say. **Both cases land here** — the cell is live; or it is grey
///            while this result genuinely has no such cell (`√8`'s fraction print is character for
///            character its exact one, and `2+2` has a single drawing). In the second case "this result
///            cannot be drawn that way" is **true**, and the menu's subtitle is about exactly that.
///          - [engineNotAsked]: **this result did not come from the engine**, so the spellings only the
///            engine prints (exact / fraction / mixed / DMS) are ones this app never received. There are
///            two routes into the engine not taking part: it is absent, times out or cannot answer (the
///            legacy parser takes over), or the kill switch is set to `数学表达式`
///            (`kEngineBackedLiveExpressionDisplay`) — and that one governs **as-you-type only**: the
///            submit path (`=`) still asks the engine.
///          - [typesettingOff]: **the result line typesets nothing at all right now** — with
///            `表达式显示` set to `数学表达式`, `_accepted` returns an empty string for every spelling
///            (which is what that setting has always meant). Even if the engine has already handed the
///            spelling over (the `=` path will ask it), nothing of it goes on screen.
///
///          **When both hold, [typesettingOff] wins**: under `数学表达式` those cells cannot be drawn
///          no matter what the engine answered, so "turn the setting back" is the sentence that fits
///          (`=` does ask the engine, and they still are not drawn).
enum ResultCellGap {
  /// 中文：这一格亮着，或者这一份结果本来就没有这一格——菜单标题那句说的就是后一种。
  /// English: the cell is live, or this result has no such cell — which is what the menu's subtitle is
  ///          about.
  none,

  /// 中文：这一份结果不是引擎算的，那几格写法只有引擎印得出来。
  /// English: this result did not come from the engine, and only the engine prints those spellings.
  engineNotAsked,

  /// 中文：`表达式显示` 设成了 `数学表达式`——结果行不排任何写法。
  /// English: `表达式显示` is `数学表达式` — the result line typesets nothing.
  typesettingOff,
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
    required this.mixedTex,
    required this.dmsTex,
    required this.hasDecimal,
    required this.cycle,
    required this.naturalDisplay,
    required this.engineTookPart,
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
    String mixedTex = '',
    bool degreesMode = false,
    bool engineTookPart = true,
  }) {
    // 中文：后两个入参默认成「没有这一格」——既有调用方（组件测试、老代码）一个字不改就拿到与
    //       以前逐字符相同的那一行。它们的来路是 `MathResult.dmsText` 与当前角度模式。
    // English: the last two default to "no such cell" — existing callers (widget tests, older code)
    //          get the line they had before, character for character, without one edit. They come from
    //          `MathResult.dmsText` and the current angle mode.
    //
    // 中文：[engineTookPart] 默认 `true`，也就是「这一次引擎答了」——既有调用方因此拿到的
    //       `gapFor` 恒为 [ResultCellGap.none]，与加这个入参之前逐字符相同。它只喂 [gapFor]：
    //       哪几格存在、哪一格的 TeX 是什么，一个字节都不看它（那几格存不存在只由传进来的写法
    //       决定，这里不另立一条判据）。
    // English: [engineTookPart] defaults to `true`, i.e. "the engine answered this time", so existing
    //          callers get [ResultCellGap.none] from `gapFor` — character for character what they had
    //          before this argument existed. It feeds [gapFor] alone: which cells exist and what each
    //          one typesets do not read it at all (those are decided by the spellings handed in; no
    //          second judgement is raised here).
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
    // 中文：**带分数那一格**（HiPER 结果格式菜单里 `Mixed number` 那一项）。它与上面两格走**同一套
    //       门槛**，一个字没改，只是已经收下的写法多了一份（精确、分数）：带分数与分数画出来一样的
    //       结果（`1/3` 两边都是 `\frac{1}{3}`）不多占一格，与「不印同一个数两遍」是同一条规矩。
    //       印不出来（`12345.6789` 那串带 `\num{…}` 的）照样整格不要——与分数那一格同一条 fail-closed。
    // English: **the mixed-number cell** (HiPER's `Mixed number` entry in the result format menu). It
    //          goes through **the same gates**, not one character altered, except that one more
    //          spelling is already accepted (the exact one and the fraction): a result whose mixed
    //          number draws the same as its fraction (`1/3` is `\frac{1}{3}` on both sides) does not
    //          take a second cell, which is the same rule as "do not write one number twice". A print
    //          that does not typeset (the `\num{…}`-carrying `12345.6789`) loses the whole cell just
    //          the same — the fraction cell's own fail-closed behaviour.
    final mixed = _accepted(
      naturalDisplay,
      mixedTex.trim(),
      decimal,
      <String>[exactTex, fraction],
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

    final autoSignature = _signature(ResultForm.auto, exactTex, fraction, mixed, dms, hasDecimal);
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
      if (seen.add(_signature(form, exactTex, fraction, mixed, dms, hasDecimal))) {
        cycle.add(form);
      }
    }

    return ResultPresentation._(
      exactTex: exactTex,
      fractionTex: fraction,
      mixedTex: mixed,
      dmsTex: dms,
      hasDecimal: hasDecimal,
      cycle: List<ResultForm>.unmodifiable(cycle),
      naturalDisplay: naturalDisplay,
      engineTookPart: engineTookPart,
    );
  }

  /// 中文：**结果行排不排写法**——`表达式显示` 那个设置的读法（`数学符号` 才排）。它在这里被留
  ///       下来，是因为 [gapFor] 要说清「这一格排不出来」与「本应用没有这一份写法」的区别，而那
  ///       两句话的分岔正是它。
  /// English: **whether the result line typesets spellings at all** — how the `表达式显示` setting
  ///          reads (`数学符号` is what turns it on). It is kept here because [gapFor] has to tell
  ///          "this cell cannot be typeset" apart from "this app does not have that spelling", and that
  ///          is exactly the fork it decides.
  final bool naturalDisplay;

  /// 中文：**这一份结果是不是引擎算出来的**。调用方从结果自己的形状字段取（
  ///       `CalculatorController.resultCameFromEngine`），不是一个设置：`数学表达式` 之下按 `=`
  ///       提交**照样会问引擎**，所以「设置是数学表达式」并不等于「这一份结果是旧解析器算的」。
  /// English: **whether this result came from the engine.** Callers take it from the result's own
  ///          shape field (`CalculatorController.resultCameFromEngine`), never from a setting: under
  ///          `数学表达式` the submit path (`=`) **still asks the engine**, so "the setting is
  ///          `数学表达式`" is not the same statement as "this result came from the legacy parser".
  final bool engineTookPart;

  /// 中文：这一份结果可以排出来的精确写法；空串表示这一次没有。
  /// English: the exact spelling this result can typeset; empty when there is none this time.
  final String exactTex;

  /// 中文：这一份结果可以排出来的**分数**写法；空串表示这一次没有（引擎缺席、`d/c` 那一格没有
  ///       可显示的东西、或分数写法与精确写法相同）。
  /// English: the **fraction** spelling this result can typeset; empty when there is none this time
  ///          (no engine, nothing distinct to show for the `d/c` cell, or a fraction spelling
  ///          identical to the exact one).
  final String fractionTex;

  /// 中文：这一份结果可以排出来的**带分数**写法（`2 + \frac{1}{2}`）；空串表示这一次没有这一格：
  ///       没有引擎答案、与精确写法或分数写法逐字符相同、与十进制读数相同、或者引擎那一份印出来
  ///       排不出来（`\num{…}`）——四条都是上面那同一套既有门槛。
  ///
  ///       它的来路与 [fractionTex] 是**同一个已求值结构**（精确结构）的两次打印，值严格相等；
  ///       引擎把它印成一个加法，见 `MathResult.mixedTex`。
  /// English: the **mixed-number** spelling this result can typeset (`2 + \frac{1}{2}`); an empty string
  ///          means there is no such cell this time: no engine answer, character-for-character equal to
  ///          the exact or the fraction spelling, equal to the decimal reading, or an engine print that
  ///          does not typeset (`\num{…}`) — all four are the same existing gates as above.
  ///
  ///          It comes from **one evaluated structure** (the exact one), the same as [fractionTex], and
  ///          carries a strictly equal value; the engine prints it as an addition, see
  ///          `MathResult.mixedTex`.
  final String mixedTex;

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

  /// 中文：这个结果有没有带分数写法——结果格式菜单里 `Mixed number` 那一格据此判断自己点不点得动。
  /// English: whether this result has a mixed-number spelling — what the `Mixed number` cell of the
  ///          result format menu asks before it can be pressed at all.
  bool get hasMixed => mixedTex.isNotEmpty;

  /// 中文：**这一份结果有没有这一格**——菜单里每一格点不点得动，以及 `resolve` 的回落判据，都是它。
  ///       一处判据，不是两处（规则 6），所以「菜单上亮着的格」与「按下去真的画得出来的格」不可能
  ///       漂开。
  ///
  ///       逐格的判据就是**那一格自己的写法在不在**：写法在（且排得出来、且不与别的写法重复），
  ///       这一格就存在。[ResultForm.decimal] 那一格问的是 `hasDecimal` ——十进制形态本来就没有
  ///       「排得出来的 TeX」，它就是那一串读数本身，所以它的存在性由「有没有读数」回答。
  ///       [ResultForm.auto] 恒存在：它是这一份结果的默认那一行。
  ///
  ///       **它比 `cycle` 宽，而且宽得有限**：`cycle` 会把「画出来与默认那一行一模一样」的形态合并
  ///       掉，因为它是一条**循环**——循环里放一次「按下去什么都没变」是坏的。菜单不是循环：一格
  ///       画出来与当前那一行相同不是缺陷（HiPER 的菜单六项一律可点，当前那一项再点一次也毫无
  ///       变化）。所以菜单用 `canDraw`。两者不会矛盾：凡 `cycle` 收下的形态，它的写法一定非空
  ///       （循环就是这么建起来的），于是 `canDraw` 也为真——**放宽只朝「少回落」这一个方向走**，
  ///       而 `resolve` 的 fail-closed 性质（画出来永远是这一份结果自己的一行，不会空白、不会
  ///       是另一个数）由 `texFor` 保证：非空写法排得出来，`decimal` 那一格排空串、整行就是读数。
  /// English: **does this result have this cell** — the judgement behind both "may this cell be pressed
  ///          in the menu" and `resolve`'s fallback. One judgement, not two (rule 6), so "a cell lit in
  ///          the menu" and "a cell that really draws something when pressed" cannot drift apart.
  ///
  ///          The test per cell is simply **whether that cell's own spelling is there**: if it is (and
  ///          it typesets, and it is not a duplicate of another spelling), the cell exists.
  ///          [ResultForm.decimal] asks `hasDecimal` — the decimal cell has no "typesettable TeX" at
  ///          all, it *is* that reading, so "is there a reading" answers whether it exists.
  ///          [ResultForm.auto] always exists: it is this result's default line.
  ///
  ///          **It is wider than `cycle`, and only just**: `cycle` merges away a form that draws
  ///          exactly like the default line, because it is a **cycle** — a press that changes nothing
  ///          is bad in one. A menu is not a cycle: a cell drawing the same line as the current one is
  ///          not a defect (HiPER's six menu entries are all pressable, and pressing the current one
  ///          again changes nothing). So the menu uses `canDraw`. The two cannot disagree: every form
  ///          `cycle` takes has a non-empty spelling by construction, so `canDraw` is true for it too —
  ///          **the widening only ever removes fallbacks**, and `resolve`'s fail-closed property (the
  ///          line drawn is always one belonging to this result, never blank and never another number)
  ///          is guaranteed by `texFor`: a non-empty spelling typesets, and the `decimal` cell typesets
  ///          the empty string and leaves the whole line as the reading.
  bool canDraw(ResultForm form) => switch (form) {
        ResultForm.auto => true,
        ResultForm.exact => exactTex.isNotEmpty,
        ResultForm.fraction => fractionTex.isNotEmpty,
        ResultForm.mixed => mixedTex.isNotEmpty,
        ResultForm.dms => hasDms,
        ResultForm.decimal => hasDecimal,
      };

  /// 中文：**这一格今天灰着，是因为什么**——结果格式菜单据此给那一行写一句实话（灰着的那几格
  ///       从前一句话都没有，而菜单标题那句「灰掉的那一项是这一份结果画不出来的」在引擎没参与时
  ///       是假的）。判据只有一条：这一格画不出来（[canDraw]），而且它是**引擎印出来的那四格**
  ///       之一；原因本身见 [ResultCellGap]。
  ///
  ///       **只有那四格有这两个原因**：`默认` 恒存在，`十进制` 那一格画的是那串读数本身、它不靠
  ///       任何印法（它灰着的原因只有一个——这一份结果没有读数，那是一件关于**结果**的事，标题
  ///       那句说的正是它）。所以这两格一律回 [ResultCellGap.none]。
  ///
  ///       **引擎答了、而这一格仍然没有**（`√8` 的分数印法与精确印法逐字符相同、`1/3` 的带分数
  ///       与分数相同、`2+2` 只有一种画法）时也是 [ResultCellGap.none]：那几格里「这一份结果画
  ///       不出来的」是**真话**，不该再给它编一个理由。这一条与 [canDraw] 一样是**一处判据**：
  ///       菜单不自己拼原因，它只问这里。
  /// English: **why this cell is grey today** — the result format menu writes one true sentence from
  ///          it (those grey rows used to say nothing at all, and the menu's subtitle — "the greyed
  ///          entry is one this result cannot be drawn in" — was false whenever the engine took no
  ///          part). There is one test: the cell cannot be drawn ([canDraw]) *and* it is one of **the
  ///          four cells the engine prints**; the reason itself is [ResultCellGap].
  ///
  ///          **Only those four have these two reasons**: `默认` always exists, and the `Decimal` cell
  ///          draws the reading itself and rests on no print at all (the only reason it is grey is that
  ///          this result has no reading — a fact about the **result**, which is what the subtitle is
  ///          about). Those two therefore always answer [ResultCellGap.none].
  ///
  ///          **The engine answered and the cell still is not there** (`√8`'s fraction print is
  ///          character for character its exact one, `1/3`'s mixed number equals its fraction, `2+2`
  ///          has one drawing) also answers [ResultCellGap.none]: "this result cannot be drawn that
  ///          way" is **true** there, and no reason should be invented for it. Like [canDraw] this is
  ///          **one judgement**: the menu does not assemble a reason of its own, it only asks here.
  ResultCellGap gapFor(ResultForm form) {
    if (canDraw(form)) return ResultCellGap.none;
    final enginePrinted = switch (form) {
      ResultForm.exact ||
      ResultForm.fraction ||
      ResultForm.mixed ||
      ResultForm.dms =>
        true,
      ResultForm.auto || ResultForm.decimal => false,
    };
    if (!enginePrinted) return ResultCellGap.none;
    // 中文：**排不排写法**在「引擎没参与」之前问。`数学表达式` 之下那几格不管引擎答没答都排不
    //       出来（按 `=` 提交会问到引擎，屏幕上照样不排），所以那一句才是对症的。
    // English: **whether spellings are typeset at all** is asked before "the engine took no part".
    //          Under `数学表达式` those cells cannot be drawn whatever the engine answered (`=`
    //          submits and does ask it, and they still are not drawn), so that is the sentence that
    //          fits.
    if (!naturalDisplay) return ResultCellGap.typesettingOff;
    if (!engineTookPart) return ResultCellGap.engineNotAsked;
    return ResultCellGap.none;
  }

  /// 中文：**把请求的形态落到这个结果上**。请求的那一种在这个结果上不存在时一律回落到
  ///       [ResultForm.auto]——**这是这条路径的 fail-closed**：换了一个结果之后，上一份结果上选的
  ///       形态不会留下来把新结果的某一段画成空白或画成另一个数，屏幕上永远是这一份结果自己那一行。
  ///
  ///       **判据自本轮起是 [canDraw] 一处**（从前是 `cycle.contains` 加 dms 那句单独的询问）。
  ///       两处判据本来就不该有：菜单要问「这一格点不点得动」，而这个方法要问几乎同一个问题，分成
  ///       两份迟早会漂。放宽的量与为什么不会破坏 fail-closed 见 [canDraw]。
  /// English: **resolve a requested form against this result.** A form this result does not have
  ///          always falls back to [ResultForm.auto] — **this is where the path fails closed**:
  ///          after the result changes, a form chosen for the previous one can never survive to draw
  ///          part of the new result blank or draw a different number; the screen always shows a
  ///          line belonging to this result.
  ///
  ///          **The judgement is [canDraw] alone from this round on** (it used to be `cycle.contains`
  ///          plus a separate question for dms). There should never have been two: the menu asks "may
  ///          this cell be pressed" and this method asks almost the same question, and two copies
  ///          would drift. How much this widens, and why fail-closed survives, is on [canDraw].
  ResultForm resolve(ResultForm requested) =>
      canDraw(requested) ? requested : ResultForm.auto;

  /// 中文：从 [current] 走到**下一个画出来不一样的形态**，走完一圈回到 [ResultForm.auto]。
  ///       `current` 不在循环里（包括就是 `auto`）时回到循环的第一个。循环为空时恒为 `auto`
  ///       ——这一份结果只有一行可画，那颗键于是是空操作，而不是假装换了点什么。
  ///
  ///       **自本轮起没有键调它，而且这是修好的那一处**：从前 `x⇔E` 走的就是它（本应用对那一维
  ///       画成循环，因为六格里当时只有三格印得出来）。厂商自己的 FAQ 写死了那颗键**打开菜单**
  ///       ——"press the `x⇔E` key. It **opens the Select Result Format menu**"，手册 v12.0 p.10
  ///       也写 "press `x⇔E` and **choose** one of the following formats"——所以循环被菜单取代，
  ///       菜单的每一项直接落到 [resolve] 上，不经过这里。
  ///       **留着它不是因为舍不得**：[cycle] 仍是 `d/c` 的判据（[toggleStandard] 读它），而它是
  ///       那个顺序**唯一可执行的那一句**；它的断言钉住的正是「哪几种画法算不同」这条规则，
  ///       删掉它等于把那条规则连同断言一起删掉（本项目的断言只许增不许减）。
  /// English: advance from [current] to the **next form that draws differently**, wrapping back to
  ///          [ResultForm.auto]. A `current` outside the cycle (including `auto` itself) goes to the
  ///          cycle's first entry. An empty cycle is always `auto` — this result has one line to
  ///          draw, so that key is a no-op rather than pretending something changed.
  ///
  ///          **No key calls it from this round on, and that is the fix**: it is what `x⇔E` used to
  ///          walk (this app drew that dimension as a cycle because only three of the six cells could
  ///          be printed then). The vendor's own FAQ settles it — "press the `x⇔E` key. It **opens
  ///          the Select Result Format menu**" — and manual v12.0 p.10 says "press `x⇔E` and
  ///          **choose** one of the following formats". The menu replaced the cycle, and each menu
  ///          entry lands on [resolve] directly, never here.
  ///          **It is kept for a reason, not out of fondness**: [cycle] is still `d/c`'s judgement
  ///          ([toggleStandard] reads it), and this is that order's **only executable statement**; its
  ///          assertions pin exactly the "which drawings count as different" rule, and deleting it
  ///          would delete the rule along with the assertions (assertions here only ever grow).
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
        ResultForm.mixed => mixedTex,
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
    String mixedTex,
    String dmsTex,
    bool hasDecimal,
  ) =>
      switch (form) {
        ResultForm.auto => (exactTex, hasDecimal && exactTex.isNotEmpty),
        ResultForm.exact => (exactTex, false),
        ResultForm.fraction => (fractionTex, false),
        ResultForm.mixed => (mixedTex, false),
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
