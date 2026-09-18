import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/application/controllers/calculator_controller.dart';
import 'package:nekocalc/core/math/math_engine.dart';
import 'package:nekocalc/core/math/math_result.dart';
import 'package:nekocalc/core/math/result_text_rules.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/repositories/history_repository.dart';
import 'package:nekocalc/data/repositories/notes_repository.dart';
import 'package:nekocalc/data/repositories/settings_repository.dart';

/// 中文：**修复轮 7 的判据：先把表达式翻译成引擎的写法，再采用它的答案。**
///
///       - 采用规则只剩三级：**词表在名字层拦下** / **有限十进制 ⇒ 当数字用** / **可显示 ⇒ 上结果
///         行**；其余按「这一次没有引擎答案」回落旧解析器。
///       - **没有值比较。** 它问的是「引擎的值与应用的 `double` 一致吗」，而那个问题的前提是错的：
///         在引擎真正有价值的场合——超出 double 量程、灾难性相消、大角度——应用的 `double` 恰恰是
///         错的那一方。本文件最后一组就是被它杀死的**三个活错值**。
///       - 名字那一层还在（`AppEngineVocabulary`）：`log`/`mod`/`phi` 这些「引擎读不了这个拼法」
///         的名字，引擎的答案一律不采用。第一组钉住这个行为。
///
///       每个引擎文本都是**实测的引擎原文**：在宿主上对 libqalculate **5.12.0** 按**桥自己的调用
///       序列**量得（`unlocalizeExpression` → `calculate(EXACT)` → `calculate(APPROXIMATE)` →
///       `print(TERMINAL)`，精度 16、`INTERVAL_DISPLAY_MIDPOINT`，见
///       `tool/qalculate_semantics_probe/probe.cc` 的同一条序列），替身只是把它送回同一个表达式。
///       真机与宿主的差别没有被抹掉：这里能钉的是**取舍**，不是引擎本身。
/// English: **fix round 7's criterion: translate the expression into the engine's language, then take
///          the engine's answer.**
///
///          - taking an answer has three tiers: **the vocabulary stops it at the name layer** / **a
///            finite decimal is used as a number** / **a displayable answer goes on the result line**;
///            anything else counts as "no engine answer this time" and falls back to the legacy parser.
///          - **there is no value comparison.** It asked "does the engine's value match this app's
///            `double`", a premise that is false: in exactly the cases the engine exists for — beyond
///            the double range, catastrophic cancellation, large angles — this app's `double` is the
///            wrong side. The last group below is the **three live wrong values** it killed.
///          - the name layer is still there (`AppEngineVocabulary`): for names the engine cannot be
///            trusted with (`log`/`mod`/`phi`/…) its answer is never used. The first group pins that.
///
///          Every engine string is a **measured engine answer**: measured on the host against
///          libqalculate **5.12.0** **through the bridge's own call sequence**
///          (`unlocalizeExpression` → `calculate(EXACT)` → `calculate(APPROXIMATE)` →
///          `print(TERMINAL)`, precision 16, `INTERVAL_DISPLAY_MIDPOINT`; the sequence in
///          `tool/qalculate_semantics_probe/probe.cc`), and the double only hands it back for the same
///          expression. What this can pin is the **selection**, not the engine itself; the
///          device-vs-host difference is not papered over.
void main() {
  group('名字层：引擎读不了这个拼法时，它的答案一律不采用', () {
    // 中文：这里的样本都是这五轮里出现过的**活错值**——引擎对它们**不报错**，只是把名字读成了
    //       别的东西（`log` 是自然对数、`mod` 的余数定义不同）。修复轮 7 之后它们挡在**名字层**
    //       （`canRead`）：翻译那一层也各有分晓，但这一层更早。
    //
    //       **`phi(2)` 曾经是这一组的一行；修复轮 9 起它不是了，而且不是被删掉，是搬走了。** 名字层
    //       现在读归一化之后的字符串，而归一化把 `phi(2)` 写成 `phi*(2)`（常量乘分组，**不再是调用**
    //       ——实测 `ExpressionParser.normalizeExpressionInput`），所以这一层对它无话可说；常量那件事
    //       由翻译了结（把 `phi` 写成它的数值），引擎对 `((1.618033988749895)*((2)))` 的答复
    //       `3.23606797749979`（实测）就是应用自己的值。它的三种拼法因此由下面 `φ(2)` 那一条钉住
    //       （问出去的字符串 + 屏幕上的值），屏幕值另有一条在
    //       `calculator_engine_display_gate_test.dart`。
    // English: every sample here is a **live wrong value** from these rounds — the engine does not
    //          error on them, it just reads the name as something else (`log` is the natural
    //          logarithm, `mod`'s remainder is defined differently). After fix round 7 they are
    //          stopped at the **name layer** (`canRead`); the translation layer settles them too, but
    //          this one comes first.
    //
    //          **`phi(2)` used to be a row here; since fix round 9 it is not — and it was moved, not
    //          deleted.** The name layer now reads the normalised string, and normalisation writes
    //          `phi(2)` as `phi*(2)` (a constant times a group, **no longer a call** — measured with
    //          `ExpressionParser.normalizeExpressionInput`), so this layer has nothing to say about it.
    //          The constant is settled by the translation (it writes `phi` as its value) and the
    //          engine's measured answer for `((1.618033988749895)*((2)))`, `3.23606797749979`, is this
    //          app's own value. Its three spellings are pinned by the `φ(2)` row below (the string
    //          asked + the value on screen), with a screen-value row in
    //          `calculator_engine_display_gate_test.dart`.
    const cases = <({String expression, String engineText, String expected})>[
      // 引擎的 `log` 是自然对数（实测 4.605170185988091），应用的是常用对数（翻译写成 `log10`）。
      (expression: 'log(100)', engineText: '4.605170185988091', expected: '2'),
      // 引擎的 `mod(7,-3)` 是 -2，应用的 `%` 是欧几里得余数 1。
      (expression: 'mod(7,-3)', engineText: '-2', expected: '1'),
    ];

    for (final row in cases) {
      test('${row.expression}：屏幕上是 ${row.expected}，不是引擎的 ${row.engineText}',
          () async {
        final controller = _controller(
          _FakeDatabase(),
          engine: _FakeMathEngine(_reply(row.engineText)),
        );

        controller.setExpression(row.expression);
        await controller.submit();

        expect(controller.result, row.expected,
            reason: '${row.expression} 采用了引擎的值 ${row.engineText}');
        // 中文：应用自己的值同时也是十进制形态（`Ans`/记忆用它）。
        // English: the app's own value is also the decimal form (`Ans`/memory use it).
        expect(controller.resultDecimal, row.expected);
        expect(controller.hasError, isFalse);

        controller.dispose();
      });
    }
  });

  group('canRead 那一层是必要的：这些输入上它挡下的是屏幕上的值（修复轮 8 起）', () {
    // 中文：**修复轮 7 在词表文件头写过「这一层不再改变屏幕上任何一个值」，那句话是假的。**
    //       `log(8,2)` 与 `fact(171)` 是修复轮 8 量的两条反例；修复轮 9 又补了 `fact 171`
    //       （裸调用）与 `ｌｇ(8,2)`（全角）两条——它们只有**归一化之后**才成为词汇表里的名字。
    //       四条都**可以失败**：把 `canRead` 变异成恒为 `true`（或把它读的输入改回原文），
    //       红都在屏幕值上（引擎的答复上屏）。
    //       每一条的引擎文本都是实测的（宿主 libqalculate 5.12.0，桥的调用序列）。
    // English: **fix round 7 wrote "this layer no longer changes any value on screen" in the vocabulary
    //          header, and that sentence is false.** `log(8,2)` and `fact(171)` are the two
    //          counterexamples fix round 8 measured; fix round 9 added `fact 171` (a bare call) and
    //          `ｌｇ(8,2)` (full-width) — spellings that only become vocabulary names **after
    //          normalisation**. All four **can fail**: mutate `canRead` to a constant `true` (or put
    //          its input back to the raw source) and every red lands on the screen value (the engine's
    //          reply reaching the screen). Every engine text here is measured (host libqalculate
    //          5.12.0, the bridge's call sequence).
    test('log(8,2)（logₓy 键）：引擎对 log10(8,2) 答二元素向量，屏幕上是应用的 3', () async {
      final engine = _MeasuredEngine();
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('log(8,2)');
      await controller.submit();

      expect(engine.calls.single.expression, 'log10(8,2)');
      expect(controller.result, '3');
      expect(controller.resultDecimal, '3');
      expect(controller.hasError, isFalse);

      controller.dispose();
    });

    test('φ(2)：与应用里的 `phi(2)` 是同一个式子，引擎被问的是常量的数值', () async {
      // 中文：**这一条以前是名字层那个循环里的一行**（替身对**任何**表达式都回 `1`，也就是模拟
      //       「引擎把 `φ` 读成了欧拉函数」）。修复轮 8 之后它不能那样测了：归一化把 `φ` 写成 `phi`，
      //       翻译再把 `phi` 写成**它的数值**，于是引擎被问的是 `(1.618033988749895)*(2)`，
      //       而它对这一问的答复（实测 `3.23606797749979`）**就是应用自己的值**——替身那声「1」
      //       描述的是一份永远不会被问到的表达式。
      //       所以这一条现在钉的是**翻译**（问的是常量的数值）而不是名字层，而且它照样钉住值：
      //       `φ` / `phi` / `ϕ` 三种拼法必须给同一个数。
      //
      //       **修复轮 9 起三种拼法走的是同一条路。** 名字层读的也是归一化之后的字符串了，
      //       而归一化把三种拼法都写成 `phi*(2)`（常量乘分组，不再是调用），所以它不再拦 `phi(2)`
      //       （ASCII）——三种拼法全部由引擎作答，十进制形态因此**同精度**（引擎那一份未取整的）。
      //       屏幕上显示的数不变（`3.236068`，`formatNumber(precision: 6)`），换的是作答那条路。
      // English: **this used to be one row of the name layer's loop** (the double answered `1` for
      //          **every** expression, modelling "the engine read `φ` as Euler's function"). After fix
      //          round 8 that is no longer how it behaves: normalisation writes `φ` as `phi`, the
      //          translation writes `phi` as **its value**, so the engine is asked
      //          `(1.618033988749895)*(2)` and its answer to that (measured `3.23606797749979`) **is this
      //          app's own value** — the double's "1" described an expression that is never asked.
      //          So this row now pins the **translation** (that the constant's value is what is asked),
      //          and it still pins a value: the three spellings `φ` / `phi` / `ϕ` have to agree.
      //
      //          **Since fix round 9 all three spellings take the same path.** The name layer reads the
      //          normalised string too now, and normalisation writes all three as `phi*(2)` (a constant
      //          times a group, no longer a call), so it no longer stops `phi(2)` (ASCII) — all three
      //          are answered by the engine, and the decimal form is therefore **of one precision**
      //          (the engine's unrounded one). The number shown does not change (`3.236068`,
      //          `formatNumber(precision: 6)`); what changes is which path answers.
      for (final spelling in <String>['φ(2)', 'ϕ(2)', 'phi(2)']) {
        final engine = _MeasuredEngine();
        final controller = _controller(_FakeDatabase(), engine: engine);

        controller.setExpression(spelling);
        await controller.submit();

        expect(engine.calls.single.expression, '((1.618033988749895)*((2)))',
            reason: spelling);
        // 中文：**屏幕上的值三种拼法相同**——这是这一条真正要钉的事。
        // English: **the value on screen is the same for all three spellings** — what this row is
        //          really pinning.
        expect(controller.result, '3.236068', reason: spelling);
        // 中文：三种拼法现在都由引擎作答，十进制形态是引擎那一份未取整的（修复轮 9 之前
        //       `phi(2)` 还带着旧解析器那条路的取整值 `3.236068`）——**显示出来的数没变**。
        // English: all three are answered by the engine now, so the decimal form is the engine's
        //          unrounded one (before fix round 9 `phi(2)` still carried the legacy path's rounded
        //          `3.236068`) — **the number shown is unchanged**.
        expect(controller.resultDecimal, '3.23606797749979', reason: spelling);

        controller.dispose();
      }
    });

    test('fact(171)：引擎的阶乘定义域比应用宽，屏幕上是应用的错误', () async {
      final engine = _MeasuredEngine();
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('fact(171)');
      await controller.submit();

      expect(engine.calls.single.expression, 'factorial(171)');
      expect(controller.hasError, isTrue);
      expect(controller.result, isNot('1.241018070217668E309'));

      controller.dispose();
    });

    test('fact 171（裸调用）：归一化之后才是 `fact(`，引擎的答案不许用', () async {
      // 中文：**修复轮 9 的第一条红证。** `fact 171` 里没有括号，`_callName` 的正则看不见这个调用；
      //       归一化（`_normalizeBareUnaryFunctionCalls`）把它写成 `fact(171)`，于是名字层读到的
      //       正是那个 `fact(`，落在「不可用」那一列。修复轮 9 之前这一层读原文、判真，引擎对
      //       `factorial(171)` 的答复 `1.241018070217668E309`（实测）因此上屏，而应用自己的答案是
      //       「阶乘只支持 0 到 170 的整数」。裸调用（`名字 数字`）是这个应用**明确支持并测过**的
      //       输入形态（`test/core/expression_parser_test.dart` 那一组，键盘可达），不是粘贴才有的写法。
      // English: **fix round 9's first red proof.** `fact 171` has no bracket, so `_callName`'s regex
      //          cannot see the call; normalisation (`_normalizeBareUnaryFunctionCalls`) writes it as
      //          `fact(171)`, so the name layer reads exactly that `fact(` and it lands in the unusable
      //          column. Before fix round 9 this layer read the raw source and said true, so the
      //          engine's measured `1.241018070217668E309` for `factorial(171)` reached the screen,
      //          where this app's own answer is "阶乘只支持 0 到 170 的整数". A bare call (`name
      //          number`) is an input form this app **supports and tests** (the group in
      //          `test/core/expression_parser_test.dart`, keypad-reachable), not a paste-only curiosity.
      final engine = _MeasuredEngine();
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('fact 171');
      await controller.submit();

      expect(engine.calls.single.expression, 'factorial(171)',
          reason: '归一化把裸调用写成 `fact(171)`，翻译再写成 `factorial(171)`');
      expect(controller.result, '阶乘只支持 0 到 170 的整数');
      expect(controller.hasError, isTrue);

      controller.dispose();
    });

    test('ｌｇ(8,2)（全角字母）：归一化之后才是 `log(`，引擎的答案不许用', () async {
      // 中文：**修复轮 9 的第二条红证。** 全角拉丁字母（`U+FF21`–`U+FF5A`）不在 `_callName` 的
      //       `[A-Za-z]` 里；`_normalizeFullWidthAscii` 把 `ｌｇ` 写成 `lg`，别名表再折成 `log`，
      //       于是名字层看得见这个调用。修复轮 9 之前判真，引擎对 `log10(8,2)` 的二元素向量
      //       `[0.9030899869919436  0.3010299956639812]`（实测）上屏，而应用自己给 `3`。
      //       `ｆａｃｔ(171)` 是同一类的另一个实例（同样实测过）。
      // English: **fix round 9's second red proof.** Full-width Latin (`U+FF21`–`U+FF5A`) is not in
      //          `_callName`'s `[A-Za-z]`; `_normalizeFullWidthAscii` writes `ｌｇ` as `lg` and the
      //          alias table folds that to `log`, so the name layer can see the call. Before fix round
      //          9 it said true, and the engine's measured two-element vector for `log10(8,2)`,
      //          `[0.9030899869919436  0.3010299956639812]`, reached the screen where this app gives
      //          `3`. `ｆａｃｔ(171)` is the same class's other measured instance.
      final engine = _MeasuredEngine();
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('ｌｇ(8,2)');
      await controller.submit();

      expect(engine.calls.single.expression, 'log10(8,2)');
      expect(controller.result, '3');
      expect(controller.resultDecimal, '3');
      expect(controller.hasError, isFalse);

      controller.dispose();
    });

    test('1.5° to arcmin：名字层判假，但翻译器先拒了 `degangle`——引擎一次都没被问', () async {
      // 中文：这条钉的是**修复轮 9 那条期望值改动为什么不改变屏幕**。`1.5° to arcmin` 归一化之后是
      //       `degangle(1.5) to arcmin`（`°` 写成内部名字 `degangle`，见 `_replaceDegreeSign`），
      //       里面有一个 `degangle` 调用，于是 `canRead` 判假（修复轮 9 之前它读原文、判真；
      //       `°` 修好之前这里写的是 `rad`，判的同样是假）。**两种判词下屏幕都一样**：
      //       `_askEngineTranslated` 先问翻译器，翻译器对 `degangle` 给「词表里这个名字没有引擎写法」，
      //       引擎**根本没被问**（`calls` 为空），走旧解析器，而旧解析器读不了 `to` ——应用自己的错误。
      //       所以这一条在「把 `canRead` 的输入改回原文」的变异体里仍然是绿的，只有
      //       `calculator_engine_display_gate_test.dart` 里那条 `canRead('1.5° to arcmin')` 的期望值
      //       断言会红。
      // English: this pins **why fix round 9's expectation change does not change the screen**.
      //          `1.5° to arcmin` normalises to `degangle(1.5) to arcmin` (`°` is written as the
      //          internal name `degangle`; see `_replaceDegreeSign`), which contains a `degangle` call,
      //          so `canRead` says false (before fix round 9 it read the raw source and said true, and
      //          before the `°` fix this text held `rad`, which also said false). **The screen is the
      //          same either way**: `_askEngineTranslated` consults the translator first, the
      //          translator has no engine spelling for `degangle`, the engine is **never asked**
      //          (`calls` is empty) and the legacy parser answers — and it cannot read `to`, so this is
      //          the app's own error. That is why this row stays green in the "put `canRead`'s input
      //          back to the raw source" mutant; only the `canRead('1.5° to arcmin')` expectation in
      //          `calculator_engine_display_gate_test.dart` goes red there.
      final engine = _MeasuredEngine();
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('1.5° to arcmin');
      await controller.submit();

      expect(engine.calls, isEmpty, reason: '翻译器先拒了 `rad`，引擎不该被问');
      expect(controller.result, '存在无法识别的内容');
      expect(controller.hasError, isTrue);

      controller.dispose();
    });

    test('sin(30°)：两种角度模式下引擎一次都不被问，旧解析器给 0.5', () async {
      // 中文：**这条钉的是「`°` 的修好没有把引擎那条路打开」**，以及**屏幕上真的不再是那个错值**。
      //       修复前：`sin(30°)` 归一化写成 `sin(rad(30))`，翻译器拒了 `rad`，引擎一次都没被问，
      //       旧解析器在 DEG 下把实参再乘一次 π/180——屏幕上写着 0.009138（设备 `d87f1aa3` 实测）。
      //       现在：`°` 归一化写成内部名字 `degangle(30)`，翻译器**仍旧**拒绝（引擎没有这个拼法），
      //       所以引擎那一边逐字未变（`calls` 为空），而旧解析器按当前角度单位给值：两种模式下都是
      //       `sin(30°)` = 0.5，与参考实现（宿主 `qalc` 5.12.0，两个角度模式）一致。
      //       两种模式都断一次，是因为这条错值**只在 DEG 下出现过**——只断一种就漏得掉它。
      // English: **this pins that fixing `°` did not open the engine route**, and that the screen no
      //          longer carries the wrong value. Before the fix: `sin(30°)` normalised to
      //          `sin(rad(30))`, the translator refused `rad`, the engine was never asked, and the
      //          legacy parser multiplied the argument by π/180 a second time under DEG — the screen
      //          read 0.009138 (measured on device `d87f1aa3`). Now `°` normalises to the internal name
      //          `degangle(30)`, the translator **still** refuses it (the engine has no such spelling),
      //          so the engine side is byte for byte unchanged (`calls` is empty), while the legacy
      //          parser gives the value in the current angle unit: `sin(30°)` = 0.5 in **both** modes,
      //          matching the reference (host `qalc` 5.12.0, both angle modes). Both modes are asserted
      //          because that wrong value only ever appeared under DEG — pinning one mode would miss it.
      for (final mode in <String>['DEG', 'RAD']) {
        final engine = _MeasuredEngine();
        final controller = _controller(
          _FakeDatabase(),
          engine: engine,
          settings: AppSettings(
            haptics: true,
            hapticStrength: '标准',
            restoreState: false,
            autoSaveHistory: false,
            angleMode: mode,
            precision: 6,
            themeModeLabel: '跟随系统',
            expressionDisplayMode: '数学符号',
          ),
        );

        controller.setExpression('sin(30°)');
        await controller.submit();

        expect(engine.calls, isEmpty,
            reason: '$mode：`degangle` 没有引擎写法，翻译器先拒了它，引擎不该被问');
        expect(controller.result, '0.5', reason: '$mode：`sin(30°)` 是 0.5');
        expect(controller.hasError, isFalse, reason: '$mode：这是一个答得出来的输入');

        controller.dispose();
      }
    });
  });
}

