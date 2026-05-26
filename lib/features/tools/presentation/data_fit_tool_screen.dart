import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/number_formatter.dart';
import '../../../data/local/app_database.dart';
import '../../../data/repositories/history_repository.dart';
import '../../../data/repositories/notes_repository.dart';
import '../../../domain/entities/tool_definition.dart';
import '../../../domain/usecases/data_fit.dart';
import '../../../shared/presentation/app_chrome.dart';

/// 中文：数据拟合图表工具页，负责输入数据、选择模型、展示图表和残差表。
/// English: Data fitting tool screen for data entry, model selection, chart rendering, and residual table display.
class DataFitToolScreen extends StatefulWidget {
  const DataFitToolScreen({
    required this.db,
    required this.tool,
    super.key,
  });

  final AppDatabase db;
  final ToolDefinition tool;

  @override
  State<DataFitToolScreen> createState() => _DataFitToolScreenState();
}

class _DataFitToolScreenState extends State<DataFitToolScreen> {
  late final TextEditingController _dataController;
  late final HistoryRepository _historyRepository;
  late final NotesRepository _notesRepository;
  FitModel _model = FitModel.linear;
  List<DataSeries> _series = const [];
  int _selectedSeriesIndex = 0;
  FitResult? _result;
  String? _error;
  Timer? _recalculateTimer;
  bool _savingHistory = false;
  bool _savingNote = false;

  @override
  void initState() {
    super.initState();
    _dataController = TextEditingController(
      text:
          '1, 2.1, 1.2\n2, 3.9, 1.8\n3, 6.2, 3.2\n4, 8.1, 5.1\n5, 10.2, 7.4\n6, 12.3, 10.9',
    )..addListener(_scheduleRecalculate);
    _historyRepository = HistoryRepository(widget.db);
    _notesRepository = NotesRepository(widget.db);
    _recalculate();
  }

  @override
  void dispose() {
    _recalculateTimer?.cancel();
    _dataController.dispose();
    super.dispose();
  }

  void _scheduleRecalculate() {
    _recalculateTimer?.cancel();
    // 中文：粘贴或连续编辑数据时合并拟合计算，避免图表和表格反复重建。
    // English: Debounce fitting while pasting or editing data to avoid repeatedly rebuilding chart and table.
    _recalculateTimer = Timer(const Duration(milliseconds: 90), _recalculate);
  }

