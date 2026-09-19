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
import 'tool_catalog_strings.dart';
import 'tool_detail_strings.dart';
import 'tool_field_strings.dart';
import 'tool_result_label_strings.dart';
import 'tool_widgets.dart';
import 'tools_strings.dart';

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
      strings: ToolDetailStrings.forCode(widget.settings.languageCode),
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _detailController.strings = ToolDetailStrings.of(context);
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
    final strings = ToolsStrings.of(context);
    // 中文：页头那行是**目录表里的名字**，不是 `widget.tool.title`——后者是内容数据；下面那行说明
    //       同理走目录表，与名字取自同一次 `of(context)`。
    // English: the page head shows the **catalogue table’s name**, not `widget.tool.title` —
    //          the latter is content data; the description below it comes from the catalogue table too,
    //          out of the same `of(context)` call as the name.
    final catalog = ToolCatalogStrings.of(context);
    // 中文：公式、解释、参数标签与单位取自 `ToolFieldStrings`（本轮新表），与上面两张表同一套分派。
    // English: the formula, the explanation, the parameter labels and the units come from
    //          `ToolFieldStrings` (this round's table), dispatched the same way as the two above.
    final fields = ToolFieldStrings.of(context);
    final toolTitle = catalog.toolName(widget.tool.id);
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
                Expanded(child: Center(child: PageTitle(toolTitle))),
                IconButton(
                  tooltip: strings.favoriteAdd,
                  onPressed: _toggleFavorite,
                  icon: Icon(
                      _detailController.favorite
                          ? Icons.star
                          : Icons.star_border,
                      color: _detailController.favorite ? Colors.amber : null),
                ),
                PopupMenuButton<String>(
                  tooltip: strings.more,
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
                  itemBuilder: (context) => [
                    PopupMenuItem(
                        value: 'paste', child: Text(strings.pasteInputs)),
                    PopupMenuItem(
                        value: 'copy_inputs', child: Text(strings.copyInputs)),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                        value: 'copy', child: Text(strings.copyResult)),
                    PopupMenuItem(
                        value: 'save', child: Text(strings.saveHistory)),
                    PopupMenuItem(value: 'note', child: Text(strings.saveNote)),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                        value: 'reset', child: Text(strings.resetInputs)),
                  ],
                ),
              ],
            ),
            Text(catalog.toolDescription(widget.tool.id),
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
                    // 中文：公式与解释两行取自 `ToolFieldStrings`，**目录里那两个字段仍是中文**
                    //       （检索读的就是它们，本轮一个字节没动）：认得出的字串查表，
                    //       认不出的原样返回，所以没有汉字的公式在两种语言下一模一样。
                    // English: the formula and the explanation come from `ToolFieldStrings`, while
                    //          **the catalogue's two fields stay Chinese** (search reads those, and not
                    //          one byte moved): a recognised string is looked up and anything else comes
                    //          back unchanged, so a formula with no Han character reads the same in
                    //          both languages.
                    SectionTitle(strings.formula),
                    Text(fields.formula(widget.tool.formula),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(fields.explanation(widget.tool.explanation),
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
                        label: strings.copy,
                        onTap: _copyResult)),
                const SizedBox(width: 8),
                Expanded(
                    child: ActionButton(
                        icon: Icons.save_outlined,
                        label: strings.save,
                        onTap: _saveResult)),
                const SizedBox(width: 8),
                Expanded(
                    child: ActionButton(
                        icon: Icons.refresh_outlined,
                        label: strings.reset,
                        onTap: _resetInputs)),
                const SizedBox(width: 8),
                Expanded(
                    child: ActionButton(
                        icon: Icons.note_add_outlined,
                        label: strings.note,
                        onTap: _saveNote)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputCard() {
    final strings = ToolsStrings.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: SectionTitle(strings.inputParameters)),
                IconButton(
                  tooltip: strings.pasteInputs,
                  onPressed: _pasteInputs,
                  icon: const Icon(Icons.content_paste_outlined),
                ),
                IconButton(
                  tooltip: strings.copyInputs,
                  onPressed: _copyInputs,
                  icon: const Icon(Icons.copy_all_outlined),
                ),
                TextButton(
                  onPressed: _resetInputs,
                  child: Text(strings.reset),
                ),
              ],
            ),
            if (widget.tool.inputs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(strings.noNumericInputs),
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
    final strings = ToolsStrings.of(context);
    // 中文：标签与单位走本轮那张表，**`input.label` / `input.unit` 本身仍是目录里那条中文**
    //       （检索读的就是它们）；认不出的字串原样返回，所以 `pH`、`ROI`、`50Ω` 这类
    //       本来就是拉丁字母的标签两种语言逐字节相同。
    // English: the label and the unit go through this round's table, while **`input.label` /
    //          `input.unit` themselves stay the catalogue's Chinese** (search reads those); an
    //          unrecognised string comes back unchanged, so labels already in Latin letters —
    //          `pH`, `ROI`, `50Ω` — are byte-identical in both languages.
    final fields = ToolFieldStrings.of(context);
    final controller = _controllers[input.key]!;
    final scheme = Theme.of(context).colorScheme;
    final error = _detailController.inputErrors[input.key];
    final clearsInput = input.optional || input.defaultValue == null;
    final label = fields.inputLabel(input.label);
    return Row(
      children: [
        Expanded(
            flex: 3,
            child: Text(
                input.optional ? strings.optionalInput(label) : label)),
        const SizedBox(width: 8),
        _stepButton(
          icon: Icons.remove,
          tooltip: strings.decrease,
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
              suffixText: fields.inputUnit(input.unit),
              errorText: error,
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: clearsInput
                          ? strings.clearInput
                          : strings.restoreDefault,
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
          tooltip: strings.increase,
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
        SnackBar(content: Text(pasteResult.summaryForTool(widget.tool, _detailController.strings))),
      );
      return;
    }
    final applyResult = _detailController.applyInputPasteResult(pasteResult);
    _applyInputTexts(applyResult.inputTexts, keys: applyResult.filledKeys);
    _locallyEditedInputKeys.addAll(applyResult.filledKeys);
    _scheduleDraftSave();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(applyResult.summaryForTool(widget.tool, _detailController.strings))),
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
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ToolsStrings.of(context).resultCopied)));
    }
  }

  Future<void> _copyInputs() async {
    await Clipboard.setData(
      ClipboardData(text: _detailController.inputCopyText()),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ToolsStrings.of(context).inputsCopied)));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          // 中文：**这句提示里的标签走表，剪贴板里那份不走。** 屏幕上的字是渲染出来的字，
          //       剪贴板里的是复制出去的数据——后者与历史、笔记一样属于持久化，本轮一个字节没动
          //       （见 `tool_result_label_strings.dart` 的文件头）。英文界面下这两处因此不一致，
          //       这是本轮认下的代价。
          // English: **the label in this hint goes through the table; the one in the clipboard does
          //          not.** Text on screen is rendered text, the clipboard is copied-out data — the
          //          latter is persistence, like history and notes, and not one byte moved this round
          //          (see `tool_result_label_strings.dart`'s head). In English those two therefore
          //          disagree, a cost this round knowingly accepts.
          content: Text(ToolsStrings.of(context)
              .copiedLabel(ToolResultLabelStrings.of(context).label(result.label)))));
    }
  }

  void _showInputErrorSnack() {
    final strings = ToolsStrings.of(context);
    final summary = _detailController.inputErrorSummary();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(summary.isEmpty
            ? strings.fixInputsFirst
            : strings.fixInputsFirstWith(summary)),
      ),
    );
  }

  Widget _resultStatusCard() {
    final strings = ToolsStrings.of(context);
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
        ? strings.statusInputInvalid
        : hasResultIssues
            ? strings.statusResultCheck
            : strings.statusResultReusable;
    // 中文：状态卡里的结果标签走结果标签表——与结果卡、主结果框同一个来源；写进库里的那份
    //       （历史、复制正文、笔记）读的还是 `result.label` 本身，一个字节没动。
    // English: the result labels inside the status card go through the result-label table — the same
    //          source as the result card and the primary-result box; what is written to the database
    //          (history, the copied body, the note body) still reads `result.label` itself.
    final resultLabel = ToolResultLabelStrings.of(context).label;
    final details = hasInputErrors
        ? _detailController.inputErrorSummary()
        : hasResultIssues
            ? _detailController.resultIssueSummary(resultLabel: resultLabel)
            : _detailController.resultHealthSummaryForDisplay(resultLabel);
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
    final strings = ToolsStrings.of(context);
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
                // 中文：主结果框那句标签与结果卡上那一格同源（`ToolResultLabelStrings`）——
                //       同一个 `result.label` 在同一屏上的两处落点不该各翻各的。
                //       这一格最宽（实测 242dp、字号 14），没有长度问题。
                // English: the primary result's label comes from the same table as the result card's
                //          cell (`ToolResultLabelStrings`) — one `result.label` with two landing places
                //          on one screen should not be translated twice. This cell is the widest
                //          (measured 242dp at 14sp) and has no length problem.
                child: Text(ToolResultLabelStrings.of(context).label(primary.label),
                    style: TextStyle(
                        color: scheme.primary, fontWeight: FontWeight.w700)),
              ),
              IconButton.filledTonal(
                tooltip: strings.copyPrimaryResult,
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
    final strings = ToolsStrings.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(strings.insights),
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
