part of 'calculator_page.dart';

/// 中文：**`CPLX` 的面板：那一格与它打开的面板。** 缝与理由逐条同 `calculator_page_other_sheet.dart` 的开头：本页自成一体的面板各有自己的 part 文件，这一块按同一条规矩搬出来，`calculator_page_sheets.dart` 只留共用件。搬的只是位置，内容一个字没有动。
///
/// English: **the `CPLX` panel: that cell and the sheet it opens.** The seam and its reasons are the ones at the head of `calculator_page_other_sheet.dart`: every self-contained panel on this screen has its own part file, so this one moved out by the same rule and `calculator_page_sheets.dart` keeps only the shared parts. Only the position moved; not one character of the content changed.

extension _CalculatorPageComplexSheet on _CalculatorPageState {
  /// 中文：`CPLX` 打开的复数面板。与 `CONV`/`X` 同一种做法：面板只交出**记号**，插入仍走主屏的
  ///       `_pressKey`——于是「面板里有什么」与「键盘能派发什么」是同一套 id 词汇，没有第二份映射
  ///       （`_MoreFunctionsSheet` 立的规矩）。四颗一元函数按下去包住光标前那一个值，`i` 按下去把
  ///       虚数单位追加进去，两者都是键盘上已经有的动作，只是键盘上没有这几颗键。
  ///
  ///       为什么这里**没有一个「复数模式」开关**：这一轮量出来的事实是那个能力**已经开着**
  ///       （`allow_complex(true)`，实测 `sqrt(-4)` = `2i`），所以一个开关只会是一盏骗人的指示灯。
  ///       键位表上 `CPLX` 那颗键的注释写了完整的论证。
  /// English: the complex sheet `CPLX` opens. The `CONV`/`X` shape: the sheet hands over **tokens**
  ///          only, and insertion still travels the screen's `_pressKey` — so "what is in the sheet"
  ///          and "what the keypad can dispatch" are one id vocabulary with no second mapping (the rule
  ///          `_MoreFunctionsSheet` set). The four unary functions wrap the value before the cursor and
  ///          `i` appends the imaginary unit, and both are actions the keypad already has — it simply
  ///          has no key for these.
  ///
  ///          Why there is **no "complex mode" switch** here: what was measured this round is that the
  ///          capability is **already on** (`allow_complex(true)`, `sqrt(-4)` = `2i` measured), so a
  ///          switch could only be a lying indicator lamp. The full argument is on the `CPLX` cell in
  ///          the key table.
  void _openComplexSheet() {
    final theme = CalcTheme.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height *
            _CalculatorPageState._moreSheetHeightRatio,
      ),
      builder: (sheetContext) => _ComplexSheet(page: this, theme: theme),
    );
  }
}

/// 中文：`CPLX` 面板的内容——**复数入口**，与 `CONV`/`X` 同一种形状：面板只列记号，按下去交给
///       本页的 `_pressKey`，所以这里没有第二份「记号 → 动作」的映射。
///
///       六格里的每一格都有一个**理由**，写下来是因为「复数面板该放什么」不是一个自明的问题：
///       - `conj` / `arg` / `re` / `im`：键盘上一个键都没有，而它们各自要一个实参（`arg` 还要跟着
///         角度模式走），所以只能从这里进；
///       - `abs`：键盘上**有**这颗键（算复数就是模），放在这里是因为没有模的复数面板不成套；
///       - `i`：`i` 那颗键也在键盘上，但虚数单位不在面板里同样说不通。两者都只是**再指一次**
///         同一个 id，主屏那一侧一行没改。
///
///       面板**按一下就关**（与 `OTHER` 一致，不像 `CONV`/`X` 那样留着）：这里每一下都是完整动作，
///       而面板盖住键盘与显示区，留着它反而挡住「看看包出什么来了」。
/// English: the contents of the `CPLX` sheet — the **complex entrance**, the `CONV`/`X` shape: the
///          sheet lists tokens only and hands a press to this page's `_pressKey`, so no second
///          "token → action" mapping exists here.
///
///          Each of the six cells has a **reason**, written down because "what belongs in a complex
///          sheet" is not a self-evident question:
///          - `conj` / `arg` / `re` / `im`: the keypad has no key for any of them, and each takes an
///            argument (`arg` also follows the angle mode), so this is their only way in;
///          - `abs`: the keypad **does** have this key (for a complex number it is the modulus); it is
///            here because a complex sheet without a modulus is not a set;
///          - `i`: the `i` key is on the keypad too, but an imaginary unit missing from the sheet would
///            be just as odd. Both merely **point again** at the same id; the screen is unchanged.
///
///          The sheet **closes on a press** (as `OTHER` does, not staying up like `CONV`/`X`): every
///          press here is a complete action, and the sheet covers the keypad and the display, so
///          leaving it up would block the "see what it wrapped" step.
class _ComplexSheet extends StatelessWidget {
  const _ComplexSheet({required this.page, required this.theme});

  final _CalculatorPageState page;
  final CalcTheme theme;

  /// 中文：（键面文字, 派发的 id）。id 逐字来自主屏的 `_pressKey`，与键位表用的是同一套词汇。
  /// English: (key face, dispatched id). The ids come verbatim from the screen's `_pressKey` and are
  ///          the same vocabulary the key table uses.
  static const List<(String, String)> _entries = <(String, String)>[
    ('i', 'ins:i'),
    ('abs', 'abs'),
    ('conj', 'conj'),
    ('arg', 'arg'),
    ('re', 're'),
    ('im', 'im'),
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
      ),
    );
  }
}
