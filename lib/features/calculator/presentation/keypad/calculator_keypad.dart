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

/// 中文：**图形键面的高度，以主键字号为单位。** 数值是量出来的，不是挑出来的——两份来源把
///       它夹在 1.30 与 1.36 em 之间，这里取小的那一端，图形因此永远不会顶到键框：
///       1. 厂商那张 1440×3200 真机图（`~/Downloads/04_媒体/Screenshot_2026-05-12-13-11-45-205_cz.hipercalc.p.jpg`）
///          上，同一行第 3 格的字形高 **86 px**、第 1 格 `DRG` 的大写高 **45 px**、键面高 124 px
///          ——图形是同一行大写文字的 86/45 = **1.91 倍**。本应用主键字号 17，Roboto 的大写高
///          0.711 em = 12.1 px，1.91 × 12.1 = 23.1 px = **1.36 em**。
///       2. 厂商官网当前主屏截图（`https://hiperlabs.eu/screenshots.html` → `assets/img/01 calculator.png`）
///          上同一格：字形高 **22 px**、`DRG` 大写高 **12 px** —— 1.83 倍，换成 em 是 **1.30 em**。
///       两份差的只是两张图的缩放（0.694 与 0.647 的「图形高 ÷ 键面高」同理），取 1.30 是保守的那个。
/// English: **The figure face's height, in units of the main key font size.** The number is measured,
///          not picked — two sources bracket it between 1.30 and 1.36 em, and the smaller end is
///          taken so the figure can never touch the key's rim:
///          1. On the vendor's 1440×3200 device screenshot (path above), this cell's glyph is
///             **86 px** tall while `DRG`'s capitals in the same row are **45 px** and the key face
///             is 124 px — the figure is 86/45 = **1.91×** the row's capital height. This app draws
///             main keys at 17 px, Roboto's capitals are 0.711 em = 12.1 px, so 1.91 × 12.1 =
///             23.1 px = **1.36 em**.
///          2. On the vendor's current main-screen screenshot (URL above) the same cell measures
///             **22 px** against `DRG`'s **12 px** capitals — 1.83×, i.e. **1.30 em**.
///          The two differ only by the two pictures' scale (the same is true of "figure height over
///          key-face height", 0.694 against 0.647), and 1.30 is the conservative one.
const double _iconFaceFontFactor = 1.3;

/// 中文：图形键面的笔宽（图形自身的坐标里，见 `_KeyFaceIconPainter`）——厂商那张图上量到
///       5–6 px，取中。**它随图形一起缩放**，所以任何键高下粗细都与厂商成比例。
/// English: The figure face's stroke width, in the figure's own coordinates (see
///          `_KeyFaceIconPainter`) — measured 5–6 px on the vendor's screenshot, taken at the middle.
///          **It scales with the figure**, so the weight stays proportional at any key height.
const double _iconFaceStroke = 5.5;

/// 中文：禁用键底色朝键盘底色混合的比例——越大越淡。
/// English: How far a disabled key's fill blends towards the panel background; larger is dimmer.
const double _disabledBlend = 0.55;

