import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/application/controllers/calculator_controller.dart';
import 'package:nekocalc/core/math/math_engine.dart';
import 'package:nekocalc/core/math/math_result.dart';
import 'package:nekocalc/core/math/result_text_rules.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/features/calculator/presentation/calculator_controller_strings.dart';
import 'package:nekocalc/l10n/app_language.dart';
import 'package:nekocalc/data/repositories/history_repository.dart';
import 'package:nekocalc/data/repositories/notes_repository.dart';
import 'package:nekocalc/data/repositories/settings_repository.dart';

/// 中文：**解方程：主屏第一次问引擎。**
///
///       **这一条在本轮之前完全不通。** 实测：替身引擎的 `asked` 对 `2x+1=7`、`x^2=4`、
///       `sin(x)=0.5` **全是空的**——`engineExpressionFor` 对含 `=` 的输入一律回
///       `UntranslatableExpression`（那个文件里**没有一处处理等号**），于是引擎根本不会被问，
///       屏幕上落的是旧解析器的「存在无法识别的内容」。
///       （`5d78d08` 修的是**粘贴**路径，与这一条不是一回事。）
///
///       **引擎那一半是量过的，不是猜的。** 宿主 `qalc` 5.12.0、桥自己的调用序列、
///       **照抄原生分类器的判据**（`QalculateEngine.kt:390`）跑出来的表在
///       `.superpowers/backup/engine-capability-probe.md` 第八节：
///       `2x+1=7` → kind `SYMBOLIC`、印 `x = 3`；`x^2=4` → `x = 2 || x = -2`。
///       **`SYMBOLIC` 正是 `isDisplayable` 放行的那一支**，所以原生侧一行都不用改。
///
///       ⚠️ **而三个退化形状落进 `number`，它们才是这一轮真正的活。** `x^2=-1`、`1=2`、`x=x`
///       印出来分别是 `0`、`0`、`1`——**全都是有限十进制**，而采用规则的第二级写着
///       「有限十进制 ⇒ 当数字用」。**照原来那条路，用户问「x²=−1 的解」，屏幕答 `0`。**
///       那不是算错，是**引擎的布尔值被当成了一个数**。这组测试的下半部分钉的就是这一条。
///
///       引擎替身照惯例回**实测原文**；**这些断言钉的是取舍，不是引擎本身**。
/// English: **equation solving: the first time the main screen asks the engine.**
///
///          **This road did not work at all before this round.** Measured: a double's `asked` list comes
///          back **empty** for `2x+1=7`, `x^2=4` and `sin(x)=0.5` — `engineExpressionFor` returned
///          `UntranslatableExpression` for any input holding an `=` (not one place in that file handled
///          the equals sign), so the engine was never asked and the screen fell to the legacy parser's
///          "unrecognised content". (`5d78d08` fixed the **paste** path; that is a different thing.)
///
///          **The engine half was measured, not guessed.** The table produced on host `qalc` 5.12.0
///          through the bridge's own call sequence with the native classifier's criterion transcribed
///          (`QalculateEngine.kt:390`) is in section 八 of
///          `.superpowers/backup/engine-capability-probe.md`: `2x+1=7` → kind `SYMBOLIC`, prints `x = 3`;
///          `x^2=4` → `x = 2 || x = -2`. **`SYMBOLIC` is exactly the branch `isDisplayable` lets
///          through**, so no native code changed.
///
///          ⚠️ **The three degenerate shapes land in `number`, and they are what this round is really
///          about.** `x^2=-1`, `1=2` and `x=x` print `0`, `0` and `1` — **all finite decimals**, while
///          the taking rule's second tier reads "a finite decimal ⇒ use it as a number". **On the old
///          road the user asks for the roots of x² = −1 and the screen answers `0`.** That is not a
///          miscalculation: it is **the engine's truth value taken for a number**. The lower half of
///          this file pins exactly that.
///
///          The engine double returns the **measured** strings, as always; **these assertions pin the
///          selection, not the engine itself.**
EngineReply _reply(String text, EngineResultKind kind) => EngineReply.success(
      MathResult(
        displayText: text,
        displayTex: '',
        decimalText: decimalTextIsFinite(text) ? text : '',
        resultKind: kind,
      ),
    );

