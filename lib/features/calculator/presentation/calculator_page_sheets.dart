part of 'calculator_page.dart';

extension _CalculatorPageSheets on _CalculatorPageState {
  /// 中文：`More...` 面板里的两个可长按光标键。配色仍全部来自 `CalcTheme`：图标用次要状态色，
  ///       底色用显示区底色，描边是该色的低透明度版本（不引入新的色位，也没有硬编码色值）。
  /// English: The two hold-to-repeat cursor keys inside the `More...` sheet. Every colour still comes
  ///          from `CalcTheme`: the icon takes the secondary status colour, the fill the display
  ///          background, and the border a low-alpha version of the icon colour — no new colour slot
  ///          and no hardcoded value.
  Widget _repeatableCursorButton({
    required CalcTheme theme,
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required VoidCallback onBlockMove,
    required VoidCallback onRepeat,
  }) {
    return _RepeatableCursorButton(
      icon: icon,
      tooltip: tooltip,
      color: theme.display.statusFg,
      backgroundColor: theme.display.background,
      borderColor: theme.display.statusFg.withValues(alpha: _CalculatorPageState._cursorBorderAlpha),
      onTap: onTap,
      onBlockMove: onBlockMove,
      onRepeat: onRepeat,
    );
  }

  /// 中文：记忆寄存器的读数——`M ` 加按设置格式化的值，与应用其余处的数字格式一致：显示结果
  ///       （`calculator_controller.dart:530`）与导出报告文本（`:544`）都按 `settings.groupThousands`
  ///       格式化。重写前的记忆条是唯一漏掉该设置的地方（只传了 precision），所以读数现在会写
  ///       `M 12,345` 而不是 `M 12345`——由「记忆读数按设置的千分位格式化」这条测试钉住。
  /// English: The memory register's reading — `M ` plus the value formatted per settings, matching how
  ///          the rest of the app formats numbers: both the displayed result
  ///          (`calculator_controller.dart:530`) and the exported report text (`:544`) honour
  ///          `settings.groupThousands`. The pre-rewrite memory bar was the one place that ignored the
  ///          setting (it passed `precision` only), so the reading now shows `M 12,345` rather than
  ///          `M 12345` — pinned by the 「记忆读数按设置的千分位格式化」 test.
  String _memoryLabel() {
    return 'M ${formatNumber(
      _controller.memoryValue,
      precision: widget.settings.precision,
      groupThousands: widget.settings.groupThousands,
    )}';
  }

  /// 中文：面板里的「编辑表达式」：先关面板再打开内联编辑器并要求焦点——旧工具条上那颗编辑按钮的行为。
  /// English: The sheet's "edit expression": close the sheet, then open the inline editor asking for
  ///          focus — exactly what the old toolbar's edit button did.
  void _editFromSheet() {
    _openInlineEditor(requestFocus: true);
  }

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
        maxHeight: MediaQuery.sizeOf(context).height * _CalculatorPageState._moreSheetHeightRatio,
      ),
      builder: (sheetContext) => _MoreFunctionsSheet(page: this, theme: theme),
    );
  }

  /// 中文：`CONV` 打开的单位面板。面板**不自动关**（一次换算要插源、`to`、目标三样），插入直接
  ///       走控制器的 `input`——与键盘同一个入口，所以光标位置、撤销栈、边打边算全都照旧。
  /// English: the unit sheet `CONV` opens. It does **not** close itself (one conversion inserts the
  ///          source, a `to` and the target), and insertion goes through the controller's `input` — the
  ///          same entrance the keypad uses, so cursor position, the undo stack and as-you-type
  ///          evaluation all behave as before.
  void _openUnitSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * _CalculatorPageState._moreSheetHeightRatio,
      ),
      // 中文：**面板交出来的是裸记号，分隔符在这里（也是唯一一处）决定。** 真实按键流是一串
      //       相邻插入（`5` → `km` → `to` → `mi`），不加分隔符它们会粘成 `5kmtomi`——那**一个**
      //       标识符，翻译层拒收、旧解析器读不懂。见 [unitInsertionText] 上的长注释。
      // English: **the sheet hands over bare tokens and the separators are decided here (the only
      //          place).** The real keypad flow is a run of adjacent insertions (`5` → `km` → `to` →
      //          `mi`) and without separators they glue into `5kmtomi` — **one** identifier, refused by
      //          the translation and unreadable by the legacy parser. See the long note on
      //          [unitInsertionText].
      builder: (sheetContext) => UnitPickerSheet(
        onInsert: (token) =>
            _controller.input(unitInsertionText(token, _controller.expression)),
      ),
    );
  }

  /// 中文：`X` 打开的面板。与 `CONV` 那个同一种做法：插入走控制器的 `input`（与键盘同一个入口，
  ///       所以光标位置、撤销栈、边打边算全都照旧），读数与按钮的可用态跟着控制器走
  ///       （`AnimatedBuilder` 的 `animation` 就是控制器，与 `More...` 面板一样），于是「存入当前值」
  ///       按下去之后那一行在原地变成 `= 4`，不需要关掉重开。
  ///
  ///       面板**不自动关闭**：插 `x` 与存值各是一下，两次都要用。关它的方式是点面板外、按返回键，
  ///       或者点面板里的「关闭」。
  ///
  /// English: the sheet `X` opens. Same shape as the `CONV` one: insertion goes through the controller's
  ///          `input` (the same entrance the keypad uses, so cursor position, the undo stack and
  ///          as-you-type evaluation all behave as before), and the readings and button availability
  ///          follow the controller (the `AnimatedBuilder`'s animation is the controller, exactly as in
  ///          the `More...` sheet), so pressing "store current value" turns that row into `= 4` in
  ///          place with no need to close and reopen.
  ///
  ///          The sheet **does not close itself**: inserting `x` and storing a value are two separate
  ///          presses and both are wanted. Tapping outside, the back button, or the sheet's own "关闭"
  ///          closes it.
  void _openVariableSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight:
            MediaQuery.sizeOf(context).height * _CalculatorPageState._moreSheetHeightRatio,
      ),
      builder: (sheetContext) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => VariablePickerSheet(
          readings: <VariableReading>[
            for (final String name in kBindableVariableNames)
              VariableReading(
                name: name,
                value: _controller.variableValue(name),
              ),
          ],
          storableValue: _controller.storableVariableValue,
          onInsert: _controller.append,
          onAssign: _controller.assignVariable,
          onClear: _controller.clearVariable,
          onClose: () => Navigator.of(sheetContext).pop(),
        ),
      ),
    );
  }

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
        maxHeight: MediaQuery.sizeOf(context).height * _CalculatorPageState._moreSheetHeightRatio,
      ),
      builder: (sheetContext) => _ComplexSheet(page: this, theme: theme),
    );
  }

  /// 中文：`STAT` 打开的统计面板。形状与上面那个一样（面板交记号、插入走 `_pressKey`），插入的是
  ///       **完整**的引擎调用：这几个函数都吃一串数，而**键盘上没有逗号键**，所以 `mean(` 这种前缀
  ///       在键盘上永远补不完——与 `Σ`/`Π`/`∫dx`/`logₓy` 那几颗键同一条理由。
  ///
  ///       **这一轮没有做「统计编辑器」。** HiPER 的 `STAT` 背后是一台能存数据集、能算回归、能画
  ///       散点的编辑器，而那样一个东西必须有一个**参与撤销/重做、落盘与代际守卫**的存放处
  ///       （变量那一轮否掉引擎自己的变量表，正是这条理由）。这一轮只做**入口**：把完整的统计调用
  ///       送进表达式。数据集就是表达式里那串实参——它已经在撤销栈、落盘与代际守卫里了，用户可以在
  ///       内联编辑器里直接改（那里打得进逗号）。
  /// English: the statistics sheet `STAT` opens. Same shape as the one above (the sheet hands over
  ///          tokens, insertion travels `_pressKey`), and what it inserts is a **complete** engine
  ///          call: these functions each take a run of numbers and **the keypad has no comma key**, so
  ///          a prefix like `mean(` can never be completed from the keypad — the same reason as the
  ///          `Σ`/`Π`/`∫dx`/`logₓy` keys.
  ///
  ///          **This round does not build the "statistics editor".** Behind HiPER's `STAT` sits an
  ///          editor that stores a dataset, computes regressions and draws scatter plots, and such a
  ///          thing needs a home that takes part in **undo/redo, persistence and the generation
  ///          guard** (the reason the variables round rejected the engine's own variable table). This
  ///          round builds the **entrance** only: it delivers a complete statistics call into the
  ///          expression. The dataset is the argument list written in that expression — already inside
  ///          the undo stack, the persisted state and the generation guard — and the user edits it in
  ///          the inline editor, which does accept commas.
  void _openStatisticsSheet() {
    final theme = CalcTheme.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * _CalculatorPageState._moreSheetHeightRatio,
      ),
      builder: (sheetContext) => _StatisticsSheet(page: this, theme: theme),
    );
  }

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
        maxHeight: MediaQuery.sizeOf(context).height * _CalculatorPageState._moreSheetHeightRatio,
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

  Future<void> _copyResult() async {
    try {
      await Clipboard.setData(ClipboardData(text: _controller.copyText()));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已复制计算详情')));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('无法复制计算详情')));
      }
    }
  }

  Future<void> _pasteCalculatorDetails() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (!mounted) return;
      final paste = _controller.applyPastedText(data?.text ?? '');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(paste.summary)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('无法读取剪贴板')));
      }
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pastingCalculatorDetails = false;
      });
    }
  }

  void _beginCalculatorDetailsPaste() {
    _pastingCalculatorDetails = true;
  }

  void _endCalculatorDetailsPasteGesture() {
    _pastingCalculatorDetails = false;
  }

  Future<void> _saveNote() async {
    // 中文：保存笔记是异步数据库写入，页面退出后不能再使用旧 context 弹提示。
    // English: Saving notes writes to SQLite asynchronously; after navigation, the old context must not show feedback.
    if (_savingNote) return;
    if (!_controller.canSaveCurrentExpression) {
      _showCurrentStatusSnack();
      return;
    }
    _savingNote = true;
    try {
      final result = await _controller.saveToNote();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.message)));
    } finally {
      _savingNote = false;
    }
  }

  void _showCurrentStatusSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_controller.resultStatusMessage)),
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
    'cot', 'sec', 'csc', 'log₂', 'exp',
    'floor', 'ceil', 'round', 'min', 'max',
    'gcd', 'lcm', 'atan2',
    'deg', 'rad', '90°', '180°', '360°',
    '2ˣ', 'φ', '√2', 'τ', 'ln2', 'ln10', 'g', 'c', '2π', 'π/2',
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