  void _recalculate() {
    _recalculateTimer?.cancel();
    _recalculateTimer = null;
    try {
      // 中文：输入解析支持单组、多列和空行分组，UI 只关心当前选中序列。
      // English: Parsing supports single-series, multi-column, and blank-line groups; the UI only fits the selected series.
      final series = parseDataSeries(_dataController.text);
      if (series.isEmpty) {
        throw const FormatException('请输入至少两行有效数据');
      }
      final selectedIndex = _selectedSeriesIndex.clamp(0, series.length - 1);
      final result = fitData(series[selectedIndex].points, _model);
      setState(() {
        _series = series;
        _selectedSeriesIndex = selectedIndex;
        _result = result;
        _error = null;
      });
    } catch (error) {
      setState(() {
        _result = null;
        _error = error.toString().replaceFirst('FormatException: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: [
            Row(
              children: [
                IconToolButton(
                  icon: Icons.arrow_back_ios_new,
                  tooltip: '返回',
                  onTap: () => Navigator.pop(context),
                ),
                Expanded(child: Center(child: PageTitle(widget.tool.title))),
                IconToolButton(
                  icon: Icons.refresh_outlined,
                  tooltip: '重置',
                  onTap: _reset,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(widget.tool.description,
                style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            _inputCard(),
            const SizedBox(height: 12),
            if (_result != null) ...[
              _animatedResult(_resultCard(_result!), 'result'),
              const SizedBox(height: 12),
              _animatedResult(_chartCard(_result!), 'chart'),
              const SizedBox(height: 12),
              _animatedResult(_dataTableCard(_result!), 'table'),
            ] else
              EmptyPanel(_error ?? '请输入至少两行有效数据。'),
            const SizedBox(height: 12),
            _actions(),
          ],
        ),
      ),
    );
  }

  Widget _inputCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: SectionTitle('数据与模型')),
                TextButton(onPressed: _pasteClipboard, child: const Text('粘贴')),
              ],
            ),
            SegmentedButton<FitModel>(
              segments: [
                for (final model in FitModel.values)
                  ButtonSegment(value: model, label: Text(model.label)),
              ],
              selected: {_model},
              showSelectedIcon: false,
              onSelectionChanged: (value) {
                setState(() => _model = value.first);
                _recalculate();
              },
            ),
            if (_series.length > 1) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                initialValue: _selectedSeriesIndex.clamp(0, _series.length - 1),
                decoration: const InputDecoration(
                  labelText: '拟合数据组',
                  isDense: true,
                ),
                items: [
                  for (var i = 0; i < _series.length; i++)
                    DropdownMenuItem(
                      value: i,
                      child: Text(
                          '${_series[i].name} · ${_series[i].points.length} 点'),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedSeriesIndex = value);
                  _recalculate();
                },
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _dataController,
              minLines: 7,
              maxLines: 12,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(
                labelText: '数据列表',
                hintText:
                    '支持 x,y；x,y1,y2 多列；空行分隔多组。\n例如：\n1, 2.1, 1.2\n2, 3.9, 1.8\n\n1, 8\n2, 13',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _animatedResult(Widget child, String key) {
    final result = _result;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: KeyedSubtree(
        key: ValueKey(
            '$key-${_model.name}-$_selectedSeriesIndex-${result?.equation ?? ''}'),
        child: child,
      ),
    );
  }

  Widget _resultCard(FitResult result) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: softPanel(context: context, highlight: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${result.model.label}拟合',
              style: TextStyle(
                  color: scheme.primary, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          SelectableText(
            result.equation,
            style: TextStyle(
                color: scheme.primary,
                fontSize: 22,
                fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metricChip('R²', formatNumber(result.rSquared, precision: 6)),
              _metricChip('RMSE', formatNumber(result.rmse, precision: 6)),
              _metricChip('点数', result.points.length.toString()),
              if (_series.isNotEmpty)
                _metricChip('数据组', _series[_selectedSeriesIndex].name),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricChip(String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Text('$label  $value',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }

  Widget _chartCard(FitResult result) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('图表'),
            const SizedBox(height: 8),
            AspectRatio(
              aspectRatio: 1.55,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: CustomPaint(
                    painter: _FitChartPainter(
                      result: result,
                      series: _series,
                      selectedSeriesIndex: _selectedSeriesIndex,
                      scheme: scheme,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dataTableCard(FitResult result) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: SectionTitle('数据表')),
                Text(
                  '当前组 ${result.points.length} 行',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: scheme.outlineVariant),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 38,
                    dataRowMinHeight: 36,
                    dataRowMaxHeight: 42,
                    columnSpacing: 18,
                    headingTextStyle: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                    columns: const [
                      DataColumn(label: Text('#')),
                      DataColumn(label: Text('x')),
                      DataColumn(label: Text('y')),
                      DataColumn(label: Text('ŷ')),
                      DataColumn(label: Text('残差')),
                    ],
                    rows: [
                      for (var i = 0; i < result.points.length; i++)
                        _tableRow(result, i, scheme),
                    ],
                  ),
                ),
              ),
            ),
            if (_series.length > 1) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < _series.length; i++)
                    ChoiceChip(
                      selected: i == _selectedSeriesIndex,
                      label: Text(
                          '${_series[i].name} (${_series[i].points.length})'),
                      onSelected: (_) {
                        setState(() => _selectedSeriesIndex = i);
                        _recalculate();
                      },
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  DataRow _tableRow(FitResult result, int index, ColorScheme scheme) {
    final point = result.points[index];
    final predicted = result.predictions[index].y;
    final residual = point.y - predicted;
    final residualColor =
        residual.abs() <= result.rmse ? scheme.onSurfaceVariant : scheme.error;
    Text cell(String value, {Color? color}) => Text(
          value,
          style: TextStyle(
            color: color ?? scheme.onSurface,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        );
    return DataRow(
      color: WidgetStateProperty.resolveWith((states) {
        return index.isEven
            ? scheme.surfaceContainerHighest.withValues(alpha: 0.22)
            : null;
      }),
      cells: [
        DataCell(cell('${index + 1}', color: scheme.onSurfaceVariant)),
        DataCell(cell(formatNumber(point.x, precision: 6))),
        DataCell(cell(formatNumber(point.y, precision: 6))),
        DataCell(cell(formatNumber(predicted, precision: 6))),
        DataCell(
            cell(formatNumber(residual, precision: 6), color: residualColor)),
      ],
    );
  }

  Widget _actions() {
    // 中文：复制、保存历史、保存笔记保持同一行，符合工具页统一操作区。
    // English: Copy, save history, and save note share one row to match the common tool action layout.
    return Row(
      children: [
        Expanded(
          child: ActionButton(
            icon: Icons.copy_outlined,
            label: '复制',
            onTap: _copyResult,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ActionButton(
            icon: Icons.save_outlined,
            label: '保存',
            onTap: _saveHistory,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ActionButton(
            icon: Icons.note_add_outlined,
            label: '笔记',
            onTap: _saveNote,
          ),
        ),
      ],
    );
  }

  Future<void> _pasteClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    _dataController.text = text;
  }

  void _reset() {
    _recalculateTimer?.cancel();
    _model = FitModel.linear;
    _selectedSeriesIndex = 0;
    _dataController.text =
        '1, 2.1, 1.2\n2, 3.9, 1.8\n3, 6.2, 3.2\n4, 8.1, 5.1\n5, 10.2, 7.4\n6, 12.3, 10.9';
    _recalculate();
  }

  String _copyText() {
    final result = _result;
    if (result == null) return _error ?? '无有效拟合结果';
    // 中文：复制内容包含原始数据，便于把拟合结论贴到笔记或外部文档后仍可复核。
    // English: Copied text includes raw data so the fitted result remains auditable in notes or external docs.
    return [
      widget.tool.title,
      if (_series.isNotEmpty) '数据组: ${_series[_selectedSeriesIndex].name}',
      result.summary,
      '',
      '数据:',
      _dataController.text.trim(),
    ].join('\n');
  }

  Future<void> _copyResult() async {
    await Clipboard.setData(ClipboardData(text: _copyText()));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已复制结果')));
    }
  }

  Future<void> _saveHistory() async {
    // 中文：保存动作防重入，避免快速连点生成重复历史记录。
    // English: Guard save action re-entry to prevent duplicate history rows from rapid taps.
    if (_savingHistory) return;
    final result = _result;
    if (result == null) return;
    _savingHistory = true;
    try {
      await _historyRepository.saveToolResult(
        toolId: widget.tool.id,
        expression: '${result.model.label}拟合: ${_dataController.text.trim()}',
        result: result.summary,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('结果已保存到 SQLite 历史记录')));
      }
    } finally {
      _savingHistory = false;
    }
  }

  Future<void> _saveNote() async {
    // 中文：笔记写入可能经过 SQLite，快速连点时只保留第一个请求。
    // English: Note writes go through SQLite; rapid repeated taps keep only the first request.
    if (_savingNote) return;
    _savingNote = true;
    try {
      await _notesRepository.create(
        title: widget.tool.title,
        body: _copyText(),
        description: widget.tool.description,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已保存到笔记')));
      }
    } finally {
      _savingNote = false;
    }
  }
}

class _FitChartPainter extends CustomPainter {
  const _FitChartPainter({
    required this.result,
    required this.series,
    required this.selectedSeriesIndex,
    required this.scheme,
  });

  final FitResult result;
  final List<DataSeries> series;
  final int selectedSeriesIndex;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    const padding = EdgeInsets.fromLTRB(52, 22, 20, 42);
    final dark = scheme.brightness == Brightness.dark;
    final backgroundColor = scheme.surface;
    final plotColor = scheme.surface;
    final labelColor = scheme.onSurface;
    final mutedLabelColor = scheme.onSurfaceVariant;
    final gridColor =
        scheme.outlineVariant.withValues(alpha: dark ? 0.52 : 0.62);
    final borderColor = scheme.outlineVariant;
    final labelBackground =
        scheme.surface.withValues(alpha: dark ? 0.92 : 0.96);
    final legendBackground =
        scheme.surface.withValues(alpha: dark ? 0.94 : 0.97);
    final plot = Rect.fromLTWH(
      padding.left,
      padding.top,
      size.width - padding.horizontal,
      size.height - padding.vertical,
    );
    final allPoints = [
      for (final item in series) ...item.points,
      ...result.predictions,
    ];
    // 中文：坐标范围同时纳入原始点和预测点，保证拟合曲线不会被裁掉。
    // English: Axis bounds include both raw points and predictions so the fitted curve is not clipped.
    final minX = allPoints.map((p) => p.x).reduce(math.min);
    final maxX = allPoints.map((p) => p.x).reduce(math.max);
    final minY = allPoints.map((p) => p.y).reduce(math.min);
    final maxY = allPoints.map((p) => p.y).reduce(math.max);
    final xRange = (maxX - minX).abs() < 1e-9 ? 1.0 : maxX - minX;
    final yRange = (maxY - minY).abs() < 1e-9 ? 1.0 : maxY - minY;

    Offset map(DataPoint p) {
      final x = plot.left + (p.x - minX) / xRange * plot.width;
      final y = plot.bottom - (p.y - minY) / yRange * plot.height;
      return Offset(x, y);
    }

    final chartBackground = Paint()..color = backgroundColor;
    canvas.drawRect(Offset.zero & size, chartBackground);

    final plotBackground = Paint()..color = plotColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(plot, const Radius.circular(8)),
      plotBackground,
    );

    final axisPaint = Paint()
      ..color = borderColor
      ..strokeWidth = 1.4;
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.65;
    final zeroAxisPaint = Paint()
      ..color = scheme.primary.withValues(alpha: dark ? 0.86 : 0.68)
      ..strokeWidth = 1.3;
    final lineShadowPaint = Paint()
      ..color = scheme.primary.withValues(alpha: 0.28)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final linePaint = Paint()
      ..color = scheme.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (var i = 0; i <= 5; i++) {
      // 中文：固定 5 等分网格，移动端上标签密度稳定，避免小屏拥挤。
      // English: A fixed five-step grid keeps label density stable and avoids crowding on phones.
      final xValue = minX + xRange * i / 5;
      final yValue = minY + yRange * i / 5;
      final x = plot.left + plot.width * i / 5;
      final y = plot.bottom - plot.height * i / 5;
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), gridPaint);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      _drawLabel(canvas, Offset(x - 14, plot.bottom + 7),
          formatNumber(xValue, precision: 3), scheme,
          color: mutedLabelColor, backgroundColor: labelBackground);
      _drawLabel(
          canvas, Offset(6, y - 7), formatNumber(yValue, precision: 3), scheme,
          color: mutedLabelColor, backgroundColor: labelBackground);
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(plot, const Radius.circular(8)),
      axisPaint,
    );
    if (minX <= 0 && maxX >= 0) {
      final zeroX = plot.left + (0 - minX) / xRange * plot.width;
      canvas.drawLine(
          Offset(zeroX, plot.top), Offset(zeroX, plot.bottom), zeroAxisPaint);
    }
    if (minY <= 0 && maxY >= 0) {
      final zeroY = plot.bottom - (0 - minY) / yRange * plot.height;
      canvas.drawLine(
          Offset(plot.left, zeroY), Offset(plot.right, zeroY), zeroAxisPaint);
    }

