import 'dart:async';

import 'package:flutter/services.dart';
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

  test('the submit path displays the engine result', () async {
    final engine = _FakeMathEngine(sqrt32Reply());
    final controller = _controller(_FakeDatabase(), engine: engine);

    controller.setExpression('sqrt(32)');
    final submitted = await controller.submit();

    expect(engine.calls, hasLength(1));
    expect(controller.hasError, isFalse);
    expect(controller.result, engineDisplay);
    expect(controller.resultTex, engineTex);
    expect(controller.resultDecimal, engineDecimal);
    expect(submitted.submitted, isTrue);
    expect(submitted.result, engineDisplay);

    controller.dispose();
  });

  test(
      'display rounding of an engine result stays in Dart, at the user precision',
      () async {
    // 中文：引擎给的是未取整的 16 位有效数字；屏幕上的形态仍然由 `formatNumber` 按
    //       `AppSettings.precision`（小数位数）与千分位设置决定——取整只有一处实现。
    // English: The engine hands over an unrounded 16-significant-digit value; what reaches the
    //          screen still comes from `formatNumber` at `AppSettings.precision` (decimal places)
    //          and the grouping setting — rounding has exactly one implementation.
    for (final (precision, digits, expected) in const [
      (4, '4 位', '5.6569'),
      (6, '6 位', '5.656854'),
      (8, '8 位', '5.65685425'),
    ]) {
      final controller = _controller(
        _FakeDatabase(),
        engine: _FakeMathEngine(sqrt32Reply()),
        settings: _settings(precision: precision, digits: digits),
      );

      controller.setExpression('sqrt(32)');
      await controller.submit();

      expect(controller.result, expected, reason: 'precision $precision');
      expect(controller.resultDecimal, engineDecimal,
          reason: 'the decimal form stays unrounded');
      controller.dispose();
    }

    // 中文：千分位也照旧由 Dart 侧决定，引擎的十进制形态不受影响。
    // English: Grouping stays Dart's decision too, and never touches the decimal form.
    final grouped = _controller(
      _FakeDatabase(),
      engine: _FakeMathEngine(
        EngineReply.success(
          const MathResult(
            displayText: '1234567.5',
            decimalText: '1234567.5',
          ),
        ),
      ),
      settings: _settings(groupThousands: true),
    );
    grouped.setExpression('1234567.5');
    await grouped.submit();
    expect(grouped.result, '1,234,567.5');
    expect(grouped.resultDecimal, '1234567.5');
    grouped.dispose();
  });

  test('the engine is asked with the angle mode the controller is in',
      () async {
    final engine = _FakeMathEngine(
      EngineReply.success(const MathResult(displayText: '1', decimalText: '1')),
    );
    final controller = _controller(_FakeDatabase(), engine: engine);

    controller.setExpression('sin(90)');
    await controller.submit();
    expect(engine.calls.last.angleMode, 'RAD');

    controller.setAngleMode('DEG');
    controller.setExpression('sin(90)');
    await controller.submit();
    expect(engine.calls.last.angleMode, 'DEG');

    // 中文：这正是裁决 3 要防的那条矛盾——同一个 `sin(90)`，DEG 下是 1、RAD 下不是。角度模式
    //       不过去的话，提交路径（引擎默认角度单位）与边打边算（读 AppSettings）会互相矛盾。
    // English: This is the contradiction ruling 3 exists to prevent — the same `sin(90)` is 1 in
    //          DEG and something else in RAD. Without the mode, the submit path (the engine's
    //          default angle unit) and as-you-type (which reads AppSettings) contradict each other.
    expect(engine.calls.map((call) => call.angleMode), ['RAD', 'DEG']);

    controller.dispose();
  });

  test('the engine is asked with ans and last already resolved', () async {
    // 中文：引擎不认识 `Ans`/`last`，问它之前必须先换成十进制数值，否则它会把 `ans` 当成未知变量。
    // English: The engine does not know `Ans`/`last`, so they must be substituted before it is
    //          asked; otherwise it would treat `ans` as an unknown variable.
    final engine = _FakeMathEngine(
      EngineReply.success(
          const MathResult(displayText: '42', decimalText: '42')),
    );
    final controller = _controller(_FakeDatabase(), engine: engine);

    controller.setExpression('6*7');
    await controller.submit();

    controller.setExpression('ans + 1');
    await controller.submit();

    expect(engine.calls.map((call) => call.expression), ['6*7', '42 + 1']);

    controller.dispose();
  });

  test('a failing engine falls back to the legacy parser, unchanged', () async {
    final engine = _FakeMathEngine(
      EngineReply.failure('missing_plugin: no native side'),
    );
    final controller = _controller(_FakeDatabase(), engine: engine);

    controller.setExpression('sqrt(32)');
    final submitted = await controller.submit();

    expect(engine.calls, hasLength(1));
    expect(controller.hasError, isFalse);
    expect(controller.result, engineDisplay);
    // 中文：回落之后拿到的**就是今天那条路**的结果——显示文本同时也是十进制形态、没有 LaTeX。
    //       注意十进制形态因此是取整后的 `5.656854`，与引擎那份未取整的不同：这不是缺陷，
    //       是两条路径各自的性质，而回落存在的意义就是「用户看不到差别」。
    // English: After falling back, the result is exactly what today's path produces — the display
    //          text doubles as the decimal form and there is no LaTeX. Note the decimal form is
    //          therefore the rounded `5.656854`, unlike the engine's unrounded one: that is not a
    //          defect but a property of each path, and the point of the fallback is that the user
    //          cannot tell them apart.
    expect(controller.resultDecimal, engineDisplay);
    expect(controller.resultTex, isEmpty);
    expect(submitted.result, engineDisplay);

    // 中文：DEG 模式下也一样（旧解析器读 `AppSettings.angleMode`）。
    // English: The same holds in DEG mode (the legacy parser reads `AppSettings.angleMode`).
    controller.setAngleMode('DEG');
    controller.setExpression('sin(90)');
    await controller.submit();
    expect(controller.result, '1');

    controller.dispose();
  });

  test('an engine that throws falls back instead of crashing', () async {
    for (final thrown in <Object>[
      MissingPluginException('No implementation found for method evaluate'),
      PlatformException(code: 'invalid_angle_mode', message: '缺少 angleMode 参数'),
    ]) {
      final engine = _FakeMathEngine(null, throwOnEvaluate: thrown);
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('2+3');
      final submitted = await controller.submit();

      expect(controller.result, '5', reason: '$thrown');
      expect(controller.hasError, isFalse, reason: '$thrown');
      expect(submitted.submitted, isTrue, reason: '$thrown');
      controller.dispose();
    }
  });

  test('an engine reply with no decimal form falls back', () async {
    // 中文：没有十进制形态（精确形式、带单位的结果）与没有可用答案是一回事：没有东西可以喂给
    //       数值消费者，也没有东西可以放到显示区上。
    // English: No decimal form (an exact form, a result carrying a unit) is the same as no usable
    //          answer: there is nothing for numeric consumers and nothing for the display.
    final exactForm = _controller(
      _FakeDatabase(),
      engine: _FakeMathEngine(
        EngineReply.success(
          const MathResult(displayText: r'4\sqrt{2}', displayTex: r'4\sqrt{2}'),
        ),
      ),
    );
    exactForm.setExpression('sqrt(32)');
    await exactForm.submit();
    expect(exactForm.result, engineDisplay);
    expect(exactForm.resultTex, isEmpty);
    exactForm.dispose();
  });

  test('an engine reply that is not a finite number falls back', () async {
    // 中文：`Infinity` / `NaN` 字面量不算答案——放上屏幕就是一个看起来像结果的 `无效`，而今天
    //       这里是一条明明白白的错误（`1/0`）。
    // English: The `Infinity` / `NaN` literals are not an answer — on screen they would put a
    //          result-looking `无效` where today there is a plain error (`1/0`).
    final notFinite = _controller(
      _FakeDatabase(),
      engine: _FakeMathEngine(
        EngineReply.success(
          const MathResult(
            displayText: 'Infinity',
            decimalText: 'Infinity',
          ),
        ),
      ),
    );
    notFinite.setExpression('1/0');
    await notFinite.submit();
    expect(notFinite.hasError, isTrue);
    expect(notFinite.errorMessage, '结果不是有限数值');
    expect(notFinite.result, '结果不是有限数值');
    expect(notFinite.resultDecimal, isEmpty);
    notFinite.dispose();
  });

  test('a finite result beyond the double range is accepted and displayed',
      () async {
    // 中文：`2^2000 ≈ 1.148e+602`。**在真机上实测过**：以前这里用 `double.isFinite` 判有限性，
    //       `double.tryParse` 对它返回 `Infinity`，于是引擎的正确答案被丢掉，用户看到一条
    //       「结果不是有限数值」。有限性必须在字符串层面判——精确引擎存在的理由正是这类结果。
    // English: `2^2000 ≈ 1.148e+602`. *Reproduced on a real device*: finiteness used to be judged
    //          with `double.isFinite`, `double.tryParse` returns `Infinity` for it, the engine's
    //          correct answer was thrown away and the user saw "结果不是有限数值". Finiteness has
    //          to be judged at the string level — results like this are why an exact engine exists.
    const hugeDecimal = '1.148130695274e+602';
    final controller = _controller(
      _FakeDatabase(),
      engine: _FakeMathEngine(
        EngineReply.success(
          const MathResult(
            displayText: hugeDecimal,
            displayTex: r'1.148130695274 \times 10^{602}',
            decimalText: hugeDecimal,
          ),
        ),
      ),
    );

    controller.setExpression('2^2000');
    final submitted = await controller.submit();

    expect(controller.hasError, isFalse);
    expect(controller.result, hugeDecimal);
    expect(controller.resultDecimal, hugeDecimal);
    expect(submitted.submitted, isTrue);

    // 中文：`Ans`/`last` 拿到的是那段**文本**，所以它们照常可用；记忆寄存器拿不到 double，
    //       于是显式拒绝，而不是加一个 0（见下一条）。
    // English: `Ans`/`last` get that *text*, so they keep working; the memory register cannot get a
    //          double and therefore refuses explicitly rather than adding a 0 (next test).
    expect(controller.reusableResult, hugeDecimal);

    controller.dispose();
  });

  test('an underflowing result never becomes a zero for Ans or the memory',
      () async {
    // 中文：`2^-2000 ≈ 9.3e-603` 是同一根因的另一端，也是**更严重**的一端：`double.tryParse`
    //       返回 `0.0`（不是 Infinity），`isFinite` 为真，于是答案被接受，而 `Ans`、`last`、
    //       记忆寄存器全部拿到 0——不抛异常、不报错，给一个错值。
    // English: `2^-2000 ≈ 9.3e-603` is the other end of the same root cause and the worse one:
    //          `double.tryParse` returns `0.0` (not Infinity) and `isFinite` is true, so the answer
    //          was accepted while `Ans`, `last` and the memory register all took 0 — nothing threw,
    //          nothing complained, and the value was wrong.
    const tinyDecimal = '9.303768583076e-603';
    final engine = _FakeMathEngine(
      EngineReply.success(
        const MathResult(
          displayText: tinyDecimal,
          decimalText: tinyDecimal,
        ),
      ),
    );
    final controller = _controller(_FakeDatabase(), engine: engine);

    // 中文：先让寄存器里有一个真实的非零值，这样「加了 0」与「什么都没加」是能分开的。
    // English: Put a real non-zero value in the register first, so "added a 0" and "added nothing"
    //          are distinguishable.
    engine.reply = EngineReply.success(
      const MathResult(displayText: '5', decimalText: '5'),
    );
    controller.setExpression('5');
    await controller.submit();
    controller.memoryAdd();
    expect(controller.memoryValue, 5);

    engine.reply = EngineReply.success(
      const MathResult(displayText: tinyDecimal, decimalText: tinyDecimal),
    );
    controller.setExpression('2^-2000');
    await controller.submit();

    expect(controller.hasError, isFalse);
    expect(controller.result, tinyDecimal);
    expect(controller.result, isNot('0'));
    expect(controller.resultDecimal, tinyDecimal);

    // 中文：`Ans`/`last` 拿到的是那段文本（不是 0）……
    // English: `Ans`/`last` get that text (not a 0)...
    expect(controller.reusableResult, tinyDecimal);

    // 中文：……而记忆寄存器**不动**：它放不下这个数，加 0 会是一个静默的错值。
    // English: ...and the memory register is *left alone*: the value does not fit, and adding 0
    //          would be a silently wrong value.
    controller.memoryAdd();
    expect(controller.memoryValue, 5);
    controller.memorySubtract();
    expect(controller.memoryValue, 5);

    controller.dispose();
  });

  test('the engine result feeds Ans, last and the memory register', () async {
    final engine = _FakeMathEngine(sqrt32Reply());
    final controller = _controller(_FakeDatabase(), engine: engine);

    controller.setExpression('sqrt(32)');
    await controller.submit();

    // 中文：数值消费者拿到的必须是引擎那份**未取整**的十进制值，而不是屏幕上的 `5.656854`。
    // English: Numeric consumers must get the engine's *unrounded* decimal value, not the
    //          `5.656854` that reaches the screen.
    controller.memoryAdd();
    expect(controller.memoryValue, 5.656854249492381);

    controller.continueWithResult();
    expect(controller.expression, engineDecimal);

    controller.dispose();
  });

  test('an engine result is persisted in all three forms', () async {
    final db = _FakeDatabase()
      ..savedSettings.addAll({
        'restore_state': 'true',
        'angle_mode': '弧度',
        'digits': '6 位',
      });
    final controller = _controller(db, engine: _FakeMathEngine(sqrt32Reply()));
    await controller.reloadSettingsAndRestore();

    controller.setExpression('sqrt(32)');
    await controller.submit();
    await Future<void>.delayed(Duration.zero);

    expect(db.savedSettings['calculator_result'], engineDisplay);
    expect(db.savedSettings['calculator_result_tex'], engineTex);
    expect(db.savedSettings['calculator_result_decimal'], engineDecimal);

    controller.dispose();
  });

  test('as-you-type evaluation never asks the engine', () async {
    // 中文：这一步的硬边界——`evaluate()` 一行未动，仍然完全走旧的同步解析器。引擎只在
    //       「按下等号」时被问到，所以边打边算的时序风险（异步结果与输入的竞态）根本不存在。
    // English: This step's hard boundary — `evaluate()` is untouched and still runs entirely on the
    //          legacy synchronous parser. The engine is only consulted on "pressed =", so the timing
    //          risk of live evaluation (an async result racing the next keystroke) cannot arise.
    final engine = _FakeMathEngine(sqrt32Reply());
    final controller = _controller(_FakeDatabase(), engine: engine);

    controller.setExpression('sqrt(32)');
    controller.evaluate();

    expect(engine.calls, isEmpty);
    expect(controller.result, engineDisplay);
    expect(controller.resultTex, isEmpty);
    expect(controller.resultDecimal, engineDisplay);

    // 中文：按键路径（`input`）同样只触发实时解析，不问引擎。
    // English: The keypad path (`input`) drives live evaluation too, and never asks the engine.
    controller.setExpression('');
    controller.input('6');
    controller.input('*');
    controller.input('7');
    expect(engine.calls, isEmpty);

    controller.dispose();
  });

  test('an engine that never answers times out and falls back', () async {
    // 中文：原生卡住不回时提交路径必须自己停止等待——否则 `=` 从此静默失效直到重启（单线程引擎
    //       队列里还排着那一次调用）。超时按既有约定走回落，不是报错。
    // English: When the native side never answers, the submit path has to stop waiting on its own —
    //          otherwise `=` is silently dead until the app is restarted (the single-threaded
    //          engine queue still holds that call). A timeout falls back, as the existing contract
    //          says, rather than reporting an error.
    final engine = _FakeMathEngine(null, hangForever: true);
    final controller = _controller(
      _FakeDatabase(),
      engine: engine,
      engineTimeout: const Duration(milliseconds: 20),
    );

    controller.setExpression('2+3');
    final submitted = await controller.submit();

    expect(engine.calls, hasLength(1));
    expect(controller.result, '5');
    expect(controller.hasError, isFalse);
    expect(submitted.submitted, isTrue);

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
  String digits = '6 位',
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
  );
}

/// 中文：测试替身。记下每次调用（表达式与角度模式），按配置回执或抛异常——后者用来证明
///       「引擎实现没守住不抛异常的约定」时提交路径仍然回落，而不是崩溃；[hangForever] 则是
///       「永远不回答」，用来走超时那条路。
/// English: The test double. It records every call (expression and angle mode) and either returns
///          the configured receipt or throws — the latter proves the submit path still falls back
///          when an engine implementation breaks its no-throw promise instead of crashing;
///          [hangForever] is "never answers", which exercises the timeout.
class _FakeMathEngine implements MathEngine {
  _FakeMathEngine(this.reply, {this.throwOnEvaluate, this.hangForever = false});

  EngineReply? reply;
  final Object? throwOnEvaluate;
  final bool hangForever;
  final List<({String expression, String angleMode})> calls = [];

  @override
  Future<EngineReply> evaluate(
    String expression, {
    required String angleMode,
  }) async {
    calls.add((expression: expression, angleMode: angleMode));
    if (hangForever) return Completer<EngineReply>().future;
    final thrown = throwOnEvaluate;
    if (thrown != null) throw thrown;
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
