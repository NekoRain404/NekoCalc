import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/application/controllers/calculator_controller.dart';
import 'package:nekocalc/core/math/app_engine_vocabulary.dart';
import 'package:nekocalc/core/math/math_engine.dart';
import 'package:nekocalc/core/math/math_result.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/repositories/history_repository.dart';
import 'package:nekocalc/data/repositories/notes_repository.dart';
import 'package:nekocalc/data/repositories/settings_repository.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/math_expression_view.dart';

/// 中文：**符号结果上屏的那一步。**
///
///       以前，一个含变量的结果是一种「应用自己的语言表达不了、而显示判据一律拒绝」的值，于是
///       `2x` 是一条错误。这一步放行其中的一部分，而放行的判据**不是「结果看起来像符号」**——
///       那正是上一轮栽过的坑（那一轮把引擎**误读**应用词表得到的答案也放了进去）。这里问的是
///       两个**结构性**的问题，一个由引擎回答、一个由应用自己回答：
///
///       1. **引擎这一次算没算**（原生侧 `KIND_SYMBOLIC`）：结果里有变量符号，而且引擎这一次
///          **一句话都没说**（消息队列是空的）。引擎做不了一个运算时**不抛异常**，它把那个运算
///          原样退回来再排一句话——实测 `1/0`、`x/0`、`0/0`、`2/0`、`0^(-1)`、`1/(x-x)` 全部排
///          `Division by zero.`，而 `2x`、`x^2+1`、`x+y`、`sqrt(x)`、`2/x`、`x^2*y^2` 一条都没有。
///          这条判据在 **Kotlin 里**，`flutter test` 跑不到它：这个文件钉住的是它**发过来的那个
///          种类**（`EngineResultKind.symbolic`）在 Dart 侧的处理，原生那一半的证据是宿主上的
///          量测与 `flutter build apk --debug`，见 `.superpowers/backup/symbolic-results-report.md`。
///       2. **应用自己的语言答不答得了这个输入**（[AppEngineVocabulary.canExpress]）：答得了时，
///          旧解析器依旧是权威——引擎把它自己的函数名印到屏幕上（`pi!` → `factorial(pi)`）就
///          必须被拦住，因为那句文本不是这个应用对这一行的答案。
///
///       这个文件里的每一个回执都按**实测**配（宿主 libqalculate 5.12.0，按桥的调用序列：
///       `unlocalizeExpression` → `calculate` → `print`，精度 16、`INTERVAL_DISPLAY_MIDPOINT`、
///       `mixed_units_conversion=NONE`、`comma_as_separator=false`、角度单位弧度）。
/// English: **The step that puts symbolic results on screen.**
///
///          A result containing a variable used to be a value "this app's own language cannot express"
///          that the display judgement refused outright, so `2x` was an error. This step admits part
///          of that set, and the criterion is **not "does the result look symbolic"** — that is exactly
///          the hole the last round fell into (it also admitted the answers the engine produced by
///          **mis-reading** this app's vocabulary). What is asked here are two **structural**
///          questions, one answered by the engine and one by this app itself:
///
///          1. **did the engine compute this time** (natively, `KIND_SYMBOLIC`): the result holds a
///             variable symbol and the engine said **not one word** (its message queue is empty).
///             When the engine cannot perform an operation it does **not** throw — it hands the
///             operation back and queues a line: measured, `1/0`, `x/0`, `0/0`, `2/0`, `0^(-1)`,
///             `1/(x-x)` all queue `Division by zero.`, while `2x`, `x^2+1`, `x+y`, `sqrt(x)`, `2/x`
///             and `x^2*y^2` queue nothing. That half lives in **Kotlin** and `flutter test` cannot
///             reach it: this file pins how the Dart side handles the kind it sends
///             (`EngineResultKind.symbolic`); the native half's evidence is the host measurement and
///             `flutter build apk --debug`, both recorded in
///             `.superpowers/backup/symbolic-results-report.md`.
///          2. **can this app's own language answer this input**
///             ([AppEngineVocabulary.canExpress]): when it can, the legacy parser is still the
///             authority — the engine printing its own function name on screen (`pi!` →
///             `factorial(pi)`) has to be stopped, because that text is not this app's answer for that
///             line.
///
///          Every receipt in this file is fitted to a **measurement** (host libqalculate 5.12.0, over
///          the bridge's call sequence: `unlocalizeExpression` → `calculate` → `print`, precision 16,
///          `INTERVAL_DISPLAY_MIDPOINT`, `mixed_units_conversion=NONE`, `comma_as_separator=false`,
///          angle unit radians).
void main() {
  group('符号结果：引擎算出来的那一个上屏', () {
    test('提交 `2x`：结果行上是 `2x`，排版形态也排得出来', () async {
      // 中文：实测（宿主 5.12.0）：`((2)*(x))` → decimal `2x`、latex `2x`、消息队列空、
      //       结构里有变量——原生侧的种类因此是 `symbolic`。放行之前屏幕上是一条错误
      //       （旧解析器对 `2x` 报「Unexpected token at 1」）。
      // English: measured (host 5.12.0): `((2)*(x))` → decimal `2x`, latex `2x`, empty message
      //          queue, a variable in the structure — so the native kind is `symbolic`. Before the
      //          relaxation the screen held an error (the legacy parser reports "Unexpected token at
      //          1" for `2x`).
      final engine = _FakeMathEngine(
        const _Receipt(displayText: '2x', displayTex: '2x').reply,
      );
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('2x');
      final submitted = await controller.submit();

      expect(submitted.submitted, isTrue);
      expect(controller.hasError, isFalse);
      expect(controller.result, '2x');
      expect(controller.resultTex, '2x');
      expect(MathExpressionView.typesetsTex(controller.resultTex), isTrue,
          reason: '新放行的渲染路径必须排得出来，不能退化成纯文本');

      controller.dispose();
    });

    test('提交 `x^2+1`：排版形态是 `x^{2} + 1`，排得出来', () async {
      final engine = _FakeMathEngine(
        const _Receipt(displayText: 'x^2 + 1', displayTex: r'x^{2} + 1').reply,
      );
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('x^2+1');
      await controller.submit();

      expect(controller.hasError, isFalse);
      expect(controller.result, 'x^2 + 1');
      expect(MathExpressionView.typesetsTex(controller.resultTex), isTrue);

      controller.dispose();
    });

    test('符号结果没有十进制形态：`resultDecimal` 是空的', () async {
      // 中文：`2x` 不是有限数，所以适配层的规矩（`_replyFrom`）让它留空——数值消费者据此不再
      //       解析，而不是解析失败后取 0。
      // English: `2x` is not a finite number, so the adapter's rule (`_replyFrom`) leaves it empty —
      //          numeric consumers stop there rather than taking 0 after a failed parse.
      final engine = _FakeMathEngine(
        const _Receipt(displayText: '2x', displayTex: '2x').reply,
      );
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('2x');
      await controller.submit();

      expect(controller.resultDecimal, isEmpty);

      controller.dispose();
    });
  });

  group('应用自己的语言答得了时，旧解析器依旧是权威', () {
    test('`pi!`：引擎报 symbolic，而屏幕上是旧解析器那句阶乘错误', () async {
      // 中文：**实测的错值，这一轮拦住的就是它。** 宿主 5.12.0：`factorial(pi)` 的消息队列是空的、
      //       结构里有变量（`pi` 在引擎里是一个变量），所以原生侧的种类是 `symbolic`；精确印法是
      //       `\operatorname{factorial}(\pi )`，而十进制那一份（走近似求值）是
      //       `factorial(3.141592653589793)`。两种都会**排得出来**——也就是说漏过去的话，屏幕上
      //       是一个看起来完全正常的公式，而应用自己的答案是「阶乘只支持 0 到 170 的整数」。
      //
      //       应用自己的语言答得了这个输入（`pi` 是它的常量、`!` 是它的后缀），于是
      //       [AppEngineVocabulary.canExpress] 为真，这一份不算——屏幕上因此还是那句错误。
      //       替身故意把**两种形态都配成引擎的原文**：判据一旦松口，这里的第一条断言就会红。
      // English: **the measured wrong value this round stops.** Host 5.12.0: `factorial(pi)` leaves
      //          the message queue empty and its structure holds a variable (`pi` is one of the
      //          engine's variables), so the native kind is `symbolic`; the exact print is
      //          `\operatorname{factorial}(\pi )` and the decimal half (which goes through the
      //          approximating evaluation) is `factorial(3.141592653589793)`. **Both typeset** — so
      //          had it slipped through, the screen would hold a formula that looks entirely
      //          legitimate, while this app's own answer is "阶乘只支持 0 到 170 的整数".
      //
      //          This app's own language *can* answer the input (`pi` is one of its constants and `!`
      //          one of its postfixes), so [AppEngineVocabulary.canExpress] is true and this receipt
      //          does not count: the screen keeps that error. The double deliberately carries the
      //          engine's own text in both forms, so the first assertion below goes red the moment the
      //          judgement loosens.
      final engine = _FakeMathEngine(
        const _Receipt(
          displayText: 'factorial(3.141592653589793)',
          displayTex: r'\operatorname{factorial}(\pi )',
        ).reply,
      );
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('pi!');
      final submitted = await controller.submit();

      expect(engine.calls, isNotEmpty,
          reason: '`pi!` 过得了词汇与翻译，引擎真的会被问到——这是这条判据的前提');
      expect(controller.result, isNot(contains('factorial')));
      expect(controller.hasError, isTrue);
      expect(controller.errorMessage, '阶乘只支持 0 到 170 的整数');
      expect(submitted.submitted, isFalse);

      controller.dispose();
    });

    test('判据本身：应用自己的语言答得了的表达式为真，含未绑定名字的为假', () {
      // 中文：判据是**节点类型**，不是名字表也不是正则——`ExpressionAstParser` 只产出三种东西：
      //       常量、调用、以及「其余一切」（`VariableNode`）。所以这一条钉的是那三种落在哪一边。
      //       `km` 是单位名，应用自己的解析器同样不认它，所以它也在「为假」那一列。
      // English: the test is the **node type**, not a name table and not a regex —
      //          `ExpressionAstParser` produces exactly three things: a constant, a call, and
      //          "everything else" (a `VariableNode`). So this pins which side each falls on. `km`
      //          is a unit name and this app's own parser does not bind those either, so it is on the
      //          false side too.
      for (final source in <String>['2+2', 'pi!', 'sin(1)', 'matrix(2,2,1,2,3,4)']) {
        expect(AppEngineVocabulary.canExpress(source), isTrue,
            reason: '「$source」里没有应用自己的语言没有绑定的名字');
      }
      for (final source in <String>['2x', 'x', 'x^2+1', 'sqrt(x)', 'sin(x)', 'x km', 'i']) {
        expect(AppEngineVocabulary.canExpress(source), isFalse,
            reason: '「$source」里有应用自己的语言没有绑定的名字');
      }
    });
  });

  group('符号结果不进数值消费者', () {
    test('符号结果不挪动 `Ans`/`last`：它仍旧是上一个数字，不是 `2x`', () async {
      // 中文：`_lastFiniteResult` 只在这一份结果**能当数字用**时才更新（`usableAsNumber`），而
      //       符号结果不是。于是：先算一个数字，再算一个符号结果，`ans` 仍然是**那个数字**。
      //
      //       这一条钉的正是那个「猜」：要是哪一层把显示文本当成了 `ans` 的值（比如
      //       `_result.decimalText.isEmpty ? displayText : …`），引擎会被问到 `((2x)+(1))` 之类
      //       的东西——`ans` 就变成了一个符号式子，而它明明白白叫**数值**答案。
      //       （第一次求值之前 `_lastFiniteResult` 的初值是 `'0'`，所以这里必须先算一个数字，
      //       否则「没挪动」与「本来就是 0」分不开。）
      // English: `_lastFiniteResult` is updated only when this result is **usable as a number**
      //          (`usableAsNumber`), and a symbolic result is not. So: evaluate a number first, then a
      //          symbolic result, and `ans` is still **that number**.
      //
      //          What this pins is exactly that guess: if any layer took the display text as the value
      //          of `ans` (say `_result.decimalText.isEmpty ? displayText : …`), the engine would be
      //          asked something like `((2x)+(1))` — and `ans` would have become a symbolic
      //          expression, while it is plainly named a *numeric* answer. (Before the first
      //          evaluation `_lastFiniteResult` starts as `'0'`, so a number has to be evaluated first
      //          or "not moved" and "was 0 all along" cannot be told apart.)
      final engine = _FakeMathEngine(
        const _Receipt(
          displayText: '4',
          displayTex: '4',
          kind: EngineResultKind.number,
        ).reply,
      );
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('2+2');
      await controller.submit();
      expect(controller.result, '4', reason: '前提：先有一个数字结果');

      engine.reply = const _Receipt(displayText: '2x', displayTex: '2x').reply;
      controller.setExpression('2x');
      await controller.submit();
      expect(controller.result, '2x', reason: '前提：符号结果先上了屏');

      engine.calls.clear();
      engine.reply = const _Receipt(
        displayText: '5',
        displayTex: '5',
        kind: EngineResultKind.number,
      ).reply;
      controller.setExpression('ans+1');
      await controller.submit();

      expect(engine.calls, isNotEmpty, reason: '`ans` 有这个值可以换');
      expect(engine.calls.single.expression, '((4)+(1))',
          reason: '`ans` 是上一个**数字**；把它换成 `2x` 就是拿符号结果当数字用');
      expect(controller.result, '5');

      controller.dispose();
    });

    test('符号结果不进记忆寄存器：`M+` 之后寄存器还是 0', () async {
      // 中文：`_currentNumericValue()` 对引擎结果读的是 `decimalValue`，而符号结果那一份是 null
      //       （十进制形态为空）——于是寄存器**原样不动**，而不是加上一个 0。
      // English: `_currentNumericValue()` reads `decimalValue` for an engine result, and a symbolic
      //          result's is null (its decimal form is empty) — so the register is **left alone**
      //          rather than having a 0 added to it.
      final engine = _FakeMathEngine(
        const _Receipt(displayText: '2x', displayTex: '2x').reply,
      );
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('2x');
      await controller.submit();
      expect(controller.result, '2x', reason: '前提：符号结果先上了屏');

      controller.memoryAdd();

      expect(controller.memoryValue, 0);
      expect(controller.hasError, isFalse);

      controller.dispose();
    });

    test('`continue with result` 写回的是显示文本，不是猜出来的数字', () async {
      // 中文：与今天带单位的结果（`5 km to mi` → `3.106855961186670 mi`）走的是同一条既有路：
      //       十进制形态缺失时写回显示文本。写回去的是用户自己打的那串 `2x`，不是一个假数字。
      // English: the same existing route today's unit-carrying results take (`5 km to mi` →
      //          `3.106855961186670 mi`): with no decimal form, the display text is what goes back.
      //          What goes back is the user's own `2x`, not a fabricated number.
      final engine = _FakeMathEngine(
        const _Receipt(displayText: '2x', displayTex: '2x').reply,
      );
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('2x');
      await controller.submit();

      expect(controller.canContinueWithResult, isTrue);
      expect(controller.reusableResult, '2x');

      controller.dispose();
    });
  });

  group('边打边算那条路同样收，并且同样不污染 `Ans`', () {
    test('边打边算：符号结果也会上屏', () async {
      // 中文：**两条求值路径共用 `_selectEngineResult` 一处取舍**，所以符号结果在边打边算上也上屏。
      //       这一条钉的是那处共用的接线真的接上了（而不是只有提交路径）。
      // English: **both evaluation paths share the one selection** (`_selectEngineResult`), so a
      //          symbolic result reaches the screen on the as-you-type path too. This pins that the
      //          shared wiring really is shared (rather than the submit path only).
      final engine = _FakeMathEngine(
        const _Receipt(displayText: '2x', displayTex: '2x').reply,
      );
      final controller = _controller(
        _FakeDatabase(),
        engine: engine,
        liveEvaluationDelay: const Duration(milliseconds: 1),
        liveEngineFollowUpDelay: const Duration(milliseconds: 1),
      );

      controller.setExpression('2x');
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(controller.result, '2x');
      expect(controller.hasError, isFalse);
      expect(MathExpressionView.typesetsTex(controller.resultTex), isTrue);

      controller.dispose();
    });

    test('边打边算落地时 `_lastFiniteResult` 被置空（与提交路径是两条不同的写法）', () async {
      // 中文：边打边算走的是 `_adoptEngineResult`，它**无条件下**写 `_lastFiniteResult`：没有十进制
      //       形态就置 **null**（提交路径则是「不碰」——只在 `usableAsNumber` 为真时更新）。
      //       两条写法都不会把显示文本当成数字，但结果不同：边打边算之后 `ans` 换不出东西，于是
      //       引擎一次都不会被问到。这一条把那处差异钉住，免得以后有人把两条路径「顺手统一」成
      //       退回显示文本。
      // English: as-you-type lands through `_adoptEngineResult`, which writes `_lastFiniteResult`
      //          **unconditionally**: with no decimal form it becomes **null** (the submit path, by
      //          contrast, does not touch it — it updates only when `usableAsNumber` is true). Neither
      //          spelling takes the display text as a number, but they differ in outcome: after an
      //          as-you-type symbolic result `ans` resolves to nothing, so the engine is never asked.
      //          This pins that difference so a later "let's unify the two paths" cannot quietly turn
      //          it into a fallback to the display text.
      final engine = _FakeMathEngine(
        const _Receipt(
          displayText: '4',
          displayTex: '4',
          kind: EngineResultKind.number,
        ).reply,
      );
      final controller = _controller(
        _FakeDatabase(),
        engine: engine,
        liveEvaluationDelay: const Duration(milliseconds: 1),
        liveEngineFollowUpDelay: const Duration(milliseconds: 1),
      );

      controller.setExpression('2+2');
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(controller.result, '4', reason: '前提：先有一个数字结果');

      engine.reply = const _Receipt(displayText: '2x', displayTex: '2x').reply;
      controller.setExpression('2x');
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(controller.result, '2x', reason: '前提：符号结果先上了屏');

      engine.calls.clear();
      controller.setExpression('ans+1');
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(engine.calls, isEmpty,
          reason: '`ans` 在边打边算那条路上被置空了，换不出东西——显示文本绝不能被当成数字');

      controller.dispose();
    });
  });

  group('引擎没算的那些照旧不显示', () {
    test('`x/0`：引擎把那次除法退回来（消息队列里有话），种类是 arithmetic，不显示', () async {
      // 中文：实测（宿主 5.12.0）：`((x)/(0))` → decimal `x / 0`、消息队列里是
      //       `Division by zero.`。原生侧因此判 `arithmetic` 而不是 `symbolic` —— 屏幕上是
      //       旧解析器的「Function x needs (」。**这一条守卫在 Kotlin 里**，所以这里配的是原生侧
      //       在那种情形下**会发出来的那个种类**（`arithmetic`），钉的是 Dart 侧收到它时的行为。
      // English: measured (host 5.12.0): `((x)/(0))` → decimal `x / 0`, with `Division by zero.` in
      //          the message queue. The native side therefore reports `arithmetic` rather than
      //          `symbolic` — the screen holds the legacy parser's "Function x needs (". **That guard
      //          lives in Kotlin**, so what is fitted here is the kind the native side **emits** in
      //          that situation (`arithmetic`), and what is pinned is what the Dart side does with it.
      final engine = _FakeMathEngine(
        const _Receipt(
          displayText: 'x / 0',
          displayTex: r'\frac{x}{0}',
          kind: EngineResultKind.arithmetic,
        ).reply,
      );
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('x/0');
      await controller.submit();

      expect(engine.calls, isNotEmpty);
      expect(controller.result, isNot(contains('x / 0')));
      expect(controller.hasError, isTrue);

      controller.dispose();
    });

    test('`sin(x rad)`：引擎把它当带单位的结果（unit），照旧不显示', () async {
      // 中文：**这是这一步刻意不碰的那一支，量出来的理由是三条**：引擎把 `rad` 当一个**单位**，
      //       所以这个结果的种类是 `unit` 而不是 `symbolic`（实测：`sin(((x)*(rad)))` →
      //       `containsType(STRUCT_UNIT)` 非零、`isPlainQuantity` 为假）；`unit` 那一支里住着
      //       **有测试钉住的** `5 km + 3 s` 与**有文档钉住的** `x km`，要把 `sin(x rad)` 从它们
      //       中间分出来只能再切一刀（「顶层是不是函数调用」），而那一刀背后没有任何实测的错值；
      //       而且它的 LaTeX `\sin(\qty[parse-numbers=false]{x}{\radian})` **排不出来**
      //       （`\qty` / `\radian` 是 flutter_math_fork 不认的两个宏），放行它等于新开一条排不出
      //       版式的渲染路径。三条合起来就是「拿不准时失败」。
      // English: **the branch this step deliberately leaves alone, for three measured reasons**: the
      //          engine treats `rad` as a **unit**, so this result's kind is `unit` rather than
      //          `symbolic` (measured: `sin(((x)*(rad)))` → `containsType(STRUCT_UNIT)` non-zero and
      //          `isPlainQuantity` false); the `unit` branch holds `5 km + 3 s` (**pinned by a test**)
      //          and `x km` (**pinned by the docs**), and separating `sin(x rad)` from them needs one
      //          more cut ("is the top level a call") with no measured wrong value behind it; and its
      //          LaTeX `\sin(\qty[parse-numbers=false]{x}{\radian})` **does not typeset** (`\qty` and
      //          `\radian` are two macros flutter_math_fork does not know), so admitting it would open
      //          a new rendering path that cannot typeset. Together, those three are "when in doubt,
      //          fail closed".
      final engine = _FakeMathEngine(
        const _Receipt(
          displayText: 'sin(x rad)',
          displayTex: r'\sin(\qty[parse-numbers=false]{x}{\radian})',
          kind: EngineResultKind.unit,
        ).reply,
      );
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('sin(x rad)');
      await controller.submit();

      expect(engine.calls, isNotEmpty, reason: '翻译得过去，引擎真的会被问到');
      expect(controller.result, isNot(contains('sin(x rad)')));
      expect(controller.hasError, isTrue);

      controller.dispose();
    });

    test('`0^0`：引擎没算而队列是空的，种类是 arithmetic（结果里没有变量），不显示', () async {
      // 中文：实测（宿主 5.12.0）：`((0)^(0))` → decimal `0^0`、消息队列**空**，而结构里没有变量
      //       ——原生侧的两条判据一条也不成立，种类因此是 `arithmetic`。这一条正是「只看队列空不空」
      //       会漏掉的那一个，也是这里第二条结构性判据（结果里有没有变量）的实测实例。
      // English: measured (host 5.12.0): `((0)^(0))` → decimal `0^0`, message queue **empty**, and
      //          the structure holds no variable — neither native test holds, so the kind is
      //          `arithmetic`. This is exactly the one a queue-emptiness-only rule would miss, and the
      //          measured instance of the second structural test here (does the result hold a
      //          variable).
      final engine = _FakeMathEngine(
        const _Receipt(
          displayText: '0^0',
          displayTex: r'0^{0}',
          kind: EngineResultKind.arithmetic,
        ).reply,
      );
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('0^0');
      await controller.submit();

      expect(controller.result, isNot('0^0'));
      expect(controller.hasError, isFalse, reason: '旧解析器答得出来：`0^0` 是 1');
      expect(controller.result, '1');

      controller.dispose();
    });
  });

  group('那两支种类本身', () {
    test('`symbolic` 可显示，`arithmetic` 不可——两者只差在「引擎算没算」', () {
      MathResult withKind(EngineResultKind kind) =>
          MathResult(displayText: '2x', resultKind: kind);

      expect(withKind(EngineResultKind.symbolic).isDisplayable, isTrue);
      expect(withKind(EngineResultKind.arithmetic).isDisplayable, isFalse);
      // 中文：文本那一层照旧先跑——真正非有限的字面量在两种种类下都不显示。
      // English: the text layer still runs first — a genuinely non-finite literal is undisplayable
      //          under either kind.
      expect(
        const MathResult(
                displayText: '-infinity', resultKind: EngineResultKind.symbolic)
            .isDisplayable,
        isFalse,
      );
    });

    test('符号结果不能当数字用：十进制形态为空，`hasFiniteDecimal` 为假', () {
      const result = MathResult(displayText: '2x', resultKind: EngineResultKind.symbolic);

      expect(result.decimalText, isEmpty);
      expect(result.hasFiniteDecimal, isFalse);
      expect(result.decimalValue, isNull);
    });
  });
}

