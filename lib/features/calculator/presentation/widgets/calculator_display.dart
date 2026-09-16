import 'package:flutter/material.dart';

import '../../../../shared/presentation/calc_theme.dart';
import 'math_expression_view.dart';

/// 中文：状态行里按钮的边长——比 Material 默认的 48 小，面板本来就不高，但仍是手指能稳稳点到的
///       方块。状态行的高度就等于它。
/// English: Edge length of a status-row button — smaller than Material's default 48 because the
///          panel itself is short, yet still a square a finger can hit reliably. The status row is
///          exactly this tall.
const double _statusButtonSize = 40;

/// 中文：角度模式 chip 与记忆指示的高度。
/// English: Height of the angle-mode chip and the memory indicator.
const double _chipHeight = 24;

/// 中文：chip / 指示灯的圆角半径。
/// English: Corner radius of the chip and the indicators.
const double _chipRadius = 6;

/// 中文：chip 底色在显示区底上的浓度——用指示色的低透明度版本，因此底色仍全部来自
///       `CalcDisplayColors`，没有第二个色位，也没有硬编码色值。
/// English: How strongly the chip's fill sits on the display background — a low-alpha version of
///          the indicator colour, so the fill still comes entirely from `CalcDisplayColors`: no
///          second colour slot and no hardcoded value.
const double _chipFillAlpha = 0.12;

/// 中文：表达式字号（字号决定整条算式的大小，见 `MathExpressionView`）。
/// English: Expression font size (the size drives the whole equation's metrics, see
///          `MathExpressionView`).
const double _expressionFontSize = 19;

/// 中文：结果与等号的字号——结果行是面板里最重的一行，因此明显大于表达式。
/// English: Font sizes for the result and its equals sign — the result line is the heaviest line
///          in the panel, so it is clearly larger than the expression.
const double _resultFontSize = 30;
const double _equalsFontSize = 22;

/// 中文：错误行字号。
/// English: Font size of the error line.
const double _errorFontSize = 13;

/// 中文：两行显示面板——状态行、表达式行、结果行，出错时再多一行错误提示。
///       组件是**纯函数**：所有值都从构造参数进来，组件自身不持有任何状态、不读控制器、
///       不访问数据库，因此可以脱离应用直接测试。
/// English: The two-line display panel — a status row, the expression line and the result line,
///          plus an error line while there is an error. The widget is a **pure function**: every
///          value arrives as a constructor parameter, it holds no state, reads no controller and
///          touches no database, so it is testable without the app around it.
///
/// 布局 / Layout（自上而下 / top to bottom）:
/// 中文：1) 状态行：最左是抽屉按钮（`onOpenDrawer` 为空则不渲染），接着角度模式 chip、
///       记忆指示 `M`（`hasMemory` 为假时留空），`Spacer` 把 `More...` 推到最右
///       （`onMore` 为空则不渲染）；2) 表达式行：`MathExpressionView`，右对齐，外面套一圈横向
///       滚动，算式比屏幕宽时滚动而不是溢出；3) 结果行：右对齐，`=` 前缀 + 结果，都是纯文本；
///       4) 错误行：仅 `hasError` 为真时渲染。
/// English: 1) status row: the drawer button leftmost (not rendered when `onOpenDrawer` is null),
///          then the angle-mode chip, the `M` memory indicator (nothing when `hasMemory` is
///          false), and a `Spacer` pushing `More...` to the right edge (not rendered when
///          `onMore` is null); 2) expression line: `MathExpressionView`, right-aligned, inside a
///          horizontal scroll view so a long expression scrolls instead of overflowing; 3) result
///          line: right-aligned, an `=` prefix followed by the result, both plain text; 4) error
///          line: rendered only while `hasError` is true.
/// 中文：`statusTitle` 不占可视位置（本布局没有常驻状态卡），它作为整块面板的无障碍标签
///       ——详见该字段的注释。
/// English: `statusTitle` gets no visual slot (this layout has no permanent status card); it
///          serves as the whole panel's accessibility label — see that field's own comment.
///
/// 抽屉按钮（跨任务约定）/ The drawer button (cross-task contract):
/// 中文：主屏的 ☰ 由本组件渲染，`tooltip: '打开导航'`——任务 4 的主屏与任务 5 的外壳测试都靠
///       这个 tooltip 找到它，因此**主屏不得再另造一个 ☰**；`onOpenDrawer` 为空时它整个不渲染。
/// English: The screen's ☰ lives here and carries `tooltip: '打开导航'` — the Task 4 screen and
///          the Task 5 shell test both find it by that tooltip, so **no second ☰ may be built on
///          the screen**; when `onOpenDrawer` is null it is not rendered at all.
///
/// 结果行为什么是纯文本 / Why the result line is plain text:
/// 中文：求值器只产出 `double`，`iπ√14/6` 这类精确形式需要另一个引擎，不在本阶段；在结果行上
///       做自然排版只会把十进制值排成一棵毫无意义的公式树，所以这里刻意不排版。
/// English: The evaluator only produces a `double`; exact forms such as `iπ√14/6` need a
///          different engine and are out of scope here. Typesetting the result would only dress a
///          decimal value up as a formula tree that says nothing, so it is deliberately plain.
class CalculatorDisplay extends StatelessWidget {
  const CalculatorDisplay({
    required this.expression,
    required this.result,
    required this.hasError,
    required this.statusTitle,
    required this.statusMessage,
    required this.cursorIndex,
    required this.angleMode,
    required this.hasMemory,
    required this.colors,
    required this.naturalDisplay,
    this.onTapOffset,
    this.onMore,
    this.onOpenDrawer,
    super.key,
  });

