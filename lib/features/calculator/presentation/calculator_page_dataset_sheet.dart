part of 'calculator_page.dart';

/// 中文：**统计数据集这一侧的界面**——`STAT` 面板（统计入口）与它下面那行数据集读数，以及打开数据集
///       编辑面板的那一个方法。它们从 `calculator_page_sheets.dart` 里搬出来**只是为了行数**：那个文件
///       已经贴着 800 行那条硬性上限，而这一块是自成一体的（`STAT` 那两颗键与它们的数据集）。
///
///       搬动是**纯搬动**：没有改任何一个字符的行为，`_StatisticsSheet` 仍是本库私有的那个类，仍然只
///       由 `openStatistics` 那一条 case 打开，插入仍然走主屏的 `_pressKey`。
///
/// English: **the dataset side of the statistics UI** — the `STAT` sheet (the statistics entrance) with
///          the dataset row under it, plus the one method that opens the dataset editor sheet. They were
///          moved out of `calculator_page_sheets.dart` **for line count alone**: that file was sitting
///          against the hard 800-line cap, and this block is self-contained (the `STAT` key and its
///          dataset).
///
///          The move is a **pure move**: not one character of behaviour changed. `_StatisticsSheet` is
///          still this library's private class, still opened only by the `openStatistics` case, and
///          insertion still travels the screen's `_pressKey`.
extension _CalculatorPageDatasetSheet on _CalculatorPageState {
  /// 中文：`STAT` 面板里那颗 `数据集…` 打开的编辑面板。与 `X` 面板同一种做法：**不自动关闭**
  ///       （加值、去值、清空是好几下，每按一下都关掉的话用户要开很多次），读数与按钮的可用态跟着
  ///       控制器走（`AnimatedBuilder` 的 `animation` 就是控制器），于是加进去一个值之后那一行原地
  ///       变成新的计数，不需要关掉重开。
  ///
  ///       它**不插任何东西进表达式**：值是加进数据集的，插入仍然只发生在 `STAT` 面板那四格
  ///       （那里走主屏的 `_pressKey`）。一个按钮因此只有一个落点，没有第二份映射。
  ///
  ///       `onAdd` 直接把控制器的 `addDatasetValue` 挂上去——它返回的那句话（被拒时）由面板显示。
  ///       判定在控制器里、界面在别处，那句话不可能与判定漂开（与 `VariablePickerSheet` 同一条）。
  ///
  /// English: the editor sheet the `数据集…` button inside the `STAT` sheet opens. Same shape as the
  ///          `X` sheet: it **does not close itself** (adding, dropping and clearing are several
  ///          presses, and closing after each would make the user reopen it many times), and the
  ///          readings and button availability follow the controller (the `AnimatedBuilder`'s animation
  ///          is the controller), so after adding a value that line becomes the new count in place with
  ///          no need to close and reopen.
  ///
  ///          It inserts **nothing** into the expression: values go into the dataset, and insertion
  ///          still happens only in the `STAT` sheet's four cells (which travel the screen's `_pressKey`).
  ///          One button therefore has one landing place and there is no second mapping.
  ///
  ///          `onAdd` is the controller's `addDatasetValue` itself — the sentence it returns (on a
  ///          refusal) is displayed by the sheet. The judgement is in the controller and the screen is
  ///          elsewhere, so the sentence cannot drift from it (the same rule as `VariablePickerSheet`).
  void _openDatasetSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height *
            _CalculatorPageState._moreSheetHeightRatio,
      ),
      builder: (sheetContext) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => DatasetSheet(
          values: _controller.datasetValues,
          storableValue: _controller.storableDatasetValue,
          callArguments: _controller.datasetCallArguments,
          onAdd: _controller.addDatasetValue,
          onRemove: _controller.removeDatasetValueAt,
          onClear: _controller.clearDataset,
          onClose: () => Navigator.of(sheetContext).pop(),
        ),
      ),
    );
  }

  /// 中文：**回归图那一张面板**——HiPER 那条计算细节（`Graph of regression`：一条拟合曲线与所有
  ///       的数据点，来源与取法见 `RegressionGraphSheet` 的类注释）。
  ///
  ///       ### 为什么入口在这一行
  ///
  ///       它紧挨着那三个拟合格，因为那张图画的就是**这三个函数之一**：来源里这条图是**回归函数**
  ///       的计算细节，而在这个应用里回归函数只在 `STAT` 面板上。放到别处（比如显示区那颗 `更多…`）
  ///       就得在这里另造一套「当前是哪条回归」的状态——那是第二个真相源。
  ///
  ///       ### 那一刻的点与读数都是**冻结**的
  ///
  ///       打开时把三个东西交给面板：**那一刻的 `points`**、那一行读数、以及一个「向控制器要曲线」
  ///       的回调。面板**不**跟着控制器重建，理由有两条，第二条是承重的：
  ///
  ///       1. 数据集**改不动**——编辑数据集的入口在 `STAT` 面板里（打开本面板时它已经关掉了），
  ///          而这是一张模态面板，键盘在遮罩后面。所以「图上的点」在这一整段时间里不会变。
  ///       2. 曲线是从**那一刻**的数据集算出来的（[CalculatorController.regressionCurveFor] 的代际
  ///          守卫挡的是同一件事）。让面板跟着控制器重建，就会有一个「新的点 + 旧的曲线」的瞬间，
  ///          而那个瞬间在屏幕上看起来是一张完全正常的图。
  ///
  ///       **画不出来时不画线**：三种原因（对数不够 / 翻译不过去 / 引擎没答）各有各的话，都由
  ///       控制器给出（`RegressionCurveOutcome.refusal`），面板只把它印出来。
  ///
  /// English: **the regression graph sheet** — HiPER's calculation detail (`Graph of regression`: one
  ///          fitted curve and all the data points; the sources and how they were checked are on
  ///          `RegressionGraphSheet`'s class note).
  ///
  ///          ### Why the entrance is on this row
  ///
  ///          It sits next to the three fit cells because that figure is of **one of those three
  ///          functions**: in the sources this plot is a calculation detail of the **regression
  ///          function**, and in this app the regression functions live only on the `STAT` sheet.
  ///          Anywhere else (the display's `更多…`, say) would mean inventing a "which regression is
  ///          current" state over there — a second source of truth.
  ///
  ///          ### The points and the reading are **frozen** at open time
  ///
  ///          Three things are handed to the sheet: **the `points` as they are at that moment**, that
  ///          row's reading, and a callback that asks the controller for a curve. The sheet does
  ///          **not** rebuild with the controller, for two reasons, the second of which is
  ///          load-bearing:
  ///
  ///          1. The dataset **cannot change** — its editor is opened from the `STAT` sheet (already
  ///             closed by the time this one opens) and this is a modal sheet with the keypad behind
  ///             the barrier. So "the points on the plot" cannot move for as long as it is up.
  ///          2. The curve is computed from **that moment's** dataset (the generation guard in
  ///             [CalculatorController.regressionCurveFor] stops the same thing). Letting the sheet
  ///             rebuild with the controller would create an instant of "new points, old curve", and
  ///             that instant looks like a perfectly normal figure on screen.
  ///
  ///          **When it cannot be drawn, no line is drawn**: the three causes (not enough pairs / does
  ///          not translate / the engine did not answer) each have a sentence of their own from the
  ///          controller (`RegressionCurveOutcome.refusal`), and the sheet merely prints it. And those
  ///          three cells **are always lit** (the reason is written beside them in the sheet) — so "why
  ///          has the cubic fit no curve" is a question the screen can answer.
  void _openRegressionGraphSheet() {
    final points = _controller.regressionGraphPoints;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height *
            _CalculatorPageState._moreSheetHeightRatio,
      ),
      builder: (sheetContext) => RegressionGraphSheet(
        points: points,
        fitNames: kFitMinimumPairs.keys.toList(growable: false),
        loadCurve: _controller.regressionCurveFor,
        fitReading: _controller.regressionGraphFitReading,
        pointsUnavailableMessage: _controller.regressionUnavailableMessage,
      ),
    );
  }

  // 中文：**下面这两个方法是搬过来的**（纯搬动，行为一个字符没改）：它们建的是 `STAT` 面板那几格
  //       插进表达式的调用，所以与面板住在一起；`_pressKey` 里那几个 `ins:` case 跨文件调用它们。
  // English: **the two methods below were moved here** (a pure move, not one character of behaviour
  //          changed): they build the calls the `STAT` sheet's cells insert, so they live with that
  //          sheet; the `ins:` cases in `_pressKey` call them from the other part file.
  /// 中文：双变量那三格（`pearson`/`covar`/`spearman`）共用的一条：**控制器说读不成两行就不插**。
  ///
  ///       为什么不让 `case` 里直接 `append(regressionCall(...)!)`：`regressionCall` 在数据集读不成
  ///       两行时返回 `null`，而 `!` 会把它变成一个只在设备上崩的异常——那正是 `MathEngine` 契约里
  ///       明说不许出现的形状（「实现不抛异常，调用方不能把守约当本钱」）。这里把 `null` 与「什么
  ///       都不做」对上，判据仍然是 `regressionCall` 那一处，这里不写第二份。
  ///
  ///       面板上同一条判据把这三格变成禁用态，所以从界面上到不了这个 `null`；这条分支的存在是为了
  ///       **让 id 本身不会绕过面板**去插一条引擎答不出来的调用。
  ///
  /// English: the one path the three two-variable cells (`pearson`/`covar`/`spearman`) share: **when
  ///          the controller says the dataset cannot be read as two rows, nothing is inserted.**
  ///
  ///          Why not `append(regressionCall(...)!)` in the `case`: `regressionCall` returns `null`
  ///          while the dataset cannot be read as two rows, and `!` would turn that into an exception
  ///          that only ever fires on a device — exactly the shape the `MathEngine` contract forbids
  ///          ("implementations do not throw, and the caller may not bank on that"). Here `null` maps
  ///          to "do nothing", and the judgement still lives in `regressionCall` alone; no second copy
  ///          is written.
  ///
  ///          The sheet turns these three cells into disabled ones on the same judgement, so the
  ///          `null` is unreachable from the screen; this branch exists so that **an id cannot bypass
  ///          the sheet** and insert a call the engine cannot answer.
  void _appendRegressionCall(String function) {
    final call = _controller.regressionCall(function);
    if (call == null) return;
    _controller.append(call);
  }

  /// 中文：三个拟合格共用的一条，与 [_appendRegressionCall] 逐字同形（判据说 `null` 就什么都不做，
  ///       判据仍然只有 `fitCall` 一处）。**它是分开的一个方法，因为判据不同**：三个拟合各有各的
  ///       下限，所以「哪几格亮」不是整行一个布尔。
  /// English: the one path the three fit cells share, word for word the shape
  ///          [_appendRegressionCall] has (the judgement says `null` ⇒ do nothing, and that judgement
  ///          is still written once, on `fitCall`). **It is a separate method because the judgement
  ///          differs**: each fit has its own floor, so "which cells are lit" is not one boolean for the
  ///          whole row.
  void _appendFitCall(String function) {
    final call = _controller.fitCall(function);
    if (call == null) return;
    _controller.append(call);
  }
}

