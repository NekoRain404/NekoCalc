import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/math/expression_parser.dart';
import '../../../shared/presentation/app_chrome.dart';

/// 中文：函数图形页，提供函数管理、拖拽缩放，以及零点/交点/极值标记。
/// English: Function graph page with function management, pan/zoom, and zero/intersection/extrema markers.
class GraphPage extends StatefulWidget {
  const GraphPage({super.key});

  @override
  State<GraphPage> createState() => _GraphPageState();
}

class _GraphPageState extends State<GraphPage> {
  final List<GraphFunction> _functions = [
    const GraphFunction(
        expression: 'sin(x)', label: 'y = sin(x)', color: Color(0xFF1677FF)),
    const GraphFunction(
        expression: 'x^2 - 3*x + 2',
        label: 'y = x² - 3x + 2',
        color: Color(0xFF7C3AED)),
  ];
  GraphViewport _viewport =
      const GraphViewport(centerX: 0, centerY: 0, spanX: 12, spanY: 12);
  List<GraphMarker> _markers = const [];
  int? _selectedMarker;
  String _status = '拖动画布平移，双指缩放';
  double _lastScale = 1;

  Future<void> _addFunction() async {
    final controller = TextEditingController(
        text: _functions.length % 2 == 0 ? 'cos(x)' : '0.5*x + 1');
    final expression = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加函数'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
              labelText: 'y =', hintText: '例如 sin(x)、x^2 - 3*x + 2'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('添加')),
        ],
      ),
    );
    controller.dispose();
    if (expression == null || expression.isEmpty) return;
    setState(() {
      _functions.add(GraphFunction(
        expression: expression,
        label: 'y = $expression',
        color: _palette[_functions.length % _palette.length],
      ));
      _markers = const [];
      _selectedMarker = null;
      _status = '已添加 y = $expression';
    });
  }

  void _toggle(int index) {
    setState(() {
      _functions[index] =
          _functions[index].copyWith(visible: !_functions[index].visible);
    });
  }

  Future<void> _editFunction(int index) async {
    final controller =
        TextEditingController(text: _functions[index].expression);
    final expression = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑函数'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
              labelText: 'y =', hintText: '例如 sin(x)、x^2 - 3*x + 2'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('保存')),
        ],
      ),
    );
    controller.dispose();
    if (expression == null || expression.isEmpty) return;
    setState(() {
      final current = _functions[index];
      _functions[index] = GraphFunction(
          expression: expression,
          label: 'y = $expression',
          color: current.color,
          visible: current.visible);
      _markers = const [];
      _selectedMarker = null;
      _status = '已更新 y = $expression';
    });
  }

  void _deleteFunction(int index) {
    setState(() {
      final removed = _functions.removeAt(index);
      _markers = const [];
      _selectedMarker = null;
      _status = '已删除 ${removed.label}';
    });
  }

  void _reset() {
    setState(() {
      for (var i = 0; i < _functions.length; i++) {
        _functions[i] = _functions[i].copyWith(visible: true);
      }
      _viewport =
          const GraphViewport(centerX: 0, centerY: 0, spanX: 12, spanY: 12);
      _markers = const [];
      _selectedMarker = null;
      _status = '视图已重置';
    });
  }

  void _zoom(double factor) {
    setState(() {
      _viewport = _viewport.zoom(factor);
      _status =
          '视图范围 x: ${_viewport.xMin.toStringAsFixed(1)} ~ ${_viewport.xMax.toStringAsFixed(1)}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      children: [
        Row(
          children: [
            const Expanded(child: PageTitle('图形')),
            IconToolButton(
                icon: Icons.add, tooltip: '添加函数', onTap: _addFunction),
          ],
        ),
        Card(
          child: Column(
            children: [
              for (var i = 0; i < _functions.length; i++) ...[
                FunctionRow(
                  function: _functions[i],
                  onToggle: () => _toggle(i),
                  onEdit: () => _editFunction(i),
                  onDelete:
                      _functions.length <= 1 ? null : () => _deleteFunction(i),
                ),
                if (i != _functions.length - 1) const Divider(height: 1),
              ],
              const Divider(height: 1),
              ListTile(
                onTap: _addFunction,
                leading: const Icon(Icons.add_circle_outline,
                    color: Color(0xFF1677FF)),
                title: const Text('添加函数',
                    style: TextStyle(color: Color(0xFF1677FF))),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 380,
          decoration: softPanel(context: context),
          clipBehavior: Clip.antiAlias,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              return GestureDetector(
                onScaleStart: (_) => _lastScale = 1,
                onTapUp: (details) =>
                    _selectMarker(details.localPosition, size),
                onScaleUpdate: (details) {
                  if (details.pointerCount == 1) {
                    setState(() {
                      _viewport = _viewport.pan(details.focalPointDelta, size);
                      _status =
                          'x: ${_viewport.xMin.toStringAsFixed(1)} ~ ${_viewport.xMax.toStringAsFixed(1)}';
                    });
                    return;
                  }
                  if ((details.scale - 1).abs() < 0.01) return;
                  final incremental = details.scale / _lastScale;
                  _lastScale = details.scale;
                  setState(() {
                    _viewport = _viewport.zoom(1 / incremental);
                    _status =
                        '缩放 ${(12 / _viewport.spanX).toStringAsFixed(2)}x';
                  });
                },
                onScaleEnd: (_) => _lastScale = 1,
                child: CustomPaint(
                  painter: GraphPainter(
                    functions: _functions,
                    viewport: _viewport,
                    markers: _markers,
                    selectedMarker: _selectedMarker,
                    gridColor: scheme.outlineVariant.withValues(alpha: 0.52),
                    axisColor: scheme.onSurfaceVariant,
                    labelColor: scheme.onSurfaceVariant,
                    markerLabelColor: scheme.onSurface,
                    markerLabelBackground: scheme.surface,
                    markerLabelBorder: scheme.outlineVariant,
                  ),
                  child: const SizedBox.expand(),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: softPanel(context: context, highlight: true),
          child: Center(
            child: Text(_status,
                style: TextStyle(
                    color: scheme.secondary, fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: ActionButton(
                    icon: Icons.refresh, label: '重置', onTap: _reset)),
            const SizedBox(width: 8),
            Expanded(
                child: ActionButton(
                    icon: Icons.zoom_in,
                    label: '放大',
                    onTap: () => _zoom(0.75))),
            const SizedBox(width: 8),
            Expanded(
                child: ActionButton(
                    icon: Icons.zoom_out,
                    label: '缩小',
                    onTap: () => _zoom(1.35))),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
                child: ActionButton(
                    icon: Icons.adjust, label: '零点', onTap: _markZeros)),
            const SizedBox(width: 8),
            Expanded(
                child: ActionButton(
                    icon: Icons.scatter_plot_outlined,
                    label: '交点',
                    onTap: _markIntersections)),
            const SizedBox(width: 8),
            Expanded(
                child: ActionButton(
                    icon: Icons.timeline, label: '极值', onTap: _markExtremes)),
          ],
        ),
      ],
    );
  }

  void _selectMarker(Offset localPosition, Size size) {
    if (_markers.isEmpty) return;
    var bestIndex = -1;
    var bestDistance = double.infinity;
    for (var i = 0; i < _markers.length; i++) {
      final marker = _markers[i];
      final point = Offset(_viewport.toScreenX(marker.x, size),
          _viewport.toScreenY(marker.y, size));
      final distance = (point - localPosition).distance;
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = i;
      }
    }
    if (bestIndex == -1 || bestDistance > 26) return;
    setState(() {
      _selectedMarker = bestIndex;
      _status = _markers[bestIndex].info;
    });
  }

  void _markZeros() {
    final markers = _findZeroMarkers();
    setState(() {
      _markers = markers;
      _selectedMarker = markers.isEmpty ? null : 0;
      _status =
          markers.isEmpty ? '当前视图未找到零点' : '找到 ${markers.length} 个零点，点击高亮点查看详情';
    });
  }

  void _markIntersections() {
    final markers = _findIntersectionMarkers();
    setState(() {
      _markers = markers;
      _selectedMarker = markers.isEmpty ? null : 0;
      _status =
          markers.isEmpty ? '当前视图未找到交点' : '找到 ${markers.length} 个交点，点击高亮点查看详情';
    });
  }

  void _markExtremes() {
    final markers = _findExtremeMarkers();
    setState(() {
      _markers = markers;
      _selectedMarker = markers.isEmpty ? null : 0;
      _status = markers.isEmpty
          ? '当前视图没有有效极值采样'
          : '找到 ${markers.length} 个极值点，点击高亮点查看详情';
    });
  }

  List<GraphMarker> _findZeroMarkers() {
    final visible = _functions.where((item) => item.visible).toList();
    if (visible.isEmpty) return const [];
    final markers = <GraphMarker>[];
    final step = _viewport.spanX / 800;
    for (final function in visible) {
      for (var x = _viewport.xMin; x < _viewport.xMax; x += step) {
        final y1 = function.evaluate(x);
        final y2 = function.evaluate(x + step);
        if (!_finite(y1) || !_finite(y2)) continue;
        if (y1.abs() < 1e-7 || y1.sign != y2.sign) {
          final root = y1.abs() < 1e-7
              ? x
              : _bisect((value) => function.evaluate(value), x, x + step);
          if (_hasNearby(markers, root, 0, step * 3)) continue;
          markers.add(GraphMarker(
            x: root,
            y: 0,
            color: function.color,
            kind: '零点',
            info: '${function.label} 零点\nx = ${root.toStringAsFixed(6)}\ny = 0',
          ));
        }
      }
    }
    return markers;
  }

  List<GraphMarker> _findIntersectionMarkers() {
    final visible = _functions.where((item) => item.visible).toList();
    if (visible.length < 2) return const [];
    final markers = <GraphMarker>[];
    final step = _viewport.spanX / 800;
    // 中文：所有可见函数两两配对，避免只检查前两条曲线导致交点缺失。
    // English: Compare every visible function pair so intersections are not limited to the first two curves.
    for (var i = 0; i < visible.length; i++) {
      for (var j = i + 1; j < visible.length; j++) {
        final first = visible[i];
        final second = visible[j];
        for (var x = _viewport.xMin; x < _viewport.xMax; x += step) {
          final d1 = first.evaluate(x) - second.evaluate(x);
          final d2 = first.evaluate(x + step) - second.evaluate(x + step);
          if (!_finite(d1) || !_finite(d2)) continue;
          if (d1.abs() < 1e-7 || d1.sign != d2.sign) {
            final root = _bisect(
                (value) => first.evaluate(value) - second.evaluate(value),
                x,
                x + step);
            final y = first.evaluate(root);
            if (!_finite(y) || _hasNearby(markers, root, y, step * 3)) {
              continue;
            }
            markers.add(GraphMarker(
              x: root,
              y: y,
              color: const Color(0xFFFF8A00),
              kind: '交点',
              info:
                  '${first.label}\n${second.label}\n交点 x = ${root.toStringAsFixed(6)}, y = ${y.toStringAsFixed(6)}',
            ));
          }
        }
      }
    }
    return markers;
  }

  List<GraphMarker> _findExtremeMarkers() {
    final visible = _functions.where((item) => item.visible).toList();
    if (visible.isEmpty) return const [];
    final markers = <GraphMarker>[];
    final step = _viewport.spanX / 1000;
    // 中文：使用相邻三点判断局部极值，再用二次插值细化点位。
    // English: Detect local extrema with three neighboring samples, then refine the point by quadratic interpolation.
    for (final function in visible) {
      var leftX = _viewport.xMin;
      var leftY = function.evaluate(leftX);
      var midX = leftX + step;
      var midY = function.evaluate(midX);
      for (var rightX = midX + step; rightX <= _viewport.xMax; rightX += step) {
        final rightY = function.evaluate(rightX);
        if (_finite(leftY) && _finite(midY) && _finite(rightY)) {
          final isMin = midY < leftY && midY <= rightY;
          final isMax = midY > leftY && midY >= rightY;
          if (isMin || isMax) {
            final refined =
                _quadraticVertex(leftX, leftY, midX, midY, rightX, rightY);
            final x = refined?.$1 ?? midX;
            final y = refined?.$2 ?? midY;
            if (_finite(x) &&
                _finite(y) &&
                !_hasNearby(markers, x, y, step * 4)) {
              markers.add(GraphMarker(
                x: x,
                y: y,
                color:
                    isMin ? const Color(0xFF23B45D) : const Color(0xFFFF4D5E),
                kind: isMin ? '极小值' : '极大值',
                info:
                    '${function.label} ${isMin ? '极小值' : '极大值'}\nx = ${x.toStringAsFixed(6)}\ny = ${y.toStringAsFixed(6)}',
              ));
            }
          }
        }
        leftX = midX;
        leftY = midY;
        midX = rightX;
        midY = rightY;
      }
    }
    return markers;
  }

  bool _hasNearby(
      List<GraphMarker> markers, double x, double y, double tolerance) {
    return markers.any((marker) =>
        (marker.x - x).abs() < tolerance && (marker.y - y).abs() < tolerance);
  }

  bool _finite(double value) => value.isFinite && !value.isNaN;

  double _bisect(double Function(double x) f, double left, double right) {
    // 中文：二分法用于符号变号区间，收敛稳定且足够适合移动端交互。
    // English: Bisection is stable for sign-change intervals and inexpensive enough for mobile interaction.
    var a = left;
    var b = right;
    var fa = f(a);
    for (var i = 0; i < 50; i++) {
      final mid = (a + b) / 2;
      final fm = f(mid);
      if (!fm.isFinite || fm.abs() < 1e-10) return mid;
      if (fa.sign == fm.sign) {
        a = mid;
        fa = fm;
      } else {
        b = mid;
      }
    }
    return (a + b) / 2;
  }

  (double, double)? _quadraticVertex(
      double x1, double y1, double x2, double y2, double x3, double y3) {
    // 中文：用三点拟合局部抛物线，提升极值标记精度但避免引入重型数值库。
    // English: Fit a local parabola from three points for better extrema accuracy without a heavy numeric library.
    final denominator = (x1 - x2) * (x1 - x3) * (x2 - x3);
    if (denominator.abs() < 1e-12) return null;
    final a = (x3 * (y2 - y1) + x2 * (y1 - y3) + x1 * (y3 - y2)) / denominator;
    final b =
        (x3 * x3 * (y1 - y2) + x2 * x2 * (y3 - y1) + x1 * x1 * (y2 - y3)) /
            denominator;
    if (a.abs() < 1e-12) return null;
    final x = -b / (2 * a);
    if (x < math.min(x1, x3) || x > math.max(x1, x3)) return null;
    final y = a * x * x + b * x + (y2 - a * x2 * x2 - b * x2);
    return (x, y);
  }
}

class FunctionRow extends StatelessWidget {
  const FunctionRow({
    required this.function,
    required this.onToggle,
    required this.onEdit,
    this.onDelete,
    super.key,
  });

  final GraphFunction function;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.circle, color: function.color, size: 12),
      title: Text(function.label),
      trailing: Wrap(
        spacing: 2,
        children: [
          IconButton(
            tooltip: function.visible ? '隐藏' : '显示',
            onPressed: onToggle,
            icon: Icon(
                function.visible ? Icons.visibility : Icons.visibility_off,
                color: const Color(0xFF1677FF)),
          ),
          PopupMenuButton<String>(
            tooltip: '函数操作',
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete?.call();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('编辑函数')),
              PopupMenuItem(
                  value: 'delete',
                  enabled: onDelete != null,
                  child: const Text('删除函数')),
            ],
          ),
        ],
      ),
    );
  }
}

