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

  @override
  Widget build(BuildContext context) {
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
            // 中文：两句都不是装饰。①不说「那串数是从哪儿来的」，屏幕上就凭空多出一串用户没打过的
            //       数字，看起来像错值；②不说样本（n−1）约定，`stdev` 给的 1.290 会被当成总体的
            //       1.118——**两个都是合理的数**，而屏幕上没有任何线索。
            // English: neither sentence is decoration. Without (1) a run of digits the user never
            //          typed appears from nowhere and reads as a wrong value; without (2) `stdev`'s
            //          sample-convention 1.290 reads as the population 1.118 — **both are reasonable
            //          numbers** and nothing on screen would say which one this is.
            Text(
              '插入的是完整调用；实参来自数据集，数据集为空时用起手数据，'
              '插入之后那串数仍可在内联编辑器里改（逗号可以打）。'
              'stdev/var 按样本（n−1）算。',
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
    return Row(
      children: [
        Expanded(
          child: Text(
            values.isEmpty
                ? '数据集空，插入起手数据 ${page._controller.datasetCallArguments}'
                : '数据集 ${values.length} 个：${values.join(', ')}',
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
          child: const Text('数据集…'),
        ),
      ],
    );
  }
}
