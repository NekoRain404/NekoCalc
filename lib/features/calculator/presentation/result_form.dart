import 'package:flutter/foundation.dart';

import 'widgets/math_expression_view.dart';

/// 中文：**结果行的形态**——同一份结果用哪一种写法出现在 `=` 后面。HiPER 的 `x⇔E` 管的就是这一维
///       （它的手册把「结果格式」与「数字记法」分成两维，`x⇔E` 是前者、`FSE` 是后者），
///       `d/c` 则是其中的分数那一格。
/// English: **What the result line shows** — which spelling of one result appears after the `=`.
///          This is the dimension HiPER's `x⇔E` owns (its manual splits "result format" from
///          "number notation": `x⇔E` is the first, `FSE` the second), and `d/c` is the fraction
///          cell inside it.
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

  /// 中文：只要**分数写法**（HiPER 的 `d/c` / `a b/c` 那一格）。
  /// English: the **fraction spelling** alone (HiPER's `d/c` / `a b/c` cell).
  fraction,

  /// 中文：只要十进制读数（HiPER 的 `FIX` / `SCI` 那一侧，也就是没有 `EXPR` 指示器时的默认）。
  /// English: the decimal reading alone (HiPER's `FIX` / `SCI` side — what it shows with no `EXPR`
  ///          indicator lit).
  decimal,
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
  }) {
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
    //       合并是**有意的**：HiPER 的手册列了五种形态，而其中三种（MIXED / DMS / POLAR）这台
    //       计算器印不出来（引擎里没有度分秒换算，也没有极坐标印法），所以这里只列得出三种；剩下
    //       的一种若与默认那一行画出来一模一样，它就不是一种形态，只是一个名字。
    // English: **forms are merged by "does it draw the same line", not by name.** Each form's
    //          signature is (the TeX to typeset, whether the `≈` half is drawn); the plain reading
    //          stays out of the signature because all of them degrade to it. So `1/3`'s `decimal`
    //          form (`0.333333`) is character-for-character its `auto` form and gets merged away —
    //          the cycle never contains a press that changes nothing.
    //
    //          The merging is **deliberate**: HiPER's manual lists five forms and three of them
    //          (MIXED / DMS / POLAR) this calculator cannot print (the engine has no
    //          degrees-minutes-seconds conversion and no polar print), so only three are listable
    //          here; and one of those, if it draws exactly the default line, is not a form but a
    //          name.
    final autoSignature = _signature(ResultForm.auto, exactTex, fraction, hasDecimal);
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
      if (seen.add(_signature(form, exactTex, fraction, hasDecimal))) cycle.add(form);
    }

    return ResultPresentation._(
      exactTex: exactTex,
      fractionTex: fraction,
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
    return cycle.contains(requested) ? requested : ResultForm.auto;
  }

  /// 中文：从 [current] 走到**下一个画出来不一样的形态**，走完一圈回到 [ResultForm.auto]。
  ///       `current` 不在循环里（包括就是 `auto`）时回到循环的第一个。循环为空时恒为 `auto`
  ///       ——这一份结果只有一行可画，那颗键于是是空操作，而不是假装换了点什么。
  /// English: advance from [current] to the **next form that draws differently**, wrapping back to
  ///          [ResultForm.auto]. A `current` outside the cycle (including `auto` itself) goes to the
  ///          cycle's first entry. An empty cycle is always `auto` — this result has one line to
  ///          draw, so that key is a no-op rather than pretending something changed.
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
  ///       为什么不是「只切分数」：分数写法**只对有理数存在**，而 `√8`、`√2`、`π` 这类结果一个都
  ///       没有。只切分数的 `d/c` 在那些结果上按下去什么都不发生——一颗看起来坏掉的键，而它的
  ///       名字与它该做的事并没有矛盾。Casio 的 `S⇔D` 走的就是这条更宽的路：**标准写法**（分数、
  ///       根号、π 都算）⇄ 十进制。分数存在时它就是「分数 ⇄ 十进制」，一字不差。
  /// English: **standard spelling ⇄ decimal reading** — the `d/c` key. The standard spelling prefers
  ///          the **fraction** (`1/3`, `10/4`'s `\frac{5}{2}`) and falls back to the engine's exact
  ///          spelling when this result has no fraction (`√8`'s `2\times \sqrt{2}`); with neither,
  ///          the key is a no-op (`2+2`: the exact spelling *is* that decimal, so there is no second
  ///          spelling).
  ///
  ///          Why not "fractions only": a fraction spelling **exists only for rationals**, and none
  ///          of `√8`, `√2` or `π` has one. A fractions-only `d/c` would do nothing at all on those
  ///          results — a key that looks broken, while its name and its job are not in conflict.
  ///          Casio's `S⇔D` takes this same wider route: **standard form** (fractions, radicals and
  ///          π included) ⇄ decimal. Where a fraction exists it is "fraction ⇄ decimal", to the
  ///          letter.
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
  ///       **三种形态各自的 TeX 都要参与**：分数形态排的是 [fractionTex]，不是空串；写错这一格会
  ///       让分数与十进制两个形态撞成同一个签名，于是其中一种被悄悄合并掉（这个坑踩过一次）。
  /// English: (the TeX to typeset, whether the `≈` is drawn) — two forms drawing this alike count as
  ///          one. See the merging note above. **Each form's own TeX takes part**: the fraction form
  ///          typesets [fractionTex], not an empty string, and getting this cell wrong makes the
  ///          fraction and decimal forms share a signature so one is silently merged away (a pit this
  ///          fell into once).
  static (String, bool) _signature(
    ResultForm form,
    String exactTex,
    String fractionTex,
    bool hasDecimal,
  ) =>
      switch (form) {
        ResultForm.auto => (exactTex, hasDecimal && exactTex.isNotEmpty),
        ResultForm.exact => (exactTex, false),
        ResultForm.fraction => (fractionTex, false),
        ResultForm.decimal => (const ('', false)),
      };

  /// 中文：一段 TeX 收不收——三条既有门槛，位置与含义都没变（见类注释）。`already` 是已经收下的
  ///       写法，用来挡「与上一种写法逐字符相同」。
  ///
  ///       注意 `fraction` 这一格**不额外要求值相等**：两份打印来自同一个结构，值本来就相等
  ///       （见 `printOptions`）；这里判的是**写法**，不是值。
  /// English: whether a piece of TeX is accepted — the three existing gates, unchanged in place or
  ///          meaning (see the class note). `already` holds the spellings already accepted, which is
  ///          what rejects "character-for-character the previous spelling".
  ///
  ///          Note the `fraction` cell asks for **no extra value check**: the two prints come from one
  ///          structure and already carry equal values (see `printOptions`); what is judged here is
  ///          the *spelling*, not the value.
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
