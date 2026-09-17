import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../application/app_settings.dart';
import '../../../application/controllers/calculator_controller.dart';
import '../../../application/controllers/expression_selection.dart';
import '../../../core/math/variable_references.dart';
import '../../../core/platform/app_haptics.dart';
import '../../../core/utils/number_formatter.dart';
import '../../../data/local/app_database.dart';
import '../../../data/repositories/history_repository.dart';
import '../../../data/repositories/notes_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../shared/presentation/calc_theme.dart';
import 'keypad/calculator_keypad.dart';
import 'keypad/hiper_keypad.dart';
import 'result_form.dart';
import 'widgets/calculator_display.dart';
import 'widgets/inline_expression_editor.dart';
import 'widgets/unit_picker_sheet.dart';
import 'widgets/variable_picker_sheet.dart';

part 'calculator_key_dispatch.dart';
part 'calculator_page_sheets.dart';
part 'calculator_page_repeat_button.dart';

/// 中文：计算器主界面——上半是两行显示面板（`CalculatorDisplay`），下半是 HiPER 键位表渲染出的
///       键盘（`CalculatorKeypad`），**不滚动**。UI 只负责布局和输入分发，计算逻辑留在
///       CalculatorController，主题配色全部取自 `CalcTheme`。
/// English: The calculator main screen — a two-line display panel (`CalculatorDisplay`) above a
///          keypad rendered from the HiPER key table (`CalculatorKeypad`), with **no scrolling**.
///          The UI only lays out and dispatches input; calculation stays in CalculatorController and
///          every colour comes from `CalcTheme`.
class CalculatorPage extends StatefulWidget {
  const CalculatorPage({
    required this.db,
    required this.onOpenSettings,
    required this.settings,
    this.reloadToken = 0,
    this.onNavigate,
    super.key,
  });

  final AppDatabase db;
  final VoidCallback onOpenSettings;
  final AppSettings settings;
  final int reloadToken;

  /// 中文：页面级导航（`HISTORY`、`OTHER`、`CNST`、`CONV` 与四个进制胶囊）。可选——为空时这些键
  ///       是惰性的，独立使用本页（例如组件测试）不会虚构出目标页；外壳接入后传 'history'/'tools'。
  /// English: Page-level navigation (the `HISTORY`, `OTHER`, `CNST`, `CONV` keys and the four base
  ///          pills). Optional — with no callback those keys are inert and no destination is invented
  ///          for standalone use (widget tests included); the shell passes 'history'/'tools' once it
  ///          is wired.
  final void Function(String destination)? onNavigate;