/// 中文：一条引擎回执的固定装置。与 `calculator_engine_display_gate_test.dart` 里那一份同形——
///       两个文件各自持有一份是有意的：测试替身应当随测试走，共享它会让一次改动同时动到两条
///       不相干的测试。
/// English: a fixture for one engine receipt, the same shape as the one in
///          `calculator_engine_display_gate_test.dart` — each file keeping its own is deliberate: a
///          test double belongs with its test, and sharing it would make one edit touch two unrelated
///          tests.
class _Receipt {
  const _Receipt({
    required this.displayText,
    required this.displayTex,
    this.kind = EngineResultKind.symbolic,
  });

  final String displayText;
  final String displayTex;
  final EngineResultKind kind;

  EngineReply get reply => EngineReply.success(MathResult(
        displayText: displayText,
        displayTex: displayTex,
        // 中文：`QalculateMathEngine._replyFrom` 自己的规矩：十进制形态只在它**是有限数**时才写。
        // English: `QalculateMathEngine._replyFrom`'s own rule: the decimal form is written only when
        //          it **is** a finite number.
        decimalText:
            MathResult.decimalTextIsFinite(displayText) ? displayText : '',
        resultKind: kind,
      ));
}

class _FakeMathEngine implements MathEngine {
  _FakeMathEngine(this.reply);

  EngineReply? reply;

  final List<({String expression, String angleMode})> calls = [];

  @override
  Future<EngineReply> evaluate(
    String expression, {
    required String angleMode,
  }) async {
    calls.add((expression: expression, angleMode: angleMode));
    return reply ?? EngineReply.failure('no reply configured');
  }
}

CalculatorController _controller(
  _FakeDatabase db, {
  required MathEngine engine,
  Duration liveEvaluationDelay = const Duration(minutes: 10),
  Duration liveEngineFollowUpDelay = const Duration(minutes: 10),
}) {
  return CalculatorController(
    historyRepository: HistoryRepository(db),
    notesRepository: NotesRepository(db),
    settingsRepository: SettingsRepository(db),
    settings: const AppSettings(
      haptics: true,
      hapticStrength: '标准',
      restoreState: false,
      autoSaveHistory: false,
      angleMode: 'RAD',
      precision: 6,
      themeModeLabel: '跟随系统',
      expressionDisplayMode: '数学符号',
    ),
    engine: engine,
    liveEvaluationDelay: liveEvaluationDelay,
    liveEngineFollowUpDelay: liveEngineFollowUpDelay,
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
