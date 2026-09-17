import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/application/controllers/calculator_controller.dart';
import 'package:nekocalc/core/math/math_engine.dart';
import 'package:nekocalc/core/math/math_result.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/repositories/history_repository.dart';
import 'package:nekocalc/data/repositories/notes_repository.dart';
import 'package:nekocalc/data/repositories/settings_repository.dart';
import 'package:nekocalc/domain/usecases/calculator_submit_result.dart';

/// 中文：引擎接进**提交路径**（按下等号）之后的控制器行为。全部用测试替身跑，不需要设备、
///       不需要引擎；引擎的失败路径（答不出来、抛异常）在这里是主要考点，因为那是用户唯一会
///       看到的差别。
///
/// English: Controller behaviour once an engine is on the *submit path* (pressed =). Everything runs
///          against a double — no device, no engine. The failure paths (no answer, thrown
///          exception) are the main subject here, because they are the only difference a user can
///          ever see.
void main() {
  /// 中文：引擎给出的十六位有效数字的十进制形态，以及它对应的、按用户设置取整后的显示形态。
  ///       `sqrt(32)` 在 16 位有效数字下是 `5.656854249492381`，6 位小数下显示 `5.656854`——
  ///       与旧解析器今天给出的显示完全一致，这正是「引擎负责算得准，Dart 负责显示」的意思。
  /// English: The 16-significant-digit decimal the engine hands over, and the display form it rounds
  ///          to at the user's setting. `sqrt(32)` is `5.656854249492381` at 16 significant digits
  ///          and displays as `5.656854` at 6 decimal places — character-for-character what the
  ///          legacy parser shows today, which is what "the engine computes, Dart displays" means.
  const engineDecimal = '5.656854249492381';
  const engineDisplay = '5.656854';
  const engineTex = r'4\sqrt{2}';

  EngineReply sqrt32Reply() => EngineReply.success(
        const MathResult(
          displayText: engineDecimal,
          displayTex: engineTex,
          decimalText: engineDecimal,
        ),
      );

  test('a reply that arrives after a timeout does not overwrite the fallback',
      () async {
    // 中文：超时已经触发、界面已经回落到旧解析器的结果之后，原生那个**慢响应**才回来。
    //       它必须什么都不改：既不能覆盖显示，也不能碰 `_lastFiniteResult` 或持久化。
    //       （这是修复轮 1 报告里说「有」、复审说「没有」的那条——复审找错了名字，
    //       `an engine that never answers times out and falls back` 确实存在；真正缺的是这一条：
    //       超时**之后**迟到的那一次回包。）
    // English: After the timeout has fired and the interface has fallen back to the legacy result,
    //          the slow native response finally arrives. It must change nothing: neither the display
    //          nor `_lastFiniteResult` nor what gets persisted. (This is the case round 1's report
    //          claimed to have and the re-review said was missing — the re-review looked for the
    //          wrong name: `an engine that never answers times out and falls back` does exist. What
    //          was genuinely missing is this one: the *late* reply arriving after the timeout.)
    final engine = _PendingMathEngine();
    final db = _FakeDatabase();
    final controller = _controller(
      db,
      engine: engine,
      settings: _settings(restoreState: true),
      engineTimeout: const Duration(milliseconds: 20),
    );

    controller.setExpression('sqrt(32)');
    final submitted = await controller.submit();

    // 中文：超时 → 回落：结果是旧解析器那条，提交本身是成功的。
    // English: Timeout → fallback: the result is the legacy one and the submit still succeeds.
    expect(controller.result, engineDisplay);
    expect(controller.resultTex, isEmpty);
    expect(submitted.status, CalculatorSubmitStatus.calculated);

    // 中文：慢响应现在才回来，带着引擎那份结果。
    // English: The slow response arrives only now, carrying the engine's result.
    engine.answer(sqrt32Reply());
    await Future<void>.delayed(Duration.zero);

    expect(controller.result, engineDisplay);
    expect(controller.resultTex, isEmpty);
    expect(controller.resultDecimal, engineDisplay);
    expect(controller.reusableResult, engineDisplay,
        reason: '_lastFiniteResult must not have been touched');

    // 中文：落盘的内容也必须还是回落那份——迟到的回包不许把自己写进持久化。
    // English: What gets persisted has to stay the fallen-back result too — the late reply must not
    //          write itself into persistence.
    controller.applyPastedText('角度模式: RAD');
    await Future<void>.delayed(Duration.zero);
    expect(db.savedSettings['calculator_result'], engineDisplay);
    expect(db.savedSettings['calculator_result_tex'], isEmpty);
    expect(db.savedSettings['calculator_result_decimal'], engineDisplay);

    controller.dispose();
  });

  test('a reply that arrives after newer input does not overwrite it',
      () async {
    // 中文：这是本步引入的那个竞态——`submit()` 现在会在引擎上等待，用户在往返期间继续输入时，
    //       过期的回包不许落地：那会覆盖更新的边打边算结果，还会把 `_lastFiniteResult` 与持久化
    //       一起带到过期的那条时间线上。启动后的第一次提交最容易触发（那次包含懒加载全局定义）。
    // English: This is the race this step introduced — `submit()` now waits on the engine, and a
    //          reply that lands after the user has typed on must not be adopted: it would overwrite
    //          the newer as-you-type result and drag `_lastFiniteResult` and persistence onto the
    //          stale timeline. The first submit after launch is the likeliest trigger (it includes
    //          the lazy global-definition load).
    final engine = _PendingMathEngine();
    final db = _FakeDatabase();
    final controller = _controller(
      db,
      engine: engine,
      settings: _settings(restoreState: true),
    );

    controller.setExpression('sqrt(32)');
    final pending = controller.submit();

    // 中文：用户在等号还没回来时又输入了——边打边算立即产出新结果。
    // English: The user types on before "=" comes back — as-you-type evaluation produces a newer
    //          result immediately.
    controller.setExpression('6*7');
    controller.evaluate();
    expect(controller.result, '42');

    // 中文：过期的引擎回包现在才到。
    // English: The stale engine reply arrives only now.
    engine.answer(sqrt32Reply());
    final submitted = await pending;

    expect(controller.result, '42');
    expect(controller.resultDecimal, '42');
    expect(controller.resultTex, isEmpty);
    expect(submitted.status, CalculatorSubmitStatus.superseded);
    expect(submitted.needsAttention, isFalse);

    // 中文：`_lastFiniteResult` 也必须是新结果那一份——`Ans` 引用的值没有被过期回包改掉。
    // English: `_lastFiniteResult` has to be the newer one too — the value `Ans` resolves from was
    //          not changed by the stale reply.
    controller.setExpression('ans');
    controller.evaluate();
    expect(controller.result, '42');

    // 中文：持久化里也不许出现过期回包的那份结果。
    // English: The stale reply's result must not show up in what was persisted either.
    expect(db.savedSettings['calculator_result'], isNot(engineDisplay));
    expect(db.savedSettings['calculator_result_decimal'], isNot(engineDecimal));

    controller.dispose();
  });

  test('a reply that lands after dispose is dropped without notifying',
      () async {
    // 中文：控制器其余异步完成处都有 `_disposed` 检查，提交路径以前没有——`notifyListeners()` 在
    //       `dispose()` 之后是可达的，debug 模式下会报 `FlutterError`。
    // English: Every other async completion point in the controller checks `_disposed`; the submit
    //          path did not — `notifyListeners()` was reachable after `dispose()`, which reports a
    //          `FlutterError` in debug mode.
    final engine = _PendingMathEngine();
    final controller = _controller(_FakeDatabase(), engine: engine);

    controller.setExpression('sqrt(32)');
    final pending = controller.submit();
    controller.dispose();

    engine.answer(sqrt32Reply());

    // 中文：`await` 必须正常返回（落到过期分支），而不是抛 `FlutterError` 或者永远悬着。
    // English: The `await` has to return normally (onto the stale branch) rather than throwing a
    //          `FlutterError` or hanging forever.
    await expectLater(pending, completes);
  });

  test('dispose collects the engine timeout timer', () async {
    // 中文：超时定时器属于控制器，销毁时必须一起收掉——`flutter_test` 的「widget 树销毁后仍有
    //       定时器挂在那里」查的就是这个，而 `Future.timeout` 的定时器拿不到句柄、收不掉。
    //       （页面级的那条路径由 `calculator_page_test.dart` 的用例把守。）
    // English: The timeout timer belongs to the controller and has to be collected on dispose —
    //          which is what flutter_test's "a timer is still pending after the widget tree was
    //          disposed" checks, and a `Future.timeout` timer cannot be reached to cancel. (The
    //          page-level path is guarded by the case in `calculator_page_test.dart`.)
    final engine = _FakeMathEngine(null, hangForever: true);
    final controller = _controller(
      _FakeDatabase(),
      engine: engine,
      engineTimeout: const Duration(seconds: 30),
    );

    controller.setExpression('2+3');
    final pending = controller.submit();
    controller.dispose();

    // 中文：销毁时给在飞的请求补一条失败回执，所以这里会正常返回一个过期结果。
    // English: Disposal hands the request in flight a failure receipt, so this returns normally
    //          with a superseded result.
    final submitted = await pending;
    expect(submitted.status, CalculatorSubmitStatus.superseded);
  });
}