/// 中文：锁定时标签带小标签的内边距。
/// English: Padding inside a highlighted band chip.
const EdgeInsets _hintChipInsets =
    EdgeInsets.symmetric(horizontal: 3, vertical: 1);

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
///
/// 接入契约 / Wiring contract（Task 4 需要知道的三件事）:
/// 中文：1) 本组件需要**有界高度**并会填满它（见上）；2) `modifierActive` 可以省略，省略时按
///       `modifier != none` 推导——忘了传也不会丢掉「SHIFT 已锁定」的信号；3) `modifier` 只决定
///       按键如何解析，组件**不认识任何具体 id**——包括 `shift`/`hyp` 两个修饰键：它们像其它键
///       一样把自己的 id 交给 `onKey`，由上层切换修饰态。因此键位表里改 id 不必回到本文件。
///       「哪个修饰键正被按下」这个问题不靠 id 回答，靠 `modifier.name` 与键的 id 相等——键位表里
///       两个修饰键的 id 与 `KeypadModifier` 的枚举名一致，这一点由
///       `test/features/keypad_definition_test.dart` 钉住。
/// English: 1) it needs a **bounded height** and fills it (above); 2) `modifierActive` may be
///          omitted — it then derives from `modifier != none`, so the "SHIFT is latched" signal
///          cannot be lost by forgetting an argument; 3) `modifier` decides only how a tapped key
///          resolves, and the widget **knows no concrete id at all** — the `shift`/`hyp` modifier
///          keys included: they hand their id to `onKey` like every other key, and the screen above
///          flips the modifier. Changing an id in the key table therefore never reaches this file.
///          "Which modifier key is latched" is not answered by an id constant but by
///          `modifier.name` matching the key's id — the two modifier ids in the table equal the
///          `KeypadModifier` enum names, which
///          `test/features/keypad_definition_test.dart` pins.
class CalculatorKeypad extends StatelessWidget {
  const CalculatorKeypad({
    super.key,
    required this.definition,
    required this.modifier,
    required this.colors,
    required this.background,
    required this.onKey,
    this.modifierActive,
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

  /// 中文：按键动作 id 的回调（禁用键永不触发）。修饰键也走这条通路——它们的 id 就是
  ///       `shift`/`hyp`，由上层决定那是切换修饰态。
  /// English: Callback for a key's action id (a disabled key never fires it). The modifier keys
  ///          travel this path too — their ids are `shift`/`hyp`, and the screen above decides that
  ///          those mean "flip the modifier".
  final ValueChanged<String> onKey;

  /// 中文：是否有非 none 的修饰态被锁定——SHIFT 与 hyp 都会点亮标签横带（两者互斥，所以一个
  ///       布尔就够）。**可以省略**：省略时按 `modifier != KeypadModifier.none` 推导，所以漏传
  ///       不会漏掉提示，安全行为就是默认行为。显式传入则优先于推导，用于 `hyp` 在上层是独立
  ///       状态位的形状（那时 `modifier` 可能仍是 none）。
  /// English: Whether a non-`none` modifier is latched. Both SHIFT and hyp light the label band
  ///          (they are mutually exclusive, so one bool covers both). **It may be omitted**:
  ///          omitting it derives `modifier != KeypadModifier.none`, so forgetting it cannot lose
  ///          the signal — the safe behaviour is the default one. An explicit value wins over
  ///          the derivation, which is what a screen that tracks `hyp` as its own flag needs
  ///          (there `modifier` may still read `none`).
  final bool? modifierActive;

  /// 中文：标签横带是否点亮——见 `modifierActive` 的推导规则。
  /// English: Whether the label band is lit — see `modifierActive` for the derivation.
  bool get _bandLit => modifierActive ?? (modifier != KeypadModifier.none);

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
  ///       （HiPER 只把四个进制胶囊放进标签行；本应用还多一颗 `hyp`，是立项时写下的刻意偏离，
  ///       见 `keypad_definition.dart` 的 `InlineKey`），空位是同宽的占位盒。
  /// English: One band cell — a `ShiftLabel` is a plain, non-tappable hint, an `InlineKey` is
  ///          a real button (HiPER only puts the four base pills in bands; this app adds `hyp`
  ///          besides, a deliberate deviation recorded on `InlineKey` in `keypad_definition.dart`),
  ///          and an empty slot is a same-width placeholder.
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
          child: _bandLit
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
  ///       （不是只做得暗淡）；其余一律把当前修饰态解析出的变体 id 交给 `onKey`——修饰键自己
  ///       也不例外（上层拿 `shift`/`hyp` 去切换修饰态）。
  /// English: One real key, end to end: its fill, its hit state and its centred face text.
  ///          A disabled key gets **no** `onTap` at all (it is not merely drawn dim); every other
  ///          key hands the variant id the modifier resolved to up through `onKey` — the modifier
  ///          keys included (the screen above turns `shift`/`hyp` into a modifier flip).
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
            onTap: enabled ? () => onKey(variant.id) : null,
            borderRadius: capsule ? null : corners,
            customBorder: capsule ? const StadiumBorder() : null,
            child: Center(
              // 中文：键面永远画**基准**标签（或基准变体点名的图形）——修饰态解析出的是
              //       「按下去会发生什么」（变体 id），而那个功能已经印在键上方的标签横带里。
              //       若把键面也换成变体标签，`sin` 在 SHIFT/hyp 下就没有任何可点的文字了
              //       （本组件的测试与 Task 4 的主屏测试都断言那时仍能点到 `sin`，并按变体 id
              //       上报）。**图形同理**：矩阵键在 SHIFT 下键面仍画那张图，变体的名字 `MTRX`
              //       只出现在横带里——这正是 HiPER 的机制。
              // English: The face always draws the **base** label (or the figure the base variant
              //          names). Modifier resolution yields what pressing will do (the variant's
              //          id), and that function is already printed in the band above the key.
              //          Swapping the face for the variant label would leave `sin` with no tappable
              //          text under SHIFT/hyp, which this widget's tests — and Task 4's screen
              //          tests — rely on. **A figure behaves the same way**: the matrix key keeps
              //          its figure under SHIFT, and the variant's name `MTRX` appears only in the
              //          band, which is exactly HiPER's mechanism.
              child: _variantFace(key.base, color: paint.fg, fontSize: fontSize),
            ),
          ),
        ),
      ),
    );
  }

  /// 中文：一个变体的**键面**——两条路：没有图形走 `_face` 画 `label` 那几个字；`icon` 有值时
  ///       改画那个图形，由 `KeyFaceIconView` 负责。**名字（`label`）不会因此消失**：横带里的
  ///       提示、逐格快照与词表条目都还叫它这个名字，只是键面画的不是字——HiPER 上矩阵键就是
  ///       这样（名字 `MTRX` 在它上方那一格，键面是一张图）。
  /// English: One variant's **face** — two paths: with no figure it goes through `_face` and draws
  ///          the characters of `label`; when `icon` is set it draws that figure instead, which is
  ///          `KeyFaceIconView`'s job. **The name (`label`) does not disappear with it**: the band
  ///          hint, the per-cell snapshot and the vocabulary entries still call the key by it; only
  ///          the drawing changes — which is exactly how HiPER's matrix key works (the name `MTRX`
  ///          sits in the cell above, the face carries a figure).
  Widget _variantFace(
    KeyVariant variant, {
    required Color color,
    required double fontSize,
  }) {
    final KeyFaceIcon? icon = variant.icon;
    if (icon == null) {
      return _face(variant.label, color: color, fontSize: fontSize);
    }
    // 中文：⚠️ **图形键面要自己带一个语义标签。**
    //       文字键面不用管：`InkWell` 会**从子节点的文字推出**标签，所以 `SHIFT`/`⌫` 那些
    //       读屏一直读得出来；而图形键面**没有文字可推**，于是那一颗在语义树里
    //       **是个没有名字的可点节点**（实测：`labeledTapTargetGuideline` 只在这一颗上失败，
    //       坐标 `Rect.fromLTRB(270.2, 283.9, 398.5, 309.7)`——`[matrix]` 那一格）。
    //
    //       名字取 `variant.label`——**它本来就是这颗键的名字**（键位表里那一栏、
    //       横带里的提示、逐格快照用的都是它），只是**键面画的不是字**而已（见
    //       [_variantFace] 的文档注释：名字不会因为画图标而消失）。
    //       所以这不是"给它取个名字"，是**把已经有的名字接到语义树上**。
    //
    //       仍然说清代价：`KeyFaceIconView` 是图形键**共用**的那一个组件，
    //       这一层对所有图形键生效——而它们的 `label` 都是现成的，**没有一颗需要新取名字**。
    // English: ⚠️ **a figure-faced key has to carry its own semantic label.**
    //          A text face needs nothing: `InkWell` **derives** a label from the descendant text, which
    //          is why `SHIFT`/`⌫` have always been readable. A figure face **has no text to derive
    //          from**, so that one key is **an unnamed tappable node** in the semantics tree (measured:
    //          `labeledTapTargetGuideline` fails on exactly that node, `Rect.fromLTRB(270.2, 283.9,
    //          398.5, 309.7)` — the `[matrix]` cell).
    //
    //          The name comes from `variant.label`, which **is already that key's name** (the same one the
    //          keypad table, the band hint and the per-cell snapshot use) — only the face draws a figure
    //          instead of characters (see [_variantFace]'s doc: the name does not disappear when an icon is
    //          drawn). So this is not "giving it a name" but **wiring the name that already exists into the
    //          semantics tree**.
    //
    //          The cost, stated: `KeyFaceIconView` is **shared** by the figure keys and this layer applies to
    //          all of them — and every one already has a `label`, so **none needs a new name.**
    return Semantics(
      label: variant.label,
      child: KeyFaceIconView(
        icon: icon,
        color: color,
        height: fontSize * _iconFaceFontFactor,
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

  /// 中文：修饰键自身是否正被按下——`shift` 键在 SHIFT 态、`hyp` 键在 hyp 态。判定不引任何 id 常量：
  ///       正被按下的修饰键，其 id 恰好等于当前 `KeypadModifier` 的枚举名（键位表里两个修饰键的 id
  ///       就是 `shift`/`hyp`，`keypad_definition_test.dart` 钉住这一点）。于是本组件不必知道
  ///       任何具体 id，改表也不会漏改这里。
  /// English: Whether a modifier key is the one latched on — the `shift` key while SHIFT is active,
  ///          the `hyp` key while hyp is active. No id constant is involved: the latched modifier key's
  ///          id equals the current `KeypadModifier`'s enum name (the table's two modifier ids are
  ///          `shift`/`hyp`, which `keypad_definition_test.dart` pins). So this widget knows no
  ///          concrete id and editing the table cannot leave a stale one behind here.
  bool _isActiveModifier(KeypadKey key) =>
      modifier != KeypadModifier.none &&
      key.category == KeyCategory.modifier &&
      key.base.id == modifier.name;

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
}

// 中文：**括号从字形外缘伸进来多宽、四个方格多大、摆在哪。** 全部是厂商那张 1440×3200 真机图上
//       第 2 行第 3 格字形的实测读数，换算到图形自己的坐标里（外框 118×86，原点在左上角）：
//       左括号竖笔 x 543..547 → 0..5，上下臂伸到 x 559 → 17；四个方格外框 21×30（量到
//       575..595 与 1340..1369），左列 x 32、右列 x 64、上行 y 8、下行 y 48；行距 10、列距 11。
//       括号竖向占满外框（y 1332..1417 → 0..86），方格上下各内缩 8——这一格与「四个方块挨在一起」
//       的画法不同，也与单个 `▦`/`⊞` 不同。
// English: **How far the brackets reach in, how big the four squares are, and where they sit.** All
//          of it is the measured geometry of this cell's glyph on the vendor's 1440×3200 device
//          screenshot, converted into the figure's own coordinates (a 118×86 box, origin top-left):
//          the left bracket's stem x 543..547 → 0..5 with its arms reaching x 559 → 17; each square
//          is 21×30 (measured 575..595 and 1340..1369), left column x 32, right column x 64, top row
//          y 8, bottom row y 48, with 10 between the rows and 11 between the columns. The brackets
//          span the whole box vertically (y 1332..1417 → 0..86) while the squares are inset 8 from
//          top and bottom — which is not the same drawing as four squares touching, and not the same
//          as a single `▦` or `⊞`.
const double _matrixBracketReach = 17;
const double _matrixSquareWidth = 21;
const double _matrixSquareHeight = 30;
const double _matrixSquareLeftX = 32;
const double _matrixSquareRightX = 64;
const double _matrixSquareTopY = 8;
const double _matrixSquareBottomY = 48;

/// 中文：键面上的**图形**（`KeyFaceIcon` 的一个取值）。**公开是有意的**：键面从文字变成图形之后，
///       测试再也没有 `find.text('MTRX')` 可抓——那颗键的可点那一层要从本组件的实例往上找
///       （两个面板测试与那一格的键位测试就是这么找它的），与 `find.text` 找文字键面是同一件事。
///
///       尺寸：高度由调用方给（主键面给 `fontSize * _iconFaceFontFactor`，那一段解释了为什么是
///       1.3），宽度按 `KeyFaceIcon.aspectRatio` 推出，图形因此永远不变形；外面照文字那条路一样
///       套一个只缩不放的 `FittedBox`，窄屏与矮行都不会溢出。
///
///       颜色：由调用方给键面自己的前景色（`_paint` 的 `fg`），所以三套主题 × 明暗六种变体下
///       **自动跟着走**——厂商那张图上这个图形的颜色 (46,46,46) 与同一行文字的键面前景色同值，
///       本来就是一回事。
/// English: A **figure** on a key face (one value of `KeyFaceIcon`). **Being public is deliberate**:
///          once a face stops being text there is no `find.text('MTRX')` left to grab it by — the
///          key's tappable layer is found upwards from an instance of this widget (which is how the
///          two sheet tests and that cell's keypad test find it), the same thing `find.text` does for
///          a text face.
///
///          Size: the height comes from the caller (a main key passes
///          `fontSize * _iconFaceFontFactor`, where that number is justified), and the width is
///          derived from `KeyFaceIcon.aspectRatio`, so the figure can never be distorted. Like the
///          text path it sits inside a `FittedBox` that only scales down, so no narrow screen and no
///          short row can overflow.
///
///          Colour: the caller passes the face's own foreground colour (`fg` from `_paint`), so all
///          six variants (three themes × light/dark) **follow automatically** — on the vendor's
///          screenshot this figure's colour (46,46,46) equals the face foreground of the text beside
///          it, which is the same thing.
class KeyFaceIconView extends StatelessWidget {
  const KeyFaceIconView({
    super.key,
    required this.icon,
    required this.color,
    required this.height,
  });

  /// 中文：画哪一个图形。
  /// English: Which figure to draw.
  final KeyFaceIcon icon;

  /// 中文：图形的颜色（键面的前景色）。
  /// English: The figure's colour (the face's foreground).
  final Color color;

  /// 中文：图形的高度；宽度由 `icon.aspectRatio` 推出。
  /// English: The figure's height; its width comes from `icon.aspectRatio`.
  final double height;

  @override
  Widget build(BuildContext context) => FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: height * icon.aspectRatio,
          height: height,
          child: CustomPaint(
            painter: _KeyFaceIconPainter(icon: icon, color: color),
          ),
        ),
      );
}

