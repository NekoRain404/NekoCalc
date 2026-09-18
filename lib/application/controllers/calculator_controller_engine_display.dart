part of 'calculator_controller.dart';

/// 中文：**引擎那一份答案怎么画在屏幕上**——与「选哪一份答案」分家的那一半（`_selectEngineResult`
///       仍在 `calculator_controller_evaluation.dart`）。分家是这一轮做的，理由是那一条硬边界：
///       800 行。这一半原来只有六行（能当数字用就取整、装不下就原样），本轮加上了「一个量」那一条，
///       于是搬出来——**搬的是这一半，不是判据**：哪些结果取整、怎么取，仍然只有一处实现
///       （`quantity_display.dart` 的 [roundedQuantityDisplayText]，与 [formatNumber]）。
///
///       取整只有这一处实现，边打边算与提交路径共用，因此用户在设置里选的小数位数对两条路径含义完全
///       相同：引擎负责算得准，Dart 负责显示成什么样。
///
///       **装不下一个 double 的结果原样显示引擎那一份文本**（`2^2000 ≈ 1.148e+602`、
///       `2^-2000 ≈ 8.7e-603`，还有带单位的 `2^2000 m` → `1.148130695274255E599 km`）：Dart 手里
///       没有可以取整的数（`decimalValue` 为 null），硬要走 [formatNumber] 只能先把 `Infinity` 或 `0`
///       喂进去，而那两个都是假值。取整规则没有被搬到引擎里，只是对超出取整能力的结果不假装能取整。
///       带单位的结果**不属于**这一类——它装得下，只是末尾多一个单位，所以它取整；它的数字部分装不下
///       时（`2^2000 m`）就落回这一条豁免，两条判据是同一个 `decimalValueOf`。
/// English: **how the engine's answer is drawn on screen** — the half that was split off from "which
///          answer is taken" (`_selectEngineResult` still lives in
///          `calculator_controller_evaluation.dart`). The split happened this round for the hard
///          800-line bound. That half used to be six lines (round it when it is usable as a number,
///          show it as it stands when it does not fit); this round added the "a quantity" case, so it
///          moved out — **what moved is the drawing, not the judgement**: which results are rounded
///          and how still lives in exactly one place ([roundedQuantityDisplayText] in
///          `quantity_display.dart`, together with [formatNumber]).
///
///          Rounding has this one implementation, shared by as-you-type and submit, so the digit count
///          the user picked means exactly the same thing on both paths: the engine computes
///          accurately, Dart decides what it looks like.
///
///          **A result that does not fit a double is shown as the engine's own text**
///          (`2^2000 ≈ 1.148e+602`, `2^-2000 ≈ 8.7e-603`, and the unit-carrying `2^2000 m` →
///          `1.148130695274255E599 km`): Dart has no number to round (`decimalValue` is null), and
///          forcing it through [formatNumber] would mean feeding it `Infinity` or `0` — both false.
///          Rounding has not moved into the engine; the code just does not pretend to round what it
///          cannot represent. A unit-carrying result is **not** that case — it fits, it merely ends in
///          a unit, so it is rounded; when its numeric part does not fit (`2^2000 m`) it falls back to
///          this same exemption, both judgements being one `decimalValueOf`.
mixin _CalculatorEngineDisplay on _CalculatorState {
  /// 中文：把引擎的结果变成屏幕上那一份。三条路，顺序不能反：
  ///
  ///       1. **能当数字用**（[MathResult.decimalValue] 非空）→ `formatNumber` 按小数位数取整。与
  ///          迁移引擎之前逐字节一致：取整过的显示文本是画出来的那一份，而**数值本身不动**——
  ///          `decimalText` 里那串未取整的十进制照旧，`Ans`/记忆/继续使用读的是它。
  ///       2. **一个量**（带单位的数字 × 单位）→ [roundedQuantityDisplayText]：数取整、单位原样。
  ///          引擎原文（未取整）留在 [MathResult.quantityText] 里，于是「继续使用」写回表达式的仍是
  ///          16 位那一份——**取整只改写法**，与第 1 条同一条规矩。哪些种类、什么形状、装不装得下，
  ///          四条判据全在那一个函数里，这里不再判一遍。
  ///       3. **其余一切**（装不下 double 的结果、矩阵、复数、符号式、形状认不出来的换算）→ 原样
  ///          返回引擎那一份。
  ///
  ///       三条路共用一处重建（[_shown]）：那些「同一次求值的另外几半」——分数 / 带分数 / 度分秒
  ///       写法与 `resultKind`——**一份都不许在重建时丢掉**，理由写在 [_shown] 上。
  /// English: Turns the engine's answer into the one on screen. Three routes, and the order matters:
  ///
  ///          1. **Usable as a number** ([MathResult.decimalValue] is non-null) → rounded by
  ///             `formatNumber` at the decimal-places setting. Byte-for-byte what it was before the
  ///             engine was wired in: the rounded text is what gets drawn while the **value does not
  ///             move** — the unrounded decimal stays in `decimalText`, which is what `Ans`, the
  ///             memory register and "continue with result" read.
  ///          2. **A quantity** (a number times a unit) → [roundedQuantityDisplayText]: the number is
  ///             rounded, the unit copied. The engine's own (unrounded) text stays in
  ///             [MathResult.quantityText], so "continue with result" still writes the 16-digit one
  ///             back — **rounding changes the writing only**, the same rule as route 1. Which kinds,
  ///             which shape, whether it fits: all four judgements live in that one function and are
  ///             not repeated here.
  ///          3. **Everything else** (a result beyond a double, a matrix, a complex number, a symbolic
  ///             form, a conversion whose shape is not recognised) → the engine's own text, as it
  ///             stands.
  ///
  ///          All three share one rebuild ([_shown]): the "other halves of this same evaluation" —
  ///          the fraction / mixed / DMS spellings and `resultKind` — **must not be dropped by it**,
  ///          and the reasons are on [_shown].
  MathResult _engineMathResult(MathResult engineResult) {
    final value = engineResult.decimalValue;
    if (value != null) {
      return _shown(
        engineResult,
        formatNumber(
          value,
          precision: _settings.precision,
          groupThousands: _settings.groupThousands,
        ),
      );
    }
    final quantity = roundedQuantityDisplayText(
      engineResult,
      precision: _settings.precision,
      groupThousands: _settings.groupThousands,
    );
    if (quantity == null) return engineResult;
    return _shown(engineResult, quantity, quantityText: engineResult.displayText);
  }

  /// 中文：**重建这一份结果，只换画出来的那一段文本**——三条路唯一的构造点。它是「同一次求值」
  ///       整体搬家时的那一处：谁漏了一格，谁就在引擎已经答出来的结果上留下一格空操作或一盏永远
  ///       灰着的灯，而那个退化没有任何理由。
  ///
  ///       - **三种「写法」都跟着走**（分数 / 带分数 / 度分秒）：它们是同一次求值的另外几半，各自是
  ///         同一个已求值结构的又一次打印。（`mixedTex` 漏过一次，被 `10/4` 逮到。）
  ///       - **`resultKind` 必须跟着走**：丢了它，重建出来的结果会带上 `notFromEngine`——而那个值在
  ///         [MathResult.isDisplayable] 里是**放行**的一支，于是「不是来自引擎」成了一句假话，判据
  ///         也跟着变宽。今天没有消费者读重建之后那一份的 `isDisplayable`，但那是**碰巧**，不是设计。
  ///       - **`decimalText` 跟着走**：它是数值消费者唯一允许解析的那一份，重画一次不该动它。
  ///       - [quantityText] 只有第 2 条（一个量）会给：它记的是**取整前**的引擎原文，好让「继续使用」
  ///         写回那个位数更多的数。给不出来时是空串，与别处的「没有这一份」同义。
  /// English: **rebuilds this result, replacing only the text that gets drawn** — the three routes'
  ///          single construction point. It is where "one evaluation" travels as a whole: drop a cell
  ///          here and that cell becomes a no-op or a permanently grey lamp on a result the engine did
  ///          answer, a degradation with no reason behind it.
  ///
  ///          - **All three spellings travel** (fraction / mixed / DMS): they are this same
  ///            evaluation's other halves, each an extra print of one evaluated structure.
  ///            (`mixedTex` was dropped here once; `10/4` caught it.)
  ///          - **`resultKind` has to travel**: dropping it leaves the rebuilt result carrying
  ///            `notFromEngine` — which [MathResult.isDisplayable] treats as **displayable** — so "not
  ///            from the engine" would be a lie and the judgement would widen with it. Nothing reads
  ///            the rebuilt copy's `isDisplayable` today, but that is a coincidence, not a design.
  ///          - **`decimalText` travels**: it is the only field numeric consumers may parse, and
  ///            redrawing must not touch it.
  ///          - [quantityText] is given by route 2 alone: it holds the **unrounded** engine text so
  ///            that "continue with result" writes back the longer number. It is an empty string when
  ///            there is no such text, which means the same thing it means everywhere else.
  MathResult _shown(
    MathResult engineResult,
    String displayText, {
    String quantityText = '',
  }) {
    return MathResult(
      displayText: displayText,
      displayTex: engineResult.displayTex,
      fractionTex: engineResult.fractionTex,
      mixedTex: engineResult.mixedTex,
      dmsText: engineResult.dmsText,
      decimalText: engineResult.decimalText,
      quantityText: quantityText,
      resultKind: engineResult.resultKind,
    );
  }
}