  /// 中文：本页 `_pressKey` **显式**派发的动作 id 集合——即它全部 `case` 标签去重后的并集。
  ///       它与下面的 `defaultInputKeyIds` 合起来必须覆盖 `hiper_keypad.dart` 里每一个已启用的
  ///       id：这正是本计划那句「改键位表，别的地方不用动」的可测形式，
  ///       `test/features/keypad_definition_test.dart` 逐格走表守住它，主屏也有一条逐格派发的
  ///       行为测试。改 `_pressKey` 的 case 时务必同步改这里，否则两条测试都会红。
  /// English: The action ids this page's `_pressKey` dispatches **explicitly** — the deduplicated union
  ///          of its `case` labels. Together with `defaultInputKeyIds` below it must cover every enabled
  ///          id `hiper_keypad.dart` can produce: that is the testable form of this plan's "edit the key
  ///          table, change nothing else", guarded cell by cell by
  ///          `test/features/keypad_definition_test.dart` and by a dispatch-per-id behaviour test on the
  ///          screen itself. Adding or removing a `case` in `_pressKey` means updating this set too, or
  ///          both tests go red.
  static const Set<String> dispatchedKeyIds = <String>{
    // 修饰键 / 页面级动作
    'shift', 'hyp', 'drawer', 'openHistory', 'openTools',
    'openConstants', 'openUnits', 'openVariables',
    // 中文：`CPLX` 与 `STAT` 两颗键各自打开的面板（本轮点亮的那两颗）。面板插入的记号仍走主屏这
    //       一条通路：`conj`/`arg`/`re`/`im` 是下面的**一元函数** id，`mean`/`median`/`stdev`/`var`
    //       由面板直接拼成完整调用交给控制器——所以「面板里有什么」与「主屏接得住什么」是同一套
    //       词汇，没有第二份映射（`_MoreFunctionsSheet` 立的规矩）。
    // English: the sheets the `CPLX` and `STAT` keys each open (the two lit this round). What a sheet
    //          inserts still travels the screen's own path: `conj`/`arg`/`re`/`im` are the **unary
    //          function** ids below, and `mean`/`median`/`stdev`/`var` are assembled by the sheet into a
    //          complete call handed to the controller — so "what is in the sheet" and "what the screen
    //          accepts" are one vocabulary with no second mapping (the rule `_MoreFunctionsSheet` set).
    'openComplex', 'openStatistics',
    // 中文：`STAT` 面板插入的四个完整统计调用。它们与 `ins:sum`/`ins:product`/… 同属「插一整条引擎
    //       调用」那一类：这几个函数都要一串实参，而键盘上没有逗号键。
    // English: the four complete statistics calls the `STAT` sheet inserts. They belong with
    //          `ins:sum`/`ins:product`/… in the "insert a whole engine call" class: each takes a run of
    //          arguments and the keypad has no comma key.
    'ins:mean', 'ins:median', 'ins:stdev', 'ins:var',
    'baseDec', 'baseHex', 'baseBin', 'baseOct',
    // 结果行的形态：`x⇔E` 循环、`d/c` 在标准写法与十进制之间来回、`D°M'S` 在度分秒写法与
    // 原来那一行之间来回。三者都只改**显示**，结果行、`Ans`/`last`、记忆寄存器、继续使用与历史
    // 一个字都不动。
    'resultForm', 'fractionForm', 'dmsForm',
    // 编辑与结果
    'backspace', 'clear', 'equals', 'angleMode', 'negate', 'ans',
    // 中文：`◀` `▶` 两颗光标键（**不是翻页键**——来源见 `hiper_keypad.dart` 第 1 行那一段）。它们与
    //       `backspace` 同属「改光标/改表达式」那一类，走的是控制器已有的 `moveCursorLeft`/
    //       `moveCursorRight`，与 `More...` 面板里那两颗光标键同一个入口。
    // English: the two cursor keys `◀` `▶` (**not page keys** — the sources are in `hiper_keypad.dart`'s
    //          row-1 note). They sit with `backspace` in the "edit the caret / the expression" class and
    //          take the controller's existing `moveCursorLeft`/`moveCursorRight` — the same entrance the
    //          `More...` sheet's two cursor keys use.
    'cursorLeft', 'cursorRight',
    // 记忆寄存器
    'memoryRecall', 'memoryStore', 'memoryAdd', 'memorySubtract',
    // 插入文本（`ins:` 前缀）
    'ins:pi', 'ins:e', 'ins:^-1', 'ins:^2', 'ins:^3', 'ins:^', 'ins:10^',
    'ins:e^', 'ins:inf', 'ins:%', 'ins:exp', 'ins:rand',
    // 变量：`Y` 一下插入 `y`（`x` 从 `X` 打开的面板里插入，那颗键走 `openVariables`）。
    'ins:y',
    // 微积分与复现：Σ / Π / ∫dx / lim / logₓy——各自插一整条引擎调用，见下面 `_pressKey` 里的
    // 那一段注释（键盘上没有逗号键，半条调用补不完）。
    'ins:sum', 'ins:product', 'ins:integrate', 'ins:limit', 'ins:logxy',
    // 矩阵与虚数单位：`MTRX` 插一整条 `matrix(行, 列, 元素…)`（引擎实测 `[1  2; 3  4]`），
    // `i` 插引擎认识的虚数单位（`2i+1` 实测 `1 + 2i`）。
    'ins:matrix', 'ins:i',
    // 一元函数（含只从 `OTHER` 面板进来的那些）
    'sin', 'cos', 'tan', 'asin', 'acos', 'atan', 'sinh', 'cosh', 'tanh',
    'cot', 'sec', 'csc', 'log₂', 'exp', 'floor', 'ceil', 'round',
    'deg', 'rad', 'log', 'ln', 'abs', 'sqrt', 'cbrt', 'fact',
    // 中文：复数面板插的那四个一元函数（`CPLX`）。它们没有键、也不在 `OTHER` 面板里，只能从
    //       `CPLX` 的面板进来——所以它们**必须**在这里，否则键位覆盖率那条测试会红（它只走键位表，
    //       而这几颗不在表里）。放在这一组是因为它们走的就是一元函数那一条 `case`。
    // English: the four unary functions the complex sheet inserts (`CPLX`). They have no key and are
    //          not in the `OTHER` sheet, so the `CPLX` sheet is their only entrance — which is why
    //          they **have to** be listed here or the key-coverage test goes red (it walks the key
    //          table, and these are not in it). They sit in this group because they take that group's
    //          unary-function `case`.
    'arg', 'conj', 're', 'im',
    // 二元函数
    'mod', 'nCr', 'nPr', 'root', 'min', 'max', 'gcd', 'lcm', 'atan2',
    // 只从 `OTHER` 面板进来的常数与角度快捷值
    '2ˣ', '90°', '180°', '360°', 'φ', '√2', 'τ', 'ln2', 'ln10', 'g', 'c',
    '2π', 'π/2',
    // `×`/`÷` 的 id 是给解析器用的 ASCII，键面仍是 `×`/`÷`
    '*', '/',
  };

