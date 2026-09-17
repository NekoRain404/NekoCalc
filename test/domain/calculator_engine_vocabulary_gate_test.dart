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

    test('phi(2)：问出去的是常量 ×2 的数值，屏幕上必须是 3.236068（不是欧拉函数的 1）', () async {
      // 中文：**常量被当成函数调用**（修复轮 5 的第三个 `log`）。引擎里 `phi` 是一个**函数**
      //       （欧拉 φ 函数，实测 `phi(2)` → `1`），应用里 `phi` 是**常量**（黄金比），所以
      //       「引擎读这个拼法」的答案曾经是错的。
      //
      //       **修复轮 8/9 之后这件事由翻译了结，不由名字层。** 归一化把 `phi(2)` 写成 `phi*(2)`
      //       （常量乘分组，**不再是调用**，实测 `ExpressionParser.normalizeExpressionInput`），
      //       名字层读的正是这一份，于是它不再判 `phi` 不可用；翻译再把常量写成它的数值，引擎被问的
      //       是 `((1.618033988749895)*((2)))`——它对这一问的答复（实测 `3.23606797749979`）**就是
      //       应用自己的值**。欧拉函数那个 `1` 因此**问不出来**了：引擎不会再收到 `phi(2)` 这个式子。
      //       本条的替身回的是**引擎实测的原文**（对上面那个被问到的字符串），断言因此落在
      //       「问出去的字符串」与「屏幕上的值」两处——替身再回一个 `1`，就成了现实里不存在的引擎。
      //       可输入、可粘贴（内联编辑器的文本框与剪贴板都能到它）。
      // English: **a constant written as a function call** (fix round 5's third `log`). In the engine
      //          `phi` is a **function** (Euler's totient, measured `phi(2)` → `1`) while in this app
      //          it is a **constant** (the golden ratio), so "what the engine reads for this spelling"
      //          used to be the wrong thing.
      //
      //          **After fix rounds 8/9 the translation settles this, not the name layer.**
      //          Normalisation writes `phi(2)` as `phi*(2)` (a constant times a group, **no longer a
      //          call** — measured with `ExpressionParser.normalizeExpressionInput`), and that is
      //          exactly the string the name layer reads, so it stops judging `phi` unusable; the
      //          translation then writes the constant as its value, and the engine is asked
      //          `((1.618033988749895)*((2)))` — whose answer (measured `3.23606797749979`) **is this
      //          app's own value**. The totient's `1` therefore **cannot be asked for any more**: the
      //          engine never receives `phi(2)`. The double here answers with the **engine's measured
      //          text** for that asked string, so the assertions land on "the string that goes out" and
      //          "the value on screen" — a double answering `1` again would model an engine that
      //          cannot exist. It is typeable and pasteable (the inline editor's text field and the
      //          clipboard both reach it).
      final engine = _FakeMathEngine(const EngineReplyFixture(
        displayText: '3.23606797749979',
        displayTex: '3.23606797749979',
        kind: EngineResultKind.number,
      ).reply);
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('phi(2)');
      await controller.submit();

      expect(engine.calls.single.expression, '((1.618033988749895)*((2)))',
          reason: '引擎被问的必须是常量的数值，不是 `phi(2)` 这个调用');
      expect(controller.result, '3.236068', reason: '引擎的欧拉函数被当成了黄金比');
      expect(controller.resultDecimal, '3.23606797749979');

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
      // 中文：**输入先过 `ExpressionParser.normalizeExpressionInput`（修复轮 9）**，下面是这一层
      //       自己的例子。`fact 171` 归一化写成 `fact(171)`、全角 `ｌｇ(8,2)` 写成 `lg(8,2)` 再折成
      //       `log`——**归一化之后才成为词汇表名字**的拼法。不归一化时这两条都判真，引擎的答案因此
      //       上屏（实测：`1.241018070217668E309` 与二元素向量；两条端到端的红证在
      //       `calculator_engine_translation_test.dart`）。
      // English: **the input goes through `ExpressionParser.normalizeExpressionInput` first (fix round
      //          9)**; here are that layer's own examples. `fact 171` normalises to `fact(171)`, the
      //          full-width `ｌｇ(8,2)` to `lg(8,2)` and on to `log` — spellings that **only become
      //          vocabulary names after normalisation**. Without the normalisation both were true and
      //          the engine's answer reached the screen (measured: `1.241018070217668E309` and a
      //          two-element vector; the two end-to-end red proofs are in
      //          `calculator_engine_translation_test.dart`).
      expect(AppEngineVocabulary.canRead('fact 171'), isFalse);
      expect(AppEngineVocabulary.canRead('ｆａｃｔ(171)'), isFalse);
      expect(AppEngineVocabulary.canRead('ｌｇ(8,2)'), isFalse);
      // 中文：`1.5° to arcmin` **归一化之后**是 `rad(1.5) to arcmin`（`°` 被写成 `rad(…)`），里面因此
      //       有一个 `rad` 调用，而 `rad` 在「不可用」那一列——修复轮 9 之前它读原文、判真。
      //       **屏幕上没有变化**：翻译器在名字层之前就拒了 `rad`，引擎一次都没被问
      //       （实测与那条端到端断言同在 `calculator_engine_translation_test.dart`）。
      // English: `1.5° to arcmin` **normalises** to `rad(1.5) to arcmin` (`°` is written `rad(…)`), so
      //          it does contain a `rad` call, and `rad` is in the unusable column — before fix round
      //          9 this read the raw source and said true. **Nothing changes on screen**: the
      //          translator refuses `rad` ahead of the name layer, so the engine is never asked (the
      //          measurement lives with the end-to-end assertion in
      //          `calculator_engine_translation_test.dart`).
      expect(AppEngineVocabulary.canRead('1.5° to arcmin'), isFalse);
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
        decimalText:
            MathResult.decimalTextIsFinite(displayText) ? displayText : '',
        resultKind: kind,
      ));
}

class _FakeMathEngine implements MathEngine {
  _FakeMathEngine(this.reply);

  EngineReply? reply;

  /// 中文：被问到的表达式。`phi(2)` 那一条要断言**问出去的是常量的数值**（修复轮 9 起那件事由
  ///       翻译负责，名字层不再拦它）。
  /// English: every expression it was asked about. The `phi(2)` row asserts that **the constant's
  ///          value is what goes out** (since fix round 9 that is the translation's job; the name
  ///          layer no longer stops it).
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
