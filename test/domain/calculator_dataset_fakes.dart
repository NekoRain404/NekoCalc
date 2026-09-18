/// 中文：**数据集那两份测试共用的那几只假货。** 它们原来住在 `calculator_dataset_test.dart` 里
///       （私有名字），本轮那道缝把那个文件拆成「数据集这个存放处」与「面板插进去的那条调用」两半
///       之后两边都要用它们，于是按项目里 `test/shared/` 的老规矩搬成一个**共用件**：假库、假引擎、
///       一条按实测形状配好的回执，以及那一个装配控制器的工厂。
///
///       **假货本身一条没改**，只有名字从私有变成公开（私有名字跨不了库）：`holdSettings` 那扇门、
///       `noSuchMethod` 的 fail-loud 契约、两个 `Duration(minutes: 10)` 的防抖窗口（把边打边算的
///       定时器推出测试窗口）都逐字相同。
///
/// English: **the fakes the dataset's two test files share.** They used to live in
///          `calculator_dataset_test.dart` under private names; once this round's seam split that file
///          into "the dataset store" and "the call the sheet inserts", both sides needed them, so by
///          the project's `test/shared/` precedent they became a **shared fixture**: the fake
///          database, the fake engine, one receipt shaped like a measurement, and the factory that
///          assembles a controller.
///
///          **Not one fake changed** — only the names went from private to public (a private name
///          cannot cross a library): the `holdSettings` gate, `noSuchMethod`'s fail-loud contract and
///          the two `Duration(minutes: 10)` debounce windows (which push the as-you-time timers out of
///          the test's window) are character for character what they were.
library;

import 'dart:async';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/application/controllers/calculator_controller.dart';
import 'package:nekocalc/core/math/math_engine.dart';
import 'package:nekocalc/core/math/math_result.dart';
import 'package:nekocalc/core/math/result_text_rules.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/repositories/history_repository.dart';
import 'package:nekocalc/data/repositories/notes_repository.dart';
import 'package:nekocalc/data/repositories/settings_repository.dart';

/// 中文：一条按实测形状配好的回执（十进制只在**是有限数**时才写，与 `QalculateMathEngine` 同规矩）。
/// English: one receipt shaped like a measurement (the decimal is written only when it **is** a finite
///          number, the same rule `QalculateMathEngine` follows).
class DatasetFakeReply {
  const DatasetFakeReply(this.displayText,
      {this.tex = '', this.kind = EngineResultKind.number});

  final String displayText;
  final String tex;
  final EngineResultKind kind;

  EngineReply get reply => EngineReply.success(MathResult(
        displayText: displayText,
        displayTex: tex,
        decimalText:
            decimalTextIsFinite(displayText) ? displayText : '',
        resultKind: kind,
      ));
}

final EngineReply datasetEngineUnavailable = EngineReply.failure('engine unavailable');

class DatasetFakeMathEngine implements MathEngine {
  DatasetFakeMathEngine(this.reply);

  EngineReply reply;

  final List<({String expression, String angleMode})> calls = [];

  @override
  Future<EngineReply> evaluate(
    String expression, {
    required String angleMode,
  }) async {
    calls.add((expression: expression, angleMode: angleMode));
    return reply;
  }
}

CalculatorController datasetController(
  DatasetFakeDatabase db, {
  required MathEngine engine,
  bool restoreState = false,
  String? storedDataset,
}) {
  if (storedDataset != null) {
    db.savedSettings['calculator_dataset'] = storedDataset;
  }
  return CalculatorController(
    historyRepository: HistoryRepository(db),
    notesRepository: NotesRepository(db),
    settingsRepository: SettingsRepository(db),
    settings: AppSettings(
      haptics: true,
      hapticStrength: '标准',
      restoreState: restoreState || storedDataset != null,
      autoSaveHistory: false,
      angleMode: 'RAD',
      precision: 6,
      themeModeLabel: '跟随系统',
      expressionDisplayMode: '数学符号',
    ),
    engine: engine,
    liveEvaluationDelay: const Duration(minutes: 10),
    liveEngineFollowUpDelay: const Duration(minutes: 10),
  );
}

class DatasetFakeDatabase implements AppDatabase {
  final savedSettings = <String, String>{};

  /// 中文：立起来时 [settings] 会一直等到 [releaseSettings] 被调用——用来把一次「读盘期间」的窗口
  ///       撑开。
  /// English: while raised, [settings] waits until [releaseSettings] is called — used to hold a
  ///          "while reading from disk" window open.
  bool holdSettings = false;

  /// 中文：撑开「读盘期间」那一段窗口的那扇门。
  /// English: the gate that holds the "while reading from disk" window open.
  final _gate = Completer<void>();

  void releaseSettings() => _gate.complete();

  @override
  Future<void> setSettings(Map<String, String> values) async {
    if (holdSettings) await _gate.future;
    savedSettings.addAll(values);
  }

  @override
  Future<void> setSetting(String key, String value) async {
    savedSettings[key] = value;
  }

  @override
  Future<Map<String, String>> settings() async {
    if (holdSettings) await _gate.future;
    return Map<String, String>.from(savedSettings);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