/// 中文：把 `KeyFaceIcon` 的一个取值画出来。画在**图形自己的坐标**里（`0..icon.width`、
///       `0..icon.height`），进入之前先缩放到组件给的尺寸——于是所有几何常量都是量到的 px 数，
///       换多大画多大，粗细也跟着走。
/// English: Draws one `KeyFaceIcon` value. It draws in the **figure's own coordinates**
///          (`0..icon.width`, `0..icon.height`) after scaling to the widget's size, so every geometry
///          constant above is a measured pixel count and the stroke keeps its weight at any size.
class _KeyFaceIconPainter extends CustomPainter {
  const _KeyFaceIconPainter({required this.icon, required this.color});

  final KeyFaceIcon icon;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // 中文：只按高缩放（等比）。宽由 `KeyFaceIconView` 按长宽比定出来，所以这里两边同倍；
    //       `translate` 只是让万一宽了一点的情况仍居中，图形不会偏。
    // English: Scale by height only (uniformly). `KeyFaceIconView` derives the width from the
    //          aspect ratio, so both factors agree; the `translate` only keeps a slightly wider box
    //          centred instead of off to one side.
    final double scale = size.height / icon.height;
    canvas.save();
    canvas.translate((size.width - icon.width * scale) / 2, 0);
    canvas.scale(scale);
    switch (icon) {
      case KeyFaceIcon.matrix:
        _paintMatrix(canvas);
    }
    canvas.restore();
  }

  /// 中文：矩阵键的键面——两个方括号夹着 2×2 的四个空心方格（几何常量见本文件上面那一段）。
  ///       括号是**一条折线**（上臂 → 竖笔 → 下臂，再镜像一条），笔端是平口，所以上下臂的末端
  ///       正好落在 `_matrixBracketReach` 上、竖笔的左边正好落在 0；方格用描边的矩形，描边居中，
  ///       所以内部矩形先按半个笔宽内缩，画出来的**外框**才是量到的 21×30。
  /// English: The matrix key's face — four hollow squares in a 2×2 grid between two brackets (the
  ///          geometry constants are the block above). Each bracket is **one polyline** (upper arm →
  ///          stem → lower arm, then mirrored), and with butt caps the arms end exactly at
  ///          `_matrixBracketReach` while the stem's outer edge lands on 0. The squares are stroked
  ///          rectangles; a stroke is centred on its rect, so the rect is inset by half the stroke
  ///          first — only then is the **outer** box the measured 21×30.
  void _paintMatrix(Canvas canvas) {
    const double half = _iconFaceStroke / 2;
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _iconFaceStroke
      ..strokeCap = StrokeCap.butt
      ..strokeJoin = StrokeJoin.miter;

    final Path brackets = Path();
    for (final bool left in const <bool>[true, false]) {
      final double stem = left ? half : icon.width - half;
      final double arm =
          left ? _matrixBracketReach : icon.width - _matrixBracketReach;
      brackets
        ..moveTo(arm, half)
        ..lineTo(stem, half)
        ..lineTo(stem, icon.height - half)
        ..lineTo(arm, icon.height - half);
    }
    canvas.drawPath(brackets, stroke);

    for (final double x in const <double>[
      _matrixSquareLeftX,
      _matrixSquareRightX,
    ]) {
      for (final double y in const <double>[
        _matrixSquareTopY,
        _matrixSquareBottomY,
      ]) {
        canvas.drawRect(
          Rect.fromLTWH(
            x + half,
            y + half,
            _matrixSquareWidth - _iconFaceStroke,
            _matrixSquareHeight - _iconFaceStroke,
          ),
          stroke,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_KeyFaceIconPainter oldDelegate) =>
      oldDelegate.icon != icon || oldDelegate.color != color;
}
