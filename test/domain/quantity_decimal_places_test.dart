import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/application/controllers/calculator_controller.dart';
import 'package:nekocalc/core/math/math_engine.dart';
import 'package:nekocalc/core/math/math_result.dart';
import 'package:nekocalc/core/math/quantity_display.dart';
import 'package:nekocalc/core/math/result_text_rules.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/repositories/history_repository.dart';
import 'package:nekocalc/data/repositories/notes_repository.dart';
import 'package:nekocalc/data/repositories/settings_repository.dart';

/// 中文：**「小数位数」对一个量是什么意思。** 这个文件钉的是设备上抓到的那条错值：
///
///       | 表达式 | 屏幕 | 设置 | 判定 |
///       |---|---|---|---|
///       | `1÷3` | `= 0.333333` | 6 位 | 取整生效 |
///       | `-5deg to rad` | `= -0.08726646259971648 rad` | 6 位 | **没生效** |
///
///       同一台设备、同一组设置、相差几分钟。值本身是对的（−5° = −0.0872664625997165），错的只有
///       位数。根因是结构性的：带单位的结果 `decimalValue` 为 null（那一串末尾带着单位），于是掉进
///       「Dart 手里没有可以取整的数，原样显示引擎文本」那一支——而那一支本来是为**装不进 double**
///       的结果准备的（`2^2000`），一个量装得下，只是末尾多一个单位。
///
///       判据与全部实测在 `lib/core/math/quantity_display.dart`；这里钉的是**屏幕上的取值**：
///       三条路各自画出来什么（下面前三组），以及**值没有动**（第四组）。
///
/// English: **what "decimal places" means for a quantity.** This file pins the wrong value caught on
///          the device:
///
///          | expression | screen | setting | verdict |
///          |---|---|---|---|
///          | `1÷3` | `= 0.333333` | 6 places | honoured |
///          | `-5deg to rad` | `= -0.08726646259971648 rad` | 6 places | **ignored** |
///
///          Same phone, same settings, minutes apart. The value itself was right
///          (−5° = −0.0872664625997165); only the digit count was wrong. The root cause is structural:
///          a unit-carrying result has a null `decimalValue` (the string ends in a unit), so it fell
///          into the "Dart has no number to round, show the engine's text" branch — a branch meant for
///          results that **cannot fit a double** (`2^2000`), while a quantity fits and merely ends in
///          a unit.
///
///          The judgement and every measurement are in `lib/core/math/quantity_display.dart`; what is
///          pinned here is **the value on screen**: what each of the three routes draws (the first
///          three groups below) and **that the value did not move** (the fourth).
void main() {
  group('一个量取整了（`conversion` / `quantity` 两种种类）', () {
    test('`-5deg to rad`：16 位变成用户要的 6 位，单位原样', () async {
      // 中文：**设备上那一条。** 回执逐字来自宿主实测（`qalc` 5.12.0，精度 16，与桥同一组选项）：
      //       `-5 deg to rad` = `−0.08726646259971648 rad`（终端印的减号是 U+2212，桥洗成 ASCII
      //       `-`，设备上那一条正是洗过之后的形状）。
      //
      //       **表达式那一栏的写法在这一条里是量过的**：能问到引擎的是**带空格**的
      //       `-5 deg to rad`（或 `(-5) deg to rad`）。写成 `-5deg to rad` 时 `deg` 是一个表外的
      //       自由变量，翻译层在引擎被问到**之前**就拒绝了它（`engineExpressionFor` 量过：
      //       「引擎不认识这个自由变量：`deg`」），屏幕上是旧解析器的一句错误——那一条路上根本没有
      //       这个错值。所以这里用带空格的那一种，它是设备上那个数真正的来路。
      // English: **the spelling in the expression column is a measured fact here**: what reaches the
      //          engine is the **spaced** `-5 deg to rad` (or `(-5) deg to rad`). Written as
      //          `-5deg to rad`, `deg` is a free variable outside the table and the translation
      //          refuses it **before** the engine is asked (measured through `engineExpressionFor`:
      //          "引擎不认识这个自由变量：`deg`"), so the screen shows a legacy-parser error — that
      //          road never produces this wrong value at all. The spaced form is used here because it
      //          is how that number on the device really came about.
      final controller = _controllerWith(
        const EngineReplyFixture(
          displayText: '-0.08726646259971648 rad',
          displayTex: r'\qty{0.08726646259971648}{\radian}',
          kind: EngineResultKind.conversion,
        ).result,
      );

      controller.setExpression('-5 deg to rad');
      final submitted = await controller.submit();

      expect(controller.hasError, isFalse);
      expect(controller.result, '-0.087266 rad',
          reason: '小数点后 6 位——用户设置的那一位，与 `1÷3` 的 `0.333333` 是同一条规矩');
      expect(controller.result, endsWith(' rad'), reason: '单位那一截逐字节照抄');
      expect(submitted.submitted, isTrue);

      controller.dispose();
    });

    test('`5 km/h` 与 `1 m/s²`：已经够短的量一位都不动', () async {
      // 中文：**单位记号里的数字、`^`、上标都不是「小数位数」管的东西**：`m/s²` 的 `2` 是单位的
      //       指数，不是这个数的小数部分。两条实测印法（宿主）在这里当作输入。
      // English: **the digits, `^` and superscripts inside a unit mark are not the setting's
      //          business**: the `2` in `m/s²` is the unit's exponent, not a decimal of the number.
      //          Both measured prints (host) are inputs here.
      for (final (text, kind) in <(String, EngineResultKind)>[
        ('5 km/h', EngineResultKind.quantity),
        ('1 m/s²', EngineResultKind.quantity),
      ]) {
        final controller = _controllerWith(
          EngineReplyFixture(
            displayText: text,
            displayTex: r'\qty{5}{\km\per h}',
            kind: kind,
          ).result,
        );
        controller.setExpression('1+1');
        await controller.submit();
        expect(controller.result, text, reason: '`$text` 取整后还是它自己');
        controller.dispose();
      }
    });

    test('`1/3 m`：引擎自己选的单位前缀与取整后的位数各归各', () async {
      // 中文：宿主实测 `1/3 m` 印成 `333.3333333333333 mm`——**引擎把米换成了毫米**，好让数字好看。
      //       小数位数管的是那一串数字（`333.333333`），`mm` 一个字母都不动：那是引擎的答案的一部分，
      //       不是本应用画上去的。
      // English: measured on the host, `1/3 m` prints `333.3333333333333 mm` — **the engine picked
      //          millimetres** so the number reads better. The setting governs that number
      //          (`333.333333`); `mm` does not move by one letter: it is part of the engine's answer,
      //          not something this app draws on top.
      final controller = _controllerWith(
        const EngineReplyFixture(
          displayText: '333.3333333333333 mm',
          displayTex: r'\qty{333.3333333333333}{\mm}',
          kind: EngineResultKind.quantity,
        ).result,
      );

      controller.setExpression('1/3 m');
      await controller.submit();

      expect(controller.result, '333.333333 mm');
      controller.dispose();
    });
  });

  group('装不进 double 的结果仍然原样上屏（那条豁免没有被拆掉）', () {
    test('`2^2000` 与 `2^-2000`：没有单位的那两条', () async {
      // 中文：**这条豁免是既有的，也是必须活着的**：`1.148130695274255E602` 硬取整只能先把
      //       `Infinity` 喂给 `formatNumber`（它印「无效」），`8.709809816217217E-603` 会被
      //       `double.tryParse` 读成 `0.0`——两个都是假值。两条文本都来自宿主实测（精度 16；
      //       桥把大写 `E` 与无符号指数洗成应用自己的 `e+602`/`e-603` 拼法）。
      // English: **this exemption is pre-existing and must survive**: forcing
      //          `1.148130695274255E602` through the rounding means feeding `formatNumber` an
      //          `Infinity` (it prints `无效`), and `8.709809816217217E-603` is read as `0.0` by
      //          `double.tryParse` — both false. Both texts are measured on the host (precision 16;
      //          the bridge washes the uppercase `E` and the unsigned exponent into this app's own
      //          `e+602`/`e-603` spelling).
      for (final text in <String>[
        '1.148130695274255e+602',
        '8.709809816217217e-603',
      ]) {
        final controller = _controllerWith(
          MathResult(displayText: text, decimalText: text),
        );
        final expression = text.startsWith('1.') ? '2^2000' : '2^-2000';
        controller.setExpression(expression);
        await controller.submit();
        expect(controller.result, text, reason: '`$expression` 原样显示引擎那一份');
        expect(controller.result, isNot('0'));
        controller.dispose();
      }
    });

    test('`2^2000 m`：带单位的结果装不下时，走的是同一条豁免', () async {
      // 中文：**这一条把新判据与旧豁免接在一起。** 宿主实测 `2^2000 m` 印成
      //       `1.148130695274255E599 km`（引擎把米换成了千米）——它**是**一个量，种类是 `quantity`，
      //       于是会走到取整那一步；而它的数字部分装不进 double，`decimalValueOf` 给 null，取整那一步
      //       于是什么都不做。两条判据是同一个函数，不是两份规则。
      // English: **this joins the new judgement to the old exemption.** Measured on the host,
      //          `2^2000 m` prints `1.148130695274255E599 km` (the engine picked kilometres). It **is**
      //          a quantity (`quantity` kind), so it reaches the rounding step; its numeric part does
      //          not fit a double, `decimalValueOf` gives null, and that step therefore does nothing.
      //          Both judgements are one function, not two sets of rules.
      final controller = _controllerWith(
        const EngineReplyFixture(
          displayText: '1.148130695274255E599 km',
          displayTex: r'\qty{1.148130695274255e599}{\km}',
          kind: EngineResultKind.quantity,
        ).result,
      );

      controller.setExpression('2^2000 m');
      await controller.submit();

      expect(controller.result, '1.148130695274255E599 km');
      controller.dispose();
    });

    test('`5 km + 3 s`：不是一个量，那串文本一个字都上不了屏', () async {
      // 中文：**「带单位」不等于「是一个量」。** 宿主实测那条加法引擎原样退回来（`5 km + 3 s`），
      //       原生侧判 `unit`——`isDisplayable` 拒绝它，于是它连取整那一步都到不了。这条与新判据
      //       同一条边界：取整只对**数 × 单位**生效，算式不在其中。
      // English: **"carries a unit" is not "is a quantity".** Measured on the host, the engine hands
      //          that addition straight back (`5 km + 3 s`) and the native side reports `unit` —
      //          `isDisplayable` refuses it, so it never reaches the rounding step. This is the same
      //          boundary as the new judgement: rounding applies to **a number times a unit**, and an
      //          expression is not one.
      final controller = _controllerWith(
        const EngineReplyFixture(
          displayText: '5 km + 3 s',
          displayTex: r'\qty{5}{\km} + \qty{3}{\second}',
          kind: EngineResultKind.unit,
        ).result,
      );

      controller.setExpression('5 km + 3 s');
      final submitted = await controller.submit();

      expect(controller.hasError, isTrue);
      expect(controller.result, isNot(contains('5 km')));
      expect(submitted.submitted, isFalse);
      controller.dispose();
    });
  });

  group('值没有动（取整只改写法）', () {
    test('屏幕上少的是位数；Ans / 记忆 / 继续使用读的那一份逐字节不变', () async {
      const exact = '-0.08726646259971648 rad';
      final controller = _controllerWith(
        const EngineReplyFixture(
          displayText: exact,
          displayTex: r'\qty{0.08726646259971648}{\radian}',
          kind: EngineResultKind.conversion,
        ).result,
      );

      controller.setExpression('-5 deg to rad');
      await controller.submit();

      // 中文：**画出来的那一份是取过整的，值那一份不是。**
      // English: **the drawn copy is rounded; the value copy is not.**
      expect(controller.result, '-0.087266 rad');
      expect(controller.resultDecimal, isEmpty,
          reason: '一个量没有十进制形态——数值消费者的判据一个字都没动');
      expect(controller.reusableResult, exact,
          reason: '写回表达式 / Ans / last 用的是引擎那一份未取整的原文');

      // 中文：**「同一个数、写得更短」这句话是可验的**：两串里的数字部分都解析成 double 之后，
      //       相差不超过取整那一位的一半（6 位小数的半步 = 5e-7）。取整不是换一个数。
      // English: **"the same number, written shorter" is checkable**: parse the numeric part of both
      //          strings and the difference is at most half a unit in the last kept place (half a step
      //          of the 6th decimal = 5e-7). Rounding is not swapping in another number.
      final drawn = double.parse(controller.result.split(' ').first);
      final value = double.parse(exact.split(' ').first);
      expect((drawn - value).abs(), lessThanOrEqualTo(5e-7),
          reason: '取整只挪动半个最低位，不挪动别的');

      // 中文：**「继续使用」写回去的是 16 位那一份**——这是上面那条断言在行为上的后果，也是
      //       `MathResult.quantityText` 存在的全部理由。
      // English: **"continue with result" writes the 16-digit copy back** — the behavioural
      //          consequence of the assertion above and the entire reason `MathResult.quantityText`
      //          exists.
      controller.continueWithResult();
      expect(controller.expression, exact);

      controller.dispose();
    });

    test('四位 / 八位：同一个文本，画出来的是用户选的那一档', () async {
      for (final (precision, expected) in <(int, String)>[
        (4, '-0.0873 rad'),
        (8, '-0.08726646 rad'),
      ]) {
        final controller = _controllerWith(
          const EngineReplyFixture(
            displayText: '-0.08726646259971648 rad',
            displayTex: r'\qty{0.08726646259971648}{\radian}',
            kind: EngineResultKind.conversion,
          ).result,
          precision: precision,
        );
        controller.setExpression('-5 deg to rad');
        await controller.submit();
        expect(controller.result, expected, reason: '$precision 位这一档');
        expect(controller.reusableResult, '-0.08726646259971648 rad',
            reason: '$precision 位之下值一样不动');
        controller.dispose();
      }
    });
  });

  group('拆「数 + 单位」的规则本身（纯函数，四条拒绝）', () {
    test('认下来的形状：数取整、单位一整块照抄', () {
      expect(
        roundedQuantityDisplayText(
          _quantity('-0.08726646259971648 rad',
              kind: EngineResultKind.conversion),
          precision: 6,
          groupThousands: false,
        ),
        '-0.087266 rad',
      );
      // 中文：**千分位也跟着设置走**——画出来的那一串就是 `formatNumber` 的输出，一个字都不另写。
      // English: **grouping follows the setting too** — the drawn string is `formatNumber`'s output,
      //          not one character written elsewhere.
      expect(
        roundedQuantityDisplayText(_quantity('3106.855961186670 mi'),
            precision: 6, groupThousands: true),
        '3,106.855961 mi',
      );
      expect(
        roundedQuantityDisplayText(_quantity('3106.855961186670 mi'),
            precision: 6, groupThousands: false),
        '3106.855961 mi',
      );
      // 中文：**比 1e-6 还小的量走科学计数法**，与屏幕上每一个别的数字同一条规矩（引擎印
      //       `0.000000001 km`，6 位之下不是 `0.000000`——那会是一句假话）。
      // English: **a quantity below 1e-6 goes scientific**, the same rule as every other number on
      //          screen (the engine prints `0.000000001 km`; at 6 places that is not `0.000000`, which
      //          would be a lie).
      expect(
        roundedQuantityDisplayText(_quantity('0.000000001 km'),
            precision: 6, groupThousands: false),
        '1e-9 km',
      );
    });

    test('认不出来的形状一律不动（返回 null）：原样上屏就是今天的行为', () {
      // 中文：每一条都带着它为什么到不了这里 / 到了也不能动的理由。**返回 null 不是失败**——
      //       它是「这一次不取整」，调用方照常把引擎那一份画出去。
      // English: each entry carries why it cannot get here, or why it must not move if it does.
      //          **A null is not a failure** — it means "no rounding this time" and the caller draws
      //          the engine's own text as usual.
      final cases = <(String, String, EngineResultKind)>[
        // 中文：进制换算的结果——数不是从 0-9 开头的那一段十进制（`255 to hex` 实测 `0xFF`）。
        // English: a base conversion's result — not a decimal stretch (measured: `255 to hex` →
        //          `0xFF`).
        ('0xFF', '进制换算的结果', EngineResultKind.conversion),
        // 中文：货币——引擎把符号印在数字**前面**（`5 USD` 实测 `$4.38…`），前缀不是数。
        // English: currency — the engine prints the symbol **before** the number (measured: `5 USD` →
        //          `$4.38…`), so the string does not start with one.
        (r'$4.380201489268506', '货币符号在前', EngineResultKind.conversion),
        // 中文：**粘在一起**的写法（数后面不是空格）——宁可不动，也不去猜哪一段是数。
        // English: a **glued** spelling (no space after the number) — better to leave it than to
        //          guess where the number ends.
        ('5km', '数与单位之间没有空格', EngineResultKind.quantity),
        // 中文：**单位那一段里出现空白 ⇒ 整条不认。** 这是「算式」与「量」在文本上分得开的地方：
        //       引擎判成 `unit` 的加法本来到不了这里（种类那一关就挡住了），这一条是第二道——
        //       就算种类报错了，`km + 3 s` 也过不了形状这一关。
        // English: **whitespace inside the unit stretch fails the whole match.** This is where an
        //          expression and a quantity come apart in text: an addition the engine reports as
        //          `unit` cannot get here anyway (the kind gate stops it), and this is the second
        //          line — even with a wrong kind, `km + 3 s` fails the shape.
        ('5 km + 3 s', '单位那一段里带着空白', EngineResultKind.quantity),
        // 中文：复数——`2` 只是两个数里的一个，取整一小半不是这个设置的含义。
        // English: a complex number — the `2` is one of two numbers, and rounding one of them is not
        //          what the setting means.
        ('1 + 2i', '复数的种类是 number', EngineResultKind.number),
        // 中文：符号式——系数取整会把一个符号式子写成另一个样子。
        // English: a symbolic form — rounding the coefficient rewrites a symbolic expression.
        ('2x', '符号式的种类是 symbolic', EngineResultKind.symbolic),
        // 中文：矩阵——一整片数，没有「那个数」。
        // English: a matrix — a field of numbers, with no "the number".
        ('[1  2; 3  4]', '矩阵的种类是 structured', EngineResultKind.structured),
        // 中文：**装不进 double 的量**（宿主实测 `2^2000 m` 印成这个）。
        // English: **a quantity that does not fit a double** (measured on the host for `2^2000 m`).
        ('1.148130695274255E599 km', '数字部分溢出', EngineResultKind.quantity),
        // 中文：下溢那一端——`double.tryParse` 给 `0.0`，`decimalValueOf` 拦下它。
        // English: the underflowing end — `double.tryParse` yields `0.0` and `decimalValueOf` stops it.
        ('8.709809816217217e-603 km', '数字部分下溢', EngineResultKind.quantity),
        // 中文：逗号小数（逗号不是分组位置时桥不会剥掉）——不猜。
        // English: a comma decimal (the bridge does not strip a comma that is not in a grouping
        //          position) — no guessing.
        ('5,656854 km', '逗号小数', EngineResultKind.quantity),
        // 中文：U+2212 减号（桥会洗成 ASCII，这里是第二道）。
        // English: a U+2212 minus (the bridge washes it to ASCII; this is the second line).
        ('−5 km', 'Unicode 减号', EngineResultKind.quantity),
      ];

      for (final (text, why, kind) in cases) {
        expect(
          roundedQuantityDisplayText(_quantity(text, kind: kind),
              precision: 6, groupThousands: false),
          isNull,
          reason: '$why：`$text` 不许被取整',
        );
      }
    });
  });
}