EngineReply _reply(String decimal, {String tex = '', String kind = 'number'}) =>
    EngineReply.success(MathResult(
      displayText: decimal,
      displayTex: tex,
      decimalText: decimalTextIsFinite(decimal) ? decimal : '',
      resultKind: switch (kind) {
        'structured' => EngineResultKind.structured,
        'unit' => EngineResultKind.unit,
        'conversion' => EngineResultKind.conversion,
        _ => EngineResultKind.number,
      },
    ));

/// 中文：**按被问到的文本回话的替身，两种写法都答。** 每一行都是**实测的引擎原文**
///       （宿主 libqalculate 5.12.0，按桥的调用序列：`unlocalizeExpression` → `calculate` →
///       `print`，精度 16、`INTERVAL_DISPLAY_MIDPOINT`、`comma_as_separator=false`）：
///
///       - **修好的写法**（归一化之后翻译出来的那一个）给引擎真正会答的那一份；
///       - **修复轮 7 的写法**（喂原文时翻译出来的那一个）也答，给的同样是实测值
///         （1.021012125707193 / 0.0009 / 3 / 1 / 二元素向量…）。
///
///       于是「拿掉归一化」这件事**落在值上**：屏幕上会出现 `broken` 那一列，而不只是「问的字符串变了」。
/// English: **a double that answers by the text it is asked, in both spellings.** Every row is **measured
///          engine text** (host libqalculate 5.12.0, through the bridge's call sequence:
///          `unlocalizeExpression` → `calculate` → `print`, precision 16, `INTERVAL_DISPLAY_MIDPOINT`,
///          `comma_as_separator=false`):
///
///          - the **repaired spelling** (what the normalised translation produces) gets what the engine
///            really answers;
///          - **fix round 7's spelling** (what translating the raw source produced) is answered too, with
///            its own measured value (1.021012125707193 / 0.0009 / 3 / 1 / a two-element vector …).
///
///          So "remove the normalisation" **shows up in the value**: the `broken` column reaches the
///          screen, not merely a different asked string.
class _MeasuredEngine implements MathEngine {
  final List<({String expression, String angleMode})> calls = [];

