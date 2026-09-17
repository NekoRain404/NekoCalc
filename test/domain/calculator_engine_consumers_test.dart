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
import 'package:nekocalc/domain/usecases/calculator_save_result.dart';

// 中文：最后两个还走在旧解析器上的消费者（步骤 4）：`saveToNote()` 与 `_currentNumericValue()`
//       （`M+` / `M-` 用它）。
//
//       两者现在都从**引擎结果**取值，并且沿用既有那一处判定（`MathResult` 里的
//       `hasFiniteDecimal` / `decimalValueOf` / `decimalValue`）。这里钉住三件事：
//
//       1. 保存笔记不再把引擎算出的结果覆盖掉（结果行不会在保存后翻脸，笔记里写的也是引擎那一份）；
//       2. `M+` 取的是**屏幕上的那个值**，不是拿同一个表达式再算一遍——`0.1+0.2` 在 16 位有效数字
//          的引擎下是 `0.3`，而重新跑一遍旧解析器会得到 `0.30000000000000004`；
//       3. 引擎答不出来时（没有原生侧、超时、答不出有限的十进制）两者照旧回落旧解析器——回落是
//          硬要求，对用户完全不可见。
//
//       引擎这里全部用测试替身，不需要设备。
// English: The last two consumers still running on the legacy parser (step 4): `saveToNote()` and
//          `_currentNumericValue()` (used by `M+` / `M-`).
//
//          Both now take the value from the **engine's result** and reuse the one existing judgement
//          (`hasFiniteDecimal` / `decimalValueOf` / `decimalValue` over `MathResult`). Three things
//          are pinned here:
//
//          1. saving a note no longer overwrites what the engine computed (the result line does not
//             flip after the save, and the note carries the engine's value);
//          2. `M+` takes **the value on screen** rather than re-deriving it from the same expression —
//             `0.1+0.2` is `0.3` under the 16-significant-digit engine, while re-running the legacy
//             parser yields `0.30000000000000004`;
//          3. when the engine cannot answer (no native side, timeout, no finite decimal) both fall
//             back to the legacy parser exactly as before — the fallback is a hard requirement and
//             is invisible to the user.
//
//          The engine is a test double throughout; no device is involved.

const engineDecimal = '5.656854249492380';
const engineTex = r'4\times \sqrt{2}';

EngineReply sqrt32Reply() => EngineReply.success(
      const MathResult(
        displayText: engineDecimal,
        displayTex: engineTex,
        decimalText: engineDecimal,
      ),
    );