/// 中文：`STAT` 面板的内容——**统计入口**。同样只列记号，按下去交给本页的 `_pressKey`。
///
///       每一格派发的是一个 `ins:` id，主屏把它变成**一整个调用**（`mean(1,2,3,4)`）追加进表达式。
///       那串实参是一份**起手数据**，不是算出来的值：它与 `Σ`/`Π`/`∫dx` 那几颗键插进去的
///       `sum(x,1,10,x)` 是同一类东西——按下去立刻求得出一个数，同时把引擎的实参顺序摆在屏幕上，
///       用户在内联编辑器里照着改成自己那串数（那里打得进逗号）。
///
///       **这一轮没有数据集编辑器**：没有表格、没有增删行、没有回归、没有散点。数据集活在表达式里
///       （因此撤销、落盘、代际守卫全都已经盖着它），而不是活在一个新的存放处。这是有意的取舍：
///       一个真正存数据集的编辑器需要一个参与那三样的存放处，那是下一轮的事，这一轮不半做。
/// English: the contents of the `STAT` sheet — the **statistics entrance**. It likewise lists tokens
///          only and hands a press to this page's `_pressKey`.
///
///          Each cell dispatches an `ins:` id that the screen turns into **a whole call**
///          (`mean(1,2,3,4)`) appended to the expression. That argument list is a **starting sample**,
///          not a computed value: it is the same kind of thing as the `sum(x,1,10,x)` the `Σ`/`Π`/`∫dx`
///          keys insert — one press yields a number immediately, and it puts the engine's argument
///          order on screen so the user can edit it into their own run of numbers in the inline
///          editor, which accepts commas.
///
///          **There is no dataset editor this round**: no table, no add/remove row, no regression, no
///          scatter plot. The dataset lives in the expression (so undo, persistence and the generation
///          guard already cover it) rather than in a new home. That is a deliberate trade: an editor
///          that really stores a dataset needs a home taking part in those three, which is the next
///          round's work — this round does not half-build it.
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
            // 中文：把「插进去的那串数是什么」与「它怎么改」讲清楚。没有这句话，屏幕上会凭空多出
            //       一串用户没打过的数字，而那看起来像一个错值。
            // English: spell out what the inserted run of numbers is and how to change it. Without
            //          this line a run of digits the user never typed appears from nowhere, which
            //          reads as a wrong value.
            Text(
              '插入的是完整调用，实参是一份起手数据；'
              '括号里的数在内联编辑器里改成你自己的（逗号可以打）。',
              style: TextStyle(color: theme.display.statusFg, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// 中文：`More...` 面板的内容。它直接驱动本页的控制器——面板是本页私有的 UI，把十几个回调逐个传进来
///       只会更难读，所以它拿页面状态本体。一次性动作（复制、保存、编辑、退格、撤销/重做、光标移动）
///       先关面板再执行；四个记忆寄存器按钮**不关面板**，这样记忆读数能在原地跟着更新。
/// English: The contents of the `More...` sheet. It drives the page's controller directly: the sheet is
///          page-private UI, and threading a dozen callbacks through would hurt readability more than
///          passing the state it belongs to. One-shot actions (copy, save, edit, backspace,
///          undo/redo, cursor moves) close the sheet first; the four memory-register buttons **keep
///          it open** so the memory reading updates in place.
class _MoreSheet extends StatelessWidget {
  const _MoreSheet({required this.page, required this.theme});

  final _CalculatorPageState page;
  final CalcTheme theme;

  @override
  Widget build(BuildContext context) {
    final controller = page._controller;
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
                _action(context, '编辑表达式', page._editFromSheet),
                _action(context, '退格', controller.backspace),
                _action(context, '撤销', controller.undo,
                    enabled: controller.canUndo),
                _action(context, '重做', controller.redo,
                    enabled: controller.canRedo),
                _action(context, '复制结果', page._copyResult),
                // 中文：继续使用。它把结果**替换**成表达式（`ans` 是追加，两者不等价），而显示区在结果
                //       可用时会写着「结果可继续使用」/「当前值可继续使用」——那句话必须有对应的入口，
                //       否则 UI 在让用户做一件它不再提供的事。不可用时和撤销/重做一样置灰。
                // English: continue-with-result. It **replaces** the expression with the result (`ans`
                //          appends, so the two are not equivalent), and the display says "结果可继续使用"
                //          / "当前值可继续使用" whenever it is available — that sentence needs an entry
                //          point, or the UI asks for something it no longer offers. Greyed out when
                //          unavailable, like undo/redo.
                _action(context, '继续使用', controller.continueWithResult,
                    enabled: controller.canContinueWithResult),
                _action(context, '保存笔记', page._saveNote),
                _action(context, '移到开头', controller.moveCursorToStart),
                _action(context, '移到末尾', controller.moveCursorToEnd),
                // 中文：设置入口。它原本长在被删掉的应用名标题行上，而抽屉（Task 5）才是导航的主入口；
                //       这里保留一个次级入口，是因为没有它整台应用的设置页在主屏上就完全不可达了。
                // English: The settings entry. It used to live on the deleted app-name title row, and the
                //          drawer (Task 5) is the primary navigation; this secondary entry is kept because
                //          without it the settings page would be unreachable from the main screen at all.
                _action(context, '设置', page.widget.onOpenSettings),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                page._repeatableCursorButton(
                  theme: theme,
                  icon: Icons.keyboard_arrow_left,
                  tooltip: '光标左移（长按按表达式块左移后连续移动）',
                  onTap: controller.moveCursorLeft,
                  onBlockMove: controller.moveCursorByBlockBackward,
                  onRepeat: controller.moveCursorLeft,
                ),
                const SizedBox(width: 6),
                page._repeatableCursorButton(
                  theme: theme,
                  icon: Icons.keyboard_arrow_right,
                  tooltip: '光标右移（长按按表达式块右移后连续移动）',
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
                _memoryButton('MR', controller.memoryRecall),
                _memoryButton('MC', controller.memoryClear),
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

  /// 中文：记忆寄存器按钮——不关面板，读数就在旁边的同一行里跟着变。
  /// English: A memory-register button — it keeps the sheet open so the reading beside it updates.
  Widget _memoryButton(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: OutlinedButton(
        onPressed: () {
          page._feedback();
          onTap();
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

class _RepeatableCursorButton extends StatefulWidget {
  const _RepeatableCursorButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.backgroundColor,
    required this.borderColor,
    required this.onTap,
    required this.onBlockMove,
    required this.onRepeat,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final Color backgroundColor;
  final Color borderColor;
  final VoidCallback onTap;
  final VoidCallback onBlockMove;
  final VoidCallback onRepeat;

  @override
  State<_RepeatableCursorButton> createState() =>
      _RepeatableCursorButtonState();
}

class _RepeatableCursorButtonState extends State<_RepeatableCursorButton> {
  static const _repeatInterval = Duration(milliseconds: 80);
  Timer? _repeatTimer;

  void _startRepeat(LongPressStartDetails details) {
    widget.onBlockMove();
    _repeatTimer ??= Timer.periodic(_repeatInterval, (_) => widget.onRepeat());
  }

  void _stopRepeat() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  @override
  void dispose() {
    _stopRepeat();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.tooltip,
      onLongPress: widget.onBlockMove,
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onLongPressStart: _startRepeat,
          onLongPressEnd: (_) => _stopRepeat(),
          onLongPressCancel: _stopRepeat,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: widget.borderColor),
            ),
            child: Icon(widget.icon, size: 17, color: widget.color),
          ),
        ),
      ),
    );
  }
}