class GraphFunction {
  const GraphFunction({
    required this.expression,
    required this.label,
    required this.color,
    this.visible = true,
  });

  final String expression;
  final String label;
  final Color color;
  final bool visible;

  GraphFunction copyWith({bool? visible}) {
    return GraphFunction(
        expression: expression,
        label: label,
        color: color,
        visible: visible ?? this.visible);
  }

  double evaluate(double x) {
    try {
      // 中文：图形页复用核心表达式解析器，保证计算器和图形函数语义一致。
      // English: The graph page reuses the core expression parser so graph functions match calculator semantics.
      final parsed = _normalize(expression, x);
      return ExpressionParser(parsed, degreeMode: false).parse();
    } catch (_) {
      return double.nan;
    }
  }

  String _normalize(String raw, double x) {
    // 中文：把常见数学显示符号转成 parser 语法，并把 x 替换为当前采样值。
    // English: Convert common display math symbols to parser syntax and replace x with the current sample value.
    var parsed = raw
        .toLowerCase()
        .replaceAll('π', 'pi')
        .replaceAll('²', '^2')
        .replaceAll('×', '*')
        .replaceAll('÷', '/');
    parsed = parsed.replaceAll(RegExp(r'\bx\b'), '(${_numberLiteral(x)})');
    parsed = parsed.replaceAllMapped(
        RegExp(r'(\d|\))(?=(\(|pi|e|sin|cos|tan|sqrt|log|ln|abs))'),
        (match) => '${match.group(1)}*');
    // 中文：补上隐式乘法，例如 2sin(x)、3pi、(x+1)(x-1)。
    // English: Insert implicit multiplication for forms such as 2sin(x), 3pi, and (x+1)(x-1).
    return parsed;
  }

