import 'package:flutter/material.dart';

import '../../../../shared/presentation/calc_theme.dart';
import 'keypad_definition.dart';

/// 中文：当前生效的修饰态。`shift` 与 `hyp` 互斥，由上层持有并在按键后按需要复位。
/// English: The active modifier state. SHIFT and hyp are mutually exclusive; the screen above
///          owns the state and resets it when its own rules say so.
enum KeypadModifier { none, shift, hyp }

/// 中文：键盘区外边距。
/// English: Margin around the keypad panel.
const double _panelPadding = 6;

/// 中文：单元格内边距。主键条与标签条共用同一份横向内边距，两行的列才对得上。
/// English: Padding inside a cell. The main strip and the band share the same horizontal
///          padding so their columns line up.
const double _cellPadding = 1.5;

/// 中文：主键圆角半径。
/// English: Corner radius of a main key.
const double _keyRadius = 8;

/// 中文：标签行里小键的圆角半径。
/// English: Corner radius of a small key inside a label band.
const double _bandKeyRadius = 6;

/// 中文：主键行与标签横带的高度配比——HiPER 的矮行大约是高行的五分之二。
/// English: Height ratio between a main key row and a label band — HiPER's short bands are
///          roughly two fifths of a key row.
const int _mainFlex = 5;
const int _bandFlex = 2;

/// 中文：主键与标签行小键的字号。
/// English: Font size for main keys and for the small keys inside a band.
const double _keyFontSize = 17;
const double _bandFontSize = 11;

/// 中文：禁用键底色朝键盘底色混合的比例——越大越淡。
/// English: How far a disabled key's fill blends towards the panel background; larger is dimmer.
const double _disabledBlend = 0.55;

/// 中文：锁定时标签带小标签的内边距。
/// English: Padding inside a highlighted band chip.
const EdgeInsets _hintChipInsets =
    EdgeInsets.symmetric(horizontal: 3, vertical: 1);

/// 中文：两个修饰键在 `hiper_keypad.dart` 里的固定 id——它们代表键盘自身的状态切换，
///       不属于表达式动作，所以走 `onToggleShift`/`onToggleHyp` 而不是 `onKey`。
/// English: The two modifier keys' fixed ids in `hiper_keypad.dart`. They switch the keypad's
///          own state rather than acting on the expression, so they route to
///          `onToggleShift`/`onToggleHyp` instead of `onKey`.
const String _shiftKeyId = 'shift';
const String _hypKeyId = 'hyp';

const EdgeInsets _cellInsets = EdgeInsets.all(_cellPadding);
const BorderRadius _keyCorners = BorderRadius.all(Radius.circular(_keyRadius));
const BorderRadius _bandKeyCorners =
    BorderRadius.all(Radius.circular(_bandKeyRadius));

/// 中文：把 `KeypadDefinition` 渲染成 HiPER 式键盘：一列主键条，每条上方压着一条矮标签横带。
///       组件是**纯渲染**的——键位、分类、启用态、修饰态变体全部读自数据表与传入的
///       `CalcKeyColors`，这里不写任何色值，也不决定哪些键存在。
/// English: Renders a `KeypadDefinition` as HiPER's keypad: a column of main key strips, each
///          carrying a short label band above it. The widget is **render-only** — keys,
///          categories, enabled states and modifier variants all come from the data table and
///          from the `CalcKeyColors` handed in; no colour is written here and no key set is
///          decided here.
///
/// 高度 / Height:
/// 中文：全部行按 flex 分配传入的高度，所以本组件**需要一个有界高度**（例如放在 `Expanded`
///       或固定高度的槽里）并会填满它；任何屏幕高度下都不会溢出，键会跟着变矮。
/// English: Every row takes its share of the incoming height through flex, so the widget
///          **needs a bounded height** (an `Expanded` or fixed-height slot) and fills it. No
///          screen height can overflow; the keys get shorter instead.
///
/// 修饰态 / Modifier state:
/// 中文：`shift`/`hyp` 生效时，主键**执行**各自的变体（键面上仍是基准标签——变体是「按下去
///       会发生什么」，由上方标签横带的提示告诉用户，与 HiPER 的机制一致），修饰键自身改用
///       强调色显示自己正被按下，同时 `modifierActive` 让标签横带整体点亮：横带是唯一说明
///       「按下去会发生什么」的地方，只有它变色，用户才看得见 `sin` 现在会执行 `sin⁻¹`。
/// English: While `shift`/`hyp` is on, a main key **executes** its variant (its face keeps the
///          base label — the variant is what pressing it will do, which the band above spells
///          out, exactly HiPER's mechanism), the modifier key itself wears the accent colour to
///          show it is latched on, and `modifierActive` lights the band up. The band is the only
///          surface that says what pressing a key will do, so it has to be the one that changes
///          colour for the user to see that `sin` will now run `sin⁻¹`.
class CalculatorKeypad extends StatelessWidget {
  const CalculatorKeypad({
    super.key,
    required this.definition,
    required this.modifier,
    required this.colors,
    required this.background,
    required this.onKey,
    required this.onToggleShift,
    required this.onToggleHyp,
    this.modifierActive = false,
  });

