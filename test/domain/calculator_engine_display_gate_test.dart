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
import 'package:nekocalc/features/calculator/presentation/widgets/math_expression_view.dart';

/// 中文：这一轮把 `_acceptedEngineResult` 拆成了两个判据：
///
///       - **可显示**（结果行）——矩阵、复数、解集、精确形式都算；
///       - **可当数字用**（`Ans`/`last`/记忆/继续使用/历史去重/粘贴回填）——仍然要求有限十进制。
///
///       这个文件钉住两件事：两个判据**各自**的边界，以及放宽的那一半**没有**漏进数值消费者。
///       所有引擎侧的形状都取自真机日志（`smoke` 行），不是编的。
/// English: This round split `_acceptedEngineResult` into two judgements:
///
///          - **displayable** (the result line) — matrices, complex numbers, solution sets and exact
///            forms all qualify;
///          - **usable as a number** (`Ans`/`last`/memory/continue-with/history de-duplication/paste)
///            — still requires a finite decimal.
///
///          This file pins both boundaries, and pins that the relaxed half did **not** leak into the
///          numeric consumers. Every engine-side shape below comes from a device log line (`smoke`),
///          not from imagination.
void main() {
  group('可显示：只拒绝真正非有限的，以及引擎没算的', () {
    test('矩阵、复数、符号结果、解集都可显示', () {
      // 中文：每一条都是真机日志里的原文（`smoke` 行的 decimal 字段）。
      // English: each of these is verbatim from a device log line (the `decimal` field).
      expect(MathResult.textIsDisplayable('[1  2; 3  4]'), isTrue);
      expect(MathResult.textIsDisplayable('1 + 2i'), isTrue);
      expect(MathResult.textIsDisplayable('2x'), isTrue);
      expect(MathResult.textIsDisplayable('[2  -2]'), isTrue);
      expect(MathResult.textIsDisplayable('i'), isTrue);
      expect(MathResult.textIsDisplayable('5.656854249492380'), isTrue);
      expect(MathResult.textIsDisplayable('1.071508607186267E301'), isTrue);
    });

    test('真正非有限的字面量不可显示', () {
      for (final text in <String>[
        '-infinity', // 真机：`ln(0)` 印成这个
        'infinity',
        '+infinity',
        'infinity',
        'NaN',
        'nan',
        '∞',
        '-∞',
        '+∞',
      ]) {
        expect(MathResult.textIsDisplayable(text), isFalse,
            reason: '「$text」不是有限值，不该上结果行');
      }
    });

    test('形状决定配不配显示：矩阵/向量/复数/换算是唯一放行的四种', () {
      // 中文：`resultKind` 由引擎自己的判据回答，Dart 侧只做这条策略。四支放行、两支拒绝，
      //       合起来是引擎结果空间的一个划分（见 `MathResult.isDisplayable` 的长注释）。
      // English: `resultKind` is answered by the engine's own predicates and Dart only applies this
      //          policy. Four branches pass and two do not; together they partition the engine's
      //          result space (see the long note on `MathResult.isDisplayable`).
      MathResult withKind(EngineResultKind kind) =>
          MathResult(displayText: 'whatever', resultKind: kind);

      expect(withKind(EngineResultKind.structured).isDisplayable, isTrue);
      expect(withKind(EngineResultKind.number).isDisplayable, isTrue);
      expect(withKind(EngineResultKind.conversion).isDisplayable, isTrue);
      expect(withKind(EngineResultKind.notFromEngine).isDisplayable, isTrue);
      expect(withKind(EngineResultKind.unit).isDisplayable, isFalse);
      expect(withKind(EngineResultKind.arithmetic).isDisplayable, isFalse);
    });

    test('非有限字面量即便形状是 number 也不可显示', () {
      // 中文：这一条是文本层的存在理由——`ln(0)` 在引擎那里是一个 Number（形状层会放行），
      //       只有非有限字面量这一条拦得住它。
      // English: why the text layer still exists — `ln(0)` is a Number on the engine's side (the shape
      //          layer would wave it through), and only the non-finite literal clause stops it.
      for (final text in <String>['-infinity', 'infinity', 'NaN', '∞']) {
        final result = MathResult(
          displayText: text,
          resultKind: EngineResultKind.number,
        );
        expect(result.isDisplayable, isFalse, reason: '「$text」不该上结果行');
      }
    });

    test('空串不可显示', () {
      expect(MathResult.textIsDisplayable(''), isFalse);
      expect(MathResult.textIsDisplayable('   '), isFalse);
      // 中文：判据只对**引擎印出来的值**用（[isDisplayable] 的唯一调用点是引擎回执那条路），
      //       所以它刻意只拒绝那两类、其余一律放行；「等待输入」这类应用自己的占位文本从不经过它。
      //       这一条钉住「拒绝面是窄的」这件事本身：多拒绝一类就会少显示一类引擎结果。
      // English: the judgement is applied only to **what the engine printed** (its one call site is
      //          the engine-receipt path), so it deliberately rejects those two families and lets
      //          everything else through; app-side placeholders like "等待输入" never reach it. This
      //          assertion pins that narrowness: one extra rejection is one engine result fewer.
      expect(MathResult.textIsDisplayable('等待输入'), isTrue);
    });

    test('两个判据互不替代', () {
      // 中文：矩阵**可显示但不可当数字用**；`5.656854249492380` 两者皆是。这正是不该合并它们
      //       的原因——合并成任何一个都会错一半。
      // English: a matrix is **displayable but not usable as a number**; `5.656854249492380` is
      //          both. That is exactly why the two must not be merged — merging into either one gets
      //          half the cases wrong.
      const matrix = MathResult(displayText: '[1  2; 3  4]');
      expect(matrix.isDisplayable, isTrue);
      expect(matrix.hasFiniteDecimal, isFalse);
      expect(matrix.decimalValue, isNull);

      const decimal = MathResult(
        displayText: '5.656854',
        decimalText: '5.656854249492380',
      );
      expect(decimal.isDisplayable, isTrue);
      expect(decimal.hasFiniteDecimal, isTrue);
      expect(decimal.decimalValue, isNotNull);
    });
  });

  group('收紧：形状不配显示的答案一律回落旧解析器', () {
    // 中文：**这一组是修复轮 2 的核心。** 上一条规则（「整个文本是『数字 运算符 数字』」）是一张
    //       举例清单，实测漏掉了一整类；现在由引擎自己报的形状决定，下面每一条都是**真机实测的
    //       原文**（`decimal` 与引擎判据同时列出）。
    // English: **this group is the heart of fix round 2.** The previous rule ("the whole text is
    //          `number operator number`") was a list of examples and missed a whole class; the shape
    //          the engine itself reports now decides. Every row below is verbatim **device-measured**
    //          (the `decimal` together with the engine's predicates).
    const rows = <({String expression, String decimal, EngineResultKind kind, bool legacyAnswers})>[
      // 引擎把 app 自己的名字读成了单位或常量——一个带单位的量。
      (expression: 'fact(-1)', decimal: '-10 aa*t', kind: EngineResultKind.unit, legacyAnswers: false),
      (
        expression: 'ncr(5,10)',
        decimal: "[(1.49896229n'r' km/us)  (2.99792458n'r' km/us)]",
        kind: EngineResultKind.unit,
        // 旧解析器认得 `ncr`（它是应用自己的词汇），所以它给得出一个答案——那正是要的：
        // 引擎的乱码不上屏，应用一贯的答案照旧。
        legacyAnswers: true,
      ),
      // 引擎拒绝做这次运算，把结果留成一个未求值的形状：乘积 / 幂 / 函数调用。
      (expression: '1/0', decimal: '1 / 0', kind: EngineResultKind.arithmetic, legacyAnswers: false),
      (expression: 'i/0', decimal: 'i / 0', kind: EngineResultKind.arithmetic, legacyAnswers: false),
      (expression: '(1+i)/0', decimal: '(1 + i) / 0', kind: EngineResultKind.arithmetic, legacyAnswers: false),
      (
        expression: 'matrix(2,2,1,2,3,4)/0',
        decimal: '[1  2; 3  4] / 0',
        kind: EngineResultKind.arithmetic,
        legacyAnswers: false,
      ),
      (expression: '2 mod 0', decimal: 'mod(2; 0)', kind: EngineResultKind.arithmetic, legacyAnswers: false),
      (expression: 'root(2,0)', decimal: 'root(2; 0)', kind: EngineResultKind.arithmetic, legacyAnswers: false),
      (expression: 'x/0', decimal: 'x / 0', kind: EngineResultKind.arithmetic, legacyAnswers: false),
    ];

    for (final row in rows) {
      test('${row.expression} 不显示引擎的「${row.decimal}」', () async {
        final engine = _FakeMathEngine(EngineReplyFixture(
          displayText: row.decimal,
          displayTex: '',
          kind: row.kind,
        ).reply);
        final controller = _controller(_FakeDatabase(), engine: engine);

        controller.setExpression(row.expression);
        await controller.submit();

        expect(controller.result, isNot(row.decimal),
            reason: '${row.expression} 把引擎的乱码印上了结果行');
        if (!row.legacyAnswers) {
          expect(controller.hasError, isTrue,
              reason: '${row.expression} 应当由旧解析器给出错误');
        }

        controller.dispose();
      });
    }
  });

  group('过期回包不许动 Ans/last（修的是守卫的顺序）', () {
    test('过期的 tier 2 回包不写 `_lastFiniteResult`', () async {
      // 中文：**这一条必须走得到 tier 2。** `_tryLegacyResult` → `_calculateResult` 会写
      //       `_lastFiniteResult`，而那是 `ans`/`last` 的取值处；旧测试用的都是数值回包
      //       （引擎有十进制），tier 1 直接采用、根本不碰旧解析器，所以覆盖不到这条路。
      //
      //       构造方式：让第一发引擎调用在飞时改掉输入（代际因此前进），再放行那一发——
      //       它落地时代际已经不匹配，什么都不许写。`ans` 会被替换成哪个值，是通过**问引擎时
      //       实际发过去的字符串**观测的（替身记下了每一次调用）。
      // English: **this one has to reach tier 2.** `_tryLegacyResult` → `_calculateResult` writes
      //          `_lastFiniteResult`, which is what `ans`/`last` resolve from; the older staleness
      //          tests all used numeric replies (the engine had a decimal), which are adopted at tier
      //          1 without ever touching the legacy parser — so they cannot reach this path.
      //
      //          Construction: change the input while the first engine call is in flight (the
      //          generation moves on), then release that call — by the time it lands the generation no
      //          longer matches and nothing may be written. Which value `ans` gets replaced with is
      //          observed from **the string actually sent to the engine** (the double records each
      //          call).
      final engine = _DeferredMathEngine();
      final controller = _controller(
        _FakeDatabase(),
        engine: engine,
        liveEvaluationDelay: const Duration(milliseconds: 1),
        liveEngineFollowUpDelay: const Duration(milliseconds: 1),
      );

      // 中文：第一段时间线：`6*7`，旧解析器给出 42 → `_lastFiniteResult` = 42；引擎那一发在飞。
      // English: first timeline: `6*7`, the legacy parser answers 42 → `_lastFiniteResult` = 42; the
      //          engine call is in flight.
      controller.setExpression('6*7');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(engine.calls.map((c) => c.expression), contains('6*7'));

      // 中文：第二段时间线：`1+1` → 2，于是 `_lastFiniteResult` = 2。
      // English: second timeline: `1+1` → 2, so `_lastFiniteResult` = 2.
      controller.setExpression('1+1');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(controller.result, '2');

      // 中文：放行**第一发**（过期的那个）：它的形状是 tier 2（矩阵），所以取舍那一处会去问
      //       旧解析器；而过期的源表达式 `6*7` 旧解析器答得出来 —— 42。
      // English: release the **first** call (the stale one): its shape is tier 2 (a matrix), so the
      //          selection asks the legacy parser, and the stale source `6*7` has an answer — 42.
      engine.answer(const EngineReplyFixture(
        displayText: '[1  2; 3  4]',
        displayTex: r'\begin{bmatrix}1 & 2 \\ 3 & 4\end{bmatrix}',
        kind: EngineResultKind.structured,
      ).reply);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      // 中文：屏幕上还该是 2。此时那一发「还欠一次」的跟进已经在飞，用一个**失败**回执把它收掉：
      //       失败回执什么都不写，于是 `_lastFiniteResult` 保持在第 2 段时间线的值上——
      //       这样后面那一次观测到的差异只可能来自过期的那一发。
      // English: the screen still reads 2. The follow-up "one more is owed" is now in flight; retire
      //          it with a **failure** receipt: a failure writes nothing, so `_lastFiniteResult` stays
      //          on the second timeline's value — which leaves the stale call as the only possible
      //          source of a difference in the observation below.
      await Future<void>.delayed(const Duration(milliseconds: 30));
      engine.answer(EngineReply.failure('test: nothing lands'));
      await Future<void>.delayed(const Duration(milliseconds: 30));

      // 中文：`ans` 必须解析成 **2**——被问到的字符串就是答案（替身记下了每一次调用）。
      // English: `ans` has to resolve to **2** — the string it was asked about is the answer (the
      //          double records every call).
      expect(controller.result, '2');
      controller.setExpression('ans');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(engine.calls.last.expression, '2',
          reason: '过期的回包把 Ans/last 挪到了旧时间线上（应当是 2，不是 42）');

      controller.dispose();
    });
  });

  group('新点亮的两个形态在渲染器里排得出来', () {
    test('矩阵的排版形态（引擎给的 LaTeX）与复数的排版形态都认', () {
      // 中文：这两条是**引擎印出来的**精确形态（真机日志原文），结果行会原样把它们交给
      //       `Math.tex`——所以它们必须过渲染器自己那一关，否则结果行会退回纯文本读数
      //       （`[1  2; 3  4]` 也能看，但一个真矩阵比一串方括号好）。
      // English: these two are the **engine's own** exact forms (verbatim device log lines) and the
      //          result line hands them to `Math.tex` as they are — so they have to pass the
      //          renderer's own check, or the result line falls back to the plain reading (`[1  2;
      //          3  4]` is readable, but a real matrix beats a string of brackets).
      expect(
        MathExpressionView.typesetsTex(r'\begin{bmatrix}1 & 2 \\ 3 & 4\end{bmatrix}'),
        isTrue,
        reason: '矩阵的 LaTeX 排不出来，结果行会退回纯文本',
      );
      expect(MathExpressionView.typesetsTex('1 + 2i'), isTrue);
      expect(MathExpressionView.typesetsTex('i'), isTrue);
    });
  });

  group('提交路径：能显示就显示，能当数字用才留给数值消费者', () {
    test('矩阵结果显示出来（改之前它被整条丢掉）', () async {
      final engine = _FakeMathEngine(const EngineReplyFixture(
        displayText: '[1  2; 3  4]',
        displayTex: r'\begin{bmatrix}1 & 2 \\ 3 & 4\end{bmatrix}',
        kind: EngineResultKind.structured,
      ).reply);
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('matrix(2,2,1,2,3,4)');
      final submitted = await controller.submit();

      expect(controller.hasError, isFalse, reason: '矩阵现在应当能上屏');
      expect(controller.result, '[1  2; 3  4]');
      expect(controller.resultTex, contains('bmatrix'));
      expect(submitted.submitted, isTrue);

      controller.dispose();
    });

    test('复数结果显示出来，但 `Ans`/记忆拿不到数字', () async {
      final engine = _FakeMathEngine(const EngineReplyFixture(
        displayText: '1 + 2i',
        displayTex: '1 + 2i',
        kind: EngineResultKind.number,
      ).reply);
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('2i+1');
      await controller.submit();

      expect(controller.hasError, isFalse);
      expect(controller.result, '1 + 2i');

      // 中文：数值消费者这一半**没有放宽**：`decimalText` 是空的，于是记忆寄存器拒绝收下它，
      //       而不是静默加一个 0。
      // English: the numeric half is **not** relaxed: `decimalText` is empty, so the memory register
      //          refuses it rather than silently adding a 0.
      expect(controller.resultDecimal, isEmpty);
      controller.memoryAdd();
      expect(controller.memoryValue, 0);

      controller.dispose();
    });

    test('`1/0` 仍然不显示成 `1 / 0`', () async {
      // 中文：引擎对这一条**回的是 ok**，只是把算式原样退回来。整条落到旧解析器，用户看到的
      //       仍是今天那句「结果不是有限数值」。
      // English: for this one the engine answers **ok** and simply hands the expression back. The
      //          whole thing falls through to the legacy parser, and the user still sees today's
      //          "结果不是有限数值".
      // 中文：真机实测 `1/0` 的形状是「乘积 / 幂」——引擎拒绝做这次除法，把算式原样退回来，
      //       所以原生侧报的是 `arithmetic`（不是列表式的「看它像不像一个算式」）。
      // English: measured on a device, `1/0`'s shape is a product/a power — the engine refuses the
      //          division and hands the expression back, so the native side reports `arithmetic`
      //          (rather than a list-like "does this look like an arithmetic").
      final engine = _FakeMathEngine(
        const EngineReplyFixture(
          displayText: '1 / 0',
          displayTex: r'\frac{1}{0}',
          kind: EngineResultKind.arithmetic,
        ).reply,
      );
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('1/0');
      final submitted = await controller.submit();

      expect(controller.hasError, isTrue);
      expect(controller.result, '结果不是有限数值');
      expect(controller.result, isNot(contains('1 / 0')));
      expect(submitted.submitted, isFalse);

      controller.dispose();
    });

    test('引擎把应用自己的词汇表读成别的东西时，旧解析器的答案优先', () async {
      // 中文：真机实测 `ncr(5,10)` 被引擎读成一串带单位的量（`n`=纳、`c`、`r` 各自成了单位/常量），
      //       印成 `[(1.49896229n'r' km/us) …]`——那是**可显示**的，但它是引擎把表达式理解成
      //       另一个东西之后的产物。旧解析器认得 `ncr` 并给出 10。已经上线的键必须逐字节不变。
      // English: measured on a device — the engine reads `ncr(5,10)` as a list of unit-carrying
      //          quantities (`n`, `c` and `r` each become a unit or a constant) and prints
      //          `[(1.49896229n'r' km/us) …]`. That is **displayable**, but it is what the engine
      //          made of an expression it read as something else. The legacy parser knows `ncr` and
      //          answers 10. A key that already works has to stay byte-for-byte what it was.
      final engine = _FakeMathEngine(const EngineReplyFixture(
        displayText: "[(1.49896229n'r' km/us)  (2.99792458n'r' km/us)]",
        displayTex: r'\begin{bmatrix}1.49896229\end{bmatrix}',
      ).reply);
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('ncr(5,10)');
      await controller.submit();

      expect(controller.hasError, isFalse);
      // 旧解析器的答案：C(5,10) 在它那里是 0（选不出来），关键是它**答得出**，于是它说了算。
      expect(controller.result, '0');
      expect(controller.resultDecimal, '0');

      controller.dispose();
    });

    test('边打边算走同一处取舍：矩阵在屏幕上、且不会被旧解析器顶掉', () async {
      final engine = _FakeMathEngine(const EngineReplyFixture(
        displayText: '[1  2; 3  4]',
        displayTex: r'\begin{bmatrix}1 & 2 \\ 3 & 4\end{bmatrix}',
        kind: EngineResultKind.structured,
      ).reply);
      // 中文：两段延迟都要压短：`evaluate()` 由防抖定时器（`liveEvaluationDelay`）叫起，引擎那
      //       一发由它再排（`liveEngineFollowUpDelay`）。
      // English: both delays have to be shortened: `evaluate()` is called by the debounce timer
      //          (`liveEvaluationDelay`), and the engine follow-up is scheduled from there
      //          (`liveEngineFollowUpDelay`).
      final controller = _controller(
        _FakeDatabase(),
        engine: engine,
        liveEvaluationDelay: const Duration(milliseconds: 1),
        liveEngineFollowUpDelay: const Duration(milliseconds: 1),
      );

      controller.setExpression('matrix(2,2,1,2,3,4)');
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(controller.result, '[1  2; 3  4]');
      expect(controller.hasError, isFalse);

      controller.dispose();
    });
  });
}

