import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../application/app_settings.dart';
import '../../../application/controllers/text_tool_controller.dart';
import '../../../data/local/app_database.dart';
import '../../../data/repositories/history_repository.dart';
import '../../../data/repositories/notes_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../domain/entities/tool_definition.dart';
import '../../../domain/usecases/tool_save_result.dart';
import '../../../shared/presentation/app_chrome.dart';
import 'tools_strings.dart';

/// 中文：文本/编程类工具详情页，承载 JSON、Base64、URL、正则等输入输出型工具。
/// English: Detail screen for text/programming tools such as JSON, Base64, URL, and regex utilities.
class TextToolDetailScreen extends StatefulWidget {
  const TextToolDetailScreen({
    required this.db,
    required this.tool,
    required this.settings,
    super.key,
  });

  final AppDatabase db;
  final ToolDefinition tool;
  final AppSettings settings;

  @override
  State<TextToolDetailScreen> createState() => _TextToolDetailScreenState();
}

class _TextToolDetailScreenState extends State<TextToolDetailScreen> {
  static const _draftInputKey = 'input';
  static const _draftFormulaKey = 'formula';
  static const _draftAKey = 'a';
  static const _draftBKey = 'b';
  static const _draftCKey = 'c';

  late final TextEditingController _inputController;
  late final TextEditingController _formulaController;
  late final TextEditingController _aController;
  late final TextEditingController _bController;
  late final TextEditingController _cController;
  late final HistoryRepository _historyRepository;
  late final NotesRepository _notesRepository;
  late final SettingsRepository _settingsRepository =
      SettingsRepository(widget.db);
  final TextToolController _toolController = const TextToolController();
  TextToolOutput _output = const TextToolOutput('', '');
  String _result = '';
  String _detail = '';
  List<String> _insights = const [];
  Timer? _recalculateTimer;
  Timer? _draftSaveTimer;
  bool _savingHistory = false;
  bool _savingNote = false;
  bool _applyingDraft = false;
  final Set<String> _locallyEditedDraftKeys = {};

  @override
  void initState() {
    super.initState();
    // 中文：初值先留空，`didChangeDependencies` 里再填——`_defaultInput` 的两个示例取值来自
    //       文案表，而文案表要查祖先里的 `AppLanguageScope`，`initState` 阶段查不了（理由见
    //       `didChangeDependencies` 上的注释）。
    // English: The initial text is filled in `didChangeDependencies` rather than here, because
    //          `_defaultInput` reads two sample values from the copy table, which needs an ancestor
    //          `AppLanguageScope` — not available while `initState` runs (see the note on
    //          `didChangeDependencies`).
    _inputController = TextEditingController();
    _formulaController =
        TextEditingController(text: TextToolController.defaultFormula);
    _aController = TextEditingController(text: TextToolController.defaultA);
    _bController = TextEditingController(text: TextToolController.defaultB);
    _cController = TextEditingController(text: TextToolController.defaultC);
    _historyRepository = HistoryRepository(widget.db);
    _notesRepository = NotesRepository(widget.db);
    _inputController.addListener(() => _scheduleRecalculate(_draftInputKey));
    _formulaController
        .addListener(() => _scheduleRecalculate(_draftFormulaKey));
    _aController.addListener(() => _scheduleRecalculate(_draftAKey));
    _bController.addListener(() => _scheduleRecalculate(_draftBKey));
    _cController.addListener(() => _scheduleRecalculate(_draftCKey));
    if (widget.settings.restoreState) unawaited(_loadDraft());
  }

