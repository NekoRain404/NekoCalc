import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/application/controllers/calculator_controller.dart';
import 'package:nekocalc/core/math/math_engine.dart';
import 'package:nekocalc/core/math/math_result.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/repositories/history_repository.dart';
import 'package:nekocalc/data/repositories/notes_repository.dart';
import 'package:nekocalc/data/repositories/settings_repository.dart';

/// 中文：**进制读数**（`CalculatorController.showBaseReadout` 与 `baseReadout`）的控制器级行为。
///       主屏那一条端到端测试（`test/features/calculator_base_key_test.dart`）证的是「按下去屏幕上
///       出现什么」；这里证的是它**不许**发生什么——那才是这一步真正的风险所在：
///
///       - 它绝不进值通路（结果行、`decimalText`、Ans/记忆读的那一份）；
///       - 引擎失败/缺席/答的不是换算时，它一个字都不显示；
///       - 它描述的那个结果一旦不在屏幕上，它立刻不算数——**包括不经过编辑的那些替换**。
///
/// English: **the base read-out** (`CalculatorController.showBaseReadout` and `baseReadout`) at the
///          controller level. The end-to-end screen test
///          (`test/features/calculator_base_key_test.dart`) proves what a press puts on screen; this
///          proves what it must **not** do — which is where this step's real risk lives: it never
///          enters the value path (the result line, `decimalText`, what `Ans`/memory read), it shows
///          not one digit when the engine fails / is absent / answers something that is not a
///          conversion, and it stops counting the moment the result it describes leaves the screen —
///          **including the replacements that do not go through an edit**.
void main() {
  const conversion = MathResult(
    displayText: '64',
    decimalText: '64',
    resultKind: EngineResultKind.conversion,
  );

  test('四个进制各自算对，而且**根本不问引擎**', () async {
    // 中文：**这是本轮改的那一处，而它是被量出来的。** 在这之前这里问的是
    //       `'(<十进制>) to <目标词>'`——**那条路从来没有工作过**：桥走的是
    //       `Calculator::calculate(...)`，而那个入口把结尾的 `to` 当成一次除法。
    //       所以 `engine.calls` 为空不是"顺手省了一次调用"，**它就是修复本身**。
    // English: **this is the one thing this round changed, and it was measured.** Before, this asked
    //          `'(<decimal>) to <target word>'` — **a road that never worked**: the bridge goes through
    //          `Calculator::calculate(...)`, which reads a trailing `to` as a division. So an empty
    //          `engine.calls` is not "one call saved by the way": **it is the fix.**
    for (final (base, digits) in const [
      (CalculatorBase.bin, '1100100'),
      (CalculatorBase.oct, '144'),
      (CalculatorBase.hex, '64'),
    ]) {
      final engine = _FakeMathEngine(EngineReply.failure('engine_no_decimal'));
      final controller = _controller(engine);
      _typeHundred(controller);
      engine.calls.clear();

      final message = await controller.showBaseReadout(base);

      expect(message, isNull, reason: '算得出来时没有话要说');
      expect(engine.calls, isEmpty,
          reason: '进制换算是纯函数，一次引擎调用都不该发');
      expect(controller.baseReadout?.digits, digits,
          reason: '`${base.label}` 的数位应当是独立实现给的那一串');
      controller.dispose();
    }
  });

  test('用的是**十进制形态**，不是取整过的显示文本', () async {
    // 中文：屏幕上的 `0.333333` 是 `formatNumber` 按精度取整的结果，而这次求值的值是
    //       `0.3333333333333333`（`Ans` 用的就是它）。拿显示文本去换算，得到的是**另一个数**
    //       的进制写法——一个看着像答案、其实不是这个结果的读数。
    //       这一条在改成自己算之后**照样成立**：`convertToBase` 吃的就是 `decimalText`。
    // English: the `0.333333` on screen is `formatNumber`'s rounding at the user's precision, while
    //          the value of this evaluation is `0.3333333333333333` (what `Ans` reads). Converting the
    //          display text would give **another number**'s digits — a read-out that looks like an
    //          answer and is not this result's. The test **still holds** after the change to computing
    //          it here: `convertToBase` is fed `decimalText`.
    final controller = _controller(_FakeMathEngine(EngineReply.failure('unused')));
    // 中文：**两步分开摆**：显示文本是取整过的 `0.333333`，十进制形态是 `0.3333333333333333`。
    //       这正是真机上引擎回执的样子（`formatNumber` 只管显示那一份）。
    // English: **the two are set apart on purpose**: the display text is the rounded `0.333333` and the
    //          decimal form is `0.3333333333333333`, which is what an engine receipt looks like on a
    //          device (`formatNumber` only touches the display copy).
    controller.applyMathResult(const MathResult(
      displayText: '0.333333',
      decimalText: '0.3333333333333333',
      resultKind: EngineResultKind.number,
    ));
    expect(controller.resultDecimal, '0.3333333333333333',
        reason: '前置条件：十进制形态比显示文本长');
    expect(controller.result, isNot('0.3333333333333333'),
        reason: '前置条件：显示文本是取整过的');

    await controller.showBaseReadout(CalculatorBase.hex);

    expect(controller.baseReadout?.sourceDecimal, '0.3333333333333333');
    expect(controller.baseReadout?.digits, isNot('0.555555'),
        reason: '按显示文本算会得到另一个数的写法');
    controller.dispose();
  });

  test('DEC 不发引擎调用：它就是撤掉读数', () async {
    final engine = _FakeMathEngine(EngineReply.success(conversion));
    final controller = _controller(engine);
    _typeHundred(controller);

    await controller.showBaseReadout(CalculatorBase.hex);
    expect(controller.baseReadout?.label, 'HEX 64');

    engine.calls.clear();
    final message = await controller.showBaseReadout(CalculatorBase.dec);

    expect(message, isNull);
    expect(controller.baseReadout, isNull);
    expect(engine.calls, isEmpty, reason: '结果行本来就是十进制，不必问引擎');
    controller.dispose();
  });

  test('**读数不进值通路**：引擎回 `decimal = 64`，结果与 Ans 仍然是 100', () async {
    // 中文：这一条是本设计的存在理由。真实的回执里 `100 to hex` 的 `decimal` 就是 `64`，而
    //       `decimalTextIsFinite('64')` 为真——只要那串数字走进结果，`Ans` 就会从
    //       100 变成 64，没有任何异常、没有任何提示。
    // English: this is why the design exists. In a real receipt `100 to hex` carries `decimal = 64`,
    //          and `decimalTextIsFinite('64')` is true — the moment those digits enter the
    //          result, `Ans` turns from 100 into 64 with nothing thrown and nothing said.
    final engine = _FakeMathEngine(
      EngineReply.success(conversion),
    );
    final controller = _controller(engine);
    _typeHundred(controller);

    await controller.showBaseReadout(CalculatorBase.hex);

    expect(controller.baseReadout?.label, 'HEX 64');
    expect(controller.result, '100', reason: '结果行');
    expect(controller.resultDecimal, '100', reason: '十进制形态：Ans/last、记忆、继续使用');
    expect(controller.reusableResult, '100', reason: 'Ans 引用的就是它');
    expect(controller.canContinueWithResult, isTrue);
    controller.dispose();
  });

  test('读数里的数字取自 displayText，不是 decimalText', () async {
    // 中文：`255 to hex` 的真实回执是 `display = FF` 而 `decimalText` 判不出有限数（留空）。
    //       取错字段的实现在这里会得到一个空读数——而不是 `FF`。
    // English: the real receipt for `255 to hex` is `display = FF` while `decimalText` is left empty
    //          (not a finite number). An implementation reading the wrong field gets an empty
    //          read-out here rather than `FF`.
    final engine = _FakeMathEngine(
      EngineReply.success(
        const MathResult(
          displayText: 'FF',
          resultKind: EngineResultKind.conversion,
        ),
      ),
    );
    final controller = _controller(engine);
    controller.setExpression('255');
    controller.evaluate();

    await controller.showBaseReadout(CalculatorBase.hex);

    expect(controller.baseReadout?.label, 'HEX FF');
    controller.dispose();
  });

  test('没有可换算的十进制形态：不给数字，给一句话', () async {
    // 中文：**这一条原本叫「引擎答不出来」，现在引擎已经不在那条路上了。** 它守的东西没变——
    //       「算不出来时屏幕上不许出现数字，只许出现一句话」——只是"算不出来"的来源从引擎
    //       换成了 `convertToBase` 回 `null`。下面这条走的是**前置判据**那一支
    //       （`!source.hasFiniteDecimal`），它与 `convertToBase` 回 null 那一支是两道不同的闸。
    // English: **this used to be called "the engine cannot answer"; the engine is no longer on that
    //          road.** What it guards is unchanged — "when it cannot be computed no digits may appear
    //          on screen, only a sentence" — only the source of "cannot" moved from the engine to
    //          `convertToBase` returning `null`. This one drives the **prior judgement**
    //          (`!source.hasFiniteDecimal`), which is a different gate from the `null` one.
    final controller = _controller(_FakeMathEngine(EngineReply.failure('unused')));
    controller.setExpression('2+');
    controller.evaluate();
    expect(controller.hasError, isTrue, reason: '前置条件：这一次求值是错的');

    final message = await controller.showBaseReadout(CalculatorBase.hex);

    expect(message, isNotNull);
    expect(controller.baseReadout, isNull);
    controller.dispose();
  });


  test('没有可换算的十进制形态时，连引擎都不问', () async {
    final engine = _FakeMathEngine(EngineReply.failure('engine_no_decimal'));
    final controller = _controller(engine);
    // 中文：`2+` 让旧解析器报错，结果行是错误文案，没有十进制形态。
    // English: `2+` makes the legacy parser error out; the result line is then an error message with
    //          no decimal form.
    controller.setExpression('2+');
    controller.evaluate();
    expect(controller.hasError, isTrue, reason: '前置条件：这一次求值是错的');
    engine.calls.clear();

    final message = await controller.showBaseReadout(CalculatorBase.hex);

    expect(message, isNotNull);
    expect(controller.baseReadout, isNull);
    expect(engine.calls, isEmpty, reason: '没有东西可换算，不该白问一次');
    controller.dispose();
  });

  test('编辑之后读数不再算数', () async {
    final engine = _FakeMathEngine(EngineReply.success(conversion));
    final controller = _controller(engine);
    _typeHundred(controller);

    await controller.showBaseReadout(CalculatorBase.hex);
    expect(controller.baseReadout, isNotNull);

    controller.input('7');
    controller.evaluate();

    expect(controller.baseReadout, isNull,
        reason: '屏幕上那个数已经不是 100 了');
    controller.dispose();
  });

  test('编辑之后读数不会自己回来：就算结果又变回同一个数', () async {
    // 中文：读数是**一次按键的结果**，不是「结果的一个属性」。用户改过输入之后，它就结束了——
    //       哪怕删掉刚敲的那个字、结果又变回 100，读数也不该自己复活（否则它看起来像是屏幕上的
    //       一个常驻属性，而它其实描述的是很久以前的那一次按键）。这一条由「代际」判据保证：
    //       十进制形态判据在这里是**通过**的（两边都是 100）。
    // English: a read-out is **the result of one press**, not a property of the result. Once the user
    //          has edited, it is over — even if deleting the new digit brings the result back to 100,
    //          it must not come back to life (which would make it look like a permanent property of
    //          the screen rather than the record of a press long ago). The **generation** judgement
    //          guarantees this: the decimal-form judgement *passes* here (both sides are 100).
    final engine = _FakeMathEngine(EngineReply.success(conversion));
    final controller = _controller(engine);
    _typeHundred(controller);

    await controller.showBaseReadout(CalculatorBase.hex);
    expect(controller.baseReadout, isNotNull);

    controller.input('7');
    controller.evaluate();
    controller.backspace();
    controller.evaluate();

    expect(controller.resultDecimal, '100', reason: '前置条件：结果又变回 100');
    expect(controller.baseReadout, isNull, reason: '读数不该复活');
    controller.dispose();
  });

  test('**结果被换掉（不经过编辑）时读数立刻不算数**', () async {
    // 中文：引擎跟进落地（`_adoptEngineResult`）与 `applyMathResult` 都会换掉结果而**不动代际**。
    //       少了「来源十进制形态」这道判据，一个描述旧值的读数会继续挂在屏幕上，而它旁边就是
    //       新值——屏幕上于是同时有两个互相矛盾的数字。
    // English: the engine follow-up landing (`_adoptEngineResult`) and `applyMathResult` both replace
    //          the result **without moving the generation**. Without the "source decimal" judgement, a
    //          read-out describing the old value would stay on screen next to the new one, and the
    //          screen would carry two contradictory numbers at once.
    final engine = _FakeMathEngine(EngineReply.success(conversion));
    final controller = _controller(engine);
    _typeHundred(controller);

    await controller.showBaseReadout(CalculatorBase.hex);
    expect(controller.baseReadout, isNotNull);

    controller.applyMathResult(MathResult.legacy('999'));

    expect(controller.baseReadout, isNull,
        reason: '读数说的是 100，屏幕上现在是 999：它已经不算数了');
    controller.dispose();
  });


  test('位数超过上限时截断，且截断看得见', () async {
    // 中文：**`100` 那种三位数根本到不了上限**，所以这一条要一个真够大的值：
    //       1e30 的十六进制是 **25 位**，20 位预算装不下。截断处必须留下 `…`——
    //       一个被截短而没有任何标记的多位数就是屏幕上的错值。
    // English: **a three-digit `100` never reaches the cap**, so this one needs a value that is really
    //          big: 1e30 is **25 hex digits** and does not fit a budget of 20. The cut must leave a
    //          `…` — a truncated multi-digit number with no mark on it is a wrong value on screen.
    final controller = _controller(_FakeMathEngine(EngineReply.failure('unused')));
    controller.applyMathResult(const MathResult(
      displayText: '1e+30',
      decimalText: '1E30',
      resultKind: EngineResultKind.number,
    ));

    await controller.showBaseReadout(CalculatorBase.hex);

    expect(controller.baseReadout?.digits, 'C9F2C9CD04674EDEA40…');
    expect(controller.baseReadout?.digits.length, 20,
        reason: '上限就是上限，`…` 也占一位');
    controller.dispose();
  });

}

