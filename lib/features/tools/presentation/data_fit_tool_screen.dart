import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../application/app_settings.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../data/local/app_database.dart';
import '../../../data/repositories/history_repository.dart';
import '../../../data/repositories/notes_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../domain/entities/tool_definition.dart';
import '../../../domain/usecases/data_fit.dart';
import '../../../domain/usecases/tool_save_result.dart';
import '../../../shared/presentation/app_chrome.dart';

/// 中文：数据拟合图表工具页，负责输入数据、选择模型、展示图表和残差表。
/// English: Data fitting tool screen for data entry, model selection, chart rendering, and residual table display.
class DataFitToolScreen extends StatefulWidget {
  const DataFitToolScreen({
    required this.db,
    required this.tool,
    required this.settings,
    super.key,
  });

  final AppDatabase db;
  final ToolDefinition tool;
  final AppSettings settings;

  @override
  State<DataFitToolScreen> createState() => _DataFitToolScreenState();
}

class _DataFitToolScreenState extends State<DataFitToolScreen> {
  static const _defaultData =
      '1, 2.1, 1.2\n2, 3.9, 1.8\n3, 6.2, 3.2\n4, 8.1, 5.1\n5, 10.2, 7.4\n6, 12.3, 10.9';
  static const _spreadsheetExample =
      'x,y1,y2\n1, 2, 10\n2, 4, 20\n3, 6, 30\n4, 8, 40';
  static const _localizedExample = 'x,y\n１,５０％\n２,１００％\n３,１.５\n４,２.０';
  static const _draftDataKey = 'data';
  static const _draftPredictionKey = 'prediction';
  static const _draftModelKey = 'model';
  static const _draftSeriesKey = 'series';

  late final TextEditingController _dataController;
  late final TextEditingController _predictionController;
  late final HistoryRepository _historyRepository;
  late final NotesRepository _notesRepository;
  late final SettingsRepository _settingsRepository =
      SettingsRepository(widget.db);
  FitModel _model = FitModel.linear;
  List<DataSeries> _series = const [];
  int _selectedSeriesIndex = 0;
  FitResult? _result;
  List<FitRecommendation> _recommendations = const [];
  List<String> _diagnostics = const [];
  List<FitResidualPoint> _residualAlerts = const [];
  String? _error;
  double? _predictionX;
  double? _predictionY;
  String? _predictionError;
  Timer? _recalculateTimer;
  Timer? _draftSaveTimer;
  bool _savingHistory = false;
  bool _savingNote = false;
  bool _applyingDraft = false;
  final Set<String> _locallyEditedDraftKeys = {};

  @override
  void initState() {
    super.initState();
    _dataController = TextEditingController(text: _defaultData)
      ..addListener(_scheduleRecalculate);
    _predictionController = TextEditingController()
      ..addListener(_recalculatePrediction);
    _historyRepository = HistoryRepository(widget.db);
    _notesRepository = NotesRepository(widget.db);
    _recalculate();
    if (widget.settings.restoreState) unawaited(_loadDraft());
  }

  @override
  void dispose() {
    _recalculateTimer?.cancel();
    _draftSaveTimer?.cancel();
    if (widget.settings.restoreState) unawaited(_saveDraftNow());
    _dataController.dispose();
    _predictionController.dispose();
    super.dispose();
  }