  String _numberLiteral(double value) {
    if (value.abs() < 1e-12) return '0';
    return value
        .toStringAsFixed(12)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}

class GraphMarker {
  const GraphMarker({
    required this.x,
    required this.y,
    required this.color,
    required this.kind,
    required this.info,
  });

  final double x;
  final double y;
  final Color color;
  final String kind;
  final String info;
}

const List<Color> _palette = [
  Color(0xFF1677FF),
  Color(0xFF7C3AED),
  Color(0xFFFF8A00),
  Color(0xFF23B45D),
  Color(0xFFFF4D5E),
];

class GraphPainter extends CustomPainter {
  const GraphPainter({
    required this.functions,
    required this.viewport,
    required this.markers,
    required this.selectedMarker,
    required this.gridColor,
    required this.axisColor,
    required this.labelColor,
    required this.markerLabelColor,
    required this.markerLabelBackground,
    required this.markerLabelBorder,
  });

  final List<GraphFunction> functions;
  final GraphViewport viewport;
  final List<GraphMarker> markers;
  final int? selectedMarker;
  final Color gridColor;
  final Color axisColor;
  final Color labelColor;
  final Color markerLabelColor;
  final Color markerLabelBackground;
  final Color markerLabelBorder;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final axis = Paint()
      ..color = axisColor
      ..strokeWidth = 1.2;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    // 中文：网格步长使用 1/2/5 序列，让缩放时刻度更接近工程图表习惯。
    // English: Grid steps use the 1/2/5 sequence so zoomed ticks feel like engineering charts.
    final xStep = _niceStep(viewport.spanX / 8);
    final yStep = _niceStep(viewport.spanY / 8);
    for (var x = (viewport.xMin / xStep).floor() * xStep;
        x <= viewport.xMax;
        x += xStep) {
      final sx = viewport.toScreenX(x, size);
      canvas.drawLine(Offset(sx, 0), Offset(sx, size.height), grid);
      _label(canvas, textPainter, x.toStringAsFixed(_digits(xStep)),
          Offset(sx + 3, size.height - 18));
    }
    for (var y = (viewport.yMin / yStep).floor() * yStep;
        y <= viewport.yMax;
        y += yStep) {
      final sy = viewport.toScreenY(y, size);
      canvas.drawLine(Offset(0, sy), Offset(size.width, sy), grid);
      _label(canvas, textPainter, y.toStringAsFixed(_digits(yStep)),
          Offset(4, sy - 16));
    }
    if (viewport.yMin <= 0 && viewport.yMax >= 0) {
      final y0 = viewport.toScreenY(0, size);
      canvas.drawLine(Offset(0, y0), Offset(size.width, y0), axis);
    }
    if (viewport.xMin <= 0 && viewport.xMax >= 0) {
      final x0 = viewport.toScreenX(0, size);
      canvas.drawLine(Offset(x0, 0), Offset(x0, size.height), axis);
    }
    for (final function in functions.where((item) => item.visible)) {
      _plot(canvas, size, function);
    }
    _plotMarkers(canvas, size);
  }

