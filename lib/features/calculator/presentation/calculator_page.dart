import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../application/app_settings.dart';
import '../../../application/controllers/calculator_controller.dart';
import '../../../application/controllers/expression_selection.dart';
import '../../../core/platform/app_haptics.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../data/local/app_database.dart';
import '../../../data/repositories/history_repository.dart';
import '../../../data/repositories/notes_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../shared/presentation/calc_theme.dart';
import 'keypad/calculator_keypad.dart';
import 'keypad/hiper_keypad.dart';
import 'widgets/calculator_display.dart';
import 'widgets/inline_expression_editor.dart';

/// 中文：计算器主界面——上半是两行显示面板（`CalculatorDisplay`），下半是 HiPER 键位表渲染出的
///       键盘（`CalculatorKeypad`），**不滚动**。UI 只负责布局和输入分发，计算逻辑留在
///       CalculatorController，主题配色全部取自 `CalcTheme`。
/// English: The calculator main screen — a two-line display panel (`CalculatorDisplay`) above a
///          keypad rendered from the HiPER key table (`CalculatorKeypad`), with **no scrolling**.
///          The UI only lays out and dispatches input; calculation stays in CalculatorController and
///          every colour comes from `CalcTheme`.
class CalculatorPage extends StatefulWidget {
  const CalculatorPage({
    required this.db,
    required this.onOpenSettings,
    required this.settings,
    this.reloadToken = 0,
    this.onNavigate,
    super.key,
  });

  final AppDatabase db;
  final VoidCallback onOpenSettings;
  final AppSettings settings;
  final int reloadToken;

  /// 中文：页面级导航（`HISTORY`、`OTHER`、`CNST`、`CONV` 与四个进制胶囊）。可选——为空时这些键
  ///       是惰性的，独立使用本页（例如组件测试）不会虚构出目标页；外壳接入后传 'history'/'tools'。
  /// English: Page-level navigation (the `HISTORY`, `OTHER`, `CNST`, `CONV` keys and the four base
  ///          pills). Optional — with no callback those keys are inert and no destination is invented
  ///          for standalone use (widget tests included); the shell passes 'history'/'tools' once it
  ///          is wired.
  final void Function(String destination)? onNavigate;

  /// 中文：本页 `_pressKey` **显式**派发的动作 id 集合——即它全部 `case` 标签去重后的并集。
  ///       它与下面的 `defaultInputKeyIds` 合起来必须覆盖 `hiper_keypad.dart` 里每一个已启用的
  ///       id：这正是本计划那句「改键位表，别的地方不用动」的可测形式，
  ///       `test/features/keypad_definition_test.dart` 逐格走表守住它，主屏也有一条逐格派发的
  ///       行为测试。改 `_pressKey` 的 case 时务必同步改这里，否则两条测试都会红。
  /// English: The action ids this page's `_pressKey` dispatches **explicitly** — the deduplicated union
  ///          of its `case` labels. Together with `defaultInputKeyIds` below it must cover every enabled
  ///          id `hiper_keypad.dart` can produce: that is the testable form of this plan's "edit the key
  ///          table, change nothing else", guarded cell by cell by
  ///          `test/features/keypad_definition_test.dart` and by a dispatch-per-id behaviour test on the
  ///          screen itself. Adding or removing a `case` in `_pressKey` means updating this set too, or
  ///          both tests go red.
  static const Set<String> dispatchedKeyIds = <String>{
    // 修饰键 / 页面级动作
    'shift', 'hyp', 'drawer', 'openHistory', 'openTools',
    'openConstants', 'openUnits', 'baseDec', 'baseHex', 'baseBin', 'baseOct',
    // 编辑与结果
    'backspace', 'clear', 'equals', 'angleMode', 'negate', 'ans',
    // 记忆寄存器
    'memoryRecall', 'memoryStore', 'memoryAdd', 'memorySubtract',
    // 插入文本（`ins:` 前缀）
    'ins:pi', 'ins:e', 'ins:^-1', 'ins:^2', 'ins:^3', 'ins:^', 'ins:10^',
    'ins:e^', 'ins:inf', 'ins:%', 'ins:exp',
    // 一元函数（含只从 `OTHER` 面板进来的那些）
    'sin', 'cos', 'tan', 'asin', 'acos', 'atan', 'sinh', 'cosh', 'tanh',
    'cot', 'sec', 'csc', 'log₂', 'exp', 'floor', 'ceil', 'round',
    'deg', 'rad', 'log', 'ln', 'abs', 'sqrt', 'cbrt', 'fact',
    // 二元函数
    'mod', 'nCr', 'nPr', 'root', 'min', 'max', 'gcd', 'lcm', 'atan2',
    // 只从 `OTHER` 面板进来的常数与角度快捷值
    '2ˣ', '90°', '180°', '360°', 'φ', '√2', 'τ', 'ln2', 'ln10', 'g', 'c',
    '2π', 'π/2',
    // `×`/`÷` 的 id 是给解析器用的 ASCII，键面仍是 `×`/`÷`
    '*', '/',
  };

