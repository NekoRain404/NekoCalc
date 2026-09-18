import 'dart:async';
import 'fit_chart_painter.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../application/app_settings.dart';
import '../../../core/platform/document_export_channel.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../core/utils/render_export.dart';
import '../../../data/local/app_database.dart';
import '../../../data/repositories/history_repository.dart';
import '../../../data/repositories/notes_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../domain/entities/tool_definition.dart';
import '../../../domain/usecases/data_fit.dart';
import '../../../domain/usecases/tool_save_result.dart';
import '../../../shared/presentation/app_chrome.dart';
import 'data_fit_strings.dart';

part 'data_fit_cards.dart';
part 'data_fit_actions.dart';

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
  final GlobalKey _chartBoundaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _dataController = TextEditingController(text: _defaultData)
      ..addListener(_scheduleRecalculate);
    _predictionController = TextEditingController()
      ..addListener(_recalculatePrediction);
    _historyRepository = HistoryRepository(widget.db);
    _notesRepository = NotesRepository(widget.db);
    if (widget.settings.restoreState) unawaited(_loadDraft());
  }

  /// 中文：第一次计算推迟到这里跑，**不能留在 `initState` 里**——它要取 `DataFitStrings`，而
  ///       在 `initState` 阶段查祖先里的 `AppLanguageScope` 在 debug 构建里会直接抛
  ///       （`dependOnInheritedWidgetOfExactType` 在 `initState` 未完成时是禁止的；真实 App 里
  ///       `app.dart` 一定装了那个作用域，所以这不是理论问题——`tools_strings_test.dart` 里那两条
  ///       装作用域的用例就是为此加的）。`didChangeDependencies` 在 `initState` 之后、第一次
  ///       `build` 之前跑，屏幕上看不出先后差别。
  /// English: The first calculation runs here rather than in `initState`, because it reads
  ///          `DataFitStrings`, and looking up an ancestor `AppLanguageScope` while `initState` is
  ///          still running throws in debug builds (`dependOnInheritedWidgetOfExactType` is
  ///          forbidden there). That is not theoretical: `app.dart` always installs that scope, and
  ///          the two scope-installing cases in `tools_strings_test.dart` exist for exactly this.
  ///          `didChangeDependencies` runs after `initState` and before the first `build`, so nothing
  ///          on screen can tell the difference.
  bool _calculatedOnce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_calculatedOnce) return;
    _calculatedOnce = true;
    _recalculate();
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
        // 中文：异常里带的是**那一刻**取到的文案（与 `_error` 一样）。切换界面语言不会回填已经
        //       存下来的那句话，要等下一次重算——这是已知的小口子，不是漏翻。
        // English: The exception carries the copy **as of that moment**, exactly like `_error`.
        //          Switching the interface language does not rewrite an already-stored sentence; the
        //          next recalculation does. A known small gap, not a missed translation.
        throw FormatException(DataFitStrings.of(context).needTwoRows);
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
    final strings = DataFitStrings.of(context);
    final text = _predictionController.text.trim();
    if (text.isEmpty) return (x: null, y: null, error: null);
    final x = parseFitNumber(text);
    if (x == null) return (x: null, y: null, error: strings.invalidX);
    if (result == null) return (x: x, y: null, error: strings.needFitFirst);
    final y = predictFitValue(result, x);
    if (!y.isFinite) {
      return (x: x, y: null, error: strings.noPrediction);
    }
    return (x: x, y: y, error: null);
  }

  @override
  Widget build(BuildContext context) {
    final strings = DataFitStrings.of(context);
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
                  tooltip: strings.back,
                  onTap: () => Navigator.pop(context),
                ),
                Expanded(child: Center(child: PageTitle(widget.tool.title))),
                IconToolButton(
                  icon: Icons.refresh_outlined,
                  tooltip: strings.reset,
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
              EmptyPanel(_error ?? strings.needTwoRowsPanel),
            const SizedBox(height: 12),
            _actions(),
          ],
        ),
      ),
    );
  }

  /// 中文：切换当前拟合的数据组。数据组下拉框与数据表下方的胶囊走同一条通路，所以这条状态更新
  ///       只有一个落点（两处原本各写了一遍同样的四行）。
  /// English: Switch which parsed series is fitted. The series dropdown and the chips under the data
  ///          table travel one path, so this state update has a single home (the two call sites used to
  ///          repeat the same four lines).
  void _selectSeriesIndex(int index) {
    _locallyEditedDraftKeys.add(_draftSeriesKey);
    setState(() => _selectedSeriesIndex = index);
    _recalculate();
    _scheduleDraftSave();
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
    final strings = DataFitStrings.of(context);
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
      _error = strings.needTwoRows;
    });
    _scheduleDraftSave();
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
}