  void _plot(Canvas canvas, Size size, GraphFunction function) {
    final paint = Paint()
      ..color = function.color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path();
    var started = false;
    Offset? previous;
    for (var i = 0; i <= size.width; i++) {
      // 中文：按屏幕像素采样，缩放后曲线密度自然跟随可见宽度。
      // English: Sample per screen pixel so curve density follows the visible width after zooming.
      final x = viewport.xMin + i / size.width * viewport.spanX;
      final y = function.evaluate(x);
      if (y.isNaN ||
          y.isInfinite ||
          y < viewport.yMin - viewport.spanY ||
          y > viewport.yMax + viewport.spanY) {
        started = false;
        previous = null;
        continue;
      }
      final point = Offset(i.toDouble(), viewport.toScreenY(y, size));
      if (!started ||
          previous == null ||
          (point.dy - previous.dy).abs() > size.height * 0.75) {
        // 中文：大跳变时断开路径，避免渐近线被错误连成竖线。
        // English: Break the path on large jumps to avoid drawing false vertical lines at asymptotes.
        path.moveTo(point.dx, point.dy);
        started = true;
      } else {
        path.lineTo(point.dx, point.dy);
      }
      previous = point;
    }
    canvas.drawPath(path, paint);
  }

  void _plotMarkers(Canvas canvas, Size size) {
    // 中文：只绘制当前视窗内的标记，平移后隐藏离屏点，避免标签污染画布。
    // English: Paint only in-viewport markers so offscreen points do not pollute the canvas after panning.
    for (var i = 0; i < markers.length; i++) {
      final marker = markers[i];
      if (marker.x < viewport.xMin ||
          marker.x > viewport.xMax ||
          marker.y < viewport.yMin ||
          marker.y > viewport.yMax) {
        continue;
      }
      final center = Offset(viewport.toScreenX(marker.x, size),
          viewport.toScreenY(marker.y, size));
      final selected = selectedMarker == i;
      final fill = Paint()..color = marker.color;
      final halo = Paint()
        ..color = marker.color.withValues(alpha: selected ? 0.22 : 0.12);
      final stroke = Paint()
        ..color = markerLabelBackground
        ..strokeWidth = selected ? 3 : 2
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(center, selected ? 14 : 10, halo);
      canvas.drawCircle(center, selected ? 6.5 : 5, fill);
      canvas.drawCircle(center, selected ? 6.5 : 5, stroke);
      if (selected) {
        _markerLabel(canvas, marker.kind, center + const Offset(10, -28));
      }
    }
  }