  /// 中文：`default` 分支**按字面量**输入的 id——数字、小数点、括号与加减。它们不是「没接住的
  ///       键」，而是刻意走 `CalculatorController.input`（它认得这些 token 并处理小数、括号与
  ///       折叠尾随运算符）。这个集合是那批 id 的唯一定义处，覆盖测试与派发测试都读它。
  /// English: The ids the `default` branch types **verbatim** — digits, the decimal point, brackets and
  ///          the plus and minus signs. These are not unwired keys: routing them through
  ///          `CalculatorController.input` is deliberate (it knows those tokens and handles decimals,
  ///          brackets and collapsing a trailing operator). This set is the one place defining that
  ///          batch; the coverage test and the dispatch test both read it.
  static const Set<String> defaultInputKeyIds = <String>{
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
    '.', '(', ')', '+', '-',
  };

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  /// 中文：内联编辑器的字号，与 `CalculatorDisplay` 表达式行的字号一致。
  /// English: The inline editor's font size, matching `CalculatorDisplay`'s expression line.
  static const double _inlineEditorFontSize = 19;

  /// 中文：显示区最多占可用高度的比例，以及它的高度上下限（下限见 `build` 里的注释）。
  /// English: The display band's share of the available height and its bounds (see `build`).
  static const double _displayHeightRatio = 0.38;
  static const double _displayHeightMin = 176;
  static const double _displayHeightMax = 230;

  /// 中文：`More...` 面板最多占屏幕高度的比例——够放下全部动作，又不会盖住显示区。
  /// English: How much of the screen the `More...` sheet may take — room for every action without
  ///          covering the display band.
  static const double _moreSheetHeightRatio = 0.7;

  /// 中文：`More...` 面板里光标键描边的透明度。
  /// English: Alpha of the cursor keys' border inside the `More...` sheet.
  static const double _cursorBorderAlpha = 0.3;

  late final CalculatorController _controller;
  bool _savingNote = false;
  bool _inlineEditing = false;
  bool _requestInlineFocus = false;
  bool _pastingCalculatorDetails = false;

  /// 中文：当前修饰态。`KeypadModifier` 一个值就同时表达了「SHIFT 还是 hyp」与「互斥」，
  ///       所以旧计划里另立一个 `bool _hypActive` 是多余的——两个字段表达同一事实只会走岔。
  /// English: The active modifier. One `KeypadModifier` value already carries both "SHIFT or hyp"
  ///          and their mutual exclusion, so a second `bool _hypActive` (as the plan sketched) would
  ///          duplicate the same fact and could only drift from it.
  KeypadModifier _modifier = KeypadModifier.none;