  void _scheduleRecalculate() {
    if (_applyingDraft) return;
    _locallyEditedDraftKeys.add(_draftDataKey);
    _recalculateTimer?.cancel();
    // 中文：粘贴或连续编辑数据时合并拟合计算，避免图表和表格反复重建。
    // English: Debounce fitting while pasting or editing data to avoid repeatedly rebuilding chart and table.
    _recalculateTimer = Timer(const Duration(milliseconds: 90), () {
      _recalculate();
      _scheduleDraftSave();
    });
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
      final recommendations = recommendFitModels(series[selectedIndex].points);
      final prediction = _buildPredictionState(result);
      setState(() {
        _series = series;
        _selectedSeriesIndex = selectedIndex;
        _result = result;
        _recommendations = recommendations;
        _diagnostics = buildFitDiagnostics(result);
        _residualAlerts = buildFitResidualAlerts(result);
        _predictionX = prediction.x;
        _predictionY = prediction.y;
        _predictionError = prediction.error;
        _error = null;
      });
    } catch (error) {
      final prediction = _buildPredictionState(null);
      setState(() {
        _result = null;
        _recommendations = const [];
        _diagnostics = const [];
        _residualAlerts = const [];
        _predictionX = prediction.x;
        _predictionY = prediction.y;
        _predictionError = prediction.error;
        _error = error.toString().replaceFirst('FormatException: ', '');
      });
    }
  }

  void _recalculatePrediction() {
    if (_applyingDraft) return;
    _locallyEditedDraftKeys.add(_draftPredictionKey);
    final prediction = _buildPredictionState(_result);
    setState(() {
      _predictionX = prediction.x;
      _predictionY = prediction.y;
      _predictionError = prediction.error;
    });
    _scheduleDraftSave();
  }

  Future<void> _loadDraft() async {
    final settings = await _settingsRepository.load();
    final raw = settings[dataFitDraftSettingKey(widget.tool.id)];
    final draft = decodeDataFitDraft(toolId: widget.tool.id, raw: raw);
    if (!mounted || draft == null || !widget.settings.restoreState) return;

    final applyData = !_locallyEditedDraftKeys.contains(_draftDataKey);
    final applyPrediction =
        !_locallyEditedDraftKeys.contains(_draftPredictionKey);
    final applyModel = !_locallyEditedDraftKeys.contains(_draftModelKey);
    final applySeries =
        applyData && !_locallyEditedDraftKeys.contains(_draftSeriesKey);
    if (!applyData && !applyPrediction && !applyModel && !applySeries) return;

    final series =
        _tryParseSeries(applyData ? draft.data : _dataController.text);
    final selectedSeriesIndex = draft.selectedSeriesIndex
        .clamp(
          0,
          math.max(0, series.length - 1),
        )
        .toInt();
    _recalculateTimer?.cancel();
    _applyingDraft = true;
    try {
      if (applyModel) _model = draft.model;
      if (applySeries) {
        _selectedSeriesIndex = selectedSeriesIndex;
      } else {
        _selectedSeriesIndex = _selectedSeriesIndex
            .clamp(0, math.max(0, series.length - 1))
            .toInt();
      }
      _setControllerText(_dataController, applyData ? draft.data : null);
      _setControllerText(
          _predictionController, applyPrediction ? draft.prediction : null);
    } finally {
      _applyingDraft = false;
    }
    _recalculate();
    if (_locallyEditedDraftKeys.isNotEmpty) _scheduleDraftSave();
  }

  List<DataSeries> _tryParseSeries(String data) {
    try {
      return parseDataSeries(data);
    } catch (_) {
      return const [];
    }
  }

  void _setControllerText(TextEditingController controller, String? value) {
    if (value == null || controller.text == value) return;
    controller.text = value;
    controller.selection = TextSelection.collapsed(offset: value.length);
  }

  void _scheduleDraftSave() {
    if (!widget.settings.restoreState || _applyingDraft) return;
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(
      const Duration(milliseconds: 260),
      () => unawaited(_saveDraftNow()),
    );
  }

  Future<void> _saveDraftNow() async {
    if (!widget.settings.restoreState) return;
    await _settingsRepository.set(
      dataFitDraftSettingKey(widget.tool.id),
      encodeDataFitDraft(
        DataFitDraft(
          toolId: widget.tool.id,
          data: _dataController.text,
          prediction: _predictionController.text,
          model: _model,
          selectedSeriesIndex: _selectedSeriesIndex,
        ),
      ),
    );
  }

  ({double? x, double? y, String? error}) _buildPredictionState(
      FitResult? result) {
    final text = _predictionController.text.trim();
    if (text.isEmpty) return (x: null, y: null, error: null);
    final x = parseFitNumber(text);
    if (x == null) return (x: null, y: null, error: '请输入一个 x 数值');
    if (result == null) return (x: x, y: null, error: '请先得到有效拟合结果');
    final y = predictFitValue(result, x);
    if (!y.isFinite) {
      return (x: x, y: null, error: '当前模型在这个 x 上无有效预测');
    }
    return (x: x, y: y, error: null);
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
              _animatedResult(_predictionCard(_result!), 'prediction'),
              const SizedBox(height: 12),
              _animatedResult(_recommendationCard(), 'recommendation'),
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
                IconButton(
                  tooltip: '示例数据',
                  onPressed: _showExampleMenu,
                  icon: const Icon(Icons.dataset_outlined),
                ),
                IconButton(
                  tooltip: '清空数据',
                  onPressed: _clearData,
                  icon: const Icon(Icons.backspace_outlined),
                ),
                IconButton(
                  tooltip: '粘贴',
                  onPressed: _pasteClipboard,
                  icon: const Icon(Icons.content_paste),
                ),
              ],
            ),
            SegmentedButton<FitModel>(
              segments: [
                for (final model in FitModel.values)
                  ButtonSegment(value: model, label: Text(model.label)),
              ],
              selected: {_model},
              showSelectedIcon: false,
              onSelectionChanged: (value) => _applyModel(value.first),
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
                  _locallyEditedDraftKeys.add(_draftSeriesKey);
                  setState(() => _selectedSeriesIndex = value);
                  _recalculate();
                  _scheduleDraftSave();
                },
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              key: ValueKey('data-fit-${widget.tool.id}-data'),
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
            const SizedBox(height: 10),
            _parseSummary(),
          ],
        ),
      ),
    );
  }

  Widget _parseSummary() {
    final scheme = Theme.of(context).colorScheme;
    final text = _series.isEmpty
        ? (_error ?? '尚未解析到有效数据')
        : [
            '已解析 ${_series.length} 组',
            '${_series.fold<int>(0, (sum, item) => sum + item.points.length)} 点',
            '当前 ${_series[_selectedSeriesIndex].name} ${_series[_selectedSeriesIndex].points.length} 点',
          ].join(' · ');
    return Row(
      children: [
        Icon(
          _series.isEmpty ? Icons.info_outline : Icons.check_circle_outline,
          size: 17,
          color: _series.isEmpty ? scheme.error : scheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: _series.isEmpty ? scheme.error : scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
        ),
      ],
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
    final best = _bestRecommendation;
    final bestLabel = best == null
        ? null
        : best.model == result.model
            ? '当前模型已是推荐模型'
            : '推荐尝试 ${best.model.label}';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: softPanel(context: context, highlight: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${result.model.label}拟合',
              style: TextStyle(
                  color: scheme.primary, fontWeight: FontWeight.w800)),
          if (bestLabel != null) ...[
            const SizedBox(height: 4),
            Text(bestLabel,
                style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700)),
          ],
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
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _copyEquation,
                icon: const Icon(Icons.functions, size: 18),
                label: const Text('复制方程'),
              ),
              if (_residualAlerts.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: _copyResidualAlerts,
                  icon: const Icon(Icons.report_problem_outlined, size: 18),
                  label: const Text('复制异常点'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _predictionCard(FitResult result) {
    final scheme = Theme.of(context).colorScheme;
    final hasPrediction = _predictionX != null && _predictionY != null;
    final predictionText = hasPrediction
        ? 'x=${formatNumber(_predictionX!, precision: 6)} 时，y=${formatNumber(_predictionY!, precision: 6)}'
        : (_predictionError ?? '输入 x 后实时计算预测值');
    final isOutsideRange = _predictionX == null
        ? false
        : _predictionX! < result.points.map((p) => p.x).reduce(math.min) ||
            _predictionX! > result.points.map((p) => p.x).reduce(math.max);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: SectionTitle('预测')),
                if (hasPrediction)
                  TextButton.icon(
                    onPressed: _copyPrediction,
                    icon: const Icon(Icons.copy_outlined, size: 16),
                    label: const Text('复制'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              key: ValueKey('data-fit-${widget.tool.id}-prediction'),
              controller: _predictionController,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true, signed: true),
              decoration: InputDecoration(
                labelText: '预测 x',
                hintText: '例如 7、2.5、５０％',
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: _predictionController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清空预测',
                        onPressed: _predictionController.clear,
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hasPrediction
                    ? scheme.primaryContainer.withValues(alpha: 0.32)
                    : (_predictionError == null
                        ? scheme.surfaceContainerHighest.withValues(alpha: 0.34)
                        : scheme.errorContainer.withValues(alpha: 0.24)),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: hasPrediction
                      ? scheme.primary.withValues(alpha: 0.22)
                      : (_predictionError == null
                          ? scheme.outlineVariant
                          : scheme.error.withValues(alpha: 0.24)),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    hasPrediction
                        ? Icons.trending_up
                        : (_predictionError == null
                            ? Icons.touch_app_outlined
                            : Icons.error_outline),
                    size: 18,
                    color: hasPrediction
                        ? scheme.primary
                        : (_predictionError == null
                            ? scheme.onSurfaceVariant
                            : scheme.error),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      predictionText,
                      style: TextStyle(
                        color: _predictionError == null
                            ? scheme.onSurface
                            : scheme.error,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (isOutsideRange) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_outlined,
                      size: 17, color: scheme.tertiary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '该 x 超出样本范围，属于外推估算。',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _recommendationCard() {
    final scheme = Theme.of(context).colorScheme;
    final visibleRecommendations = _recommendations.take(4).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: SectionTitle('模型建议')),
                if (_bestRecommendation != null)
                  TextButton.icon(
                    onPressed: () => _applyModel(_bestRecommendation!.model),
                    icon: const Icon(Icons.auto_fix_high, size: 16),
                    label: const Text('应用最佳'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final recommendation in visibleRecommendations)
                  ChoiceChip(
                    selected: recommendation.model == _model,
                    label: Text(_recommendationLabel(recommendation)),
                    onSelected: recommendation.available
                        ? (_) => _applyModel(recommendation.model)
                        : null,
                  ),
              ],
            ),
            if (_diagnostics.isNotEmpty) ...[
              const SizedBox(height: 12),
              ..._diagnostics.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.insights_outlined,
                          size: 17, color: scheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(line,
                            style: TextStyle(
                                color: scheme.onSurfaceVariant, height: 1.35)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (_residualAlerts.isNotEmpty) ...[
              const SizedBox(height: 8),
              _residualAlertPanel(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _residualAlertPanel() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.error.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.report_problem_outlined,
                  color: scheme.error, size: 18),
              const SizedBox(width: 8),
              Text('疑似异常点',
                  style: TextStyle(
                      color: scheme.error, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          for (final alert in _residualAlerts)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                alert.label,
                style: TextStyle(color: scheme.onSurface, height: 1.3),
              ),
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
                      residualAlerts: _residualAlerts,
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
                        _locallyEditedDraftKeys.add(_draftSeriesKey);
                        setState(() => _selectedSeriesIndex = i);
                        _recalculate();
                        _scheduleDraftSave();
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
    final isAlert = _residualAlerts.any((item) => item.index == index);
    final residualColor = residual.abs() <= result.rmse && !isAlert
        ? scheme.onSurfaceVariant
        : scheme.error;
    Text cell(String value, {Color? color}) => Text(
          value,
          style: TextStyle(
            color: color ?? scheme.onSurface,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        );
    return DataRow(
      color: WidgetStateProperty.resolveWith((states) {
        if (isAlert) {
          return scheme.errorContainer.withValues(alpha: 0.24);
        }
        return index.isEven
            ? scheme.surfaceContainerHighest.withValues(alpha: 0.22)
            : null;
      }),
      cells: [
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isAlert) ...[
                Icon(Icons.report_problem_outlined,
                    size: 15, color: scheme.error),
                const SizedBox(width: 4),
              ],
              cell('${index + 1}',
                  color: isAlert ? scheme.error : scheme.onSurfaceVariant),
            ],
          ),
        ),
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
    if (!mounted) return;
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    final paste = parseDataFitPasteText(text);
    if (!paste.hasData) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(paste.summary)),
      );
      return;
    }
    _applyPastedData(paste);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(paste.summary)),
    );
  }

  void _applyPastedData(DataFitPasteResult paste) {
    _recalculateTimer?.cancel();
    _locallyEditedDraftKeys.addAll({_draftDataKey, _draftSeriesKey});
    if (paste.model != null) _locallyEditedDraftKeys.add(_draftModelKey);
    if (paste.prediction != null) {
      _locallyEditedDraftKeys.add(_draftPredictionKey);
    }
    _model = paste.model ?? _model;
    _selectedSeriesIndex = 0;
    _dataController.text = paste.data;
    if (paste.prediction != null) {
      _predictionController.text = paste.prediction!;
    }
    _recalculate();
    _scheduleDraftSave();
  }

  void _reset() {
    _recalculateTimer?.cancel();
    _locallyEditedDraftKeys.addAll(
        {_draftDataKey, _draftPredictionKey, _draftModelKey, _draftSeriesKey});
    _applyDataSample(_defaultData, model: FitModel.linear);
  }

  void _clearData() {
    _recalculateTimer?.cancel();
    _locallyEditedDraftKeys.addAll({_draftDataKey, _draftSeriesKey});
    _dataController.clear();
    final prediction = _buildPredictionState(null);
    setState(() {
      _selectedSeriesIndex = 0;
      _series = const [];
      _result = null;
      _recommendations = const [];
      _diagnostics = const [];
      _residualAlerts = const [];
      _predictionX = prediction.x;
      _predictionY = prediction.y;
      _predictionError = prediction.error;
      _error = '请输入至少两行有效数据';
    });
    _scheduleDraftSave();
  }

  Future<void> _showExampleMenu() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.show_chart_outlined),
              title: const Text('多列示例'),
              subtitle: const Text('一列 x，多列 y，适合对比多组数据'),
              onTap: () => Navigator.pop(context, 'multi'),
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: const Text('表头示例'),
              subtitle: const Text('兼容从表格粘贴的 x,y1,y2 表头'),
              onTap: () => Navigator.pop(context, 'spreadsheet'),
            ),
            ListTile(
              leading: const Icon(Icons.percent_outlined),
              title: const Text('本地化数字示例'),
              subtitle: const Text('全角数字、百分号会自动规范化'),
              onTap: () => Navigator.pop(context, 'localized'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || selected == null) return;
    switch (selected) {
      case 'spreadsheet':
        _applyDataSample(_spreadsheetExample, model: FitModel.linear);
      case 'localized':
        _applyDataSample(_localizedExample, model: FitModel.linear);
      default:
        _applyDataSample(_defaultData, model: FitModel.linear);
    }
  }

  void _applyDataSample(String data, {required FitModel model}) {
    _recalculateTimer?.cancel();
    _locallyEditedDraftKeys
        .addAll({_draftDataKey, _draftModelKey, _draftSeriesKey});
    _model = model;
    _selectedSeriesIndex = 0;
    _dataController.text = data;
    _recalculate();
    _scheduleDraftSave();
  }

  void _applyModel(FitModel model) {
    if (_model == model) return;
    _locallyEditedDraftKeys.add(_draftModelKey);
    setState(() => _model = model);
    _recalculate();
    _scheduleDraftSave();
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
      if (_predictionCopyText() != null) ...[
        '',
        _predictionCopyText()!,
      ],
      '',
      '模型建议:',
      ..._recommendationLines(),
      '',
      '诊断:',
      ..._diagnostics,
      if (_residualAlerts.isNotEmpty) ...[
        '',
        '疑似异常点:',
        ..._residualAlerts.map((item) => item.label),
      ],
      '',
      '数据:',
      _dataController.text.trim(),
    ].join('\n');
  }

  FitRecommendation? get _bestRecommendation {
    for (final recommendation in _recommendations) {
      if (recommendation.available && recommendation.result != null) {
        return recommendation;
      }
    }
    return null;
  }

  String _recommendationLabel(FitRecommendation recommendation) {
    final result = recommendation.result;
    if (result == null) return '${recommendation.model.label}不可用';
    return '${recommendation.model.label}  R² ${formatNumber(result.rSquared, precision: 4)}';
  }

  List<String> _recommendationLines() {
    return _recommendations.take(4).map((recommendation) {
      final result = recommendation.result;
      if (result == null) {
        return '${recommendation.model.label}: ${recommendation.warning ?? '不可用'}';
      }
      return '${recommendation.model.label}: R²=${formatNumber(result.rSquared, precision: 6)}, RMSE=${formatNumber(result.rmse, precision: 6)}';
    }).toList(growable: false);
  }

  String? _predictionCopyText() {
    if (_predictionX == null || _predictionY == null) return null;
    return '预测: x=${formatNumber(_predictionX!, precision: 6)}, y=${formatNumber(_predictionY!, precision: 6)}';
  }

  Future<void> _copyEquation() async {
    final result = _result;
    if (result == null) return;
    await Clipboard.setData(ClipboardData(text: result.equation));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已复制方程')));
    }
  }

  Future<void> _copyResidualAlerts() async {
    if (_residualAlerts.isEmpty) return;
    await Clipboard.setData(ClipboardData(
      text: ['疑似异常点:', ..._residualAlerts.map((item) => item.label)].join('\n'),
    ));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已复制异常点')));
    }
  }

  Future<void> _copyPrediction() async {
    final text = _predictionCopyText();
    if (text == null) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已复制预测')));
    }
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
    _savingHistory = true;
    try {
      final save = await _saveHistoryResult();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(save.message)));
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
      final save = await _saveNoteResult();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(save.message)));
      }
    } finally {
      _savingNote = false;
    }
  }

  Future<ToolSaveResult> _saveHistoryResult() async {
    final result = _result;
    if (result == null) {
      return ToolSaveResult.inputInvalid(
        target: ToolSaveTarget.history,
        summary: _error ?? '请先得到有效拟合结果',
      );
    }
    try {
      final historyId = await _historyRepository.saveToolResult(
        toolId: widget.tool.id,
        expression: '${result.model.label}拟合: ${_dataController.text.trim()}',
        result: result.summary,
      );
      if (historyId <= 0) {
        return ToolSaveResult.notWritten(ToolSaveTarget.history);
      }
      return ToolSaveResult.savedHistory(historyId);
    } catch (error) {
      return ToolSaveResult.failed(
        target: ToolSaveTarget.history,
        error: error,
      );
    }
  }

  Future<ToolSaveResult> _saveNoteResult() async {
    if (_result == null) {
      return ToolSaveResult.inputInvalid(
        target: ToolSaveTarget.note,
        summary: _error ?? '请先得到有效拟合结果',
      );
    }
    try {
      final noteId = await _notesRepository.create(
        title: widget.tool.title,
        body: _copyText(),
        description: widget.tool.description,
      );
      if (noteId <= 0) return ToolSaveResult.notWritten(ToolSaveTarget.note);
      return ToolSaveResult.savedNote(noteId);
    } catch (error) {
      return ToolSaveResult.failed(
        target: ToolSaveTarget.note,
        error: error,
      );
    }
  }
}

