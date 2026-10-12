import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/models/history_item.dart';
import 'package:nekocalc/features/calculator/presentation/calculator_page.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/calculator_keypad.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/calculator_display.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/math_expression_view.dart';

/// 中文：**主屏上「打一个算式、按等号」这条完整的用户动作，结果与历史一起量。**
///
///       **它补的是哪一格。** 到这一条为止，两件事各自被证明过，中间那一段没有：
///       - 控制器的防重复（`CalculatorSubmitStatus.historySkippedDuplicate`）由
///         `calculator_controller_persistence_test.dart` 的 `auto save skips equivalent submitted
///         expressions` 钉住——那是**领域层**，屏幕上那颗等号键接没接上它，它管不着；
///       - 「结果真的能上屏」由 `dataset_sheet_test.dart` 的 `_type()` 顺带走过一次——那是**别的
///         流程**里的副产品，那一组用的假库 `autoSaveHistory: false`，一行历史都不会写。
///
///       所以这一条走**真实的按键路径**：数字、运算符与等号全部按在键面上（`find.descendant`
///       把查找限定在 `CalculatorKeypad` 里，免得命中表达式行的富文本或键盘上的同名记号），然后
///       同时断言两件事——**结果真的画在显示面板里**，以及**历史恰好写了一行**；再按一次等号，
///       行数不许变。
///
///       **每次提交要等的那 5 秒是真的。** `flutter test` 里没有原生引擎，提交路径会先问一次
///       引擎；控制器自己的上限是 `engineTimeout`（5 秒），到点才回落到旧解析器——真机上没有
///       原生侧时走的是同一条路。所以按下等号之后要先断言**历史还是空的**（证明它不是同步写的），
///       再推过那个上限，才看到那一行。这不是在等一个随机的慢：推的是假时钟。
///
///       **「恰好一行」量的是写入次数。** 假库逐次记账、自己不去重，所以第二次等号若真的又走了
///       一次保存，记下的就是两行——这条断言才能认出控制器那道防重复被删掉。真库另有自己的一道
///       兜底（`AppDatabase.addHistory` 那两秒窗口，见该方法的注释），它在用户那一侧会挡下短时间
///       内的重复行；两处是同一条不变量的两道门，这里量的是**上面那道**。
/// English: **the whole user action "type an expression, press equals" on the main screen, with the
///          result and the history measured together.**
///
///          **The cell this fills.** Until this case, two things were each proven and the middle was
///          not: the controller's duplicate guard (`CalculatorSubmitStatus.historySkippedDuplicate`)
///          is pinned by `calculator_controller_persistence_test.dart`'s `auto save skips equivalent
///          submitted expressions` — that is the **domain layer**, and it cannot say whether the
///          equals key on the screen is wired to it; and "the result really reaches the screen" was
///          walked incidentally by `dataset_sheet_test.dart`'s `_type()` — a by-product of **another
///          flow**, whose fake database has `autoSaveHistory: false` and writes no history at all.
///
///          So this case walks the **real key path**: digits, operator and equals are all pressed on
///          key faces (`find.descendant` keeps the search inside `CalculatorKeypad`, so it cannot hit
///          the expression line's rich text or a same-named mark on the keypad), and then asserts two
///          things at once — **the result really is painted in the display panel**, and **exactly one
///          history row was written**; pressing equals again must not change the count.
///
///          **The five seconds each submit waits are real.** There is no native engine under
///          `flutter test`, and the submit path asks the engine first; the controller's own cap is
///          `engineTimeout` (5 s), after which it falls back to the legacy parser — the same road a
///          device without a native side takes. So the case asserts **the history is still empty**
///          right after equals (proving it is not written synchronously), then pushes past that cap
///          to see the row. This is not waiting on an arbitrary slow thing: it advances a fake clock.
///
///          **"Exactly one row" measures write attempts.** The fake records every call and does no
///          dedup of its own, so a second equals that really saved again would leave two rows — which
///          is what lets this assertion notice the controller's guard being removed. The real
///          database has a backstop of its own (`AppDatabase.addHistory`'s two-second window, see its
///          note) that hides short-window duplicates on the user side; the two are two doors on one
///          invariant, and what is measured here is **the upper door**.
void main() {
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('12+34 按等号：结果上屏、历史恰好一行；再按一次等号不多写', (tester) async {
    final db = _RecordingDatabase();
    await tester.pumpWidget(_page(db));
    await tester.pumpAndSettle();

    for (final face in <String>['1', '2', '+', '3', '4']) {
      await _tapKey(tester, face);
    }
    expect(_displayedExpression(tester), '12+34',
        reason: '五个键面按下去，表达式行上就该是这一串');
    expect(db.savedHistory, isEmpty, reason: '还没按等号，一行都不许写');

    await _tapKey(tester, '✓');
    expect(db.savedHistory, isEmpty,
        reason: '提交要等引擎那一次往返（这里是它超时的 5 秒），历史不该在按下的一瞬间就写好');
    await _submitRoundTrip(tester);

    // 中文：**判据是画在显示面板里的那个数**，不是控制器里那个字段。
    // English: **the criterion is the number painted in the display panel**, not a field on the
    //          controller.
    _expectResultOnScreen(tester, '46');
    expect(db.savedHistory, hasLength(1),
        reason: '等号必须恰好写一行历史（写入次数，不是数据库里查到的行数）');
    expect(db.savedHistory.single.expression, '12+34');
    expect(db.savedHistory.single.result, '46');

    await _tapKey(tester, '✓');
    await _submitRoundTrip(tester);

    expect(db.savedHistory, hasLength(1),
        reason: '第二次等号还是同一个算式：不许再写一行（控制器那道防重复必须接在屏幕上）');
    _expectResultOnScreen(tester, '46');
  });
}

