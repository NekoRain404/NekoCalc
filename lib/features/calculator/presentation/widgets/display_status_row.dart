import 'package:flutter/material.dart';

import '../../../../shared/presentation/calc_theme.dart';
import 'status_chips.dart';

/// 中文：状态行里按钮的边长——比 Material 默认的 48 小，面板本来就不高，但仍是手指能稳稳点到的
///       方块。状态行的高度就等于它。
/// English: Edge length of a status-row button — smaller than Material's default 48 because the
///          panel itself is short, yet still a square a finger can hit reliably. The status row is
///          exactly this tall.
const double _statusButtonSize = 48;

/// 中文：**状态行整条**——抽屉按钮、角度模式 chip、记忆徽标、结果形式指示、两格读数（进制 / 记法），
///       `Spacer` 之后是 `More...`。它们原来长在 `calculator_display.dart` 里（作为那个组件的私有
///       方法），这一次只是**搬家**，与上一轮 `status_chips.dart` 同一手法：每一行原样搬过来，只有
///       「私有方法」变成「同一个包的公开组件」，以及按钮边长那个度量跟着它唯一的使用者一起走
///       （度量与用它的东西分开就会漂，那条规矩写在 `calculator_display.dart` 里）。
///
///       **这条缝为什么在这里。** `calculator_display.dart` 是那块面板：它持有对外的契约（各类
///       行的字号、行高与伸缩规则，见它的类注释）并决定整块怎么排；而状态行是**一行自己成形的东西**
///       ——它读的九个值全部由调用方递进来，它自己不看控制器、不算结果、不做判断。上一轮把这一行里的
///       三格小标记拆成 `status_chips.dart`，这一轮拆的是**把那些标记拼成一行的那段装配**：组件只
///       回答「这一行怎么摆」，面板回答「这一行拿到什么、整块又怎么排」。
///
///       **一个判断留在面板那边**：结果形式指示那盏灯（`EXPR` / `DMS`）由调用方解析好再传进来
///       （传的是 `ResultPresentation.resolve(resultForm).indicator` 的结果），所以「这一份结果有
///       没有那一格」仍然只有 `ResultPresentation` 一处回答（rule 6），这里不重判，也不另算一次。
///
///       **这一行的排版契约**：两类格子都是宽松 `Flexible`——旁边的 `Spacer` 是 `Expanded`，两者按
///       flex 分余量，所以格子**永远放得下**：内容比份额长时自己按省略号收窄而不让整行溢出（不给
///       `Flexible` 时实测报 `A RenderFlex overflowed by 30 pixels on the right.`）；空串时整格不
///       存在。读数为什么落在这一行见 [baseReadout]，形式指示的判据见 `ResultForm.indicator`。
///
/// English: **the whole status row** — the drawer button, the angle-mode chip, the memory badge, the
///          result-form indicator and the two read-outs (base / notation), then `More...` after a
///          `Spacer`. It used to be private methods on `calculator_display.dart`; this is a **move**,
///          the same device as `status_chips.dart` last round: every line came across as it was, only
///          "private method" became "public widget in the same package", and the button's edge length
///          travelled with its only user (metrics separated from their user drift apart — that rule is
///          written down in `calculator_display.dart`).
///
///          **Why the seam is here.** `calculator_display.dart` is the panel: it holds the outward
///          contract (the font sizes, row heights and shrink rules in its class comment) and decides
///          how the whole block is laid out, while the status row is **a row that stands on its own** —
///          all nine values it reads arrive from the caller, and it touches no controller, computes no
///          result and makes no judgement. Last round split the three small marks inside this row out
///          into `status_chips.dart`; this round splits **the assembly that makes a row of them**: the
///          widget answers "how is this row laid out", the panel answers "what does this row get, and
///          how is the whole block laid out".
///
///          **One judgement stays on the panel's side**: the result-form lamp (`EXPR` / `DMS`) arrives
///          already resolved (the caller passes the result of
///          `ResultPresentation.resolve(resultForm).indicator`), so "does this result have that cell"
///          is still answered in exactly one place, `ResultPresentation` (rule 6) — nothing is judged
///          or computed a second time here.
///
///          **this row's layout contract**: both kinds of cell are a loose `Flexible` — the `Spacer`
///          beside them is an `Expanded`, the two share the slack by flex, so a cell **always fits**:
///          longer than its share it narrows itself with an ellipsis rather than overflowing the row
///          (measured: `A RenderFlex overflowed by 30 pixels on the right.` without it); empty means
///          absent. Why the read-outs land here is in [baseReadout], the form indicator's judgement in
///          `ResultForm.indicator`.
class DisplayStatusRow extends StatelessWidget {
  const DisplayStatusRow({
    required this.formIndicator,
    required this.angleMode,
    required this.hasMemory,
    required this.baseReadout,
    required this.notationReadout,
    required this.colors,
    required this.openNavigationTooltip,
    this.onOpenDrawer,
    this.onMore,
    super.key,
  });