  void _markerLabel(Canvas canvas, String text, Offset offset) {
    final painter = TextPainter(
      text: TextSpan(
          text: text,
          style: TextStyle(
              color: markerLabelColor,
              fontSize: 11,
              fontWeight: FontWeight.w800)),
      textDirection: TextDirection.ltr,
    )..layout();
    final rect = Rect.fromLTWH(
        offset.dx - 6, offset.dy - 4, painter.width + 12, painter.height + 8);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    canvas.drawRRect(rrect, Paint()..color = markerLabelBackground);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = markerLabelBorder
        ..style = PaintingStyle.stroke,
    );
    painter.paint(canvas, offset);
  }

  void _label(Canvas canvas, TextPainter painter, String text, Offset offset) {
    painter.text =
        TextSpan(text: text, style: TextStyle(color: labelColor, fontSize: 10));
    painter.layout();
    painter.paint(canvas, offset);
  }

  double _niceStep(double value) {
    final exponent =
        math.pow(10, (math.log(value) / math.ln10).floor()).toDouble();
    final fraction = value / exponent;
    final nice = fraction <= 1
        ? 1
        : fraction <= 2
            ? 2
            : fraction <= 5
                ? 5
                : 10;
    return nice * exponent;
  }

  int _digits(double step) => step < 1
      ? 2
      : step < 10
          ? 1
          : 0;

  @override
  bool shouldRepaint(covariant GraphPainter oldDelegate) {
    return oldDelegate.functions != functions ||
        oldDelegate.viewport != viewport ||
        oldDelegate.markers != markers ||
        oldDelegate.selectedMarker != selectedMarker ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.labelColor != labelColor ||
        oldDelegate.markerLabelColor != markerLabelColor ||
        oldDelegate.markerLabelBackground != markerLabelBackground ||
        oldDelegate.markerLabelBorder != markerLabelBorder;
  }
}

class GraphViewport {
  const GraphViewport({
    required this.centerX,
    required this.centerY,
    required this.spanX,
    required this.spanY,
  });

  final double centerX;
  final double centerY;
  final double spanX;
  final double spanY;

  double get xMin => centerX - spanX / 2;
  double get xMax => centerX + spanX / 2;
  double get yMin => centerY - spanY / 2;
  double get yMax => centerY + spanY / 2;

  GraphViewport zoom(double factor) {
    final safe = factor.clamp(0.2, 5.0);
    return GraphViewport(
        centerX: centerX,
        centerY: centerY,
        spanX: (spanX * safe).clamp(0.5, 200),
        spanY: (spanY * safe).clamp(0.5, 200));
  }

  GraphViewport pan(Offset delta, Size size) {
    return GraphViewport(
      centerX: centerX - delta.dx / size.width * spanX,
      centerY: centerY + delta.dy / size.height * spanY,
      spanX: spanX,
      spanY: spanY,
    );
  }

  double toScreenX(double x, Size size) => (x - xMin) / spanX * size.width;

  double toScreenY(double y, Size size) => (yMax - y) / spanY * size.height;
}
