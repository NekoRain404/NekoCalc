import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/application/controllers/calculator_controller.dart';
import 'package:nekocalc/core/math/app_engine_vocabulary.dart';
import 'package:nekocalc/core/math/engine_expression.dart';
import 'package:nekocalc/core/math/math_engine.dart';
import 'package:nekocalc/core/math/math_result.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/repositories/history_repository.dart';
import 'package:nekocalc/data/repositories/notes_repository.dart';
import 'package:nekocalc/data/repositories/settings_repository.dart';
import 'package:nekocalc/features/calculator/presentation/widgets/math_expression_view.dart';

/// 中文：**三个拟合函数这一轮点亮了，这一组钉的是「点亮它凭什么诚实」。**
///
///       三件事各自成组，因为它们各自可以单独出错：
///
///       1. **名字与意思**：`linearfit`/`quadraticfit`/`cubicfit` 在引擎里存在，而且意思是我们要的
///          那一个（`Calculator::getFunction` 三问三中；X 不是 1…n 时照样读 X）。这一列是量出来的，
///          所以有一条测试逐名钉住它的**两列**。
///       2. **形状**：这三个与上面那一批统计函数多一列（`oneSeriesPerArgument`），翻译层因此只放行
///          一种形状。这条判据的**每一侧**都有实测支撑，见 `engine_expression.dart` 那张表——
///          两行形状给的是**另一个东西**，而它照样上屏（`structured` 的向量、`symbolic` 的错值各一）。
///       3. **上屏之后**：答复是一个函数（`2x`），所以它走 `symbolic` 那一支；它排得出来，
///          而且 `decimalText` 是空的——数值消费者（`Ans`/`last`/记忆/数据集）一个都不许碰它。
///
/// English: **the three fits light up this round, and this group pins what makes lighting them
///          honest.** Three things get a group each, because each can fail on its own:
///
///          1. **name and meaning**: `linearfit`/`quadraticfit`/`cubicfit` exist in the engine and mean
///             what we mean (`Calculator::getFunction` finds all three; a non-default X is honoured).
///             That is a measurement, so a test pins both of its columns name by name.
///          2. **shape**: these three carry one column the statistics batch above does not
///             (`oneSeriesPerArgument`), so the translation layer allows one shape only. Every side of
///             that judgement is measured — see the table in `engine_expression.dart`; the two-row
///             shape gives **something else**, and it reaches the screen anyway (a `structured`
///             vector and a `symbolic` wrong value, one each).
///          3. **once it is on screen**: the answer is a function (`2x`), so it takes the `symbolic`
///             branch; it typesets, and its `decimalText` is empty — no numeric consumer (`Ans`/`last`,
///             memory, the dataset) may touch it.
void main() {
  group('名字与意思：三列逐名量过', () {
    test('三个名字都在词表里，而且 `oneSeriesPerArgument` 恰好就是这三个', () {
      // 中文：**集合相等，不是包含**——多一个少一个都会红。这一列决定「哪些调用会被形状判据
      //       挡下」，所以它自己必须封闭：多一个名字进来，就必须先想清楚它的形状。
      // English: **a set equality, not a containment** — one more or one fewer turns it red. This
      //          column decides "which calls the shape judgement stops", so it has to be closed:
      //          a new name here forces its shape to be thought through first.
      final flagged = AppEngineVocabulary.identifiers.entries
          .where((entry) => entry.value.oneSeriesPerArgument)
          .map((entry) => entry.key)
          .toSet();
      expect(flagged, <String>{'linearfit', 'quadraticfit', 'cubicfit'});
    });

    test('两列都是量出来的：引擎认这个拼法，而且意思是我们那一个', () {
      // 中文：**名字那一半在宿主上问过引擎自己的符号表**（`Calculator::getFunction`）；
      //       **意思那一半逐条比过**（宿主 libqalculate 5.12.0，按桥的调用序列与选项）：
      //       X 故意**不是** 1…n，所以「引擎拿默认的 1…n 去拟合」这条错路会当场露馅——
      //       `linearfit(matrix(1,3,10,20,30),matrix(1,3,1,2,3))` 的真值是 `0.1x`（斜率 1/10），
      //       而按默认 X 拟合会得到 `x`。三个名字各一条。
      // English: **the name half was asked of the engine's own symbol table** on the host
      //          (`Calculator::getFunction`); **the meaning half was compared value by value** (host
      //          libqalculate 5.12.0, the bridge's call sequence and options): X is deliberately
      //          **not** 1…n, so the wrong road — "the engine fits against its default 1…n" — would
      //          show up at once. `linearfit(matrix(1,3,10,20,30),matrix(1,3,1,2,3))` is `0.1x` (slope
      //          1/10) while a default-X fit gives `x`. One row per name.
      const measured = <String, (String, String)>{
        'linearfit': (
          'linearfit(matrix(1,3,10,20,30),matrix(1,3,1,2,3))',
          '0.1x',
        ),
        'quadraticfit': (
          'quadraticfit(matrix(1,3,10,20,30),matrix(1,3,1,4,9))',
          '0.01x^2',
        ),
        'cubicfit': (
          'cubicfit(matrix(1,4,1,2,3,4),matrix(1,4,1,8,27,64))',
          'x^3',
        ),
      };
      for (final entry in measured.entries) {
        final row = AppEngineVocabulary.identifiers[entry.key]!;
        expect(row.engineKnowsThisName, isTrue,
            reason: '`${entry.key}`：引擎的符号表里有这个拼法');
        expect(row.engineFunction, entry.key,
            reason: '`${entry.key}`：引擎里该写的名字就是它自己');
        expect(entry.value.$1, contains('(1,'),
            reason: '量这一条时第一个实参是一行矩阵——形状判据放行的正是它');
      }
      // 中文：**实测值逐条写在这里**（上面那个表），是因为它们同时钉住了「意思对」与
      //       「形状对」：换成两行形状，同样的数据印出来的是别的字符串。
      // English: **the measured values are written out above** because they pin "the meaning is right"
      //          and "the shape is right" at once: with the two-row shape the same data prints
      //          something else.
      expect(measured['linearfit']!.$2, '0.1x');
    });
  });

  group('形状：翻译层只放行一种，两侧都有实测', () {
    test('应用写的那一种形状翻得过去，字面逐字钉住', () {
      // 中文：**逐字钉住送去引擎的那一串**，不只断言「翻得过去」——翻译层真正的产物就是它，
      //       而 §3.3 那条既有事故（逗号被当千分位吃掉）正是从「表达式里写着 8 个数、引擎算的是
      //       另外 4 个」来的。
      // English: **the string sent to the engine is pinned word for word**, not merely asserted to
      //          translate — that string *is* the translation layer's product, and the standing
      //          comma accident (§3.3) came exactly from "the screen says 8 numbers and the engine
      //          computes 4 of them".
      const app = 'linearfit(matrix(1,4,1,100,2,200),matrix(1,4,3,300,4,400))';
      final translated = engineExpressionFor(app);
      expect(translated, isA<TranslatedExpression>());
      expect((translated as TranslatedExpression).text,
          'linearfit(matrix(1,4,1,100,2,200),matrix(1,4,3,300,4,400))');
    });

    test('两行形状被拒——两种 n 各一条，两种印出来的东西都是错的', () {
      // 中文：**这两条就是这一轮要关掉的那个洞**（宿主实测，种类判据照抄 `QalculateEngine.kt`）：
      //       - n>2：`linearfit(matrix(2,5,…))` → `[x  2x  3x  4x  5x]`，种类 `structured`；
      //       - n=2：`linearfit(matrix(2,2,1,2,3,4))` → `x + 1`，种类 `symbolic`。
      //       **两者 `isDisplayable` 都放行**，所以它们本来会直接上结果行。第二行尤其要紧：
      //       上一轮的报告写着「n=2 时两行与两列是同一个布局，所以碰巧对」——**那是错的**，
      //       正解是 `x + 2`，引擎给的是按**列**读的那一份。
      // English: **these two are the hole this round closes** (host-measured, the kind predicate copied
      //          from `QalculateEngine.kt`): for n>2 `linearfit(matrix(2,5,…))` → `[x  2x  3x  4x  5x]`,
      //          kind `structured`; for n=2 `linearfit(matrix(2,2,1,2,3,4))` → `x + 1`, kind `symbolic`.
      //          **`isDisplayable` admits both**, so they would have gone straight onto the result
      //          line. The second matters most: last round's report says "at n=2 the two-row and
      //          two-column layouts are the same, so it happens to be right" — **that is false**; the
      //          answer is `x + 2` and the engine gives the column reading.
      for (final twoRow in <String>[
        'linearfit(matrix(2,5,1,2,3,4,5,2,4,6,8,10))',
        'linearfit(matrix(2,2,1,2,3,4))',
        'quadraticfit(matrix(2,3,1,2,3,1,4,9))',
        'cubicfit(matrix(2,4,1,2,3,4,1,8,27,64))',
      ]) {
        expect(engineExpressionFor(twoRow), isA<UntranslatableExpression>(),
            reason: '`$twoRow` 的实参不是一行矩阵，引擎读成另一件事');
      }
    });

    test('第二个实参多行也被拒——「只管第一个实参」是错的', () {
      // 中文：**这一条是这一轮量出来的，而它推翻了简报里那一句话。** 简报把危险说成「HiPER 的
      //       两行形状喂给拟合」——第一个实参。实测：**第二个**实参多行同样返回一个向量，照样
      //       上屏：`linearfit(matrix(1,3,1,2,3),matrix(3,3,1,2,3,4,5,6,7,8,9))` →
      //       `[(3x - 2)  (3x - 1)  3x]`，种类 `structured`。
      //       （第二个实参是**两**行时反而退回原样、种类 `arithmetic`、不显示——同样是量出来的。）
      // English: **this one is a product of this round, and it overturns a sentence in the brief.** The
      //          brief describes the danger as "HiPER's two-row shape fed to the fits" — the first
      //          argument. Measured: a multi-row **second** argument also comes back as a vector and
      //          reaches the screen: `linearfit(matrix(1,3,1,2,3),matrix(3,3,1,2,3,4,5,6,7,8,9))` →
      //          `[(3x - 2)  (3x - 1)  3x]`, kind `structured`. (A **two**-row second argument is
      //          handed straight back with kind `arithmetic` and is not displayed — also measured.)
      const hazard = 'linearfit(matrix(1,3,1,2,3),matrix(3,3,1,2,3,4,5,6,7,8,9))';
      expect(engineExpressionFor(hazard), isA<UntranslatableExpression>());
    });

    test('括号先剥掉：正确的写法收下，危险的写法仍被拒', () {
      // 中文：剥括号是**量过**的，不是顺手：`linearfit((matrix(1,5,…)),matrix(1,5,…))` 实测印的
      //       正是 `2x`，而 `linearfit((matrix(2,5,…)))` 实测仍在 else 那一支上（印向量）。
      //       所以「剥掉再看」两侧都对；不剥的话，前一条会变成一句错误——一个值该在的地方是错误。
      // English: stripping parentheses is **measured**, not a flourish:
      //          `linearfit((matrix(1,5,…)),matrix(1,5,…))` measures `2x` and
      //          `linearfit((matrix(2,5,…)))` measures the else branch (a vector). Stripping is right
      //          in both directions; without it the first would become an error — an error where a
      //          value belongs.
      expect(engineExpressionFor(
        'linearfit((matrix(1,5,1,2,3,4,5)),(matrix(1,5,2,4,6,8,10)))',
      ), isA<TranslatedExpression>());
      expect(engineExpressionFor('linearfit((matrix(2,5,1,2,3,4,5,2,4,6,8,10)))'),
          isA<UntranslatableExpression>());
    });

    test('形状之外的名字一个字都没放宽：别的名字照旧', () {
      // 中文：**这条判据只作用于那三行**，所以别的名字的接受/拒绝一个字节都没动。抽两个对照：
      //       `mean`（词表里，形状不限）与 `npr`（词表里、两列都是「不可用」，照旧拒绝）。
      // English: **the judgement acts on those three rows only**, so every other name's
      //          accept/refuse is byte for byte what it was. Two controls: `mean` (in the vocabulary,
      //          no shape rule) and `npr` (in the vocabulary, unusable in both columns, still refused).
      expect(engineExpressionFor('mean(1,2,3)'), isA<TranslatedExpression>());
      expect(engineExpressionFor('mean(matrix(2,3,1,2,3,4,5,6))'),
          isA<TranslatedExpression>());
      expect(engineExpressionFor('npr(2,1)'), isA<UntranslatableExpression>());
    });
  });

  group('数据集 → 那一条调用', () {
    test('切法就是两行那一种，只是形状换成两个行矩阵', () async {
      final controller = _controller(_FakeDatabase(), engine: _engine);
      await _seed(controller, <String>['1', '2', '100', '200']);

      expect(controller.fitCall('linearfit'),
          'linearfit(matrix(1,2,1,2),matrix(1,2,100,200))');
      // 中文：**与 `regressionCall` 逐字对照**——同一串值、同一种切法，形状不同。这一条把
      //       「两个行矩阵」与「一个两行矩阵」的分别钉在屏幕上，改回两行会当场红。
      // English: **side by side with `regressionCall`** — the same values and the same cut, a different
      //          shape. This pins the "two row matrices" vs "one two-row matrix" difference on screen;
      //          reverting to two rows turns it red at once.
      expect(controller.regressionCall('pearson'),
          'pearson(matrix(2,2,1,2,100,200))');
      controller.dispose();
    });

    test('下限按函数分开：2/3/4，一个共用的下限会让两格说谎', () async {
      // 中文：**这三个数字来自引擎自己的 `<condition>`，而且是量出来的**：一个行向量
      //       `matrix(1,n,…)` 的 `dimension` 就是 `n`，所以 n=2 时 `quadraticfit` 原样退回
      //       （种类 `arithmetic`，不显示）——屏幕上会是一句错误。共用下限就等于让那两格
      //       各按下去插一条答不出来的调用。
      // English: **the three numbers come from the engine's own `<condition>` and are measured**: a row
      //          vector `matrix(1,n,…)` has `dimension` `n`, so at n=2 `quadraticfit` comes straight
      //          back (kind `arithmetic`, not displayed) — an error on screen. A shared floor would
      //          make those two cells each insert a call the engine cannot answer.
      final controller = _controller(_FakeDatabase(), engine: _engine);
      await _seed(controller, <String>['1', '2', '100', '200']);

      expect(controller.fitCall('linearfit'), isNotNull, reason: '2 对：够');
      expect(controller.fitCall('quadraticfit'), isNull, reason: '2 对：不够（要 3）');
      expect(controller.fitCall('cubicfit'), isNull, reason: '2 对：不够（要 4）');

      await _seed(controller, <String>['1', '2', '3', '100', '200', '300']);
      expect(controller.fitCall('quadraticfit'),
          'quadraticfit(matrix(1,3,1,2,3),matrix(1,3,100,200,300))');
      expect(controller.fitCall('cubicfit'), isNull, reason: '3 对：还是不够（要 4）');

      await _seed(
          controller, <String>['1', '2', '3', '4', '100', '200', '300', '400']);
      expect(controller.fitCall('cubicfit'),
          'cubicfit(matrix(1,4,1,2,3,4),matrix(1,4,100,200,300,400))');
      controller.dispose();
    });

    test('读不成两行时三格都插不进去，而且理由说出来、与上面那三格的措辞不同', () async {
      final controller = _controller(_FakeDatabase(), engine: _engine);

      expect(controller.fitCall('linearfit'), isNull);
      expect(controller.fitStatusMessage, contains('linearfit 要 2 对'));
      expect(controller.fitStatusMessage, contains('quadraticfit 要 3 对'));
      expect(controller.fitStatusMessage, contains('cubicfit 要 4 对'));

      await _seed(controller, <String>['1', '2', '3']);
      expect(controller.fitCall('linearfit'), isNull, reason: '奇数个值读不成两行');
      expect(controller.fitStatusMessage, contains('需要偶数个值'));
      expect(controller.fitStatusMessage, contains('当前有 3 个'));
      // 中文：两句话会同时出现在面板上，所以它们**不许共用一串字符**——共用的话
      //       `find.textContaining` 那几条断言就分不清屏幕上那句话说的是哪一行。
      // English: both sentences sit on the sheet at once, so they may **not share a run of
      //          characters** — sharing would leave `find.textContaining` unable to tell which row a
      //          sentence is about.
      expect(controller.fitStatusMessage,
          isNot(contains('现在数据集是空的')));
      expect(controller.fitStatusMessage, isNot(contains('需要偶数个值，现在有')));
      controller.dispose();
    });

    test('未知函数名给 `null`，不抛异常（`fitCall` 是唯一那一处判据）', () async {
      final controller = _controller(_FakeDatabase(), engine: _engine);
      await _seed(controller, <String>['1', '2', '100', '200']);
      expect(controller.fitCall('zorkmid'), isNull);
      controller.dispose();
    });
  });

  group('上屏之后：一个函数，排得出来，而且不是数', () {
    test('提交 `linearfit(…)`：屏幕上就是引擎那一份 `2x`，TeX 排得出来', () async {
      // 中文：`2x` 是**这一轮新放行**的那一类（应用自己的求值器没有绑定 `linearfit`/`matrix`，
      //       所以 `canExpress` 为假 ⇒ 引擎的 `symbolic` 答复留下）。这一条走的是**提交路径**，
      //       替身回执与宿主印出来的那一份逐字节相同。
      // English: `2x` is the class **this round newly admits** (this app's own evaluator binds neither
      //          `linearfit` nor `matrix`, so `canExpress` is false ⇒ the engine's `symbolic` answer
      //          stays). This goes through the **submit path**, and the stub receipt is byte for byte
      //          what the host prints.
      final engine = _FakeMathEngine(
        const _Reply('2x', tex: '2x', kind: EngineResultKind.symbolic).reply,
      );
      final controller = _controller(_FakeDatabase(), engine: engine);
      await _seed(controller, <String>['1', '2', '3', '100', '200', '300']);

      controller.setExpression(controller.fitCall('linearfit')!);
      await controller.submit();

      expect(controller.result, '2x');
      expect(controller.resultTex, '2x');
      expect(MathExpressionView.typesetsTex(controller.resultTex), isTrue,
          reason: '新放行的答案排不出来就不算改进');
      // 中文：**它绝不能被当成数**（硬性边界 5）。`decimalText` 是空的，所以 `Ans`/`last`
      //       与数据集那道门都不会收它——这一条与 `MathResult.decimalValueOf` 是同一条判据。
      // English: **it must never be taken for a number** (hard boundary 5). `decimalText` is empty, so
      //          neither `Ans`/`last` nor the dataset's door takes it — the same judgement as
      //          `MathResult.decimalValueOf`.
      expect(controller.reusableResult, isNotNull);
      expect(controller.storableDatasetValue, isNull,
          reason: '一个函数不是数，数据集那道门必须挡住它');
      controller.dispose();
    });

    test('三个拟合实测的 LaTeX 都排得出来（逐条量自宿主）', () {
      // 中文：表格驱动，**每一条都是宿主在同一个调用序列下印出来的那份 LaTeX**——只断言
      //       `typesetsTex` 会漏掉「印的是别的东西」这一类，所以字符串本身也钉住。
      // English: table-driven, and **every row is the LaTeX the host printed under the same call
      //          sequence** — asserting `typesetsTex` alone would miss "it printed something else", so
      //          the strings themselves are pinned too.
      const rows = <(String, String)>[
        ('linearfit(matrix(1,5,1,2,3,4,5),matrix(1,5,2,4,6,8,10))', '2x'),
        ('linearfit(matrix(1,5,1,2,3,4,5),matrix(1,5,1,4,9,16,25))', '6x - 7'),
        ('quadraticfit(matrix(1,3,10,20,30),matrix(1,3,1,4,9))', '0.01x^{2}'),
        ('cubicfit(matrix(1,4,1,2,3,4),matrix(1,4,1,8,27,64))', 'x^{3}'),
      ];
      for (final (call, tex) in rows) {
        expect(MathExpressionView.typesetsTex(tex), isTrue,
            reason: '`$call` 的 LaTeX `$tex` 排不出来');
      }
    });

    test('引擎答不出来时回落旧解析器并报错——绝不猜一个函数出来', () async {
      // 中文：硬性边界 1。旧解析器没有实现这三个名字（实测 `linearfit(1)` 抛
      //       `FormatException: Unknown function linearfit`），所以引擎缺席时屏幕上是一句错误。
      //       **失败是关上的**：这条路上没有任何东西能变成一个看起来合理的答案。
      // English: hard boundary 1. The legacy parser does not implement these names (measured:
      //          `linearfit(1)` throws `FormatException: Unknown function linearfit`), so an absent
      //          engine means an error on screen. **Failure is closed**: nothing on this path can turn
      //          into a plausible-looking answer.
      final controller = _controller(
        _FakeDatabase(),
        engine: _FakeMathEngine(_failure),
      );
      await _seed(controller, <String>['1', '2', '100', '200']);

      controller.setExpression(controller.fitCall('linearfit')!);
      await controller.submit();

      expect(controller.hasError, isTrue,
          reason: '旧解析器读不懂 `linearfit`，这一条只能是一句错误');
      expect(controller.result, isNot(contains('2x')),
          reason: '失败是关上的：屏幕上不许出现一个看起来合理的函数');
      controller.dispose();
    });
  });
}

