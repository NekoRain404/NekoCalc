import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/core/math/ast/expression_ast_parser.dart';
import 'package:nekocalc/core/math/ast/tex_emitter.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/features/calculator/presentation/calculator_page.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/calculator_keypad.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/hiper_keypad.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/keypad_definition.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/dataset_sheet.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/math_expression_view.dart';

/// 中文：**统计数据集那一侧的界面证据**——入口、读数、四个动作，以及「四个统计调用改用数据集」这件事。
///
///       这里走的是**真实的交互路径**：`STAT` 那颗键从键位表里查出来（不是写死 id），面板上的每个新
///       控件都真的被按下去，插入仍然走主屏的 `_pressKey`。所以这一组同时回答两件事：新控件**真的在
///       动**（不是灰着不响的装饰），以及四个统计格插进去的文本真的换成了数据集里那几个值。
///
///       **数据集为空时插的仍是起手数据**是这一组里最要紧的一条：它是「本轮没有改掉任何已经工作的
///       行为」的可测形式。`calculator_page_hiper_engine_test.dart` 里那条四层证据（面板 → 派发 →
///       排版 → 渲染）也仍然按 `mean(1,2,3,4)` 钉着，两条一起才说明白「空数据集这条路没变」。
///
/// English: **the UI evidence for the statistics dataset** — its entrance, its reading, its four
///          actions, and the fact that the four statistics calls now draw on it.
///
///          This walks the **real interaction path**: the `STAT` key is looked up **in the key table**
///          (not a hardcoded id), every new control on the sheets is really pressed, and insertion still
///          travels the screen's `_pressKey`. So this group answers two things at once: the new controls
///          **really act** (they are not dead decoration), and the text the four statistics cells insert
///          really is the dataset's values.
///
///          **An empty dataset still inserts the starting sample** is the most important item here: it is
///          the testable form of "this round changed none of the behaviour that already worked". The
///          four-layer test in `calculator_page_hiper_engine_test.dart` (sheet → dispatch → typesetting
///          → rendering) also still pins `mean(1,2,3,4)`, and the two together are what says "the empty
///          dataset path has not moved".
void main() {
  testWidgets('STAT 面板：有数据集的读数与入口，按一下打开编辑面板', (tester) async {
    await _pumpPage(tester);

    _openStatistics(tester);
    await tester.pumpAndSettle();

    expect(find.textContaining('数据集空，插入起手数据 1,2,3,4'), findsOneWidget,
        reason: '不说清楚此刻会插什么，按下去就会凭空多出一串用户没打过的数字');
    expect(find.text('数据集…'), findsOneWidget);

    await tester.tap(find.text('数据集…'));
    await tester.pumpAndSettle();

    expect(find.byType(DatasetSheet), findsOneWidget,
        reason: '「数据集…」按下去必须真的打开编辑面板');
    expect(find.text('还没有值'), findsOneWidget);
  });

  testWidgets('编辑面板：加入当前结果 → 那一格出现、读数跟着变', (tester) async {
    await _pumpPage(tester);
    await _type(tester, '5');

    await _openDatasetSheet(tester);
    expect(find.text('还没有值'), findsOneWidget);

    await tester.tap(find.text('加入当前结果'));
    await tester.pumpAndSettle();

    expect(_chipLabels(tester), <String>['5']);
    expect(find.textContaining('数据集 1 个值'), findsOneWidget);
    expect(find.text('加入当前结果 5'), findsOneWidget,
        reason: '读数是「会加进去的那个数」的预览');
  });

  testWidgets('编辑面板：去一个值、清空，两个控件都真的动', (tester) async {
    await _pumpPage(tester);
    await _type(tester, '5');
    await _openDatasetSheet(tester);
    await tester.tap(find.text('加入当前结果'));
    await tester.pumpAndSettle();
    await _type(tester, '12');
    await tester.tap(find.text('加入当前结果'));
    await tester.pumpAndSettle();

    expect(_chipLabels(tester), <String>['5', '12']);

    // 中文：去掉第一个（chip 上的删除按钮就是那个控件的真身，不是装饰）。
    // English: drop the first one (the chip's delete button is the control itself, not decoration).
    await tester.tap(find.descendant(
      of: find.widgetWithText(InputChip, '5'),
      matching: find.byTooltip('去掉这个值'),
    ));
    await tester.pumpAndSettle();
    expect(_chipLabels(tester), <String>['12']);

    await tester.tap(find.text('清空'));
    await tester.pumpAndSettle();
    expect(_chipLabels(tester), isEmpty);
    expect(find.text('还没有值'), findsOneWidget);
    expect(find.textContaining('数据集是空的'), findsOneWidget);
  });

  testWidgets('数据集非空时，STAT 面板插的是它那几个值', (tester) async {
    await _pumpPage(tester);
    await _type(tester, '5');
    await _openDatasetSheet(tester);
    await tester.tap(find.text('加入当前结果'));
    await tester.pumpAndSettle();
    await _type(tester, '12');
    await tester.tap(find.text('加入当前结果'));
    await tester.pumpAndSettle();

    // 中文：回 STAT 面板看一眼读数，再按 `mean`。两下都是真实交互。（先把表达式清掉：面板是往
    //       光标处**追加**一条调用，屏幕上那串 `12` 留着的话会与它粘成一条隐式乘法。）
    // English: go back to the `STAT` sheet to read it once, then press `mean`. Both are real presses.
    //          (The expression is cleared first: the sheet **appends** a call at the cursor, and the
    //          `12` left on screen would glue onto it as an implicit multiplication.)
    await _closeSheet(tester);
    await _press(tester, 'clear');
    _openStatistics(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('数据集 2 个：5, 12'), findsOneWidget);

    await tester.tap(find.text('mean'));
    await tester.pumpAndSettle();

    expect(_expression(tester), 'mean(5,12)');
    // 中文：插进去的那条调用也要排得出来（不是降级成字面文本）——与那四个名字本身的排版证据同一条。
    // English: the inserted call has to typeset too (no fallback to literal text) — the same criterion
    //          the four names themselves are held to.
    expect(_literalTextFragment(_expression(tester)), isFalse);
    expect(
      MathExpressionView.typesetsTex(const TexEmitter()
          .emit(const ExpressionAstParser().parse('mean(5,12)'))),
      isTrue,
    );
  });

  testWidgets('数据集为空时插的仍是起手数据——本轮没有改掉已经工作的行为', (tester) async {
    await _pumpPage(tester);

    _openStatistics(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('median'));
    await tester.pumpAndSettle();

    expect(_expression(tester), 'median(1,2,3,4)');
  });

  testWidgets('手改过的那条调用不受影响：面板只往光标处加一条新的，从不改写已经写下的文本',
      (tester) async {
    await _pumpPage(tester);

    // 中文：先在屏幕上算出 `5` 并把它加进数据集。
    // English: first get `5` on screen and add it to the dataset.
    await _type(tester, '5');
    await _openDatasetSheet(tester);
    await tester.tap(find.text('加入当前结果'));
    await tester.pumpAndSettle();
    await _closeSheet(tester);

    // 中文：再照面板自己那句话说的，把表达式在内联编辑器里改成一条**手写**的统计调用。
    //       （手改之后屏幕上就没有可加的数了——`mean(7,8,9)` 是旧解析器算不出来的，这正是要点：
    //       数据集已经存好了，用户接下来只管按函数格。）
    // English: then — following what the sheet's own sentence says to do — rewrite the expression into
    //          a **hand-written** statistics call in the inline editor. (After the edit there is nothing
    //          storable on screen — `mean(7,8,9)` is something the legacy parser cannot evaluate, which
    //          is exactly the point: the dataset is already stored and the user only has to press a
    //          function cell now.)
    await _startEditing(tester);
    await tester.enterText(find.byType(TextField), 'mean(7,8,9)');
    // 中文：编辑器占着表达式那一行，所以先让它收回去（与 `calculator_page_hiper_engine_test.dart`
    //       里同一步的做法逐字相同），再读显示面板上的表达式。
    // English: the editor occupies the expression line, so it is dismissed first (byte for byte what
    //          the same step does in `calculator_page_hiper_engine_test.dart`) before reading the
    //          expression off the display.
    FocusManager.instance.primaryFocus!.unfocus();
    await tester.pumpAndSettle();
    expect(_expression(tester), 'mean(7,8,9)');

    _openStatistics(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('mean'));
    await tester.pumpAndSettle();

    // 中文：**手改过的那一条一个字符都没动**——面板只往光标处加了一条新的，没有回头去改写已经写下的
    //       文本。两条紧挨着排（`_appendSmart` 的「补一个乘号」那张函数名前缀表里没有 `mean(`，与
    //       `sum(`/`matrix(` 一样），这是**本轮之前就有的**形状，本轮没有动它；这里钉住的是「手改
    //       的那一段原样留着、新的一段接在后面」。
    // English: **the hand-edited call is not touched by a single character** — the sheet only appends a
    //          new one at the cursor and never reaches back into text already written. The two sit
    //          side by side (`_appendSmart`'s "insert a ×" function-prefix table has no `mean(`, just as
    //          it has no `sum(`/`matrix(`), which is a shape that **predates this round** and is
    //          untouched here; what is pinned is "the hand-edited run stays verbatim and the new one
    //          follows it".
    expect(_expression(tester), startsWith('mean(7,8,9)'),
        reason: '手改的那条必须原样留着');
    expect(_expression(tester), endsWith('mean(5)'),
        reason: '新的一条必须接在后面');
    expect(_expression(tester), 'mean(7,8,9)mean(5)');
  });

  testWidgets('负值与小数插进去照样排得出来（数据集里的值原样进调用）', (tester) async {
    await _pumpPage(tester);

    await _type(tester, '5');
    await _press(tester, 'negate');
    await _openDatasetSheet(tester);
    await tester.tap(find.text('加入当前结果'));
    await tester.pumpAndSettle();
    await _closeSheet(tester);
    await _type(tester, '1');
    await _press(tester, '.');
    await _press(tester, '5');
    await _openDatasetSheet(tester);
    await tester.tap(find.text('加入当前结果'));
    await tester.pumpAndSettle();
    await _closeSheet(tester);
    await _press(tester, 'clear');

    _openStatistics(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('stdev'));
    await tester.pumpAndSettle();

    expect(_expression(tester), 'stdev(-5,1.5)');
    expect(_literalTextFragment(_expression(tester)), isFalse,
        reason: '负号与小数点不能被读成别的形状（降级成字面文本就是一种）');
  });

  testWidgets('两变量三格：数据集读成两行时插的是那条两行矩阵调用，而且排得出来', (tester) async {
    await _pumpPage(tester);
    await _addValues(tester, <String>['1', '100', '2', '200']);
    await _press(tester, 'clear');

    _openStatistics(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('数据集读成两行：pearson(matrix(2,2,1,100,2,200))'),
        findsOneWidget,
        reason: '那串数里的 2 与 2 必须有个来历，否则屏幕上就是两个凭空出现的数字');

    await tester.tap(find.text('pearson'));
    await tester.pumpAndSettle();

    expect(_expression(tester), 'pearson(matrix(2,2,1,100,2,200))');
    // 中文：插进去的那条调用也要排得出来（不是降级成字面文本）——与上面四格那条同一条判据。
    // English: the inserted call has to typeset too (no fallback to literal text) — the same criterion
    //          the four cells above are held to.
    expect(_literalTextFragment(_expression(tester)), isFalse);
    // 中文：TeX 的**形状**逐字钉住，不只断言 `typesetsTex`——只断言排得出来的话，换成别的写法
    //       照样绿。矩阵那一层也在此（`matrix` 走 `\operatorname`，与实参不粘连）。
    // English: the **shape** of the TeX is pinned word for word rather than only `typesetsTex` — that
    //          alone stays green under a different spelling. The matrix layer is in there too
    //          (`matrix` goes through `\operatorname` and does not stick to its arguments).
    expect(
      const TexEmitter()
          .emit(const ExpressionAstParser().parse(_expression(tester))),
      r'\operatorname{pearson}{\left(\operatorname{matrix}{\left(2, 2, 1, 100, 2, 200\right)}\right)}',
    );
    // 第四层：屏幕上画的是公式，不是承载降级文本的那个 `Text`。
    // Layer four: what is drawn is a formula, not the `Text` that carries degraded text.
    expect(
      find.descendant(
        of: find.byType(MathExpressionView),
        matching: find.text(_expression(tester)),
      ),
      findsNothing,
      reason: '`${_expression(tester)}` 画成了字面文本而不是公式',
    );
  });

  testWidgets('两变量另外两格也真的在动（covar / spearman 各自插自己那一条）', (tester) async {
    await _pumpPage(tester);
    await _addValues(tester, <String>['1', '2', '3', '4']);

    for (final name in <String>['covar', 'spearman']) {
      await _press(tester, 'clear');
      _openStatistics(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
      expect(_expression(tester), '$name(matrix(2,2,1,2,3,4))');
      expect(_literalTextFragment(_expression(tester)), isFalse);
    }
  });

  testWidgets('数据集读不成两行时，两变量三格是灰的，而且旁边写着为什么', (tester) async {
    await _pumpPage(tester);

    // 中文：空数据集。
    // English: an empty dataset.
    _openStatistics(tester);
    await tester.pumpAndSettle();
    _expectRegressionCellsDisabled(tester);
    expect(find.textContaining('现在数据集是空的'), findsOneWidget,
        reason: '灰键不解释自己为什么灰，就等于没说');

    await _closeSheet(tester);

    // 中文：奇数个值——两行读法需要偶数个，这里**拒绝，不是四舍五入**。
    // English: an odd count — the two-row reading needs an even one, and here it is **refused, not
    //          rounded**.
    await _setDataset(tester, <String>['1', '2', '3']);
    _openStatistics(tester);
    await tester.pumpAndSettle();
    _expectRegressionCellsDisabled(tester);
    expect(find.textContaining('需要偶数个值，现在有 3 个'), findsOneWidget);

    await _closeSheet(tester);

    // 中文：只有一对（2 个值）——宿主实测 `pearson(matrix(2,1,1,2))` 给的是未求值的 `0 / 0`。
    // English: one pair only (two values) — measured on the host, `pearson(matrix(2,1,1,2))` returns
    //          the unevaluated `0 / 0`.
    await _setDataset(tester, <String>['1', '2']);
    _openStatistics(tester);
    await tester.pumpAndSettle();
    _expectRegressionCellsDisabled(tester);
    expect(find.textContaining('每行至少 2 个值，现在有 2 个'), findsOneWidget);
  });

  testWidgets('数据集一够长，那三格当场亮起来（不必关掉面板重开）', (tester) async {
    await _pumpPage(tester);
    await _addValues(tester, <String>['1', '2', '3']);

    _openStatistics(tester);
    await tester.pumpAndSettle();
    _expectRegressionCellsDisabled(tester);

    // 中文：从面板进编辑面板，再加一个值——回到 STAT 面板时那三格必须是亮的（读数跟着控制器走，
    //       与上面那行数据集读数是同一个 `AnimatedBuilder`）。
    // English: from the sheet into the editor sheet, add one more value — on returning to the `STAT`
    //          sheet those three cells must be lit (the reading follows the controller, the same
    //          `AnimatedBuilder` the dataset line above uses).
    await tester.tap(find.text('数据集…'));
    await tester.pumpAndSettle();
    await _type(tester, '4');
    await tester.tap(find.text('加入当前结果'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();

    // 中文：`数据集…` 那一按会**先把 STAT 面板收掉**（面板盖着键盘，两层叠着的面板谁也看不清），
    //       所以从编辑面板回来之后要再打开一次 STAT 面板。
    // English: pressing `数据集…` **closes the `STAT` sheet first** (the sheet covers the keypad and
    //          two stacked sheets are legible to nobody), so the `STAT` sheet is reopened after coming
    //          back from the editor.
    _openStatistics(tester);
    await tester.pumpAndSettle();

    _expectRegressionCellsEnabled(tester);
    expect(find.textContaining('数据集读成两行：pearson(matrix(2,2,1,2,3,4))'),
        findsOneWidget);
  });

  testWidgets('屏幕上没有可加的数时，「加入当前结果」是灰的（看得见的拒绝）', (tester) async {
    await _pumpPage(tester);

    // 中文：`(` 之后那条表达式算不出结果，结果行是「等待输入」（没有十进制形态）。
    // English: after `(` the expression has no result, so the result line is the "waiting for input"
    //          placeholder (no decimal form at all).
    await _press(tester, '(');
    await _openDatasetSheet(tester);

    final button = tester.widget<TextButton>(
      find.widgetWithText(TextButton, '加入当前结果'),
    );
    expect(button.onPressed, isNull,
        reason: '没有可加的值时按钮必须是灰的——按下去没反应比这更糟');
    expect(find.textContaining('当前没有可加入的数值'), findsOneWidget);
  });
}

/// 中文：主屏 + 键位表这一套的公共前奏。
/// English: the shared preamble for the screen-and-key-table setup.
Future<void> _pumpPage(WidgetTester tester) async {
  await tester.pumpWidget(_testApp());
  await tester.pumpAndSettle();
}

/// 中文：按键面文字查键位表，派发那一刻的 id——「面板上那颗键此刻是点亮的」才是被钉住的东西。
/// English: look a cell up in the key table by its face and dispatch the id it carries **right now** —
///          "that key on the keypad is lit at this moment" is what gets pinned.
void _openStatistics(WidgetTester tester) {
  tester
      .widget<CalculatorKeypad>(find.byType(CalculatorKeypad))
      .onKey(_cellByFace('STAT'));
}

Future<void> _openDatasetSheet(WidgetTester tester) async {
  _openStatistics(tester);
  await tester.pumpAndSettle();
  await tester.tap(find.text('数据集…'));
  await tester.pumpAndSettle();
}

Future<void> _press(WidgetTester tester, String id) async {
  tester.widget<CalculatorKeypad>(find.byType(CalculatorKeypad)).onKey(id);
  await tester.pumpAndSettle();
}

/// 中文：先按 `AC` 清掉表达式，再打进 [digits]，然后提交——于是屏幕上那个结果就是这一串。
/// English: press `AC` first to clear the expression, type [digits], then submit — so the result on
///          screen is exactly that run of digits.
Future<void> _type(WidgetTester tester, String digits) async {
  await _press(tester, 'clear');
  for (final digit in digits.split('')) {
    await _press(tester, digit);
  }
  await _press(tester, 'equals');
}

/// 中文：点面板外把它收掉（`CONV` 那一套的同一个做法）。
/// English: dismiss the sheet by tapping outside it (the same device the `CONV` sheet's test uses).
Future<void> _closeSheet(WidgetTester tester) async {
  await tester.tapAt(const Offset(10, 10));
  await tester.pumpAndSettle();
}

/// 中文：逐个把 [values] 算到屏幕上、加进数据集、再回主屏。四个值的两行读法是这一组的前提。
/// English: put each of [values] on screen, add it to the dataset and return to the main screen. A
///          four-value two-row reading is the precondition of this group.
Future<void> _addValues(WidgetTester tester, List<String> values) async {
  for (final value in values) {
    await _type(tester, value);
    await _openDatasetSheet(tester);
    await tester.tap(find.text('加入当前结果'));
    await tester.pumpAndSettle();
    await _closeSheet(tester);
  }
}

/// 中文：把数据集换成 [values]（先清空再加）——同一个 `testWidgets` 里数据集是**累积**的，
///       而这一组要逐个看空 / 奇数 / 一对这三种状态。
/// English: replace the dataset with [values] (clear first, then add) — the dataset **accumulates**
///          within one `testWidgets`, and this group looks at the empty / odd / one-pair states in
///          turn.
Future<void> _setDataset(WidgetTester tester, List<String> values) async {
  await _openDatasetSheet(tester);
  await tester.tap(find.text('清空'));
  await tester.pumpAndSettle();
  await _closeSheet(tester);
  await _addValues(tester, values);
}

/// 中文：三格此刻都是灰的——**判据是那个控件本身**（`TextButton.onPressed` 为 null），
///       不是「那段文字在不在」。灰键不做事，而一个 `onPressed` 非空的键无论如何都会做点什么。
/// English: all three cells are grey right now — **the criterion is the control itself**
///          (`TextButton.onPressed` is null), not "is that text present". A grey cell does nothing,
///          while a cell with a non-null `onPressed` always does something.
void _expectRegressionCellsDisabled(WidgetTester tester) {
  for (final name in <String>['pearson', 'spearman', 'covar']) {
    final button = tester.widget<TextButton>(
      find.widgetWithText(TextButton, name),
    );
    expect(button.onPressed, isNull, reason: '`$name` 读不成两行时必须是灰的');
  }
}

void _expectRegressionCellsEnabled(WidgetTester tester) {
  for (final name in <String>['pearson', 'spearman', 'covar']) {
    final button = tester.widget<TextButton>(
      find.widgetWithText(TextButton, name),
    );
    expect(button.onPressed, isNotNull, reason: '`$name` 数据够长时必须亮着');
  }
}

Future<void> _startEditing(WidgetTester tester) async {
  await tester.tap(find.text('More...'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('编辑表达式'));
  await tester.pumpAndSettle();
}

List<String> _chipLabels(WidgetTester tester) => tester
    .widgetList<InputChip>(find.byType(InputChip))
    .map((chip) => (chip.label as Text).data!)
    .toList();

String _expression(WidgetTester tester) =>
    tester.widget<MathExpressionView>(find.byType(MathExpressionView)).expression;

bool _literalTextFragment(String expression) =>
    const TexEmitter()
        .emit(const ExpressionAstParser().parse(expression))
        .contains(r'\text{');

String _cellByFace(String face) {
  for (final row in hiperKeypad.rows) {
    for (final key in row.keys) {
      if (key.base.label == face) return key.base.id;
    }
    for (final label in row.labels) {
      if (label is InlineKey && label.key.base.label == face) {
        return label.key.base.id;
      }
    }
  }
  throw StateError('键位表里没有「$face」这一格');
}

Widget _testApp() {
  return MaterialApp(
    theme: ThemeData.light(),
    home: Scaffold(
      body: CalculatorPage(
        db: _FakeDatabase(),
        onOpenSettings: () {},
        settings: const AppSettings(
          haptics: false,
          hapticStrength: '标准',
          restoreState: false,
          autoSaveHistory: false,
          angleMode: 'RAD',
          precision: 6,
          themeModeLabel: '跟随系统',
          expressionDisplayMode: '数学符号',
        ),
      ),
    ),
  );
}

class _FakeDatabase implements AppDatabase {
  @override
  Future<Map<String, String>> settings() async => const {};

  @override
  Future<void> setSettings(Map<String, String> values) async {}

  @override
  Future<void> setSetting(String key, String value) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