class _StubEngine implements MathEngine {
  _StubEngine(this.reply);

  final EngineReply reply;
  final List<String> asked = [];

  @override
  Future<EngineReply> evaluate(String expression,
      {required String angleMode}) async {
    asked.add(expression);
    return reply;
  }
}

class _FakeDatabase implements AppDatabase {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

CalculatorController _controller(
  MathEngine engine, {
  Duration liveEvaluationDelay = const Duration(minutes: 10),
  Duration liveEngineFollowUpDelay = const Duration(minutes: 10),
}) =>
    CalculatorController(
      historyRepository: HistoryRepository(_FakeDatabase()),
      notesRepository: NotesRepository(_FakeDatabase()),
      settingsRepository: SettingsRepository(_FakeDatabase()),
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

void main() {
  group('解方程：引擎被问到了，答案上屏', () {
    test('`2x+1=7` 这一次引擎真的被问到了——这是本轮之前做不到的那一步', () async {
      final engine = _StubEngine(_reply('x = 3', EngineResultKind.symbolic));
      final controller = _controller(engine);

      controller.setExpression('2x+1=7');
      await controller.submit();

      // 中文：**`asked` 非空是这条测试的全部前提。** 在这之前它是空的，屏幕上是那句
      //       「存在无法识别的内容」——而引擎其实早就会解。
      // English: **a non-empty `asked` is this test's entire premise.** Before, it was empty and the
      //          screen carried "unrecognised content" — while the engine had been able to solve it all
      //          along.
      expect(engine.asked, isNotEmpty, reason: '引擎没被问到，下面那条断言就没有意义');
      expect(engine.asked.single, contains('='), reason: '送到引擎的句子里那个等号必须在');
      expect(controller.hasError, isFalse);
      expect(controller.result, 'x = 3');

      controller.dispose();
    });

    test('两个解的那一支（引擎实测原文 `x = 2 || x = -2`）也照常上屏', () async {
      final engine =
          _StubEngine(_reply('x = 2 || x = -2', EngineResultKind.symbolic));
      final controller = _controller(engine);

      controller.setExpression('x^2=4');
      await controller.submit();

      expect(engine.asked, isNotEmpty);
      expect(controller.hasError, isFalse);
      expect(controller.result, 'x = 2 || x = -2');

      controller.dispose();
    });
  });

  group('⚠️ 关系被答成了一个数 ⇒ 那是布尔值，不许上屏', () {
    // 中文：**这一组是本轮真正修掉的那个错值。** 三个实测形状，一个是"无解"、一个是"不成立"、
    //       一个是"恒等"——**它们全都印成有限十进制**，所以判据不能看文本，要看**引擎把这条关系
    //       当成了哪一类值**。这个决定写在 `_relationCameBackAsTruthValue` 一处。
    // English: **this group is the wrong value this round actually fixed.** Three measured shapes — "no
    //          solution", "false", "identity" — **all printed as finite decimals**, so the test cannot
    //          read the text; it reads **which kind of value the engine made of the relation**. That
    //          decision lives in one place, `_relationCameBackAsTruthValue`.
    for (final (source, printed) in <(String, String)>[
      ('x^2=-1', '0'),
      ('1=2', '0'),
      ('x=x', '1'),
    ]) {
      test('`$source`：引擎印 `$printed`，屏幕上是「没有解」而不是 `$printed`', () async {
        final engine = _StubEngine(_reply(printed, EngineResultKind.number));
        final controller = _controller(engine);

        controller.setExpression(source);
        await controller.submit();

        expect(controller.hasError, isTrue,
            reason: '`$source` 的 `$printed` 是布尔值，不是这次求值的答案');
        expect(controller.result, isNot(printed),
            reason: '**这一条是本轮的全部意义**：`$printed` 不许出现在结果行上');
        expect(controller.errorMessage, contains('没有解'));

        controller.dispose();
      });
    }

    test('⚠️ 反过来：普通表达式回 `0`/`1` 照旧收——旗标不许泛滥', () async {
      // 中文：**上面那三条的反面，防的是"把判据写死成 `0`/`1` 就不收"。** 那样写会顺手打死
      //       `1-1`、`2^0`、`sin(0)` 这些**真的等于 0 或 1** 的普通算式。
      //       判据问的是"这一次的输入是不是一条关系"，只有关系才套得上那一条。
      // English: **the reverse of the three above, guarding against "refuse a `0`/`1`".** Written that
      //          way it would also kill `1-1`, `2^0` and `sin(0)` — ordinary expressions that really do
      //          equal 0 or 1. The test asks "was this input a relation"; only a relation is subject to
      //          that rule.
      for (final (source, printed) in <(String, String)>[
        ('1-1', '0'),
        ('2^0', '1'),
      ]) {
        final engine = _StubEngine(_reply(printed, EngineResultKind.number));
        final controller = _controller(engine);

        controller.setExpression(source);
        await controller.submit();

        expect(controller.hasError, isFalse,
            reason: '`$source` 不是关系，它真的等于 `$printed`');
        expect(controller.result, printed);

        controller.dispose();
      }
    });
  });

  group('⚠️ 超时：设计没动，补的是"回落也读不懂"那一支', () {
    test('超时 + 旧解析器读不懂 ⇒ 说真原因，而不是「函数需要括号」', () async {
      // 中文：**这一条不推翻"超时回落旧解析器"那个设计**——它被另外三条测试钉着（名字就叫
      //       `times out and falls back`）。补的是**回落也失败**的那一支：
      //       那时屏幕上写的是旧解析器那句「函数需要括号」，而真机上量到的那个输入
      //       （`sum(1/x^2, 1, 200000, x)`）**一个括号都没错**——用户会去找一个不存在的问题。
      // English: **this does not overturn the "a timeout falls back" design** — three other tests pin it
      //          (one is literally named `times out and falls back`). What it fills in is the branch where
      //          **the fallback also fails**: there the screen carried the legacy parser's "function needs
      //          parentheses" while the input measured on a device (`sum(1/x^2, 1, 200000, x)`) **has no
      //          bracket error at all** — the user would hunt a problem that does not exist.
      final engine = _StubEngine(
          EngineReply.failure('engine_timeout: 5000ms'));
      final controller = _controller(engine);

      controller.setExpression('sum(1/x^2, 1, 200000, x)');
      await controller.submit();

      expect(controller.hasError, isTrue);
      expect(controller.errorMessage, contains('引擎没在时限内算完'));
      expect(controller.errorMessage, isNot(contains('括号')),
          reason: '**这一条是本组的全部意义**：那个式子没有括号问题');

      controller.dispose();
    });

    test('超时 + 旧解析器**读得懂** ⇒ 照旧由它作答（设计没动）', () async {
      // 中文：**反面。** `2+3` 旧解析器读得懂，所以超时之后屏幕上仍然是 `5`——
      //       与那三条既有测试断言的行为逐字相同。
      // English: **the reverse.** The legacy parser can read `2+3`, so after a timeout the screen still
      //          shows `5` — byte-for-byte the behaviour the three existing tests assert.
      final engine = _StubEngine(
          EngineReply.failure('engine_timeout: 5000ms'));
      final controller = _controller(engine);

      controller.setExpression('2+3');
      await controller.submit();

      expect(controller.hasError, isFalse);
      expect(controller.result, '5');

      controller.dispose();
    });
  });

  group('⚠️ 引擎没有单位与常数（定义没加载）：设计没动，补的是「回落也读不懂」那一支', () {
    test('定义没加载 + 旧解析器读不懂 ⇒ 说根因，而不是「存在无法识别的内容」', () async {
      // 中文：**这一条与上面超时那组同形，理由也一样。** 引擎层（`QalculateMathEngine._replyFrom`）
      //       把 `definitionsLoaded: false` 的回执判成「这一次没有引擎答案」——定义没加载时引擎照样
      //       算数，但 400 多个单位与所有常数静默消失，同一条输入会被读成**别的东西**，答案与真的
      //       没有区别（§5o）。回落**读得懂**时照旧由旧解析器作答（下一条钉它）；**回落也读不懂**时，
      //       屏幕上就不该是通用那句「存在无法识别的内容」——那句话在用户眼里是「`km` 打错了」，
      //       而真正的原因是引擎没有单位与常数。
      //
      //       表达式用的是超时那组量过的同一个 `sum(1/x^2, 1, 200000, x)`：应用自己的解析器
      //       **读得懂单位表达式**（`5 km to mi` 在它那里是一条换算），所以「旧解析器读不懂」的样本
      //       不能拿单位来举——而这个函数名在定义没加载的引擎里同样不认识（符号表是空的）。
      // English: **the same shape as the timeout group above, for the same reason.** The engine layer
      //          (`QalculateMathEngine._replyFrom`) files a `definitionsLoaded: false` receipt as "no
      //          engine answer this time" — with the definitions unloaded the engine still computes,
      //          but 400-odd units and every constant vanish silently, the same input gets read as
      //          **something else** and its answer is indistinguishable from a real one (§5o). When the
      //          fallback **can** read the expression the legacy parser answers as before (the next
      //          test pins that); when it **cannot** either, the screen must not carry the generic
      //          "unrecognised content" — which reads as "you mistyped `km`" while the real cause is
      //          that the engine has no units and constants.
      //
      //          The expression is the one the timeout group measured, `sum(1/x^2, 1, 200000, x)`:
      //          this app's own parser **does** read unit expressions (`5 km to mi` is a conversion to
      //          it), so a unit cannot serve as the "the fallback cannot read it" sample — while that
      //          function name is just as unknown to a definitions-less engine (its symbol table is
      //          empty).
      final engine = _StubEngine(
          EngineReply.failure('engine_definitions_unloaded'));
      final controller = _controller(engine);

      controller.setExpression('sum(1/x^2, 1, 200000, x)');
      await controller.submit();

      expect(controller.hasError, isTrue);
      expect(controller.errorMessage, contains('引擎没加载单位和常数'));
      expect(controller.errorMessage, isNot(contains('存在无法识别的内容')),
          reason: '**这一条是本组的全部意义**：真正的原因是引擎没有单位与常数，不是用户打错了名字');

      controller.dispose();
    });

    test('定义没加载 + 旧解析器**读得懂** ⇒ 照旧由它作答（设计没动）', () async {
      // 中文：**反面，与超时那组的反面逐字同形。** `2+3` 旧解析器读得懂，所以引擎不可用
      //       （这一次是「没有单位与常数」）之后屏幕上仍然是 `5`——引擎的失败对用户不可见，
      //       硬性边界 1 一个字没动。
      // English: **the reverse, byte-for-byte the shape of the timeout group's reverse.** The legacy
      //          parser can read `2+3`, so with the engine unavailable (this time "no units and
      //          constants") the screen still shows `5` — an engine failure stays invisible to the
      //          user; hard boundary 1 is untouched.
      final engine = _StubEngine(
          EngineReply.failure('engine_definitions_unloaded'));
      final controller = _controller(engine);

      controller.setExpression('2+3');
      await controller.submit();

      expect(controller.hasError, isFalse);
      expect(controller.result, '5');

      controller.dispose();
    });
  });

  group('那一句话本身', () {
    test('英文侧一个汉字都没有，两种语言说的是同一件事', () {
      // 中文：**这句话是这一轮新加的文案，它得和别的文案同一条规矩。**
      //       屏幕上的那句话由 `_friendlyCalculationError` 按**判据的英文原文**（`Relation has no
      //       numeric answer`）从表里取——判据与文案分家，所以这里查的是表。
      // English: **this sentence is new this round and follows the same rule as every other.** The
      //          sentence on screen is picked by `_friendlyCalculationError` from the table using the
      //          verdict's **English source text** (`Relation has no numeric answer`) — verdict and
      //          wording are separate, so this checks the table.
      final zh = CalculatorControllerStrings.forLanguage(AppLanguage.zh);
      final en = CalculatorControllerStrings.forLanguage(AppLanguage.en);

      expect(zh.friendlyRelationNoSolution, isNotEmpty);
      expect(RegExp(r'[一-鿿]').hasMatch(en.friendlyRelationNoSolution), isFalse,
          reason: '英文侧还有汉字：`${en.friendlyRelationNoSolution}`');
      expect(en.friendlyRelationNoSolution, isNot(zh.friendlyRelationNoSolution));
      // 中文：**这句话必须同时说对"无解"与"不成立"两种情形。** 实测里 `x^2=-1` 与 `1=2`
      //       给的是同一个 `0`，所以应用分不出它们——**也就不许假装分得出**。
      // English: **the sentence must be right for both "no solution" and "false".** Measured, `x^2=-1`
      //          and `1=2` give the same `0`, so the app cannot tell them apart — **and must not pretend
      //          to**.
      expect(zh.friendlyRelationNoSolution, contains('没有解'));
    });
  });

  group('⚠️ 边打边算那条路上，关系同样不许由旧解析器作答', () {
    // 中文：**这一组是真机量出来的，不是设计出来的。** 本轮在设备上跑 `x^2=-1`，
    //       结果行上写的是**旧解析器那句「函数需要括号」**——因为边打边算那一支当时对关系的处理
    //       是"回落旧解析器"，而**应用自己的语法里根本没有等号**，旧解析器对一条关系永远没有
    //       发言权。用户问「x²=−1 的解」，读到的是"我括号打错了"。
    //
    //       修法是两条路**说同一句话**：判据的原文是一个常量（`kRelationTruthValueVerdict`），
    //       翻成人话的只有 `_friendlyCalculationError` 一处。
    // English: **this group came off a device, not off a design.** Running `x^2=-1` on the hardware this
    //          round, the result line carried **the legacy parser's "function needs parentheses"** —
    //          because that as-you-type branch's handling of a relation was "fall back to the legacy
    //          parser", and **this app's grammar has no equals sign at all**, so the legacy parser never
    //          has standing on a relation. The user asks for the roots of x² = −1 and reads "I mistyped
    //          a bracket".
    //
    //          The fix makes both paths **say one sentence**: the verdict's text is a constant
    //          (`kRelationTruthValueVerdict`) and `_friendlyCalculationError` is the only place that
    //          turns it into words.
    test('`x^2=-1`：边打边算给的是「没有解」，与提交路径同一句话', () async {
      final engine = _StubEngine(_reply('0', EngineResultKind.number));
      final controller = _controller(
        engine,
        liveEvaluationDelay: const Duration(milliseconds: 1),
        liveEngineFollowUpDelay: const Duration(milliseconds: 1),
      );

      controller.setExpression('x^2=-1');
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(controller.hasError, isTrue);
      expect(controller.result, isNot('0'),
          reason: '**这一条是本轮的全部意义**：`0` 不许出现在结果行上');
      expect(controller.errorMessage, contains('没有解'));
      // 中文：**这一条钉的就是真机上量到的那句错话。** 它不许多出一个字。
      // English: **this pins the wrong sentence measured on the device.** It may not appear even once.
      expect(controller.errorMessage, isNot(contains('括号')),
          reason: '关系不许由旧解析器作答——它只会说「函数需要括号」');

      controller.dispose();
    });
  });

  group('方程组：`multisolve` 上屏，而"退回"不许上屏', () {
    // 中文：**两侧都是量出来的**（宿主 `qalc` 5.12.0，桥自己的调用序列，第九节）：
    //       `multisolve([x+y=3, x-y=1], x, y)` → `[2  1]`，kind `structured`（放行）；
    //       而无解与欠定**都**把调用原样退回、kind `SYMBOLIC`——那正是 `isDisplayable` 放行的一支。
    // English: **both sides were measured** (host `qalc` 5.12.0, the bridge's own call sequence, section
    //          九): `multisolve([x+y=3, x-y=1], x, y)` → `[2  1]`, kind `structured` (let through), while
    //          inconsistent and underdetermined **both** hand the call back with kind `SYMBOLIC` — a
    //          branch `isDisplayable` lets through.
    test('解出来的方程组：`[2  1]` 照常上屏，而且引擎收到的是 `multisolve`', () async {
      final engine = _StubEngine(_reply('[2  1]', EngineResultKind.structured));
      final controller = _controller(engine);

      controller.setExpression('x+y=3; x-y=1');
      await controller.submit();

      expect(engine.asked, isNotEmpty, reason: '方程组必须真的被问出去');
      expect(engine.asked.single, startsWith('multisolve(['));
      expect(engine.asked.single, endsWith('], x, y)'),
          reason: '未知数名单不能空：${engine.asked.single}');
      expect(controller.hasError, isFalse);
      expect(controller.result, '[2  1]');

      controller.dispose();
    });

    test('⚠️ 引擎把调用原样退回：屏幕上不许出现 `multisolve(`', () async {
      // 中文：**这一条防的是"把引擎的调用原文当成答案"**——无解与欠定都走这一支。
      // English: **this stops "the engine's own call text taken for an answer"** — both the inconsistent
      //          and the underdetermined case land here.
      // 中文：**三种种类都试**，因为真机上报的**不是**宿主报的那一个（见那段判据的注释）。
      //       判据写成"不是 `structured`/`number`"，所以它不依赖平台报哪一个。
      // English: **all three kinds**, because the device does **not** report the one the host does (see
      //          the note on that judgement). It is written as "not `structured`/`number`", so it does
      //          not depend on which one this platform reports.
      for (final (echoed, kind) in <(String, EngineResultKind)>[
        ('multisolve([(x = 1 - y)  (x = 2 - y)]; [x  y])',
            EngineResultKind.symbolic),
        ('multisolve(x = 3 - y; [x  y])', EngineResultKind.symbolic),
        ('multisolve([(x = 1 - y)  (x = 2 - y)]; [x  y])',
            EngineResultKind.arithmetic),
        ('multisolve(x = 3 - y; [x  y])', EngineResultKind.unit),
      ]) {
        final engine = _StubEngine(_reply(echoed, kind));
        final controller = _controller(engine);

        controller.setExpression('x+y=3; x-y=1');
        await controller.submit();

        expect(controller.hasError, isTrue, reason: '没解出来就不算答案');
        expect(controller.result, isNot(contains('multisolve')),
            reason: '**这一条是本组的全部意义**：${controller.result}');
        expect(controller.errorMessage, contains('没有解'));

        controller.dispose();
      }
    });

    test('⚠️ 反过来：**一条**关系回 `symbolic` 照旧收——旗标不许泛滥', () async {
      // 中文：**这是上面那条的反面，防的是"把 `symbolic` 一律挡掉"。** 一条关系合法地回
      //       `symbolic`（`2x+1=7` → `x = 3`），挡掉它就是把真答案丢了。
      //       判据问的是"这一次是不是**一组**关系"，只有 `isSystem` 才套得上。
      // English: **the reverse, guarding against "refuse every `symbolic`".** One relation legitimately
      //          returns `symbolic` (`2x+1=7` → `x = 3`), and refusing it throws away the real answer. The
      //          test asks "was this a **group**?", and only `isSystem` is subject to it.
      final engine = _StubEngine(_reply('x = 3', EngineResultKind.symbolic));
      final controller = _controller(engine);

      controller.setExpression('2x+1=7');
      await controller.submit();

      expect(controller.hasError, isFalse);
      expect(controller.result, 'x = 3');

      controller.dispose();
    });

    test('边打边算那条路同样挡住退回，同样不误伤一条关系', () async {
      final unsolved = _controller(
        _StubEngine(_reply('multisolve(x = 3 - y; [x  y])',
            EngineResultKind.symbolic)),
        liveEvaluationDelay: const Duration(milliseconds: 1),
        liveEngineFollowUpDelay: const Duration(milliseconds: 1),
      );
      unsolved.setExpression('x+y=3; x-y=1');
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(unsolved.result, isNot(contains('multisolve')));
      expect(unsolved.errorMessage, contains('没有解'));
      unsolved.dispose();

      final single = _controller(
        _StubEngine(_reply('x = 3', EngineResultKind.symbolic)),
        liveEvaluationDelay: const Duration(milliseconds: 1),
        liveEngineFollowUpDelay: const Duration(milliseconds: 1),
      );
      single.setExpression('2x+1=7');
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(single.result, 'x = 3');
      single.dispose();
    });
  });
}
