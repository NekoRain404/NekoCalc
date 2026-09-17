import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/application/controllers/calculator_controller.dart';
import 'package:nekocalc/core/math/app_engine_vocabulary.dart';
import 'package:nekocalc/core/math/app_unit_catalog.dart';
import 'package:nekocalc/core/math/ast/expression_ast_parser.dart';
import 'package:nekocalc/core/math/engine_expression.dart';
import 'package:nekocalc/core/math/math_engine.dart';
import 'package:nekocalc/core/math/math_result.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/repositories/history_repository.dart';
import 'package:nekocalc/data/repositories/notes_repository.dart';
import 'package:nekocalc/data/repositories/settings_repository.dart';

/// 中文：**「把单位送进表达式」这条路的钉子**：语法（`to` 是一个词运算符）、翻译（译成引擎的写法，
///       而且**两侧必须带空格**）、词汇（哪些单位名放行）、以及端到端一次真正的换算。
///
///       所有引擎侧的取值都是宿主实测的（libqalculate 5.12.0，按桥的调用序列
///       `unlocalizeExpression` → `calculate` → `print`，精度 16、`mixed_units_conversion=NONE`、
///       `auto_post_conversion=POST_CONVERSION_OPTIMAL`）。量测程序与完整输出在步骤 6 的报告里。
///
/// English: **Pins for the "get a unit into the expression" route**: the grammar (`to` is a word
///          operator), the translation (written the engine's way, and **with spaces on both sides**),
///          the vocabulary (which unit names pass) and one real end-to-end conversion.
///
///          Every engine-side value here is measured on the host (libqalculate 5.12.0, through the
///          bridge's call sequence `unlocalizeExpression` → `calculate` → `print`, precision 16,
///          `mixed_units_conversion=NONE`, `auto_post_conversion=POST_CONVERSION_OPTIMAL`). The
///          measuring program and its full output are in the step 6 report.
void main() {
  group('语法：`to` 是一个词运算符', () {
    const parser = ExpressionAstParser();

    test('`5 km to mi` 读成换算，而不是三连乘', () {
      final node = parser.parse('5 km to mi');
      expect(node, isA<BinaryNode>());
      final binary = node as BinaryNode;
      expect(binary.op, 'to');
      expect(binary.left, isA<ImplicitProductNode>());
      expect(binary.right, isA<VariableNode>());
      expect((binary.right as VariableNode).name, 'mi');
    });

    test('词边界：`toto` 与 `2to` 都不是这个运算符', () {
      // 中文：`to` 是字母组成的，所以边界必须判。「`toto`」是一个标识符，`2to` 里前一格是名字
      //       字符——两者都不该被拆成 `to` + 别的东西。
      // English: `to` is made of letters, so its boundary has to be judged. `toto` is one identifier
      //          and in `2to` the preceding character is a name character — neither may be split.
      expect(parser.parse('toto'), isA<VariableNode>());
      expect(parser.parse('2to'), isNot(isA<BinaryNode>()),
          reason: '`2to` 里没有空格，`to` 不构成一个词');
    });

    test('`to` 单独出现仍然只是一个变量（旧行为没变）', () {
      final node = parser.parse('to');
      expect(node, isA<VariableNode>());
      expect((node as VariableNode).name, 'to');
    });

    test('括号与实参里也成立，右操作数是一整段表达式', () {
      final grouped = parser.parse('(5 km to mi)');
      expect(grouped, isA<GroupNode>());
      expect((grouped as GroupNode).child, isA<BinaryNode>());

      final binary = parser.parse('5 km to m/s') as BinaryNode;
      expect(binary.op, 'to');
      expect(binary.right, isA<BinaryNode>(),
          reason: '目标里的 `/` 属于目标自己');
      expect((binary.right as BinaryNode).op, '/');
    });
  });

  group('翻译：写出来的那串东西，引擎读得懂', () {
    test('`5 km to mi` 译成带空格的换算', () {
      // 中文：**两侧的空格是必须的，这是量出来的**：引擎把 `((5)*(km))to((mi))`（没有空格）读成
      //       `t`·`o` 的乘积——`8.04672 MB*t*m^2`，**不报错**；带空格的那一串才是那次换算
      //       （`3.106855961186670 mi`，`to_struct` 非空）。所以这里钉住的是逐字的字符串。
      // English: **The spaces on both sides are required, and that is measured**: the engine reads
      //          `((5)*(km))to((mi))` (no spaces) as the product `t`·`o` — `8.04672 MB*t*m^2`, with
      //          **no error**; the spaced string is the conversion (`3.106855961186670 mi`,
      //          `to_struct` defined). What is pinned here is the string verbatim.
      expect((engineExpressionFor('5 km to mi') as TranslatedExpression).text,
          '((((5)*(km))) to (mi))');
    });

    test('单位名原样透传，表外的一切自由变量仍然拒绝', () {
      expect((engineExpressionFor('5 km') as TranslatedExpression).text,
          '((5)*(km))');
      expect((engineExpressionFor('5 km + 3 s') as TranslatedExpression).text,
          '((((5)*(km)))+(((3)*(s))))');
      // 中文：`zorkmid` 是**不存在**的单位，引擎会给一个看似合理的值（实测 `5E-21 B`），所以它
      //       必须在翻译这一层就被拒绝——引擎根本不该被问到。
      // English: `zorkmid` is a unit that does **not exist** and the engine returns a plausible value
      //          for it (measured `5E-21 B`), so it has to be refused here at the translation layer —
      //          the engine must not be asked at all.
      expect(engineExpressionFor('5 zorkmid'), isA<UntranslatableExpression>());
    });

    test('词汇按原样查表：`KM` 不是 `km`', () {
      // 中文：引擎的单位名分大小写，折成小写等于把两个单位当成一个；`KM` 因此落回「表外的自由
      //       变量」，由旧解析器报错，而不是被当成 `km` 送过去。
      // English: the engine's unit names distinguish case, so folding would treat two units as one;
      //          `KM` therefore falls back to "a free variable outside the table", where the legacy
      //          parser reports an error, rather than being sent as `km`.
      expect(AppEngineVocabulary.variableUnknownToEngine('km'), isNull);
      expect(AppEngineVocabulary.variableUnknownToEngine('KM'), isNotNull);
      expect(AppEngineVocabulary.variableUnknownToEngine('zorkmid'), isNotNull);
    });
  });

  group('单位表', () {
    test('符号不重复，每一族都有单位', () {
      expect(kAppUnits.length, kAppUnitSymbols.length,
          reason: '重复的符号会让面板里出现两个一样的按钮，而它们是同一个单位');
      final families = <String>{for (final unit in kAppUnits) unit.family};
      expect(families, kAppUnitFamilies.toSet());
    });

    test('表里的每一个符号都过得了词汇这一关', () {
      // 中文：这条防的是「表里加了单位、词汇却没放行」（或反过来）——两边读的是同一张表，所以它
      //       今天必然成立，而它一旦不成立就说明有人把其中一处改成了第二份清单。
      // English: this guards against "a unit was added to the table but the vocabulary does not let it
      //          through" (or the reverse) — both read the same table, so it holds by construction
      //          today, and if it ever fails someone has made a second copy of the list.
      for (final unit in kAppUnits) {
        expect(AppEngineVocabulary.variableUnknownToEngine(unit.symbol), isNull,
            reason: '${unit.symbol} 在表里，却过不了词汇这一关');
      }
    });

    test('刻意不在表里的两类', () {
      // 中文：`m^2`/`m/s` 是**表达式**不是名字；`°C` 在应用这一侧根本不是摄氏度（`°` 被解析器
      //       改写成角度）。放进表里会让同一个写法两侧含义不同。
      // English: `m^2`/`m/s` are **expressions** rather than names; `°C` does not mean degrees Celsius
      //          on this side at all (`°` is rewritten as an angle by the parser). Listing them would
      //          give one spelling two meanings on the two sides.
      for (final absent in <String>['m^2', 'm/s', '°C', 'deg']) {
        expect(isAppUnit(absent), isFalse, reason: '「$absent」不该在可插入单位表里');
        expect(AppEngineVocabulary.variableUnknownToEngine(absent), isNotNull);
      }
    });
  });

  group('端到端：一次真正的换算', () {
    test('`5 km to mi` 送出去的是翻译后的串，屏幕上是引擎的换算结果', () async {
      // 中文：回执的三个字段逐字来自宿主实测（`5 km to mi`）。这条同时钉住三件事：引擎**被问到了**
      //       （单位名过得了词汇）、问出去的是**翻译后的**串、以及结果**上了屏**。
      // English: the receipt's three fields are verbatim from the host (`5 km to mi`). This pins three
      //          things at once: the engine **was asked** (unit names pass the vocabulary), what went
      //          out is the **translated** string, and the result **landed on screen**.
      final engine = _FakeMathEngine(
        const EngineReplyFixture(
          displayText: '3.106855961186670 mi',
          displayTex: r'\qty{3.106855961186670}{mi}',
          kind: EngineResultKind.conversion,
        ).reply,
      );
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('5 km to mi');
      final submitted = await controller.submit();

      expect(engine.calls.map((call) => call.expression).toList(),
          <String>['((((5)*(km))) to (mi))']);
      expect(controller.hasError, isFalse);
      // 中文：**带单位的结果原样上屏**，数值部分不过 `formatNumber`。理由是结构性的：那个函数要的
      //       是一个 `double`，而 `decimalText` 这一份**不是有限数**（`3.106855961186670 mi`），
      //       `decimalValue` 因此为 null。要取整就得先在显示路径上把「数字 + 单位」拆开——那是
      //       在显示层发明一条解析规则，代价比它带来的整齐更大。（同一条理由已经用在「放不进
      //       double 的精确结果原样显示」上。）用户设置的小数位数对普通数值照旧生效。
      // English: **a unit-carrying result lands on screen as it stands**, its numeric part not passed
      //          through `formatNumber`. The reason is structural: that function wants a `double`, and
      //          this `decimalText` **is not a finite number** (`3.106855961186670 mi`), so
      //          `decimalValue` is null. Rounding it would mean splitting "number + unit" on the
      //          display path first — inventing a parse rule in the display layer, a bigger price than
      //          the tidiness is worth. (The same reasoning already applies to exact results that do
      //          not fit a double, which are shown verbatim.) The user's decimal-places setting still
      //          applies to ordinary numeric results.
      expect(controller.result, '3.106855961186670 mi');
      expect(submitted.submitted, isTrue);

      controller.dispose();
    });

    test('换算不成立时屏幕上是那条「单位不匹配」，不是引擎退回来的输入', () async {
      // 中文：`5 km to kg` 在引擎那边**不报错**（宿主实测）、把输入原样退回；原生侧判出
      //       `unit_mismatch`（把结果除以目标还剩 `5 m/g`），Dart 侧据此报错。
      // English: `5 km to kg` **does not error** in the engine (measured) and hands the input back;
      //          the native side judges `unit_mismatch` (dividing the result by the target leaves
      //          `5 m/g`) and Dart reports the error on that basis.
      final engine = _FakeMathEngine(
        const EngineReplyFixture(
          displayText: '5 km',
          displayTex: r'\qty{5}{\km}',
          kind: EngineResultKind.unitMismatch,
        ).reply,
      );
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('5 km to kg');
      await controller.submit();

      expect(controller.hasError, isTrue);
      expect(controller.result, '单位不匹配：这两个单位不能互相换算');

      controller.dispose();
    });
  });
}

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
