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

    test('引擎没做的那次运算不可显示（1/0 不许印成 `1 / 0`）', () {
      // 中文：真机实测 `1/0` → `1 / 0`、`0/0` → `0 / 0`、`2/0` → `2 / 0`：引擎拒绝做这次除法，
      //       把**算式本身**退回来。判据不是「取消检查」而是「换一个检查」，这几条仍然被挡住。
      // English: measured on a device — `1/0` → `1 / 0`, `0/0` → `0 / 0`, `2/0` → `2 / 0`: the
      //          engine refuses the division and hands the **expression itself** back. The rule is
      //          not "delete the check" but "swap it", and these stay out.
      expect(MathResult.textIsDisplayable('1 / 0'), isFalse);
      expect(MathResult.textIsDisplayable('0 / 0'), isFalse);
      expect(MathResult.textIsDisplayable('2 / 0'), isFalse);
      expect(MathResult.textIsDisplayable('1/0'), isFalse);
      expect(MathResult.textIsDisplayable('1 + 2'), isFalse);
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
      final engine = _FakeMathEngine(
        const EngineReplyFixture(displayText: '1 / 0', displayTex: r'\frac{1}{0}').reply,
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
  const EngineReplyFixture({required this.displayText, required this.displayTex});

  final String displayText;
  final String displayTex;

  EngineReply get reply => EngineReply.success(MathResult(
        displayText: displayText,
        displayTex: displayTex,
        // 中文：引擎自己的规矩（`QalculateMathEngine._replyFrom`）：十进制形态只在它**是有限数**
        //       时才写；矩阵/复数这一类留空，数值消费者据此不再解析。
        // English: the adapter's own rule (`QalculateMathEngine._replyFrom`): the decimal form is
        //          written only when it **is** a finite number; matrices and complex numbers leave it
        //          empty, and numeric consumers stop there.
        decimalText: MathResult.decimalTextIsFinite(displayText) ? displayText : '',
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
