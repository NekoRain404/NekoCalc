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
import '../../../l10n/app_language.dart';
import 'text_tool_detail_cards.dart';
import 'text_tool_inputs.dart';
import 'text_tool_result_saver.dart';
import 'text_tool_strings.dart';
import 'tool_catalog_strings.dart';
import 'tool_save_message.dart';
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
  /// 中文：保存那一层（错误即拒 / 没写进去 / 抛出来，三条出口都住在它里面）。屏幕这一侧
  ///       只剩防重入与把回来的那句话显示出来。
  /// English: the saving layer (refuse on error / not written / threw — all three exits live in
  ///          it). What is left on the screen is the re-entry guard and showing the sentence
  ///          that comes back.
  late final TextToolResultSaver _saver;
  late final SettingsRepository _settingsRepository =
      SettingsRepository(widget.db);
  final TextToolController _toolController = const TextToolController();

  /// 中文：空壳，第一帧之前就会被 `_recalculate()` 换掉——`TextToolOutput` 自己不认字，
  ///       状态卡上那两行要等文案表到位才算得出来。
  /// English: An empty shell, replaced by `_recalculate()` before the first frame — a
  ///          `TextToolOutput` knows no words of its own and the two status lines can only be worked
  ///          out once the copy table is available.
  TextToolOutput _output = const TextToolOutput('', '');

  /// 中文：当前语言的文案表。**在一个地方取**（`didChangeDependencies` 里），其余地方读它：
  ///       `_recalculate` 要递给控制器，状态卡与复制的正文要拿它算字。这样"表从哪来"只有一个答案。
  ///       它一开始是中文那份（与 `AppLanguage.of` 的兜底同源），`didChangeDependencies` 一跑就
  ///       会被换成真正的当前语言。
  /// English: The copy table for the active language, read **in one place**
  ///          (`didChangeDependencies`) and consulted everywhere else: `_recalculate` hands it to the
  ///          controller, and the status card and the copied report use it to produce words. That
  ///          leaves exactly one answer to "where did the table come from". It starts as the Chinese
  ///          one (the same source as `AppLanguage.of`'s fallback) and `didChangeDependencies`
  ///          replaces it with the real active language as soon as it runs.
  TextToolStrings _strings = TextToolStrings.forLanguage(AppLanguage.fallback);
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
    _saver = TextToolResultSaver(
      historyRepository: _historyRepository,
      notesRepository: _notesRepository,
    );
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
    // 中文：**换了语言要把结果重算一遍。** 表是 `switch` 出来的 `static final`，同一语言下每次
    //       都是同一个实例，所以 `identical` 就是"语言变了吗"的判据；变了就重算，否则切到英文
    //       之后主结果与详情会一直停在旧语言，直到用户碰一下输入框才跟上。
    //       **这里不走 `_recalculate()`**：它套着 `setState`，而依赖变化本来就排好了一次重建，
    //       再喊一次是多余的（`didChangeDependencies` 跑在 `build` 之前）。
    // English: **Changing the language has to recompute the result.** The tables are `static final`
    //          instances picked by a `switch`, so within one language every lookup returns the same
    //          object and `identical` is the test for "did the language change". If it did, recompute;
    //          otherwise switching to English leaves the primary result and detail in the old
    //          language until the user touches an input field. **This does not go through
    //          `_recalculate()`**: that wraps `setState`, and a dependency change has already
    //          scheduled a rebuild (`didChangeDependencies` runs before `build`).
    final next = TextToolStrings.of(context);
    final languageChanged = _seededOnce && !identical(next, _strings);
    _strings = next;
    if (_seededOnce) {
      if (languageChanged) {
        _recalculateTimer?.cancel();
        _recalculateTimer = null;
        _applyOutput();
      }
      return;
    }
    _seededOnce = true;
    _applyingDraft = true;
    try {
      _inputController.text = defaultInputFor(widget.tool.id, ToolsStrings.of(context));
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
    setState(_applyOutput);
  }

  /// 中文：算一次并把结果落到字段上，**自己不喊重建**——两条路径调它：`_recalculate()`（用户改了
  ///       输入，外面套着 `setState`）与 `didChangeDependencies`（语言变了，重建已经排在队里）。
  /// English: Evaluates once and writes the result into the fields, **without asking for a rebuild**:
  ///          two paths call it — `_recalculate()` when the user changed an input (wrapped in
  ///          `setState`) and `didChangeDependencies` when the language changed (a rebuild is already
  ///          queued).
  void _applyOutput() {
    final output = _toolController.calculate(
      toolId: widget.tool.id,
      strings: _strings,
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
        // 中文：回执在**呈现边缘**翻译（`tool_save_message.dart`）——领域层只给令牌，字在
        //       `ToolsStrings` 里。这里从前印的是 `result.message`。
        // English: the receipt is translated **at the presentation edge**
        //          (`tool_save_message.dart`) — the domain hands over the token and the words live in
        //          `ToolsStrings`. This used to print `result.message`.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              toolSaveMessage(result, ToolsStrings.of(context)),
            ),
          ),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              toolSaveMessage(result, ToolsStrings.of(context)),
            ),
          ),
        );
      }
    } finally {
      _savingNote = false;
    }
  }

  /// 中文：保存那两条路的**判定**搬到了 `text_tool_result_saver.dart`（错误即拒 / 没写进去 /
  ///       抛出来），这里只把这次输出的四样东西交给它：工具（标题与 id）、输出本体、文案表，
  ///       以及这一串算的是什么。
  /// English: the **judgements** behind both save roads moved to `text_tool_result_saver.dart`
  ///          (refuse on error / not written / threw); all that is left here is handing over this
  ///          output's four things: the tool (its title and id), the output itself, the copy table,
  ///          and the string saying what was computed.
  Future<ToolSaveResult> _saveHistoryResult() {
    return _saver.saveHistory(
      tool: widget.tool,
      output: _output,
      strings: _strings.output,
      input: _mainInputText(),
      result: _result,
    );
  }

  Future<ToolSaveResult> _saveNoteResult() {
    return _saver.saveNote(
      tool: widget.tool,
      output: _output,
      strings: _strings.output,
      input: _mainInputText(),
    );
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
    final toolTitle = catalog.toolName(widget.tool.id);
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
                Expanded(child: Center(child: PageTitle(toolTitle))),
                IconToolButton(
                  icon: Icons.refresh_outlined,
                  tooltip: strings.reset,
                  onTap: _reset,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(catalog.toolDescription(widget.tool.id),
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
                          Expanded(
                              child: TextToolSmallField(
                                  label: 'a', controller: _aController)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: TextToolSmallField(
                                  label: 'b', controller: _bController)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: TextToolSmallField(
                                  label: 'c', controller: _cController)),
                        ],
                      ),
                    ] else
                      TextField(
                        controller: _inputController,
                        minLines: widget.tool.id == 'json_format' ? 6 : 2,
                        maxLines: 10,
                        decoration: InputDecoration(
                          hintText: hintTextFor(widget.tool.id, ToolsStrings.of(context)),
                          alignLabelWithHint: true,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextToolStatusCard(output: _output, strings: _strings.output),
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
              TextToolInsightCard(insights: _insights),
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

  void _reset() {
    _recalculateTimer?.cancel();
    _inputController.text = defaultInputFor(widget.tool.id, ToolsStrings.of(context));
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
        strings: _strings.output,
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
              .fixInput(_output.statusMessage(_strings.output)))),
    );
  }

  String _mainInputText() {
    if (widget.tool.id == 'custom_formula') {
      return '${_formulaController.text}; a=${_aController.text}, b=${_bController.text}, c=${_cController.text}';
    }
    return _inputController.text;
  }

}