  /// 中文：被问到的文本 → （引擎印出来的东西, 形状）。形状只对**非有限十进制**的那些重要
  ///       （向量/矩阵走 tier 3，需要 `structured`）。
  /// English: asked text → (what the engine prints, kind). The kind only matters for the
  ///          **non-finite-decimal** ones (vectors/matrices go through tier 3 and need `structured`).
  static const Map<String, (String, String)> _answers =
      <String, (String, String)>{
    // 修好的写法（归一化之后）。
    '((((2)^((3))))/(100))': ('0.08', 'number'),
    '(((3))/(((100)^(2))))': ('0.0003', 'number'),
    '((((9)^((50))))/(100))': ('5.153775207320113E45', 'number'),
    'round(1024)': ('1024', 'number'),
    'log2(1024)': ('10', 'number'),
    'sqrt(1024)': ('32', 'number'),
    'abs(1024)': ('1024', 'number'),
    'ln(1024)': ('6.931471805599453', 'number'),
    'ceil(1024)': ('1024', 'number'),
    'floor(1024)': ('1024', 'number'),
    'cbrt(1024)': ('10.07936839915899', 'number'),
    // 修复轮 7 的写法（喂原文）——红证落在这些值上。
    '((2)^(((3)/100)))': ('1.021012125707193', 'number'),
    '((((3)/100))^(2))': ('0.0009', 'number'),
    '((9)^(((50)/100)))': ('3', 'number'),
    'round(1,024)': ('1', 'number'),
    'log2(1,024)': ('[0.000000000000000  4.584962500721156]', 'structured'),
    'sqrt(1,024)': ('[1  4.898979485566356]', 'structured'),
    'abs(1,024)': ('[1  24]', 'structured'),
    'ln(1,024)': ('[0.000000000000000  3.178053830347946]', 'structured'),
    'ceil(1,024)': ('[1  24]', 'structured'),
    'floor(1,024)': ('[1  24]', 'structured'),
    'cbrt(1,024)': ('[1  2.884499140614817]', 'structured'),
    // `canRead` 那两条：引擎对**翻译后**的拼法的真实答复（这一份才是它会被问到的）。
    'log10(8,2)': ('[0.9030899869919436  0.3010299956639812]', 'structured'),
    'factorial(171)': ('1.241018070217668E309', 'number'),
    // `φ(2)`：翻译把常量写成它的数值，引擎对这个式子的答复就是应用自己的值。
    '((1.618033988749895)*((2)))': ('3.23606797749979', 'number'),
  };

  @override
  Future<EngineReply> evaluate(
    String expression, {
    required String angleMode,
  }) async {
    calls.add((expression: expression, angleMode: angleMode));
    final answer = _answers[expression];
    if (answer == null) {
      return EngineReply.failure('test: unexpected expression <$expression>');
    }
    return _reply(answer.$1, kind: answer.$2);
  }
}

/// 中文：立刻回话的替身，并记下每一次被问到的表达式——「问引擎的是翻译后的那一份」正是靠它钉住的。
/// English: a double that answers at once and records every expression it was asked about — that record
///          is what pins "the engine is asked the translated expression".
class _FakeMathEngine implements MathEngine {
  _FakeMathEngine(this.reply);

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

CalculatorController _controller(
  _FakeDatabase db, {
  required MathEngine engine,
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
    engine: engine,
    liveEngineFollowUpDelay: const Duration(minutes: 10),
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