  /// 中文：结果形式指示那盏灯上的字（`EXPR` / `DMS`…），空串表示这一份结果没有那一格。
  /// English: The word on the result-form lamp (`EXPR` / `DMS`, …); empty means this result has no
  ///          such cell.
  final String formIndicator;

  /// 中文：当前角度模式，状态行左侧的 chip 显示它（`DEG` / `RAD`）。
  /// English: The current angle mode, shown by the chip on the left of the status row
  ///          (`DEG` / `RAD`).
  final String angleMode;

  /// 中文：记忆寄存器里是否有值——为真时状态行显示 `M` 徽标，为假时该位置空着。
  /// English: Whether the memory register holds a value — a truthy value shows the `M` badge in the
  ///          status row, and with a falsy one the slot is empty.
  final bool hasMemory;

  /// 中文：**进制读数**（`HEX 64`），空串表示没有。它是四个进制胶囊那一次换算的产物，由控制器
  ///       决定，这里只负责摆。
  /// English: **the base read-out** (`HEX 64`); an empty string means there is none. It is what the
  ///          four base pills' conversion produces, decided by the controller — this widget only
  ///          lays it out.
  final String baseReadout;

  /// 中文：**数字记法读数**（`SCI 1.23456789E4`），`FSE` 那一颗键按出来的。契约与 [baseReadout]
  ///       相同：空串表示没有，非空就摆出来。
  /// English: **the number-notation read-out** (`SCI 1.23456789E4`), produced by the `FSE` key. Its
  ///          contract is [baseReadout]'s: an empty string means absent, a non-empty one is shown.
  final String notationReadout;

  /// 中文：显示区语义色，这一行里的每一个色值都取自它。
  /// English: Semantic display colours; every colour in this row comes from here.
  final CalcDisplayColors colors;

  /// 中文：抽屉按钮的 tooltip 文案，由调用方按当前界面语言取好再传进来——本组件不读文案表。
  /// English: The drawer button's tooltip, fetched by the caller in the active interface language —
  ///          this widget reads no copy table.
  final String openNavigationTooltip;

  /// 中文：抽屉按钮的回调；为空时按钮不渲染。
  /// English: Callback for the drawer button; the button is not rendered when null.
  final VoidCallback? onOpenDrawer;

