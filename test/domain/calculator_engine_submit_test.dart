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

    // 中文：`ans` 的替换照旧发生在翻译**之前**（`_resolveAnswerReferences`），所以第二个表达式
    //       里被问的是替换后的 `42`，只是它同样被翻译成了括号形式。
    // English: `ans` is still substituted **before** the translation (`_resolveAnswerReferences`), so
    //          the second expression is asked with the substituted `42` — which is itself translated
    //          into the parenthesised form.
    expect(engine.calls.map((call) => call.expression),
        ['((6)*(7))', '((42)+(1))']);

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

  test('an engine reply with no decimal form is displayed, and is not a number', () async {
    // 中文：**这条规则在修复轮 7 变了，断言因此是反过来的。** 以前「没有十进制形态」等于「没有
    //       可用答案」，整条回落旧解析器（显示旧解析器的 `5.656854`、LaTeX 为空）；那条规则的
    //       前提是「引擎的答案可能是误读」，而翻译把那件事消除了——交给引擎的已经是翻译后的表达式。
    //       取舍于是只剩三级：词表拦下 / 有限十进制当数字用 / **可显示就显示**。这里钉第三级，
    //       以及那条**没有**放宽的边界：数值消费者（`Ans`/记忆）仍旧拿不到它。
    // English: **this rule changed in fix round 7, so the assertions are the other way round.** "No
    //          decimal form" used to mean "no usable answer" and the whole thing fell back to the
    //          legacy parser (which showed its `5.656854`, with no LaTeX); that rule's premise was
    //          "the engine's answer may be a misreading", which the translation removes — what
    //          reaches the engine is already the translated expression. Three tiers are left: the
    //          vocabulary stops it / a finite decimal is used as a number / **a displayable answer is
    //          displayed**. This pins the third tier and the boundary that was **not** relaxed:
    //          numeric consumers (`Ans`/memory) still get nothing from it.
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
    expect(exactForm.hasError, isFalse);
    expect(exactForm.result, r'4\sqrt{2}');
    expect(exactForm.resultTex, r'4\sqrt{2}');
    // 中文：十进制形态是空的——数值消费者据此拒绝它，而不是静默当成 0。
    // English: the decimal form is empty — which is how numeric consumers refuse it instead of
    //          silently reading a 0.
    expect(exactForm.resultDecimal, isEmpty);
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
    // 中文：`2^-2000 ≈ 8.709809816e-603` 是同一根因的另一端，也是**更严重**的一端：`double.tryParse`
    //       返回 `0.0`（不是 Infinity），`isFinite` 为真，于是答案被接受，而 `Ans`、`last`、
    //       记忆寄存器全部拿到 0——不抛异常、不报错，给一个错值。
    // English: `2^-2000 ≈ 8.709809816e-603` is the other end of the same root cause and the worse one:
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

  test('as-you-type evaluation answers synchronously while the submit path owns its own engine call',
      () async {
    // 中文：这条测试以前叫「as-you-type evaluation never asks the engine」，断言的是 3d 的硬边界
    //       ——`evaluate()` 一次都不问引擎。**那条边界正是 3e 拆掉的东西**，所以这里不再断言它：
    //       引擎在边打边算上什么时候被问到、回包怎么落地、过期怎么丢，归
    //       `calculator_engine_live_test.dart`（那个文件注入毫秒级延迟来精确控制那一发）。
    //
    //       留在这里、并且必须继续成立的是另外两件事：
    //       1. 输入路径上**同步**就有结果（裁决 1 的即时反馈不依赖引擎）；
    //       2. 提交路径**一个引擎调用都没多**——边打边算的跟进被夹具推到 1 小时后（见 `_controller`），
    //          于是这一次 `submit()` 的调用计数仍然恰好是 1，与 3d 时一模一样。
    //
    // English: This test used to be called "as-you-type evaluation never asks the engine" and asserted
    //          3d's hard boundary — that `evaluate()` never consults the engine. **That boundary is
    //          exactly what 3e removes**, so it is no longer asserted here: when the engine is asked
    //          during as-you-type evaluation, how its reply lands and how stale ones are dropped all
    //          belong to `calculator_engine_live_test.dart` (which injects a millisecond-scale delay
    //          to control that call precisely).
    //
    //          What stays here, and must keep holding, is two other things:
    //          1. the input path has a result **synchronously** (ruling 1's instant feedback does not
    //             depend on the engine);
    //          2. the submit path gains **not one extra engine call** — the as-you-type follow-up is
    //             pushed an hour out by the fixture (see `_controller`), so this `submit()` still
    //             makes exactly one call, precisely as it did at 3d.
    final engine = _FakeMathEngine(sqrt32Reply());
    final controller = _controller(_FakeDatabase(), engine: engine);

    controller.setExpression('sqrt(32)');
    controller.evaluate();

    expect(controller.result, engineDisplay);
    expect(controller.resultDecimal, engineDisplay);
    expect(controller.resultTex, isEmpty, reason: '引擎还没被问到，精确形态自然还没有');
    expect(engine.calls, isEmpty);

    // 中文：按键路径（`input`）同样如此：表达式立刻是新的，结果由显示侧的合并定时器刷新。
    // English: The keypad path (`input`) behaves the same way: the expression is immediately the new
    //          one, and the result is refreshed by the display-side coalescing timer.
    controller.setExpression('');
    controller.input('6');
    controller.input('*');
    controller.input('7');
    expect(controller.expression, '6*7');
    expect(engine.calls, isEmpty);

    // 中文：回包与表达式一致（`6*7` = 42）——新判据只采用「值与应用一致」的引擎答案，
    //       不一致的回包会被**正确**丢弃，所以这里给一个自洽的替身。
    // English: the reply agrees with the expression (`6*7` = 42) — the new criterion adopts only an
    //          engine answer whose value matches the app's, discarding disagreeing ones by design, so
    //          this double is made self-consistent.
    engine.reply = EngineReply.success(
      const MathResult(displayText: '42', displayTex: '42', decimalText: '42'),
    );
    final submitted = await controller.submit();
    expect(engine.calls, hasLength(1));
    expect(submitted.submitted, isTrue);
    expect(controller.resultTex, '42');

    controller.dispose();
  });

  test(
      'a beyond-double value written back into the expression never reaches the memory',
      () async {
    // 中文：**可从界面走通**的那条路（修复轮 2 的第 1 条）：
    //       `2^-2000` → `=` →「继续使用」→ `M+`。
    //       「继续使用」把结果文本写回表达式之后，记忆寄存器的表达式分支会直接问旧解析器，
    //       而那个 double 早就丢了量程：`…E-603` 变成 `0.0`（寄存器静默变 0），
    //       `…E602` 变成 `Infinity`（寄存器里是 Infinity，还会持久化、重启后还在）。
    //       现在这条分支与提交路径共用同一处判定。
    // English: The path *reachable from the UI* (fix round 2, item 1):
    //          `2^-2000` → `=` → "continue with result" → `M+`.
    //          Once "continue with result" has written the result text back, the memory register's
    //          expression branch asks the legacy parser directly, and that double lost the range
    //          long ago: `…E-603` becomes `0.0` (the register silently turns 0) and `…E602` becomes
    //          `Infinity` (the register holds Infinity — which persists across a restart). That
    //          branch now shares one judgement implementation with the submit path.
    const tiny = '8.709809816217217E-603';
    const huge = '1.148130695274255E602';
    final engine = _FakeMathEngine(
      EngineReply.success(const MathResult(displayText: '5', decimalText: '5')),
    );
    final db = _FakeDatabase();
    final controller = _controller(
      db,
      engine: engine,
      settings: _settings(restoreState: true),
    );

    // 中文：寄存器先有一个真实的非零值，「加了 0」「加了 Infinity」与「什么都没加」才分得开。
    // English: Give the register a real non-zero value first, so "added a 0", "added Infinity" and
    //          "added nothing" are distinguishable.
    controller.setExpression('5');
    await controller.submit();
    controller.memoryAdd();
    expect(controller.memoryValue, 5);

    for (final (expression, beyondDouble) in [
      ('2^-2000', tiny),
      ('2^2000', huge),
    ]) {
      engine.reply = EngineReply.success(
        MathResult(displayText: beyondDouble, decimalText: beyondDouble),
      );
      controller.setExpression(expression);
      await controller.submit();
      controller.continueWithResult();
      expect(controller.expression, beyondDouble, reason: expression);

      controller.memoryAdd();
      expect(controller.memoryValue, 5, reason: '$expression / M+');
      controller.memorySubtract();
      expect(controller.memoryValue, 5, reason: '$expression / M-');

      // 中文：寄存器里的**数值**分不开「加了 0」与「什么都没加」（5 + 0 还是 5），所以下溢那一行
      //       要看副作用：成功时 `memoryAdd` 会推撤销快照、改状态代际并落盘，被拒时一件都不做。
      //       这两句之间没有 `await`，那个 32ms 的实时求值定时器插不进来。
      // English: The register's *value* cannot tell "added a 0" from "added nothing" (5 + 0 is still
      //          5), so the underflow row has to look at the side effects: a successful `memoryAdd`
      //          pushes an undo snapshot, bumps the state revision and persists, a refused one does
      //          none of it. Nothing `await`s between these two lines, so the 32ms live-evaluation
      //          timer cannot slip in.
      db.savedSettings.clear();
      controller.memoryAdd();
      expect(db.savedSettings, isEmpty, reason: '$expression / 被拒时不许有任何副作用');

      // 中文：也不能被持久化成一个错值（`Infinity` 会活过一次重启）。
      // English: And it must not be persisted as a wrong value (`Infinity` survives a restart).
      controller.applyPastedText('角度模式: RAD');
      await Future<void>.delayed(Duration.zero);
      expect(db.savedSettings['calculator_memory'], '5.0', reason: expression);
    }

    controller.dispose();
  });

  test('an expression that evaluates to infinity is not added to the memory',
      () async {
    // 中文：表达式分支的另一半——表达式不是单个数字时走旧解析器，算出来的 double 同样要过判定。
    //       `1/0` 以前会把 `Infinity` 放进去，而且同样会持久化。
    // English: The other half of the expression branch — a non-literal expression goes to the
    //          legacy parser, and the double it computes goes through the same judgement. `1/0` used
    //          to put `Infinity` in the register, where it persisted too.
    final controller =
        _controller(_FakeDatabase(), engine: _FakeMathEngine(null));

    controller.setExpression('5');
    await controller.submit();
    controller.memoryAdd();
    expect(controller.memoryValue, 5);

    controller.setExpression('1/0');
    controller.memoryAdd();
    expect(controller.memoryValue, 5);

    controller.dispose();
  });

  test('a synchronously throwing engine still falls back', () async {
    // 中文：这是修复轮 1 **引入的回归**。`async` 实现抛出来是一个被拒绝的 Future（走 `onError`），
    //       但同步实现可以在返回 Future 之前直接抛——把引擎调用移出原来那个 `try` 之后，这一抛
    //       会一路冒到 `submit()` 的 catch，`=` 于是从「回落旧解析器给出 5」变成「表达式错误」。
    // English: This is the regression fix round 1 *introduced*. An `async` implementation's throw
    //          becomes a rejected future (handled by `onError`), but a synchronous implementation can
    //          throw before it returns a future at all — and once the engine call moved out of the old
    //          `try`, that throw reached `submit()`'s catch, turning "=" from a legacy fallback
    //          yielding 5 into 表达式错误.
    final controller = _controller(
      _FakeDatabase(),
      engine: _SyncThrowingMathEngine(),
    );

    controller.setExpression('2+3');
    final submitted = await controller.submit();

    expect(controller.result, '5');
    expect(controller.hasError, isFalse);
    expect(submitted.status, CalculatorSubmitStatus.calculated);

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

/// 中文：**同步**抛出的替身：在返回 Future 之前就抛。`async` 方法做不到这一点（它的抛出会变成
///       一个被拒绝的 Future），所以这个替身必须是普通方法。
/// English: A *synchronous* thrower: it throws before returning a future. An `async` method cannot
///          do that (its throw becomes a rejected future), so this double must be a plain method.
class _SyncThrowingMathEngine implements MathEngine {
  @override
  Future<EngineReply> evaluate(
    String expression, {
    required String angleMode,
  }) {
    throw PlatformException(code: 'sync_throw', message: '炸在返回 Future 之前');
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