  @override
  void initState() {
    super.initState();
    _controller = CalculatorController(
      historyRepository: HistoryRepository(widget.db),
      notesRepository: NotesRepository(widget.db),
      settingsRepository: SettingsRepository(widget.db),
      settings: widget.settings,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.restoreIfEnabled();
    });
  }

  @override
  void didUpdateWidget(covariant CalculatorPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) {
      _controller.updateSettings(widget.settings);
    }
    if (oldWidget.reloadToken != widget.reloadToken) {
      _controller.reloadSettingsAndRestore();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = CalcTheme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // 中文：显示区固定取可用高度的 38%，clamp 在 176–230dp。176dp 是 `CalculatorDisplay`
        //       的高度下限（它的类注释按真实 Android 字体度量推导出：与字体无关的固定行 74dp，
        //       双行错误的内容约需 165dp），230dp 让高窗口下显示区不至于吃掉键盘。剩下的高度全给
        //       键盘：`Expanded` 填满、不给固定高度，于是任何窗口高度都不会溢出（键变矮而已）。
        // English: The display band takes 38% of the available height, clamped to 176–230dp. 176dp
        //          is `CalculatorDisplay`'s floor (its class comment derives 74dp of font-independent
        //          chrome plus ≈165dp of content for a two-line error under real Android metrics) and
        //          230dp stops it eating the keypad on tall windows. Everything left goes to the
        //          keypad, which fills it via `Expanded` with no fixed height, so no window height
        //          can overflow — the keys just get shorter.
        final displayHeight = (constraints.maxHeight * _displayHeightRatio)
            .clamp(_displayHeightMin, _displayHeightMax);
        return Column(
          children: [
            SizedBox(
              height: displayHeight,
              // 中文：只让依赖控制器状态的显示区重建，键盘本体不随每次输入重建。
              // English: Rebuild only the controller-dependent display band; the keypad itself does
              //          not rebuild on every input.
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) =>
                    _inlineEditing ? _editingSurface(theme) : _display(theme),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: CalculatorKeypad(
                // 中文：`modifierActive` 不传——`CalculatorKeypad` 由 `modifier` 自行推导，
                //       漏传也不会丢掉「修饰键已锁定」的提示。`shift`/`hyp` 两个键也走 `onKey`
                //       （键盘组件不认识任何 id），由这里的 `_pressKey` 切换修饰态。
                // English: `modifierActive` is omitted — `CalculatorKeypad` derives it from
                //          `modifier`, so the latched-modifier signal cannot be lost. The `shift`/`hyp`
                //          keys travel `onKey` too (the keypad widget knows no ids); `_pressKey` here
                //          flips the modifier.
                definition: hiperKeypad,
                modifier: _modifier,
                colors: theme.keys,
                background: theme.keypadBackground,
                onKey: _pressKey,
              ),
            ),
          ],
        );
      },
    );
  }

  /// 中文：两行显示面板。点表达式里的某个单元会在该单元的原文偏移处打开内联编辑器（用户原有的
  ///       编辑功能，保留）；`More...` 打开动作面板，☰ 打开外壳的抽屉。
  /// English: The two-line display panel. Tapping a display unit opens the inline editor at that
  ///          unit's source offset (the user's editing feature, preserved); `More...` opens the
  ///          action sheet and ☰ opens the shell's drawer.
  Widget _display(CalcTheme theme) {
    return CalculatorDisplay(
      expression: _controller.expression,
      result: _controller.result,
      hasError: _controller.hasError,
      statusTitle: _controller.resultStatusTitle,
      statusMessage: _controller.resultStatusMessage,
      cursorIndex: _controller.cursorIndex,
      angleMode: _controller.angleMode,
      hasMemory: _controller.memoryValue != 0,
      colors: theme.display,
      naturalDisplay: widget.settings.expressionDisplayMode == '数学符号',
      onTapOffset: (sourceOffset) =>
          _openInlineEditor(sourceOffset: sourceOffset),
      onMore: _openMoreSheet,
      onOpenDrawer: _openDrawer,
    );
  }

  /// 中文：内联编辑时的显示区。用户的编辑器组件占满整块区域，底色与内边距沿用显示面板的配色，
  ///       键盘仍然可见可点——按键写入编辑器里的选区，这正是这套编辑交互的核心。
  /// English: The display band while inline editing. The user's editor widget fills the band on the
  ///          display panel's own background and padding, and the keypad stays visible and tappable:
  ///          its keys write into the editor's selection, which is the whole point of this editing
  ///          interaction.
  Widget _editingSurface(CalcTheme theme) {
    return Container(
      color: theme.display.background,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      alignment: Alignment.center,
      child: InlineExpressionEditor(
        expression: _controller.expression,
        selection: _controller.selection,
        onExpressionChanged: _controller.setExpression,
        onSelectionChanged: _controller.setSelection,
        onFocusLost: _closeInlineEditor,
        onPastePointerDown: _beginCalculatorDetailsPaste,
        onPasteGestureEnded: _endCalculatorDetailsPasteGesture,
        onPasteCalculatorDetails: _pasteCalculatorDetails,
        requestFocus: _requestInlineFocus,
        style: TextStyle(
          color: theme.display.expressionFg,
          fontSize: _inlineEditorFontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// 中文：抽屉按钮。外壳的 Scaffold 有 Drawer 就打开它；本页单独使用时（组件测试就是这种）
  ///       Scaffold 里没有 drawer，于是是空操作。
  /// English: The drawer button: opens the shell Scaffold's drawer when it has one. Standalone —
  ///          which is what the widget tests do — the Scaffold has no drawer, so it is a no-op.
  void _openDrawer() {
    Scaffold.maybeOf(context)?.openDrawer();
  }

  /// 中文：页面级导航。`onNavigate` 为空时惰性——不虚构目标页。
  /// English: Page-level navigation; inert while `onNavigate` is null — no destination is invented.
  void _navigate(String destination) {
    widget.onNavigate?.call(destination);
  }

  /// 中文：SHIFT 与 hyp 互斥（它们是同一个字段的两个值），再点一次各自的键退出该修饰态。
  /// English: SHIFT and hyp are mutually exclusive (two values of one field); tapping a latched
  ///          modifier key again leaves that state.
  void _toggleShift() {
    _feedback();
    setState(() {
      _modifier = _modifier == KeypadModifier.shift
          ? KeypadModifier.none
          : KeypadModifier.shift;
    });
  }

  void _toggleHyp() {
    _feedback();
    setState(() {
      _modifier = _modifier == KeypadModifier.hyp
          ? KeypadModifier.none
          : KeypadModifier.hyp;
    });
  }

  /// 中文：SHIFT 是一次性修饰态——任何一次按键之后就复位（HiPER 行为）；hyp 是持续态，只能由
  ///       hyp 键退出，所以不在这里复位。
  /// English: SHIFT is one-shot: it clears after any key press (HiPER's behaviour). hyp latches and
  ///          can only be left by the hyp key, so it is not cleared here.
  void _clearOneShotShift() {
    if (_modifier != KeypadModifier.shift) return;
    setState(() => _modifier = KeypadModifier.none);
  }

  /// 中文：`More...` 面板里的两个可长按光标键。配色仍全部来自 `CalcTheme`：图标用次要状态色，
  ///       底色用显示区底色，描边是该色的低透明度版本（不引入新的色位，也没有硬编码色值）。
  /// English: The two hold-to-repeat cursor keys inside the `More...` sheet. Every colour still comes
  ///          from `CalcTheme`: the icon takes the secondary status colour, the fill the display
  ///          background, and the border a low-alpha version of the icon colour — no new colour slot
  ///          and no hardcoded value.
  Widget _repeatableCursorButton({
    required CalcTheme theme,
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required VoidCallback onBlockMove,
    required VoidCallback onRepeat,
  }) {
    return _RepeatableCursorButton(
      icon: icon,
      tooltip: tooltip,
      color: theme.display.statusFg,
      backgroundColor: theme.display.background,
      borderColor: theme.display.statusFg.withValues(alpha: _cursorBorderAlpha),
      onTap: onTap,
      onBlockMove: onBlockMove,
      onRepeat: onRepeat,
    );
  }

  /// 中文：记忆寄存器的读数——`M ` 加按设置格式化的值，与应用其余处的数字格式一致：显示结果
  ///       （`calculator_controller.dart:530`）与导出报告文本（`:544`）都按 `settings.groupThousands`
  ///       格式化。重写前的记忆条是唯一漏掉该设置的地方（只传了 precision），所以读数现在会写
  ///       `M 12,345` 而不是 `M 12345`——由「记忆读数按设置的千分位格式化」这条测试钉住。
  /// English: The memory register's reading — `M ` plus the value formatted per settings, matching how
  ///          the rest of the app formats numbers: both the displayed result
  ///          (`calculator_controller.dart:530`) and the exported report text (`:544`) honour
  ///          `settings.groupThousands`. The pre-rewrite memory bar was the one place that ignored the
  ///          setting (it passed `precision` only), so the reading now shows `M 12,345` rather than
  ///          `M 12345` — pinned by the 「记忆读数按设置的千分位格式化」 test.
  String _memoryLabel() {
    return 'M ${formatNumber(
      _controller.memoryValue,
      precision: widget.settings.precision,
      groupThousands: widget.settings.groupThousands,
    )}';
  }

  /// 中文：面板里的「编辑表达式」：先关面板再打开内联编辑器并要求焦点——旧工具条上那颗编辑按钮的行为。
  /// English: The sheet's "edit expression": close the sheet, then open the inline editor asking for
  ///          focus — exactly what the old toolbar's edit button did.
  void _editFromSheet() {
    _openInlineEditor(requestFocus: true);
  }

  /// 中文：`OTHER` 打开的「更多函数」面板。HiPER 手册里 `OTHER` 就是「键盘放不下的函数」的入口，
  ///       所以这里只列 HiPER 网格上没有专属键位的函数与常数（`√x`、`x²`、`n!` 这些已经有键的
  ///       不重复出现）。机制与 `More...` 相同，只是内容不同。
  /// English: The "more functions" sheet `OTHER` opens. In HiPER's manual `OTHER` is the entry point
  ///          for the functions the keypad cannot fit, so this lists only the functions and constants
  ///          with no dedicated HiPER grid cell (ones that already have a key — `√x`, `x²`, `n!` — are
  ///          not repeated). Same mechanism as `More...`, different content.
  void _openMoreFunctionsSheet() {
    final theme = CalcTheme.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * _moreSheetHeightRatio,
      ),
      builder: (sheetContext) => _MoreFunctionsSheet(page: this, theme: theme),
    );
  }

  /// 中文：`More...` 打开的动作面板。它是被删掉的三块（底部操作行、常驻记忆条、显示工具条）里那些
  ///       操作的落点——复制结果、保存笔记、撤销/重做、编辑表达式、退格、光标移动，以及记忆寄存器。
  ///       面板比显示区更高优先级：`isScrollControlled` 让它按内容取高（上限 70% 屏高），
  ///       内容再长也能滚动，任何窗口高度都不会溢出。
  /// English: The action sheet `More...` opens. It is where the operations from the three deleted
  ///          pieces (the action row, the permanent memory bar and the display toolbar) now live:
  ///          copy, save note, undo/redo, the explicit edit action, backspace, cursor movement and
  ///          the memory register. `isScrollControlled` lets it size to its content up to 70% of the
  ///          screen height, and the content scrolls past that, so no window height can overflow.
  void _openMoreSheet() {
    final theme = CalcTheme.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * _moreSheetHeightRatio,
      ),
      builder: (sheetContext) => AnimatedBuilder(
        // 中文：面板里的记忆读数与撤销/重做可用态要跟着控制器走，否则面板打开期间它们会僵住。
        // English: The sheet's memory reading and undo/redo availability follow the controller, so they
        //          do not freeze while the sheet is open.
        animation: _controller,
        builder: (context, _) => _MoreSheet(page: this, theme: theme),
      ),
    );
  }

  Future<void> _copyResult() async {
    try {
      await Clipboard.setData(ClipboardData(text: _controller.copyText()));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已复制计算详情')));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('无法复制计算详情')));
      }
    }
  }

  Future<void> _pasteCalculatorDetails() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (!mounted) return;
      final paste = _controller.applyPastedText(data?.text ?? '');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(paste.summary)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('无法读取剪贴板')));
      }
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pastingCalculatorDetails = false;
      });
    }
  }

  void _beginCalculatorDetailsPaste() {
    _pastingCalculatorDetails = true;
  }

  void _endCalculatorDetailsPasteGesture() {
    _pastingCalculatorDetails = false;
  }

  Future<void> _saveNote() async {
    // 中文：保存笔记是异步数据库写入，页面退出后不能再使用旧 context 弹提示。
    // English: Saving notes writes to SQLite asynchronously; after navigation, the old context must not show feedback.
    if (_savingNote) return;
    if (!_controller.canSaveCurrentExpression) {
      _showCurrentStatusSnack();
      return;
    }
    _savingNote = true;
    try {
      final result = await _controller.saveToNote();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.message)));
    } finally {
      _savingNote = false;
    }
  }

  void _showCurrentStatusSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_controller.resultStatusMessage)),
    );
  }

  Future<void> _pressKey(String key) async {
    _feedback();
    // 中文：SHIFT 是一次性修饰态，按键后自动复位；hyp 是持续态，不在这里复位。两个修饰键自身例外：
    //       它们由下面的 case 切换，若先在这里复位，再点一次 SHIFT 会「复位又立刻锁上」，永远退不出
    //       SHIFT 态。
    // English: SHIFT is one-shot and clears after a press; hyp latches and is not cleared here. The two
    //          modifier keys themselves are the exception: the cases below flip them, and clearing first
    //          would turn a second SHIFT tap into "unlatch then immediately relatch", never leaving the
    //          SHIFT state.
    if (key != 'shift' && key != 'hyp') _clearOneShotShift();
    // 中文：按键 id 在这里统一映射为控制器动作与解析器表达式，避免 parser 混入展示层符号。id 逐字来自
    //       `hiper_keypad.dart`（含 camelCase 的 `dis:pagePrev`、`dis:xchgE` 这类），修饰态解析出的
    //       变体 id（`asin`、`ins:^3`、`cbrt`…）也走同一条通路。
    // English: Key ids are mapped to controller actions and parser expressions here, keeping display
    //          symbols out of the parser. Ids come verbatim from `hiper_keypad.dart` (camelCase ones
    //          such as `dis:pagePrev` and `dis:xchgE` included), and the variant id a modifier
    //          resolves to (`asin`, `ins:^3`, `cbrt`, …) travels the same path.
    switch (key) {
      // 中文：修饰键。`CalculatorKeypad` 不认识任何 id，`SHIFT`/`hyp` 两个键的 id 就像别的键一样交到
      //       这里，由这两个 case 切换修饰态——这是它们唯一的处理处。
      // English: The modifier keys. `CalculatorKeypad` knows no ids; the `SHIFT`/`hyp` keys hand their
      //          ids here like every other key and these two cases flip the state — the only place that
      //          handles them.
      case 'shift':
        _toggleShift();
      case 'hyp':
        _toggleHyp();
      // 中文：导航键。`drawer` 打开外壳抽屉，其余交给页面的 `onNavigate`；为空时惰性——独立使用本页
      //       （组件测试）不虚构目标页。四个进制胶囊是进制换算入口，与 CNST/CONV 同归工具箱。
      // English: Navigation. `drawer` opens the shell's drawer and the rest go to the page's
      //          `onNavigate`, which is inert when null — standalone use (widget tests) invents no
      //          destination. The four base pills are base-conversion entry points and belong with
      //          CNST/CONV under the toolbox.
      case 'drawer':
        _openDrawer();
      case 'openHistory':
        _navigate('history');
      // 中文：`OTHER` 在 HiPER 里就是「键盘放不下的那些函数」的入口（它的手册原话），所以它打开
      //       更多函数面板，而不是工具箱；工具箱仍由 `CNST`/`CONV` 与四个进制胶囊经 `onNavigate`
      //       抵达（`MENU` 打开抽屉）。
      // English: in HiPER `OTHER` is the entry point for the functions the keypad cannot fit (its
      //          manual says so), so it opens the more-functions sheet rather than the toolbox. The
      //          toolbox stays reachable through `CNST`/`CONV` and the four base pills via
      //          `onNavigate` (`MENU` opens the drawer).
      case 'openTools':
        _openMoreFunctionsSheet();
      case 'openConstants':
      case 'openUnits':
      case 'baseDec':
      case 'baseHex':
      case 'baseBin':
      case 'baseOct':
        _navigate('tools');
      case 'backspace':
        _controller.backspace();
      case 'clear':
        _controller.clear();
      case 'equals':
        final submitResult = await _controller.submit();
        if (mounted && submitResult.needsAttention) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(submitResult.message)));
        }
      // 中文：DRG 是循环键（HiPER 一个键在 DEG 与 RAD 之间切换），不是两个键。
      // English: DRG cycles (HiPER has one key switching between DEG and RAD, not two).
      case 'angleMode':
        _controller
            .setAngleMode(_controller.angleMode == 'DEG' ? 'RAD' : 'DEG');
      // 中文：`+/−` 用控制器已有的符号切换 token，不新造动作。
      // English: `+/−` uses the controller's existing sign-toggle token.
      case 'negate':
        _controller.input('+/-');
      case 'ans':
        _controller.append(_controller.reusableResult);
      // 中文：记忆键。`x→M`（id `memoryStore`）在 HiPER 上是把当前值**写入**寄存器（替换），而控制器
      //       只有累加的 `memoryAdd`；先清空再累加，两次调用合起来就是替换。写成两次是为了不碰控制器
      //       正在进行的其它工作，也不必为它加方法——将来控制器真有了 `memoryStore()`，这个 case
      //       应该直接换成那一次调用。
      // English: Memory keys. On HiPER `x→M` (id `memoryStore`) *writes* the current value into the
      //          register (a replace), while the controller only offers the accumulating `memoryAdd`;
      //          clearing first and adding after makes the pair a replace. Doing it in two calls avoids
      //          touching the work the controller is already doing and avoids adding a method for it —
      //          if a real `memoryStore()` ever lands on the controller, this case should call that
      //          instead.
      case 'memoryRecall':
        _controller.memoryRecall();
      case 'memoryStore':
        _controller.memoryClear();
        _controller.memoryAdd();
      case 'memoryAdd':
        _controller.memoryAdd();
      case 'memorySubtract':
        _controller.memorySubtract();
      // 中文：`ins:` 前缀 = 插入这段文本。三处落点比裸插入更贴切：`%` 走控制器的百分号运算（`50+10%`
      //       会被折算），`exp` 走一元函数（它插入 `exp(`，裸插的 `exp` 会被解析器拒绝），`inf` 是
      //       解析器承认的常数。
      // English: The `ins:` prefix means "insert this text". Three ids land on something better than a
      //          raw insert: `%` uses the controller's percent arithmetic (so `50+10%` is resolved),
      //          `exp` uses the unary function (it inserts `exp(`; a bare `exp` is rejected by the
      //          parser) and `inf` is a constant the parser knows.
      case 'ins:pi':
        _controller.append('pi');
      case 'ins:e':
        _controller.append('e');
      case 'ins:^-1':
        _controller.append('^-1');
      case 'ins:^2':
        _controller.append('^2');
      case 'ins:^3':
        _controller.append('^3');
      case 'ins:^':
        _controller.append('^');
      case 'ins:10^':
        _controller.append('10^');
      case 'ins:e^':
        _controller.append('e^');
      case 'ins:inf':
        _controller.append('inf');
      case 'ins:%':
        _controller.input('%');
      case 'ins:exp':
        _controller.applyUnaryFunction('exp');
      case 'sin':
      case 'cos':
      case 'tan':
      case 'asin':
      case 'acos':
      case 'atan':
      case 'sinh':
      case 'cosh':
      case 'tanh':
      // 中文：以下几项在 HiPER 网格上没有专属键位，只能从 `OTHER` 的「更多函数」面板进来
      //       （`cot`/`sec`/`csc`/`log₂`/`exp`、取整族与角度辅助族）；id 逐字沿用重写前
      //       `_functionSections` 的写法。
      // English: the ids below have no HiPER grid cell and are reachable only from `OTHER`'s
      //          "more functions" sheet (`cot`/`sec`/`csc`/`log₂`/`exp`, the rounding family and the
      //          angle helpers); the ids are kept verbatim from the pre-rewrite `_functionSections`.
      case 'cot':
      case 'sec':
      case 'csc':
      case 'log₂':
      case 'exp':
      case 'floor':
      case 'ceil':
      case 'round':
      case 'deg':
      case 'rad':
      case 'log':
      case 'ln':
      case 'abs':
      case 'sqrt':
      case 'cbrt':
      case 'fact':
        _controller.applyUnaryFunction(_functionNameForKey(key));
      case 'mod':
      case 'nCr':
      case 'nPr':
      case 'root':
      // 中文：同上——`gcd`/`lcm`/`atan2` 与 `min`/`max` 也只在「更多函数」面板里。
      // English: as above — `gcd`/`lcm`/`atan2` and `min`/`max` live only in the sheet too.
      case 'min':
      case 'max':
      case 'gcd':
      case 'lcm':
      case 'atan2':
        _controller.applyBinaryFunction(_functionNameForKey(key));
      // 中文：常数与角度快捷值，同样只在「更多函数」面板里——插入的文本逐字沿用旧函数面板，
      //       所以行为与重写前一致。
      // English: the constants and angle shortcuts, likewise sheet-only — the inserted text is kept
      //          from the old function panel, so the behaviour matches the pre-rewrite screen.
      case '2ˣ':
        _controller.append('2^');
      case '90°':
        _controller.append('90');
      case '180°':
        _controller.append('180');
      case '360°':
        _controller.append('360');
      case 'φ':
        _controller.append('1.61803398875');
      case '√2':
        _controller.append('sqrt(2)');
      case 'τ':
        _controller.append('(2*pi)');
      case 'ln2':
        _controller.append('0.69314718056');
      case 'ln10':
        _controller.append('2.30258509299');
      case 'g':
        _controller.append('9.80665');
      case 'c':
        _controller.append('299792458');
      case '2π':
        _controller.append('2*pi');
      case 'π/2':
        _controller.append('pi/2');
      // 中文：`×`/`÷` 的键面符号正是控制器认的运算符（`_isOperator` 只认 `+ - × ÷ ^`），而键位表的
      //       id 是给解析器用的 ASCII `*`/`/`。这里把 id 翻回符号，才会走 `_appendOperator`
      //       （它折叠尾随的运算符、忽略开头的运算符），而不是当成普通字符插入：`5` `+` `×` `3`
      //       得到 `5×3` 而不是 `5+*3`，空显示时按 `×` 什么也不发生。
      // English: the faces' `×`/`÷` are the tokens the controller recognises (`_isOperator` knows only
      //          `+ - × ÷ ^`) while the key table's ids are the parser-friendly ASCII `*` and `/`.
      //          Translating the id back to the symbol routes it through `_appendOperator` (which
      //          collapses a trailing operator and ignores a leading one) instead of a plain insert:
      //          `5` `+` `×` `3` gives `5×3`, not `5+*3`, and `×` on an empty display does nothing.
      //          `-` needs no such case: its id is ASCII and so is the controller's token.
      case '*':
        _controller.input('×');
      case '/':
        _controller.input('÷');
      default:
        // 中文：禁用键（`dis:` 前缀）键盘永不触发，万一到达就安静忽略，绝不当成文本写进表达式；
        //       数字、小数点、运算符与括号则直接输入——但**只有** `defaultInputKeyIds` 里那些 id 该
        //       走这条路。别的 id 落到这里说明 `_pressKey` 没接住它，而 `default` 会把它原样插进
        //       表达式（`×`/`÷` 的事故就是这个形状），所以开发期直接断言把那个 id 喊出来。
        //       `dispatchedKeyIds`/`defaultInputKeyIds` 与键位表的覆盖关系由
        //       `test/features/keypad_definition_test.dart` 逐格守着，本断言是那条守卫在运行期的回声：
        //       集合漏写、case 漏加，第一次按到那颗键就会响，而不是静默写错表达式。
        // English: A disabled key (`dis:`) is never fired by the keypad — if one arrives it is ignored
        //          quietly rather than typed into the expression; digits, the decimal point, operators
        //          and brackets go straight in — but **only** the ids in `defaultInputKeyIds` may travel
        //          this path. Any other id reaching here means `_pressKey` does not handle it, and
        //          `default` would insert it verbatim (the shape of the `×`/`÷` accident), so
        //          development fails an assertion that names it. The coverage of the key table by
        //          `dispatchedKeyIds`/`defaultInputKeyIds` is guarded cell by cell in
        //          `test/features/keypad_definition_test.dart`; this assertion is that guard's echo at
        //          run time — a missing set entry or a missing `case` rings on the first tap instead of
        //          silently writing the wrong expression.
        if (key.startsWith('dis:')) return;
        assert(
          CalculatorPage.defaultInputKeyIds.contains(key),
          '未派发的按键 id / undispatched key id: $key',
        );
        _controller.input(key);
    }
  }

  void _feedback() {
    AppHaptics.tap(
      enabled: widget.settings.haptics,
      strength: widget.settings.hapticStrength,
    );
  }

  /// 中文：键面标签与解析器函数名不一致的少数几个在这里换算（`nCr` → `ncr`、`nPr` → `npr`、
  ///       `log₂` → `log2`）；其余 id 本身就是解析器词汇。
  /// English: The few places where a key face and the parser's function name differ are translated
  ///          here (`nCr` → `ncr`, `nPr` → `npr`, `log₂` → `log2`); every other id already is parser
  ///          vocabulary.
  String _functionNameForKey(String key) {
    return switch (key) {
      'nCr' => 'ncr',
      'nPr' => 'npr',
      'log₂' => 'log2',
      _ => key,
    };
  }

  void _openInlineEditor({bool requestFocus = false, int? sourceOffset}) {
    if (sourceOffset != null) {
      _controller.setSelection(ExpressionSelection.collapsed(sourceOffset));
    }
    setState(() {
      _inlineEditing = true;
      _requestInlineFocus = requestFocus;
    });
  }

  void _closeInlineEditor() {
    if (!mounted || !_inlineEditing || _pastingCalculatorDetails) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_inlineEditing || _pastingCalculatorDetails) return;
      setState(() {
        _inlineEditing = false;
        _requestInlineFocus = false;
      });
    });
  }
}

