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
    _inputController =
        TextEditingController(text: _defaultInput(widget.tool.id));
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
    _recalculate();
    if (widget.settings.restoreState) unawaited(_loadDraft());
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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: SectionTitle(isCustom ? '公式与变量' : '输入')),
                        IconButton(
                          tooltip: '粘贴',
                          onPressed: _pasteInput,
                          icon: const Icon(Icons.content_paste_outlined),
                        ),
                        IconButton(
                          tooltip: '清空',
                          onPressed: _clearInput,
                          icon: const Icon(Icons.clear),
                        ),
                      ],
                    ),
                    if (isCustom) ...[
                      TextField(
                        controller: _formulaController,
                        decoration: const InputDecoration(
                            labelText: '公式', hintText: '例如 a * b + sqrt(c)'),
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
                        child: Text('主结果',
                            style: TextStyle(
                                color: scheme.primary,
                                fontWeight: FontWeight.w700)),
                      ),
                      IconButton.filledTonal(
                        tooltip: '复制主结果',
                        onPressed: () => _copyTextValue(
                          _output.primaryCopyText,
                          '已复制主结果',
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
                        const Expanded(child: SectionTitle('详细结果')),
                        IconButton(
                          tooltip: '复制详细结果',
                          onPressed: () => _copyTextValue(
                            _output.detailCopyText,
                            '已复制详细结果',
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
                        label: '复制',
                        onTap: _copyResult)),
                const SizedBox(width: 8),
                if (!isCustom) ...[
                  Expanded(
                      child: ActionButton(
                          icon: Icons.keyboard_return,
                          label: '回填',
                          onTap: _useResultAsInput)),
                  const SizedBox(width: 8),
                ],
                Expanded(
                    child: ActionButton(
                        icon: Icons.save_outlined,
                        label: '保存',
                        onTap: _saveHistory)),
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
            const SectionTitle('校核'),
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已复制结果')));
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
      SnackBar(content: Text('请先修正输入：${_output.statusMessage}')),
    );
  }

  String _mainInputText() {
    if (widget.tool.id == 'custom_formula') {
      return '${_formulaController.text}; a=${_aController.text}, b=${_bController.text}, c=${_cController.text}';
    }
    return _inputController.text;
  }

  String _defaultInput(String id) {
    return switch (id) {
      'base_convert' => '0xFF',
      'timestamp' => (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString(),
      'color_convert' => '#5B47FF',
      'base64' => 'NekoCalc',
      'url_codec' => 'NekoCalc 工具箱',
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
      'text_stats' => 'NekoCalc\n全能计算工具箱',
      'csv_json' => 'name,category\nNekoCalc,calculator\nGraph,tool',
      'fnv_crc' => 'NekoCalc',
      _ => '',
    };
  }

  String _hintText(String id) {
    return switch (id) {
      'base_convert' => '输入 255、0xFF、#FF、FFh、1010b 或 0o755',
      'timestamp' => '输入秒/毫秒时间戳、1700000000.123s 或 2026年6月8日',
      'color_convert' => '输入 #5B47FF、rgb(...)、hsl(...) 或 rebeccapurple',
      'base64' => '输入文本、Base64、Base64URL 或 data URL',
      'url_codec' => '输入 URL、query string、普通文本或百分号编码文本',
      'json_format' => '输入 JSON、JSON Lines 或带 BOM 的 JSON 文本',
      'ascii_unicode' => r'输入字符、U+4E2D、\u4E2D 或 128072',
      'bitwise' => '输入两个整数，例如 12 5、0xFF 0b1010、A=0xF0 B=0b1010',
      'checksum' => r'输入文本或 DE AD BE EF / \xDE 十六进制字节',
      'uuid' => '留空生成 UUID，或粘贴 UUID 校验/标准化',
      'jwt_decode' => '输入完整 JWT token，离线解码 Header/Payload',
      'query_params' => '输入 URL、请求行、片段 query 或 a=1&b=2;b=3',
      'html_entities' => '输入 HTML、命名实体或 &#x4E2D; 数字实体',
      'regex_test' => '第一行正则，后续行测试文本',
      'text_stats' => '输入要统计的文本，输出字符分类和段落信息',
      'csv_json' => '首行为表头，支持逗号、Tab、分号、竖线分隔',
      'fnv_crc' => r'输入文本或 31 32 33 十六进制字节',
      _ => '输入内容',
    };
  }
}
