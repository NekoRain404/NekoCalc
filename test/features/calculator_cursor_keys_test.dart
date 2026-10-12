import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/features/calculator/presentation/calculator_page.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/hiper_keypad.dart';
import 'package:nekocalc/features/calculator/presentation/keypad/keypad_definition.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/math_expression_view.dart';

/// 中文：`◀` / `▶` 两颗光标键。**它们不是翻页键**——本文件同时是那条结论的可执行记录：HiPER 的命令
///       表里只有 `CHAR_LEFT`/`CHAR_RIGHT`（"Move cursor one char left/right"），没有翻页这一个动作，
///       所以这两颗键在屏幕上做的事就是「把光标挪一个字符」。来源与取舍写在 `hiper_keypad.dart`
///       第 1 行那一段。
///
///       三件事分开证，坏掉哪一件都能从红的地方看出来：
///       1. **表里是亮着的**，且带的是光标 id（退回 `dis:`/禁用会红）；
///       2. **按一下真的挪一格**，四个方向与两个边界各一条；
///       3. **不是空转**——若它没被主屏接住，`_pressKey` 的 `default` 会把 id 当字面量写进表达式，
///          这一条正是要抓那个形状。
///
/// English: The `◀` / `▶` cursor keys. **They are not page keys** — this file is also the executable
///          record of that finding: HiPER's command catalogue holds only `CHAR_LEFT`/`CHAR_RIGHT`
///          ("Move cursor one char left/right") and no paging action at all, so what these keys do on
///          screen is move the caret one character. The sources and the trade-off are in
///          `hiper_keypad.dart`'s row-1 note.
///
///          Three things are proved separately, so a break shows up where it happened:
///          1. **the table has them lit**, carrying the cursor ids (going back to `dis:`/disabled
///             turns this red);
///          2. **a tap really moves one cell**, with one case per direction and one per boundary;
///          3. **they are not spinning in place** — an id the screen does not accept falls through
///             `_pressKey`'s `default` and is typed into the expression as a literal, which is the
///             exact shape this catches.
void main() {
  group('HiPER 式主屏 光标键 ◀ ▶', () {
    testWidgets('键位表里两颗都是亮着的，且带的是光标 id 而不是翻页 id', (tester) async {
      final left = _cellByFace('◀');
      final right = _cellByFace('▶');

      // 中文：断言的是**这一刻表里那一格**的启用态与 id，不是测试里写死的常量——把 `◀` 改回
      //       `dis:pagePrev` 或把 enabled 翻回 false，这里就红，与 `keypad_definition_test.dart`
      //       的逐格快照一内一外守着同一件事。
      // English: these assert **the cell's state in the table right now**, not a constant hardcoded in
      //          the test — setting `◀` back to `dis:pagePrev` or flipping enabled back to false turns
      //          this red, guarding the same fact as `keypad_definition_test.dart`'s per-cell snapshot
      //          from the other side.
      expect(left.enabled, isTrue, reason: '`◀` 这一刻还是禁用态');
      expect(right.enabled, isTrue, reason: '`▶` 这一刻还是禁用态');
      expect(left.category, isNot(KeyCategory.disabled),
          reason: '`◀` 这一刻还在 disabled 分类里');
      expect(right.category, isNot(KeyCategory.disabled),
          reason: '`▶` 这一刻还在 disabled 分类里');
      expect(left.id, 'cursorLeft');
      expect(right.id, 'cursorRight');

      // 中文：主屏必须声称自己接得住这两个 id，否则「表里亮着、屏幕上没人接」——那正是禁用态
      //       想避免的那件事，只是换了个方向。
      // English: the screen must claim both ids, or the table is lit while nothing accepts the press —
      //          exactly what the disabled state was there to prevent, only the other way round.
      expect(CalculatorPage.dispatchedKeyIds, contains('cursorLeft'));
      expect(CalculatorPage.dispatchedKeyIds, contains('cursorRight'));
    });

    testWidgets('按 ◀ 把光标左移一个字符', (tester) async {
      await _pumpScreen(tester);
      await _type(tester, <String>['1', '2', '3']);
      expect(_caret(tester), 3, reason: '打三个数字之后光标应停在末尾');

      await _tapKey(tester, '◀');

      expect(_caret(tester), 2, reason: '按一下 ◀ 应左移**一格**，不是一格也不动、也不是到开头');
      expect(_displayedExpression(tester), '123',
          reason: '光标键只动光标，表达式一个字符都不该变');
    });

    testWidgets('按 ▶ 把光标右移一个字符', (tester) async {
      await _pumpScreen(tester);
      await _type(tester, <String>['1', '2', '3']);
      await _tapKey(tester, '◀');
      await _tapKey(tester, '◀');
      expect(_caret(tester), 1);

      await _tapKey(tester, '▶');

      expect(_caret(tester), 2, reason: '按一下 ▶ 应右移**一格**');
      expect(_displayedExpression(tester), '123');
    });

    testWidgets('光标已经在开头时按 ◀ 是空操作，不抛异常也不改动任何东西', (tester) async {
      await _pumpScreen(tester);
      await _type(tester, <String>['7']);
      await _tapKey(tester, '◀');
      expect(_caret(tester), 0, reason: '一个字符的表达式，按一下 ◀ 就应停在开头');

      await _tapKey(tester, '◀');

      // 中文：这里就是「失败要闭」那一条——开头没有可去的位置，正确的行为是**什么都不做**，
      //       而不是绕回末尾、不是清空、不是报错。屏幕上的光标本来就停在 0，用户看到的是实情。
      // English: this is the fail-closed case — there is nowhere to go at position 0, so the right
      //          behaviour is to do **nothing**: not wrap to the end, not clear, not throw. The caret on
      //          screen is already at 0, so what the user sees is the truth.
      expect(tester.takeException(), isNull, reason: '在开头按 ◀ 抛了异常');
      expect(_caret(tester), 0, reason: '在开头按 ◀ 把光标挪走了');
      expect(_displayedExpression(tester), '7', reason: '在开头按 ◀ 改动了表达式');
    });

    testWidgets('光标已经在末尾时按 ▶ 是空操作', (tester) async {
      await _pumpScreen(tester);
      await _type(tester, <String>['4', '2']);
      expect(_caret(tester), 2);

      await _tapKey(tester, '▶');

      expect(tester.takeException(), isNull, reason: '在末尾按 ▶ 抛了异常');
      expect(_caret(tester), 2, reason: '在末尾按 ▶ 把光标挪走了');
      expect(_displayedExpression(tester), '42');
    });

    testWidgets('两颗键都不是空转：按下去不会把 id 当字面量写进表达式', (tester) async {
      await _pumpScreen(tester);
      await _type(tester, <String>['5', '6']);
      await _tapKey(tester, '◀');
      await _tapKey(tester, '▶');

      // 中文：主屏的 `default` 分支按字面量输入未知 id，所以「没接住的键」在屏幕上留下的是它自己的
      //       id。表达式里出现 `cursorLeft`/`cursorRight` 就说明这两颗键没人接——它们看起来能按，
      //       实际什么也没做。两条断言合起来才能把「按下去没反应」与「按下去把 id 打上屏」分开。
      // English: the screen's `default` branch types an unknown id verbatim, so a key nothing accepts
      //          leaves its own id on screen. Seeing `cursorLeft`/`cursorRight` in the expression means
      //          nobody accepted the press — the key looks tappable and does nothing. Only together do
      //          these two assertions separate "pressed, nothing happened" from "pressed, id typed".
      expect(_displayedExpression(tester), '56');
      expect(_displayedExpression(tester), isNot(contains('cursor')));
    });

    testWidgets('开机恢复的非折叠选区：按 ◀ 只左移一个字，不是跳到选区起点', (tester) async {
      // 中文：**这条钉的正是用户报的那一条。** 非折叠选区能在屏幕上存在而一个高亮都不画——主显示区
      //       只有 `MathExpressionView` 的那一根光标条（位置 = `cursorIndex` = 选区末端），于是
      //       「按 ◀ 跳到选区起点」在用户眼里就是「按一下直接到开头」。而选区是**从盘上恢复的**：
      //       `restoreState` 打开时 `_persistState` 一直在存 `calculator_selection_start/end`，
      //       开机后 `restoreIfEnabled()` 原样装回，第一次按键就撞上——用户完全看不出为什么。
      // English: **this pins the exact report.** A non-collapsed selection can exist on screen without
      //          drawing a single highlight — the display band has only `MathExpressionView`'s caret
      //          (at `cursorIndex` = the selection's end) — so "◀ jumps to the selection's start"
      //          reads to the user as "one press goes straight to the beginning". And the selection is
      //          **restored from disk**: while `restoreState` is on, `_persistState` always writes
      //          `calculator_selection_start/end`, `restoreIfEnabled()` puts it back after launch, and
      //          the first keypress meets it — with nothing on screen to explain it.
      await _pumpRestoredScreen(
        tester,
        expression: '12345',
        selectionStart: 1,
        selectionEnd: 4,
      );
      expect(_caret(tester), 4, reason: '恢复后屏幕上的那根光标条画在选区末端');

      await _tapKey(tester, '◀');

      expect(_caret(tester), 3,
          reason: '按一下 ◀ 只左移一个字（从屏幕上那根光标处算），不是跳到选区起点 1');
      expect(_displayedExpression(tester), '12345',
          reason: '光标键只动光标，表达式一个字符都不该变');
    });

    testWidgets('开机恢复的非折叠选区：按 ▶ 只右移一个字，不是钉在选区末端', (tester) async {
      await _pumpRestoredScreen(
        tester,
        expression: '12345',
        selectionStart: 1,
        selectionEnd: 4,
      );
      expect(_caret(tester), 4, reason: '恢复后屏幕上的那根光标条画在选区末端');

      await _tapKey(tester, '▶');

      expect(_caret(tester), 5,
          reason: '按一下 ▶ 只右移一个字；旧行为是把光标塌到选区末端——与按之前同一个位置，等于没动');
      expect(_displayedExpression(tester), '12345',
          reason: '光标键只动光标，表达式一个字符都不该变');
    });
  });
}

