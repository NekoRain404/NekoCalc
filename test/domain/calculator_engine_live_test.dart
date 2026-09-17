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

/// 中文：引擎接进**边打边算**之后的控制器行为（步骤 3e）。全部用测试替身跑，不需要设备。
///
///       这里能钉住的是**逻辑**：谁先上屏、过期回包丢不丢、在飞上限是不是 1、回落是不是全覆盖、
///       kill switch 关了之后还问不问引擎。**钉不住的是时序**——`flutter_test` 没有真的原生通道，
///       真机上毫秒级的乱序、冷启动那一次懒加载、慢设备上的队列堆积，都只能在设备上量。这一点在
///       报告里明说，不拿这里的绿灯当作「时序也验过了」。
///
/// English: Controller behaviour once the engine is on the *as-you-type* path (step 3e). Everything
///          runs against a double — no device, no engine.
///
///          What this can pin down is the **logic**: what goes on screen first, whether stale replies
///          are dropped, whether the in-flight bound is really 1, whether the fallback is complete,
///          and whether the kill switch stops the engine being asked at all. What it **cannot** pin
///          down is **timing** — `flutter_test` has no real platform channel, so millisecond-scale
///          reordering, the lazy definition load on the first call and queue build-up on a slow
///          device are only measurable on hardware. That is stated plainly in the report rather than
///          being papered over with a green light from here.
void main() {
  /// 中文：引擎给出的十六位有效数字的十进制形态，以及它在 6 位小数下的显示形态。
  ///       **两者不同**正是这些测试用来分辨「屏幕上是谁的结果」的标记：旧解析器只给得出
  ///       `5.656854`（`formatNumber` 的产物），引擎给得出 `5.656854249492381`。
  /// English: The 16-significant-digit decimal the engine hands over and the 6-decimal display form
  ///          it rounds to. The two **differ**, which is the marker these tests use to tell whose
  ///          result is on screen: the legacy parser only ever produces `5.656854` (what
  ///          `formatNumber` emits) while the engine produces `5.656854249492381`.
  const engineDecimal = '5.656854249492381';
  const engineDisplay = '5.656854';
  const engineTex = r'4\sqrt{2}';

  /// 中文：旧解析器对 `sqrt(32)` 的答案——引擎回包落地**之前**屏幕上的那一份。
  /// English: The legacy parser's answer for `sqrt(32)` — what is on screen *before* any engine reply
  ///          lands.
  const legacyDisplay = '5.656854';

  EngineReply sqrt32Reply() => EngineReply.success(
        const MathResult(
          displayText: engineDecimal,
          displayTex: engineTex,
          decimalText: engineDecimal,
        ),
      );

  group('裁决 1：旧结果先上屏，引擎结果到达后替换（策略 B）', () {
    test('旧解析器的结果同步上屏，引擎的回包到达后精确形态替换它', () async {
      final engine = _FakeMathEngine(sqrt32Reply());
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('sqrt(32)');
      controller.evaluate();

      // 中文：**同步**就有结果——这正是裁决 1 要的即时反馈，与引擎在不在、快不快无关。
      // English: A result exists **synchronously** — exactly the instant feedback ruling 1 wants,
      //          independent of whether the engine is there and how fast it is.
      expect(controller.result, legacyDisplay);
      expect(controller.resultDecimal, legacyDisplay);
      expect(controller.resultTex, isEmpty);
      expect(engine.calls, isEmpty, reason: '防抖窗口内一次都不许发');

      // 中文：跟进延迟到点之后引擎被问了一次，答案是精确形态（十进制形态是 16 位的那一份，与旧
      //       解析器给出的不同，因此这条断言能证明屏幕上的结果确实换成了引擎的）。
      // English: Once the follow-up delay elapses the engine is asked once, and its answer is the
      //          exact form (its decimal form is the 16-digit one, unlike the legacy parser's, which
      //          is what makes this assertion proof that the on-screen result really was replaced).
      await pumpEventQueue();
      expect(engine.calls, hasLength(1));
      expect(engine.calls.single.expression, 'sqrt(32)');
      expect(engine.resultDecimal, engineDecimal);
      expect(controller.result, engineDisplay);
      expect(controller.resultTex, engineTex);

      controller.dispose();
    });

    test('引擎答不出来时屏幕上仍是旧解析器的结果，且没有错误状态', () async {
      final engine = _FakeMathEngine(EngineReply.failure('engine_unavailable'));
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('sqrt(32)');
      controller.evaluate();
      await pumpEventQueue();

      expect(engine.calls, hasLength(1));
      expect(controller.result, legacyDisplay);
      expect(controller.resultDecimal, legacyDisplay);
      expect(controller.resultTex, isEmpty);
      expect(controller.hasError, isFalse);
      expect(controller.errorMessage, isNull);

      controller.dispose();
    });

    test('引擎给出非有限十进制时同样不采用（与提交路径同一处判定）', () async {
      // 中文：`1/0` 那种情形——引擎**回了话**，但回的是一个不是有限数的十进制。采用它的条件与
      //       提交路径共用一处（[MathResult.hasFiniteDecimal]，判定在字符串层面不借 double），
      //       于是屏幕上是旧解析器那条「结果不是有限数值」，而不是一个看起来像结果的 `infinity`。
      // English: The `1/0` shape — the engine *did* answer, but with a decimal that is not a finite
      //          number. Adoption is shared with the submit path ([MathResult.hasFiniteDecimal],
      //          judged as text rather than through a double), so what is on screen is the legacy
      //          parser's "结果不是有限数值" instead of an `infinity` that looks like a result.
      for (final notFinite in const ['Infinity', 'NaN']) {
        final engine = _FakeMathEngine(
          EngineReply.success(
            MathResult(displayText: notFinite, decimalText: notFinite),
          ),
        );
        final controller = _controller(_FakeDatabase(), engine: engine);

        controller.setExpression('1/0');
        controller.evaluate();
        await pumpEventQueue();

        // 中文：引擎被问过、也回了话，但它的答案没有被采用——屏幕上仍是旧解析器那一条（错误状态
        //       一并在），而不是一个看起来像结果的 `Infinity`。
        // English: The engine was asked and did answer, yet its answer was not adopted — what remains
        //          on screen is the legacy parser's own line (error state included) rather than an
        //          `Infinity` that looks like a result.
        expect(engine.calls, hasLength(1), reason: notFinite);
        expect(controller.result, '等待输入', reason: notFinite);
        expect(controller.errorMessage, '结果不是有限数值', reason: notFinite);
        expect(controller.hasError, isTrue, reason: notFinite);
        controller.dispose();
      }
    });

    test('引擎给出的、放不进 double 的有限值照样采用', () async {
      // 中文：`2^2000`。旧求值器给不出有限值（它只有 double），于是先闪一条错误——这正是裁决 1
      //       里写着的代价——引擎那一份完全有限，只是超出 double 上限，于是被采用并原样显示。
      // English: `2^2000`. The legacy evaluator has no finite answer (it has only a double), so an
      //          error flashes first — the cost ruling 1 names — while the engine's answer is
      //          perfectly finite and merely overflows a double, so it is adopted and shown as it is.
      final engine = _FakeMathEngine(
        EngineReply.success(
          const MathResult(
            displayText: '1.148130695274255E602',
            decimalText: '1.148130695274255E602',
          ),
        ),
      );
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('2^2000');
      controller.evaluate();
      expect(controller.hasError, isTrue, reason: '旧求值器只给得出「结果不是有限数值」');

      await pumpEventQueue();
      expect(controller.hasError, isFalse);
      expect(controller.result, '1.148130695274255E602');
      expect(controller.resultDecimal, '1.148130695274255E602');

      controller.dispose();
    });

    test('策略 (A)：引擎回话之前屏幕上留着上一个结果', () async {
      // 中文：另一条分支也得能跑——把策略做成常量而不是写死，就是为了随时能切过去。
      // English: The other branch has to work too — making the policy a constant rather than
      //          hardcoding it is exactly so it can be switched to.
      final engine = _ReleasableMathEngine();
      final controller = _controller(
        _FakeDatabase(),
        engine: engine,
        liveResultPolicy: LiveResultPolicy.engineOnly,
      );

      controller.applyMathResult(
        const MathResult(displayText: '上一个', decimalText: '7'),
      );
      controller.setExpression('sqrt(32)');
      controller.evaluate();

      // 中文：旧解析器这次没跑，所以屏幕停在上一个结果上——这就是 (A) 的「陈旧值」。
      // English: The legacy parser did not run, so the screen stays on the previous result — (A)'s
      //          "stale value".
      expect(controller.result, '上一个');
      expect(engine.calls, isEmpty);

      await pumpEventQueue();
      expect(engine.calls, hasLength(1));
      expect(controller.result, '上一个',
          reason: '(A) 下引擎回话之前屏幕上没有新结果，也不会退回旧解析器');

      engine.answerAll(sqrt32Reply());
      await pumpEventQueue();
      expect(controller.result, engineDisplay);
      expect(controller.resultTex, engineTex);

      controller.dispose();
    });

    test('策略 (A)：引擎答不出来时补上旧解析器的结果（回落全覆盖）', () async {
      // 中文：(A) 下屏幕上没有旧结果，所以回落必须在引擎失败时**补一次**——否则引擎一坏，结果行
      //       就永远停在旧值上。这是 (A) 比 (B) 多出来的那套逻辑，也正是裁决 1 选 (B) 的理由之一。
      // English: Under (A) there is no legacy result on screen, so the fallback has to *supply one*
      //          when the engine fails — otherwise a broken engine leaves the result line stuck. That
      //          extra rule is exactly what (B) does not need, and one of ruling 1's reasons for (B).
      final engine = _FakeMathEngine(EngineReply.failure('engine_unavailable'));
      final controller = _controller(
        _FakeDatabase(),
        engine: engine,
        liveResultPolicy: LiveResultPolicy.engineOnly,
      );

      controller.setExpression('sqrt(32)');
      controller.evaluate();
      expect(controller.result, '0', reason: '还没跑到引擎那一步，也没有旧结果');

      await pumpEventQueue();
      expect(controller.result, legacyDisplay);
      expect(controller.resultDecimal, legacyDisplay);
      expect(controller.hasError, isFalse);

      controller.dispose();
    });
  });

  group('裁决 2：kill switch 就是 AppSettings.expressionDisplayMode', () {
    test('切到「数学表达式」后边打边算一次都不问引擎，且只剩旧解析器的结果', () async {
      final engine = _FakeMathEngine(sqrt32Reply());
      final controller = _controller(
        _FakeDatabase(),
        engine: engine,
        settings: _settings(expressionDisplayMode: '数学表达式'),
        // 中文：这一条要的就是「按键路径」——注入一个小窗口让显示侧那次求值真的发生。
        // English: This one is about the keypad path, so a small window is injected to make the
        //          display-side evaluation actually happen.
        liveEvaluationDelay: const Duration(milliseconds: 20),
      );

      controller.setExpression('sqrt(32)');
      controller.evaluate();
      controller.input('+1');
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await pumpEventQueue();

      expect(engine.calls, isEmpty);
      expect(controller.result, '6.656854');
      expect(controller.resultDecimal, '6.656854');
      expect(controller.resultTex, isEmpty);

      controller.dispose();
    });

    test('开关开着（默认值）时同样的输入会问引擎', () async {
      final engine = _FakeMathEngine(sqrt32Reply());
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('sqrt(32)');
      controller.evaluate();
      await pumpEventQueue();

      expect(engine.calls, hasLength(1));

      controller.dispose();
    });

    test('运行时把开关拨回去，之后的求值不再问引擎，屏幕回到旧解析器的结果', () async {
      final engine = _FakeMathEngine(sqrt32Reply());
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('sqrt(32)');
      controller.evaluate();
      await pumpEventQueue();
      expect(engine.calls, hasLength(1));
      expect(controller.resultTex, engineTex);

      controller.updateSettings(_settings(expressionDisplayMode: '数学表达式'));
      controller.evaluate();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await pumpEventQueue();

      expect(engine.calls, hasLength(1), reason: '拨回去之后一次都不许再问');
      expect(controller.resultTex, isEmpty);
      expect(controller.result, legacyDisplay);

      controller.dispose();
    });
  });

  group('裁决 3：防抖与「队不积压」', () {
    test('连续输入期间一发都不发，停下来之后只发一发，且问的是最后的表达式', () async {
      // 中文：这条测试钉的是**两个延迟之间的关系**，不是它们的绝对值（生产是 32ms / 120ms，这里
      //       按同样的比例缩小到 20ms / 400ms，好让测试快一点）：击键间隔取在**显示侧那一次之上、
      //       引擎跟进延迟之下**——这正是防抖要挡的那条带。显示侧结果照常随每个安静点刷新，而引擎
      //       调用被一路推后，直到输入真正停下来。引擎跟进延迟取小了这条断言就会失败（每一次显示侧
      //       求值都会带出一发引擎调用）。
      // English: This test pins the **relationship between the two delays**, not their absolute values
      //          (production is 32 ms / 120 ms; the same proportions are scaled down to 20 ms / 400 ms
      //          here so the test stays quick): the key interval sits **above the display-side tick and
      //          below the engine follow-up delay** — the band the debounce exists for. The
      //          display-side result keeps refreshing at each quiet point while the engine call is
      //          pushed back until typing actually stops. Too small an engine delay makes this
      //          assertion fail, because every display-side evaluation drags an engine call out with
      //          it.
      // 中文：延迟取 400ms 而不是刚好高过击键间隔——真实定时器只保证「不早于」，机器一忙就被拉长，
      //       余量太小的话这条测试会随负载随机失败（第一次全量跑正是这样失败的）。
      // English: The delay is 400 ms rather than barely above the key interval — a real timer only
      //          promises "not earlier than", and a busy machine stretches it, so too little headroom
      //          makes this test fail at random with the load (which is exactly how the first full
      //          run failed).
      final engine = _FakeMathEngine(sqrt32Reply());
      final controller = _controller(
        _FakeDatabase(),
        engine: engine,
        liveEvaluationDelay: const Duration(milliseconds: 20),
        liveEngineFollowUpDelay: const Duration(milliseconds: 400),
      );

      for (final key in ['1', '2', '3']) {
        controller.input(key);
        await Future<void>.delayed(const Duration(milliseconds: 45));
        expect(engine.calls, isEmpty, reason: '连续输入期间不许发');
      }

      await Future<void>.delayed(const Duration(milliseconds: 600));
      expect(engine.calls, hasLength(1));
      expect(engine.calls.single.expression, '123');

      controller.dispose();
    });

    test('在飞上限恒为 1：输入再密也不会排成第二发', () async {
      // 中文：引擎**故意不回话**，于是整个测试期间都有一发在飞。期间的每一次输入都会重新排一次
      //       跟进（并且真的到点），但在飞那一发没落地之前，一次都不许发第二发——原生线程池的队列
      //       因此永远只有那一发。
      // English: The engine deliberately does not answer, so one call stays in flight for the whole
      //          test. Every input during that window re-schedules a follow-up (and really reaches its
      //          tick), yet no second call may go out before the first lands — which is why the native
      //          thread pool's queue never holds more than that one.
      final engine = _ReleasableMathEngine();
      final controller = _controller(
        _FakeDatabase(),
        engine: engine,
        // 中文：显示侧那次求值也要走按键路径（`input`），所以窗口取小。
        // English: The display-side evaluation goes through the keypad path (`input`) here, so the
        //          window is small.
        liveEvaluationDelay: const Duration(milliseconds: 20),
        liveEngineFollowUpDelay: const Duration(milliseconds: 20),
      );

      controller.setExpression('1');
      controller.evaluate();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(engine.calls, hasLength(1));
      expect(engine.pending, 1);

      for (var i = 0; i < 5; i++) {
        controller.input('+1');
        await Future<void>.delayed(const Duration(milliseconds: 60));
        expect(engine.pending, 1, reason: '同时只能有一发在飞');
      }
      expect(engine.calls, hasLength(1));
      expect(controller.expression, '1+1+1+1+1+1');

      // 中文：回包到达时表达式早就变了——过期，不落地；但「还欠一次」被补上，补的是**当前**表达式，
      //       而且只有一发。
      // English: By the time the reply arrives the expression has long changed — stale, so nothing
      //          lands; but the "one more is owed" is made good, for the *current* expression and as
      //          one call only.
      engine.answerNext(sqrt32Reply());
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(engine.calls, hasLength(2));
      expect(engine.calls.last.expression, '1+1+1+1+1+1');
      expect(engine.pending, 1);

      engine.answerNext(sqrt32Reply());
      await pumpEventQueue();
      expect(controller.resultDecimal, engineDecimal);

      controller.dispose();
    });

    test('过期回包被丢弃：它描述的是一个已经不在屏幕上的表达式', () async {
      final engine = _ReleasableMathEngine();
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('sqrt(32)');
      controller.evaluate();
      await pumpEventQueue();
      expect(engine.calls, hasLength(1));

      // 中文：请求在飞时用户又输入了。
      // English: The user types on while the request is in flight.
      controller.input('+1');
      controller.evaluate();
      expect(controller.result, '6.656854');

      // 中文：那一发的回包现在才到——它答的是 `sqrt(32)`，屏幕上已经是 `sqrt(32)+1`。
      // English: That reply arrives only now — it answers `sqrt(32)` while the screen already holds
      //          `sqrt(32)+1`.
      engine.answerAll(sqrt32Reply());
      await pumpEventQueue();

      expect(controller.result, '6.656854');
      expect(controller.resultDecimal, '6.656854');
      expect(controller.resultTex, isEmpty);

      controller.dispose();
    });

    test('边打边算的回包不许盖掉提交路径的结果', () async {
      final engine = _ReleasableMathEngine();
      final controller = _controller(
        _FakeDatabase(),
        engine: engine,
        liveEngineFollowUpDelay: const Duration(milliseconds: 20),
      );

      controller.setExpression('sqrt(32)');
      controller.evaluate();
      // 中文：等这一发**真的发出去**（跟进延迟 + 显示侧那一次定时器都到点），而不是靠
      //       `pumpEventQueue`——后者不推进真实时间，在负载下会让「已经发了几发」变成碰运气。
      // English: Wait for this call to **actually go out** (both the follow-up delay and the
      //          display-side tick come due) instead of leaning on `pumpEventQueue`, which does not
      //          advance real time and would turn "how many calls went out" into a coin toss under
      //          load.
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(engine.calls, hasLength(1));

      // 中文：用户按下等号——提交路径也去问引擎（这是第二发在飞）。
      // English: The user presses "=", so the submit path asks the engine too (a second call in
      //          flight).
      final submitted = controller.submit();
      await pumpEventQueue();
      expect(engine.calls, hasLength(2));

      // 中文：边打边算那一发的回包先到，提交那一发的后到。先到的必须被丢掉——代际守卫认得出它。
      // English: The as-you-type reply lands first and the submit's second. The first one has to be
      //          dropped — the generation guard recognises it.
      engine.completeAt(0, sqrt32Reply());
      await pumpEventQueue();
      engine.completeAt(1, sqrt32Reply());
      final result = await submitted;

      expect(result.status, isNot(CalculatorSubmitStatus.superseded));
      expect(controller.resultDecimal, engineDecimal);
      expect(controller.resultTex, engineTex);

      controller.dispose();
    });
  });

  group('裁决 4：有限性判定与提交路径共用一处', () {
    test('边打边算落地的结果与提交路径写同一组状态（Ans/继续使用读的是十进制形态）',
        () async {
      final engine = _FakeMathEngine(sqrt32Reply());
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('sqrt(32)');
      controller.evaluate();
      await pumpEventQueue();

      // 中文：`reusableResult` 是「继续使用」写回表达式的文本、也是 `Ans`/`last` 的来源，它必须是
      //       引擎的**十进制形态**（16 位那一份），不是显示取整后的 `5.656854`。
      // English: `reusableResult` is what "continue with result" writes back and what `Ans`/`last`
      //          resolve from, and it has to be the engine's **decimal form** (the 16-digit one), not
      //          the display-rounded `5.656854`.
      expect(controller.reusableResult, engineDecimal);
      expect(controller.result, engineDisplay);
      expect(controller.resultDecimal, engineDecimal);

      controller.dispose();
    });
  });

  group('界面不被挡住、销毁不留尾巴', () {
    test('输入与求值都是同步返回的，引擎那一段永远在 await 之后', () async {
      final engine = _ReleasableMathEngine();
      final controller = _controller(_FakeDatabase(), engine: engine);

      // 中文：`input` / `setExpression` / `evaluate` 都没有 Future——调用方拿不到可以 await 的东西，
      //       界面因此在结构上就不可能被引擎挡住。`input` 之后表达式立刻就是新的（结果由显示侧的
      //       合并定时器刷新，见 `_scheduleLiveEvaluation`），`evaluate` 之后旧解析器的结果同步就在
      //       屏幕上，而引擎那一发还在定时器里躺着（这里断言的是「同步路径上没有任何引擎调用」）。
      // English: `input`, `setExpression` and `evaluate` all return nothing — callers get nothing to
      //          await, so the interface structurally cannot be blocked on the engine. After `input`
      //          the expression is already the new one (the result is refreshed by the display-side
      //          coalescing timer, see `_scheduleLiveEvaluation`), and after `evaluate` the legacy
      //          parser's result is on screen synchronously while the engine call is still sitting in
      //          its timer (what is asserted here is "no engine call on the synchronous path").
      controller.input('2');
      controller.input('+');
      controller.input('2');
      expect(controller.expression, '2+2');
      controller.evaluate();
      expect(controller.result, '4');
      expect(engine.calls, isEmpty);

      controller.dispose();
    });

    test('销毁时在飞的那一发被收掉，之后的回包不落地也不通知', () async {
      final engine = _ReleasableMathEngine();
      final controller = _controller(_FakeDatabase(), engine: engine);
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.setExpression('sqrt(32)');
      controller.evaluate();
      await pumpEventQueue();
      expect(engine.pending, 1);

      final before = notifications;
      controller.dispose();
      expect(() => engine.answerAll(sqrt32Reply()), returnsNormally);
      await pumpEventQueue();
      expect(notifications, before, reason: '销毁之后不许再通知');
    });

    test('引擎永远不回答时屏幕照常有旧解析器的结果，超时之后这一发被释放', () async {
      final engine = _ReleasableMathEngine();
      final controller = _controller(
        _FakeDatabase(),
        engine: engine,
        engineTimeout: const Duration(milliseconds: 30),
      );

      controller.setExpression('sqrt(32)');
      controller.evaluate();
      await pumpEventQueue();
      expect(engine.pending, 1);
      expect(controller.result, legacyDisplay);

      // 中文：超时到点，那一发按「没有可用结果」处理（不是报错）：屏幕上没有任何变化，错误状态也
      //       没有被点亮——回落对用户不可见这条要求在这里同样成立。在飞名额随之释放。
      // English: The timeout fires and that call counts as "no usable result" (not an error): nothing
      //          changes on screen and no error state lights up — "the fallback is invisible to the
      //          user" holds here too. The in-flight slot is released with it.
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(controller.result, legacyDisplay);
      expect(controller.hasError, isFalse);

      // 中文：释放之后，新的输入仍然能走到引擎——一次卡死不会让这条路从此僵住。
      // English: Once released, a new input still reaches the engine — one stuck call does not leave
      //          this path dead.
      controller.setExpression('6*7');
      controller.evaluate();
      expect(controller.result, '42', reason: '旧解析器的结果始终在屏幕上');
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(engine.calls.last.expression, '6*7');
      // 中文：这里**不能**用替身的 `pending` 当作「在飞上限」——控制器超时之后就不再等那一发了，而
      //       替身并不知道，它的 `pending` 数的是「引擎没回话的调用」，不是「控制器还在等的调用」。
      //       在飞上限由「在飞上限恒为 1」那条测试用没有超时的方式钉住。
      // English: The double's `pending` must **not** be read as the in-flight bound here: once the
      //          controller times out it stops waiting for that call, while the double has no way to
      //          know, so its `pending` counts "calls the engine never answered" rather than "calls
      //          the controller is still waiting on". The bound is pinned by the "at most one in
      //          flight" test, which has no timeout in play.

      controller.dispose();
    });
  });
}