class _Reply {
  const _Reply(this.displayText, {required this.tex, required this.kind});

  final String displayText;
  final String tex;
  final EngineResultKind kind;

  EngineReply get reply => EngineReply.success(MathResult(
        displayText: displayText,
        displayTex: tex,
        decimalText:
            MathResult.decimalTextIsFinite(displayText) ? displayText : '',
        resultKind: kind,
      ));
}

final EngineReply _failure = EngineReply.failure('engine unavailable');

final _FakeMathEngine _engine = _FakeMathEngine(_failure);

/// 中文：**把数据集填成给定的那几个值。** 走的是真实路径（屏幕上那一次结果 → `addDatasetValue`），
///       不是直接塞字段——值进数据集只有那一道门，测它就得走那道门。
/// English: **fill the dataset with the given values.** It goes through the real path (the result on
///          screen → `addDatasetValue`) rather than poking the field: there is exactly one door into
///          the dataset, and testing it means walking through that door.
Future<void> _seed(CalculatorController controller, List<String> values) async {
  controller.clearDataset();
  for (final value in values) {
    controller.setExpression(value);
    await controller.submit();
    final refusal = controller.addDatasetValue();
    if (refusal != null) throw StateError('数据集拒了 `$value`：$refusal');
  }
}

class _FakeMathEngine implements MathEngine {
  _FakeMathEngine(this.reply);

  EngineReply reply;

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
  AppDatabase db, {
  required MathEngine engine,
}) =>
    CalculatorController(
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