AppSettings _settings({
  int precision = 6,
  bool groupThousands = false,
  String angleMode = 'RAD',
  bool restoreState = false,
}) {
  return AppSettings(
    haptics: true,
    hapticStrength: '标准',
    restoreState: restoreState,
    autoSaveHistory: false,
    angleMode: angleMode,
    precision: precision,
    themeModeLabel: '跟随系统',
    expressionDisplayMode: '数学符号',
    groupThousands: groupThousands,
  );
}

/// 中文：**边打边算的引擎跟进被推到一个小时之后**。这个文件考的是提交路径，它那些
///       `expect(engine.calls, hasLength(1))` 只有在「边打边算那一发不会自己冒出来」时才确定；
///       3e 之后边打边算也会问引擎（默认延迟 120ms），于是这里注入一个比任何一次测试运行都长的值，
///       把它挪出这条路径。提交路径自己的超时仍然由 [engineTimeout] 控制。
///       ——边打边算那一侧的行为由 `calculator_engine_live_test.dart` 负责，那里注入的是毫秒级。
///
/// English: **The as-you-type engine follow-up is pushed an hour out.** This file is about the submit
///          path, and its `expect(engine.calls, hasLength(1))` assertions are only deterministic while
///          that follow-up cannot appear on its own; after 3e as-you-type asks the engine too (120 ms
///          by default), so a value longer than any test run is injected here to move it out of the
///          way. The submit path's own timeout is still [engineTimeout]. The as-you-type half is
///          covered by `calculator_engine_live_test.dart`, which injects a millisecond-scale delay.
CalculatorController _controller(
  _FakeDatabase db, {
  required MathEngine engine,
  AppSettings? settings,
  Duration engineTimeout = const Duration(seconds: 5),
}) {
  return CalculatorController(
    historyRepository: HistoryRepository(db),
    notesRepository: NotesRepository(db),
    settingsRepository: SettingsRepository(db),
    settings: settings ?? _settings(),
    engine: engine,
    engineTimeout: engineTimeout,
    liveEngineFollowUpDelay: const Duration(hours: 1),
  );
}