class _FitChartPainter extends CustomPainter {
  const _FitChartPainter({
    required this.result,
    required this.series,
    required this.selectedSeriesIndex,
    required this.residualAlerts,
    required this.scheme,
  });

  final FitResult result;
  final List<DataSeries> series;
  final int selectedSeriesIndex;
  final List<FitResidualPoint> residualAlerts;
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
      for (var pointIndex = 0;
          pointIndex < series[seriesIndex].points.length;
          pointIndex++) {
        final point = series[seriesIndex].points[pointIndex];
        final offset = map(point);
        final isAlert = selected && _isResidualAlertPoint(point);
        if (selected) canvas.drawCircle(offset, 7.4, haloPaint);
        if (isAlert) {
          canvas.drawCircle(
            offset,
            9.6,
            Paint()
              ..color = scheme.error.withValues(alpha: 0.2)
              ..style = PaintingStyle.fill,
          );
        }
        canvas.drawCircle(offset, selected ? 4.3 : 3.4, paint);
        canvas.drawCircle(offset, selected ? 4.3 : 3.4, strokePaint);
        if (isAlert) {
          canvas.drawCircle(
            offset,
            7.1,
            Paint()
              ..color = scheme.error
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.8,
          );
        }
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
    return predictFitValue(result, x);
  }

  bool _isResidualAlertPoint(DataPoint point) {
    return residualAlerts.any(
      (alert) =>
          (alert.point.x - point.x).abs() < 1e-9 &&
          (alert.point.y - point.y).abs() < 1e-9,
    );
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
        oldDelegate.residualAlerts != residualAlerts ||
        oldDelegate.scheme != scheme;
  }
}