  /// 中文：键位表；渲染层只读它。
  /// English: The key table; the rendering layer only reads it.
  final KeypadDefinition definition;

  /// 中文：当前生效的修饰态。
  /// English: The modifier state currently in effect.
  final KeypadModifier modifier;

  /// 中文：键位语义色，全部配色由此而来。
  /// English: Semantic key colours; every colour in this widget comes from here.
  final CalcKeyColors colors;

  /// 中文：键盘区底色。
  /// English: Keypad panel background.
  final Color background;

  /// 中文：按键动作 id 的回调（禁用键永不触发）。
  /// English: Callback for a key's action id (a disabled key never fires it).
  final ValueChanged<String> onKey;

  /// 中文：`SHIFT` 键的回调。
  /// English: Callback for the `SHIFT` key.
  final VoidCallback onToggleShift;

  /// 中文：`hyp` 键的回调。
  /// English: Callback for the `hyp` key.
  final VoidCallback onToggleHyp;

  /// 中文：是否有非 none 的修饰态被锁定——SHIFT 与 hyp 都会点亮标签横带（两者互斥，所以一个
  ///       布尔就够）。由上层持有；`hyp` 若在上层是独立的状态位，直接传它即可，不必与
  ///       `modifier` 保持同步。
  /// English: Whether a non-`none` modifier is latched. Both SHIFT and hyp light the label band
  ///          (they are mutually exclusive, so one bool covers both). The screen above owns it;
  ///          if `hyp` is a separate flag up there, pass that — it need not be kept in sync with
  ///          `modifier`, which only decides how a tapped key resolves.
  final bool modifierActive;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: background,
      child: Padding(
        padding: const EdgeInsets.all(_panelPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final KeypadRow row in definition.rows) ..._row(row),
          ],
        ),
      ),
    );
  }

  /// 中文：一行 = 可选的标签横带 + 主键条，横带在上（HiPER 的矮横带是它**下面**那行主键的
  ///       功能提示）。两段都参与高度分配，因此多少行都不会溢出。
  /// English: One row is an optional label band plus the main key strip, band first (HiPER's
  ///          short band labels the key row *below* it). Both segments take part in the height
  ///          split, so no row count can overflow.
  List<Widget> _row(KeypadRow row) => <Widget>[
        if (row.labels.any((KeypadLabel? label) => label != null))
          Expanded(flex: _bandFlex, child: _band(row)),
        Expanded(flex: _mainFlex, child: _mainStrip(row)),
      ];

  /// 中文：主键条——`Row` + `Expanded` 让本行的键平分宽度，于是 6 键行与 5 键行各有各的
  ///       列宽，这正是 HiPER 屏幕上两套列宽并存的原因。
  /// English: The main key strip — a `Row` of `Expanded` cells divides this row's width
  ///          equally, so a six-key row and a five-key row each keep their own column width.
  ///          That is how HiPER's two column widths coexist on one screen.
  Widget _mainStrip(KeypadRow row) => Row(
        children: <Widget>[
          for (final KeypadKey key in row.keys)
            Expanded(
              child:
                  _keyButton(key, corners: _keyCorners, fontSize: _keyFontSize),
            ),
        ],
      );

  /// 中文：标签横带。格子数取自主键条（而不是 labels 自身的长度），列就永远与下面的键对齐；
  ///       末尾没有标签的格子渲染成占位盒，宽度照占。
  /// English: The label band. Its cell count comes from the key strip rather than from
  ///          `labels` itself, which keeps every column aligned with the key under it; a slot
  ///          with no label becomes a placeholder that still holds the column's width.
  Widget _band(KeypadRow row) => Row(
        children: <Widget>[
          for (int i = 0; i < row.keys.length; i++)
            Expanded(
              child: _bandCell(i < row.labels.length ? row.labels[i] : null),
            ),
        ],
      );

  /// 中文：标签行的一格——`ShiftLabel` 是不可点的纯文字提示，`InlineKey` 是真按钮
  ///       （HiPER 只把四个进制胶囊与 `hyp` 放进标签行），空位是同宽的占位盒。
  /// English: One band cell — a `ShiftLabel` is a plain, non-tappable hint, an `InlineKey` is
  ///          a real button (HiPER only puts the four base pills and `hyp` in bands), and an
  ///          empty slot is a same-width placeholder.
  Widget _bandCell(KeypadLabel? label) => switch (label) {
        null => const SizedBox.expand(),
        ShiftLabel(:final String text) => _shiftHint(text),
        InlineKey(:final KeypadKey key) =>
          _keyButton(key, corners: _bandKeyCorners, fontSize: _bandFontSize),
      };

  /// 中文：SHIFT 提示。空闲时是纯文字、无边框、不挂任何手势（点它什么也不会发生）；修饰键
  ///       锁定后改画成强调色小标签，底色 `accentBg`、文字 `accentFg`——这一对由主题自己配套，
  ///       六套变体（三套主题 × 明暗）都保证可读；反过来把 `accentFg` 当文字画在键盘底色上，
  ///       浅色主题里是近白色压在浅底上，直接看不见。
  /// English: A SHIFT hint. Idle it is plain text, unframed and carrying no gesture (tapping it
  ///          does nothing); while a modifier is latched it becomes a small accent chip —
  ///          `accentBg` fill, `accentFg` text. The theme pairs those two by construction, so
  ///          all six variants (three themes × light/dark) stay readable; drawing `accentFg` as
  ///          text on the panel instead would be near-white on a light background in the light
  ///          themes, i.e. invisible.
  Widget _shiftHint(String text) => Padding(
        padding: _cellInsets,
        child: Center(
          child: modifierActive
              ? Container(
                  padding: _hintChipInsets,
                  decoration: BoxDecoration(
                    color: colors.accentBg,
                    borderRadius: _bandKeyCorners,
                  ),
                  child: _face(
                    text,
                    color: colors.accentFg,
                    fontSize: _bandFontSize,
                  ),
                )
              : _face(
                  text,
                  color: colors.shiftLabelFg,
                  fontSize: _bandFontSize,
                ),
        ),
      );

  /// 中文：一个实体键的完整渲染：底色 + 命中态 + 居中的键面文字。禁用键**不挂** `onTap`
  ///       （不是只做得暗淡），修饰键则走各自的切换回调。
  /// English: One real key, end to end: its fill, its hit state and its centred face text.
  ///          A disabled key gets **no** `onTap` at all (it is not merely drawn dim), and a
  ///          modifier key routes to its own toggle callback.
  Widget _keyButton(
    KeypadKey key, {
    required BorderRadius corners,
    required double fontSize,
  }) {
    final KeyVariant variant = _variantFor(key);
    final bool enabled = _isEnabled(key);
    final ({Color bg, Color fg}) paint = _paint(key);
    // 中文：四个进制胶囊是半圆端的胶囊形，其余键是圆角矩形。
    // English: The four base pills are capsules with half-round ends; every other key is a
    //          rounded rectangle.
    final bool capsule = key.category == KeyCategory.pill;
    final Decoration decoration = capsule
        ? ShapeDecoration(color: paint.bg, shape: const StadiumBorder())
        : BoxDecoration(color: paint.bg, borderRadius: corners);
    return Padding(
      padding: _cellInsets,
      child: Container(
        decoration: decoration,
        // 中文：`Material` 放在底色**之内**，命中涟漪才画在键面之上而不是被底色盖住。
        // English: The `Material` sits *inside* the fill so the ink ripple paints above the
        //          key's colour instead of being hidden behind it.
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: enabled ? () => _activate(key, variant) : null,
            borderRadius: capsule ? null : corners,
            customBorder: capsule ? const StadiumBorder() : null,
            child: Center(
              // 中文：键面永远画**基准**标签——修饰态解析出的是「按下去会发生什么」（变体 id），
              //       而那个功能已经印在键上方的标签横带里。若把键面也换成变体标签，`sin` 在
              //       SHIFT/hyp 下就没有任何可点的文字了（本组件的测试与 Task 4 的主屏测试都
              //       断言那时仍能点到 `sin`，并按变体 id 上报）。
              // English: The face always draws the **base** label. Modifier resolution yields
              //          what pressing will do (the variant's id), and that function is already
              //          printed in the band above the key. Swapping the face for the variant
              //          label would leave `sin` with no tappable text under SHIFT/hyp, which
              //          this widget's tests — and Task 4's screen tests — rely on.
              child: _face(key.base.label, color: paint.fg, fontSize: fontSize),
            ),
          ),
        ),
      ),
    );
  }

  /// 中文：键面文字。`FittedBox` 只缩不放，任何宽度与字号下都不会溢出，长标签
  ///       （`HISTORY`、`=,＜＞`）因此不会撑破格子，窄屏也无需另写一套布局。
  /// English: Face text. `FittedBox` only scales down, so it never overflows at any width or
  ///          font size: long labels (`HISTORY`, `=,＜＞`) cannot burst their cell and a narrow
  ///          screen needs no second layout.
  Widget _face(
    String text, {
    required Color color,
    required double fontSize,
  }) =>
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.clip,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            height: 1.1,
          ),
        ),
      );

  /// 中文：修饰态解析——`hyp` 变体存在且在 hyp 态就用它，否则 shift 态用 `shift` 变体，
  ///       都没有就退回基准变体。执行的是变体的 id，键面文字仍取基准标签。
  /// English: Modifier resolution — the `hyp` variant wins while hyp is on, otherwise the
  ///          `shift` variant is used while SHIFT is on, and a key without either falls back to
  ///          its base variant. The variant supplies the dispatched id; the face keeps the base
  ///          label (see the class comment).
  KeyVariant _variantFor(KeypadKey key) {
    if (modifier == KeypadModifier.hyp && key.hyp != null) {
      return key.hyp!;
    }
    if (modifier == KeypadModifier.shift && key.shift != null) {
      return key.shift!;
    }
    return key.base;
  }

  /// 中文：键是否可用——变体自身要启用，且分类不能是 `disabled`。
  /// English: Whether the key is usable — its variant must be enabled and its category must
  ///          not be `disabled`.
  bool _isEnabled(KeypadKey key) =>
      _variantFor(key).enabled && key.category != KeyCategory.disabled;

  /// 中文：修饰键自身是否正被按下——`shift` 键在 SHIFT 态、`hyp` 键在 hyp 态。
  /// English: Whether a modifier key is the one latched on — the `shift` key while SHIFT is
  ///          active, the `hyp` key while hyp is active.
  bool _isActiveModifier(KeypadKey key) {
    if (key.category != KeyCategory.modifier) return false;
    return switch (key.base.id) {
      _shiftKeyId => modifier == KeypadModifier.shift,
      _hypKeyId => modifier == KeypadModifier.hyp,
      _ => false,
    };
  }

  /// 中文：键面配色——禁用键降饱和（把中性键底朝键盘底色混合）并改用提示色文字；按下的修饰键
  ///       改用强调色；其余按分类取 `CalcKeyColors` 的语义色对。
  /// English: Face colours — a disabled key is desaturated (its neutral fill blends towards the
  ///          panel background) and takes the hint colour for text; a latched modifier key
  ///          switches to the accent pair; everything else takes its category's semantic pair
  ///          from `CalcKeyColors`.
  ({Color bg, Color fg}) _paint(KeypadKey key) {
    if (!_isEnabled(key)) {
      return (
        bg: Color.lerp(colors.functionBg, background, _disabledBlend)!,
        fg: colors.shiftLabelFg,
      );
    }
    if (_isActiveModifier(key)) {
      return (bg: colors.accentBg, fg: colors.accentFg);
    }
    return switch (key.category) {
      KeyCategory.digit => (bg: colors.digitBg, fg: colors.digitFg),
      KeyCategory.operator => (bg: colors.operatorBg, fg: colors.operatorFg),
      KeyCategory.function => (bg: colors.functionBg, fg: colors.functionFg),
      KeyCategory.variable => (bg: colors.variableBg, fg: colors.variableFg),
      KeyCategory.modifier => (bg: colors.modifierBg, fg: colors.modifierFg),
      KeyCategory.destructive => (
          bg: colors.destructiveBg,
          fg: colors.destructiveFg
        ),
      KeyCategory.accent => (bg: colors.accentBg, fg: colors.accentFg),
      KeyCategory.pill => (bg: colors.pillBg, fg: colors.pillFg),
      // 中文：`disabled` 分类永远走不到这一支（上面的 `_isEnabled` 已经拦下），
      //       这一行只是让 switch 穷尽。
      // English: The `disabled` category never reaches this arm (`_isEnabled` above stops it);
      //          the line exists only so the switch stays exhaustive.
      KeyCategory.disabled => (bg: colors.functionBg, fg: colors.shiftLabelFg),
    };
  }

  /// 中文：按下分派——`shift`/`hyp` 两个 id 属于修饰键自身，走切换回调；其余键上报当前修饰态
  ///       解析出的变体 id，让它与键面（基准标签）可以不同。
  /// English: Tap dispatch — the `shift` and `hyp` ids belong to the modifier keys themselves,
  ///          so they route to the toggle callbacks; every other key reports the current
  ///          modifier's variant id, which may differ from the label on its face.
  void _activate(KeypadKey key, KeyVariant variant) {
    if (key.base.id == _shiftKeyId) {
      onToggleShift();
      return;
    }
    if (key.base.id == _hypKeyId) {
      onToggleHyp();
      return;
    }
    onKey(variant.id);
  }
}