/// 中文：测试替身。记下每次调用（表达式与角度模式），按配置回执；[hangForever] 是
///       「永远不回答」，用来走超时那条路。**抛异常那一半不在这里**——它随
///       `an engine that throws falls back instead of crashing` 留在
///       `calculator_engine_submit_test.dart` 的替身里：这个文件里没有测试用它，
///       分析器因此不接受一个没人传的开关。
/// English: The test double. It records every call (expression and angle mode) and returns the
///          configured receipt; [hangForever] is "never answers", which exercises the timeout.
///          **The throwing half is not here** — it stays with
///          `an engine that throws falls back instead of crashing` in
///          `calculator_engine_submit_test.dart`: no test in this file used it, so the analyzer
///          refuses a switch nobody passes.
class _FakeMathEngine implements MathEngine {
  _FakeMathEngine(this.reply, {this.hangForever = false});

  EngineReply? reply;
  final bool hangForever;
  final List<({String expression, String angleMode})> calls = [];

  @override
  Future<EngineReply> evaluate(
    String expression, {
    required String angleMode,
  }) async {
    calls.add((expression: expression, angleMode: angleMode));
    if (hangForever) return Completer<EngineReply>().future;
    return reply ?? EngineReply.failure('no reply configured');
  }
}

/// 中文：回包由测试决定何时到达的替身。用来构造「提交还挂在引擎上，用户已经继续输入」这个竞态。
/// English: A double whose reply the test releases when it wants. It exists to build the race where
///          a submit is still waiting on the engine while the user has already typed on.
class _PendingMathEngine implements MathEngine {
  final List<({String expression, String angleMode})> calls = [];
  final List<Completer<EngineReply>> _pending = [];

  void answer(EngineReply reply) {
    for (final completer in _pending) {
      if (!completer.isCompleted) completer.complete(reply);
    }
    _pending.clear();
  }

  @override
  Future<EngineReply> evaluate(
    String expression, {
    required String angleMode,
  }) {
    calls.add((expression: expression, angleMode: angleMode));
    final completer = Completer<EngineReply>();
    _pending.add(completer);
    return completer.future;
  }
}

/// 中文：只需要设置表的最小假数据库，够本文件用到即可。
/// English: A minimal fake database covering only the settings table, which is all this file needs.
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