AppSettings _settings({
  int precision = 6,
  bool groupThousands = false,
  String angleMode = 'RAD',
  bool restoreState = false,
  String expressionDisplayMode = kEngineBackedLiveExpressionDisplay,
}) {
  return AppSettings(
    haptics: true,
    hapticStrength: '标准',
    restoreState: restoreState,
    autoSaveHistory: false,
    angleMode: angleMode,
    precision: precision,
    themeModeLabel: '跟随系统',
    expressionDisplayMode: expressionDisplayMode,
    groupThousands: groupThousands,
  );
}

/// 中文：两个延迟的默认注入值，都是为了把**真实定时器**从断言里拿掉：
///
///       - **显示侧那 32ms 默认推到 10 分钟之后**。真实定时器只保证「不早于」，机器一忙就被拉长，
///         而 `pumpEventQueue()` 只让出事件循环、不推进真实时间——它那 20 轮在负载下有可能超过
///         32ms，于是那一次显示侧求值会在测试没料到的时候插进来，凭空多出一发引擎调用。默认把这个
///         定时器挪远，需要它参与的那几条测试自己注入一个小值。
///       - **引擎跟进默认 `Duration.zero`**：下一次事件循环轮转就到点，测试于是能用
///         `pumpEventQueue()` 精确控制「这一发发出去了没有」，不必真的等 120ms。
///
/// English: The default injected values of both delays exist to take **real timers** out of the
///          assertions:
///
///          - **The 32 ms display-side window is pushed ten minutes out.** A real timer only promises
///            "not earlier than", so a busy machine stretches it, and `pumpEventQueue()` only yields
///            the event loop without advancing real time — under load its 20 turns can exceed 32 ms,
///            at which point that display-side evaluation cuts in where the test did not expect it and
///            conjures an extra engine call. Moving that timer away by default keeps the assertions
///            exact; the few tests that need it inject a small value themselves.
///          - **The engine follow-up defaults to `Duration.zero`**: it comes due on the next turn of
///            the event loop, so tests can control "has this call gone out yet" precisely with
///            `pumpEventQueue()` instead of really waiting 120 ms.
CalculatorController _controller(
  _FakeDatabase db, {
  required MathEngine engine,
  AppSettings? settings,
  Duration engineTimeout = const Duration(seconds: 5),
  Duration liveEvaluationDelay = const Duration(minutes: 10),
  Duration liveEngineFollowUpDelay = Duration.zero,
  LiveResultPolicy liveResultPolicy = kLiveResultPolicy,
}) {
  return CalculatorController(
    historyRepository: HistoryRepository(db),
    notesRepository: NotesRepository(db),
    settingsRepository: SettingsRepository(db),
    settings: settings ?? _settings(),
    engine: engine,
    engineTimeout: engineTimeout,
    liveEvaluationDelay: liveEvaluationDelay,
    liveEngineFollowUpDelay: liveEngineFollowUpDelay,
    liveResultPolicy: liveResultPolicy,
  );
}

