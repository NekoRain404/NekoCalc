import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../calculator_strings.dart';
import '../result_form.dart';

/// 中文：**结果格式菜单里的一项。**
///
///       [form] 为 `null` 表示**本应用给不出这一格**——今天的唯一一项是 `Polar coordinates`
///       （理由见 [resultFormatCells] 里那一项的注释与它上面的到期日断言）。用 `null` 而不是
///       给 `ResultForm` 添一个永远画不出来的枚举值：那种值会让每一处 `switch` 都多出一条**永远
///       走不到**的分支，而「本应用没有这一格」是一句关于**这一项**的话，不是关于那一维的话。
///
///       [label] 是 HiPER 自己的菜单项名字（`rfMenu.*` 的原文），一个字不改——本应用的键盘键名
///       （`x⇔E`、`d/c`、`D°M'S`）一向也是照抄原文的。
/// English: **one entry of the result format menu.**
///
///          A `null` [form] means **this app cannot offer that cell** — today the only one is
///          `Polar coordinates` (its reason is on that entry in [resultFormatCells], with the
///          expiry assertion above it). `null` rather than adding a `ResultForm` value that can never
///          be drawn: such a value would add a **never-reachable** branch to every `switch`, and "this
///          app has no such cell" is a statement about **one entry**, not about the dimension.
///
///          [label] is HiPER's own menu entry name (the `rfMenu.*` strings verbatim), unaltered — this
///          app's key titles (`x⇔E`, `d/c`, `D°M'S`) have always been copied from the source too.
@immutable
class ResultFormatCell {
  const ResultFormatCell({
    required this.label,
    required this.form,
    this.note = '',
  });

  final String label;
  final ResultForm? form;

  /// 中文：这一项下那一行小字——**本应用自己那一行与给不出的那一项**都靠它说实话。
  /// English: the small line under an entry — it is how **this app's own row** and **the entry it
  ///          cannot offer** both tell the truth.
  final String note;
}

