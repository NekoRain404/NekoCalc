import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../application/app_settings.dart';
import '../../../application/controllers/notes_controller.dart';
import '../../../data/local/app_database.dart';
import '../../../data/models/history_item.dart';
import '../../../data/models/note_item.dart';
import '../../../data/repositories/history_repository.dart';
import '../../../data/repositories/notes_repository.dart';
import '../../../domain/usecases/notes_clipboard_import.dart';
import '../../../shared/presentation/app_chrome.dart';
import 'notes_receipt_message.dart';
import 'notes_strings.dart';
import 'notes_summary_message.dart';

part 'notes_page_sections.dart';
part 'notes_page_actions.dart';
part 'notes_page_dialogs.dart';

/// 中文：笔记与历史页面，统一展示计算历史、工具结果和用户笔记。
/// English: Notes and history screen for calculation history, tool results, and user notes.
class NotesPage extends StatefulWidget {
  const NotesPage({
    required this.db,
    required this.toolResultLabel,
    required this.settings,
    this.reloadToken = 0,
    super.key,
  });

  final AppDatabase db;
  final int reloadToken;

  /// 中文：**当前的设置。** 笔记页只需要里面的 `languageCode` 一项：控制器在 `initState` 里造，
  ///       而那一刻**不许查 `BuildContext`**，所以先按设置里的语言代码取一张文案表
  ///       （`NotesStrings.forCode`），随后由 `didChangeDependencies` 用作用域里**当场生效**的那张
  ///       覆盖掉——形状与理由逐条同 `ToolDetailScreen`（那里也是为了保存时写进库的那几句话）。
  ///       由外壳递进来（`AppShell` 本来就拿着 `settings`，计算页 / 工具页同样由它递）。
  /// English: **the current settings.** The notes page only needs `languageCode` from it: the
  ///          controller is built in `initState`, where a `BuildContext` **may not be queried**, so
  ///          construction takes the copy table for the settings' language code
  ///          (`NotesStrings.forCode`) and `didChangeDependencies` then overwrites it with the scope's
  ///          **immediately effective** one — the same shape and the same reasons, one for one, as
  ///          `ToolDetailScreen` (which does it for the sentences it stores when saving). It is handed
  ///          in by the shell (which already holds `settings`, as it does for the calculator and tools
  ///          pages).
  final AppSettings settings;

  /// 中文：**把一条工具结果的标签换成当前语言。** 历史行里工具那条载荷是 `标签: 值`，标签是
  ///       `ToolResultLabelStrings` 的键（键就是中文标签，712 条现成）。**由外壳递进来**，因为
  ///       笔记页与工具页互不 import（仓库的既有边界：`features/` 之间不互相依赖，
  ///       `shared/presentation/app_shell.dart` 是唯一同时认得两边的地方）。查不到时实现返回
  ///       原样，所以中文界面下这一格一个字节不动。
  /// English: **renders a tool result's label into the active language.** A tool row's payload is
  ///          `label: value`, and the label is a key of `ToolResultLabelStrings` (the key *is* the
  ///          Chinese label; 712 of them exist). **It is handed in by the shell**, because the notes
  ///          page and the tools page do not import each other (the repository's existing boundary:
  ///          `features/` do not depend on one another, and `shared/presentation/app_shell.dart` is
  ///          the only place that knows both). A miss returns its argument unchanged, so in the
  ///          Chinese interface this cell does not move by a byte.
  final String Function(String label) toolResultLabel;

  @override
  State<NotesPage> createState() => _NotesPageState();
}

/// 中文：**一行历史结果怎么画**，与页面状态无关，所以是一个能单独测的顶层函数。
///       `number` 与 `opaque` 原样（前者本来就中性，后者重渲染不了）；`tool` 把 `标签: 值` 按
///       第一个 `': '` 切开，标签交给外壳递进来的 [NotesPage.toolResultLabel]，值原样拼回。
///       **只动显示，不动存的那一份**——复制、报告、笔记正文读的仍是 `item.result` 原样
///       （沿用仓库"复制出去的是数据"的既有立场）。
/// English: **how one history result is drawn**, independent of page state, so it is a top-level
///          function that can be tested on its own. `number` and `opaque` as they stand (the former is
///          already neutral, the latter cannot be re-rendered); `tool` splits `label: value` on the
///          first `': '`, hands the label to the shell-supplied [NotesPage.toolResultLabel], and puts
///          the value back as it was. **Only the display moves, not the stored copy** — copy, report
///          and note body still read `item.result` unchanged (the repository's existing "what is
///          copied out is data" position).
String historyResultText(
  HistoryItem item,
  String Function(String label) toolResultLabel,
) {
  // 中文：`switch` 表达式必须穷尽 [HistoryResultKind]——加一种 kind 时这里编译不过。
  // English: the `switch` expression must exhaust [HistoryResultKind], so adding a kind breaks the
  //          build here.
  return switch (item.resultKind) {
    HistoryResultKind.number || HistoryResultKind.opaque => item.result,
    HistoryResultKind.tool => _toolHistoryResultText(item.result, toolResultLabel),
  };
}

/// 中文：`tool` 那条路。`': '` 找不到时**原样返回**——分类器只会把带 `': '` 的载荷判成 `tool`，
///       所以这是给"老备份里被显式标成 tool 却形状不符"的行留的兜底，不是正常路径。
/// English: the `tool` path. When `': '` is absent it **returns its argument** — the classifier only
///          marks a `label: value` payload as `tool`, so this is a fallback for a row an old backup
///          explicitly marked `tool` whose shape does not match, not a normal path.
String _toolHistoryResultText(
  String result,
  String Function(String label) toolResultLabel,
) {
  final separator = result.indexOf(': ');
  if (separator < 0) return result;
  final label = result.substring(0, separator);
  final value = result.substring(separator + 2);
  return '${toolResultLabel(label)}: $value';
}