  /// 中文：`default` 分支**按字面量**输入的 id——数字、小数点、括号与加减。它们不是「没接住的
  ///       键」，而是刻意走 `CalculatorController.input`（它认得这些 token 并处理小数、括号与
  ///       折叠尾随运算符）。这个集合是那批 id 的唯一定义处，覆盖测试与派发测试都读它。
  /// English: The ids the `default` branch types **verbatim** — digits, the decimal point, brackets and
  ///          the plus and minus signs. These are not unwired keys: routing them through
  ///          `CalculatorController.input` is deliberate (it knows those tokens and handles decimals,
  ///          brackets and collapsing a trailing operator). This set is the one place defining that
  ///          batch; the coverage test and the dispatch test both read it.
  static const Set<String> defaultInputKeyIds = <String>{
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
    '.', '(', ')', '+', '-',
  };

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  /// 中文：内联编辑器的字号，与 `CalculatorDisplay` 表达式行的字号一致。
  /// English: The inline editor's font size, matching `CalculatorDisplay`'s expression line.
  static const double _inlineEditorFontSize = 19;

  /// 中文：显示区最多占可用高度的比例，以及它的高度上下限（下限见 `build` 里的注释）。
  /// English: The display band's share of the available height and its bounds (see `build`).
  static const double _displayHeightRatio = 0.38;
  static const double _displayHeightMin = 176;
  static const double _displayHeightMax = 230;

  /// 中文：`More...` 面板最多占屏幕高度的比例——够放下全部动作，又不会盖住显示区。
  /// English: How much of the screen the `More...` sheet may take — room for every action without
  ///          covering the display band.
  static const double _moreSheetHeightRatio = 0.7;

  /// 中文：`More...` 面板里光标键描边的透明度。
  /// English: Alpha of the cursor keys' border inside the `More...` sheet.
  static const double _cursorBorderAlpha = 0.3;

  late final CalculatorController _controller;
  bool _savingNote = false;

