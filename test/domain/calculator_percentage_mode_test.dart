import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/application/controllers/calculator_controller.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/repositories/history_repository.dart';
import 'package:nekocalc/data/repositories/notes_repository.dart';
import 'package:nekocalc/data/repositories/settings_repository.dart';

/// 中文：**设置里的 `percentage_mode` 真的接到了求值那两条路上吗。** 解析器自己的两种读法由
///       `test/core/math/percentage_expansion_test.dart` 钉住；这一条钉的是**接线**：
///       控制器把 `_settings.percentageMode` 交给了 `_askEngineTranslated` 与 `_calculateResult`，
///       于是屏幕上（以及记忆寄存器里）的数跟着这个令牌走。漏传一处，两条路就会各按各的读法算。
///
///       这个测试里没有引擎（`flutter test` 下原生通道缺席，`QalculateMathEngine` 回一条失败回执），
///       所以答案来自旧解析器那条回落路——**正是 `_calculateResult` 那一处**。
/// English: **does the `percentage_mode` setting actually reach the two evaluating roads.** The
///          parser's two readings are pinned by `test/core/math/percentage_expansion_test.dart`; what
///          this pins is the **wiring**: the controller hands `_settings.percentageMode` to
///          `_askEngineTranslated` and `_calculateResult`, so the number on screen (and in the memory
///          register) follows that token. Miss one of them and the two roads compute under different
///          readings.
///
///          There is no engine here (the native channel is absent under `flutter test` and
///          `QalculateMathEngine` replies with a failure receipt), so answers come from the legacy
///          fallback — which **is** `_calculateResult`.
void main() {
  test('默认（direct）：`%` 按除以 100 算——与接入这个设置之前逐字节相同', () {
    final controller = _controller(_FakeDatabase());

    controller.setExpression('50+10%');
    controller.evaluate();
    expect(controller.result, '50.1');
    expect(controller.hasError, isFalse);

    controller.dispose();
  });

  test('relative：`50+10%` 是 55，`50+5%-5%` 是 49.875（手册那两条）', () {
    final controller =
        _controller(_FakeDatabase(), percentageMode: SettingsTokens.percentageRelative);

    controller.setExpression('50+10%');
    controller.evaluate();
    expect(controller.result, '55');

    controller.setExpression('50+5%-5%');
    controller.evaluate();
    expect(controller.result, '49.875');

    controller.dispose();
  });

  test('换设置之后当场重算：同一条表达式从 100.1 变 110', () {
    // 中文：设置页改的是库里的令牌，`updateSettings` 是它到控制器的那一步——这一步不改的话，
    //       用户改完设置要退出重进才生效。
    // English: the settings page writes the token to the database and `updateSettings` is how it reaches
    //          the controller; without that step a change would only take effect after leaving and
    //          re-entering.
    final controller = _controller(_FakeDatabase());

    controller.setExpression('100+10%');
    controller.evaluate();
    expect(controller.result, '100.1');

    controller.updateSettings(_settings(SettingsTokens.percentageRelative));
    expect(controller.result, '110',
        reason: '设置一改，屏幕上那条式子就按新读法重算');

    controller.updateSettings(_settings(SettingsTokens.percentageDirect));
    expect(controller.result, '100.1', reason: '改回去也要回来');

    controller.dispose();
  });

  test('记忆寄存器存的是同一个数，不是另一条读法的数', () {
    // 中文：`_currentNumericValue`（持久化混因）也会解析一次表达式。它要是漏传模式，
    //       屏幕上写 55 而寄存器里存的可能是 50.1——下一次 `M+`/`Ans` 就把那个错数带进下一句。
    // English: `_currentNumericValue` (the persistence mixin) parses the expression too. Were the mode
    //          missed there, the screen could read 55 while the register held 50.1 — and the next
    //          `M+`/`Ans` would carry that wrong number into the next sentence.
    final controller =
        _controller(_FakeDatabase(), percentageMode: SettingsTokens.percentageRelative);

    controller.setExpression('50+10%');
    controller.evaluate();
    expect(controller.result, '55');

    controller.memoryAdd();
    controller.setExpression('');
    controller.memoryRecall();
    expect(controller.expression, '55',
        reason: '寄存器里存的就是屏幕上那个 55，不是 50.1');

    controller.dispose();
  });
}

AppSettings _settings(String percentageMode) => AppSettings(
      haptics: true,
      hapticStrength: '标准',
      restoreState: false,
      autoSaveHistory: false,
      angleMode: 'RAD',
      precision: 6,
      themeModeLabel: SettingsTokens.themeModeSystem,
      expressionDisplayMode: SettingsTokens.expressionDisplaySymbols,
      percentageMode: percentageMode,
    );

CalculatorController _controller(
  _FakeDatabase db, {
  String percentageMode = SettingsTokens.defaultPercentageMode,
}) {
  return CalculatorController(
    historyRepository: HistoryRepository(db),
    notesRepository: NotesRepository(db),
    settingsRepository: SettingsRepository(db),
    settings: _settings(percentageMode),
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
  Future<Map<String, String>> settings() async =>
      Map<String, String>.from(savedSettings);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