/// 中文：`STAT` 面板的内容——**统计入口**。同样只列记号，按下去交给本页的 `_pressKey`。
///
///       每一格派发的是一个 `ins:` id，主屏把它变成**一整个调用**（`mean(5,12,13)`）追加进表达式。
///       **实参从这一轮起由数据集给出**：数据集非空时插的是它那几个值，为空时是那串**起手数据**
///       （`1,2,3,4`，也就是上一轮写死的那一串）。两种情况的形状一样——完整、按下去立刻求得出一个
///       数，同时把引擎的实参顺序摆在屏幕上。
///
///       面板下面那一行是这个数据集的**入口与读数**：有 `数据集…` 一个按钮打开编辑面板（值的增删在
///       那里），以及「此刻会插什么」的一句话——不说，用户按下去就会凭空多出一串自己没打过的数字。
///
///       它**不重复**那四个函数格：那是数据集的编辑面板的邻居，不是它的内容（一个按钮只有一个落点）。
///
///       这一行跟着控制器走（`AnimatedBuilder`），所以在编辑面板里加了一个值、回到这里时读数是新的，
///       不需要把面板关掉重开——与 `X` 面板里那个读数是同一条。
///
/// English: the contents of the `STAT` sheet — the **statistics entrance**. It likewise lists tokens
///          only and hands a press to this page's `_pressKey`.
///
///          Each cell dispatches an `ins:` id that the screen turns into **a whole call**
///          (`mean(5,12,13)`) appended to the expression. **The arguments come from the dataset from
///          this round on**: with a non-empty dataset it inserts those values, and with an empty one
///          the **starting sample** (`1,2,3,4`, the run hardcoded last round). Both have the same
///          shape — complete, one press yields a number immediately, and the engine's argument order
///          goes on screen.
///
///          The row below the four cells is that dataset's **entrance and reading**: a single
///          `数据集…` button opening the editor sheet (adding and dropping values happens there), plus
///          one sentence saying what would be inserted right now — unsaid, a press would produce a run
///          of digits the user never typed.
///
///          It **does not repeat** the four function cells: those belong to the statistics entrance,
///          not to the dataset editor (one button, one landing place).
///
///          This row follows the controller (`AnimatedBuilder`), so after adding a value in the editor
///          sheet the reading here is fresh when the user comes back — no need to close and reopen,
///          the same device the `X` sheet's reading uses.
class _StatisticsSheet extends StatelessWidget {
  const _StatisticsSheet({required this.page, required this.theme});