class _NotesPageState extends State<NotesPage> {
  late final NotesController _controller;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchTimer;
  bool _savingNote = false;
  bool _importingClipboard = false;
  final Set<int> _selectedHistoryIds = {};
  final Set<int> _selectedNoteIds = {};

  bool get _selectionActive =>
      _selectedHistoryIds.isNotEmpty || _selectedNoteIds.isNotEmpty;

  int get _selectedCount =>
      _selectedHistoryIds.length + _selectedNoteIds.length;

  @override
  void initState() {
    super.initState();
    _controller = NotesController(
      historyRepository: HistoryRepository(widget.db),
      notesRepository: NotesRepository(widget.db),
      // 中文：这里**不许查 `BuildContext`**（`initState` 里 `dependOnInheritedWidgetOfExactType`
      //       会抛），所以先按设置里的语言代码取一张；紧接着的 `didChangeDependencies` 会换成
      //       作用域中当场生效的那张。与 `ToolDetailScreen` 同一形状。
      // English: a `BuildContext` **may not be queried here** (inside `initState`
      //          `dependOnInheritedWidgetOfExactType` throws), so construction takes the table for the
      //          settings' language code; the `didChangeDependencies` right after swaps in the scope's
      //          immediately effective one. Same shape as `ToolDetailScreen`.
      strings: NotesStrings.forCode(widget.settings.languageCode),
    )..addListener(_onControllerChanged);
    _controller.load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 中文：**这一句是"换语言后存下去的标题也跟着换"的关键。** 控制器活得比一帧长，`initState`
    //       里那张是按当时的设置取的；用户换语言时 `app.dart` 只换内存里的 `_language`（不重载
    //       设置记录），所以只读 `widget.settings` 会停在旧语言上。这里按作用域里**当场生效**的
    //       那张覆盖，与 `ToolDetailScreen.didChangeDependencies` 同一个做法。
    // English: **this line is what makes the stored titles follow a language change.** The controller
    //          outlives one frame and the table from `initState` came from the settings of that
    //          moment; a language change makes `app.dart` swap only the in-memory `_language` (the
    //          settings record is not reloaded), so reading `widget.settings` alone would stay on the
    //          old language. This overwrites it with the scope's **immediately effective** table, the
    //          same practice as `ToolDetailScreen.didChangeDependencies`.
    _controller.strings = NotesStrings.of(context);
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant NotesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken) {
      _resetTransientStateAfterExternalReload();
      _controller.load();
    }
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final strings = NotesStrings.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      children: [
        _header(),
        const SizedBox(height: 12),
        TextField(
          controller: _searchController,
          onChanged: _setSearchQuery,
          decoration: InputDecoration(
            hintText: strings.searchHint,
            prefixIcon: const Icon(Icons.search),
          ).copyWith(
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _searchController,
              builder: (context, value, child) {
                if (value.text.isEmpty) return const SizedBox.shrink();
                return IconButton(
                  tooltip: strings.clearSearchTooltip,
                  onPressed: _clearSearch,
                  icon: const Icon(Icons.close),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _tabPill(NotesTab.all, strings.tabAll),
              _tabPill(NotesTab.notes, strings.tabNotes),
              _tabPill(NotesTab.history, strings.tabHistory),
              _tabPill(NotesTab.formulas, strings.tabFormulas),
              _tabPill(NotesTab.tools, strings.tabTools),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _filterSummary(),
        const SizedBox(height: 16),
        if (_controller.showsHistory) ...[
          SectionTitle(strings.historySectionTitle),
          _historySection(),
          const SizedBox(height: 14),
        ],
        if (_controller.showsNotes) ...[
          SectionTitle(strings.notesSectionTitle),
          _notesSection(),
        ],
      ],
    );
  }

  void _toggleHistorySelection(int id) {
    setState(() {
      if (!_selectedHistoryIds.add(id)) _selectedHistoryIds.remove(id);
    });
  }

  void _toggleNoteSelection(int id) {
    setState(() {
      if (!_selectedNoteIds.add(id)) _selectedNoteIds.remove(id);
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedHistoryIds.clear();
      _selectedNoteIds.clear();
    });
  }

  void _resetTransientStateAfterExternalReload() {
    _searchTimer?.cancel();
    _searchController.clear();
    _controller.setQuery('');
    if (!_selectionActive) return;
    setState(() {
      _selectedHistoryIds.clear();
      _selectedNoteIds.clear();
    });
  }

  void _clearSelectionForFilterChange() {
    if (!_selectionActive) return;
    setState(() {
      _selectedHistoryIds.clear();
      _selectedNoteIds.clear();
    });
  }

  void _selectVisibleItems() {
    setState(() {
      final visibleHistoryIds = _controller.showsHistory
          ? _controller.visibleHistory.map((item) => item.id).toSet()
          : const <int>{};
      final visibleNoteIds = _controller.showsNotes
          ? _controller.visibleNotes.map((item) => item.id).toSet()
          : const <int>{};
      final allVisibleSelected =
          visibleHistoryIds.every(_selectedHistoryIds.contains) &&
              visibleNoteIds.every(_selectedNoteIds.contains) &&
              (visibleHistoryIds.isNotEmpty || visibleNoteIds.isNotEmpty);

      if (allVisibleSelected) {
        _selectedHistoryIds.removeAll(visibleHistoryIds);
        _selectedNoteIds.removeAll(visibleNoteIds);
      } else {
        _selectedHistoryIds.addAll(visibleHistoryIds);
        _selectedNoteIds.addAll(visibleNoteIds);
      }
    });
  }
}
