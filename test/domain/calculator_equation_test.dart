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
      for (final echoed in <String>[
        'multisolve([(x = 1 - y)  (x = 2 - y)]; [x  y])',
        'multisolve(x = 3 - y; [x  y])',
      ]) {
        final engine = _StubEngine(_reply(echoed, EngineResultKind.symbolic));
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
