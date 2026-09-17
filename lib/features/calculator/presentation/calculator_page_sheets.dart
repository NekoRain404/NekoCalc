part of 'calculator_page.dart';

extension _CalculatorPageSheets on _CalculatorPageState {
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
      borderColor: theme.display.statusFg.withValues(alpha: _CalculatorPageState._cursorBorderAlpha),
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
        maxHeight: MediaQuery.sizeOf(context).height * _CalculatorPageState._moreSheetHeightRatio,
      ),
      builder: (sheetContext) => _MoreFunctionsSheet(page: this, theme: theme),
    );
  }

  /// 中文：`CONV` 打开的单位面板。面板**不自动关**（一次换算要插源、`to`、目标三样），插入直接
  ///       走控制器的 `input`——与键盘同一个入口，所以光标位置、撤销栈、边打边算全都照旧。
  /// English: the unit sheet `CONV` opens. It does **not** close itself (one conversion inserts the
  ///          source, a `to` and the target), and insertion goes through the controller's `input` — the
  ///          same entrance the keypad uses, so cursor position, the undo stack and as-you-type
  ///          evaluation all behave as before.
  void _openUnitSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * _CalculatorPageState._moreSheetHeightRatio,
      ),
      // 中文：**面板交出来的是裸记号，分隔符在这里（也是唯一一处）决定。** 真实按键流是一串
      //       相邻插入（`5` → `km` → `to` → `mi`），不加分隔符它们会粘成 `5kmtomi`——那**一个**
      //       标识符，翻译层拒收、旧解析器读不懂。见 [unitInsertionText] 上的长注释。
      // English: **the sheet hands over bare tokens and the separators are decided here (the only
      //          place).** The real keypad flow is a run of adjacent insertions (`5` → `km` → `to` →
      //          `mi`) and without separators they glue into `5kmtomi` — **one** identifier, refused by
      //          the translation and unreadable by the legacy parser. See the long note on
      //          [unitInsertionText].
      builder: (sheetContext) => UnitPickerSheet(
        onInsert: (token) =>
            _controller.input(unitInsertionText(token, _controller.expression)),
      ),
    );
  }

  /// 中文：`X` 打开的面板。与 `CONV` 那个同一种做法：插入走控制器的 `input`（与键盘同一个入口，
  ///       所以光标位置、撤销栈、边打边算全都照旧），读数与按钮的可用态跟着控制器走
  ///       （`AnimatedBuilder` 的 `animation` 就是控制器，与 `More...` 面板一样），于是「存入当前值」
  ///       按下去之后那一行在原地变成 `= 4`，不需要关掉重开。
  ///
  ///       面板**不自动关闭**：插 `x` 与存值各是一下，两次都要用。关它的方式是点面板外、按返回键，
  ///       或者点面板里的「关闭」。
  ///
  /// English: the sheet `X` opens. Same shape as the `CONV` one: insertion goes through the controller's
  ///          `input` (the same entrance the keypad uses, so cursor position, the undo stack and
  ///          as-you-type evaluation all behave as before), and the readings and button availability
  ///          follow the controller (the `AnimatedBuilder`'s animation is the controller, exactly as in
  ///          the `More...` sheet), so pressing "store current value" turns that row into `= 4` in
  ///          place with no need to close and reopen.
  ///
  ///          The sheet **does not close itself**: inserting `x` and storing a value are two separate
  ///          presses and both are wanted. Tapping outside, the back button, or the sheet's own "关闭"
  ///          closes it.
  void _openVariableSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight:
            MediaQuery.sizeOf(context).height * _CalculatorPageState._moreSheetHeightRatio,
      ),
      builder: (sheetContext) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => VariablePickerSheet(
          readings: <VariableReading>[
            for (final String name in kBindableVariableNames)
              VariableReading(
                name: name,
                value: _controller.variableValue(name),
              ),
          ],
          storableValue: _controller.storableVariableValue,
          onInsert: _controller.append,
          onAssign: _controller.assignVariable,
          onClear: _controller.clearVariable,
          onClose: () => Navigator.of(sheetContext).pop(),
        ),
      ),
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
        maxHeight: MediaQuery.sizeOf(context).height * _CalculatorPageState._moreSheetHeightRatio,
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