  /// 中文：**结果行画哪几种形态里的哪一种**（HiPER 的 `x⇔E` / `d/c` 管的那一维）。它只活在这一页
  ///       的状态里，与结果本身无关，所以：
  ///
  ///       - **不落盘、不进 `MathResult`**：它不是一个值，是「这一个值用哪种写法印出来」。进了结果
  ///         类型就会被别的消费者当成值读走，而这件事与值无关。
  ///       - **一页一份，`clear()` 不重置、编辑也不重置**：HiPER 上它是一个模式，换一道算式它还在。
  ///         这不构成任何风险——形态每一帧都要拿这一份**当前结果**重新解析一遍
  ///         （[ResultPresentation.resolve]），这一份结果没有的那一种一律回落到 `auto`，所以一个
  ///         留下来的模式绝不可能把新结果的某一段画成空白或画成另一个数。
  /// English: **which of the result line's forms is drawn** (the dimension HiPER's `x⇔E` / `d/c`
  ///          own). It lives in this page's state and belongs to nothing else, because:
  ///
  ///          - **it is not persisted and does not go into `MathResult`**: it is not a value, it is
  ///            "which spelling this one value is printed in". Inside the result type other consumers
  ///            would read it as a value, and it has nothing to do with the value.
  ///          - **one per page, reset by neither `clear()` nor an edit**: on HiPER it is a mode, and
  ///            it survives the next sum. That carries no risk — the form is re-resolved against
  ///            **the current result** on every single frame ([ResultPresentation.resolve]) and any
  ///            form that result does not have falls back to `auto`, so a surviving mode can never
  ///            draw part of a new result blank or draw a different number.
  ResultForm _resultForm = ResultForm.auto;
  bool _inlineEditing = false;
  bool _requestInlineFocus = false;
  bool _pastingCalculatorDetails = false;

  /// 中文：当前修饰态。`KeypadModifier` 一个值就同时表达了「SHIFT 还是 hyp」与「互斥」，
  ///       所以旧计划里另立一个 `bool _hypActive` 是多余的——两个字段表达同一事实只会走岔。
  /// English: The active modifier. One `KeypadModifier` value already carries both "SHIFT or hyp"
  ///          and their mutual exclusion, so a second `bool _hypActive` (as the plan sketched) would
  ///          duplicate the same fact and could only drift from it.
  KeypadModifier _modifier = KeypadModifier.none;

