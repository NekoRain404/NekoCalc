import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/application/controllers/calculator_controller.dart';
import 'package:nekocalc/core/math/math_engine.dart';
import 'package:nekocalc/core/math/math_result.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/repositories/history_repository.dart';
import 'package:nekocalc/data/repositories/notes_repository.dart';
import 'package:nekocalc/data/repositories/settings_repository.dart';

/// 中文：**单位那三类「静默错值」的钉子。** 三类都是在引擎里实测出来的（宿主 libqalculate
///       5.12.0，按桥的调用序列 `unlocalizeExpression` → `calculate` → `print`，精度 16、
///       `INTERVAL_DISPLAY_MIDPOINT`、`comma_as_separator=false`、`mixed_units_conversion=NONE`），
///       三者的共同点是**引擎不报错、不警告、消息队列是空的**——所以判据不能建在
///       `drainMessages` 上，只能建在「这个结果配不配当答案」那一处（[MathResult.isDisplayable]）。
///       这个文件钉住的是**屏幕上的取值**，不是内部标志：每一条都断言用户看到的是错误、
///       而不是那个数字。
///
/// English: **Pins for the three "silent wrong values" in unit handling.** All three were measured in
///          the engine (host libqalculate 5.12.0 through the bridge's call sequence
///          `unlocalizeExpression` → `calculate` → `print`, precision 16,
///          `INTERVAL_DISPLAY_MIDPOINT`, `comma_as_separator=false`, `mixed_units_conversion=NONE`),
///          and what they share is that the engine **does not error, does not warn and leaves the
///          message queue empty** — so the judgement cannot be built on `drainMessages`; it can only
///          be built on the one place that answers "is this result fit to be an answer"
///          ([MathResult.isDisplayable]). What this file pins is the **value on screen**, not an
///          internal flag: every case asserts that the user sees an error rather than that number.
void main() {
  group('静默错值一：`5 km to kg` —— 换算没发生，然而引擎把它当成了答案', () {
    test('引擎报「换算没发生」时，屏幕上没有那个 `5 km`，只有一条错误', () async {
      // 中文：**样本表达式故意与回执不对应。** 这条测的是**取舍本身**：`_selectEngineResult` 只看
      //       回执的形状，不看被问的是哪一串，所以拿一个引擎一定答得出来的表达式（`2+2`）配一条
      //       实测出来的 `5 km to kg` 回执，才能精确地落在这一支上——这与本仓库既有的
      //       「矩阵回执配 `sqrt(8)`」是同一个手法。
      //
      //       回执的三个字段逐字来自宿主实测：`5 km to kg` 的 decimal 是 `5 km`、latex 是
      //       `\qty{5}{\km}`、`to_struct` 非空（所以原生侧先报 conversion）——而把它除以 `kg`
      //       再求值剩下 `5 m/g`，于是原生侧改报 `unit_mismatch`。
      // English: **The sample expression deliberately does not match the reply.** What this tests is
      //          **the selection itself**: `_selectEngineResult` reads the reply's shape, not which
      //          string was asked, so pairing an expression the engine will certainly answer
      //          (`2+2`) with a measured `5 km to kg` receipt is what lands exactly on this branch —
      //          the same device this repository already uses for "a matrix receipt for `sqrt(8)`".
      //
      //          The receipt's three fields are verbatim from the host: for `5 km to kg` the decimal
      //          is `5 km`, the latex `\qty{5}{\km}`, and `to_struct` is defined (so the native side
      //          first reports `conversion`) — but dividing it by `kg` and evaluating leaves `5 m/g`,
      //          so the native side reports `unit_mismatch` instead.
      final engine = _FakeMathEngine(
        const EngineReplyFixture(
          displayText: '5 km',
          displayTex: r'\qty{5}{\km}',
          kind: EngineResultKind.unitMismatch,
        ).reply,
      );
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('2+2');
      final submitted = await controller.submit();

      expect(controller.hasError, isTrue, reason: '换算没发生就是一条错误');
      expect(controller.result, isNot(contains('5 km')),
          reason: '引擎原样退回来的输入不是答案');
      expect(controller.result, '单位不匹配：这两个单位不能互相换算');
      expect(submitted.submitted, isFalse);

      controller.dispose();
    });

    test('`unit_mismatch` 与 `unit` 一样不可显示，且没有十进制形态', () {
      const result = MathResult(
        displayText: '5 km',
        decimalText: '',
        resultKind: EngineResultKind.unitMismatch,
      );
      expect(result.isDisplayable, isFalse);
      expect(result.hasFiniteDecimal, isFalse);
    });

    test('`conversion` 仍然可显示——上面那条没有把成功的换算一起关掉', () {
      // 中文：这一条是上一条的对照组：`5 km to mi` 实测给 `3.106855961186670 mi`（关掉混合单位
      //       之后，见 `QalculateEngine.evaluationOptions`），它必须照样上屏。
      // English: the control for the test above: `5 km to mi` measures `3.106855961186670 mi` (with
      //          mixed units off; see `QalculateEngine.evaluationOptions`) and must still be shown.
      const result = MathResult(
        displayText: '3.106855961186670 mi',
        resultKind: EngineResultKind.conversion,
      );
      expect(result.isDisplayable, isTrue);
    });
  });

  group('静默错值二：`5 zorkmid` —— 不存在的单位返回一个看似合理的值', () {
    test('引擎根本没被问到，屏幕上也没有那个 `5E-21 B`', () async {
      // 中文：宿主实测 `5 zorkmid` 给 `5E-21 B`——引擎把 `z` 当成了前缀（zepto）。它**不报错**，
      //       所以拦下它的不能是引擎的报错，只能是输入那一层：`zorkmid` 不是应用能插进表达式的
      //       名字，翻译层因此在问引擎**之前**就拒绝了（`engineExpressionFor` → `_variable` →
      //       `AppEngineVocabulary.variableUnknownToEngine`）。
      //
      //       这条断言的是**引擎一次都没被问到**（替身配的正是那个实测错值，问到了就会上屏），
      //       以及用户拿到的是错误。
      // English: measured on the host, `5 zorkmid` gives `5E-21 B` — the engine reads `z` as a prefix
      //          (zepto). It **does not error**, so what stops it cannot be an engine error; it has to
      //          be the input layer: `zorkmid` is not a name this app can insert, so the translation
      //          refuses it **before** the engine is asked (`engineExpressionFor` → `_variable` →
      //          `AppEngineVocabulary.variableUnknownToEngine`).
      //
      //          What this asserts is that the engine was **never asked** (the double is loaded with
      //          exactly that measured wrong value, so asking would put it on screen) and that the
      //          user gets an error.
      final engine = _FakeMathEngine(
        const EngineReplyFixture(
          displayText: '5E-21 B',
          displayTex: r'\qty{5e-21}{B}',
          kind: EngineResultKind.unit,
        ).reply,
      );
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('5 zorkmid');
      final submitted = await controller.submit();

      expect(engine.calls, isEmpty,
          reason: '不在应用词汇里的自由变量不该送到引擎去猜');
      expect(controller.hasError, isTrue);
      expect(controller.result, isNot(contains('5E-21')));
      expect(submitted.submitted, isFalse);

      controller.dispose();
    });
  });

  group('静默错值三：`5 km + 3 s` —— 量纲不同却相加，引擎原样退回来', () {
    test('真的提交 `5 km + 3 s`：屏幕上是一条错误，不是那个没算出来的算式', () async {
      // 中文：宿主实测 `5 km + 3 s` 的 decimal **逐字就是输入本身**，种类是 `unit`（结果带单位），
      //       消息队列空——所以引擎给的是一个「看起来像答案」的东西，而它其实什么都没算。
      //
      //       **`km` 与 `s` 现在是应用自己的单位表里的名字**（`CONV` 面板能插进去，见
      //       `app_unit_catalog.dart`），所以这一条路**真的会问到引擎**——这正是这条错值从「够不着」
      //       变成「够得着」的那一步，判据必须在这里站住。替身配的是那条实测回执，断言的是：
      //       引擎答了、而它那串文本**没有上屏**，用户拿到的是一条错误。
      // English: measured on the host, the decimal for `5 km + 3 s` **is the input verbatim**, the kind
      //          is `unit` (the result carries a unit) and the message queue is empty — so the engine
      //          hands over something that looks like an answer while having computed nothing.
      //
      //          **`km` and `s` are now names in this app's own unit table** (the `CONV` sheet can
      //          insert them; see `app_unit_catalog.dart`), so this route **really does reach the
      //          engine** — that is the step that turns this wrong value from "out of reach" into "in
      //          reach", and the judgement has to hold here. The double holds the measured receipt, and
      //          what this asserts is: the engine answered, its text **did not land on screen**, and the
      //          user got an error.
      final engine = _FakeMathEngine(
        const EngineReplyFixture(
          displayText: '5 km + 3 s',
          displayTex: r'\qty{5}{\km} + \qty{3}{\second}',
          kind: EngineResultKind.unit,
        ).reply,
      );
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('5 km + 3 s');
      final submitted = await controller.submit();

      expect(engine.calls, isNotEmpty,
          reason: '单位名过得了词汇，引擎会被问到——这是这一步的前提');
      expect(controller.hasError, isTrue);
      expect(controller.result, isNot(contains('5 km')));
      expect(controller.result, isNot(contains('3 s')));
      expect(submitted.submitted, isFalse);

      controller.dispose();
    });

    test('引擎把带单位的结果交上来时，那串文本不落地（旧解析器作答）', () async {
      // 中文：**取舍本身的那一支**，样本故意与回执不对应（手法同静默错值一）：`unit` 那一支拒绝
      //       引擎的文本，这里 `2+2` 是旧解析器答得出来的，于是屏幕上出现的是**旧解析器的** `4`，
      //       而不是引擎那串 `5 km + 3 s`。真实输入 `5 km + 3 s` 走到同一个分支时，旧解析器答不
      //       出来，于是上一条测的那条错误就是终点。
      // English: **the branch in the selection itself**, with a sample that deliberately does not match
      //          the reply (the same device as case one): the `unit` branch refuses the engine's text,
      //          and here `2+2` is something the legacy parser can answer, so what appears is the
      //          **legacy parser's** `4` rather than the engine's `5 km + 3 s`. When the real input
      //          `5 km + 3 s` reaches this same branch the legacy parser cannot answer, and the error
      //          the test above pins is where it ends.
      final engine = _FakeMathEngine(
        const EngineReplyFixture(
          displayText: '5 km + 3 s',
          displayTex: r'\qty{5}{\km} + \qty{3}{\second}',
          kind: EngineResultKind.unit,
        ).reply,
      );
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('2+2');
      await controller.submit();

      expect(controller.hasError, isFalse, reason: '旧解析器答得出来，那就不是错误');
      expect(controller.result, '4');
      expect(controller.result, isNot(contains('5 km')));

      controller.dispose();
    });

    test('带单位的算式即便被引擎当成向量也不显示（单位压过形状）', () {
      // 中文：`unit` 这一支必须先于形状判据跑：`ncr(5,10)` 的结果**是**一个向量，只是每一项都带
      //       单位——只按形状判会把它放上屏。
      // English: the `unit` branch must run before the shape judgement: the result of `ncr(5,10)` **is**
      //          a vector, only every element carries a unit — a shape-only rule would let it through.
      const result = MathResult(
        displayText: "[2n'p''r'  1.5n'p''r']",
        resultKind: EngineResultKind.unit,
      );
      expect(result.isDisplayable, isFalse);
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
class EngineReplyFixture {
  const EngineReplyFixture({
    required this.displayText,
    required this.displayTex,
    this.kind = EngineResultKind.arithmetic,
  });

  final String displayText;
  final String displayTex;
  final EngineResultKind kind;

  EngineReply get reply => EngineReply.success(MathResult(
        displayText: displayText,
        displayTex: displayTex,
        decimalText:
            MathResult.decimalTextIsFinite(displayText) ? displayText : '',
        resultKind: kind,
      ));
}

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

CalculatorController _controller(
  _FakeDatabase db, {
  required MathEngine engine,
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
    liveEvaluationDelay: const Duration(minutes: 10),
    liveEngineFollowUpDelay: const Duration(minutes: 10),
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
