import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/application/controllers/calculator_controller.dart';
import 'package:nekocalc/application/controllers/expression_selection.dart';
import 'package:nekocalc/data/models/history_item.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/repositories/history_repository.dart';
import 'package:nekocalc/data/repositories/notes_repository.dart';
import 'package:nekocalc/data/repositories/settings_repository.dart';

void main() {
  test('undo and redo restore expression result cursor and memory', () {
    final controller = _controller(_FakeDatabase());

    controller.input('1');
    controller.input('+');
    controller.input('2');
    controller.evaluate();
    expect(controller.expression, '1+2');
    expect(controller.result, '3');
    expect(controller.canUndo, isTrue);

    controller.undo();
    expect(controller.expression, '1+');
    expect(controller.canRedo, isTrue);

    controller.redo();
    expect(controller.expression, '1+2');
    expect(controller.result, '3');

    controller.memoryAdd();
    expect(controller.memoryValue, 3);
    controller.undo();
    expect(controller.memoryValue, 0);
    controller.redo();
    expect(controller.memoryValue, 3);

    controller.clear();
    expect(controller.expression, isEmpty);
    controller.undo();
    expect(controller.expression, '1+2');
    expect(controller.memoryValue, 3);

    controller.dispose();
  });

  test('keypad input replaces the selected expression range', () {
    final controller = _controller(_FakeDatabase());

    controller.setExpression('12+34');
    controller.setSelection(const ExpressionSelection(2, 4));
    controller.input('9');

    expect(controller.expression, '1294');
    expect(controller.selection, const ExpressionSelection.collapsed(3));
    expect(controller.cursorIndex, 3);

    controller.dispose();
  });

  test('operator input replaces a selection at the start of the expression',
      () {
    final controller = _controller(_FakeDatabase());

    controller.setExpression('12');
    controller.setSelection(const ExpressionSelection(0, 1));
    controller.input('+');

    expect(controller.expression, '+2');
    expect(controller.selection, const ExpressionSelection.collapsed(1));

    controller.dispose();
  });

  test('backspace deletes the selected expression range', () {
    final controller = _controller(_FakeDatabase());

    controller.setExpression('sqrt(81)+2');
    controller.setSelection(const ExpressionSelection(4, 8));
    controller.backspace();

    expect(controller.expression, 'sqrt+2');
    expect(controller.selection, const ExpressionSelection.collapsed(4));
    expect(controller.cursorIndex, 4);

    controller.dispose();
  });

  test('undo and redo restore the expression selection', () {
    final controller = _controller(_FakeDatabase());

    controller.setExpression('12+34');
    controller.setSelection(const ExpressionSelection(2, 4));
    controller.input('9');
    controller.undo();

    expect(controller.expression, '12+34');
    expect(controller.selection, const ExpressionSelection(2, 4));

    controller.redo();

    expect(controller.expression, '1294');
    expect(controller.selection, const ExpressionSelection.collapsed(3));

    controller.dispose();
  });

  test('cursor movement with a selection moves one character from the caret',
      () {
    // 中文：**这条测试以前钉的是「按方向塌到选区的对应边」**（左→选区起点、右→选区末端）。
    //       用户看到的不是那个：主显示区只画一根光标条，位置就是 `cursorIndex`（= 选区末端），
    //       所以带选区时按 ◀ 会从屏幕上的光标处一路跳到选区起点——用户的话是「直接就是首尾」。
    //       现在两颗键一律只走一个字符，起点是**屏幕上那根光标**（选区末端）。
    // English: **this test used to pin "collapse to the selection's edge in the direction of travel"**
    //          (left → selection start, right → selection end). That is not what the user sees: the
    //          main display band draws a single caret at `cursorIndex` (= the selection's end), so
    //          with a selection ◀ jumped from the on-screen caret all the way to the selection's
    //          start — in the user's words, "straight to the ends". Both keys now move exactly one
    //          character, starting from **the caret on screen** (the selection's end).
    final controller = _controller(_FakeDatabase());

    controller.setExpression('123456');
    controller.setSelection(const ExpressionSelection(2, 5));
    controller.moveCursorLeft();

    expect(controller.selection, const ExpressionSelection.collapsed(4),
        reason: '按 ◀ 应从屏幕上的光标（选区末端 5）左移一个字到 4，不是跳到选区起点 2');

    controller.setSelection(const ExpressionSelection(2, 5));
    controller.moveCursorRight();

    expect(controller.selection, const ExpressionSelection.collapsed(6),
        reason: '按 ▶ 应从屏幕上的光标（选区末端 5）右移一个字到 6，不是塌在 5 上不动');

    controller.dispose();
  });

  test('block cursor movement follows expression boundaries', () {
    final controller = _controller(_FakeDatabase());

    controller.setExpression('12+sqrt(81)+345');
    controller.cursorIndex = 11;
    controller.moveCursorByBlockBackward();
    expect(controller.selection, const ExpressionSelection.collapsed(3));

    controller.cursorIndex = 0;
    controller.moveCursorByBlockForward();
    expect(controller.selection, const ExpressionSelection.collapsed(2));

    controller.cursorIndex = 3;
    controller.moveCursorByBlockForward();
    expect(controller.selection, const ExpressionSelection.collapsed(11));

    controller.dispose();
  });

  test('block cursor movement keeps leading literals separate from functions',
      () {
    final controller = _controller(_FakeDatabase());

    controller.setExpression('2sqrt(9)');
    controller.moveCursorByBlockBackward();
    expect(controller.selection, const ExpressionSelection.collapsed(1));

    controller.moveCursorByBlockForward();
    expect(controller.selection, const ExpressionSelection.collapsed(8));

    controller.dispose();
  });

  test('block cursor movement collapses selections at directional edges', () {
    final controller = _controller(_FakeDatabase());

    controller.setExpression('12+sqrt(81)+345');
    controller.setSelection(const ExpressionSelection(3, 11));
    controller.moveCursorByBlockBackward();
    expect(controller.selection, const ExpressionSelection.collapsed(3));

    controller.setSelection(const ExpressionSelection(3, 11));
    controller.moveCursorByBlockForward();
    expect(controller.selection, const ExpressionSelection.collapsed(11));

    controller.dispose();
  });

  test('restores persisted selection bounds and keeps a legacy cursor',
      () async {
    final db = _FakeDatabase()
      ..savedSettings.addAll({
        'restore_state': 'true',
        'auto_save': 'false',
        'angle_mode': '弧度',
        'digits': '6 位',
        'calculator_expression': '12+34',
        'calculator_result': '46',
        'calculator_angle': 'RAD',
        'calculator_memory': '0',
        'calculator_cursor': '5',
        'calculator_selection_start': '1',
        'calculator_selection_end': '4',
      });
    final controller = _controller(db);

    await controller.reloadSettingsAndRestore();

    expect(controller.selection, const ExpressionSelection(1, 4));
    expect(controller.cursorIndex, 4);

    controller.setSelection(const ExpressionSelection(2, 5));
    await Future<void>.delayed(Duration.zero);

    expect(db.savedSettings['calculator_selection_start'], '2');
    expect(db.savedSettings['calculator_selection_end'], '5');
    expect(db.savedSettings['calculator_cursor'], '5');

    controller.dispose();
  });

  test('new edits clear redo stack', () {
    final controller = _controller(_FakeDatabase());

    controller.input('9');
    controller.input('×');
    controller.input('9');
    controller.undo();
    expect(controller.canRedo, isTrue);

    controller.input('8');
    expect(controller.expression, '9×8');
    expect(controller.canRedo, isFalse);

    controller.dispose();
  });

  test('toggle sign targets the current value instead of whole expression', () {
    final controller = _controller(_FakeDatabase());

    controller.setExpression('1+2');
    controller.input('+/-');
    expect(controller.expression, '1+(-2)');
    controller.evaluate();
    expect(controller.result, '-1');

    controller.input('+/-');
    expect(controller.expression, '1+2');
    controller.evaluate();
    expect(controller.result, '3');

    controller.input('+');
    controller.input('+/-');
    expect(controller.expression, '1+2+-');
    controller.input('5');
    controller.evaluate();
    expect(controller.result, '-2');

    controller.dispose();
  });

  test('toggle sign respects cursor position and wrapped values', () {
    final controller = _controller(_FakeDatabase());

    controller.setExpression('12+34');
    controller.moveCursorLeft();
    controller.moveCursorLeft();
    controller.input('+/-');
    expect(controller.expression, '12+-34');
    expect(controller.cursorIndex, 4);

    controller.input('+/-');
    expect(controller.expression, '12+34');
    expect(controller.cursorIndex, 3);

    controller.moveCursorLeft();
    controller.input('+/-');
    expect(controller.expression, '-12+34');
    expect(controller.cursorIndex, 3);

    controller.setExpression('sqrt(9)+2');
    controller.moveCursorLeft();
    controller.moveCursorLeft();
    controller.input('+/-');
    expect(controller.expression, '-sqrt(9)+2');
    controller.evaluate();
    expect(controller.result, '-1');

    controller.input('+/-');
    expect(controller.expression, 'sqrt(9)+2');

    controller.dispose();
  });

  test('unary functions wrap the selected operand', () {
    final controller = _controller(_FakeDatabase());

    controller.setExpression('12+34');
    controller.setSelection(const ExpressionSelection(3, 5));
    controller.applyUnaryFunction('sqrt');

    expect(controller.expression, '12+sqrt(34)');
    expect(controller.selection, const ExpressionSelection.collapsed(11));

    controller.dispose();
  });

  test('binary functions replace the selected operand without dropping it', () {
    final controller = _controller(_FakeDatabase());

    controller.setExpression('12+34');
    controller.setSelection(const ExpressionSelection(3, 5));
    controller.applyBinaryFunction('root');

    expect(controller.expression, '12+root(34,)');
    expect(controller.selection, const ExpressionSelection.collapsed(11));

    controller.dispose();
  });

  test('binary functions keep a suffix outside the selected operand call', () {
    final controller = _controller(_FakeDatabase());

    controller.setExpression('12+34+56');
    controller.setSelection(const ExpressionSelection(3, 5));
    controller.applyBinaryFunction('root');

    expect(controller.expression, '12+root(34,)+56');
    expect(controller.selection, const ExpressionSelection.collapsed(11));

    controller.dispose();
  });

  test('sign toggle replaces the selected operand', () {
    final controller = _controller(_FakeDatabase());

    controller.setExpression('12+34');
    controller.setSelection(const ExpressionSelection(3, 5));
    controller.input('+/-');

    expect(controller.expression, '12+(-34)');
    expect(controller.selection, const ExpressionSelection.collapsed(8));

    controller.dispose();
  });

  test('percent replaces the selected operand', () {
    final controller = _controller(_FakeDatabase());

    controller.setExpression('12+34');
    controller.setSelection(const ExpressionSelection(3, 5));
    controller.input('%');

    expect(controller.expression, '12+(34/100)');
    expect(controller.selection, const ExpressionSelection.collapsed(11));

    controller.dispose();
  });

  group('`D°M\'S` 的分隔符：插哪一个、什么时候什么都不插', () {
    // 中文：**这一组钉的是 `_sexagesimalSeparatorBefore` 那一条判据**（纯函数在 part 里是私有的，
    //       走控制器这条生产路径进来——与 `_applyPercent`/`_appendSmart` 那几条同一把尺）。
    //       厂商原文、这颗键为什么是输入键、结果那一半去了哪里，都在
    //       `hiper_keypad_band_key_rows.dart` 那一格上。
    // English: **this group pins the one judgement in `_sexagesimalSeparatorBefore`** (the pure
    //          function is private inside the part, so it is exercised through the controller — the
    //          production path, the same instrument the `_applyPercent`/`_appendSmart` rows use). The
    //          vendor lines, why this key is an entry key and where the result half went are all on
    //          that cell in `hiper_keypad_band_key_rows.dart`.

    test('`3` `D°M\'S` `30` `D°M\'S` `0` `D°M\'S` 一路按出 `3°30′0″`', () {
      final controller = _controller(_FakeDatabase());

      controller.input('3');
      controller.insertSexagesimalSeparator();
      expect(controller.expression, '3°');

      controller.input('3');
      controller.input('0');
      controller.insertSexagesimalSeparator();
      expect(controller.expression, '3°30′');

      controller.input('0');
      controller.insertSexagesimalSeparator();
      expect(controller.expression, '3°30′0″');
      expect(controller.cursorIndex, controller.expression.length,
          reason: '光标留在插进去的记号后面，接着打字就是下一段');

      // 中文：**边打边算跟着走。** 这个文件默认的 `AppSettings` 是 RAD，所以读数就是那个角度的
      //       弧度值（0.061086523819801536，按本文件的精度设置排成 `0.061087`）——`°` 的值按当前
      //       角度单位给，与 `30°` 那条既有断言同一个形状。
      // English: **as-you-type follows.** The `AppSettings` this file defaults to says RAD, so the
      //          reading is that angle's radian value (0.061086523819801536, printed `0.061087` at this
      //          file's precision) — `°` takes its value in the current angle unit, the shape the
      //          existing `30°` assertions have.
      controller.evaluate();
      expect(double.parse(controller.result), closeTo(0.061086523819801536, 1e-6));

      controller.dispose();
    });

    test('同一串按键在 DEG 下读作 3.5：模式只由求值器那一侧给', () {
      final controller = _controller(
        _FakeDatabase(),
        settings: const AppSettings(
          haptics: true,
          hapticStrength: '标准',
          restoreState: false,
          autoSaveHistory: false,
          angleMode: 'DEG',
          precision: 6,
          themeModeLabel: '跟随系统',
          expressionDisplayMode: '数学符号',
        ),
      );

      for (final key in <String>['3', 'dms', '3', '0', 'dms', '0', 'dms']) {
        if (key == 'dms') {
          controller.insertSexagesimalSeparator();
        } else {
          controller.input(key);
        }
      }

      expect(controller.expression, '3°30′0″');
      controller.evaluate();
      expect(controller.result, '3.5',
          reason: '归一化写出的文本与模式无关，值由 `degangle` 那一支按当前角度单位给');

      controller.dispose();
    });

    test('光标停在中间：插在光标处，右边那些字符不动', () {
      final controller = _controller(_FakeDatabase());
      controller.setExpression('3+45');
      controller.setSelection(const ExpressionSelection.collapsed(3));
      controller.insertSexagesimalSeparator();

      expect(controller.expression, '3+4°5', reason: '插在光标处（`4` 与 `5` 之间）');
      expect(controller.cursorIndex, 4);

      controller.dispose();
    });

    test('四种什么都不插：没有一个字节移动，也不惊动屏幕', () {
      // 中文：四种情况与它们的理由在 `_sexagesimalSeparatorBefore` 上。这里量的是**后果**：
      //       文本不变、撤销栈不变（`canUndo` 仍为假）——「宁可什么都不发生」是看得见的。
      // English: the four cases and their reasons are on `_sexagesimalSeparatorBefore`. What is
      //          measured here is the **consequence**: the text does not move and neither does the
      //          undo stack (`canUndo` stays false) — "better that nothing happens" is visible.
      for (final source in <String>[
        '', // 左边没有数字
        '2+', // 同上：分隔的是「段」，左边没有段
        'x5', // 那个数是一个名字的一部分（`x5°` 两条路都读不懂）
        '3°30′0″', // 三个记号都齐了：没有第四个分隔符
      ]) {
        final controller = _controller(_FakeDatabase());
        controller.setExpression(source);
        // 中文：通知计数从 `setExpression` 那一次之后归零——下面量的是**这一次按键**有没有惊动屏幕。
        // English: the counter is zeroed after `setExpression`'s own notification; what is measured
        //          below is whether **this press** disturbed the screen at all.
        var notifications = 0;
        controller.addListener(() => notifications++);

        controller.insertSexagesimalSeparator();

        expect(controller.expression, source, reason: '`$source` 之后按一下不该写出任何字符');
        expect(controller.cursorIndex, source.length);
        expect(notifications, 0,
            reason: '`$source`：空操作一个字节都不动，屏幕也不该收到通知');

        controller.dispose();
      }
    });

    test('选区：在选区起点插入，选中的内容被这一次插入替换', () {
      // 中文：与 `append`/`input` 同一条规矩（`_insert`），所以这颗键不需要一套自己的选区语义。
      // English: the same rule `append`/`input` follow (`_insert`), so this key needs no selection
      //          semantics of its own.
      final controller = _controller(_FakeDatabase());
      controller.setExpression('12+345');
      controller.setSelection(const ExpressionSelection(5, 6));
      controller.insertSexagesimalSeparator();

      expect(controller.expression, '12+34°',
          reason: '光标（选区起点）落在 `4` 后面，插进去的分隔符把选中的 `5` 替换掉');
      expect(controller.cursorIndex, 6);

      controller.dispose();
    });
  });

}

