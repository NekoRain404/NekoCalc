part of 'calculator_page.dart';

/// 中文：**`►DRG` 的第二功能：HiPER 的 `TO_DRG`「换算角度单位」。**
///
///       自成一个 part 文件只为行数（与 `calculator_page_matrix_sheet.dart` 同一个理由与同一种形状）：
///       这一块是自成一体的（`DRG` 那颗键的 SHIFT 与它打开的面板）。
///
///       **一、厂商那一格说的是什么，本面板就做什么。** 手册第 678 行：**"►DRG key in compact layout
///       opens the menu to choose source and target angular units and converts the current display
///       number."** 于是这里有两行：**源单位**（选）与**目标单位**（点一下就换算）。面板的标题用
///       厂商自己的命令名 `command.name.TO_DRG` = **"Convert Angular Units"**，逐字照抄——与矩阵
///       菜单用 `MATRIX_MENU` 那一句同一个做法（不含汉字，所以不走文案表）。
///
///       **二、要换算的那个数是「当前显示的数」**（`_result` 的十进制形态），判据与四个进制胶囊
///       逐条相同，**没有可用的数时那两行是灰的**，面板里就写着为什么。理由与门槛在
///       `_CalculatorAngleConvert` 的文件头上——判断只有那一处，这里只是它的第二个读者。
///
///       **三、源单位不替用户猜。** 手里那个数是什么单位的，只有用户知道：`1.5708` 既可能是弧度也
///       可能是度，猜错就是一次静默错值。所以**没选源单位之前目标那两行是灰的**，面板上写着
///       「先选源单位」。这与 `►DRG` 的语义一致——HiPER 那一格也是先问 source、再问 target。
///
///       **四、插出去的永远是「源与目标都写出来」的完整一条**：`<值> <源单位> to <目标单位>`。
///       **只写目标单位是不行的**，而且这件事是量出来的：只写目标时那一步的源单位会变成**当前角度
///       模式**——`90 to rad` 在 DEG 下给 `1.570796327 rad`、在 RAD 下给 `90 rad`（同一台宿主
///       `qalc` 5.12.0）。两侧都写出来时答案与角度模式无关（`90 deg to rad` 在 deg/rad/gra 三档
///       下同答）。整张表在 `app_unit_catalog.dart` 的 `kAngleUnits` 上。
///
///       **五、`grad` 那一行灰的是什么。** 百分度最容易被想起来的拼法是 `grad`（HiPER 展开布局里
///       那三颗键就叫 `►DEG`/`►RAD`/`►GRAD`），而引擎里的 `grad` **不是一个角**：`1 grad` =
///       `1357.168026 s·rad`，用作换算来源时**值是对的、单位是坏的**（`90 grad to deg` = `81 d·°`）。
///       干净的拼法是 `gon`，它本来就在应用的单位表里（实测 `1 gon to deg` = `0.9°`）。**灰键是
///       诚实的**（与矩阵菜单那三行、结果格式菜单里 `Polar coordinates` 那一项同一个做法）：
///       按不下去，而且同一行里就写着实测的那些数。
///
///       **六、到期日。** 第五条的凭据钉在 `test/features/calculator_angle_convert_menu_test.dart`
///       里：哪一天引擎把 `grad` 答对了（或者应用自己实现了百分度的另一个拼法），那一条会变红，
///       那时这一行该点亮，而不是让一条过期的拒绝悄悄留着。
/// English: **`►DRG`'s second function: HiPER's `TO_DRG`, "Convert Angular Units".**
///
///          A part file of its own for line count alone (the same reason and the same shape as
///          `calculator_page_matrix_sheet.dart`): this block is self-contained (the `DRG` key's SHIFT
///          and the sheet it opens).
///
///          **1. What the vendor's cell says is what this sheet does.** Manual line 678: **"►DRG key
///          in compact layout opens the menu to choose source and target angular units and converts
///          the current display number."** So there are two rows: the **source unit** (a choice) and
///          the **target unit** (one press converts). The title is the vendor's own command name,
///          `command.name.TO_DRG` = **"Convert Angular Units"**, copied verbatim — the same device the
///          matrix sheet uses with `MATRIX_MENU` (it holds no CJK, so it does not go through the
///          string table).
///
///          **2. The number it converts is "the number currently displayed"** (`_result`'s decimal
///          form) behind the base pills' own two tests, and **with no usable number those two rows are
///          grey**, with the reason written in the sheet. The tests and the reasons are on
///          `_CalculatorAngleConvert`'s file head — the judgement lives there and only there; this is
///          its second reader.
///
///          **3. The source unit is not guessed for the user.** Only the user knows what unit that
///          number is in: `1.5708` could be radians or degrees, and guessing wrong is one silent wrong
///          value. So **the two target rows stay grey until a source is picked**, and the sheet says
///          "pick the source unit first". That matches `►DRG`'s own semantics — HiPER's cell asks for
///          a source and then a target too.
///
///          **4. What goes in is always one complete conversion with both sides written out**:
///          `<value> <source unit> to <target unit>`. **Naming only the target does not work**, and
///          that is measured: with only a target, that conversion's source unit becomes the **current
///          angle mode** — `90 to rad` gives `1.570796327 rad` under DEG and `90 rad` under RAD (same
///          host, `qalc` 5.12.0). With both sides written out the answer does not depend on the angle
///          mode (`90 deg to rad` answers the same under deg/rad/gra). The whole table is on
///          `kAngleUnits` in `app_unit_catalog.dart`.
///
///          **5. What that grey `grad` row is.** The spelling most likely to come to mind for the
///          gradian is `grad` (HiPER's expanded layout has three keys literally named
///          `►DEG`/`►RAD`/`►GRAD`), and `grad` is **not an angle** in the engine: `1 grad` =
///          `1357.168026 s·rad`, and as a conversion's source it is **right in value, corrupted in
///          unit** (`90 grad to deg` = `81 d·°`). The clean spelling is `gon`, which has been in this
///          app's unit table all along (measured: `1 gon to deg` = `0.9°`). **A grey cell is honest**
///          (the same device as the matrix sheet's three rows and the result format menu's
///          `Polar coordinates` entry): it cannot be pressed, and the measured numbers are written on
///          its own row.
///
///          **6. Expiry.** Item 5's evidence is pinned in
///          `test/features/calculator_angle_convert_menu_test.dart`: the day the engine answers `grad`
///          correctly (or this app implements another spelling for the gradian), that assertion goes
///          red — and that row should then light up rather than leaving an expired refusal quietly in
///          place.
extension _CalculatorPageAngleSheet on _CalculatorPageState {
  /// 中文：`DRG` 的 SHIFT 变体打开的面板。形状与 `CPLX`/`STAT`/`MTRX` 那几个 opener 逐条相同
  ///       （`showModalBottomSheet` + 同一个高度上限常量），理由见本文件头。
  /// English: the sheet the `DRG` SHIFT variant opens. Item-for-item the same shape as the
  ///          `CPLX`/`STAT`/`MTRX` openers (`showModalBottomSheet` plus the same height-cap constant);
  ///          the reasons are in this file's head.
  void _openAngleConvertSheet() {
    final theme = CalcTheme.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height *
            _CalculatorPageState._moreSheetHeightRatio,
      ),
      // 中文：**跟着控制器重建**（与数据集面板同一个做法）：结果换了，可不可换算、当前值是几，
      //       都会在面板开着的时候跟着变——引擎跟进回来时那两行会自己灰掉或者亮起来，而不是留下
      //       一个按下去会换算一个已经不在屏幕上的数的按钮。
      // English: **it rebuilds with the controller** (the dataset sheet's own device): when the result
      //          changes, whether anything is convertible and what the current value is follow along
      //          while the sheet is open — the engine's follow-up greys or lights those rows by itself,
      //          instead of leaving a button that would convert a number no longer on screen.
      builder: (sheetContext) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => _AngleConvertSheet(page: this, theme: theme),
      ),
    );
  }

  /// 中文：面板点了一个目标单位之后走的那一条。**先关面板再换算**（矩阵菜单同一条）：表达式整条
  ///       被换掉，用户要看的是结果行上那次换算的答案。
  ///
  ///       `convertAngle` 返回 `false` 表示**什么都没改**（没有可用的数，或者拼法不在闭集里）。
  ///       那一下必须说出来——用户按了一个东西而屏幕上什么都没有，看起来像按键失灵（与
  ///       `_showBaseReadout` 同一条：有事要说时交给 `SnackBar`）。用页面自己的 context：面板那个
  ///       context 在 `pop` 之后已经不能用了。
  /// English: the path a press on a target unit takes. **The sheet closes first, then the conversion
  ///          runs** (the matrix menu's own order): the whole expression is replaced, and what the user
  ///          wants to see is that conversion's answer on the result line.
  ///
  ///          `convertAngle` returning `false` means **nothing changed at all** (no usable number, or
  ///          a spelling outside the closed set). That has to be said — the user pressed something and
  ///          the screen shows nothing, which reads as a dead button (the same rule as
  ///          `_showBaseReadout`: when there is something to say, a `SnackBar` says it). It uses the
  ///          page's own context: the sheet's context is unusable after the `pop`.
  void _convertAngle(String sourceUnit, String targetUnit) {
    if (_controller.convertAngle(sourceUnit, targetUnit)) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(CalculatorStrings.of(context).angleConvertNoValue),
      ),
    );
  }
}