  /// 中文：`More...` 按钮的回调；为空时按钮不渲染。
  /// English: Callback for the `More...` button; the button is not rendered when null.
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _statusButtonSize,
      child: Row(
        children: <Widget>[
          if (onOpenDrawer != null) ...<Widget>[
            _drawerButton(),
            const SizedBox(width: 4),
          ],
          StatusChips.angleMode(angleMode, colors),
          if (hasMemory) ...<Widget>[
            const SizedBox(width: 6),
            StatusChips.memory(colors),
          ],
          if (formIndicator.isNotEmpty) ...<Widget>[
            const SizedBox(width: 6),
            // 中文：宽松 `Flexible`——与进制读数那一格同一契约，实测见 `DisplayStatusRow` 的类注释。
            // English: a loose `Flexible` — the base read-out's contract; the measurement is in
            //          `DisplayStatusRow`'s class note.
            Flexible(child: StatusChips.resultForm(formIndicator, colors)),
          ],
          // 中文：两格读数（进制 / 记法）走同一段渲染——它们是同一类东西，形状、配色与省略规则不该
          //       分家；各自为空时各自不存在，布局与从前逐像素相同。
          // English: the two read-outs (base / notation) share one stretch of rendering — the same
          //          kind of thing, with a shape and elision rule that must not drift apart. Each is
          //          absent while empty, so the layout is pixel-for-pixel what it was.
          for (final readout in <String>[baseReadout, notationReadout])
            if (readout.trim().isNotEmpty) ...<Widget>[
              const SizedBox(width: 6),
              Flexible(child: StatusChips.baseReadout(readout, colors)),
            ],
          const Spacer(),
          if (onMore != null) _moreButton(),
        ],
      ),
    );
  }

  /// 中文：主屏的 ☰。tooltip 是本组件对外的固定契约（见 `calculator_display.dart` 的类注释），
  ///       图标色取次要状态色。
  ///
  ///       ⚠️ **这个正方形是 48dp，而那是可达性的下限，不是配色。** 它原来是 40dp——实测那颗按钮在
  ///       语义树里就是一个 `40 × 40` 的可点节点，`androidTapTargetGuideline` 判它不合格。`48` 同时
  ///       是状态行的高度，所以整行从 40 涨到 48；`CalculatorDisplay` 的固定部分因此从 74dp 到 82dp、
  ///       它的高度下限从 176dp 到 182dp（推导在那边的类注释里）。
  ///
  ///       `shrinkWrap` 仍然留着，但**理由变了**：它以前是「关掉 Material 把命中区撑到 48 的行为」，
  ///       而现在这一格本来就是 48——留着是为了不让 Material 在这之上再加内边距，尺寸由这一条常量
  ///       说了算，图标正好落在正中。
  /// English: The screen's ☰. Its tooltip is this widget's fixed outward contract (see the class
  ///          comment in `calculator_display.dart`) and its icon takes the secondary status colour.
  ///
  ///          ⚠️ **This square is 48dp, and that is the accessibility floor, not a colour choice.**
  ///          It used to be 40dp — measured, that button is a `40 × 40` tappable node in the
  ///          semantics tree and `androidTapTargetGuideline` fails it. `48` is also the status row's
  ///          height, so the row went 40 → 48; `CalculatorDisplay`'s chrome therefore goes 74 → 82dp
  ///          and its floor 176 → 182dp (the derivation is in that widget's class comment).
  ///
  ///          `shrinkWrap` stays, but **its reason changed**: it used to mean "turn off Material's
  ///          default padding of the hit area out to 48", and this square *is* 48 now — it stays so
  ///          Material adds no padding on top of it, this constant keeps deciding the size, and the
  ///          icon lands exactly in the middle.
  Widget _drawerButton() {
    return IconButton(
      onPressed: onOpenDrawer,
      tooltip: openNavigationTooltip,
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

  /// 中文：`More...` 按钮——本阶段接入现有能力（复制结果、保存笔记等）的入口。
  ///       它只把点击转给上层，自身不关心菜单内容。
  ///
  ///       ⚠️ **高度是 48dp，同样为可达性而来。** 原来 `minimumSize` 写的是 `Size(0, 34)`——实测这颗
  ///       按钮的语义节点是 `111.7 × 34.0`，比下限矮 14dp。`shrinkWrap` 留着是为了让横向命中区**不外扩**：
  ///       它右边就是面板内边距，宽度由文字与 `horizontal: 10` 决定，因此右边缘落在哪里是可预算的。
  ///       （纵向不再由 `shrinkWrap` 决定——那一头现在由 `minimumSize` 的 48 说了算。）
  /// English: The `More...` button — the entry point to what already exists (copying the result,
  ///          saving a note, ...). It only forwards the tap and does not care what the menu holds.
  ///
  ///          ⚠️ **Its height is 48dp, again for accessibility.** `minimumSize` used to read
  ///          `Size(0, 34)` — measured, this button's semantics node is `111.7 × 34.0`, 14dp under the
  ///          floor. `shrinkWrap` stays to keep the **horizontal** hit area from expanding: the panel's
  ///          padding is right beside it, its width comes from the text plus `horizontal: 10`, and so
  ///          where its right edge lands is predictable. (The vertical extent is no longer
  ///          `shrinkWrap`'s business — `minimumSize`'s 48 decides that end now.)
  Widget _moreButton() {
    return TextButton(
      onPressed: onMore,
      style: TextButton.styleFrom(
        foregroundColor: colors.indicatorFg,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        minimumSize: const Size(0, 48),
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
}
