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

/// 中文：**数字记法（`FSE`）**的控制器级行为。主屏那一条（`test/features/calculator_notation_key_test.dart`）
///       证的是「按下去屏幕上出现什么」；这里证的是它**不许**发生什么——那才是这一步真正的风险：
///
///       - **`decimalText` 逐字节不变**（本轮最硬的一条：`Ans`/`last`/记忆/历史读的都是它）；
///       - 它绝不进值通路：结果行的数、`Ans`、历史都不动；
///       - 引擎失败/缺席/答的不是换算时，它一个字都不显示；
///       - 它描述的那个结果一旦不在屏幕上，它立刻不算数；
///       - **档位表里不许出现引擎给不出的档**（Fixed / Engineering SI，理由见
///         `calculator_controller_notation.dart` 的文件头）。
///
/// English: **number notation (`FSE`)** at the controller level. The screen test
///          (`test/features/calculator_notation_key_test.dart`) proves what a press puts on screen;
///          this proves what it must **not** do — which is where this step's real risk lives:
///
///          - **`decimalText` is byte-for-byte unchanged** (this round's hardest rule: `Ans`/`last`/
///            memory/history all read it);
///          - it never enters the value path: the result line, `Ans` and the history do not move;
///          - it shows not one digit when the engine fails / is absent / answers something that is
///            not a conversion;
///          - it stops counting the moment the result it describes leaves the screen;
///          - **no position may appear in the table that the engine cannot produce** (Fixed /
///            Engineering SI; the reason is on the file head of `calculator_controller_notation.dart`).
void main() {
  /// 中文：引擎对 `to sci` / `to eng` 真的会这么答（宿主 `qalc` 5.12.0，与本 AAR 同版本实测）：
  ///       `12345.6789 to sci` = `1.23456789E4`、`to eng` = `12.3456789E3`。
  /// English: what the engine really answers for `to sci` / `to eng` (measured on the host `qalc`
  ///          5.12.0, the version this AAR bundles): `12345.6789 to sci` = `1.23456789E4`, `to eng` =
  ///          `12.3456789E3`.
  const sciReply = MathResult(
    displayText: '1.23456789e+4',
    decimalText: '12345.6789',
    resultKind: EngineResultKind.conversion,
  );
  const engReply = MathResult(
    displayText: '12.3456789e+3',
    decimalText: '12345.6789',
    resultKind: EngineResultKind.conversion,
  );

  test('档位表：只有引擎给得出的三档，目标词是量出来的裸词', () {
    // 中文：**这条断言就是「不许造一个假的」的可执行形式。** 表里多出第四档，或者把 `sci`/`eng`
    //       换成引擎不认的词（`scientific` 长拼法虽然也认，但 `to sci` 是实测过的那一个），
    //       都会在这里响。
    // English: **this assertion is the executable form of "do not invent one".** A fourth position
    //          appearing in the table, or `sci`/`eng` being replaced by a word the engine does not
    //          recognise, trips here.
    expect(
      ResultNotation.values
          .map((notation) => '${notation.label}|${notation.engineWord}')
          .toList(),
      <String>['|', 'SCI|sci', 'ENG|eng'],
      reason: 'Fixed 与 Engineering SI 引擎给不出（理由在 calculator_controller_notation.dart '
          '的文件头），所以它们不在表里',
    );
  });

  test('循环：Normal → SCI → ENG → Normal，每一档问引擎一次', () async {
    final engine = _FakeMathEngine(EngineReply.success(sciReply));
    final controller = _controller(engine);
    _typeResult(controller);
    engine.calls.clear();

    expect(await controller.cycleNotation(), isNull);
    expect(controller.notation, ResultNotation.scientific);
    expect(engine.calls, <String>['(12345.6789) to sci'],
        reason: '目标词必须是裸的：加括号会被引擎按除法读（进制那边实测过），读数就成了错值');
    expect(controller.notationReadout?.label, 'SCI 1.23456789e+4');
    controller.dispose();
  });

  test('第二次按到 ENG，第三次回到 Normal 并且撤掉读数、不再问引擎', () async {
    final engine = _ScriptedEngine(<EngineReply>[
      EngineReply.success(sciReply),
      EngineReply.success(engReply),
    ]);
    final controller = _controller(engine);
    _typeResult(controller);
    engine.calls.clear();

    await controller.cycleNotation();
    expect(controller.notationReadout?.label, 'SCI 1.23456789e+4');

    await controller.cycleNotation();
    expect(controller.notation, ResultNotation.engineering);
    expect(controller.notationReadout?.label, 'ENG 12.3456789e+3');

    final message = await controller.cycleNotation();
    expect(message, isNull, reason: '回到 Normal 是常态，没有话要说');
    expect(controller.notation, ResultNotation.normal);
    expect(controller.notationReadout, isNull, reason: 'Normal 就是撤掉读数');
    expect(engine.calls, <String>['(12345.6789) to sci', '(12345.6789) to eng'],
        reason: 'Normal 不发引擎调用：结果行本来就是它');
    controller.dispose();
  });

  test('**钉住：改记法前后 `decimalText` 逐字节相同**，结果行与 Ans 读的那一份也不动', () async {
    // 中文：这是本轮最硬的一条边界。`decimalText` 是**唯一允许被数值消费者解析的字段**
    //       （`Ans`/`last`/记忆/继续使用/历史），记法**只许改写法**。这里的比较是逐字节的
    //       `equals`，不是「值差不多」。
    // English: this round's hardest boundary. `decimalText` is **the only field a numeric consumer may
    //          parse** (`Ans`/`last`/memory/continue-with/history) and notation may **only change the
    //          spelling**. The comparison here is a byte-for-byte `equals`, not "about the same value".
    final engine = _ScriptedEngine(<EngineReply>[
      EngineReply.success(sciReply),
      EngineReply.success(engReply),
    ]);
    final controller = _controller(engine);
    _typeResult(controller);

    final before = controller.resultDecimal;
    final resultBefore = controller.result;
    expect(before, '12345.6789');

    await controller.cycleNotation();
    expect(controller.resultDecimal, before, reason: 'SCI 之后十进制形态逐字节不变');
    expect(controller.result, resultBefore, reason: '结果行上的字也不动——记法不是值');
    expect(MathResult.decimalTextIsFinite(controller.resultDecimal), isTrue,
        reason: '它仍然是一个能被解析的数');

    await controller.cycleNotation();
    expect(controller.resultDecimal, before, reason: 'ENG 之后十进制形态逐字节不变');
    expect(controller.result, resultBefore);

    await controller.cycleNotation();
    expect(controller.resultDecimal, before, reason: '回到 Normal 之后同样不变');
    controller.dispose();
  });

  test('读数的写法只从 `displayText` 来，绝不从 `decimalText` 来', () async {
    // 中文：回执里两者常常**不一样**。取 `decimalText` 就等于把另一串数字请进唯一允许被解析成
    //       数字的字段——读数的安全性正是建立在「它从不经过那个字段」上（与进制读数同一条）。
    // English: the two often **differ** in a receipt. Reading `decimalText` would be inviting those
    //          digits into the one field allowed to be parsed as a number; a read-out's safety is
    //          exactly that it never passes through that field (the same rule as the base read-out).
    final engine = _FakeMathEngine(
      EngineReply.success(
        const MathResult(
          displayText: '1.23456789e+4',
          decimalText: '999',
          resultKind: EngineResultKind.conversion,
        ),
      ),
    );
    final controller = _controller(engine);
    _typeResult(controller);

    await controller.cycleNotation();

    expect(controller.notationReadout?.label, 'SCI 1.23456789e+4');
    expect(controller.notationReadout?.label, isNot(contains('999')));
    controller.dispose();
  });

  test('引擎报错时不显示任何数字，只给一句话', () async {
    final engine = _FakeMathEngine(
      EngineReply.failure('engine_error: boom'),
    );
    final controller = _controller(engine);
    _typeResult(controller);

    final message = await controller.cycleNotation();

    expect(controller.notationReadout, isNull, reason: '拿不准就 fail closed，绝不猜一个写法');
    expect(message, isNotNull);
    controller.dispose();
  });

  test('引擎答的不是一次换算时同样不显示', () async {
    final engine = _FakeMathEngine(
      EngineReply.success(
        const MathResult(
          displayText: '1.23456789e+4',
          decimalText: '12345.6789',
          resultKind: EngineResultKind.number,
        ),
      ),
    );
    final controller = _controller(engine);
    _typeResult(controller);

    expect(await controller.cycleNotation(), isNotNull);
    expect(controller.notationReadout, isNull);
    controller.dispose();
  });

  test('屏幕上没有可换记法的数值结果时不发引擎调用', () async {
    // 中文：进制读数与记法读数**都没有**「空屏幕也能读」这回事——但判据不是「表达式为空」：
    //       新控制器的结果就是 `MathResult.zero`，它的十进制形态是 `0`，那是一个有限数，
    //       所以 `(0) to sci` 会照常发生（与 `HEX 0` 同一条路）。真正被挡的是**没有十进制形态
    //       的结果**：带单位、矩阵这一类。
    // English: neither the base read-out nor the notation one refuses on an empty screen — but the
    //          test is not "the expression is empty": a fresh controller's result is `MathResult.zero`,
    //          whose decimal form is `0`, a finite number, so `(0) to sci` happens just as `HEX 0`
    //          does. What is refused is a result with **no decimal form**: a unit-carrying one, a
    //          matrix.
    final engine = _FakeMathEngine(EngineReply.success(sciReply));
    final controller = _controller(engine);
    controller.applyMathResult(
      const MathResult(
        displayText: '5 km',
        resultKind: EngineResultKind.quantity,
      ),
    );
    engine.calls.clear();

    final message = await controller.cycleNotation();

    expect(message, isNotNull);
    expect(engine.calls, isEmpty);
    expect(controller.notationReadout, isNull);
    controller.dispose();
  });

  test('往返期间用户改过输入：读数静默丢弃', () async {
    final engine = _PendingMathEngine();
    final controller = _controller(engine);
    _typeResult(controller);

    final pending = controller.cycleNotation();
    controller.setExpression('12345.6789 + 1');

    engine.release(EngineReply.success(sciReply));
    await pending;

    expect(controller.notationReadout, isNull,
        reason: '用户按下别的键之后，屏幕不该再冒出上一个问题的答案');
    controller.dispose();
  });

  test('结果被换掉之后读数立刻不算数（不经过编辑的那些替换也一样）', () async {
    final engine = _FakeMathEngine(EngineReply.success(sciReply));
    final controller = _controller(engine);
    _typeResult(controller);
    await controller.cycleNotation();
    expect(controller.notationReadout, isNotNull);

    controller.applyMathResult(
      const MathResult(
        displayText: '2',
        decimalText: '2',
        resultKind: EngineResultKind.number,
      ),
    );

    expect(controller.notationReadout, isNull,
        reason: '读数带着来源十进制形态，与新值对不上就不再描述屏幕上的东西');
    controller.dispose();
  });

  test('控制器销毁时还挂着的那一发会返回，不会永远悬着', () async {
    final engine = _PendingMathEngine();
    final controller = _controller(engine);
    _typeResult(controller);

    final pending = controller.cycleNotation();
    controller.dispose();

    await expectLater(pending, completion(isNull));
    expect(controller.notationReadout, isNull);
  });
}