  final _CalculatorPageState page;
  final CalcTheme theme;

  /// 中文：（键面文字, 派发的 id）。id 与主屏 `_pressKey` 里那几个 `ins:` case 逐字对应。
  /// English: (key face, dispatched id). The ids correspond byte for byte to the `ins:` cases in the
  ///          screen's `_pressKey`.
  static const List<(String, String)> _entries = <(String, String)>[
    ('mean', 'ins:mean'),
    ('median', 'ins:median'),
    ('stdev', 'ins:stdev'),
    ('var', 'ins:var'),
  ];

  /// 中文：**双变量那三格**——它们读的是同一个数据集的**另一种形状**（两行：前一半 X、后一半 Y），
  ///       所以它们自成一行，而且跟着数据集走。判据只有一处
  ///       （`canReadDatasetAsTwoRows`）：为假时这三格**禁用**，并在旁边写出为什么
  ///       （`regressionUnavailableMessage`）。
  ///
  ///       为什么禁用而不是「按下去插一条会报错的调用」：那样一颗键看起来是好的，按下去给一句
  ///       错误——那是一句谎。**灰键是诚实的**，而且它旁边就写着要加几个值才能亮。
  ///
  ///       为什么不是「数据集中有一个成对约定」：这个数据集里没有成对约定，是**两行**约定。
  ///       HiPER 的帮助文本把两种形状写在一句话里（行矩阵＝一组值，两行矩阵＝X 行与 Y 行），
  ///       本应用的一个数据集因此有两种读法——四个描述统计读一行，这三个读两行。
  ///       **不是第二个真相源**：读的还是同一串值（理由在 `datasetPairCount` 上）。
  ///
  /// English: **the three two-variable cells** — they read **another shape** of the same dataset (two
  ///          rows: the first half X, the second half Y), so they get a row of their own and they
  ///          follow the dataset. The judgement lives in one place (`canReadDatasetAsTwoRows`): while
  ///          it is false these three are **disabled**, with the reason written beside them
  ///          (`regressionUnavailableMessage`).
  ///
  ///          Why disabled rather than "a press inserts a call that errors": such a key looks fine and
  ///          answers with an error — a lie. **A grey cell is honest**, and the cell beside it says how
  ///          many values it needs before it lights up.
  ///
  ///          Why this is not "a pairing convention inside the dataset": there is no pairing
  ///          convention here, there is a **two-row** one. HiPER's help text names both shapes in a
  ///          single sentence (a row matrix is a set of values, a two-row matrix is an X row and a Y
  ///          row), so one dataset in this app has two readings — the four descriptive statistics read
  ///          one row, these three read two. **It is not a second source of truth**: the same run of
  ///          values is read (the reasons are on `datasetPairCount`).
  static const List<(String, String)> _regressionEntries = <(String, String)>[
    ('pearson', 'ins:pearson'),
    ('spearman', 'ins:spearman'),
    ('covar', 'ins:covar'),
  ];