/// 中文：`OTHER` 面板的内容——HiPER 网格上没有专属键位的函数与常数。每一条都按自己的 id 走
///       `_pressKey`，所以「面板里有什么」与「键盘能派发什么」用的是同一套词汇，没有第二份映射。
/// English: The contents of the `OTHER` sheet — the functions and constants with no HiPER grid cell.
///          Every entry dispatches its own id through `_pressKey`, so the sheet and the keypad share
///          one id vocabulary rather than keeping a second mapping.
class _MoreFunctionsSheet extends StatelessWidget {
  const _MoreFunctionsSheet({required this.page, required this.theme});

  final _CalculatorPageState page;
  final CalcTheme theme;

  /// 中文：逐字来自重写前 `_functionSections`，并且只保留 HiPER 网格没有格子的那些：三角补角
  ///       （`cot`/`sec`/`csc`）、`log₂`/`exp`、取整族、`min`/`max`、`gcd`/`lcm`/`atan2`、
  ///       角度辅助（`deg`/`rad` 与三个角度值）、`2ˣ`，以及常数快捷值。
  /// English: Kept verbatim from the pre-rewrite `_functionSections`, restricted to what the HiPER
  ///          grid has no cell for: the reciprocal trig functions (`cot`/`sec`/`csc`), `log₂`/`exp`,
  ///          the rounding family, `min`/`max`, `gcd`/`lcm`/`atan2`, the angle helpers (`deg`/`rad`
  ///          plus the three angle values), `2ˣ`, and the constant shortcuts.
  static const List<String> _entries = [
    'cot', 'sec', 'csc', 'log₂', 'exp',
    'floor', 'ceil', 'round', 'min', 'max',
    'gcd', 'lcm', 'atan2',
    'deg', 'rad', '90°', '180°', '360°',
    '2ˣ', 'φ', '√2', 'τ', 'ln2', 'ln10', 'g', 'c', '2π', 'π/2',
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final String id in _entries)
              TextButton(
                // 中文：与动作面板一样，选中即关面板再执行——面板盖住键盘，留着它挡住下一步输入。
                // English: as in the action sheet, a tap closes the sheet before running: it covers
                //          the keypad otherwise.
                onPressed: () {
                  Navigator.of(context).pop();
                  page._pressKey(id);
                },
                style: TextButton.styleFrom(
                  foregroundColor: theme.display.indicatorFg,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 38),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(id,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
          ],
        ),
      ),
    );
  }
}

