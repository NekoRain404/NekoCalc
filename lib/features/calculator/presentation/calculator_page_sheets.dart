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
      borderColor: theme.display.statusFg
          .withValues(alpha: _CalculatorPageState._cursorBorderAlpha),
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
        maxHeight: MediaQuery.sizeOf(context).height *
            _CalculatorPageState._moreSheetHeightRatio,
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
        maxHeight: MediaQuery.sizeOf(context).height *
            _CalculatorPageState._moreSheetHeightRatio,
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
  /// 中文：**`x⇔E` 打开的结果格式菜单**——HiPER 的 "Select Result Format"（`rfMenu.title`）。
  ///       面板本身在 `widgets/result_format_sheet.dart`，七项的名字与来源都在那里。
  ///
  ///       **为什么是面板而不是循环**：厂商自己的两句话都写的是「选一个」——
  ///       FAQ 的 "press the `x⇔E` key. **It opens the Select Result Format menu**" 与手册 v12.0 的
  ///       "press `x⇔E` and **choose** one of the following formats"。本应用从前画成三档循环，是因为
  ///       那六格当时只有三格印得出来；现在五格印得出来（多出带分数那一格），循环这个形状既不是
  ///       来源说的、又每次都要按着走一遍，菜单才是原来那个东西。
  ///
  ///       **换的只是「怎么选」，不是「选什么」**：选完仍然落到同一个 `_setResultForm`，也就是同一处
  ///       `ResultPresentation.resolve`，值路径一个字节都不动——`Ans`/`last`、记忆、继续使用、历史与
  ///       提交路径读的都还是 `MathResult.decimalText`。
  ///
  ///       **判据不在这里**：哪一项点得动、哪一项是当前，都由 `ResultPresentation`（`canDraw` /
  ///       `resolve`）回答，面板只把它们画出来。这一份 `ResultPresentation` 与结果行那份是**同一个
  ///       工厂**（`_resultPresentation`），所以面板里灰掉的东西与结果行画得出来的东西不可能漂开。
  ///
  ///       **面板自己关自己**（选一项就关）：这是一次「选一个格式」的动作，不是 `CONV`/`X` 那种一次
  ///       要插好几样的面板。
  /// English: **the result format menu `x⇔E` opens** — HiPER's "Select Result Format"
  ///          (`rfMenu.title`). The sheet itself lives in `widgets/result_format_sheet.dart`, with the
  ///          seven entries' names and sources.
  ///
  ///          **Why a sheet and not a cycle**: both of the vendor's own sentences say "choose" — the
  ///          FAQ's "press the `x⇔E` key. **It opens the Select Result Format menu**" and manual v12.0's
  ///          "press `x⇔E` and **choose** one of the following formats". This app drew a three-stop
  ///          cycle because only three of those six cells could be printed then; five can be printed
  ///          now (the mixed-number cell joined), and a cycle is neither the shape the sources describe
  ///          nor pleasant to walk every time — the menu is the thing that was there.
  ///
  ///          **What changes is how you choose, not what you choose**: a pick still lands on the same
  ///          `_setResultForm`, i.e. the same single `ResultPresentation.resolve`, and the value path is
  ///          untouched — `Ans`/`last`, memory, continue-with, history and the submit path all still
  ///          read `MathResult.decimalText`.
  ///
  ///          **No judgement lives here**: which entry can be pressed and which one is current are
  ///          answered by `ResultPresentation` (`canDraw` / `resolve`); the sheet only draws them. The
  ///          presentation it uses is built by the **same factory** the result line uses
  ///          (`_resultPresentation`), so what is greyed in the sheet and what the result line can draw
  ///          cannot drift apart.
  ///
  ///          **The sheet closes itself** (one pick, one close): this is a "choose a format" action, not
  ///          a sheet like `CONV`/`X` where several things get inserted in a row.
  void _openResultFormatSheet() {
    final NavigatorState navigator = Navigator.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height *
            _CalculatorPageState._moreSheetHeightRatio,
      ),
      builder: (sheetContext) => ResultFormatSheet(
        // 中文：**同一个工厂**——结果行读的就是这一份（`_resultPresentation`），所以两边的判据是
        //       一份。`plainReading` 是结果行此刻那串纯文本读数，只用于预览的降级。
        // English: **the same factory** — this is what the result line reads
        //          (`_resultPresentation`), so both sides share one judgement. `plainReading` is the
        //          plain reading the result line is showing now, used only for preview fallback.
        presentation: _resultPresentation,
        current: _resultForm,
        plainReading: _controller.result,
        onPick: (form) {
          navigator.pop();
          _setResultForm(form);
        },
      ),
    );
  }

  void _openStatisticsSheet() {
    final theme = CalcTheme.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height *
            _CalculatorPageState._moreSheetHeightRatio,
      ),
      builder: (sheetContext) => _StatisticsSheet(page: this, theme: theme),
    );
  }

  Future<void> _copyResult() async {
    final strings = CalculatorStrings.of(context);
    try {
      await Clipboard.setData(ClipboardData(text: _controller.copyText()));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(strings.detailsCopied)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(strings.detailsCopyFailed)));
      }
    }
  }

  Future<void> _pasteCalculatorDetails() async {
    // 中文：**表在 await 之前取**——与那一行的 `SnackBar` 读的是同一份界面文案：粘贴回执跟着界面
    //       语言走（`paste.summaryIn`），中文界面下逐字节与从前那句相同。
    // English: **the table is taken before the await** — the same interface copy that `SnackBar` line
    //          reads: the paste receipt follows the interface language (`paste.summaryIn`), and under
    //          the Chinese interface it is byte-for-byte the sentence it was before.
    final strings = CalculatorStrings.of(context);
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (!mounted) return;
      final paste = _controller.applyPastedText(data?.text ?? '');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(paste.summaryIn(strings.pasteSummary))));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(CalculatorStrings.of(context).clipboardReadFailed)));
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

  // 中文：**这两个方法是搬过来的**（纯搬动，行为一个字符没改）：它们的调用点就在本文件的 `_MoreSheet`
  //       （面板里那两个记忆键），而且 `_reportMemoryFromSheet` 的注释本来就引用着这个文件里的 `_action`。
  // English: **the two methods below were moved here** (a pure move, not one character of behaviour
  //          changed): their call site is this file's own `_MoreSheet` (the sheet's two memory keys), and
  //          `_reportMemoryFromSheet`'s note already referred to `_action` in this file.
  /// 中文：记忆键被拒时，把控制器那句话交给用户。通道与 [_showBaseReadout]、以及提交路径的
  ///       `needsAttention` 是同一条（`SnackBar`），因为它们是同一类事情：用户按了一个键，而这一次
  ///       没成——不说，屏幕上就什么都没有，看起来像按键失灵。控制器回 `null` 时这里什么都不做
  ///       （成功是常态，不该有提示）。
  /// English: hand the controller's sentence to the user when a memory key is refused. Same channel as
  ///          [_showBaseReadout] and the submit path's `needsAttention` (a `SnackBar`), because they
  ///          are the same kind of event: the user pressed a key and this time it did not work —
  ///          unsaid, the screen shows nothing and reads as a dead key. A `null` from the controller
  ///          does nothing here (success is the normal case and deserves no prompt).
  void _reportMemory(String? message) {
    if (message == null || !mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// 中文：`More...` 面板里的那两个记忆键走这一条（`MR`/`MC` 不会拒绝，走的是同一条但永远无声）。
  ///       有话要说时**先把面板收掉**：面板盖着屏幕底部那一条，而消息落在右下角那条 `SnackBar`
  ///       上——量过（800×600 的测试面）：面板占 y=418..600、`SnackBar` 占 y=552..600，两者重叠，
  ///       被盖住的消息 `hitTestable()` 是 0。顶着面板说，用户根本看不见，那正是这一步要消灭的
  ///       「按了没反应」；这与同文件 `_action` 的理由是同一个形状（面板盖着键盘，所以动作先关面板）。
  ///       成功时面板原地留着——那正是面板自己的注释承诺的行为（读数原地更新）。
  /// English: the path the `More...` sheet's two refusing memory keys take (`MR`/`MC` cannot refuse;
  ///          they take it too and are simply never heard from). When there is something to say the
  ///          sheet is **dismissed first**: it covers the bottom strip of the screen while the message
  ///          lands on the `SnackBar` in that same strip — measured on the 800×600 test surface: the
  ///          sheet spans y=418..600 and the `SnackBar` y=552..600, they overlap, and a covered
  ///          message has `hitTestable()` 0. Speaking from behind the sheet means the user never sees
  ///          it, which is exactly the "pressed it, nothing happened" this step exists to delete; it
  ///          is the same shape as `_action`'s reason in this file (the sheet covers the keypad, so
  ///          the action closes it first). On success the sheet stays where it is — which is what the
  ///          sheet's own comment promises (the reading updates in place).
  void _reportMemoryFromSheet(String? message) {
    if (message == null) return;
    Navigator.of(context).pop();
    _reportMemory(message);
  }
}