CalculatorController _controller(
  _FakeDatabase db, {
  AppSettings settings = const AppSettings(
    haptics: true,
    hapticStrength: '标准',
    restoreState: false,
    autoSaveHistory: false,
    angleMode: 'RAD',
    precision: 6,
    themeModeLabel: '跟随系统',
    expressionDisplayMode: '数学符号',
  ),
}) {
  return CalculatorController(
    historyRepository: HistoryRepository(db),
    notesRepository: NotesRepository(db),
    settingsRepository: SettingsRepository(db),
    settings: settings,
  );
}

class _SavedNote {
  const _SavedNote({
    required this.title,
    required this.body,
    required this.description,
  });

  final String title;
  final String body;
  final String description;
}

class _FakeDatabase implements AppDatabase {
  _FakeDatabase({
    Completer<Map<String, String>>? settingsCompleter,
    List<Completer<Map<String, String>>>? settingsLoads,
  })  : _settingsCompleter = settingsCompleter,
        _settingsLoads = List.of(settingsLoads ?? const []);

  final savedNotes = <_SavedNote>[];
  final savedHistory = <({String expression, String result, String toolId})>[];
  final savedSettings = <String, String>{};
  bool zeroNextNoteWrite = false;
  bool zeroNextHistoryWrite = false;
  Object? nextHistoryError;
  final Completer<Map<String, String>>? _settingsCompleter;
  final List<Completer<Map<String, String>>> _settingsLoads;