/// 中文：等完一次提交的引擎往返（`engineTimeout` 5 秒）并让界面静下来。
/// English: wait out one submit's engine round trip (`engineTimeout`, 5 s) and let the interface
///          settle.
Future<void> _submitRoundTrip(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await tester.pumpAndSettle();
}

/// 中文：**结果行上的那个数**——键盘上另有一颗同名的数字键，所以查找限定在显示面板里。
/// English: **the number on the result line** — the keypad carries a same-named digit key of its
///          own, so the lookup stays inside the display panel.
void _expectResultOnScreen(WidgetTester tester, String result) {
  expect(
    find.descendant(
      of: find.byType(CalculatorDisplay),
      matching: find.text(result),
    ),
    findsOneWidget,
    reason: '结果 $result 必须真的画在显示面板里',
  );
}

Future<void> _tapKey(WidgetTester tester, String face) async {
  await tester.tap(find.descendant(
    of: find.byType(CalculatorKeypad),
    matching: find.text(face, findRichText: true),
  ));
  await tester.pumpAndSettle();
}

String _displayedExpression(WidgetTester tester) =>
    tester.widget<MathExpressionView>(find.byType(MathExpressionView)).expression;

Widget _page(AppDatabase db) {
  return MaterialApp(
    theme: ThemeData.light(),
    home: Scaffold(
      body: CalculatorPage(
        db: db,
        onOpenSettings: () {},
        settings: const AppSettings(
          haptics: false,
          hapticStrength: '标准',
          restoreState: false,
          autoSaveHistory: true,
          angleMode: 'RAD',
          precision: 6,
          themeModeLabel: '跟随系统',
          expressionDisplayMode: '数学符号',
        ),
      ),
    ),
  );
}

/// 中文：**只记账、不去重**的历史库——「按了两次等号，写了几次」正是这里要量的东西。
/// English: **a history database that only records, never dedups** — "two equals presses, how many
///          writes" is exactly what is being measured here.
class _RecordingDatabase implements AppDatabase {
  final savedHistory = <({String expression, String result})>[];

  @override
  Future<Map<String, String>> settings() async => const {};

  @override
  Future<void> setSettings(Map<String, String> values) async {}

  @override
  Future<void> setSetting(String key, String value) async {}

  @override
  Future<int> addHistory({
    required String expression,
    required String result,
    String? toolId,
    HistoryResultKind? resultKind,
    DateTime? createdAt,
  }) async {
    savedHistory.add((expression: expression, result: result));
    return savedHistory.length;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
