import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/application/controllers/calculator_controller.dart';
import 'package:nekocalc/core/math/math_result.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/repositories/history_repository.dart';
import 'package:nekocalc/data/repositories/notes_repository.dart';
import 'package:nekocalc/data/repositories/settings_repository.dart';

/// 中文：结果三形态在重启时的判别（3c 评审的第 3 条）。
///
///       判别依据是**十进制键在不在**，不是值空不空：旧行（拆分之前写的）没有这个键，要从显示
///       文本推导；新行只要写下了这个键，哪怕值是空串，也代表「这一次没有十进制形态」这个事实
///       本身，必须原样保留。
///
/// English: How the three forms are told apart across a restart (finding 3 of the 3c review).
///
///          The discriminator is whether the decimal *key* exists, not whether its value is empty:
///          a row written before the split has no such key and derives its decimal from the display
///          text; a new row that wrote the key — even with an empty value — is recording the fact
///          "there is no decimal form this time", and that has to survive as it stands.
void main() {
  test('a row with an empty decimal field keeps it empty after a restart',
      () async {
    // 中文：`calculator_result_decimal` **键在、值为空**：引擎这一次没有给出十进制形态，而显示
    //       形态恰好是一个能解析成数字的字符串。若按值空不空来判别，重启后十进制形态会被从显示
    //       文本重新推导出来——一个引擎从没给过的数字。
    // English: The `calculator_result_decimal` *key is present with an empty value*: the engine
    //          produced no decimal form this time, while the display form happens to be a string
    //          that parses as a number. Judging by the value's emptiness would re-derive the decimal
    //          form from the display text after the restart — a number the engine never produced.
    final db = _FakeDatabase()
      ..savedSettings.addAll({
        'restore_state': 'true',
        'angle_mode': '弧度',
        'digits': '6 位',
        'calculator_expression': '',
        'calculator_result': '42',
        'calculator_result_tex': r'6 \times 7',
        'calculator_result_decimal': '',
        'calculator_angle': 'RAD',
        'calculator_memory': '0',
      });
    final controller = _controller(db);

    await controller.reloadSettingsAndRestore();

    expect(controller.result, '42');
    expect(controller.resultTex, r'6 \times 7');
    expect(controller.resultDecimal, isEmpty);

    // 中文：`Ans`/`last` 因此不再解析得到——与「引擎没有给出十进制形态」时的行为一致，而不是
    //       悄悄用显示文本顶上。
    // English: `Ans`/`last` therefore stop resolving — the same behaviour as whenever the engine
    //          produced no decimal form, rather than quietly substituting the display text.
    controller.setExpression('ans + 1');
    expect(controller.evaluate, returnsNormally);
    expect(controller.hasError, isTrue);

    controller.dispose();
  });

  test('a row written before the split still derives its decimal', () async {
    // 中文：没有十进制键的旧行，行为与拆分前逐字节一致。
    // English: An old row with no decimal key behaves byte-for-byte as it did before the split.
    final db = _FakeDatabase()
      ..savedSettings.addAll({
        'restore_state': 'true',
        'angle_mode': '弧度',
        'digits': '6 位',
        'calculator_expression': '',
        'calculator_result': '1,234.5',
        'calculator_angle': 'RAD',
        'calculator_memory': '0',
      });
    final controller = _controller(db);

    await controller.reloadSettingsAndRestore();

    expect(controller.result, '1,234.5');
    expect(controller.resultDecimal, '1234.5');
    expect(controller.reusableResult, '1234.5');

    controller.dispose();
  });

  test('every persisted result writes the decimal key, even when it is empty',
      () async {
    // 中文：判别依据能成立的前提——新行**一定**会写下这个键。空十进制被写成一个空值，而不是
    //       被省略，否则下一次启动又会退回到「没有键」那条推导分支。
    // English: What makes the discriminator work — a new row *always* writes the key. An empty
    //          decimal is written as an empty value rather than omitted, or the next launch would
    //          fall back into the "no key" derivation branch again.
    final db = _FakeDatabase()
      ..savedSettings.addAll({
        'restore_state': 'true',
        'angle_mode': '弧度',
        'digits': '6 位',
      });
    final controller = _controller(db);
    await controller.reloadSettingsAndRestore();

    // 中文：装上「精确形式 + 没有十进制形态」的结果，再用一个会落盘的动作把它写下去
    //       （`applyMathResult` 只改状态、不落盘，它是给引擎接线用的那个写入点）。
    // English: Install an "exact form with no decimal form" result, then persist it with an action
    //          that writes state (`applyMathResult` only changes state and does not persist — it is
    //          the write point the engine wiring uses).
    controller.applyMathResult(const MathResult(displayText: r'4\sqrt{2}'));
    controller.memoryAdd();
    await Future<void>.delayed(Duration.zero);

    expect(db.savedSettings.containsKey('calculator_result_decimal'), isTrue);
    expect(db.savedSettings['calculator_result_decimal'], isEmpty);
    expect(db.savedSettings['calculator_result'], r'4\sqrt{2}');
    expect(db.savedSettings['calculator_result_tex'], isEmpty);

    controller.dispose();
  });
}

CalculatorController _controller(_FakeDatabase db) {
  return CalculatorController(
    historyRepository: HistoryRepository(db),
    notesRepository: NotesRepository(db),
    settingsRepository: SettingsRepository(db),
    settings: const AppSettings(
      haptics: true,
      hapticStrength: '标准',
      restoreState: true,
      autoSaveHistory: false,
      angleMode: 'RAD',
      precision: 6,
      themeModeLabel: '跟随系统',
      expressionDisplayMode: '数学符号',
    ),
  );
}

class _FakeDatabase implements AppDatabase {
  final savedSettings = <String, String>{};

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
    return Map<String, String>.from(savedSettings);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
