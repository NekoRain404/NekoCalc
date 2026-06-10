import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../application/app_settings.dart';
import '../../../application/controllers/tool_detail_controller.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../data/local/app_database.dart';
import '../../../data/repositories/history_repository.dart';
import '../../../data/repositories/notes_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/repositories/tool_usage_repository.dart';
import '../../../domain/entities/tool_definition.dart';
import '../../../shared/presentation/app_chrome.dart';
import 'tool_widgets.dart';

/// 中文：数值型工具详情页，负责参数输入、结果展示、收藏、保存和笔记。
/// English: Detail screen for numeric tools; manages parameter input, results, favorites, history, and notes.
class ToolDetailScreen extends StatefulWidget {
  const ToolDetailScreen({
    required this.db,
    required this.tool,
    required this.settings,
    super.key,
  });

  final AppDatabase db;
  final ToolDefinition tool;
  final AppSettings settings;

  @override
  State<ToolDetailScreen> createState() => _ToolDetailScreenState();
}

class _ToolDetailScreenState extends State<ToolDetailScreen> {
  late final Map<String, TextEditingController> _controllers;
  late final ToolDetailController _detailController;
  late final SettingsRepository _settingsRepository =
      SettingsRepository(widget.db);
  Timer? _inputUpdateTimer;
  Timer? _draftSaveTimer;
  bool _savingResult = false;
  bool _savingNote = false;
  bool _favoriteBusy = false;
  bool _applyingDraft = false;
  final Set<String> _locallyEditedInputKeys = {};

  @override
  void initState() {
    super.initState();
    _detailController = ToolDetailController(
      historyRepository: HistoryRepository(widget.db),
      notesRepository: NotesRepository(widget.db),
      toolUsageRepository: ToolUsageRepository(widget.db),
      tool: widget.tool,
    )..addListener(_onControllerChanged);
    _controllers = {
      for (final entry
          in ToolDetailController.defaultInputTexts(widget.tool).entries)
        entry.key: TextEditingController(text: entry.value)
    };
    for (final entry in _controllers.entries) {
      entry.value.addListener(() => _scheduleInputUpdate(entry.key));
    }
    _detailController.loadFavorite();
    if (widget.settings.restoreState) unawaited(_loadDraft());
  }