  @override
  void initState() {
    super.initState();
    _controller = CalculatorController(
      historyRepository: HistoryRepository(widget.db),
      notesRepository: NotesRepository(widget.db),
      settingsRepository: SettingsRepository(widget.db),
      settings: widget.settings,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.restoreIfEnabled();
    });
  }

  @override
  void didUpdateWidget(covariant CalculatorPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) {
      _controller.updateSettings(widget.settings);
    }
    if (oldWidget.reloadToken != widget.reloadToken) {
      _controller.reloadSettingsAndRestore();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = CalcTheme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // 中文：显示区固定取可用高度的 38%，clamp 在 176–230dp。176dp 是 `CalculatorDisplay`
        //       的高度下限（它的类注释按真实 Android 字体度量推导出：与字体无关的固定行 74dp，
        //       双行错误的内容约需 165dp），230dp 让高窗口下显示区不至于吃掉键盘。剩下的高度全给
        //       键盘：`Expanded` 填满、不给固定高度，于是任何窗口高度都不会溢出（键变矮而已）。
        // English: The display band takes 38% of the available height, clamped to 176–230dp. 176dp
        //          is `CalculatorDisplay`'s floor (its class comment derives 74dp of font-independent
        //          chrome plus ≈165dp of content for a two-line error under real Android metrics) and
        //          230dp stops it eating the keypad on tall windows. Everything left goes to the
        //          keypad, which fills it via `Expanded` with no fixed height, so no window height
        //          can overflow — the keys just get shorter.
        final displayHeight = (constraints.maxHeight * _displayHeightRatio)
            .clamp(_displayHeightMin, _displayHeightMax);
        return Column(
          children: [
            SizedBox(
              height: displayHeight,
              // 中文：只让依赖控制器状态的显示区重建，键盘本体不随每次输入重建。
              // English: Rebuild only the controller-dependent display band; the keypad itself does
              //          not rebuild on every input.
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) =>
                    _inlineEditing ? _editingSurface(theme) : _display(theme),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: CalculatorKeypad(
                // 中文：`modifierActive` 不传——`CalculatorKeypad` 由 `modifier` 自行推导，
                //       漏传也不会丢掉「修饰键已锁定」的提示。`shift`/`hyp` 两个键也走 `onKey`
                //       （键盘组件不认识任何 id），由这里的 `_pressKey` 切换修饰态。
                // English: `modifierActive` is omitted — `CalculatorKeypad` derives it from
                //          `modifier`, so the latched-modifier signal cannot be lost. The `shift`/`hyp`
                //          keys travel `onKey` too (the keypad widget knows no ids); `_pressKey` here
                //          flips the modifier.
                definition: hiperKeypad,
                modifier: _modifier,
                colors: theme.keys,
                background: theme.keypadBackground,
                onKey: _pressKey,
              ),
            ),
          ],
        );
      },
    );
  }

  /// 中文：两行显示面板。点表达式里的某个单元会在该单元的原文偏移处打开内联编辑器（用户原有的
  ///       编辑功能，保留）；`More...` 打开动作面板，☰ 打开外壳的抽屉。
  /// English: The two-line display panel. Tapping a display unit opens the inline editor at that
  ///          unit's source offset (the user's editing feature, preserved); `More...` opens the
  ///          action sheet and ☰ opens the shell's drawer.
  Widget _display(CalcTheme theme) {
    return CalculatorDisplay(
      expression: _controller.expression,
      result: _controller.result,
      // 中文：精确形式与十进制读数一起下去——结果行只在「精确形式排得出来、又不是同一个数的
      //       另一种写法」时才排版它，见 `CalculatorDisplay` 的两种形态。
      // English: The exact form travels down with the decimal reading — the result line typesets it
      //          only when it renders and is not the same number written differently; see the two
      //          shapes in `CalculatorDisplay`.
      resultTex: _controller.resultTex,
      resultFractionTex: _controller.resultFractionTex,
      // 中文：度分秒写法（引擎那一串原文，`D°M'S` 那一颗键要的东西）。空串表示这一次没有，
      //       那一颗键于是是空操作——与 `d/c` 同一条路。
      // English: the DMS spelling (the engine's own string — what the `D°M'S` key needs). An empty
      //          string means there is none this time and that key is a no-op, exactly as with `d/c`.
      resultDmsText: _controller.resultDmsText,
      // 中文：请求的形态（`x⇔E` / `d/c` 按出来的那一个）。`CalculatorDisplay` 拿它对照这一份结果
      //       真正有的形态，没有的回落 `auto`——判断那一处只有一份，在 `ResultPresentation`。
      // English: the requested form (what `x⇔E` / `d/c` pressed). `CalculatorDisplay` resolves it
      //          against the forms this result really has and falls back to `auto`; that judgement
      //          exists in exactly one place, `ResultPresentation`.
      resultForm: _resultForm,
      resultDecimal: _controller.resultDecimal,
      // 中文：进制读数（四个进制胶囊按出来的那一个）。它由控制器决定此刻还成不成立——代际或来源
      //       十进制形态对不上时控制器给的就是空串，所以这里不必再判一次。
      // English: the base read-out (what the four base pills produce). The controller decides whether
      //          it still holds — when the generation or the source decimal no longer matches it hands
      //          back an empty string, so there is no second judgement to make here.
      baseReadout: _controller.baseReadout?.label ?? '',
      hasError: _controller.hasError,
      statusTitle: _controller.resultStatusTitle,
      statusMessage: _controller.resultStatusMessage,
      cursorIndex: _controller.cursorIndex,
      angleMode: _controller.angleMode,
      hasMemory: _controller.memoryValue != 0,
      colors: theme.display,
      naturalDisplay: widget.settings.expressionDisplayMode == '数学符号',
      onTapOffset: (sourceOffset) =>
          _openInlineEditor(sourceOffset: sourceOffset),
      onMore: _openMoreSheet,
      onOpenDrawer: _openDrawer,
    );
  }

  /// 中文：内联编辑时的显示区。用户的编辑器组件占满整块区域，底色与内边距沿用显示面板的配色，
  ///       键盘仍然可见可点——按键写入编辑器里的选区，这正是这套编辑交互的核心。
  /// English: The display band while inline editing. The user's editor widget fills the band on the
  ///          display panel's own background and padding, and the keypad stays visible and tappable:
  ///          its keys write into the editor's selection, which is the whole point of this editing
  ///          interaction.
  Widget _editingSurface(CalcTheme theme) {
    return Container(
      color: theme.display.background,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      alignment: Alignment.center,
      child: InlineExpressionEditor(
        expression: _controller.expression,
        selection: _controller.selection,
        onExpressionChanged: _controller.setExpression,
        onSelectionChanged: _controller.setSelection,
        onFocusLost: _closeInlineEditor,
        onPastePointerDown: _beginCalculatorDetailsPaste,
        onPasteGestureEnded: _endCalculatorDetailsPasteGesture,
        onPasteCalculatorDetails: _pasteCalculatorDetails,
        requestFocus: _requestInlineFocus,
        style: TextStyle(
          color: theme.display.expressionFg,
          fontSize: _inlineEditorFontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// 中文：SHIFT 与 hyp 互斥（它们是同一个字段的两个值），再点一次各自的键退出该修饰态。
  /// English: SHIFT and hyp are mutually exclusive (two values of one field); tapping a latched
  ///          modifier key again leaves that state.
  void _toggleShift() {
    _feedback();
    setState(() {
      _modifier = _modifier == KeypadModifier.shift
          ? KeypadModifier.none
          : KeypadModifier.shift;
    });
  }

  void _toggleHyp() {
    _feedback();
    setState(() {
      _modifier = _modifier == KeypadModifier.hyp
          ? KeypadModifier.none
          : KeypadModifier.hyp;
    });
  }

  /// 中文：SHIFT 是一次性修饰态——任何一次按键之后就复位（HiPER 行为）；hyp 是持续态，只能由
  ///       hyp 键退出，所以不在这里复位。
  /// English: SHIFT is one-shot: it clears after any key press (HiPER's behaviour). hyp latches and
  ///          can only be left by the hyp key, so it is not cleared here.
  void _clearOneShotShift() {
    if (_modifier != KeypadModifier.shift) return;
    setState(() => _modifier = KeypadModifier.none);
  }
  void _feedback() {
    AppHaptics.tap(
      enabled: widget.settings.haptics,
      strength: widget.settings.hapticStrength,
    );
  }

  /// 中文：`x⇔E` / `d/c` 两颗键换形态走的那一条。**先 `resolve` 再存**：这一份结果画不出来的形态
  ///       一律落回 [ResultForm.auto]，所以留下来的状态永远是「这一份结果真的画得出来的一种」，
  ///       下一份结果上来时也不会把某一段画成空白。没有变化时**不** `setState`——两颗键在一份只有
  ///       一种画法的结果上（`2+2`）是空操作，不该白白重建一次。
  /// English: the one path the `x⇔E` / `d/c` keys take to switch form. **Resolve first, then store**:
  ///          a form this result cannot draw falls back to [ResultForm.auto], so the stored state is
  ///          always "one this result really can draw" and cannot leave a stretch blank when the next
  ///          result arrives. Nothing is rebuilt when nothing changed — on a result with a single
  ///          drawing (`2+2`) both keys are no-ops and must not force a rebuild for nothing.
  void _setResultForm(ResultForm form) {
    final resolved = _resultPresentation.resolve(form);
    if (resolved == _resultForm) return;
    setState(() => _resultForm = resolved);
  }
  void _openInlineEditor({bool requestFocus = false, int? sourceOffset}) {
    if (sourceOffset != null) {
      _controller.setSelection(ExpressionSelection.collapsed(sourceOffset));
    }
    setState(() {
      _inlineEditing = true;
      _requestInlineFocus = requestFocus;
    });
  }

  void _closeInlineEditor() {
    if (!mounted || !_inlineEditing || _pastingCalculatorDetails) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_inlineEditing || _pastingCalculatorDetails) return;
      setState(() {
        _inlineEditing = false;
        _requestInlineFocus = false;
      });
    });
  }
}