/// 中文：一条引擎回执的固定装置——与 `calculator_unit_result_test.dart` 里那一份同形。各文件各自
///       持有一份是有意的（理由写在那边）。
/// English: a fixture for one engine receipt, the same shape as the one in
///          `calculator_unit_result_test.dart`. Each file keeping its own is deliberate (the reason is
///          over there).
class EngineReplyFixture {
  const EngineReplyFixture({
    required this.displayText,
    required this.displayTex,
    required this.kind,
  });

  final String displayText;
  final String displayTex;
  final EngineResultKind kind;

  MathResult get result => MathResult(
        displayText: displayText,
        displayTex: displayTex,
        decimalText:
            decimalTextIsFinite(displayText) ? displayText : '',
        resultKind: kind,
      );
}

/// 中文：一份「带单位的结果」——纯函数那几条测试的输入。与桥交给控制器的形状相同：显示文本与
///       十进制形态是同一个洗净后的 `decimal`，而这个 `decimal` 不是有限数（所以 `decimalText` 空）。
/// English: a unit-carrying result — the input for the pure-function cases. It has the shape the
///          bridge hands the controller: the display text and the decimal form are the same washed
///          `decimal`, and that `decimal` is not a finite number (so `decimalText` is empty).
MathResult _quantity(
  String displayText, {
  EngineResultKind kind = EngineResultKind.quantity,
}) {
  return MathResult(
    displayText: displayText,
    decimalText:
        decimalTextIsFinite(displayText) ? displayText : '',
    resultKind: kind,
  );
}

CalculatorController _controllerWith(
  MathResult result, {
  int precision = 6,
}) {
  return _controller(
    _FakeDatabase(),
    engine: _FakeMathEngine(EngineReply.success(result)),
    precision: precision,
  );
}

CalculatorController _controller(
  _FakeDatabase db, {
  required MathEngine engine,
  int precision = 6,
}) {
  return CalculatorController(
    historyRepository: HistoryRepository(db),
    notesRepository: NotesRepository(db),
    settingsRepository: SettingsRepository(db),
    settings: AppSettings(
      haptics: true,
      hapticStrength: '标准',
      restoreState: false,
      autoSaveHistory: false,
      angleMode: 'RAD',
      precision: precision,
      themeModeLabel: '跟随系统',
      expressionDisplayMode: '数学符号',
    ),
    engine: engine,
    liveEvaluationDelay: const Duration(minutes: 10),
    liveEngineFollowUpDelay: const Duration(minutes: 10),
  );
}

class _FakeMathEngine implements MathEngine {
  _FakeMathEngine(this.reply);

  final EngineReply reply;

  @override
  Future<EngineReply> evaluate(
    String expression, {
    required String angleMode,
  }) async =>
      reply;
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
