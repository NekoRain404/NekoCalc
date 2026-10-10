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

// 中文：**产出的那一半在本目录的 `tool_detail_output_section.dart` 里**（复制、有错时的拒绝提示、
//       状态卡、主结果框、校核卡）。为什么在那里切、切完两边各自负责什么，写在那份文件头上。
//       本文件留下的是"把数字弄进来并算出来"这一半。
// English: **the output half lives in `tool_detail_output_section.dart`** in this directory (the copy
//          actions, the refusal hint when an input is invalid, the status card, the primary-result box
//          and the insight card). Why the seam is there, and what each half owns afterwards, is on that
//          file's head. What stays here is the half that **brings the numbers in and computes them**.
part 'tool_detail_output_section.dart';

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
                    tooltip: strings.back,
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
                    // 中文：⚠️ **1.55 太扁，结果卡溢出 12 px**（那处溢出此前被下面那条护栏
                    //       **当作已知项容忍着**；见 `tool_result_label_lengths_test.dart` 的
                    //       `expect(knownOverflows, greaterThan(0))` 与 `docs/verification.md` §5b）。
                    //       1.35 是**量出来的**：360 dp 屏上格宽 160 dp，1.55 给 103 dp（差 12 px），
                    //       1.35 给 118 dp——**四个手机尺寸上溢出都消失**（量过）。
                    //       宽屏那一支没动（3 列、格高 150 dp，本来就够）。
                    // English: ⚠️ **1.55 is too flat and the result card overflows by 12 px** (an overflow
                    //          the guard below **tolerated as a known item**; see its
                    //          `expect(knownOverflows, greaterThan(0))` and `docs/verification.md` §5b).
                    //          1.35 is **measured**: at 360 dp a cell is 160 dp wide, 1.55 gives 103 dp (12 px
                    //          short) and 1.35 gives 118 dp — **the overflow is gone at all four phone
                    //          sizes**. The wide branch is untouched (3 columns, 150 dp tall, already enough).
                    MediaQuery.sizeOf(context).width >= 520 ? 1.05 : 1.35,
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

  /// 中文：⚠️ **这是一颗 34dp 的按钮，`androidTapTargetGuideline` 要 48dp，而 34 → 48 在这里不是
  ///       免费的——量过，代价**正好** 28dp 宽，而且**全落在文字上**。**
  ///
  ///       全屏实测（`ToolDetailScreen` + `battery_life`，360 × 2200dp，六个输入框）：
  ///       **12 个矮节点**就是它（6 行 × 2 颗，tooltip `增大` / `减小`），每个 **34 × 34**。
  ///       撑到 48 之后：
  ///
  ///       | 量的是什么 | 34dp | 48dp | 差 |
  ///       |---|---|---|---|
  ///       | 输入框 | 118.9dp | 102.9dp | **−16.0** |
  ///       | 标签那一格 | **89.142857dp** | 77.142857dp | **−12.0** |
  ///       | 行高 | 48.0 | 48.0 | **0** |
  ///
  ///       **行高是 0 代价的**——这一行的行高由那个 `TextField` 定（它本来就是 48），所以纵向白拿。
  ///       28dp 由两个 `Expanded`（`flex: 3` 标签 / `flex: 4` 输入框）按比例吸掉：3/7 × 28 = 12.0、
  ///       4/7 × 28 = 16.0，与上表**分毫不差**。
  ///
  ///       ⚠️ **而那 12dp 正是这条设计的命门。** 标签那一格的宽度是
  ///       `tool_field_strings_test.dart` 里那条**行数判据的分母**（`_lines = (advance / labelBox).ceil()`，
  ///       `labelBox = 89.142857`），英文标签上限 **2 行**。把 `labelBox` 换成实测的 77.14 再跑那条判据：
  ///       **一屏英文标签越线**——`op_amp_gain.vin`「Input voltage」84.0dp、`ldo_power.current`
  ///       「Load current」81.7dp、`capacitor_charge.c`「Capacitance」80.3dp、`complex.b`
  ///       「z1 imag part」80.7dp、`circle.circumference`「Circumference」161.1dp（3 行）、
  ///       `op_amp_gain.fullPowerFrequency`「Full-power BW」158.9dp（3 行）……**十几条。**
  ///
  ///       ⚠️ **所以我事先的那个假设是错的。** 我以为这里的耦合比结果卡那颗复制键**软**——因为这一格
  ///       的标签**会换行**（没有 `maxLines: 1`），换行总比截断轻。**量下来不软**：那格宽度本身就是
  ///       「英文最多两行」这条判据的分母，一格窄 12dp 就是判据整体收紧 12dp。**两者是同一类耦合，
  ///       只是表现不同**（那边是截断，这边是行数超限）。
  ///
  ///       **能化解而不是交换的改法**（本版没做）：把这一颗拆成「34dp 的视觉 + 48dp 的命中区」，
  ///       照 `IconToolButton` 那一套（`SizedBox(48,48) > 不透明手势 > Center > 34 的视觉`）。
  ///       ⚠️ **但那省的是视觉，不是布局宽度**——盒子仍是 48，上面那 28dp 照付。要真省下宽度只有
  ///       让步进键**另起一行**（改的是设计，不是参数）。**动这颗之前先读这一整段，并重跑
  ///       `tool_field_strings_test.dart`。**
  /// English: ⚠️ **This is a 34dp button, `androidTapTargetGuideline` wants 48dp, and 34 → 48 is not free
  ///          here — measured, the cost is *exactly* 28dp of width, and it lands entirely on the text.**
  ///
  ///          Measured across the screen (`ToolDetailScreen` + `battery_life`, 360 × 2200dp, six inputs):
  ///          these are **12** of the sub-48 nodes (6 rows × 2, tooltips `增大` / `减小`), each **34 × 34**.
  ///          At 48:
  ///
  ///          | what | 34dp | 48dp | delta |
  ///          |---|---|---|---|
  ///          | the input field | 118.9dp | 102.9dp | **−16.0** |
  ///          | the label cell | **89.142857dp** | 77.142857dp | **−12.0** |
  ///          | the row height | 48.0 | 48.0 | **0** |
  ///
  ///          **The row height is free** — it is set by the `TextField` (already 48), so the vertical half
  ///          costs nothing. The 28dp is absorbed by the two `Expanded`s (`flex: 3` label / `flex: 4` field)
  ///          in proportion: 3/7 × 28 = 12.0 and 4/7 × 28 = 16.0, matching the table to the digit.
  ///
  ///          ⚠️ **And those 12dp are this design's weak point.** The label cell's width is the
  ///          **denominator of the line criterion** in `tool_field_strings_test.dart`
  ///          (`_lines = (advance / labelBox).ceil()`, `labelBox = 89.142857`) whose cap for English is
  ///          **2 lines**. Feed in the measured 77.14 and **a screenful of English labels crosses it** —
  ///          `op_amp_gain.vin` "Input voltage" 84.0dp, `ldo_power.current` "Load current" 81.7dp,
  ///          `capacitor_charge.c` "Capacitance" 80.3dp, `complex.b` "z1 imag part" 80.7dp,
  ///          `circle.circumference` "Circumference" 161.1dp (3 lines), `op_amp_gain.fullPowerFrequency`
  ///          "Full-power BW" 158.9dp (3 lines) — **a dozen or more.**
  ///
  ///          ⚠️ **So the hypothesis I started with was wrong.** I expected the coupling here to be
  ///          **softer** than the result card's copy key, because this cell's label **wraps** (it has no
  ///          `maxLines: 1`) and wrapping beats truncation. **Measured, it is not softer**: that cell's
  ///          width *is* the denominator of the "English stays within two lines" criterion, so narrowing
  ///          it 12dp tightens the whole criterion by 12dp. **Same class of coupling, different
  ///          symptom** — truncation there, an exceeded line count here.
  ///
  ///          **A change that would resolve rather than trade** (not done in this revision): split this into
  ///          a "34dp visual + 48dp hit area", the way `IconToolButton` does
  ///          (`SizedBox(48,48) > opaque gesture > Center > the 34 visual`). ⚠️ **But that saves the visual,
  ///          not the layout width** — the box is still 48 and the 28dp is still paid. The only way to
  ///          actually save the width is to give the steppers **their own row**, which is a design change
  ///          rather than a parameter. **Read this whole note before touching it, and re-run
  ///          `tool_field_strings_test.dart` if you do.**
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
}