/// 中文：**菜单的七项，按屏幕上的顺序。**
///
///       **前六项的来源是厂商自己的字符串表**（`/tmp/hiper_en.po`），顺序就是它们在文件里的顺序，
///       名字逐字照抄（只去掉 `<tabt:%0>` 那个预填占位符）：
///
///       | # | `msgctxt` | `msgid` |
///       |---|---|---|
///       | 1 | `rfMenu.decimal` | `Decimal <tabt:%0>` |
///       | 2 | `rfMenu.expression` | `Expression <tabt:%0>` |
///       | 3 | `rfMenu.fraction` | `Fraction <tabt:%0>` |
///       | 4 | `rfMenu.mixedNumber` | `Mixed number <tabt:%0>` |
///       | 5 | `rfMenu.dms` | `Degrees, mins, secs <tabt:%0>` |
///       | 6 | `rfMenu.polar` | `Polar coordinates <tabt:%0>` |
///
///       菜单标题是 `rfMenu.title` = **'Select Result Format'**。厂商站点自己的 FAQ 也这么叫它：
///       "To convert a result between the two forms, press the `x⇔E` key. **It opens the Select
///       Result Format menu**, where you choose `Polar coordinates` for the polar form, or `Decimal`
///       (or `Expression`) to get back to the rectangular form."；手册 v12.0 里是
///       "press `x⇔E` and **choose** one of the following formats"。**两句都写的是"选一个"，
///       没有一句说它是循环**——这就是本轮把 `x⇔E` 从循环改成菜单的依据。
///
///       **第 0 项是本应用自己的一行，不是 HiPER 的六项之一。** 它必须在菜单里，因为
///       [ResultForm.auto] 是本应用的初始态与回落态：菜单若只列六项，用户一旦选了任何一项就再也
///       回不到「精确写法 + `≈` 读数」那一行（`d/c` 与 `D°M'S` 只在各自那一格存在时才回到它）。
///       它的名字与注释都写明它**不是** HiPER 的菜单项，免得被读成第七格。
///
///       **这张表是函数而不是 `const` 列表**：第 0 项的名字与那两行理由都是**给人看的字**，
///       住在 `CalculatorStrings` 里（`calculator_strings.dart`）。六项 HiPER 原文仍写在下面，
///       因为它们是厂商字符串，任何语言的构建里都是这个样子。
///
///       **`Polar coordinates` 那一项今天给不出，所以 [ResultFormatCell.form] 是 `null`，
///       菜单里那一行是灰的、点不动**。理由（两条，各自都实测过）：
///       1. **本应用没有极坐标印法。** 引擎那一侧确实有极坐标——但它是**求值选项**
///          （`EvaluationOptions.complex_number_form`，`Calculator-calculate.cc:2195` 在求值中途
///          调用 `complexToPolarForm`），不是 `PrintOptions` 上的一个开关。改它意味着**换一组
///          求值选项再求一次值**，而本项目所有的「写法」都建立在「**同一个已求值结构的又一次
///          打印**」那条不变式上（`MathResult` 的四个形态字段全是这么来的）。那正是「形式切换
///          只改显示，绝不许改值」这条硬性边界的反例。
///       2. **它印出来的也不是 HiPER 那一格。** 宿主 `qalc` 5.12.0 实测
///          `-set "cplxform polar" "4+4i"` 得到 `5.656854249(cos(45.00000000) + i ×
///          sin(45.00000000))`，而 HiPER 的极坐标格是**幅度加角**（手册 p.11 的例子
///          `7∠45`）。同一个值的两种写法不假，但它不是那一格，而 `∠` 本应用的两个解析器都读不了
///          （已核实，见 `∠` 那一格的注释）。
///
///       **到期日**：`test/features/calculator_result_format_menu_test.dart` 里那两条
///       `应用今天给不出 Polar coordinates` 的断言钉着上面两句话。哪一天本应用真的有了一个
///       **只改写法**的极坐标印法，那两条断言会变红——那时这一项该点亮，而不是让一条过期的
///       禁用悄悄留着。
/// English: **the menu's seven entries, in on-screen order.**
///
///          **The first six come from the vendor's own string table** (`/tmp/hiper_en.po`), in file
///          order, with names copied verbatim (only the `<tabt:%0>` pre-fill placeholder dropped) —
///          see the table above. The menu title is `rfMenu.title` = **'Select Result Format'**. The
///          vendor's own FAQ calls it that: "press the `x⇔E` key. **It opens the Select Result Format
///          menu**…", and manual v12.0 says "press `x⇔E` and **choose** one of the following formats".
///          **Both say "choose"; neither says it cycles** — which is this round's ground for turning
///          `x⇔E` from a cycle into a menu.
///
///          **Entry 0 is this app's own line, not one of HiPER's six.** It has to be in the menu
///          because [ResultForm.auto] is this app's initial and fallback state: with only the six
///          entries, choosing any of them would leave no way back to the "exact spelling + `≈`
///          reading" line (`d/c` and `D°M'S` return to it only while their own cell exists). Its name
///          and its note both say it is **not** a HiPER entry, so it cannot be misread as a seventh
///          cell.
///
///          **This table is a function rather than a `const` list**: entry 0's name and both notes are
///          **human-facing text** and live in `CalculatorStrings` (`calculator_strings.dart`). The six
///          HiPER strings stay written out below, because they are vendor strings and read the same in
///          every language's build.
///
///          **`Polar coordinates` cannot be offered today, so its [ResultFormatCell.form] is `null`
///          and its row is greyed and unpressable.** Two measured reasons — see the English list
///          below the table.
///
///          **Expiry**: the two `应用今天给不出 Polar coordinates` assertions in
///          `test/features/calculator_result_format_menu_test.dart` pin both sentences. The day this
///          app gains a polar spelling that **changes the writing only**, they go red — and that entry
///          should then light up rather than an expired refusal quietly staying put.
List<ResultFormatCell> resultFormatCells(CalculatorStrings strings) {
  return <ResultFormatCell>[
    ResultFormatCell(
      label: strings.resultFormatDefaultLabel,
      form: ResultForm.auto,
      note: strings.resultFormatDefaultNote,
    ),
    const ResultFormatCell(label: 'Decimal', form: ResultForm.decimal),
    const ResultFormatCell(label: 'Expression', form: ResultForm.exact),
    const ResultFormatCell(label: 'Fraction', form: ResultForm.fraction),
    const ResultFormatCell(label: 'Mixed number', form: ResultForm.mixed),
    const ResultFormatCell(label: 'Degrees, mins, secs', form: ResultForm.dms),
    ResultFormatCell(
      label: 'Polar coordinates',
      form: null,
      note: strings.resultFormatPolarNote,
    ),
  ];
}