/// 中文：立刻回话的替身，记下每次调用的表达式与角度模式。
/// English: A double that answers at once, recording every call's expression and angle mode.
class _FakeMathEngine implements MathEngine {
  _FakeMathEngine(this.reply);

  final EngineReply reply;
  final List<({String expression, String angleMode})> calls = [];
  String get resultDecimal => reply.result?.decimalText ?? '';

  @override
  Future<EngineReply> evaluate(
    String expression, {
    required String angleMode,
  }) async {
    calls.add((expression: expression, angleMode: angleMode));
    return reply;
  }
}

/// 中文：回包何时到达由测试决定的替身。用来看住「同时只能有一发在飞」与「过期回包不落地」。
/// English: A double whose replies the test releases when it wants. It exists to watch "at most one
///          call in flight" and "a stale reply never lands".
class _ReleasableMathEngine implements MathEngine {
  final List<({String expression, String angleMode})> calls = [];
  final List<Completer<EngineReply>> _pending = [];

  /// 中文：还没回话的调用数。
  /// English: How many calls have not answered yet.
  int get pending => _pending.where((completer) => !completer.isCompleted).length;

  /// 中文：按发出顺序完成第 [index] 发。
  /// English: Complete the call at [index] in the order they were issued.
  void completeAt(int index, EngineReply reply) {
    final completer = _pending[index];
    if (!completer.isCompleted) completer.complete(reply);
  }

  void answerNext(EngineReply reply) {
    completeAt(_pending.indexWhere((completer) => !completer.isCompleted), reply);
  }

  void answerAll(EngineReply reply) {
    for (final completer in _pending) {
      if (!completer.isCompleted) completer.complete(reply);
    }
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