/// 中文：`►DRG` 第二功能打开的面板本体。判据一条也不在这里：**可不可换算、要换算的是哪个数**由
///       控制器的 `angleConvertValue` 决定（[convertAngle] 的文件头），**两行灰的什么时候灰**由那个
///       读数加「选没选源单位」决定，而**`grad` 那一行为什么灰**的凭据是 `kAngleUnits` 上的实测表。
///
///       面板只交出一对单位拼法（`page._convertAngle`），单位表读的是 `kAngleUnits`——**与翻译层
///       那扇门同一张表**，所以「面板里能点的」与「翻译层放行的」不可能漂开。
/// English: the sheet `►DRG`'s second function opens. No judgement lives here: **whether anything can
///          be converted and which number it is** come from the controller's `angleConvertValue` (the
///          file head on `_CalculatorAngleConvert`), **when the two rows are grey** follows from that
///          reading plus "has a source been picked", and the evidence for **why the `grad` row is
///          grey** is the measurement table on `kAngleUnits`.
///
///          The sheet hands over one pair of unit spellings (`page._convertAngle`), and the unit table
///          it reads is `kAngleUnits` — **the same table the translation's door reads**, so "what can
///          be pressed in the sheet" and "what the translation admits" cannot drift apart.
class _AngleConvertSheet extends StatefulWidget {
  const _AngleConvertSheet({required this.page, required this.theme});