/// 中文：按**键面文字**点一颗键——走的是真机那条路（`InkWell.onTap`），所以禁用键会在这里暴露：
///       禁用的键根本不挂 `onTap`，点下去什么也不会发生。测试要的是「这颗键是亮的、按得动」，
///       而不是「它的 id 直接调回调时有效」。
/// English: Taps a key **by its face text**, i.e. the device's own path (`InkWell.onTap`), so a disabled
///          key shows up right here: a disabled key carries no `onTap` at all and the tap does nothing.
///          What is being proved is "this key is lit and pressable", not "its id works when handed
///          straight to the callback".
Future<void> _tapKey(WidgetTester tester, String face) async {
  await tester.tap(find.text(face));
  await tester.pump();
}

/// 中文：用键面文字依次按一串键（数字键），把表达式打出来。每一步之后 `pump`，让显示区跟上。
/// English: Presses a run of keys by face text (digits) to build the expression, pumping after each so
///          the display band keeps up.
Future<void> _type(WidgetTester tester, List<String> faces) async {
  for (final face in faces) {
    await _tapKey(tester, face);
  }
}

Future<void> _pumpScreen(WidgetTester tester) async {
  await tester.pumpWidget(_testApp());
  await tester.pumpAndSettle();
}

/// 中文：显示区这一刻画出来的光标下标。**这是屏幕上那根光标条的位置**，不是控制器里的一个数——
///       `CalculatorDisplay` 把它交给 `MathExpressionView` 画出来，所以断言它等于断言用户看到的。
/// English: the caret index the display band is drawing right now. **This is where the caret bar is on
///          screen**, not a number inside the controller — `CalculatorDisplay` hands it to
///          `MathExpressionView` to draw, so asserting on it is asserting on what the user sees.
int? _caret(WidgetTester tester) =>
    tester.widget<MathExpressionView>(find.byType(MathExpressionView)).cursorIndex;