void _typeResult(CalculatorController controller) {
  controller.setExpression('12345.6789');
  controller.evaluate();
  // 中文：`evaluate()` 的引擎那一发是异步的，但 `_result` 在**旧解析器**那一半就已经上屏
  //       （`legacyFirstThenEngine`），所以这里不必等引擎。为了让 `decimalText` 是引擎那一份
  //       （16 位、未经 `formatNumber` 取整），用例走的是 `applyMathResult` 之外的那条真实路径：
  //       先让控制器拿到值，再把它换成引擎那份十进制形态。
  // English: `evaluate()`'s engine leg is asynchronous, but `_result` is already on screen from the
  //          **legacy parser** half (`legacyFirstThenEngine`), so there is nothing to await here. To
  //          make `decimalText` the engine's own (16 digits, not `formatNumber`'s rounding), the test
  //          takes the real path: let the controller produce a value, then hand it the engine's
  //          decimal form.
  if (controller.resultDecimal == '12345.6789') return;
  controller.applyMathResult(
    const MathResult(
      displayText: '12345.6789',
      decimalText: '12345.6789',
      resultKind: EngineResultKind.number,
    ),
  );
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

/// 中文：按顺序回不同回执的替身——循环那几个用例要「第一发是 SCI、第二发是 ENG」。
/// English: a double that answers different receipts in order — the cycle cases need "the first call
///          is SCI, the second is ENG".
class _ScriptedEngine implements MathEngine {
  _ScriptedEngine(this.replies);

  final List<EngineReply> replies;
  final List<String> calls = <String>[];

  @override
  Future<EngineReply> evaluate(
    String expression, {
    required String angleMode,
  }) async {
    calls.add(expression);
    return replies[calls.length - 1];
  }
}

/// 中文：回包由测试决定何时到达的替身——用来构造「那一发还挂在引擎上，用户已经改了输入」那个竞态。
/// English: a double whose reply the test releases when it wants — it builds the race where the call is
///          still on the engine while the user has already edited.
class _PendingMathEngine implements MathEngine {
  final List<Completer<EngineReply>> _pending = <Completer<EngineReply>>[];

  @override
  Future<EngineReply> evaluate(
    String expression, {
    required String angleMode,
  }) {
    final completer = Completer<EngineReply>();
    _pending.add(completer);
    return completer.future;
  }

  void release(EngineReply reply) {
    _pending.removeAt(0).complete(reply);
  }
}

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
