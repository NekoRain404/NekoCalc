import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/application/controllers/calculator_controller.dart';
import 'package:nekocalc/core/math/math_engine.dart';
import 'package:nekocalc/core/math/math_result.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/repositories/history_repository.dart';
import 'package:nekocalc/data/repositories/notes_repository.dart';
import 'package:nekocalc/data/repositories/settings_repository.dart';

/// 中文：**修复轮 6 的判据：值以应用为准。**
///
///       - 应用自己的解析器**解析得了**这个表达式 ⇒ 引擎只允许贡献**形态**，而且只有它的数值与
///         应用一致时才允许；不一致就丢弃（回落旧解析器）。
///        - 引擎的十进制**超出 double 量程**（`2^2000`）⇒ 应用给不出这个值 ⇒ 引擎赢。
///        - 引擎的十进制**不是有限数**（矩阵、复数、带单位）而应用又解析得了 ⇒ 它读成了别的东西
///          ⇒ 丢弃。
///       - 应用**解析不了** ⇒ 引擎是唯一来源（矩阵、复数、微积分）。
///
///       这一组的每个样本都是**真机/宿主实测过的引擎原文**，替身只是把它送回同一个表达式。
/// English: **fix round 6's criterion: the value comes from this app.**
///
///          - the app's own parser **can parse** the expression ⇒ the engine may contribute the **form**
///            only, and only when its value agrees with the app's; a disagreement is discarded (the
///            legacy parser answers);
///          - the engine's decimal **exceeds the double range** (`2^2000`) ⇒ the app has no such value
///            ⇒ the engine wins;
///          - the engine's decimal **is not a finite number** (a matrix, a complex, a unit-carrying
///            quantity) while the app *can* parse the source ⇒ it read something else ⇒ discard;
///          - the app **cannot parse it** ⇒ the engine is the only source (matrices, complex numbers,
///            calculus).
///
///          Every sample in this group is a **device/host-measured** engine string; the double only
///          hands it back for the same expression.
void main() {
  group('值以应用为准：引擎读成别的东西时按值丢弃', () {
    // 中文：`(表达式, 引擎实测的原文, 屏幕上应有的结果)`。前四条是这五轮里出现过的活错值，
    //       后两条是**拼法**与**隐式乘法**——它们没有名字可枚举，只有值能判。
    // English: `(expression, the measured engine string, what the screen must read)`. The first four
    //          are the live wrong values these rounds produced; the last two are about **spellings**
    //          and **implicit multiplication** — nothing there can be enumerated by name, only by
    //          value.
    const cases = <({String expression, String engineText, String expected})>[
      // 引擎里 `phi` 是欧拉 φ 函数（真机：`phi(2)` → 1），应用里它是黄金比常量 ×2 = 3.236068。
      (expression: 'phi(2)', engineText: '1', expected: '3.236068'),
      // 同一个常量的**另一种拼法**：应用自己的归一化把 `φ` 折成 `phi`，而按名字枚举的词表看不见它。
      (expression: 'φ(2)', engineText: '1', expected: '3.236068'),
      // 引擎的 `log` 是自然对数（真机 4.605170185988091），应用的是常用对数。
      (expression: 'log(100)', engineText: '4.605170185988091', expected: '2'),
      // 引擎的 `mod(7,-3)` 是 -2，应用的 `%` 是欧几里得余数 1。
      (expression: 'mod(7,-3)', engineText: '-2', expected: '1'),
    ];

    for (final row in cases) {
      test('${row.expression}：屏幕上是 ${row.expected}，不是引擎的 ${row.engineText}', () async {
        final controller = _controller(
          _FakeDatabase(),
          engine: _FakeMathEngine(_reply(row.engineText)),
        );

        controller.setExpression(row.expression);
        await controller.submit();

        expect(controller.result, row.expected,
            reason: '${row.expression} 采用了引擎的值 ${row.engineText}');
        // 中文：应用自己的值同时也是十进制形态（`Ans`/记忆用它）。
        // English: the app's own value is also the decimal form (`Ans`/memory use it).
        expect(controller.resultDecimal, row.expected);
        expect(controller.hasError, isFalse);

        controller.dispose();
      });
    }
  });

  group('判据的三个例外各自成立', () {
    test('应用解析不了 ⇒ 引擎是唯一来源：矩阵照样上屏', () async {
      final controller = _controller(
        _FakeDatabase(),
        engine: _FakeMathEngine(_reply('[1  2; 3  4]', tex: r'\\begin{bmatrix}1 & 2 \\\\ 3 & 4\\end{bmatrix}')),
      );

      controller.setExpression('matrix(2,2,1,2,3,4)');
      await controller.submit();

      expect(controller.hasError, isFalse);
      expect(controller.result, '[1  2; 3  4]');
      expect(controller.resultTex, contains('bmatrix'));

      controller.dispose();
    });

    test('应用解析不了 ⇒ 复数照样上屏', () async {
      final controller = _controller(
        _FakeDatabase(),
        engine: _FakeMathEngine(_reply('1 + 2i')),
      );

      controller.setExpression('2i+1');
      await controller.submit();

      expect(controller.hasError, isFalse);
      expect(controller.result, '1 + 2i');

      controller.dispose();
    });

    test('引擎的值超出 double 量程 ⇒ 引擎赢（应用给不出这个值）', () async {
      // 中文：`2^2000` 的引擎文本是**有限十进制**，只是 double 装不下——这一条是步骤 3d 修好的，
      //       判据必须把它留住（否则引擎最不可替代的那类结果会被丢掉）。
      // English: the engine's text for `2^2000` is a **finite decimal**, just beyond a double — step 3d
      //          fixed this, and the criterion has to keep it (otherwise the results the engine is
      //          least replaceable for would be thrown away).
      final controller = _controller(
        _FakeDatabase(),
        engine: _FakeMathEngine(_reply('1.148130695274255E602')),
      );

      controller.setExpression('2^2000');
      await controller.submit();

      // 中文：替身直接构造 [MathResult]，绕过了适配层的科学计数法改写（真机上 `E602` 会被写成
      //       应用的 `e+602`），所以这里断言的是替身给的那串原文。
      // English: the double builds the [MathResult] directly, bypassing the adapter's scientific-notation
      //          rewrite (on a device `E602` is spelled the app's `e+602`), so this asserts the string the
      //          double supplied.
      expect(controller.result, '1.148130695274255E602');
      expect(controller.resultDecimal, '1.148130695274255E602');

      controller.dispose();
    });

    test('应用给得出的是**下溢的 0**（`2^-2000`）⇒ 引擎赢，不能显示 0', () async {
      // 中文：**这一条是判据最容易被误解的地方。** 应用自己的解析器对 `2^-2000` 给的是 **`0.0`**
      //       ——它是一个**有限** double，看上去"应用解析得了"；而引擎给 `8.709809816217217E-603`
      //       （文本有限、double 装不下）。判据必须认出「应用这个 0.0 装不下真实结果」，
      //       让引擎赢——否则步骤 3d 修好的下溢错值会以新判据的名义回来。
      //       （写这条测试的过程：撤掉那个例外时整套测试**仍然全绿**，说明此前没有测试覆盖它——
      //       这条就是那次变异找出来的缺口。）
      // English: **the place this criterion is easiest to get wrong.** This app's own parser returns
      //          **`0.0`** for `2^-2000` — a *finite* double, so at first sight "the app can answer" —
      //          while the engine gives `8.709809816217217E-603` (finite as text, unrepresentable as a
      //          double). The criterion has to recognise that the app's 0.0 cannot hold the real result
      //          and let the engine win; otherwise step 3d's underflow fix would come back wearing this
      //          criterion's name. (How this test got written: removing that exception left the whole
      //          suite **green**, i.e. nothing covered it — this is the gap that mutation found.)
      final controller = _controller(
        _FakeDatabase(),
        engine: _FakeMathEngine(_reply('8.709809816217217E-603')),
      );

      // 中文：先确认前提——应用自己的解析器对这条表达式给的就是 0.0（下溢），用一个**没有引擎**
      //       的控制器量它：那是应用自己的答案。
      // English: first confirm the premise — the app's own parser answers 0.0 for this expression
      //          (underflow); measured with an engine-less controller, which is the app's own answer.
      final appOnly = _controller(_FakeDatabase(), engine: _FailingMathEngine());
      appOnly.setExpression('2^-2000');
      await appOnly.submit();
      expect(appOnly.result, '0', reason: '应用自己的解析器在这里给的就是 0（下溢）');
      appOnly.dispose();

      controller.setExpression('2^-2000');
      await controller.submit();

      expect(controller.result, '8.709809816217217E-603');
      expect(controller.result, isNot('0'));

      controller.dispose();
    });

    test('值一致时引擎的形态照旧保留（精确形式不能被这一轮弄丢）', () async {
      // 中文：`sqrt(8)` 两边一致（应用 2.8284271247461903，引擎 2.828427124746190，相对差 1e-16）
      //       ⇒ 采用引擎的那一份（值 + 形态）——这是引入引擎的原始理由，判据不许把它挡住。
      // English: `sqrt(8)` agrees on both sides (app 2.8284271247461903, engine 2.828427124746190, about
      //          1e-16 apart) ⇒ the engine's copy is adopted (value and form) — the original reason the
      //          engine is here, and the criterion must not block it.
      final controller = _controller(
        _FakeDatabase(),
        engine: _FakeMathEngine(_reply('2.828427124746190', tex: r'2\\times \\sqrt{2}')),
      );

      controller.setExpression('sqrt(8)');
      await controller.submit();

      expect(controller.hasError, isFalse);
      expect(controller.result, '2.828427');
      expect(controller.resultTex, isNotEmpty);

      controller.dispose();
    });

    test('合法的精度差异不算误读：DEG 下的 sin(30)', () async {
      // 中文：角度模式两边一致（桥把 `angleMode` 同时交给 `ParseOptions.setAngle_unit` 与应用自己的
      //       解析器），但 DEG 下应用先做 `arg * pi / 180` 这一步 **double** 运算、引擎按精确值算——
      //       `sin(30)` 应用给 `0.49999999999999994`、引擎给 `0.5`，相对差约 1e-16。
      //       容差 1e-9 必须把它当一致（否则每一个 DEG 三角结果都会回落到旧解析器）。
      // English: the angle mode is consistent on both sides (the bridge gives `angleMode` to
      //          `ParseOptions.set_angle_unit` and to this app's own parser), but in DEG the app does the
      //          `arg * pi / 180` step in **double** while the engine computes it exactly — `sin(30)` is
      //          `0.49999999999999994` from the app and `0.5` from the engine, about 1e-16 apart. The
      //          1e-9 tolerance has to call that agreement (otherwise every DEG trigonometric result
      //          would fall back to the legacy parser).
      final controller = _controller(
        _FakeDatabase(),
        engine: _FakeMathEngine(_reply('0.5')),
        settings: _degSettings,
      );

      controller.setExpression('sin(30)');
      await controller.submit();

      expect(controller.hasError, isFalse);
      expect(controller.result, '0.5');

      controller.dispose();
    });

    test('引擎读成矩阵而应用解析得了 ⇒ 丢弃（不是「引擎懂得多」）', () async {
      // 中文：`sqrt(8)` 应用解析得了，引擎却回了矩阵——那说明引擎读成了别的东西，丢弃。
      // English: the app can parse `sqrt(8)` and the engine came back with a matrix — that means the
      //          engine read something else, so it is discarded.
      final controller = _controller(
        _FakeDatabase(),
        engine: _FakeMathEngine(_reply('[9  9; 9  9]', kind: 'structured')),
      );

      controller.setExpression('sqrt(8)');
      await controller.submit();

      expect(controller.result, '2.828427');
      expect(controller.result, isNot(contains('9')));

      controller.dispose();
    });
  });
}