  /// 中文：**三个拟合格**——回归的那些格的下一行。它们与上面那三格的分别有两处，两处都是量出来的：
  ///
  ///       1. **要几对值不同，而且三格各不相同**（`kFitMinimumPairs`：2/3/4）。所以这一行的
  ///          `onPressed` **按格判**，不是整行一个布尔——用同一个下限会让两格各按下去插一条
  ///          引擎答不出来的调用，屏幕上是一句错误。
  ///       2. **它们插的形状不同**（两个行矩阵，不是两行矩阵）：理由与实测表在 `fitCall` 上。
  ///
  ///       暗淡的那几格旁边**同一行里就写着为什么**（控制器的 `fitStatusMessage`，不是这里另写
  ///       一句）。**灰键是诚实的**；一个按下去只给错误的键不是。
  /// English: **the three fit cells** — the row below the regression ones. They differ from the three
  ///          above in two ways, both measured:
  ///
  ///          1. **How many pairs they need differs, and differs per cell** (`kFitMinimumPairs`:
  ///             2/3/4). So this row's `onPressed` is judged **cell by cell** rather than by one boolean
  ///             for the whole row — a shared floor would make two of them insert a call the engine
  ///             cannot answer, which is an error on screen.
  ///          2. **The shape they insert differs** (two row matrices, not a two-row matrix): the
  ///             reasons and the measurement table are on `fitCall`.
  ///
  ///          While a cell is dark, **the why sits on the same line** (the controller's
  ///          `fitStatusMessage` rather than a sentence written here). **A grey cell is honest**; a
  ///          cell that answers with an error is not.
  ///
  ///          这一行的尾巴上还有一颗 `回归图…`——**HiPER 那条计算细节的入口**（见
  ///          `_openRegressionGraphSheet`）。它**与那三格用同一条判据亮灭**
  ///          （`canReadDatasetAsTwoRows`）：读不成两行时图上没有点可画，一颗按下去只打开一张空
  ///          面板的键与一颗只给错误的键是同一种东西。
  ///          The row also carries a `回归图…` button at its end — **the entrance to HiPER's
  ///          calculation detail** (see `_openRegressionGraphSheet`). It **lights and dims on the same
  ///          judgement as the three cells** (`canReadDatasetAsTwoRows`): with no two-row reading there
  ///          are no points to plot, and a key that opens an empty sheet is the same thing as a key
  ///          that answers with an error.
  static const List<(String, String)> _fitEntries = <(String, String)>[
    ('linearfit', 'ins:linearfit'),
    ('quadraticfit', 'ins:quadraticfit'),
    ('cubicfit', 'ins:cubicfit'),
  ];