/// 中文：**`x⇔E` 打开的面板**——HiPER 的 "Select Result Format" 菜单。
///
///       四件事都由 [ResultPresentation] 一处回答，面板自己一个判据也不立：
///       - **哪一项点得动**：`presentation.canDraw(form)`——「这一份结果有没有这一格」；
///       - **哪一项是当前那一项**：`presentation.resolve(current)`——请求的形态落到这一份结果上
///         之后的那一个（所以一份换了结果的记录不会在面板上留一个假的勾）；
///       - **选完画什么**：那是 [ResultPresentation.texFor]，与结果行同一份；
///       - **灰着的那几格为什么灰**：`presentation.gapFor(form)`——「本应用今天印不出这一格」与
///         「这一份结果没有这一格」是两句不同的话，面板按它挑措辞（[_gapNote]），判据不在这里。
///
///       **后一件是本轮补上的**：那几格从前灰得**一句话都没有**，而面板顶上那句「灰掉的那一项是
///       这一份结果画不出来的」在引擎没参与求值时是**假话**——`10÷4` 就是 `5/2`，只是本应用没有
///       问过引擎。现在标题说的是那两件事本身，每一格灰着的原因逐行写在它自己那一行上（与
///       `Polar coordinates` 那一项同一个形状）。
///
///       **每一项右边画的是那一格自己的写法**——这不是装饰：HiPER 的菜单项字符串本来就是
///       `Decimal <tabt:%0>` 这个形状（`%0` 是它当场给的预览），所以「这一项会画出什么」是那一格
///       定义的一部分。排的是 `canDraw` 收下的那一段 TeX——**它一定排得出来**（`_accepted` 里的
///       `MathExpressionView.typesetsTex` 已经问过同一个 `Math.tex`），所以这里没有降级路径。
///
///       **预览不走 `MathExpressionView`，用的是它底下同一个 `Math.tex`。** 两者排出来是同一套东西
///       （`typesetsTex` 就是 `Math.tex(tex).parseError == null`），而那个组件额外背着**光标与点击
///       定位**那一套——预览一样都不要。这条也保住了一件既有的、被好几个测试依赖的事实：
///       **屏幕上只有一处 `MathExpressionView`**（表达式那一行，`_displayedExpression` 一类的辅助
///       函数就按 `tester.widget<MathExpressionView>` 取它）。面板里再放一个会让那些辅助函数一次
///       取到两个。
///
///       **选一项就关**：HiPER 那边这是一次「选一个格式」的动作，不是 `CONV`/`X` 那种一次要插
///       好几样的面板。
/// English: **the sheet `x⇔E` opens** — HiPER's "Select Result Format" menu.
///
///          All four questions are answered in one place, [ResultPresentation]; the sheet invents no
///          judgement of its own: **which entry can be pressed** (`canDraw`), **which one is the
///          current one** (`resolve(current)`, so a record carried over from another result cannot
///          leave a false tick here), and **what picking draws** (`texFor`, the result line's own) —
///          plus, from this round on, **why a grey cell is grey** (`gapFor`): "this app cannot print
///          that cell today" and "this result has no such cell" are two different sentences, and the
///          sheet picks the wording for whichever applies ([_gapNote]) while the judgement stays in
///          [ResultPresentation]. Those cells used to go grey **without a word**, and the old subtitle
///          ("the greyed entry is one this result cannot be drawn in") was **false** whenever the
///          engine took no part — `10÷4` *is* `5/2`, the app just never asked. The subtitle now states
///          the two cases themselves, and each grey cell's reason is written on its own row, in the
///          shape `Polar coordinates` already used.
///
///          **Each entry draws that cell's own spelling beside its name** — not decoration: HiPER's
///          menu strings already have the shape `Decimal <tabt:%0>` (`%0` is a preview supplied on the
///          spot), so "what this entry would draw" is part of what the cell is. What it typesets is
///          the TeX `canDraw` accepted, and that **always typesets** — `_accepted` already asked the
///          very same `Math.tex` through `MathExpressionView.typesetsTex` — so there is no fallback
///          path here.
///
///          **The preview does not go through `MathExpressionView`; it uses the `Math.tex` underneath
///          it.** The two set the same thing (`typesetsTex` *is* `Math.tex(tex).parseError == null`),
///          while that widget additionally carries the **caret and tap-to-place** machinery, of which
///          a preview wants none. This also keeps an existing fact several tests rely on: **there is
///          exactly one `MathExpressionView` on screen** (the expression line; helpers such as
///          `_displayedExpression` take it with `tester.widget<MathExpressionView>`). A second one in
///          the sheet would make those helpers find two.
///
///          **Picking closes it**: on HiPER this is a "choose a format" action, not a sheet like
///          `CONV`/`X` where several things get inserted in a row.
class ResultFormatSheet extends StatelessWidget {
  const ResultFormatSheet({
    required this.presentation,
    required this.current,
    required this.plainReading,
    required this.onPick,
    super.key,
    this.onClose,
  });