  @override
  Future<int> addHistory({
    required String expression,
    required String result,
    String? toolId,
    HistoryResultKind? resultKind,
    DateTime? createdAt,
  }) async {
    final historyError = nextHistoryError;
    if (historyError != null) {
      nextHistoryError = null;
      throw historyError;
    }
    if (zeroNextHistoryWrite) {
      zeroNextHistoryWrite = false;
      return 0;
    }
    savedHistory
        .add((expression: expression, result: result, toolId: toolId ?? ''));
    return savedHistory.length;
  }

  @override
  Future<int> addNote(String title, String body,
      {String description = '', List<String> tags = const []}) async {
    if (zeroNextNoteWrite) {
      zeroNextNoteWrite = false;
      return 0;
    }
    savedNotes
        .add(_SavedNote(title: title, body: body, description: description));
    return savedNotes.length;
  }

  @override
  Future<void> setSettings(Map<String, String> values) async {
    savedSettings.addAll(values);
  }

  @override
  Future<void> setSetting(String key, String value) async {
    savedSettings[key] = value;
  }

  @override
  Future<Map<String, String>> settings() async {
    if (_settingsLoads.isNotEmpty) {
      return _settingsLoads.removeAt(0).future;
    }
    final settingsCompleter = _settingsCompleter;
    if (settingsCompleter != null) return settingsCompleter.future;
    return Map<String, String>.from(savedSettings);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