  @override
  Widget build(BuildContext context) {
    final strings = CalculatorStrings.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final (label, id) in _entries)
                  TextButton(
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
                    child: Text(label,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            AnimatedBuilder(
              animation: page._controller,
              builder: (context, _) => _datasetRow(context),
            ),
            const SizedBox(height: 6),
            AnimatedBuilder(
              animation: page._controller,
              builder: (context, _) => _regressionRow(context),
            ),
            const SizedBox(height: 6),
            AnimatedBuilder(
              animation: page._controller,
              builder: (context, _) => _fitRow(context),
            ),
            const SizedBox(height: 6),
            // 中文：两句都不是装饰。①不说「那串数是从哪儿来的」，屏幕上就凭空多出一串用户没打过的
            //       数字，看起来像错值；②不说样本（n−1）约定，`stdev` 给的 1.290 会被当成总体的
            //       1.118——**两个都是合理的数**，而屏幕上没有任何线索。
            // English: neither sentence is decoration. Without (1) a run of digits the user never
            //          typed appears from nowhere and reads as a wrong value; without (2) `stdev`'s
            //          sample-convention 1.290 reads as the population 1.118 — **both are reasonable
            //          numbers** and nothing on screen would say which one this is.
            Text(
              strings.statisticsHint,
              style: TextStyle(color: theme.display.statusFg, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  /// 中文：数据集的读数与入口。读数说清**此刻会插什么**（这是屏幕上唯一一处交代那串数从哪儿来的
  ///       地方），按钮打开编辑面板。按按钮时**先关掉本面板**，与同文件里那几个「选中即关」的按钮
  ///       同一条理由：面板盖着键盘，两层叠着的面板谁也看不清。
  /// English: the dataset's reading and entrance. The reading says **what would be inserted right
  ///          now** (this is the only place on screen that says where those numbers come from), and the
  ///          button opens the editor sheet. Pressing it **closes this sheet first**, the same reason
  ///          the "pick and close" buttons in this file give: the sheet covers the keypad, and two
  ///          stacked sheets are legible to nobody.
  Widget _datasetRow(BuildContext context) {
    final values = page._controller.datasetValues;
    final strings = CalculatorStrings.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            values.isEmpty
                ? strings
                    .datasetCallEmpty(page._controller.datasetCallArguments)
                : strings.datasetCallValues(values.length, values.join(', ')),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: theme.display.statusFg, fontSize: 12),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            page._openDatasetSheet();
          },
          style: TextButton.styleFrom(
            foregroundColor: theme.display.indicatorFg,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            minimumSize: const Size(0, 38),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(strings.datasetSheetButton),
        ),
      ],
    );
  }