void _typeHundred(CalculatorController controller) {
  controller.setExpression('100');
  controller.evaluate();
}

CalculatorController _controller(MathEngine engine) {
  return CalculatorController(
    historyRepository: HistoryRepository(_FakeDatabase()),
    notesRepository: NotesRepository(_FakeDatabase()),
    settingsRepository: SettingsRepository(_FakeDatabase()),
    settings: const AppSettings(
      haptics: false,
      hapticStrength: '标准',
      restoreState: false,
      autoSaveHistory: false,
      angleMode: 'RAD',
      precision: 6,
      themeModeLabel: '跟随系统',
      expressionDisplayMode: '数学符号',
      groupThousands: false,
    ),
    engine: engine,
    // 中文：边打边算那一发引擎跟进排到很远的将来——这里考的是按键那一发，不是打字那一发。
    // English: the as-you-type engine follow-up is pushed far into the future — the subject here is
    //          the press, not the typing.
    liveEngineFollowUpDelay: const Duration(hours: 1),
    liveEvaluationDelay: const Duration(hours: 1),
  );
}

class _FakeMathEngine implements MathEngine {
  _FakeMathEngine(this.reply);

  final EngineReply reply;
  final List<String> calls = <String>[];

  @override
  Future<EngineReply> evaluate(
    String expression, {
    required String angleMode,
  }) async {
    calls.add(expression);
    return reply;
  }
}

/// 中文：回包由测试决定何时到达的替身——用来构造「换算还挂在引擎上，用户已经改了输入」那个竞态，
///       以及「控制器销毁时那一发还挂着」。
/// English: a double whose reply the test releases when it wants — it builds the race where a
///          conversion is still on the engine while the user has already edited, and the case where
///          a call is still outstanding when the controller is disposed.

class _FakeDatabase implements AppDatabase {
  @override
  Future<Map<String, String>> settings() async => const {};

  @override
  Future<void> setSettings(Map<String, String> values) async {}

  @override
  Future<void> setSetting(String key, String value) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