void main() {
  group('保存笔记走引擎结果', () {
    test('引擎算出的结果不会被旧解析器覆盖，笔记里写的也是它', () async {
      // 中文：`2^2000` 是这条测试最好的判别器——引擎算得出一个**有限值**，而旧解析器只会抛
      //       「结果不是有限数值」。所以：修好之前，这一步会返回 `invalidExpression` 并且一条笔记
      //       都不写；修好之后，保存成功、笔记里写的就是引擎那个值，**结果行在保存之后也没有翻脸**。
      // English: `2^2000` is the sharpest discriminator here — the engine computes a **finite** value
      //          while the legacy parser can only throw "result is not finite". Before the fix this
      //          step returned `invalidExpression` and wrote no note at all; after it, the save
      //          succeeds, the note carries the engine's value, and the result line does **not** flip
      //          when the button is pressed.
      const huge = '1.148130695274255e+602';
      final db = _FakeDatabase();
      final engine = _FakeMathEngine(EngineReply.success(
        const MathResult(
          displayText: huge,
          displayTex: r'\num{1.148130695274255e602}',
          decimalText: huge,
        ),
      ));
      final controller = _controller(db, engine: engine);

      controller.setExpression('2^2000');
      final saved = await controller.saveToNote();

      expect(saved.status, CalculatorSaveNoteStatus.saved);
      expect(engine.calls.single.expression, '2^2000');
      expect(controller.result, huge);
      expect(controller.resultDecimal, huge);
      expect(controller.hasError, isFalse);
      expect(db.savedNotes, hasLength(1));
      expect(db.savedNotes.single.body, contains('结果: $huge'));

      controller.dispose();
    });

    test('保存笔记问的是引擎，结果带的是引擎那一份十进制形态', () async {
      // 中文：真机上 `sqrt(32)` 的引擎答案是 16 位有效数字 `5.656854249492380`，而旧解析器只给得出
      //       `5.656854`（也是 `formatNumber` 取整后的显示形态）。两者在**十进制形态**上不同，所以
      //       `resultDecimal` 能证明保存走的是谁。
      // English: on a device the engine's answer for `sqrt(32)` is the 16-significant-digit
      //          `5.656854249492380` while the legacy parser only produces `5.656854` (which is also
      //          the display form `formatNumber` rounds to). The two differ in the **decimal form**,
      //          so `resultDecimal` says which one the save went through.
      final db = _FakeDatabase();
      final engine = _FakeMathEngine(sqrt32Reply());
      final controller = _controller(db, engine: engine);

      controller.setExpression('sqrt(32)');
      final saved = await controller.saveToNote();

      expect(saved.status, CalculatorSaveNoteStatus.saved);
      expect(engine.calls, hasLength(1));
      expect(engine.calls.single.expression, 'sqrt(32)');
      expect(controller.resultDecimal, engineDecimal);
      expect(controller.resultTex, engineTex);

      controller.dispose();
    });

    test('引擎答不出来时照旧回落旧解析器，保存仍然成功', () async {
      final db = _FakeDatabase();
      final controller = _controller(db, engine: _FailingMathEngine());

      controller.setExpression('8*9');
      final saved = await controller.saveToNote();

      expect(saved.status, CalculatorSaveNoteStatus.saved);
      expect(controller.result, '72');
      expect(db.savedNotes.single.body, contains('结果: 72'));

      controller.dispose();
    });

    test('保存期间表达式被改掉时，结果不落地、笔记也不写', () async {
      // 中文：引擎往返是**异步**的，这是保存笔记这一步新引入的窗口。往返期间用户改了输入，那一次
      //       回答描述的就是一条已经不在屏幕上的时间线——与提交路径同一条规则。
      // English: the engine round trip is **asynchronous**, and that window is new to this step. If
      //          the user edits during it, that answer describes a timeline that is no longer on
      //          screen — the same rule the submit path follows.
      final db = _FakeDatabase();
      final engine = _DeferredMathEngine();
      final controller = _controller(db, engine: engine);

      controller.setExpression('sqrt(32)');
      final pending = controller.saveToNote();
      controller.setExpression('sqrt(32)+1');

      engine.answer(sqrt32Reply());
      final saved = await pending;

      expect(saved.status, CalculatorSaveNoteStatus.superseded);
      expect(saved.saved, isFalse);
      expect(db.savedNotes, isEmpty);

      controller.dispose();
    });
  });

  group('M+ / M- 取屏幕上的那个值', () {
    test('寄存器加的是引擎算出的那个值，不是同一个表达式重算一遍', () async {
      final controller = _controller(_FakeDatabase(), engine: _FailingMathEngine());

      controller.setExpression('0.1+0.2');
      // 中文：引擎的十进制形态是 `0.3`（`qalc` 5.12.0 实测），而 `0.1+0.2` 在 double 下是
      //       `0.30000000000000004`。两个数在 double 层面**不相等**，所以这一条能分辨寄存器里
      //       加进去的是哪一份——旧实现（无条件重跑旧解析器）会加后面那个。
      // English: the engine's decimal form is `0.3` (measured with `qalc` 5.12.0) while `0.1+0.2` is
      //          `0.30000000000000004` in doubles. The two are **not** equal as doubles, so this
      //          tells which one went into the register — the old implementation (unconditionally
      //          re-running the legacy parser) added the latter.
      controller.applyMathResult(const MathResult(
        displayText: '0.3',
        displayTex: '0.3',
        decimalText: '0.3',
      ));

      controller.memoryAdd();

      expect(controller.memoryValue, 0.3);
      expect(controller.memoryValue, isNot(0.1 + 0.2));

      controller.memorySubtract();
      expect(controller.memoryValue, 0.0);

      controller.dispose();
    });

    test('引擎结果放不进 double 时寄存器一动不动，不会加一个 0 进去', () async {
      // 中文：`2^-2000 ≈ 8.7e-603`。旧实现里旧解析器自己就把它算成了 `0.0`（下溢），于是「加 0」
      //       悄悄发生；现在判定的是结果里那串**文本**，下溢在那里看得出来，于是寄存器不被改动。
      //       （两种做法对寄存器都是值中性的，区别在于这里不再把一个错值当作真值收下。）
      // English: `2^-2000 ≈ 8.7e-603`. Under the old implementation the legacy parser turned it into
      //          `0.0` on its own (underflow) and "add zero" happened quietly; the judgement is now
      //          made on the result's **text**, where the underflow is visible, so the register is
      //          left alone. (Both are value-neutral for the register; the difference is that a
      //          wrong value is no longer taken as real.)
      final controller = _controller(_FakeDatabase(), engine: _FailingMathEngine());
      controller.memoryAdd();
      final before = controller.memoryValue;
      expect(before, 0);

      controller.setExpression('2^-2000');
      controller.applyMathResult(const MathResult(
        displayText: '8.709809816217217e-603',
        displayTex: r'\num{8.709809816217217e-603}',
        decimalText: '8.709809816217217e-603',
      ));

      controller.memoryAdd();
      expect(controller.memoryValue, before);

      controller.dispose();
    });

    test('引擎没有参与时 M+ 仍然走旧解析器', () async {
      final controller = _controller(_FakeDatabase(), engine: _FailingMathEngine());

      controller.setExpression('6×7');
      controller.memoryAdd();

      expect(controller.memoryValue, 42);

      controller.dispose();
    });
  });
}