  /// 中文：表达式原文，交给 `MathExpressionView` 解析排版。
  /// English: The expression source, handed to `MathExpressionView`.
  final String expression;

  /// 中文：结果文本（纯文本，见类注释）。
  /// English: The result text (plain, see the class comment).
  final String result;

  /// 中文：是否处于错误态——只决定错误行渲染与否，不改结果行的颜色。
  /// English: Whether the panel is in an error state — it decides only whether the error line is
  ///          rendered, not the result line's colour.
  final bool hasError;

  /// 中文：当前状态的标题（如「等待输入」「表达式需要修正」）。
  ///       本布局按 spec 移除了常驻结果状态卡、也**没有给标题留可视位置**（错误行只放
  ///       `statusMessage`），所以它在这里作为整块面板的无障碍标签存在：读屏用户听到的
  ///       「现在是什么状态」正是这句话，参数因此不是死参数，屏幕上也不会多出 spec 没有的一行。
  /// English: Title of the current state (e.g. "waiting for input", "the expression needs
  ///          fixing"). This layout removed the permanent status card — and the spec **gives the
  ///          title no visual slot** (the error line carries only `statusMessage`) — so it lives
  ///          on as the panel's accessibility label: what a screen reader announces as the state
  ///          is exactly this sentence. The parameter is therefore not dead, and no line the spec
  ///          never asked for appears on screen.
  final String statusTitle;

  /// 中文：错误态下的提示正文（如「缺少右括号」），即错误行的内容。
  /// English: The message body while in the error state (e.g. "missing closing bracket") — the
  ///          error line's content.
  final String statusMessage;

  /// 中文：光标所在的原文字符偏移，原样转交给 `MathExpressionView`。
  /// English: Cursor position as a source character offset, passed through to
  ///          `MathExpressionView`.
  final int? cursorIndex;

  /// 中文：当前角度模式，状态行左侧的 chip 显示它（`DEG` / `RAD`）。
  /// English: The current angle mode, shown by the chip on the left of the status row
  ///          (`DEG` / `RAD`).
  final String angleMode;

  /// 中文：记忆寄存器里是否有值——为真时状态行显示 `M` 徽标，为假时该位置空着。
  /// English: Whether the memory register holds a value — a truthy value shows the `M` badge in
  ///          the status row, and when false the slot stays empty.
  final bool hasMemory;

