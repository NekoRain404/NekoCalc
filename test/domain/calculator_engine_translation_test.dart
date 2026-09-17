import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/application/controllers/calculator_controller.dart';
import 'package:nekocalc/core/math/math_engine.dart';
import 'package:nekocalc/core/math/math_result.dart';
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

  group('采用：引擎答什么就是什么（没有第二道值比较）', () {
    test('应用解析不了 ⇒ 引擎是唯一来源：矩阵照样上屏', () async {
      final controller = _controller(
        _FakeDatabase(),
        engine: _FakeMathEngine(_reply('[1  2; 3  4]',
            tex: r'\\begin{bmatrix}1 & 2 \\\\ 3 & 4\\end{bmatrix}')),
      );

      controller.setExpression('matrix(2,2,1,2,3,4)');
      await controller.submit();

      expect(controller.hasError, isFalse);
      expect(controller.result, '[1  2; 3  4]');
      expect(controller.resultTex, contains('bmatrix'));

      controller.dispose();
    });

    test('应用解析不了 ⇒ 复数照样上屏', () async {
      final controller = _controller(
        _FakeDatabase(),
        engine: _FakeMathEngine(_reply('1 + 2i')),
      );

      controller.setExpression('2i+1');
      await controller.submit();

      expect(controller.hasError, isFalse);
      expect(controller.result, '1 + 2i');

      controller.dispose();
    });

    test('引擎的值超出 double 量程 ⇒ 原样采用（应用给不出这个值）', () async {
      // 中文：`2^2000` 的引擎文本是**有限十进制**，只是 double 装不下——判据必须把它留住
      //       （否则引擎最不可替代的那类结果会被丢掉）。翻译之后的表达式是 `((2)^(2000))`。
      // English: the engine's text for `2^2000` is a **finite decimal**, just beyond a double — the
      //          criterion has to keep it (otherwise the results the engine is least replaceable for
      //          would be thrown away). The translated expression is `((2)^(2000))`.
      final controller = _controller(
        _FakeDatabase(),
        engine: _FakeMathEngine(_reply('1.148130695274255E602')),
      );

      controller.setExpression('2^2000');
      await controller.submit();

      // 中文：替身直接构造 [MathResult]，绕过了适配层的科学计数法改写（真机上 `E602` 会被写成
      //       应用的 `e+602`），所以这里断言的是替身给的那串原文。
      // English: the double builds the [MathResult] directly, bypassing the adapter's scientific-notation
      //          rewrite (on a device `E602` is spelled the app's `e+602`), so this asserts the string the
      //          double supplied.
      expect(controller.result, '1.148130695274255E602');
      expect(controller.resultDecimal, '1.148130695274255E602');

      controller.dispose();
    });

    test('应用给得出的是**下溢的 0**（`2^-2000`）⇒ 引擎赢，不能显示 0', () async {
      // 中文：**这条是「应用解析得了就以应用为准」最容易被误解的地方。** 应用自己的解析器对
      //       `2^-2000` 给的是 **`0.0`**——一个**有限** double，看上去"应用答得出来"；而引擎给
      //       `8.709809816217217E-603`（文本有限、double 装不下）。值比较在的时候这一条要靠一个
      //       专门的分支才活下来；现在没有值比较了，引擎这一份直接采用。
      // English: **the place "the app can answer, so use the app" is easiest to get wrong.** This
      //          app's own parser returns **`0.0`** for `2^-2000` — a *finite* double, so at first
      //          sight "the app has an answer" — while the engine gives `8.709809816217217E-603`
      //          (finite as text, unrepresentable as a double). Under the value comparison this case
      //          needed a dedicated carve-out to survive; with no value comparison the engine's copy is
      //          taken directly.
      final controller = _controller(
        _FakeDatabase(),
        engine: _FakeMathEngine(_reply('8.709809816217217E-603')),
      );

      // 中文：先确认前提——应用自己的解析器对这条表达式给的就是 0.0（下溢），用一个**没有引擎**
      //       的控制器量它：那是应用自己的答案。
      // English: first confirm the premise — the app's own parser answers 0.0 for this expression
      //          (underflow); measured with an engine-less controller, which is the app's own answer.
      final appOnly =
          _controller(_FakeDatabase(), engine: _FailingMathEngine());
      appOnly.setExpression('2^-2000');
      await appOnly.submit();
      expect(appOnly.result, '0', reason: '应用自己的解析器在这里给的就是 0（下溢）');
      appOnly.dispose();

      controller.setExpression('2^-2000');
      await controller.submit();

      expect(controller.result, '8.709809816217217E-603');
      expect(controller.result, isNot('0'));

      controller.dispose();
    });

    test('精确形态照旧保留（那是引擎存在的理由之一）', () async {
      // 中文：`sqrt(8)` 的引擎原文是 `2.828427124746190` + 精确形态 `2√2`。应用自己的 double 是
      //       `2.8284271247461903`（相对差 1e-16）——值比较在的时候这一条要靠容差才活下来，
      //       现在引擎那一份直接采用。
      // English: the engine's answer for `sqrt(8)` is `2.828427124746190` plus the exact form `2√2`.
      //          This app's own double is `2.8284271247461903` (about 1e-16 relative) — under the value
      //          comparison this case needed the tolerance to survive; now the engine's copy is taken
      //          directly.
      final controller = _controller(
        _FakeDatabase(),
        engine: _FakeMathEngine(
            _reply('2.828427124746190', tex: r'2\\times \\sqrt{2}')),
      );

      controller.setExpression('sqrt(8)');
      await controller.submit();

      expect(controller.hasError, isFalse);
      expect(controller.result, '2.828427');
      expect(controller.resultTex, isNotEmpty);
      expect(controller.resultDecimal, '2.828427124746190');

      controller.dispose();
    });

    test('DEG 下 sin(30)：引擎的精确 0.5 上屏（应用自己给的是 0.49999999999999994）', () async {
      // 中文：角度模式两边一致（桥把 `angleMode` 同时交给 `ParseOptions.setAngle_unit` 与应用自己的
      //       解析器），但 DEG 下应用先做 `arg * pi / 180` 这一步 **double** 运算、引擎按精确值算。
      //       值比较在的时候这要靠 1e-9 的容差才活下来；现在直接用引擎那一份。
      // English: the angle mode is consistent on both sides (the bridge gives `angleMode` to
      //          `ParseOptions.setAngle_unit` and to this app's own parser), but in DEG the app does
      //          the `arg * pi / 180` step in **double** while the engine computes it exactly. Under
      //          the value comparison this needed the 1e-9 tolerance; now the engine's copy is used.
      final controller = _controller(
        _FakeDatabase(),
        engine: _FakeMathEngine(_reply('0.5')),
        settings: _degSettings,
      );

      controller.setExpression('sin(30)');
      await controller.submit();

      expect(controller.hasError, isFalse);
      expect(controller.result, '0.5');
      expect(controller.resultDecimal, '0.5');

      controller.dispose();
    });

    test('可显示但不可当数字用：引擎的矩阵上屏，`Ans`/记忆拿不到它', () async {
      // 中文：**这条以前断言的是反过来的事**——「引擎读成矩阵而应用解析得了 ⇒ 丢弃」。那条规则
      //       （应用解析得了就以应用为准）在修复轮 7 被删掉了：交给引擎的已经是翻译后的表达式，
      //       所以它的答案不再需要被应用复核。钉住的两件事：矩阵上屏；十进制形态是空的，
      //       数值消费者因此拒绝它（不是静默当成 0）。
      // English: **this used to assert the opposite** — "the engine came back with a matrix while the
      //          app can parse the source ⇒ discard". That rule (the app's value wins) was deleted in
      //          fix round 7: what reaches the engine is already the translated expression, so its
      //          answer no longer needs re-checking against the app. Two things are pinned: the matrix
      //          goes on screen; the decimal form is empty, so numeric consumers refuse it instead of
      //          silently reading a 0.
      final controller = _controller(
        _FakeDatabase(),
        engine: _FakeMathEngine(_reply('[9  9; 9  9]', kind: 'structured')),
      );

      controller.setExpression('sqrt(8)');
      await controller.submit();

      expect(controller.result, '[9  9; 9  9]');
      expect(controller.resultDecimal, isEmpty);

      controller.dispose();
    });
  });

  group('翻译器的输入是归一化之后的形态（修复轮 8 的两条 medium）', () {
    // 中文：这一组的替身**按被问到的文本回话**，而且**两种写法都答**：修好的写法给实测的引擎原文，
    //       修复轮 7 的写法给它的另一份原文。于是红证落在**屏幕上的值**上——把归一化拿掉，屏幕
    //       立刻变成右列那些数（1.021012 / 0.0009 / 3 / 1 / 二元素向量），而不是只落在「问了什么」上。
    // English: this group's double **answers by the text it is asked**, and it answers **both** spellings:
    //          the repaired one with the engine text measured for it, fix round 7's spelling with the
    //          other text measured for that. So the red proof lands on the **value on screen** — remove
    //          the normalisation and the screen becomes those numbers (1.021012 / 0.0009 / 3 / 1 / a
    //          two-element vector), not merely on "what was asked".
    const rows = <({String expression, String asked, String broken})>[
      // 1a —— `%` 的 `/100` 在**整个外层项**的末尾。`broken` 是修复轮 7 的写法下屏幕上的值（实测）。
      (
        expression: '2^3%',
        asked: '((((2)^((3))))/(100))',
        broken: '1.021012',
      ),
      (expression: '3%^2', asked: '(((3))/(((100)^(2))))', broken: '0.0009'),
      (
        expression: '9^50%',
        asked: '((((9)^((50))))/(100))',
        broken: '3',
      ),
      // 1b —— 分组逗号：单参调用不该变成双参调用。
      (expression: 'round(1,024)', asked: 'round(1024)', broken: '1'),
      (
        expression: 'log2(1,024)',
        asked: 'log2(1024)',
        broken: '[0.000000000000000  4.584962500721156]',
      ),
      (
        expression: 'sqrt(1,024)',
        asked: 'sqrt(1024)',
        broken: '[1  4.898979485566356]',
      ),
      (expression: 'abs(1,024)', asked: 'abs(1024)', broken: '[1  24]'),
      (
        expression: 'ln(1,024)',
        asked: 'ln(1024)',
        broken: '[0.000000000000000  3.178053830347946]',
      ),
      (expression: 'ceil(1,024)', asked: 'ceil(1024)', broken: '[1  24]'),
      (expression: 'floor(1,024)', asked: 'floor(1024)', broken: '[1  24]'),
      (
        expression: 'cbrt(1,024)',
        asked: 'cbrt(1024)',
        broken: '[1  2.884499140614817]',
      ),
    ];

    for (final row in rows) {
      test('${row.expression}：问引擎的是 ${row.asked}，屏幕上是应用自己的值', () async {
        final engine = _MeasuredEngine();
        final controller = _controller(_FakeDatabase(), engine: engine);

        // 中文：应用自己的答案——同一个控制器、没有引擎的那一份。两个值相同才算这一条成立。
        // English: this app's own answer — the same controller with no engine. The row holds only when
        //          the two agree.
        final appOnly =
            _controller(_FakeDatabase(), engine: _FailingMathEngine());
        appOnly.setExpression(row.expression);
        await appOnly.submit();
        final expected = appOnly.result;
        expect(appOnly.hasError, isFalse,
            reason: '${row.expression}：应用自己应当答得出来');
        appOnly.dispose();

        controller.setExpression(row.expression);
        await controller.submit();

        // 中文：**值先断言，机制后断言。** 顺序有意：值那一句才是用户看得见的东西，而它单独就能
        //       把「喂原文」这件事照出来——那时替身按修复轮 7 的写法回话，屏幕上是 `broken` 那一列。
        // English: **the value is asserted first, the mechanism after.** The order is deliberate: the
        //          value is what the user sees, and on its own it shows "fed the raw source" — the double
        //          then answers fix round 7's spelling and the `broken` column reaches the screen.
        expect(controller.result, expected,
            reason: '${row.expression}：引擎那一路的值必须与应用自己的一致');
        expect(controller.result, isNot(row.broken),
            reason: '${row.expression}：这是修复轮 7 的误读值（实测）');
        expect(engine.calls.single.expression, row.asked,
            reason: '问引擎的必须是归一化之后翻译出来的那一个字符串');

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

    test('1.5° to arcmin：名字层判假，但翻译器先拒了 `rad`——引擎一次都没被问', () async {
      // 中文：这条钉的是**修复轮 9 那条期望值改动为什么不改变屏幕**。`1.5° to arcmin` 归一化之后是
      //       `rad(1.5) to arcmin`，里面有一个 `rad` 调用，于是 `canRead` 判假（修复轮 9 之前它读原文、
      //       判真）。**两种判词下屏幕都一样**：`_askEngineTranslated` 先问翻译器，翻译器对 `rad` 给
      //       「词表里这个名字没有引擎写法」，引擎**根本没被问**（`calls` 为空），走旧解析器，
      //       而旧解析器读不了 `to` ——应用自己的错误。所以这一条在「把 `canRead` 的输入改回原文」
      //       的变异体里仍然是绿的，只有 `calculator_engine_display_gate_test.dart` 里那条
      //       `canRead('1.5° to arcmin')` 的期望值断言会红。
      // English: this pins **why fix round 9's expectation change does not change the screen**.
      //          `1.5° to arcmin` normalises to `rad(1.5) to arcmin`, which contains a `rad` call, so
      //          `canRead` says false (before fix round 9 it read the raw source and said true).
      //          **The screen is the same either way**: `_askEngineTranslated` consults the translator
      //          first, the translator has no engine spelling for `rad`, the engine is **never asked**
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
  });

  group('三个活错值：值判据在的时候它们上屏，现在不了', () {
    test('DEG 大角度：引擎的精确值上屏，应用自己 `arg*pi/180` 的舍入不再顶掉它', () async {
      // 中文：`tan(1e12)` 在 DEG 下——引擎（与数学）给 `-5.671281819617710`，而应用自己先做
      //       `1e12 * pi / 180` 这一步 double 运算，舍入在 ~1e9° 以上就超过了 1e-9 的相对容差：
      //       它给 `-5.671323078223783`。值判据因此把**引擎的正确答案判成误读并丢弃**，屏幕上
      //       留下应用的错值 `-5.671323`（这是修复轮 6 相对 `a312ec8` 引入的倒退）。
      // English: `tan(1e12)` in DEG — the engine (and the mathematics) gives `-5.671281819617710`,
      //          while the app does the `1e12 * pi / 180` step in double first and its rounding exceeds
      //          the 1e-9 relative tolerance above roughly 1e9°: it gives `-5.671323078223783`. The
      //          value comparison therefore called the **engine's correct answer a misreading and threw
      //          it away**, leaving the app's wrong `-5.671323` on screen (a regression round 6
      //          introduced relative to `a312ec8`).
      final engine = _FakeMathEngine(_reply('-5.671281819617710'));
      final controller = _controller(
        _FakeDatabase(),
        engine: engine,
        settings: _degSettings,
      );

      controller.setExpression('tan(1e12)');
      await controller.submit();

      expect(engine.calls.single.expression, 'tan(1e12)');
      expect(controller.result, '-5.671282');
      expect(controller.resultDecimal, '-5.671281819617710');
      expect(controller.result, isNot('-5.671323'));

      controller.dispose();
    });

    test('灾难性相消：引擎给 1，应用下溢成 0', () async {
      // 中文：四条都是**双精度装不下、而引擎算得准**的差：应用自己的解析器把它们全算成 `0`
      //       （`123456789012345678` 与 `123456789012345677` 折成同一个 double），引擎（与数学）
      //       给 `1`。值判据看到「应用 0、引擎 1」，判定引擎读错了，于是屏幕上显示 `0`。
      //       翻译把每一条的树形写成括号形式，引擎读到的就是应用那条式子。
      // English: all four are differences a double cannot hold while the engine computes them exactly:
      //          this app's own parser answers `0` for every one of them (`123456789012345678` and
      //          `123456789012345677` round to the same double) while the engine — and the mathematics
      //          — say `1`. The value comparison saw "app 0, engine 1", called the engine a misreading,
      //          and put `0` on screen. The translation spells each tree out in brackets, so the engine
      //          reads exactly the expression the app means.
      const rows = <({String expression, String translated})>[
        (
          expression: '123456789012345678-123456789012345677',
          translated: '((123456789012345678)-(123456789012345677))',
        ),
        (
          expression: '999999999999999999-999999999999999998',
          translated: '((999999999999999999)-(999999999999999998))',
        ),
        (
          expression: '2^53+1-2^53',
          translated: '((((((2)^(53)))+(1)))-(((2)^(53))))',
        ),
        (
          expression: '(10^16+1)-10^16',
          translated: '(((((((10)^(16)))+(1))))-(((10)^(16))))',
        ),
      ];

      for (final row in rows) {
        final engine = _FakeMathEngine(_reply('1'));
        final controller = _controller(_FakeDatabase(), engine: engine);

        controller.setExpression(row.expression);
        await controller.submit();

        expect(engine.calls.single.expression, row.translated,
            reason: '问引擎的必须是翻译后的表达式');
        expect(controller.result, '1', reason: row.expression);
        expect(controller.resultDecimal, '1', reason: row.expression);

        controller.dispose();
      }
    });

    test('小量级：应用的读法是 `(1/3000000000)*pi`，翻译把它写成显式乘法', () async {
      // 中文：应用自己的解析把 `1/3000000000pi` 读成 `(1/3000000000) * pi` = `1.0471975511965977e-9`
      //       （π/3e9），而引擎读**原串**是 `1 / (3000000000 * pi)` = `1.061032954375277e-10`。
      //       值判据的容差带一个 1 的**绝对下限**，两个值只差 9.4e-10 ⇒ 判成「一致」⇒ 引擎那一份
      //       上屏，屏幕上是 `1.061033e-10`——一个应用自己从没给过的数。
      //       翻译之后问引擎的是 `((((1)/(3000000000)))*(pi))`（实测原文 `1.047197551196598E-9`），
      //       于是引擎的答案与应用的意思一致。
      // English: this app's own parser reads `1/3000000000pi` as `(1/3000000000) * pi` =
      //          `1.0471975511965977e-9` (π/3e9) while the engine reads the **raw string** as
      //          `1 / (3000000000 * pi)` = `1.061032953945969e-10`. The value comparison's tolerance
      //          carried an **absolute floor of 1**, so the two were only 9.4e-10 apart ⇒ "they agree"
      //          ⇒ the engine's copy went on screen as `1.061033e-10`, a number this app never
      //          produced. After the translation the engine is asked `((((1)/(3000000000)))*(pi))`
      //          (measured text `1.047197551196598E-9`), so its answer means what the app means.
      //
      // 中文：替身在这里**按被问到的文本回话**——两种写法各自给引擎实测的那一份原文，于是红证
      //       落在值上（不翻译时屏幕上会是 `1.061033e-10`），而不只是落在「问的是什么」上。
      // English: the double here **answers by the text it was asked** — each spelling gets the engine
      //          string measured for it — so the red proof lands on the *value* (without the
      //          translation the screen reads `1.061033e-10`), not only on "what was asked".
      final engine = _SpellingSensitiveEngine();
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('1/3000000000pi');
      await controller.submit();

      // 中文：先钉用户看得见的那个值，再钉机制（问引擎的写法）——两者都对才算这一条修好了。
      // English: pin the value the user sees first, then the mechanism (the spelling asked) — this is
      //          fixed only when both hold.
      expect(controller.result, '1.047198e-9');
      expect(controller.result, isNot('1.061033e-10'));
      expect(engine.calls.single.expression, '((((1)/(3000000000)))*(pi))');

      controller.dispose();
    });
  });
}

EngineReply _reply(String decimal, {String tex = '', String kind = 'number'}) =>
    EngineReply.success(MathResult(
      displayText: decimal,
      displayTex: tex,
      decimalText: MathResult.decimalTextIsFinite(decimal) ? decimal : '',
      resultKind: switch (kind) {
        'structured' => EngineResultKind.structured,
        'unit' => EngineResultKind.unit,
        'conversion' => EngineResultKind.conversion,
        _ => EngineResultKind.number,
      },
    ));

const AppSettings _degSettings = AppSettings(
  haptics: true,
  hapticStrength: '标准',
  restoreState: false,
  autoSaveHistory: false,
  angleMode: 'DEG',
  precision: 6,
  themeModeLabel: '跟随系统',
  expressionDisplayMode: '数学符号',
);

/// 中文：**按被问到的文本回话**的替身：`1/3000000000pi` 这一条的两种写法各自给引擎实测的原文
///       （见那条测试），其余文本一律回「没有答案」。写法的差别因此可以被观测到值上。
/// English: a double that **answers by the text it was asked**: for `1/3000000000pi` each of the two
///          spellings gets the engine string measured for it (see that test) and anything else gets
///          "no answer", so a difference in spelling shows up in the value itself.
class _SpellingSensitiveEngine implements MathEngine {
  final List<({String expression, String angleMode})> calls = [];

  @override
  Future<EngineReply> evaluate(
    String expression, {
    required String angleMode,
  }) async {
    calls.add((expression: expression, angleMode: angleMode));
    return switch (expression) {
      // 应用的意思（翻译后的写法）：(1/3000000000)*pi，实测 1.047197551196598E-9。
      '((((1)/(3000000000)))*(pi))' => _reply('1.047197551196598E-9'),
      // 原串的读法：1/(3000000000*pi)，实测 1.061032953945969E-10。
      '1/3000000000pi' => _reply('1.061032953945969E-10'),
      _ => EngineReply.failure('test: unexpected expression <$expression>'),
    };
  }
}

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

/// 中文：引擎缺席的替身——用来量「应用自己的答案」。
/// English: an engine-less double — used to measure "this app's own answer".
class _FailingMathEngine implements MathEngine {
  @override
  Future<EngineReply> evaluate(
    String expression, {
    required String angleMode,
  }) async =>
      EngineReply.failure('test: no engine');
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