  @override
  void dispose() {
    _inputUpdateTimer?.cancel();
    _draftSaveTimer?.cancel();
    if (widget.settings.restoreState) unawaited(_saveDraftNow());
    _detailController.removeListener(_onControllerChanged);
    _detailController.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _scheduleInputUpdate(String key) {
    if (_applyingDraft) return;
    _locallyEditedInputKeys.add(key);
    _inputUpdateTimer?.cancel();
    // 中文：多个数字输入框通常会连续变化，批量更新可以减少工程工具重复计算。
    // English: Numeric fields often change in bursts; batching reduces repeated engineering recalculations.
    _inputUpdateTimer = Timer(const Duration(milliseconds: 60), () {
      _inputUpdateTimer = null;
      _detailController.updateValues({
        for (final entry in _controllers.entries) entry.key: entry.value.text,
      });
      _scheduleDraftSave();
    });
  }

  Future<void> _loadDraft() async {
    final settings = await _settingsRepository.load();
    final raw = settings[ToolDetailController.draftSettingKey(widget.tool.id)];
    final draft = ToolDetailController.decodeDraft(
      tool: widget.tool,
      raw: raw,
    );
    if (!mounted || draft == null || !widget.settings.restoreState) {
      return;
    }
    final uneditedDraft = {
      for (final entry in draft.entries)
        if (!_locallyEditedInputKeys.contains(entry.key))
          entry.key: entry.value,
    };
    if (uneditedDraft.isEmpty) return;
    if (_locallyEditedInputKeys.isEmpty) _inputUpdateTimer?.cancel();
    _applyingDraft = true;
    try {
      final applied = _detailController.applyRawInputValues(uneditedDraft);
      for (final entry in applied.entries) {
        if (_locallyEditedInputKeys.contains(entry.key)) continue;
        final controller = _controllers[entry.key];
        if (controller == null || controller.text == entry.value) continue;
        controller.text = entry.value;
        controller.selection =
            TextSelection.collapsed(offset: controller.text.length);
      }
    } finally {
      _applyingDraft = false;
    }
  }

  void _scheduleDraftSave() {
    if (!widget.settings.restoreState) return;
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(
      const Duration(milliseconds: 240),
      () => unawaited(_saveDraftNow()),
    );
  }

  Future<void> _saveDraftNow() async {
    if (!widget.settings.restoreState) return;
    final encoded = ToolDetailController.encodeDraft(
      tool: widget.tool,
      rawValues: {
        for (final entry in _controllers.entries) entry.key: entry.value.text,
      },
    );
    await _settingsRepository.set(
      ToolDetailController.draftSettingKey(widget.tool.id),
      encoded,
    );
  }

  Future<void> _saveResult() async {
    // 中文：SQLite 写入期间忽略重复点击，保护历史记录不被刷屏。
    // English: Ignore repeated taps while SQLite is writing to keep history from being spammed.
    if (_savingResult) return;
    _savingResult = true;
    final expression = _detailController.inputSummary();
    try {
      final result = await _detailController.saveResult(expression);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(result.message)));
      }
    } finally {
      _savingResult = false;
    }
  }

  Future<void> _saveNote() async {
    if (_savingNote) return;
    _savingNote = true;
    try {
      final result = await _detailController.saveNote();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(result.message)));
      }
    } finally {
      _savingNote = false;
    }
  }

  Future<void> _toggleFavorite() async {
    // 中文：收藏切换必须串行，否则快速点击会让 UI 状态和数据库状态互相追赶。
    // English: Favorite toggles must be serialized so UI and database state do not race each other.
    if (_favoriteBusy) return;
    _favoriteBusy = true;
    try {
      await _detailController.toggleFavorite();
    } finally {
      _favoriteBusy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = _detailController.primary;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: [
            Row(
              children: [
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new)),
                Expanded(child: Center(child: PageTitle(widget.tool.title))),
                IconButton(
                  tooltip: '收藏',
                  onPressed: _toggleFavorite,
                  icon: Icon(
                      _detailController.favorite
                          ? Icons.star
                          : Icons.star_border,
                      color: _detailController.favorite ? Colors.amber : null),
                ),
                PopupMenuButton<String>(
                  tooltip: '更多',
                  icon: const Icon(Icons.more_horiz),
                  onSelected: (value) {
                    switch (value) {
                      case 'paste':
                        _pasteInputs();
                      case 'copy_inputs':
                        _copyInputs();
                      case 'copy':
                        _copyResult();
                      case 'save':
                        _saveResult();
                      case 'note':
                        _saveNote();
                      case 'reset':
                        _resetInputs();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'paste', child: Text('粘贴参数')),
                    PopupMenuItem(value: 'copy_inputs', child: Text('复制参数')),
                    PopupMenuDivider(),
                    PopupMenuItem(value: 'copy', child: Text('复制结果')),
                    PopupMenuItem(value: 'save', child: Text('保存历史')),
                    PopupMenuItem(value: 'note', child: Text('保存笔记')),
                    PopupMenuDivider(),
                    PopupMenuItem(value: 'reset', child: Text('重置输入')),
                  ],
                ),
              ],
            ),
            Text(widget.tool.description,
                style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            _inputCard(),
            const SizedBox(height: 12),
            _resultStatusCard(),
            const SizedBox(height: 12),
            if (primary != null) _primaryResult(primary),
            const SizedBox(height: 12),
            if (_detailController.results.length > 1)
              GridView.count(
                crossAxisCount: MediaQuery.sizeOf(context).width >= 520 ? 3 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio:
                    MediaQuery.sizeOf(context).width >= 520 ? 1.05 : 1.55,
                children: _detailController.results
                    .where((result) => !result.primary)
                    .map((result) => DetailMetric(
                          result: result,
                          onCopy: () => _copySingleResult(result),
                        ))
                    .toList(),
              ),
            const SizedBox(height: 12),
            _insightCard(),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionTitle('公式'),
                    Text(widget.tool.formula,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(widget.tool.explanation,
                        style: TextStyle(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: ActionButton(
                        icon: Icons.copy_outlined,
                        label: '复制',
                        onTap: _copyResult)),
                const SizedBox(width: 8),
                Expanded(
                    child: ActionButton(
                        icon: Icons.save_outlined,
                        label: '保存',
                        onTap: _saveResult)),
                const SizedBox(width: 8),
                Expanded(
                    child: ActionButton(
                        icon: Icons.refresh_outlined,
                        label: '重置',
                        onTap: _resetInputs)),
                const SizedBox(width: 8),
                Expanded(
                    child: ActionButton(
                        icon: Icons.note_add_outlined,
                        label: '笔记',
                        onTap: _saveNote)),
              ],
            ),
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
                const Expanded(child: SectionTitle('输入参数')),
                IconButton(
                  tooltip: '粘贴参数',
                  onPressed: _pasteInputs,
                  icon: const Icon(Icons.content_paste_outlined),
                ),
                IconButton(
                  tooltip: '复制参数',
                  onPressed: _copyInputs,
                  icon: const Icon(Icons.copy_all_outlined),
                ),
                TextButton(
                  onPressed: _resetInputs,
                  child: const Text('重置'),
                ),
              ],
            ),
            if (widget.tool.inputs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('该工具无需数字参数，请使用上方结果和操作按钮完成复制、保存或笔记记录。'),
              )
            else
              ...widget.tool.inputs.map((input) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _inputRow(input),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _inputRow(ToolInputDefinition input) {
    final controller = _controllers[input.key]!;
    final scheme = Theme.of(context).colorScheme;
    final error = _detailController.inputErrors[input.key];
    final clearsInput = input.optional || input.defaultValue == null;
    return Row(
      children: [
        Expanded(
            flex: 3,
            child: Text(input.optional ? '${input.label}（可选）' : input.label)),
        const SizedBox(width: 8),
        _stepButton(
          icon: Icons.remove,
          tooltip: '减小',
          onTap: () => _stepInput(input, -1),
        ),
        const SizedBox(width: 4),
        Expanded(
          flex: 4,
          child: TextField(
            key: ValueKey('tool-input-${widget.tool.id}-${input.key}'),
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(
                decimal: true, signed: true),
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              isDense: true,
              suffixText: input.unit,
              errorText: error,
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: clearsInput ? '清空' : '恢复默认',
                      onPressed: () => _setInputValue(
                          input, clearsInput ? null : input.defaultValue),
                      icon: Icon(
                        clearsInput ? Icons.clear : Icons.restart_alt,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        _stepButton(
          icon: Icons.add,
          tooltip: '增大',
          onTap: () => _stepInput(input, 1),
        ),
      ],
    );
  }

  Widget _stepButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 34,
      height: 34,
      child: IconButton.filledTonal(
        tooltip: tooltip,
        onPressed: onTap,
        padding: EdgeInsets.zero,
        iconSize: 18,
        icon: Icon(icon),
      ),
    );
  }

  void _resetInputs() {
    _inputUpdateTimer?.cancel();
    for (final input in widget.tool.inputs) {
      _controllers[input.key]?.text =
          input.defaultValue == null ? '' : formatNumber(input.defaultValue!);
    }
    _detailController.resetValues();
    _scheduleDraftSave();
  }

  Future<void> _pasteInputs() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = data?.text;
    if (text == null || text.trim().isEmpty) return;
    final pasteResult = ToolDetailController.inputPasteResultFromPastedText(
      tool: widget.tool,
      input: text,
    );
    if (!pasteResult.hasValues) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(pasteResult.summaryForTool(widget.tool))),
      );
      return;
    }
    final applyResult = _detailController.applyInputPasteResult(pasteResult);
    _applyInputTexts(applyResult.inputTexts, keys: applyResult.filledKeys);
    _locallyEditedInputKeys.addAll(applyResult.filledKeys);
    _scheduleDraftSave();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(applyResult.summaryForTool(widget.tool))),
    );
  }

  void _applyInputTexts(
    Map<String, String> values, {
    Iterable<String>? keys,
  }) {
    _inputUpdateTimer?.cancel();
    _applyingDraft = true;
    try {
      final targetKeys = keys?.toSet() ?? values.keys.toSet();
      for (final key in targetKeys) {
        final controller = _controllers[key];
        final value = values[key];
        if (controller == null || value == null || controller.text == value) {
          continue;
        }
        controller.text = value;
        controller.selection = TextSelection.collapsed(offset: value.length);
      }
    } finally {
      _applyingDraft = false;
    }
  }

  void _setInputValue(ToolInputDefinition input, double? value) {
    _controllers[input.key]?.text = value == null ? '' : formatNumber(value);
  }

  void _stepInput(ToolInputDefinition input, int direction) {
    final controller = _controllers[input.key];
    if (controller == null) return;
    final current = ToolDetailController.parseNumericInputForUnit(
                controller.text, input.unit)
            .value ??
        0;
    final step = _stepSize(input, current);
    final next = current + step * direction;
    controller.text = formatNumber(next, precision: 8);
    controller.selection =
        TextSelection.collapsed(offset: controller.text.length);
  }

  double _stepSize(ToolInputDefinition input, double current) {
    final reference =
        current == 0 ? (input.defaultValue ?? 1).abs() : current.abs();
    if (reference >= 1000) return 100;
    if (reference >= 100) return 10;
    if (reference >= 10) return 1;
    if (reference >= 1) return 0.1;
    if (reference >= 0.1) return 0.01;
    return 0.001;
  }

  Future<void> _copyResult() async {
    if (_detailController.hasInputErrors) {
      _showInputErrorSnack();
      return;
    }
    await Clipboard.setData(ClipboardData(text: _detailController.copyText()));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已复制结果')));
    }
  }

  Future<void> _copyInputs() async {
    await Clipboard.setData(
      ClipboardData(text: _detailController.inputCopyText()),
    );
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已复制输入参数')));
    }
  }

  Future<void> _copySingleResult(ToolResult result) async {
    if (_detailController.hasInputErrors) {
      _showInputErrorSnack();
      return;
    }
    await Clipboard.setData(
        ClipboardData(text: _detailController.singleResultCopyText(result)));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('已复制${result.label}')));
    }
  }

  void _showInputErrorSnack() {
    final summary = _detailController.inputErrorSummary();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          summary.isEmpty ? '请先修正输入参数' : '请先修正输入参数：$summary',
        ),
      ),
    );
  }

  Widget _resultStatusCard() {
    final scheme = Theme.of(context).colorScheme;
    final hasInputErrors = _detailController.hasInputErrors;
    final hasResultIssues = _detailController.hasResultIssues;
    final color = hasInputErrors
        ? scheme.error
        : hasResultIssues
            ? Colors.orange.shade700
            : scheme.primary;
    final icon = hasInputErrors
        ? Icons.error_outline
        : hasResultIssues
            ? Icons.report_problem_outlined
            : Icons.verified_outlined;
    final title = hasInputErrors
        ? '输入需要修正'
        : hasResultIssues
            ? '结果需要检查'
            : '结果可复用';
    final details = hasInputErrors
        ? _detailController.inputErrorSummary()
        : hasResultIssues
            ? _detailController.resultIssueSummary()
            : _detailController.resultHealthSummary();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: softPanel(context: context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: color,
                        fontSize: 14,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(details,
                    style: TextStyle(
                        color: hasInputErrors || hasResultIssues
                            ? scheme.onSurface
                            : scheme.onSurfaceVariant,
                        height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryResult(ToolResult primary) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: softPanel(context: context, highlight: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(primary.label,
                    style: TextStyle(
                        color: scheme.primary, fontWeight: FontWeight.w700)),
              ),
              IconButton.filledTonal(
                tooltip: '复制主结果',
                onPressed: () => _copySingleResult(primary),
                iconSize: 18,
                icon: const Icon(Icons.copy_outlined),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  primary.value,
                  style: TextStyle(
                      color: scheme.primary,
                      fontSize: 34,
                      fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(primary.unit,
                    style: TextStyle(color: scheme.onSurfaceVariant)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _insightCard() {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('校核'),
            ..._detailController.insights.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 17, color: scheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(item,
                            style: TextStyle(
                                color: scheme.onSurfaceVariant, height: 1.35))),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