CalculatorController _controller(
  _FakeDatabase db, {
  required MathEngine engine,
  Duration engineTimeout = const Duration(seconds: 5),
  Duration liveEvaluationDelay = const Duration(minutes: 10),
  Duration liveEngineFollowUpDelay = const Duration(minutes: 10),
}) {
  return CalculatorController(
    historyRepository: HistoryRepository(db),
    notesRepository: NotesRepository(db),
    settingsRepository: SettingsRepository(db),
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
    engineTimeout: engineTimeout,
    liveEvaluationDelay: liveEvaluationDelay,
    liveEngineFollowUpDelay: liveEngineFollowUpDelay,
  );
}

/// 中文：立刻回话的替身，记下每次调用的表达式。
/// English: A double that answers at once, recording every call's expression.
class _FakeMathEngine implements MathEngine {
  _FakeMathEngine(this.reply);

  final EngineReply reply;
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

/// 中文：**从不**给可用结果的替身——代表「没有原生侧」这种常态（桌面、单元测试），也是回落分支
///       的驱动方式。
/// English: A double that **never** produces a usable result — the normal state with no native side
///          (desktop, unit tests), and what drives the fallback branch.
class _FailingMathEngine implements MathEngine {
  @override
  Future<EngineReply> evaluate(
    String expression, {
    required String angleMode,
  }) async =>
      EngineReply.failure('missing_plugin: no native side');
}

/// 中文：回话时机由测试掌握的替身，用来把「往返期间用户改了输入」这件事排出来。
/// English: A double whose reply the test controls, so that "the user edited during the round trip"
///          can be staged.
class _DeferredMathEngine implements MathEngine {
  final _pending = <Completer<EngineReply>>[];

  @override
  Future<EngineReply> evaluate(
    String expression, {
    required String angleMode,
  }) {
    final completer = Completer<EngineReply>();
    _pending.add(completer);
    return completer.future;
  }

  /// 中文：给每一次还在飞的调用都发同一条回执。
  /// English: Hand the same receipt to every call still in flight.
  void answer(EngineReply reply) {
    for (final completer in _pending) {
      if (!completer.isCompleted) completer.complete(reply);
    }
    _pending.clear();
  }
}

class _SavedNote {
  const _SavedNote(this.title, this.body, this.description);

  final String title;
  final String body;
  final String description;
}

class _FakeDatabase implements AppDatabase {
  final savedNotes = <_SavedNote>[];
  final savedSettings = <String, String>{};

  @override
  Future<int> addNote(String title, String body,
      {String description = '', List<String> tags = const []}) async {
    savedNotes.add(_SavedNote(title, body, description));
    return savedNotes.length;
  }

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
