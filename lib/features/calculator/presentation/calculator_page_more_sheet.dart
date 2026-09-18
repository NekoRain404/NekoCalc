part of 'calculator_page.dart';

/// 中文：**`More...` 的面板：那颗按钮与它打开的面板。** 缝与理由逐条同 `calculator_page_other_sheet.dart` 的开头：本页自成一体的面板各有自己的 part 文件，这一块按同一条规矩搬出来。它是三块里最大的一块（面板 171 行 + 它自己那两个小部件），**面板直接拿页面状态本体**（理由写在 `_MoreSheet` 的类注释里）这一点也跟着一起搬了过来。搬的只是位置，内容一个字没有动。
///
/// English: **the `More...` panel: that button and the sheet it opens.** The seam and its reasons are the ones at the head of `calculator_page_other_sheet.dart`: every self-contained panel on this screen has its own part file and this one moved out by the same rule. It is the largest of the three (a 171-line panel plus its two small widgets), and **the panel takes the page state itself** (the reason is in `_MoreSheet`'s class comment) — that came across too. Only the position moved; not one character of the content changed.

extension _CalculatorPageMoreSheet on _CalculatorPageState {
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
        maxHeight: MediaQuery.sizeOf(context).height *
            _CalculatorPageState._moreSheetHeightRatio,
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
}

/// 中文：`More...` 面板的内容。它直接驱动本页的控制器——面板是本页私有的 UI，把十几个回调逐个传进来
///       只会更难读，所以它拿页面状态本体。一次性动作（复制、保存、编辑、退格、撤销/重做、光标移动）
///       先关面板再执行；四个记忆寄存器按钮**不关面板**，这样记忆读数能在原地跟着更新。唯一的例外是
///       **被拒的记忆键**：控制器有话要说（值放不进寄存器），而那句话落在面板盖住的那一条上，所以
///       面板先让开——判据与量到的数字在 `_reportMemoryFromSheet` 上。成功时它照旧原地不动。
/// English: The contents of the `More...` sheet. It drives the page's controller directly: the sheet is
///          page-private UI, and threading a dozen callbacks through would hurt readability more than
///          passing the state it belongs to. One-shot actions (copy, save, edit, backspace,
///          undo/redo, cursor moves) close the sheet first; the four memory-register buttons **keep
///          it open** so the memory reading updates in place. The one exception is a **refused**
///          memory key: the controller has something to say (the value does not fit the register)
///          and that sentence lands on the strip this sheet covers, so the sheet gets out of the way
///          — the argument and the measured numbers are on `_reportMemoryFromSheet`. On success it
///          stays put, exactly as before.
class _MoreSheet extends StatelessWidget {
  const _MoreSheet({required this.page, required this.theme});

  final _CalculatorPageState page;
  final CalcTheme theme;

  @override
  Widget build(BuildContext context) {
    final controller = page._controller;
    final strings = CalculatorStrings.of(context);
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
                _action(
                    context, strings.actionEditExpression, page._editFromSheet),
                _action(context, strings.actionBackspace, controller.backspace),
                _action(context, strings.actionUndo, controller.undo,
                    enabled: controller.canUndo),
                _action(context, strings.actionRedo, controller.redo,
                    enabled: controller.canRedo),
                _action(context, strings.actionCopyResult, page._copyResult),
                // 中文：继续使用。它把结果**替换**成表达式（`ans` 是追加，两者不等价），而显示区在结果
                //       可用时会写着「结果可继续使用」/「当前值可继续使用」——那句话必须有对应的入口，
                //       否则 UI 在让用户做一件它不再提供的事。不可用时和撤销/重做一样置灰。
                // English: continue-with-result. It **replaces** the expression with the result (`ans`
                //          appends, so the two are not equivalent), and the display says "结果可继续使用"
                //          / "当前值可继续使用" whenever it is available — that sentence needs an entry
                //          point, or the UI asks for something it no longer offers. Greyed out when
                //          unavailable, like undo/redo.
                _action(context, strings.actionContinueWith,
                    controller.continueWithResult,
                    enabled: controller.canContinueWithResult),
                _action(context, strings.actionSaveNote, page._saveNote),
                _action(context, strings.actionMoveToStart,
                    controller.moveCursorToStart),
                _action(context, strings.actionMoveToEnd,
                    controller.moveCursorToEnd),
                // 中文：设置入口。它原本长在被删掉的应用名标题行上，而抽屉（Task 5）才是导航的主入口；
                //       这里保留一个次级入口，是因为没有它整台应用的设置页在主屏上就完全不可达了。
                // English: The settings entry. It used to live on the deleted app-name title row, and the
                //          drawer (Task 5) is the primary navigation; this secondary entry is kept because
                //          without it the settings page would be unreachable from the main screen at all.
                _action(context, strings.actionSettings,
                    page.widget.onOpenSettings),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                page._repeatableCursorButton(
                  theme: theme,
                  icon: Icons.keyboard_arrow_left,
                  tooltip: strings.cursorLeftTooltip,
                  onTap: controller.moveCursorLeft,
                  onBlockMove: controller.moveCursorByBlockBackward,
                  onRepeat: controller.moveCursorLeft,
                ),
                const SizedBox(width: 6),
                page._repeatableCursorButton(
                  theme: theme,
                  icon: Icons.keyboard_arrow_right,
                  tooltip: strings.cursorRightTooltip,
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
                // 中文：`MR`/`MC` 不会拒绝——寄存器里那个值总写得回表达式，清零在已经是 0 时是
                //       空操作——所以它们永远没有话要说，`null` 就是「无话可说」。
                // English: `MR`/`MC` cannot refuse — the register's value always writes back into the
                //          expression and clearing an already-zero register is a no-op — so they never
                //          have anything to say, and `null` is "nothing to say".
                _memoryButton('MR', () {
                  controller.memoryRecall();
                  return null;
                }),
                _memoryButton('MC', () {
                  controller.memoryClear();
                  return null;
                }),
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

  /// 中文：记忆寄存器按钮——成功时不关面板，读数就在旁边的同一行里跟着变；`onTap` 返回控制器
  ///       那句话（`null` = 成了、无话可说），被拒时由 `_reportMemoryFromSheet` 先把面板收掉再说，
  ///       否则那句话会被面板盖住（判据与量到的数字在那个方法上）。
  ///       `String? Function()` 而不是 `VoidCallback`：后者会**静默吞掉**那个返回值，于是这颗键
  ///       又变回无声的——类型摆在这里，谁也别想绕过那句话。`MR`/`MC` 不会拒绝，它们显式回 `null`。
  /// English: A memory-register button — on success it keeps the sheet open so the reading beside it
  ///          updates; `onTap` returns the controller's sentence (`null` = it happened, nothing to
  ///          say), and on a refusal `_reportMemoryFromSheet` dismisses the sheet before speaking,
  ///          or the sheet would cover that sentence (the measurement and the argument are on that
  ///          method). `String? Function()` rather than `VoidCallback`: the latter would **silently
  ///          swallow** that return value and this key would go quiet again — the type is written
  ///          here so nobody has to remember. `MR`/`MC` cannot refuse and say `null` explicitly.
  Widget _memoryButton(String label, String? Function() onTap) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: OutlinedButton(
        onPressed: () {
          page._feedback();
          page._reportMemoryFromSheet(onTap());
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