  /// 中文：**结果行此刻那串纯文本读数**（`CalculatorDisplay.result`）。它只有一个用处：某一格的
  ///       预览排不出来时降级成它——与结果行降级用的是同一串，所以面板里的预览与选完之后屏幕上的
  ///       东西不可能是两个数。**它自己不参与任何判断**（哪一格点得动、哪一格是当前，仍然只有
  ///       `ResultPresentation` 那一份判据）。
  /// English: **the plain reading the result line is showing right now**
  ///          (`CalculatorDisplay.result`). It has one use: a cell's preview that cannot be typeset
  ///          degrades to it — the same string the result line degrades to, so a preview in the sheet
  ///          and what appears after picking cannot be two different numbers. **It takes part in no
  ///          judgement itself** (which entry can be pressed and which one is current are still
  ///          `ResultPresentation`'s alone).
  final String plainReading;

  /// 中文：**当前这一份结果有哪几种画法**——判据的唯一来源（`ResultPresentation.of`）。
  /// English: **which ways the current result can be drawn** — the single source of the judgement
  ///          (`ResultPresentation.of`).
  final ResultPresentation presentation;

  /// 中文：**请求的形态**（页面上存的那一个，可能对不上这一份结果）。当前那一项由
  ///       `presentation.resolve(current)` 回答，不是 [current] 自己。
  /// English: the **requested** form (the one stored on the page, possibly not matching this result).
  ///          The current entry is `presentation.resolve(current)`, not [current] itself.
  final ResultForm current;

  /// 中文：选了一项。面板自己关自己，调用方只负责把状态存下来。
  /// English: an entry was picked. The sheet closes itself; the caller only stores the state.
  final ValueChanged<ResultForm> onPick;

