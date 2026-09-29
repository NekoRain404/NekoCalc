part of 'text_tool_controller.dart';

/// 中文：**不确定度传播工具。**
///
///       **为什么它不经过引擎。** 宿主实测 libqalculate 认 `30 ± 2` 并会正确传播
///       （`2.5±0.1 + 3.0±0.2` → `5.50±0.22`），但那条路要求应用的解析器先认识 `±` 这个运算符；
///       而 `ExpressionParser` 求值成 `double`，**`30±2` 不是一个 double**——那是加一个节点类型的
///       架构改动。本工具要的是**一组测量值之间的合成**，本来就是一个纯函数，
///       **用 Dart 算比绕一大圈更短、更可测**，而且**不依赖引擎，单测就能证完**。
///
///       ⚠️ **HiPER 手册里 `uncertainty` 与 `±` 的命中都是 0**（本仓自己量的，见
///       `.superpowers/backup/engine-capability-probe.md`）——所以这是一条它没有的能力。
///
///       **它给什么**（三样，每一件都是实验报告里真会写上去的）：
///
///       1. **和与差的合成不确定度**：`Δ(a±b) = √(Δa² + Δb²)`。
///          **和与差是同一个数**——这一点值得当面说清，因为很多人以为相减会抵消。
///       2. **积与商的相对不确定度**：`Δ(ab)/(ab) = √((Δa/a)² + (Δb/b)²)`。同样，乘除同值。
///       3. **主要误差来源**：哪一项贡献了最大的一份。**这一条最有用**——
///          它直接回答"我该把哪台仪器换掉"。
///
///       **用的是平方和开方（quadrature），不是直接相加。** 那假设各项**互不相关**——
///       这是本科实验的通行前提，也是本工具明确写出来的一处边界，不是默认它成立。
/// English: **the uncertainty-propagation tool.**
///
///          **Why it does not go through the engine.** The host measured libqalculate accepting
///          `30 ± 2` and propagating correctly (`2.5±0.1 + 3.0±0.2` → `5.50±0.22`), but that road needs
///          this app's parser to know the `±` operator first — and `ExpressionParser` evaluates to a
///          `double`, and **`30±2` is not a double**: that is an architectural change (a new node type).
///          What this tool wants is **the combination across a set of measurements**, a pure function
///          anyway, so **computing it in Dart is shorter and more testable**, and it **does not depend on
///          the engine, so unit tests settle it completely**.
///
///          ⚠️ **HiPER's manual scores zero for both `uncertainty` and `±`** (measured in this repository;
///          see `.superpowers/backup/engine-capability-probe.md`) — a capability it does not have.
///
///          **What it gives** (three things, each of which really does get written into a lab report):
///
///          1. **The combined uncertainty of a sum or difference**: `Δ(a±b) = √(Δa² + Δb²)`.
///             **The sum and the difference are the same number** — worth saying out loud, because many
///             people expect a subtraction to cancel.
///          2. **The relative uncertainty of a product or quotient**:
///             `Δ(ab)/(ab) = √((Δa/a)² + (Δb/b)²)`. Again the same for multiply and divide.
///          3. **The dominant source**: whichever term contributes the largest share. **This is the most
///             useful one** — it answers "which instrument do I replace".
///
///          **It uses quadrature, not straight addition.** That assumes the terms are **uncorrelated** —
///          the standard undergraduate premise, and a boundary this tool states plainly rather than
///          silently assuming.
TextToolOutput _uncertainty(TextToolUncertaintyStrings strings, String input,
    String Function(String label, String value) labelled) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) {
    return TextToolOutput(strings.emptyInput, strings.hint, hasError: true);
  }

  final terms = _parseUncertaintyTerms(trimmed);
  if (terms.isEmpty) {
    return TextToolOutput(strings.unrecognized, strings.hint, hasError: true);
  }
  if (terms.length == 1) {
    final only = terms.single;
    return TextToolOutput(
      strings.readAsSingle(_format(only.value), _format(only.uncertainty)),
      strings.singleHint,
      insights: <String>[
        labelled(
            strings.relativeLabel, _percent(only.relativeUncertainty)),
      ],
      hasError: true,
    );
  }

  // 中文：和与差同值、积与商同值——所以这里只有两个数要算，不是四个。
  // English: sums and differences share a value, and so do products and quotients — two numbers to
  //          compute, not four.
  var sumSquares = 0.0;
  var relativeSquares = 0.0;
  final contributions = <double>[];
  for (final term in terms) {
    sumSquares += term.uncertainty * term.uncertainty;
    relativeSquares += term.relativeUncertainty * term.relativeUncertainty;
    contributions.add(term.uncertainty * term.uncertainty);
  }
  final absolute = math.sqrt(sumSquares);
  final relative = math.sqrt(relativeSquares);

  var dominant = 0;
  for (var i = 1; i < contributions.length; i++) {
    if (contributions[i] > contributions[dominant]) dominant = i;
  }
  final total = contributions.fold<double>(0, (a, b) => a + b);
  final dominantShare = total == 0 ? 0.0 : contributions[dominant] / total;

  return TextToolOutput(
    strings.resultLine('± ${_format(absolute)}'),
    strings.between(
        strings.termList(terms
            .map((t) => '${_format(t.value)} ± ${_format(t.uncertainty)}')
            .toList()),
        terms.length),
    insights: <String>[
      labelled(strings.sumLabel, '± ${_format(absolute)}'),
      labelled(strings.productLabel, _percent(relative)),
      labelled(
          strings.dominantLabel,
          labelled(
              strings.termNumber(dominant + 1), _percent(dominantShare))),
      labelled(strings.relativeLabel, _percent(relative)),
    ],
  );
}