  /// 中文：填初值与第一次计算推迟到这里跑，**不能留在 `initState` 里**——它们要取
  ///       `ToolsStrings`，而在 `initState` 阶段查祖先里的 `AppLanguageScope` 在 debug 构建里会
  ///       直接抛（`dependOnInheritedWidgetOfExactType` 在 `initState` 未完成时是禁止的；真实 App
  ///       里 `app.dart` 一定装了那个作用域，所以这不是理论问题——`tools_strings_test.dart` 里那
  ///       两条装作用域的用例就是为此加的）。`didChangeDependencies` 在 `initState` 之后、第一次
  ///       `build` 之前跑，屏幕上看不出先后差别；填初值那一下按 `_applyingDraft` 挡住监听器，
  ///       免得它被记成"用户改过"而挡掉稍后要恢复的草稿。
  /// English: The initial text and the first calculation run here rather than in `initState`, because
  ///          they read `ToolsStrings`, and looking up an ancestor `AppLanguageScope` while
  ///          `initState` is still running throws in debug builds
  ///          (`dependOnInheritedWidgetOfExactType` is forbidden there). Not theoretical: `app.dart`
  ///          always installs that scope, and the two scope-installing cases in
  ///          `tools_strings_test.dart` exist for exactly this. `didChangeDependencies` runs after
  ///          `initState` and before the first `build`, so nothing on screen can tell the difference;
  ///          the seeding write is guarded by `_applyingDraft` so the listeners do not record it as a
  ///          user edit and block a draft that is about to be restored.
  bool _seededOnce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seededOnce) return;
    _seededOnce = true;
    _applyingDraft = true;
    try {
      _inputController.text = _defaultInput(widget.tool.id);
    } finally {
      _applyingDraft = false;
    }
    _recalculate();
  }

  @override
  void dispose() {
    _recalculateTimer?.cancel();
    _draftSaveTimer?.cancel();
    if (widget.settings.restoreState) unawaited(_saveDraftNow());
    _inputController.dispose();
    _formulaController.dispose();
    _aController.dispose();
    _bController.dispose();
    _cController.dispose();
    super.dispose();
  }

  void _scheduleRecalculate(String draftKey) {
    if (_applyingDraft) return;
    _locallyEditedDraftKeys.add(draftKey);
    _recalculateTimer?.cancel();
    // 中文：文本/JSON/正则工具可能处理大段内容，输入过程中合并重算。
    // English: Text, JSON, and regex tools may process large content, so recalculation is debounced while typing.
    _recalculateTimer = Timer(const Duration(milliseconds: 80), () {
      _recalculate();
      _scheduleDraftSave();
    });
  }

  void _recalculate() {
    _recalculateTimer?.cancel();
    _recalculateTimer = null;
    setState(() {
      final output = _toolController.calculate(
        toolId: widget.tool.id,
        input: _inputController.text,
        formula: _formulaController.text,
        a: _aController.text,
        b: _bController.text,
        c: _cController.text,
      );
      _output = output;
      _result = output.primary;
      _detail = output.detail;
      _insights = output.insights;
    });
  }

  Future<void> _loadDraft() async {
    final settings = await _settingsRepository.load();
    final raw = settings[TextToolController.draftSettingKey(widget.tool.id)];
    final draft = TextToolController.decodeDraft(
      toolId: widget.tool.id,
      raw: raw,
    );
    if (!mounted || draft == null || !widget.settings.restoreState) return;
    final values = {
      _draftInputKey: draft.input,
      _draftFormulaKey: draft.formula,
      _draftAKey: draft.a,
      _draftBKey: draft.b,
      _draftCKey: draft.c,
    };
    final uneditedValues = {
      for (final entry in values.entries)
        if (!_locallyEditedDraftKeys.contains(entry.key))
          entry.key: entry.value,
    };
    if (uneditedValues.isEmpty) return;
    _recalculateTimer?.cancel();
    _applyingDraft = true;
    try {
      _setControllerText(_inputController, uneditedValues[_draftInputKey]);
      _setControllerText(_formulaController, uneditedValues[_draftFormulaKey]);
      _setControllerText(_aController, uneditedValues[_draftAKey]);
      _setControllerText(_bController, uneditedValues[_draftBKey]);
      _setControllerText(_cController, uneditedValues[_draftCKey]);
    } finally {
      _applyingDraft = false;
    }
    _recalculate();
    if (_locallyEditedDraftKeys.isNotEmpty) _scheduleDraftSave();
  }

  void _setControllerText(TextEditingController controller, String? value) {
    if (value == null || controller.text == value) return;
    controller.text = value;
    controller.selection = TextSelection.collapsed(offset: value.length);
  }

  void _scheduleDraftSave() {
    if (!widget.settings.restoreState) return;
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(
      const Duration(milliseconds: 260),
      () => unawaited(_saveDraftNow()),
    );
  }

  Future<void> _saveDraftNow() async {
    if (!widget.settings.restoreState) return;
    final draft = TextToolDraft(
      toolId: widget.tool.id,
      input: _inputController.text,
      formula: _formulaController.text,
      a: _aController.text,
      b: _bController.text,
      c: _cController.text,
    );
    await _settingsRepository.set(
      TextToolController.draftSettingKey(widget.tool.id),
      TextToolController.encodeDraft(draft),
    );
  }

  Future<void> _saveHistory() async {
    // 中文：防止连续点击保存按钮时写入重复工具历史。
    // English: Prevent duplicate tool-history writes from repeated save taps.
    if (_savingHistory) return;
    _savingHistory = true;
    try {
      final result = await _saveHistoryResult();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(result.message)));
      }
    } finally {
      _savingHistory = false;
    }
  }

  Future<void> _saveNote() async {
    // 中文：保存笔记使用同一个防重入策略，保持历史和笔记行为一致。
    // English: Use the same re-entry guard for note saving to keep behavior consistent with history saving.
    if (_savingNote) return;
    _savingNote = true;
    try {
      final result = await _saveNoteResult();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(result.message)));
      }
    } finally {
      _savingNote = false;
    }
  }

  Future<ToolSaveResult> _saveHistoryResult() async {
    if (_output.hasError) {
      return ToolSaveResult.inputInvalid(
        target: ToolSaveTarget.history,
        summary: _output.statusMessage,
      );
    }
    try {
      final historyId = await _historyRepository.saveToolResult(
        expression: '${widget.tool.title}: ${_mainInputText()}',
        result: _result,
        toolId: widget.tool.id,
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
    if (_output.hasError) {
      return ToolSaveResult.inputInvalid(
        target: ToolSaveTarget.note,
        summary: _output.statusMessage,
      );
    }
    try {
      final noteId = await _notesRepository.create(
        title: widget.tool.title,
        body: _output.copyText(
          title: widget.tool.title,
          input: _mainInputText(),
        ),
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

  @override
  Widget build(BuildContext context) {
    final strings = ToolsStrings.of(context);
    final isCustom = widget.tool.id == 'custom_formula';
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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: SectionTitle(isCustom
                                ? strings.formulaAndVariables
                                : strings.inputLabel)),
                        IconButton(
                          tooltip: strings.paste,
                          onPressed: _pasteInput,
                          icon: const Icon(Icons.content_paste_outlined),
                        ),
                        IconButton(
                          tooltip: strings.clearInput,
                          onPressed: _clearInput,
                          icon: const Icon(Icons.clear),
                        ),
                      ],
                    ),
                    if (isCustom) ...[
                      TextField(
                        controller: _formulaController,
                        decoration: InputDecoration(
                            labelText: strings.formula,
                            hintText: strings.formulaHint),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _smallField('a', _aController)),
                          const SizedBox(width: 8),
                          Expanded(child: _smallField('b', _bController)),
                          const SizedBox(width: 8),
                          Expanded(child: _smallField('c', _cController)),
                        ],
                      ),
                    ] else
                      TextField(
                        controller: _inputController,
                        minLines: widget.tool.id == 'json_format' ? 6 : 2,
                        maxLines: 10,
                        decoration: InputDecoration(
                          hintText: _hintText(widget.tool.id),
                          alignLabelWithHint: true,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _statusCard(),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: softPanel(context: context, highlight: true),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(strings.primaryResult,
                            style: TextStyle(
                                color: scheme.primary,
                                fontWeight: FontWeight.w700)),
                      ),
                      IconButton.filledTonal(
                        tooltip: strings.copyPrimaryResult,
                        onPressed: () => _copyTextValue(
                          _output.primaryCopyText,
                          strings.primaryResultCopied,
                        ),
                        iconSize: 18,
                        icon: const Icon(Icons.copy_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SelectableText(
                    _result,
                    style: TextStyle(
                        color: scheme.primary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: SectionTitle(strings.detailResult)),
                        IconButton(
                          tooltip: strings.copyDetailResult,
                          onPressed: () => _copyTextValue(
                            _output.detailCopyText,
                            strings.detailResultCopied,
                          ),
                          icon: const Icon(Icons.copy_outlined),
                        ),
                      ],
                    ),
                    SelectableText(_detail,
                        style: TextStyle(
                            color: scheme.onSurfaceVariant, height: 1.45)),
                  ],
                ),
              ),
            ),
            if (_insights.isNotEmpty) ...[
              const SizedBox(height: 12),
              _insightCard(),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: ActionButton(
                        icon: Icons.copy_outlined,
                        label: strings.copy,
                        onTap: _copyResult)),
                const SizedBox(width: 8),
                if (!isCustom) ...[
                  Expanded(
                      child: ActionButton(
                          icon: Icons.keyboard_return,
                          label: strings.useAsInput,
                          onTap: _useResultAsInput)),
                  const SizedBox(width: 8),
                ],
                Expanded(
                    child: ActionButton(
                        icon: Icons.save_outlined,
                        label: strings.save,
                        onTap: _saveHistory)),
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

  Widget _statusCard() {
    final scheme = Theme.of(context).colorScheme;
    final hasError = _output.hasError;
    final color = hasError ? scheme.error : scheme.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: softPanel(context: context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            hasError ? Icons.error_outline : Icons.verified_outlined,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_output.statusTitle,
                    style: TextStyle(
                        color: color,
                        fontSize: 14,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  _output.statusMessage,
                  style: TextStyle(
                      color:
                          hasError ? scheme.onSurface : scheme.onSurfaceVariant,
                      height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true, signed: true),
      decoration: InputDecoration(labelText: label, isDense: true),
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
            SectionTitle(ToolsStrings.of(context).insights),
            ..._insights.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 17, color: scheme.primary),
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
        ),
      ),
    );
  }

  void _reset() {
    _recalculateTimer?.cancel();
    _inputController.text = _defaultInput(widget.tool.id);
    _formulaController.text = TextToolController.defaultFormula;
    _aController.text = TextToolController.defaultA;
    _bController.text = TextToolController.defaultB;
    _cController.text = TextToolController.defaultC;
    _recalculate();
    _scheduleDraftSave();
  }

  Future<void> _copyResult() async {
    await Clipboard.setData(ClipboardData(
      text: _output.copyText(
        title: widget.tool.title,
        input: _mainInputText(),
      ),
    ));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ToolsStrings.of(context).resultCopied)));
    }
  }

  Future<void> _copyTextValue(String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _pasteInput() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = data?.text;
    if (text == null) return;
    if (widget.tool.id == 'custom_formula') {
      _pasteCustomFormula(text);
    } else {
      _inputController.text = text;
    }
    _recalculate();
    _scheduleDraftSave();
  }

  void _pasteCustomFormula(String text) {
    final draft = TextToolController.customFormulaDraftFromPastedText(
      input: text,
      currentFormula: _formulaController.text,
      currentA: _aController.text,
      currentB: _bController.text,
      currentC: _cController.text,
    );
    _inputController.text = draft.input;
    _setControllerText(_formulaController, draft.formula);
    _setControllerText(_aController, draft.a);
    _setControllerText(_bController, draft.b);
    _setControllerText(_cController, draft.c);
  }

  void _clearInput() {
    if (widget.tool.id == 'custom_formula') {
      _inputController.clear();
      _formulaController.clear();
      _aController.clear();
      _bController.clear();
      _cController.clear();
    } else {
      _inputController.clear();
    }
    _recalculate();
    _scheduleDraftSave();
  }

  void _useResultAsInput() {
    if (widget.tool.id == 'custom_formula') return;
    if (_output.hasError) {
      _showOutputErrorSnack();
      return;
    }
    _inputController.text = _result;
    _recalculate();
    _scheduleDraftSave();
  }

  void _showOutputErrorSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(ToolsStrings.of(context)
              .fixInput(_output.statusMessage))),
    );
  }

  String _mainInputText() {
    if (widget.tool.id == 'custom_formula') {
      return '${_formulaController.text}; a=${_aController.text}, b=${_bController.text}, c=${_cController.text}';
    }
    return _inputController.text;
  }

  String _defaultInput(String id) {
    final strings = ToolsStrings.of(context);
    return switch (id) {
      'base_convert' => '0xFF',
      'timestamp' => (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString(),
      'color_convert' => '#5B47FF',
      'base64' => 'NekoCalc',
      'url_codec' => strings.urlCodecSample,
      'json_format' =>
        '{"name":"NekoCalc","tools":["calculator","units","notes"]}',
      'ascii_unicode' => 'NekoCalc',
      'bitwise' => '12 5',
      'checksum' => 'NekoCalc',
      'uuid' => '',
      'jwt_decode' =>
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJOZWtvQ2FsYyIsImV4cCI6MTg5MzQ1NjAwMH0.signature',
      'query_params' => 'https://example.com/#/tools?tab=text&id=query_params',
      'html_entities' => '<div class="name">NekoCalc & Tools</div>',
      'regex_test' => r'\d+\nNekoCalc 2026 build 42',
      'text_stats' => strings.textStatsSample,
      'csv_json' => 'name,category\nNekoCalc,calculator\nGraph,tool',
      'fnv_crc' => 'NekoCalc',
      _ => '',
    };
  }

  String _hintText(String id) {
    final strings = ToolsStrings.of(context);
    return switch (id) {
      'base_convert' => strings.hintBaseConvert,
      'timestamp' => strings.hintTimestamp,
      'color_convert' => strings.hintColorConvert,
      'base64' => strings.hintBase64,
      'url_codec' => strings.hintUrlCodec,
      'json_format' => strings.hintJsonFormat,
      'ascii_unicode' => strings.hintAsciiUnicode,
      'bitwise' => strings.hintBitwise,
      'checksum' => strings.hintChecksum,
      'uuid' => strings.hintUuid,
      'jwt_decode' => strings.hintJwtDecode,
      'query_params' => strings.hintQueryParams,
      'html_entities' => strings.hintHtmlEntities,
      'regex_test' => strings.hintRegexTest,
      'text_stats' => strings.hintTextStats,
      'csv_json' => strings.hintCsvJson,
      'fnv_crc' => strings.hintFnvCrc,
      _ => strings.hintDefault,
    };
  }
}