    final lineMinX = result.points.map((p) => p.x).reduce(math.min);
    final lineMaxX = result.points.map((p) => p.x).reduce(math.max);
    // 中文：拟合曲线只在样本 x 范围内绘制，避免外推线误导用户。
    // English: Draw the fit only across the sampled x-range to avoid misleading extrapolation.
    final linePoints = _sampleFit(lineMinX, lineMaxX);
    final path = Path();
    for (var i = 0; i < linePoints.length; i++) {
      final offset = map(linePoints[i]);
      if (i == 0) {
        path.moveTo(offset.dx, offset.dy);
      } else {
        path.lineTo(offset.dx, offset.dy);
      }
    }
    canvas.drawPath(path, lineShadowPaint);
    canvas.drawPath(path, linePaint);

    for (var seriesIndex = 0; seriesIndex < series.length; seriesIndex++) {
      final selected = seriesIndex == selectedSeriesIndex;
      final paint = Paint()
        ..color = _seriesColor(seriesIndex, selected)
        ..style = PaintingStyle.fill;
      final strokePaint = Paint()
        ..color = selected ? scheme.onSurface : scheme.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 1.7 : 1;
      final haloPaint = Paint()
        ..color = _seriesColor(seriesIndex, selected).withValues(alpha: 0.18)
        ..style = PaintingStyle.fill;
      for (final point in series[seriesIndex].points) {
        final offset = map(point);
        if (selected) canvas.drawCircle(offset, 7.4, haloPaint);
        canvas.drawCircle(offset, selected ? 4.3 : 3.4, paint);
        canvas.drawCircle(offset, selected ? 4.3 : 3.4, strokePaint);
      }
    }

