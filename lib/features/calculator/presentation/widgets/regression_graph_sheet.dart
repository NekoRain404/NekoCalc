import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../application/controllers/calculator_controller.dart';
import '../../../../shared/presentation/calc_theme.dart';
import '../../../graph/models/graph_models.dart';
import '../../../graph/presentation/graph_painter.dart';
import '../calculator_strings.dart';

/// 中文：**回归图——HiPER 那条「计算细节」里的图：一条拟合曲线与所有的数据点。**
///
///       ### 来源
///
///       HiPER 的帮助文本（`help.statistics.contents`）在统计那一章里写着：
///       「**If you press the `<key:MORE>` button on the display, you will see a graph of regression
///       function and all points.**」那个条目的上下文键是 `detailGroup.REGRESSION_GRAPH.title`
///       （`= "Graph of regression"`），批注是 `"2D an 3D graphs" calculation details`——**一条计算
///       细节**，不是一个统计编辑器。本机那张真机截图里，显示区右上角正是那颗 `更多…`。
///
///       所以这个面板画两样东西：**数据集里的点**，和**一条拟合曲线**。
///
///       ### 点与曲线各从哪儿来
///
///       - **点**：数据集的**两行**读法（前一半 X、后一半 Y）。一行那一种读法画不出图——一组值
///         没有 y，要画就得给横轴发明一个下标，那是数据之外的第二个真相源。判据在控制器里
///         （`regressionGraphPoints`），这里只画。
///       - **曲线**：**引擎算的**，逐点问（`replace(<拟合调用>,x,<数>)`），理由与那两条被否掉的
///         路都在 `CalculatorController.regressionCurveFor` 上。这个面板**一个字都不插值**：
///         两个取样点之间画的是一条**直线**（折线是画法），而每一个取样点上的值都是引擎给的那个。
///
///       ### 画不出来的时候
///
///       **画不出来就不画那条线，只画点，并在下面写出为什么**——三种原因各有各的话，都由控制器
///       给出（`RegressionCurveOutcome.refusal`）。**一个看起来权威的错图比一张没有线的图坏得多**：
///       所以这里没有「近似一条」「按着点连一条」之类的兜底，一条都没有。
///
///       ### 颜色
///
///       每一个颜色都来自 [CalcTheme]（`display.background`/`statusFg`/`indicatorFg`/
///       `expressionFg`/`resultFg`），**没有一个是写死的**。
///
/// English: **the regression graph — the plot inside HiPER's calculation detail: one fitted curve and
///          all the data points.**
///
///          ### The sources
///
///          HiPER's help text (`help.statistics.contents`) says, in the statistics chapter: "**If you
///          press the `<key:MORE>` button on the display, you will see a graph of regression function
///          and all points.**" That entry's context key is `detailGroup.REGRESSION_GRAPH.title`
///          (`= "Graph of regression"`), annotated `"2D an 3D graphs" calculation details` — **a
///          calculation detail**, not a statistics editor. In the one real screenshot on this machine,
///          `更多…` is exactly the button at the display's top right.
///
///          So this sheet draws two things: **the dataset's points**, and **one fitted curve**.
///
///          ### Where each comes from
///
///          - **The points**: the dataset's **two-row** reading (first half X, second half Y). The
///            one-row reading cannot be plotted — a set of values has no y, and drawing one would mean
///            inventing an index for the horizontal axis, a second source of truth outside the data.
///            The judgement lives in the controller (`regressionGraphPoints`); this only draws.
///          - **The curve**: **the engine's**, asked point by point
///            (`replace(<fit call>,x,<number>)`); the reasons, and the two rejected routes, are on
///            `CalculatorController.regressionCurveFor`. This sheet **interpolates nothing**: between
///            two samples it draws a **straight line** (the polyline is a drawing), and every sample's
///            value is the engine's own.
///
///          ### When it cannot be drawn
///
///          **No curve means no line** — only the points, with the reason written underneath. Three
///          causes have three sentences, all supplied by the controller
///          (`RegressionCurveOutcome.refusal`). **A plausible wrong picture is far worse than a plot
///          with no line on it**: so there is no "approximate one", no "join the dots" fallback, not
///          one of them.
///
///          ### Colours
///
///          Every colour comes from [CalcTheme] (`display.background`/`statusFg`/`indicatorFg`/
///          `expressionFg`/`resultFg`) and **not one is hardcoded**.
class RegressionGraphSheet extends StatefulWidget {
  const RegressionGraphSheet({
    required this.points,
    required this.fitNames,
    required this.loadCurve,
    required this.fitReading,
    required this.pointsUnavailableMessage,
    super.key,
  });

