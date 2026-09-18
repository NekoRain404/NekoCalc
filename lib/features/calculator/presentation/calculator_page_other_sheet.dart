part of 'calculator_page.dart';

/// 中文：**`OTHER` 的面板：那一格与它打开的面板。** 本页每一块自成一体的面板都有自己的 part 文件（`MTRX` 在 `calculator_page_matrix_sheet.dart`、`STAT` 在 `calculator_page_dataset_sheet.dart`、`DRG` 在 `calculator_page_angle_sheet.dart`），这一块是剩下的三块之一，按同一条规矩搬过来：**一个键（或一颗按钮）与它打开的那一个面板住在一个文件里**，而 `calculator_page_sheets.dart` 留下的是所有面板**共用**的那点东西（光标键、记忆读数、复制/粘贴/笔记那几个动作）。搬的只是位置：id 词汇、插入路径与每一个字都没有动。
///
/// English: **the `OTHER` panel: that cell and the sheet it opens.** Every self-contained panel on this screen has its own part file (`MTRX` in `calculator_page_matrix_sheet.dart`, `STAT` in `calculator_page_dataset_sheet.dart`, `DRG` in `calculator_page_angle_sheet.dart`); this is one of the three still left, moved by the same rule: **one key (or button) and the one panel it opens live in one file**, while `calculator_page_sheets.dart` keeps what every panel **shares** (the cursor keys, the memory reading, the copy/paste/note actions). Only the position moved: the id vocabulary, the insertion path and every character are untouched.

extension _CalculatorPageOtherSheet on _CalculatorPageState {
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
        maxHeight: MediaQuery.sizeOf(context).height *
            _CalculatorPageState._moreSheetHeightRatio,
      ),
      builder: (sheetContext) => _MoreFunctionsSheet(page: this, theme: theme),
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
    'cot',
    'sec',
    'csc',
    'log₂',
    'exp',
    'floor',
    'ceil',
    'round',
    'min',
    'max',
    'gcd',
    'lcm',
    'atan2',
    'deg',
    'rad',
    '90°',
    '180°',
    '360°',
    '2ˣ',
    'φ',
    '√2',
    'τ',
    'ln2',
    'ln10',
    'g',
    'c',
    '2π',
    'π/2',
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