/// 中文：一行一项，写法收 `值 ± 不确定度`、`值 +- 不确定度`、`值 +/- 不确定度`。
///       值必须是有限的；**不确定度为负要挡下来**（它没有物理意义，而 `√(Δ²)` 会把负号吃掉、
///       悄悄算成一个正数——那正是本项目最反对的那种"看起来像答案的错值"）。
/// English: one term per line, written `value ± uncertainty`, `value +- uncertainty` or
///          `value +/- uncertainty`. The value must be finite, and **a negative uncertainty is
///          refused** (it has no physical meaning, and `√(Δ²)` would eat the sign and quietly produce a
///          positive number — exactly the plausible-looking wrong value this project rejects).
List<_UncertainTerm> _parseUncertaintyTerms(String source) {
  final terms = <_UncertainTerm>[];
  for (final rawLine in source.split(RegExp(r'[\r\n,，;；]+'))) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;
    final match =
        RegExp(r'^(.*?)\s*(?:±|\+/-|\+-|\+\s*/\s*-)\s*(.*)$').firstMatch(line);
    if (match == null) return const [];
    final value = _finiteNumber(match.group(1)!.trim());
    final uncertainty = _finiteNumber(match.group(2)!.trim());
    if (value == null || uncertainty == null || uncertainty < 0) {
      return const [];
    }
    terms.add(_UncertainTerm(value, uncertainty));
  }
  return terms;
}

/// 中文：读一个有限的十进制数。**空串、`abc`、`∞`、`NaN` 一律回 `null`**——工具层不猜。
/// English: reads one finite decimal. **An empty string, `abc`, `∞` and `NaN` all come back `null`** —
///          this layer does not guess.
double? _finiteNumber(String source) {
  if (source.isEmpty) return null;
  final value = double.tryParse(source.replaceAll(',', ''));
  if (value == null || !value.isFinite) return null;
  return value;
}

/// 中文：印一个数——**去掉多余的小数零，但不做有效数字的裁剪**。
///       本工具算的是不确定度，**有效数字的取舍留给人**：多印一位比少印一位安全。
/// English: prints a number with trailing zeros trimmed and **without rounding to significant
///          figures**. This tool computes uncertainties and **leaves the significant-figure decision to
///          the reader**: printing one digit too many is safer than one too few.
String _format(double value) {
  if (value == value.roundToDouble() && value.abs() < 1e15) {
    return value.toStringAsFixed(0);
  }
  final text = value.toStringAsPrecision(6);
  if (!text.contains('e')) {
    return text
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }
  return text;
}

String _percent(double fraction) => '${_format(fraction * 100)}%';

class _UncertainTerm {
  const _UncertainTerm(this.value, this.uncertainty);

  final double value;
  final double uncertainty;

  /// 中文：相对不确定度。**值为 0 时它没有定义**，回 0 并让调用方照常印——
  ///       印 `0%` 比让整条结果变成 NaN 诚实。
  /// English: the relative uncertainty. **It is undefined when the value is zero**; this returns 0 and
  ///          lets the caller print it — printing `0%` is more honest than turning the whole result
  ///          into NaN.
  double get relativeUncertainty =>
      value == 0 ? 0 : (uncertainty / value).abs();
}