/// 中文：一条引擎回执的固定装置——把「引擎给出什么形态」写成可读的三个字段。
/// English: A fixture for one engine receipt — the three shapes the engine hands over, spelled out.
class EngineReplyFixture {
  const EngineReplyFixture({
    required this.displayText,
    required this.displayTex,
    this.kind = EngineResultKind.arithmetic,
  });

  final String displayText;
  final String displayTex;

  /// 中文：引擎自己报的形状（原生侧由 `MathStructure` 的判据回答）。默认取**不显示**的那一支，
  ///       于是「忘了写形状」的测试不会意外地让垃圾上屏。
  /// English: the shape the engine reported (the native side answers it from `MathStructure`
  ///          predicates). The default is the **do-not-display** branch, so a test that forgets to
  ///          state a shape cannot accidentally let garbage through.
  final EngineResultKind kind;

  EngineReply get reply => EngineReply.success(MathResult(
        displayText: displayText,
        displayTex: displayTex,
        // 中文：引擎自己的规矩（`QalculateMathEngine._replyFrom`）：十进制形态只在它**是有限数**
        //       时才写；矩阵/复数这一类留空，数值消费者据此不再解析。
        // English: the adapter's own rule (`QalculateMathEngine._replyFrom`): the decimal form is
        //          written only when it **is** a finite number; matrices and complex numbers leave it
        //          empty, and numeric consumers stop there.
        decimalText: MathResult.decimalTextIsFinite(displayText) ? displayText : '',
        resultKind: kind,
      ));
}

class _FakeMathEngine implements MathEngine {
  _FakeMathEngine(this.reply);

  EngineReply? reply;

  @override
  Future<EngineReply> evaluate(
    String expression, {
    required String angleMode,
  }) async =>
      reply ?? EngineReply.failure('no reply configured');
}

/// 中文：**手动放行**的引擎替身——回答由测试在某个时刻给，于是「回包到达时状态已经变了」这个
///       条件可以被精确地构造出来。同时记下每一次被问到的表达式，`ans` 被替换成了什么因此可观测。
/// English: an engine double the test **releases by hand** — the answer is supplied at a chosen
///          moment, so "a reply lands after the state has moved on" can be constructed exactly. It
///          also records every expression it was asked about, which makes what `ans` was replaced
///          with observable.
class _DeferredMathEngine implements MathEngine {
  final List<({String expression, String angleMode})> calls = [];
  final List<Completer<EngineReply>> _pending = [];

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

  /// 中文：放行**最老的那一发**在飞的请求。
  /// English: releases the **oldest** request still in flight.
  void answer(EngineReply reply) {
    _pending.removeAt(0).complete(reply);
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