  /// 中文：图上那些点（数据集的**两行**读法，前一半 X、后一半 Y）。空表 = 没有点可画，面板于是
  ///       不画图，只把 [pointsUnavailableMessage] 摆出来。
  /// English: the points on the plot (the dataset's **two-row** reading, first half X, second half Y).
  ///          An empty list means there is nothing to plot, so the sheet draws no figure and puts
  ///          [pointsUnavailableMessage] up instead.
  final List<({double x, double y})> points;

  /// 中文：可选的那几条拟合（`linearfit`/`quadraticfit`/`cubicfit`），按面板上的次序，第一条是
  ///       打开时的默认选择。
  /// English: the fits on offer (`linearfit`/`quadraticfit`/`cubicfit`), in the order shown; the first
  ///          is what is selected when the sheet opens.
  final List<String> fitNames;

  /// 中文：**要一条曲线**。实现在控制器里（`regressionCurveFor`），这里只把窗口交给它。
  /// English: **ask for one curve**. The implementation is in the controller
  ///          (`regressionCurveFor`); this only hands it the window.
  final Future<RegressionCurveOutcome> Function(
    String function, {
    required double xMin,
    required double xMax,
  }) loadCurve;

  /// 中文：拟合那一行的读数（几条对数够、现在有几个值）。控制器给的那句话——它**没有**尾巴上那条
  ///       调用，因为这个面板什么都不插。
  /// English: the fit row's reading (how many pairs each needs, how many values there are). The
  ///          controller's sentence — **without** the call at the end, because this sheet inserts
  ///          nothing.
  final String fitReading;

  /// 中文：读不成两行时的那句话（控制器给的 `regressionUnavailableMessage`）。
  /// English: the sentence for "cannot be read as two rows" (the controller's
  ///          `regressionUnavailableMessage`).
  final String pointsUnavailableMessage;

  @override
  State<RegressionGraphSheet> createState() => _RegressionGraphSheetState();
}

class _RegressionGraphSheetState extends State<RegressionGraphSheet> {
  /// 中文：此刻选中的那一条拟合。默认是列表里的第一条（`linearfit`，下限最低的那一条）。
  /// English: the fit selected right now. Defaults to the first in the list (`linearfit`, the one with
  ///          the lowest floor).
  late String _selected;

  /// 中文：这一次请求的结果。`null` = 还在问引擎。
  /// English: this request's outcome. `null` means the engine is still being asked.
  RegressionCurveOutcome? _outcome;