  /// 中文：关闭按钮；为 null 时不画（测试里直接构造面板时就是这种）。
  /// English: the close button; not drawn when null (which is the case when a test builds the sheet
  ///          directly).
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = CalculatorStrings.of(context);
    final resolved = presentation.resolve(current);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // 中文：标题逐字用 HiPER 自己的 `rfMenu.title`——菜单的名字也是那一格定义的一部分。
            // English: the title is HiPER's own `rfMenu.title` verbatim — the menu's name is part of
            //          what the cell is too.
            Text(
              'Select Result Format',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            // 中文：**标题这一行从前是一句假话。** 它写的是「灰掉的那一项是这一份结果画不出来的」，
            //       而在引擎没有参与这一份结果时（边打边算在 `表达式显示` = `数学表达式` 下根本
            //       不问引擎）那三格灰着**不是**因为这一份结果画不出来——`10÷4` 就是 `5/2`，本应用
            //       只是没有问过。现在它说的是那两件事本身：**不是结果没有这一格，就是本应用今天
            //       印不出这一格**（后者逐格写在它自己那一行上，见 [_gapNote]）。
            // English: **this line used to be false.** It said "the greyed entry is one this result
            //          cannot be drawn in", and while the engine took no part in this result (under
            //          `表达式显示` = `数学表达式` as-you-type never asks it) those three cells are grey
            //          **not** because the result cannot be drawn that way — `10÷4` *is* `5/2`, this app
            //          simply never asked. It now states the two cases themselves: **either the result
            //          has no such cell, or this app cannot print that cell today** (the second is
            //          written out cell by cell, see [_gapNote]).
            Text(
              strings.resultFormatSubtitle,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            // 中文：**不是 `ListView`**：七项全部当场建出来。一是这一列短得很，没有懒建的必要；
            //       二是 `ListView` 只在视口（加一段缓存）里建子树，窗口矮一点时最后几项根本不在
            //       树里——而「菜单里有没有 `Polar coordinates` 这一项」正是一条要问的断言。
            // English: **not a `ListView`**: all seven entries are built at once. The column is short
            //          enough that laziness buys nothing, and a `ListView` only builds what is in the
            //          viewport (plus a cache stretch) — in a short window the last entries would not be
            //          in the tree at all, while "is `Polar coordinates` in the menu" is exactly one of
            //          the assertions to ask.
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (final cell in resultFormatCells(strings))
                      _cellRow(context, theme, cell, resolved, strings),
                  ],
                ),
              ),
            ),
            if (onClose != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onClose,
                  child: Text(strings.close),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cellRow(
    BuildContext context,
    ThemeData theme,
    ResultFormatCell cell,
    ResultForm resolved,
    CalculatorStrings strings,
  ) {
    final form = cell.form;
    final selected = form != null && form == resolved;
    // 中文：点不点得动只有这一条判据：**这一项得存在，而且这一份结果得有那一格**。`form == null`
    //       是「本应用给不出这一项」，`canDraw` 是「这一份结果没有这一格」——两种情况画出来一样
    //       （灰、点不动），因为对用户来说它们是同一件事：现在按不下去。
    // English: one judgement decides pressability: **the entry must exist and this result must have
    //          that cell**. `form == null` is "this app cannot offer it" and `canDraw` is "this result
    //          does not have it" — both are drawn the same way (grey, unpressable) because to the
    //          user they are one thing: it cannot be pressed now.
    final enabled = form != null && presentation.canDraw(form);
    final preview = form == null ? '' : presentation.texFor(form);
    // 中文：**这一行的小字**——每一项自己带的那一句（`默认` 与 `Polar coordinates`），或者**它灰着
    //       的原因**（`gapFor`）。判据在 [ResultPresentation] 一处，这里只把它翻成一句人能读的话。
    //       灰着而没有原因的那几格（`√8` 的分数、`2+2` 的精确）小字为空，标题那一行说的正是它们。
    // English: **this row's small line** — the one the entry itself carries (`默认` and `Polar
    //          coordinates`), or **why it is grey** (`gapFor`). The judgement lives in one place,
    //          [ResultPresentation]; this only turns it into a sentence a human reads. A grey cell with
    //          no such reason (`√8`'s fraction, `2+2`'s exact) keeps an empty line, and the subtitle is
    //          what speaks for those.
    final note = cell.note.isNotEmpty
        ? cell.note
        : (form == null
            ? ''
            : _gapNote(presentation.gapFor(form), form, strings));
    return ListTile(
      dense: true,
      enabled: enabled,
      selected: selected,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        size: 18,
        color: enabled ? theme.colorScheme.primary : theme.disabledColor,
      ),
      title: Row(
        children: <Widget>[
          Text(
            cell.label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: enabled ? null : theme.disabledColor,
            ),
          ),
          const SizedBox(width: 10),
          // 中文：预览——**那一格自己的写法**，与结果行同一套排版、同一套降级。`Decimal` 那一格
          //       排的是空串，于是它降级成纯文本读数（那正是这一格的定义）。
          // English: the preview — **that cell's own spelling**, through the result line's own
          //          typesetting and fallback. The `Decimal` cell typesets the empty string, so it
          //          degrades to the plain reading, which is exactly what that cell is.
          Flexible(
            child: preview.isEmpty
                // 中文：`Decimal` 那一格的预览就是那串纯文本读数（它排的是空串，见
                //       `ResultPresentation.texFor`）——所以这里画的正是面板上写的那个数。
                // English: the `Decimal` cell's preview is the plain reading itself (it typesets the
                //          empty string — see `ResultPresentation.texFor`), so what is drawn here is
                //          exactly the number the entry names.
                ? Text(
                    plainReading,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: enabled ? null : theme.disabledColor,
                    ),
                  )
                : FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Math.tex(
                      preview,
                      mathStyle: MathStyle.text,
                      textStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: enabled ? null : theme.disabledColor,
                      ),
                    ),
                  ),
          ),
        ],
      ),
      subtitle: note.isEmpty ? null : Text(note),
      onTap: enabled ? () => onPick(form) : null,
    );
  }

  /// 中文：**一格灰着的原因，翻成一句话**——[ResultCellGap] 到屏幕上的那行小字。与
  ///       `Polar coordinates` 那一项同一个形状（灰 + 点不动 + 一行理由），理由的**判据**不在
  ///       这里，这里只有措辞。
  ///
  ///       两句都要点出「这是关于本应用的话，不是关于结果的话」——那句假话的病根正在这里：
  ///       - [ResultCellGap.engineNotAsked]：这一份结果不是引擎算的，而这一格只有引擎印得出来。
  ///         所以本应用手上没有它，而不是这一份结果没有这一格。
  ///       - [ResultCellGap.typesettingOff]：`表达式显示` 设成 `数学表达式` 之后结果行不排写法。
  ///         这里**故意不写「本应用没有它的写法」**：按 `=` 提交时引擎已经把那几份写法给了
  ///         （提交路径不看 kill switch），屏幕上仍然不排它——所以这一句说的是「不印」，不是
  ///         「没有」。
  /// English: **a grey cell's reason, turned into one sentence** — [ResultCellGap] to the small line on
  ///          screen. It has the same shape as the `Polar coordinates` entry (grey + unpressable + one
  ///          line saying why); the **judgement** is not here, only the wording.
  ///
  ///          Both sentences have to say "this is about the app, not about the result" — that is the
  ///          root of the false line this replaces:
  ///          - [ResultCellGap.engineNotAsked]: this result did not come from the engine, and only the
  ///            engine prints this cell. So the app does not have it — the result does not lack it.
  ///          - [ResultCellGap.typesettingOff]: with `表达式显示` on `数学表达式` the result line
  ///            typesets nothing. It **deliberately does not say "this app has no such spelling"**:
  ///            on the `=` path the engine has already handed those spellings over (the submit path does
  ///            not look at the kill switch) and they still are not drawn — so the sentence says "does
  ///            not print", not "does not have".
  String _gapNote(
          ResultCellGap gap, ResultForm form, CalculatorStrings strings) =>
      switch (gap) {
        ResultCellGap.none => '',
        ResultCellGap.engineNotAsked =>
          strings.resultFormatGapNotFromEngine(_spellingName(form, strings)),
        ResultCellGap.typesettingOff =>
          strings.resultFormatGapTypesettingOff(_spellingName(form, strings)),
      };

  /// 中文：那一格自己要的写法叫什么。点它的名是为了让四行灰格不至于读起来一模一样——它们**是**
  ///       被同一个原因一起挡住的，但每一行都要能单独读懂。
  ///       **名字本身在 `CalculatorStrings` 里**（`spellingExact`…）；这里只负责"哪一格叫哪一个"，
  ///       因为那个 `switch` 是「每一格叫什么」这个问题**唯一**的落点。
  /// English: the name of the spelling this cell wants. Naming it keeps those four grey rows from
  ///          reading identically — they **are** blocked together by one cause, but each row has to be
  ///          readable on its own. **The words themselves live in `CalculatorStrings`**
  ///          (`spellingExact`…); this only answers "which cell takes which name", because that
  ///          `switch` is the **only** landing place for that question.
  String _spellingName(ResultForm form, CalculatorStrings strings) =>
      switch (form) {
        ResultForm.exact => strings.spellingExact,
        ResultForm.fraction => strings.spellingFraction,
        ResultForm.mixed => strings.spellingMixed,
        ResultForm.dms => strings.spellingDms,
        // 中文：这两格不会走到这里（`gapFor` 对它们恒回 `none`）——写出来是因为这个 `switch` 是
        //       「每一格叫什么」这个问题**唯一**的落点，留一个 `_` 兜底就等于把那条约定废掉。
        // English: these two cannot reach here (`gapFor` always answers `none` for them). They are
        //          written out because this `switch` is the **only** landing place for "what is this
        //          cell called"; a `_` catch-all would void that rule.
        ResultForm.auto || ResultForm.decimal => strings.spellingAuto,
      };
}