String _displayedExpression(WidgetTester tester) =>
    tester.widget<MathExpressionView>(find.byType(MathExpressionView)).expression;

/// 中文：在**键位表**里按键面文字查那一格这一刻的 id、启用态与分类（与
///       `calculator_page_hiper_engine_test.dart` 里同名的那一只同一套规矩：查不到就抛）。
/// English: Looks a cell up **in the key table** by face text and returns the id, enabled state and
///          category it carries right now (same rule as the helper of that name in
///          `calculator_page_hiper_engine_test.dart`: a failed lookup throws).
({String id, bool enabled, KeyCategory category}) _cellByFace(String face) {
  for (final row in hiperKeypad.rows) {
    for (final key in row.keys) {
      if (key.base.label == face) {
        return (
          id: key.base.id,
          enabled: key.base.enabled,
          category: key.category,
        );
      }
    }
    for (final label in row.labels) {
      if (label is InlineKey && label.key.base.label == face) {
        return (
          id: label.key.base.id,
          enabled: label.key.base.enabled,
          category: label.key.category,
        );
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
          groupThousands: false,
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

/// 中文：带一份**已落盘状态**的主屏：表达式、一个非折叠选区 `[selectionStart, selectionEnd)`、
///       恢复开关打开——开机后 `restoreIfEnabled()` 会把它原样装回控制器，与用户重启 App 之后
///       看到的那一刻同形（屏幕上只有一根画在选区末端的光标条，没有任何高亮）。
/// English: the main screen with **persisted state on disk**: the expression, a non-collapsed selection
///          `[selectionStart, selectionEnd)` and restore switched on — after launch
///          `restoreIfEnabled()` puts it back into the controller exactly as a real restart leaves it
///          (a single caret drawn at the selection's end, no highlight anywhere).
Future<void> _pumpRestoredScreen(
  WidgetTester tester, {
  required String expression,
  required int selectionStart,
  required int selectionEnd,
}) async {
  await tester.pumpWidget(
    _restoredApp(expression, selectionStart, selectionEnd),
  );
  await tester.pumpAndSettle();
}

Widget _restoredApp(String expression, int selectionStart, int selectionEnd) {
  return MaterialApp(
    theme: ThemeData.light(),
    home: Scaffold(
      body: CalculatorPage(
        db: _SeededDatabase(<String, String>{
          'restore_state': 'true',
          'calculator_expression': expression,
          'calculator_result': '0',
          'calculator_angle': 'RAD',
          'calculator_memory': '0',
          'calculator_cursor': '$selectionEnd',
          'calculator_selection_start': '$selectionStart',
          'calculator_selection_end': '$selectionEnd',
        }),
        onOpenSettings: () {},
        settings: const AppSettings(
          haptics: false,
          hapticStrength: '标准',
          restoreState: true,
          autoSaveHistory: false,
          angleMode: 'RAD',
          precision: 6,
          themeModeLabel: '跟随系统',
          expressionDisplayMode: '数学符号',
          groupThousands: false,
        ),
      ),
    ),
  );
}

/// 中文：一份**先有内容**的设置表（`restore_state` 与上次会话的表达式、光标、选区都写在里面），
///       写入照常落回这张表——恢复路径读的就是它。
/// English: a settings table that **starts out populated** (restore switch, the last session's
///          expression, cursor and selection); writes land back in the same table — the restore path
///          reads exactly this.
class _SeededDatabase implements AppDatabase {
  _SeededDatabase(this._settings);

  final Map<String, String> _settings;

  @override
  Future<Map<String, String>> settings() async => _settings;

  @override
  Future<void> setSettings(Map<String, String> values) async {
    _settings.addAll(values);
  }

  @override
  Future<void> setSetting(String key, String value) async {
    _settings[key] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