/// 中文：`More...` 面板的内容。它直接驱动本页的控制器——面板是本页私有的 UI，把十几个回调逐个传进来
///       只会更难读，所以它拿页面状态本体。一次性动作（复制、保存、编辑、退格、撤销/重做、光标移动）
///       先关面板再执行；四个记忆寄存器按钮**不关面板**，这样记忆读数能在原地跟着更新。
/// English: The contents of the `More...` sheet. It drives the page's controller directly: the sheet is
///          page-private UI, and threading a dozen callbacks through would hurt readability more than
///          passing the state it belongs to. One-shot actions (copy, save, edit, backspace,
///          undo/redo, cursor moves) close the sheet first; the four memory-register buttons **keep
///          it open** so the memory reading updates in place.
class _MoreSheet extends StatelessWidget {
  const _MoreSheet({required this.page, required this.theme});

  final _CalculatorPageState page;
  final CalcTheme theme;

  @override
  Widget build(BuildContext context) {
    final controller = page._controller;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _action(context, '编辑表达式', page._editFromSheet),
                _action(context, '退格', controller.backspace),
                _action(context, '撤销', controller.undo,
                    enabled: controller.canUndo),
                _action(context, '重做', controller.redo,
                    enabled: controller.canRedo),
                _action(context, '复制结果', page._copyResult),
                // 中文：继续使用。它把结果**替换**成表达式（`ans` 是追加，两者不等价），而显示区在结果
                //       可用时会写着「结果可继续使用」/「当前值可继续使用」——那句话必须有对应的入口，
                //       否则 UI 在让用户做一件它不再提供的事。不可用时和撤销/重做一样置灰。
                // English: continue-with-result. It **replaces** the expression with the result (`ans`
                //          appends, so the two are not equivalent), and the display says "结果可继续使用"
                //          / "当前值可继续使用" whenever it is available — that sentence needs an entry
                //          point, or the UI asks for something it no longer offers. Greyed out when
                //          unavailable, like undo/redo.
                _action(context, '继续使用', controller.continueWithResult,
                    enabled: controller.canContinueWithResult),
                _action(context, '保存笔记', page._saveNote),
                _action(context, '移到开头', controller.moveCursorToStart),
                _action(context, '移到末尾', controller.moveCursorToEnd),
                // 中文：设置入口。它原本长在被删掉的应用名标题行上，而抽屉（Task 5）才是导航的主入口；
                //       这里保留一个次级入口，是因为没有它整台应用的设置页在主屏上就完全不可达了。
                // English: The settings entry. It used to live on the deleted app-name title row, and the
                //          drawer (Task 5) is the primary navigation; this secondary entry is kept because
                //          without it the settings page would be unreachable from the main screen at all.
                _action(context, '设置', page.widget.onOpenSettings),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                page._repeatableCursorButton(
                  theme: theme,
                  icon: Icons.keyboard_arrow_left,
                  tooltip: '光标左移（长按按表达式块左移后连续移动）',
                  onTap: controller.moveCursorLeft,
                  onBlockMove: controller.moveCursorByBlockBackward,
                  onRepeat: controller.moveCursorLeft,
                ),
                const SizedBox(width: 6),
                page._repeatableCursorButton(
                  theme: theme,
                  icon: Icons.keyboard_arrow_right,
                  tooltip: '光标右移（长按按表达式块右移后连续移动）',
                  onTap: controller.moveCursorRight,
                  onBlockMove: controller.moveCursorByBlockForward,
                  onRepeat: controller.moveCursorRight,
                ),
                const Spacer(),
                Text(
                  page._memoryLabel(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.display.statusFg,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _memoryButton('MR', controller.memoryRecall),
                _memoryButton('MC', controller.memoryClear),
                _memoryButton('M−', controller.memorySubtract),
                _memoryButton('M+', controller.memoryAdd),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 中文：一个一次性动作。点下去先关面板再执行——面板盖住键盘，留着它反而挡住了下一步输入。
  /// English: One one-shot action. It closes the sheet before running: the sheet covers the keypad, so
  ///          leaving it up would block the next input.
  Widget _action(
    BuildContext context,
    String label,
    VoidCallback onTap, {
    bool enabled = true,
  }) {
    return TextButton(
      onPressed: enabled
          ? () {
              Navigator.of(context).pop();
              onTap();
            }
          : null,
      style: TextButton.styleFrom(
        foregroundColor: theme.display.indicatorFg,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        minimumSize: const Size(0, 38),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  /// 中文：记忆寄存器按钮——不关面板，读数就在旁边的同一行里跟着变。
  /// English: A memory-register button — it keeps the sheet open so the reading beside it updates.
  Widget _memoryButton(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: OutlinedButton(
        onPressed: () {
          page._feedback();
          onTap();
        },
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(48, 34),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
      ),
    );
  }
}

class _RepeatableCursorButton extends StatefulWidget {
  const _RepeatableCursorButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.backgroundColor,
    required this.borderColor,
    required this.onTap,
    required this.onBlockMove,
    required this.onRepeat,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final Color backgroundColor;
  final Color borderColor;
  final VoidCallback onTap;
  final VoidCallback onBlockMove;
  final VoidCallback onRepeat;

  @override
  State<_RepeatableCursorButton> createState() =>
      _RepeatableCursorButtonState();
}

class _RepeatableCursorButtonState extends State<_RepeatableCursorButton> {
  static const _repeatInterval = Duration(milliseconds: 80);
  Timer? _repeatTimer;

  void _startRepeat(LongPressStartDetails details) {
    widget.onBlockMove();
    _repeatTimer ??= Timer.periodic(_repeatInterval, (_) => widget.onRepeat());
  }

  void _stopRepeat() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  @override
  void dispose() {
    _stopRepeat();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.tooltip,
      onLongPress: widget.onBlockMove,
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onLongPressStart: _startRepeat,
          onLongPressEnd: (_) => _stopRepeat(),
          onLongPressCancel: _stopRepeat,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: widget.borderColor),
            ),
            child: Icon(widget.icon, size: 17, color: widget.color),
          ),
        ),
      ),
    );
  }
}