  /// 中文：显示区语义色，面板里的每一个色值都取自它。
  /// English: Semantic display colours; every colour in the panel comes from here.
  final CalcDisplayColors colors;

  /// 中文：是否自然排版，原样转交给 `MathExpressionView`（关闭时表达式退化为**一个**纯文本
  ///       `Text`，这是那个分支的对外契约）。
  /// English: Whether to typeset naturally, passed through to `MathExpressionView` (switched off,
  ///          the expression degrades to a **single** plain `Text` — that branch's contract).
  final bool naturalDisplay;

  /// 中文：点击某个显示单元时收到该单元在原串里的起始偏移。
  /// English: Called with the tapped display unit's start offset in the source string.
  final void Function(int sourceOffset)? onTapOffset;

  /// 中文：`More...` 按钮的回调；为空时按钮不渲染。
  /// English: Callback for the `More...` button; the button is not rendered when null.
  final VoidCallback? onMore;

  /// 中文：抽屉按钮的回调；为空时按钮不渲染（见类注释里的跨任务约定）。
  /// English: Callback for the drawer button; the button is not rendered when null (see the
  ///          cross-task contract in the class comment).
  final VoidCallback? onOpenDrawer;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: statusTitle,
      child: ColoredBox(
        color: colors.background,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _statusRow(),
              const SizedBox(height: 6),
              // 中文：表达式行吃掉全部剩余高度（面板高度由上层决定，本组件填满它）：
              //       面板变矮时先挤这一行，fixed 的状态行与结果行不会被裁掉。
              // English: The expression line takes all the leftover height (the panel's height is
              //          decided above, and this widget fills it): a shorter panel squeezes this
              //          line first, so the fixed status and result rows are never clipped.
              Expanded(child: _expressionLine()),
              const SizedBox(height: 6),
              _resultLine(),
              if (hasError) ...<Widget>[
                const SizedBox(height: 4),
                _errorLine(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 中文：状态行——抽屉按钮、角度模式 chip、记忆指示，`Spacer` 之后是 `More...`。
  /// English: The status row — drawer button, angle-mode chip, memory indicator, then `More...`
  ///          after a `Spacer`.
  Widget _statusRow() {
    return SizedBox(
      height: _statusButtonSize,
      child: Row(
        children: <Widget>[
          if (onOpenDrawer != null) ...<Widget>[
            _drawerButton(),
            const SizedBox(width: 4),
          ],
          _statusChip(angleMode),
          if (hasMemory) ...<Widget>[
            const SizedBox(width: 6),
            _memoryIndicator(),
          ],
          const Spacer(),
          if (onMore != null) _moreButton(),
        ],
      ),
    );
  }

  /// 中文：主屏的 ☰。tooltip 是本组件对外的固定契约（见类注释），图标色取次要状态色。
  ///       `shrinkWrap` 关掉 Material 默认把命中区撑到 48 的行为：那个隐形的 48 宽盒子会让状态行
  ///       的左间距忽大忽小，而这里的尺寸是自己定死的正方形，图标因此正好居中。
  /// English: The screen's ☰. Its tooltip is this widget's fixed outward contract (see the class
  ///          comment) and its icon takes the secondary status colour. `shrinkWrap` turns off
  ///          Material's default padding of the hit area out to 48: that invisible 48-wide box
  ///          makes the status row's left spacing read as uneven, while this size is a square of
  ///          our own choosing — so the icon sits exactly in its middle.
  Widget _drawerButton() {
    return IconButton(
      onPressed: onOpenDrawer,
      tooltip: '打开导航',
      icon: const Icon(Icons.menu),
      iconSize: 20,
      color: colors.statusFg,
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(
        width: _statusButtonSize,
        height: _statusButtonSize,
      ),
    );
  }

  /// 中文：角度模式 chip——底色是指示色的低透明度版本，文字用次要状态色（该色位的注释里
  ///       点名的第一用途就是角度制）。
  /// English: The angle-mode chip — its fill is a low-alpha indicator colour and its text uses the
  ///          secondary status colour, whose own doc comment names the angle mode as its first
  ///          use.
  Widget _statusChip(String label) {
    return Container(
      height: _chipHeight,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: colors.indicatorFg.withValues(alpha: _chipFillAlpha),
        borderRadius: BorderRadius.circular(_chipRadius),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colors.statusFg,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  /// 中文：记忆指示 `M`——一个徽标，所以用指示色；没有值时整块不渲染（不是画一个空徽标）。
  /// English: The `M` memory indicator — a badge, hence the indicator colour; with no value the
  ///          whole thing is absent rather than drawn empty.
  Widget _memoryIndicator() {
    return Container(
      height: _chipHeight,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: colors.indicatorFg.withValues(alpha: _chipFillAlpha),
        borderRadius: BorderRadius.circular(_chipRadius),
      ),
      child: Text(
        'M',
        style: TextStyle(
          color: colors.indicatorFg,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  /// 中文：`More...` 按钮——本阶段接入现有能力（复制结果、保存笔记等）的入口。
  ///       它只把点击转给上层，自身不关心菜单内容；`shrinkWrap` 与抽屉按钮同理，命中区不外扩，
  ///       于是它与右侧内边距的关系是可预算的。
  /// English: The `More...` button — the entry point to what already exists (copying the result,
  ///          saving a note, ...). It only forwards the tap and does not care what the menu holds;
  ///          `shrinkWrap` as on the drawer button keeps the hit area from expanding, so where its
  ///          right edge lands against the padding is predictable.
  Widget _moreButton() {
    return TextButton(
      onPressed: onMore,
      style: TextButton.styleFrom(
        foregroundColor: colors.indicatorFg,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        minimumSize: const Size(0, 34),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        'More...',
        style: TextStyle(
          color: colors.indicatorFg,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  /// 中文：表达式行——右对齐，外面套一圈横向滚动并 `reverse`，因此长算式停在**末尾**
  ///       （光标所在的那一端）而不是开头。`Align` 在有界宽度里把内容推到右边；算式比可用宽度
  ///       窄时滚动视图收缩成内容宽度，宽过可用宽度时才真的滚动——两种情况都不溢出。
  /// English: The expression line — right-aligned inside a horizontal, reversed scroll view, so a
  ///          long expression rests at its **end** (the end the caret is at) rather than its
  ///          start. `Align` pushes the content right within the bounded width; the scroll view
  ///          shrinks to the content while it fits and only then scrolls once it does not — no
  ///          overflow either way.
  Widget _expressionLine() {
    return Align(
      alignment: Alignment.centerRight,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: MathExpressionView(
          expression: expression,
          naturalDisplay: naturalDisplay,
          cursorIndex: cursorIndex,
          onTapOffset: onTapOffset,
          textStyle: TextStyle(
            color: colors.expressionFg,
            fontSize: _expressionFontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// 中文：结果行——`=` 与结果各自是一个 `Text`（不是拼成一行的 `RichText`），`FittedBox`
  ///       只缩不放，很长的数值因此缩到可用宽度里而不是溢出。
  /// English: The result line — the `=` and the result are separate `Text` widgets (not one
  ///          `RichText`), and the `FittedBox` only scales down, so a very long numeric result
  ///          shrinks into the available width instead of overflowing.
  Widget _resultLine() {
    return Align(
      alignment: Alignment.centerRight,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              '=',
              style: TextStyle(
                color: colors.resultFg,
                fontSize: _equalsFontSize,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              result,
              style: TextStyle(
                color: colors.resultFg,
                fontSize: _resultFontSize,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 中文：错误行——只有 `hasError` 为真时才会走到这里（见 `build`）。限两行并省略，
  ///       长提示既不会溢出宽度也不会把显示区撑破。
  /// English: The error line — reached only while `hasError` is true (see `build`). Capped at two
  ///          lines with an ellipsis, so a long message neither overflows the width nor bursts
  ///          the panel.
  Widget _errorLine() {
    return Text(
      statusMessage,
      textAlign: TextAlign.right,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: colors.errorFg,
        fontSize: _errorFontSize,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