  final _CalculatorPageState page;
  final CalcTheme theme;

  @override
  State<_AngleConvertSheet> createState() => _AngleConvertSheetState();
}

class _AngleConvertSheetState extends State<_AngleConvertSheet> {
  /// 中文：选中的源单位。**初始为 `null`（没选）**，这是面板唯一一个「必须由用户说出来的东西」：
  ///       那个数是什么单位，应用不知道也不猜。目标那一行在它确定之前按不动。
  /// English: the selected source unit. **It starts `null` (nothing chosen)** — the one thing this
  ///          sheet insists the user states: what unit that number is in, which this app neither knows
  ///          nor guesses. Until it is set, the target row cannot be pressed.
  String? _source;

  @override
  Widget build(BuildContext context) {
    final strings = CalculatorStrings.of(context);
    final material = Theme.of(context);
    final theme = widget.theme;
    // 中文：**一次读取，两个用途**：念给用户看的那句话，与目标行按不按得动。判断在控制器里。
    // English: **one read, two uses**: the sentence read out to the user and whether the target row can
    //          be pressed. The judgement is in the controller.
    final value = widget.page._controller.angleConvertValue;
    final canConvert = value != null && _source != null;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // 中文：标题逐字用厂商的命令名——菜单的名字也是那一格定义的一部分（与 `rfMenu.title`、
            //       `MTRX` 那个面板同一条规矩）。它不含汉字，所以不走文案表。
            // English: the title is the vendor's command name verbatim — the menu's name is part of
            //          what that cell is (the same rule as `rfMenu.title` and the `MTRX` sheet). It
            //          holds no CJK, so it does not go through the string table.
            Text(
              'Convert Angular Units',
              style: material.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            // 中文：状态那一行。三句话，各自对应一种**看得见的**状态：没有可换算的数、有数但还没选
            //       源单位、有数也选了源单位。第三种用的是结果状态卡那句现成的「当前值 X」
            //       （`currentValueReading`）——同一个说法在这个应用里只有一处写法。
            // English: the status line. Three sentences, one per **visible** state: nothing
            //          convertible, a number but no source unit yet, and both. The third is the result
            //          status card's existing "当前值 X" (`currentValueReading`) — one wording, one
            //          place in this app.
            Text(
              value == null
                  ? strings.angleConvertNoValue
                  : _source == null
                      ? strings.angleConvertPickSource
                      : strings.currentValueReading(value),
              style: TextStyle(color: theme.display.statusFg, fontSize: 12),
            ),
            const SizedBox(height: 8),
            _unitRow(
              label: strings.angleConvertSourceLabel,
              // 中文：源那一行永远点得动：选源单位不换算，也不改表达式，所以「有没有可换算的数」
              //       与它无关（那个数还没有时才真的没有什么可选的——但选了也不算错，只是还没用）。
              // English: the source row is always pressable: choosing a source converts nothing and
              //          writes nothing, so "is there a convertible number" does not concern it.
              onTap: (unit) => setState(() => _source = unit),
              isSelected: (unit) => unit == _source,
              enabled: true,
            ),
            const SizedBox(height: 8),
            _unitRow(
              label: strings.angleConvertTargetLabel,
              // 中文：**点一下就换算**：整条表达式换成 `<值> <源单位> to <目标单位>`（面板先关）。
              // English: **one press converts**: the whole expression becomes
              //          `<value> <source unit> to <target unit>` (the sheet closes first).
              onTap: (unit) {
                Navigator.of(context).pop();
                widget.page._convertAngle(_source!, unit);
              },
              isSelected: (unit) => false,
              enabled: canConvert,
            ),
            const SizedBox(height: 8),
            // 中文：那一行小字不是装饰（与 `matrixMenuHint` 同一条理由）：不说「源单位永远写出来」，
            //       用户不会知道为什么要有两行；不说「整条表达式会被换掉、一次撤销能拿回来」，
            //       换掉表达式这一步就是一次意外。
            // English: this line is not decoration (the same reason as `matrixMenuHint`): without "the
            //          source unit is always written out" the user cannot tell why there are two rows,
            //          and without "the whole expression is replaced, one undo brings it back" that
            //          replacement is a surprise.
            Text(
              strings.angleConvertHint,
              style: TextStyle(color: theme.display.statusFg, fontSize: 12),
            ),
            const SizedBox(height: 8),
            // 中文：**不是 `ListView`**：灰行全部当场建出来，理由与矩阵菜单那一列相同（窗口矮一点时
            //       `ListView` 里最后几行根本不在树里，而「菜单里有没有 `grad` 这一行」正是要被问的
            //       断言）。
            // English: **not a `ListView`**: every grey row is built at once, for the same reason as
            //          the matrix menu's column (in a short window a `ListView` would leave the last
            //          rows out of the tree entirely, while "is `grad` in the menu" is exactly one of
            //          the assertions to ask).
            for (final (label, note) in _refusedRows(strings))
              ListTile(
                dense: true,
                enabled: false,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: material.disabledColor,
                  ),
                ),
                subtitle: Text(note),
              ),
          ],
        ),
      ),
    );
  }

  /// 中文：**单位那一行**——一行小标题加上 [kAngleUnits] 里逐个拼出来的按钮。键面文字就是**插进
  ///       表达式的那串拼法本身**（与矩阵菜单同一条规矩：屏幕上不会出现「按钮叫一个名字、插进去的
  ///       是另一个」）。
  ///
  ///       `enabled` 为假时 `onPressed` 传 `null`——Flutter 自己把它画成按不动，而**这里不写第二套
  ///       置灰逻辑**：可用态只有一个来源。
  /// English: **one unit row** — a small label plus one button per spelling in [kAngleUnits]. The face
  ///          is **the spelling that goes into the expression** (the matrix menu's own rule: the screen
  ///          can never show "the button says one name and inserts another").
  ///
  ///          With `enabled` false, `onPressed` is `null` — Flutter draws it unpressable itself, and
  ///          **no second grey-out logic is written here**: availability has exactly one source.
  Widget _unitRow({
    required String label,
    required void Function(String unit) onTap,
    required bool Function(String unit) isSelected,
    required bool enabled,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final unit in kAngleUnits)
              if (isSelected(unit))
                FilledButton.tonal(
                  onPressed: enabled ? () => onTap(unit) : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 38),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(unit,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                )
              else
                TextButton(
                  onPressed: enabled ? () => onTap(unit) : null,
                  style: TextButton.styleFrom(
                    foregroundColor: widget.theme.display.indicatorFg,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 38),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(unit,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
          ],
        ),
      ],
    );
  }

  /// 中文：**按不动的格子**，以及它们各自那一行小字。写成函数而不是 `const` 表，理由与矩阵菜单
  ///       那一张逐条相同：**每一行的话必须跟着那一行走**，而话住在 `CalculatorStrings` 里；于是
  ///       「加一个被拒绝的拼法」只有一种写法——把拼法与它那句话一起写出来。
  ///
  ///       今天只有一行：`grad`（第五条的实测见本文件头与 `kAngleUnits`）。
  /// English: **the unpressable cells** with their own small line each. Written as a function rather
  ///          than a `const` table for item-for-item the matrix menu's reason: **each row's sentence
  ///          has to travel with that row**, and the sentences live in `CalculatorStrings`, so "add a
  ///          refused spelling" has exactly one spelling — write the spelling and its sentence out
  ///          together.
  ///
  ///          There is one row today: `grad` (item 5's measurements are in this file's head and on
  ///          `kAngleUnits`).
  List<(String, String)> _refusedRows(CalculatorStrings strings) =>
      <(String, String)>[
        ('grad', strings.angleConvertGradNote),
      ];
}