  /// 中文：请求序号——**用户连点两下 `quadraticfit`/`cubicfit` 时只认最后一发**。没有它，先发的那
  ///       一条回包晚到就会把后选的那条曲线盖掉，而屏幕上选中的是后者。
  /// English: the request number — **when the user taps `quadraticfit` and then `cubicfit`, only the
  ///          last one counts**. Without it a slow earlier reply could overwrite the later curve while
  ///          the later chip is the one highlighted.
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _selected = widget.fitNames.isEmpty ? '' : widget.fitNames.first;
    if (widget.points.isEmpty) return;
    _load(_selected);
  }

  Future<void> _load(String function) async {
    final request = ++_request;
    if (function.isEmpty || widget.points.isEmpty) {
      if (mounted) setState(() => _outcome = null);
      return;
    }
    final window = regressionGraphXWindow(widget.points);
    final outcome = await widget.loadCurve(
      function,
      xMin: window.xMin,
      xMax: window.xMax,
    );
    if (!mounted || request != _request) return;
    setState(() => _outcome = outcome);
  }

  void _select(String function) {
    if (function == _selected) return;
    setState(() {
      _selected = function;
      _outcome = null;
    });
    _load(function);
  }

  @override
  Widget build(BuildContext context) {
    final theme = CalcTheme.of(context);
    final strings = CalculatorStrings.of(context);
    if (widget.points.isEmpty) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Text(
            widget.pointsUnavailableMessage,
            style: TextStyle(color: theme.display.statusFg, fontSize: 12),
          ),
        ),
      );
    }
    // 中文：**x 窗口只在这里算一次**，它同时喂给取样（`_load` 里那次是同一个函数、同一个输入，
    //       所以两处给的是同一个窗口）与画笔。y 窗口要等曲线回来才定得下来。
    // English: **the x window is computed once here**, and it feeds both the sampling (`_load` calls
    //          the same function with the same input, so the two agree) and the painter. The y window
    //          can only be fixed once the curve comes back.
    final xWindow = regressionGraphXWindow(widget.points);
    final curve = _outcome?.curve;
    final yWindow = regressionGraphYWindow(
      widget.points,
      curve?.ys ?? const <double>[],
    );
    final viewport = GraphViewport(
      centerX: (xWindow.xMin + xWindow.xMax) / 2,
      centerY: (yWindow.yMin + yWindow.yMax) / 2,
      spanX: xWindow.xMax - xWindow.xMin,
      spanY: yWindow.yMax - yWindow.yMin,
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(strings.curveRowTitle,
                    style:
                        TextStyle(color: theme.display.statusFg, fontSize: 12)),
                for (final name in widget.fitNames)
                  TextButton(
                    // 中文：**这一格永远是亮的**，与 `STAT` 面板上那三格**故意不同**。理由量得出来：
                    //       那边按下去是**往表达式里插一条引擎答不出来的调用**（屏幕上多一句错误），
                    //       所以灰键是诚实的；这边按下去是**换一条曲线**，而对数不够时面板照样画出
                    //       数据集里的点、并说出还差几对——那是一件有用的事，不是一句谎。灰掉的话
                    //       用户就没有任何办法问「为什么三次拟合没有曲线」。
                    // English: **this cell is always lit**, **deliberately unlike** the three on the
                    //          `STAT` sheet. The reason is measured: there, a press **inserts a call the
                    //          engine cannot answer** into the expression (an error appears on screen),
                    //          so a grey cell is honest; here, a press **switches which curve is
                    //          drawn**, and with too few pairs the sheet still draws the dataset's
                    //          points and says how many more pairs are needed — a useful thing rather
                    //          than a lie. Greyed out, the user would have no way to ask "why has the
                    //          cubic fit no curve".
                    onPressed: () => _select(name),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.display.indicatorFg,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size(0, 38),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(name,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
            Text(
              widget.fitReading,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: theme.display.statusFg, fontSize: 12),
            ),
            const SizedBox(height: 8),
            // 中文：图本身。`ground` 用显示区的底色而不是另发明一个——图上那一片就是显示区的延续。
            // English: the figure itself. `ground` is the display area's own background rather than a
            //          newly invented one — that patch is a continuation of the display area.
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.display.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: theme.display.statusFg.withValues(alpha: 0.28)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: AspectRatio(
                  aspectRatio: 1.4,
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: RegressionGraphPainter(
                      viewport: viewport,
                      points: widget.points,
                      curveXs: curve?.xs ?? const <double>[],
                      curveYs: curve?.ys ?? const <double>[],
                      groundColor: theme.display.background,
                      gridColor: theme.display.statusFg.withValues(alpha: 0.18),
                      axisColor: theme.display.statusFg.withValues(alpha: 0.55),
                      labelColor: theme.display.statusFg,
                      pointColor: theme.display.indicatorFg,
                      curveColor: theme.display.resultFg,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _reading(strings),
              style: TextStyle(
                color: _outcome?.refusal == null
                    ? theme.display.statusFg
                    : theme.display.errorFg,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 中文：图下面那一行读数——**画的是什么，以及画不出来时为什么**。
  ///
  ///       三种状态各有各的话，而「画不出来」那一句**逐字来自控制器**（`refusal`）：判定在控制器
  ///       里、话也在控制器里，界面只是把它印出来，所以两处不可能漂开。
  ///
  /// English: the reading under the figure — **what is drawn, and why not when it is not**.
  ///
  ///          The three states each have their own sentence, and the "cannot be drawn" one comes
  ///          **verbatim from the controller** (`refusal`): the judgement is there and so is the
  ///          sentence, and the screen only prints it, so the two cannot drift apart.
  String _reading(CalculatorStrings strings) {
    final outcome = _outcome;
    if (outcome == null) return strings.curveLoading;
    final curve = outcome.curve;
    if (curve == null) return outcome.refusal ?? '';
    return strings.curveReading(
      curve.function,
      curve.ys.length,
      widget.points.length,
    );
  }
}

/// 中文：**图上那一条 x 窗口**——点的 x 范围两边各留 15%。
///
///       窗口由**点**定，与曲线无关，这是有意的：曲线画不出来时窗口一模一样，图不会因为换了一条
///       选择而跳一下。留白也是：拟合只在数据的范围里可信，把窗口拉到数据之外会画出**数据没有
///       支持的一段曲线**——那正是这个面板要避免的那类东西。
///
///       所有 x 相同时（一份退化的数据集）给一个宽 1 的窗口，那比一个宽 0（除零、画不出东西）诚实。
///
/// English: **the x window of the figure** — 15% of padding either side of the points' x range.
///
///          The window is fixed by the **points**, not by the curve, deliberately: it is identical
///          when no curve can be drawn, so the figure does not jump about when the selection changes.
///          The padding is for the same reason: a fit is only trustworthy over the data's range, and
///          stretching the window beyond it would draw **a stretch of curve nothing supports** — just
///          the sort of thing this sheet exists to avoid.
///
///          When every x is the same (a degenerate dataset) this gives a window one unit wide, which
///          is more honest than a zero-width one (a division by zero, and nothing drawable).
({double xMin, double xMax}) regressionGraphXWindow(
  List<({double x, double y})> points,
) {
  var low = double.infinity;
  var high = double.negativeInfinity;
  for (final point in points) {
    low = math.min(low, point.x);
    high = math.max(high, point.x);
  }
  if (!low.isFinite || !high.isFinite) return (xMin: -0.5, xMax: 0.5);
  final span = high - low;
  final pad = span > 0 ? span * 0.15 : 0.5;
  return (xMin: low - pad, xMax: high + pad);
}

/// 中文：**图上那一条 y 窗口**——点的 y 与曲线取样值**一起**定范围，两边各留 8%。
///
///       曲线**必须**参与：一条拟合曲线可以在两个数据点之间探出数据的范围（三次拟合尤其），
///       只按点定窗口会把那一段裁掉，而屏幕上看起来就像曲线在那里断了。
///
/// English: **the y window of the figure** — the points' y and the curve's samples **together** set
///          the range, 8% of padding either side.
///
///          The curve **has** to take part: a fitted curve can reach past the data's range between two
///          data points (a cubic especially), and a window fixed by the points alone would clip that
///          stretch — which on screen reads exactly as if the curve stopped there.
({double yMin, double yMax}) regressionGraphYWindow(
  List<({double x, double y})> points,
  List<double> curveYs,
) {
  var low = double.infinity;
  var high = double.negativeInfinity;
  for (final point in points) {
    low = math.min(low, point.y);
    high = math.max(high, point.y);
  }
  for (final y in curveYs) {
    if (!y.isFinite) continue;
    low = math.min(low, y);
    high = math.max(high, y);
  }
  if (!low.isFinite || !high.isFinite) return (yMin: -0.5, yMax: 0.5);
  final span = high - low;
  final pad = span > 0 ? span * 0.08 : 0.5;
  return (yMin: low - pad, yMax: high + pad);
}

/// 中文：回归图的画笔——网格、坐标轴、**所有的点**，以及**有就给、没有就不画**的那条曲线。
///
///       为什么不复用 `GraphPainter`：那一个画的是**从表达式字符串求值出来的函数**
///       （`GraphFunction.evaluate` 走旧解析器），而这一条曲线**没有表达式字符串**——它的值是引擎
///       一个点一个点给的。硬套的话要造一个 `GraphFunction` 子类、让它忽略自己那个 `expression`
///       字段，而那两个字段（`expression`/`label`）会读起来像「这条曲线是一个用户打进去的函数」，
///       正好是它**不是**的东西。**重用的是它下面那一层**：`GraphViewport`（窗口变换，两处同一条
///       坐标约定）与 `graphAxisStep`/`graphAxisStepDigits`（1/2/5 的刻度序列）。
///
///       点画在曲线**上面**：数据是事实，曲线是推断，推断不该盖住事实。
///
/// English: the regression graph's painter — the grid, the axes, **all the points**, and the curve
///          **drawn when there is one and not drawn when there is not**.
///
///          Why `GraphPainter` is not reused: that one draws **functions evaluated from an expression
///          string** (`GraphFunction.evaluate` goes through the legacy parser), while this curve has
///          **no expression string** — its values are handed over by the engine point by point.
///          Reusing it would mean building a `GraphFunction` subclass that ignores its own
///          `expression` field, and those two fields (`expression`/`label`) would read as if this
///          curve were a function the user typed, which is exactly what it is **not**. **What is
///          reused is the layer underneath**: `GraphViewport` (the window transform, one coordinate
///          convention in both places) and `graphAxisStep`/`graphAxisStepDigits` (the 1/2/5 tick
///          sequence).
///
///          The points are drawn **over** the curve: the data are the fact, the curve is the
///          inference, and the inference must not cover the fact.
class RegressionGraphPainter extends CustomPainter {
  const RegressionGraphPainter({
    required this.viewport,
    required this.points,
    required this.curveXs,
    required this.curveYs,
    required this.groundColor,
    required this.gridColor,
    required this.axisColor,
    required this.labelColor,
    required this.pointColor,
    required this.curveColor,
  });

  final GraphViewport viewport;
  final List<({double x, double y})> points;

  /// 中文：曲线取样位置。**空表 = 没有曲线可画**，这一支一根线都不画。
  /// English: the curve's sample positions. **An empty list means no curve**, and this branch draws
  ///          no line at all.
  final List<double> curveXs;

  /// 中文：曲线取样值，与 [curveXs] 一一对应。
  /// English: the curve's sample values, one for one with [curveXs].
  final List<double> curveYs;

  final Color groundColor;
  final Color gridColor;
  final Color axisColor;
  final Color labelColor;
  final Color pointColor;
  final Color curveColor;

  /// 中文：**此刻画了几条曲线**——0 或 1，没有别的可能。测试用它断言「拒绝时不画曲线」。
  /// English: **how many curves are drawn right now** — 0 or 1, nothing else is possible. Tests use
  ///          it to assert "a refused fit draws no curve".
  bool get drawsCurve =>
      curveXs.length >= 2 && curveYs.length == curveXs.length;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    _paintGrid(canvas, size);
    _paintCurve(canvas, size);
    _paintPoints(canvas, size);
  }

  void _paintGrid(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final axis = Paint()
      ..color = axisColor
      ..strokeWidth = 1.2;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final xStep = graphAxisStep(viewport.spanX / 8);
    final yStep = graphAxisStep(viewport.spanY / 8);
    for (var x = (viewport.xMin / xStep).floor() * xStep;
        x <= viewport.xMax;
        x += xStep) {
      final sx = viewport.toScreenX(x, size);
      canvas.drawLine(Offset(sx, 0), Offset(sx, size.height), grid);
      _label(canvas, textPainter, x.toStringAsFixed(graphAxisStepDigits(xStep)),
          Offset(sx + 3, size.height - 16));
    }
    for (var y = (viewport.yMin / yStep).floor() * yStep;
        y <= viewport.yMax;
        y += yStep) {
      final sy = viewport.toScreenY(y, size);
      canvas.drawLine(Offset(0, sy), Offset(size.width, sy), grid);
      _label(canvas, textPainter, y.toStringAsFixed(graphAxisStepDigits(yStep)),
          Offset(4, sy - 14));
    }
    if (viewport.yMin <= 0 && viewport.yMax >= 0) {
      final y0 = viewport.toScreenY(0, size);
      canvas.drawLine(Offset(0, y0), Offset(size.width, y0), axis);
    }
    if (viewport.xMin <= 0 && viewport.xMax >= 0) {
      final x0 = viewport.toScreenX(0, size);
      canvas.drawLine(Offset(x0, 0), Offset(x0, size.height), axis);
    }
  }

  void _paintCurve(Canvas canvas, Size size) {
    if (!drawsCurve) return;
    final paint = Paint()
      ..color = curveColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (var i = 0; i < curveXs.length; i++) {
      final point = Offset(
        viewport.toScreenX(curveXs[i], size),
        viewport.toScreenY(curveYs[i], size),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(path, paint);
  }

  void _paintPoints(Canvas canvas, Size size) {
    final fill = Paint()..color = pointColor;
    // 中文：一圈底色描边，让点压在曲线上时照样看得见——否则一条穿过点的曲线会把点吃掉。
    // English: a ring in the ground colour so a point stays visible on top of the curve — otherwise a
    //          curve running through the points swallows them.
    final ring = Paint()
      ..color = groundColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (final point in points) {
      final center = Offset(
        viewport.toScreenX(point.x, size),
        viewport.toScreenY(point.y, size),
      );
      canvas.drawCircle(center, 4.5, fill);
      canvas.drawCircle(center, 4.5, ring);
    }
  }

  void _label(Canvas canvas, TextPainter painter, String text, Offset offset) {
    painter.text =
        TextSpan(text: text, style: TextStyle(color: labelColor, fontSize: 10));
    painter.layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant RegressionGraphPainter oldDelegate) {
    return oldDelegate.viewport != viewport ||
        oldDelegate.points != points ||
        oldDelegate.curveXs != curveXs ||
        oldDelegate.curveYs != curveYs ||
        oldDelegate.groundColor != groundColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.labelColor != labelColor ||
        oldDelegate.pointColor != pointColor ||
        oldDelegate.curveColor != curveColor;
  }
}