EngineReply _reply(String decimal, {String tex = '', String kind = 'number'}) =>
    EngineReply.success(MathResult(
      displayText: decimal,
      displayTex: tex,
      decimalText: MathResult.decimalTextIsFinite(decimal) ? decimal : '',
      resultKind: switch (kind) {
        'structured' => EngineResultKind.structured,
        'unit' => EngineResultKind.unit,
        'conversion' => EngineResultKind.conversion,
        _ => EngineResultKind.number,
      },
    ));

const AppSettings _degSettings = AppSettings(
  haptics: true,
  hapticStrength: '标准',
  restoreState: false,
  autoSaveHistory: false,
  angleMode: 'DEG',
  precision: 6,
  themeModeLabel: '跟随系统',
  expressionDisplayMode: '数学符号',
);

/// 中文：引擎缺席的替身——用来量「应用自己的答案」。
/// English: an engine-less double — used to measure "this app's own answer".
class _FailingMathEngine implements MathEngine {
  @override
  Future<EngineReply> evaluate(
    String expression, {
    required String angleMode,
  }) async =>
      EngineReply.failure('test: no engine');
}

class _FakeMathEngine implements MathEngine {
  _FakeMathEngine(this.reply);

  EngineReply reply;

  @override
  Future<EngineReply> evaluate(
    String expression, {
    required String angleMode,
  }) async =>
      reply;
}

CalculatorController _controller(
  _FakeDatabase db, {
  required MathEngine engine,
  AppSettings settings = const AppSettings(
    haptics: true,
    hapticStrength: '标准',
    restoreState: false,
    autoSaveHistory: false,
    angleMode: 'RAD',
    precision: 6,
    themeModeLabel: '跟随系统',
    expressionDisplayMode: '数学符号',
  ),
}) {
  return CalculatorController(
    historyRepository: HistoryRepository(db),
    notesRepository: NotesRepository(db),
    settingsRepository: SettingsRepository(db),
    settings: settings,
    engine: engine,
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