  /// 中文：双变量那三格，以及它们在数据集读不成两行时的**禁用态与理由**。
  ///
  ///       读数那一行说清**这个数据集此刻被切成什么形状**（`matrix(2,n,…)` 逐字写出来），因为
  ///       屏幕上那串数正是用户自己会去改的东西——不说清，`pearson(matrix(2,3,…))` 里那个 `2`
  ///       与 `3` 就是两个没有来历的数字。这与上面 `_datasetRow` 那条读数是同一个理由。
  ///
  ///       禁用时**同一行里就写着为什么**（控制器给的 [regressionUnavailableMessage]，不是这里
  ///       另写一句）：判定在控制器里、界面在别处，两者不可能漂开。
  ///
  /// English: the three two-variable cells, together with their **disabled state and its reason**
  ///          while the dataset cannot be read as two rows.
  ///
  ///          The reading line says **what shape this dataset is cut into right now**
  ///          (`matrix(2,n,…)` spelled out), because the numbers on screen are exactly what the user
  ///          will edit — unsaid, the `2` and the `3` in `pearson(matrix(2,3,…))` are two numbers with
  ///          no provenance. That is the same reason `_datasetRow`'s reading above is there.
  ///
  ///          While disabled, **the why sits on the same line** (the controller's
  ///          [regressionUnavailableMessage] rather than a sentence written here): the judgement is in
  ///          the controller and the screen is elsewhere, so the two cannot drift apart.
  Widget _regressionRow(BuildContext context) {
    final controller = page._controller;
    final available = controller.canReadDatasetAsTwoRows;
    final strings = CalculatorStrings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              strings.twoVariableRowTitle,
              style: TextStyle(color: theme.display.statusFg, fontSize: 12),
            ),
            for (final (label, id) in _regressionEntries)
              TextButton(
                onPressed: available
                    ? () {
                        Navigator.of(context).pop();
                        page._pressKey(id);
                      }
                    : null,
                style: TextButton.styleFrom(
                  foregroundColor: theme.display.indicatorFg,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 38),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
          ],
        ),
        Text(
          available
              ? strings
                  .datasetAsTwoRows(controller.regressionCall('pearson') ?? '')
              : controller.regressionUnavailableMessage,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: theme.display.statusFg, fontSize: 12),
        ),
      ],
    );
  }

  /// 中文：三个拟合格，以及它们各自的禁用态与那一行的读数（读数为什么是这个形状见
  ///       `CalculatorController.fitStatusMessage`：三格各有各的下限，所以**一格亮两格灰是常态**，
  ///       读数因此永远给出下限与个数，再在至少有一格亮着时接上第一条会插进去的调用）。
  /// English: the three fit cells, with their own disabled states and the row's reading (why the
  ///          reading has this shape is on `CalculatorController.fitStatusMessage`: the three cells
  ///          have a floor each, so **one lit and two dark is the normal state**, and the reading
  ///          therefore always gives the floors and the count, appending the first call that would be
  ///          inserted once at least one cell is lit).
  Widget _fitRow(BuildContext context) {
    final controller = page._controller;
    final strings = CalculatorStrings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              strings.fitRowTitle,
              style: TextStyle(color: theme.display.statusFg, fontSize: 12),
            ),
            for (final (label, id) in _fitEntries)
              TextButton(
                onPressed: controller.fitCall(label) == null
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        page._pressKey(id);
                      },
                style: TextButton.styleFrom(
                  foregroundColor: theme.display.indicatorFg,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 38),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(label,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            TextButton(
              onPressed: controller.canReadDatasetAsTwoRows
                  ? () {
                      Navigator.of(context).pop();
                      page._openRegressionGraphSheet();
                    }
                  : null,
              style: TextButton.styleFrom(
                foregroundColor: theme.display.indicatorFg,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 38),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(strings.regressionGraphButton),
            ),
          ],
        ),
        Text(
          controller.fitStatusMessage,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: theme.display.statusFg, fontSize: 12),
        ),
      ],
    );
  }
}