    _drawLegend(canvas, plot, scheme,
        labelColor: labelColor,
        mutedLabelColor: mutedLabelColor,
        backgroundColor: legendBackground);
  }

  List<DataPoint> _sampleFit(double minX, double maxX) {
    final points = <DataPoint>[];
    const steps = 64;
    // 中文：64 个采样点在平滑度和绘制成本之间足够均衡。
    // English: Sixty-four samples balance smoothness and painting cost.
    for (var i = 0; i <= steps; i++) {
      final x = minX + (maxX - minX) * i / steps;
      points.add(DataPoint(x, _predict(x)));
    }
    return points;
  }

  double _predict(double x) {
    final c = result.coefficients;
    return switch (result.model) {
      FitModel.linear => c[0] * x + c[1],
      FitModel.quadratic => c[0] * x * x + c[1] * x + c[2],
      FitModel.exponential => c[0] * math.exp(c[1] * x),
      FitModel.power => c[0] * math.pow(x, c[1]).toDouble(),
      FitModel.logarithmic => x <= 0 ? double.nan : c[0] * math.log(x) + c[1],
      FitModel.reciprocal => x == 0 ? double.nan : c[0] / x + c[1],
    };
  }

  void _drawLabel(
    Canvas canvas,
    Offset offset,
    String text,
    ColorScheme scheme, {
    required Color color,
    Color? backgroundColor,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    if (backgroundColor != null) {
      final rect = Rect.fromLTWH(
        offset.dx - 3,
        offset.dy - 2,
        painter.width + 6,
        painter.height + 4,
      );
      final paint = Paint()..color = backgroundColor;
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)), paint);
    }
    painter.paint(canvas, offset);
  }

  Color _seriesColor(int index, bool selected) {
    final colors = [
      scheme.tertiary,
      const Color(0xFFFF8A00),
      const Color(0xFF23B45D),
      const Color(0xFF8B5CF6),
      const Color(0xFFFF4D5E),
    ];
    final color = colors[index % colors.length];
    return selected ? color : color.withValues(alpha: 0.42);
  }

  void _drawLegend(
    Canvas canvas,
    Rect plot,
    ColorScheme scheme, {
    required Color labelColor,
    required Color mutedLabelColor,
    required Color backgroundColor,
  }) {
    final maxItems = math.min(series.length, 4);
    var dx = plot.left + 8;
    final y = plot.top + 8;
    for (var i = 0; i < maxItems; i++) {
      final selected = i == selectedSeriesIndex;
      final paint = Paint()
        ..color = _seriesColor(i, selected)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(dx + 5, y + 5), 4, paint);
      final label = selected ? '${series[i].name} 拟合' : series[i].name;
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: selected ? labelColor : mutedLabelColor,
            fontSize: 10,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 78);
      final chipRect = Rect.fromLTWH(
        dx - 4,
        y - 3,
        painter.width + 24,
        painter.height + 7,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(chipRect, const Radius.circular(6)),
        Paint()..color = backgroundColor,
      );
      painter.paint(canvas, Offset(dx + 13, y));
      dx += painter.width + 26;
      if (dx > plot.right - 56) break;
    }
  }

  @override
  bool shouldRepaint(covariant _FitChartPainter oldDelegate) {
    return oldDelegate.result != result ||
        oldDelegate.series != series ||
        oldDelegate.selectedSeriesIndex != selectedSeriesIndex ||
        oldDelegate.scheme != scheme;
  }
}
