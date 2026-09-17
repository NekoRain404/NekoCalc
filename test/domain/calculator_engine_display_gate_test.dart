import 'dart:async';

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

    test('非有限值嵌在算式里也不可显示（按位置判，不是按整串）', () {
      // 中文：这一条是修复轮 3 的第 4 项。旧的实现是「整串恰好等于 `∞`/`infinity`/`NaN`」，
      //       于是**嵌在算式里**的非有限值照样上屏：`infinity*i` 打印成
      //       `(+infinity) * i`（复审实测，真机同样）。改成按位置扫描之后它被覆盖。
      // English: fix round 3's item 4. The old implementation matched "the whole string equals
      //          `∞`/`infinity`/`NaN`", so a non-finite value **nested inside an expression** was
      //          still displayed: `infinity*i` prints as `(+infinity) * i` (measured by the review,
      //          and on the device). Scanning by position covers it.
      for (final text in <String>[
        '(+infinity) * i',
        'infinity',
        '-infinity',
        '+infinity',
        'NaN',
        '∞',
        '1 + NaN',
      ]) {
        expect(MathResult.textIsDisplayable(text), isFalse,
            reason: '「$text」不是有限值，不该上结果行');
      }
      // 中文：有限值一个都不许受影响——包括长得像名字的那些（`info` 不是 `infinity`）。
      // English: no finite value may be affected — including ones that look like a name (`info` is
      //          not `infinity`).
      for (final text in <String>[
        '[1  2; 3  4]',
        '1 + 2i',
        '2x',
        '5.656854249492380',
        'info',
        'nanometer',
      ]) {
        expect(MathResult.textIsDisplayable(text), isTrue,
            reason: '「$text」是有限值，不该被拦');
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
    test('过期的回包不写 `_lastFiniteResult`（可显示但不是数字的那种）', () async {
      // 中文：**这一条要的是一份「会去写 `_lastFiniteResult`」的过期回包。** 旧测试用的都是数值
      //       回包（引擎有十进制），而落地的数值回包会把 `ans`/`last` 挪到**过期的那个表达式**上；
      //       这里放行的是一份可显示、却没有十进制形态的回包（矩阵），于是差异只可能来自
      //       「过期那一发到底写没写状态」。
      //
      //       构造方式：让第一发引擎调用在飞时改掉输入（代际因此前进），再放行那一发——
      //       它落地时代际已经不匹配，什么都不许写。`ans` 会被替换成哪个值，是通过**问引擎时
      //       实际发过去的字符串**观测的（替身记下了每一次调用）。
      // English: **this one needs a stale reply that *would* write `_lastFiniteResult`.** The older
      //          staleness tests all used numeric replies (the engine had a decimal), and a numeric
      //          reply landing would move `ans`/`last` onto the **stale** expression; what is released
      //          here is a displayable reply with no decimal form (a matrix), so a difference can only
      //          come from "did the stale call write state at all".
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
      // 中文：问引擎的是**翻译后**的表达式（`ans` 替换后的十进制同样会被翻译）。
      // English: the engine is asked for the **translated** expression (the substituted decimal
      //          travels through the same translation).
      expect(engine.calls.map((c) => c.expression), contains('((6)*(7))'));

      // 中文：第二段时间线：`1+1` → 2，于是 `_lastFiniteResult` = 2。
      // English: second timeline: `1+1` → 2, so `_lastFiniteResult` = 2.
      controller.setExpression('1+1');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(controller.result, '2');

      // 中文：放行**第一发**（过期的那个）：它的形状是可显示、但没有十进制形态（矩阵），
      //       所以它要是落进状态，`ans`/`last` 不会被动——但代际守卫必须在取舍**之前**拦住它。
      // English: release the **first** call (the stale one): its shape is displayable with no decimal
      //          form (a matrix), so if it landed it would not move `ans`/`last` — but the generation
      //          guard has to stop it before the selection even runs.
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

  group('应用词汇：引擎读不懂的调用名一律不由引擎作答', () {
    // 中文：**这一组是修复轮 3 的核心。** `structured` 分支曾经把「引擎读不懂我们的名字」也放进来
    //       ——引擎把 `npr` 读成符号 `n'p''r'` 之后，结果**也是一个矩阵**，于是它与「矩阵是这个语言
    //       表达不了的类型」混在同一条分支里。规则改成看**输入**：表达式里只要有一个「属于应用词汇、
    //       引擎不认识」的调用，引擎这一次的答案就不权威（`AppEngineVocabulary.engineCanRead`）。
    // English: **this group is the heart of fix round 3.** The `structured` branch used to admit "the
    //          engine cannot read our names" as well — once the engine reads `npr` as the symbols
    //          `n'p''r'`, the result **is a matrix too**, so it sat in the same branch as "a type this
    //          language cannot express". The rule now looks at the **input**: if a call belongs to
    //          this app's vocabulary and the engine does not know it, the engine's answer this time is
    //          not authoritative (`AppEngineVocabulary.engineCanRead`).
    const rows = <({String expression, String engineText})>[
      (expression: 'npr(2,1.5)', engineText: "[2n'p''r'  1.5n'p''r']"),
      // 中文：`nPr` 按在空表达式上得到的正是这一条（`applyBinaryFunction('npr')` → `npr(,)`）。
      //       它是复审发现泄漏时的原始触发路径。
      // English: this is exactly what pressing `nPr` on an empty expression produces
      //          (`applyBinaryFunction('npr')` → `npr(,)`) — the original trigger of the leak the
      //          review found.
      (expression: 'npr(,)', engineText: '[0  0]'),
    ];

    for (final row in rows) {
      test('${row.expression} 不由引擎作答', () async {
        // 中文：两条都拿真机实测的引擎原文当回包，形状给 `structured`（那正是漏洞所在：它确实是个矩阵）。
        // English: both use the device-measured engine text as the reply, with the shape set to
        //          `structured` — exactly the hole: it really is a matrix.
        final engine = _FakeMathEngine(EngineReplyFixture(
          displayText: row.engineText,
          displayTex: r'\begin{bmatrix}0 & 0\end{bmatrix}',
          kind: EngineResultKind.structured,
        ).reply);
        final controller = _controller(_FakeDatabase(), engine: engine);

        controller.setExpression(row.expression);
        await controller.submit();

        expect(controller.result, isNot(row.engineText),
            reason: '引擎对 ${row.expression} 的符号读法上了屏');
        expect(controller.hasError, isTrue,
            reason: '${row.expression} 应当由旧解析器给出应用自己的错误');

        controller.dispose();
      });
    }

    test('空表达式上按一下 `nPr`：`npr(,)` 由旧解析器给出「需要输入数字」', () async {
      // 中文：**这是 brief 点名的那个用例，也是复审发现泄漏时的原始触发路径**——键盘上按 `nPr`
      //       走的是 `applyBinaryFunction('npr')`（见 `calculator_page.dart` 的 `nPr` case），
      //       空表达式上它插出 `npr(,)`。这里走**控制器**（与键盘同一条路），断言屏幕上不是引擎
      //       那个矩阵，而是应用自己的错误文案。
      // English: **the case the brief named, and the original trigger of the leak the review found** —
      //          pressing `nPr` on the keypad goes through `applyBinaryFunction('npr')` (see the `nPr`
      //          case in `calculator_page.dart`), which on an empty expression inserts `npr(,)`. This
      //          goes through the **controller** (the same path the keypad takes) and asserts the screen
      //          shows the app's own error rather than the engine's matrix.
      final engine = _FakeMathEngine(const EngineReplyFixture(
        displayText: '[0  0]',
        displayTex: r'\begin{bmatrix}0 & 0\end{bmatrix}',
        kind: EngineResultKind.structured,
      ).reply);
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.applyBinaryFunction('npr');
      expect(controller.expression, 'npr(,)',
          reason: '键盘上的 nPr 按在空表达式上插的就是这一条');
      await controller.submit();

      expect(controller.result, isNot('[0  0]'));
      expect(controller.hasError, isTrue);
      expect(controller.errorMessage, '需要输入数字');

      controller.dispose();
    });

    test('phi(2)：屏幕上必须是 3.236068（常量 ×2），不是引擎的欧拉函数 1', () async {
      // 中文：**第三个 `log`，而且它换了个形状。** 引擎里 `phi` 是一个**函数**（欧拉 φ 函数），
      //       而应用里 `phi` 是**常量**（黄金比）——于是 `phi(2)` 引擎给 `1`、应用给 `1.618…×2`
      //       = `3.236068`。种类是 `number`、有有限十进制 → tier 1 直接采用引擎的值。
      //       这一类（**常量被当函数调用**）在修复轮 4 之前整个漏在词表之外：那张表只收函数名。
      //       现在常量也在表里（`AppEngineVocabulary.identifiers`），`phi` 标成不可信。
      //       可输入、可粘贴（内联编辑器的文本框与剪贴板都能到它）。
      // English: **the third `log`, in a different shape.** In the engine `phi` is a **function**
      //          (Euler's totient); in this app `phi` is a **constant** (the golden ratio) — so
      //          `phi(2)` gives the engine `1` and this app `1.618… × 2` = `3.236068`. Its kind is
      //          `number` with a finite decimal, so tier 1 adopted the engine's value. This class —
      //          **a constant written as a call** — was entirely outside fix round 4's vocabulary,
      //          which held function names only. Constants are in the table now
      //          (`AppEngineVocabulary.identifiers`) and `phi` is marked untrusted. It is typeable and
      //          pasteable (the inline editor's text field and the clipboard both reach it).
      final engine = _FakeMathEngine(const EngineReplyFixture(
        displayText: '1',
        displayTex: '1',
        kind: EngineResultKind.number,
      ).reply);
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('phi(2)');
      await controller.submit();

      expect(controller.result, '3.236068', reason: '引擎的欧拉函数被当成了黄金比');
      expect(controller.resultDecimal, '3.236068');

      controller.dispose();
    });

    test('mod(7,-3)：屏幕上必须是 1（应用自己的余数），不是引擎的 -2', () async {
      // 中文：**键盘可达的真错值**：`7` → `mod` → `+/-` → `3` 曾显示 `-2`（引擎的余数），
      //       而应用自己的解析器给 `1`（Dart 的 `%` 是欧几里得余数）。其种类是 `number`、
      //       有有限十进制，于是 tier 1 **直接采用**了引擎的答案。复审的 629 个表达式扫描里，
      //       它是除 `log` 外唯一剩下的同名数值分歧。
      // English: **a keypad-reachable wrong value**: `7` → `mod` → `+/-` → `3` used to show `-2` (the
      //          engine's remainder) where this app's own parser gives `1` (Dart's `%` is the
      //          Euclidean remainder). Its kind is `number` with a finite decimal, so tier 1 adopted
      //          the engine's answer outright. In the review's 629-expression sweep it was the only
      //          remaining same-name numeric divergence besides `log`.
      final engine = _FakeMathEngine(const EngineReplyFixture(
        displayText: '-2',
        displayTex: '-2',
        kind: EngineResultKind.number,
      ).reply);
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('mod(7,-3)');
      await controller.submit();

      expect(controller.result, '1', reason: '引擎的余数被当成了应用的余数');
      expect(controller.resultDecimal, '1');

      controller.dispose();
    });

    test('log(100)：语义不同，引擎的答案不许采用（应用给 2，引擎给 ln）', () async {
      // 中文：真机实测 `log(100)` 的引擎答案是 `4.605170185988091`（自然对数），而应用自己的
      //       `log` 是常用对数 → `2`。这是一条**静默错值**（它在引擎接进提交路径的那一步就存在），
      //       词表把它拦下之后由旧解析器给出正确值。
      // English: measured on a device, the engine's answer for `log(100)` is `4.605170185988091` (the
      //          natural logarithm) while this app's `log` is the common one → `2`. That is a
      //          **silently wrong value** (it has been there since the engine reached the submit path);
      //          the vocabulary stops it and the legacy parser gives the right value.
      final engine = _FakeMathEngine(const EngineReplyFixture(
        displayText: '4.605170185988091',
        displayTex: '4.605170185988091',
        kind: EngineResultKind.number,
      ).reply);
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('log(100)');
      await controller.submit();

      expect(controller.result, '2', reason: '引擎的自然对数被当成了常用对数');
      expect(controller.resultDecimal, '2');

      controller.dispose();
    });

    test('词表：引擎的答案能用的名字照旧放行，不能用的才拦', () {
      // 中文：`engineCanRead` 只看**输入里的调用名**与那张封闭词表，与结果无关。
      //       「引擎不认识」那一列是用引擎自己的符号表量出来的（见词表文件头与报告）。
      // English: `engineCanRead` looks only at the **call names in the input** against that closed
      //          vocabulary, never at the result. The "the engine does not know it" column was
      //          measured from the engine's own symbol table (see the vocabulary file header and the
      //          report).
      expect(AppEngineVocabulary.canRead('matrix(2,2,1,2,3,4)'), isTrue);
      expect(AppEngineVocabulary.canRead('sum(x,1,10,x)'), isTrue);
      // 中文：`log2` 是**引擎认识**的拼法（量过），所以它不拦。
      // English: `log2` is a spelling the engine **knows** (measured), so it is not blocked.
      expect(AppEngineVocabulary.canRead('sqrt(8)+log2(4)'), isTrue);
      // 中文：`log` 是**语义**不同的例子：引擎有这个名字，但它的 `log` 是自然对数、应用的是
      //       常用对数（实测 `log(100)`：引擎 `4.605170185988091`、应用 `2`），所以它的答案不权威。
      // English: `log` is the **semantic** case: the engine has the name, but its `log` is the natural
      //          logarithm while the app's is the common one (measured `log(100)`: engine
      //          `4.605170185988091`, app `2`), so its answer is not authoritative.
      expect(AppEngineVocabulary.canRead('log(100)'), isFalse);
      // 中文：不是调用（没有括号）的名字不由这张词表管——`i` 是引擎认识的变量。
      // English: a name that is not a call (no bracket) is not this table's business — `i` is a
      //          variable the engine knows.
      expect(AppEngineVocabulary.canRead('2i+1'), isTrue);
      expect(AppEngineVocabulary.canRead('ncr(5,2)'), isFalse);
      expect(AppEngineVocabulary.canRead('npr(2,1.5)'), isFalse);
      expect(AppEngineVocabulary.canRead('fact(5)'), isFalse);
      expect(AppEngineVocabulary.canRead('deg(pi)'), isFalse);
      expect(AppEngineVocabulary.canRead('1+rad(30)*2'), isFalse);
      // 中文：`1.5° to arcmin` 里没有任何**调用**，所以词表管不着它——它由 conversion 那一支接住。
      // English: `1.5° to arcmin` contains no **call**, so the vocabulary has nothing to say about it
      //          — the conversion branch catches it.
      expect(AppEngineVocabulary.canRead('1.5° to arcmin'), isTrue);
      // 中文：`i(2)`/`e(2)`/`pi(2)` 里的名字**不是函数**（`i`/`e`/`pi` 是引擎的变量、应用里的常量），
      //       所以它们不在词表里、这条规则不管它们。引擎侧放行它们是有意的：`i(2)` 是隐式乘法
      //       `2i`（在本轮之前就可显示），把「不是函数名」当成「读不懂」会误伤它——那一条判据在
      //       原生侧（`QalculateEngine` 里函数/变量/单位三者认一个），设备实测见报告第 4 条。
      // English: the names in `i(2)`/`e(2)`/`pi(2)` are **not functions** (`i`/`e`/`pi` are the
      //          engine's variables and this app's constants), so they are not in the vocabulary and
      //          this rule has nothing to say about them. Letting them through on the engine side is
      //          deliberate: `i(2)` is the implicit product `2i` (displayable before this round), and
      //          treating "not a function name" as "cannot be read" would break it — that judgement
      //          lives natively (`QalculateEngine`: function, variable or unit all count), and the
      //          device measurement is in the report, item 4.
      expect(AppEngineVocabulary.canRead('i(2)'), isTrue);
      expect(AppEngineVocabulary.canRead('e(2)'), isTrue);
      expect(AppEngineVocabulary.canRead('pi(2)'), isTrue);
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

    test('第三级：引擎给得出可显示的形态时就用它，应用解析得了也不再顶掉它', () async {
      // 中文：**这条测试接替的是那条已经不存在的「应用解析得了 ⇒ 旧解析器优先」规则**（修复轮 5
      //       及以前的 tier 2 内部规则）：它在修复轮 6 被值判据取代，修复轮 7 又用翻译替掉了值判据。
      //       取舍现在只剩三级：词表拦下 / 有限十进制当数字用 / **可显示就显示**——第三级对
      //       「应用解析得了」的表达式同样成立，因为交给引擎的已经是翻译后的表达式（前提不再是
      //       「引擎的答案可能是误读」）。
      //
      //       样本必须真的落在**第三级**上，否则它测的是词表那一级：`sqrt(8)` 过得了词表
      //       （下面那条断言就在本文件里），旧解析器也答得出来（2.828427）——正是旧规则会起作用的那种
      //       输入，现在的答案是**引擎那一份上屏**。
      //       把第三级那两行（`isDisplayable` 那一支）删掉这条测试就会红：屏幕上会退回旧解析器的
      //       `2.828427`（命令与输出见修复轮 7 的报告）。
      // English: **this replaces the "the app can parse it ⇒ the legacy parser wins" rule, which no
      //          longer exists** (the old tier-2 internal rule, up to fix round 5): round 6 replaced it
      //          with the value criterion and round 7 replaced that with the translation. Three tiers
      //          are left: the vocabulary stops it / a finite decimal is used as a number / **a
      //          displayable answer is displayed** — and the third tier holds for expressions the app
      //          can parse too, because what reaches the engine is already the translated expression
      //          (the premise is no longer "the engine's answer may be a misreading").
      //
      //          The sample has to land on **the third tier** or the test is really about the
      //          vocabulary: `sqrt(8)` passes it (asserted right here), and the legacy parser can answer
      //          it too (2.828427) — exactly the input the old rule acted on, and now the answer is that
      //          **the engine's copy lands**. Deleting those two lines (the `isDisplayable` branch)
      //          turns this red: the screen falls back to the legacy parser's `2.828427` (command and
      //          output in fix round 7's report).
      expect(AppEngineVocabulary.canRead('sqrt(8)'), isTrue,
          reason: '样本必须过得了词表，否则这条测试到的是词表那一级');
      final engine = _FakeMathEngine(const EngineReplyFixture(
        displayText: '[9  9; 9  9]',
        displayTex: r'\begin{bmatrix}9 & 9 \\ 9 & 9\end{bmatrix}',
        kind: EngineResultKind.structured,
      ).reply);
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('sqrt(8)');
      await controller.submit();

      // 中文：引擎的矩阵上屏，旧解析器的 2.828427 不再说了算。
      // English: the engine's matrix goes on screen; the legacy parser's 2.828427 no longer wins.
      expect(controller.result, '[9  9; 9  9]');
      expect(controller.resultTex, contains('bmatrix'));
      // 中文：可显示**不等于**能当数字用：十进制形态是空的，`Ans`/记忆因此拿不到它（这一条没有放宽）。
      // English: displayable is **not** the same as usable as a number: the decimal form is empty, so
      //          `Ans`/memory get nothing from it (this one was not relaxed).
      expect(controller.resultDecimal, isEmpty);

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
