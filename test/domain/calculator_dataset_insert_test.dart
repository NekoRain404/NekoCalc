import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/core/math/app_engine_vocabulary.dart';
import 'package:nekocalc/core/math/engine_expression.dart';
import 'package:nekocalc/core/math/expression_parser.dart';
import 'package:nekocalc/core/math/math_result.dart';

import 'calculator_dataset_fakes.dart';

/// 中文：**面板插进去的那一条调用**——`DATASET` 面板把数据集里的数拼成一条引擎调用插进表达式，以及
///       那条调用要用的名字在词表与翻译层里的位置。它与 `calculator_dataset_test.dart`（那个存放处
///       自己的四件事：谁进得来、撤销栈、盘上怎么写、它不做什么）是两件事：这一份测的是**读它的人**
///       ——面板怎么把它拼成调用、那一串数送去引擎时长什么样、名字认不认得。
///
///       **断言一条没动**：两组的每一条 `expect`、每一个 `reason` 与那两条「引擎缺席时回落旧解析器」
///       的用法都逐字搬了过来；几只假货搬进了 `calculator_dataset_fakes.dart`（它们本身也逐字未改，
///       只有私有名字变成公开名字）。
///
/// English: **the call the sheet inserts** — the `DATASET` panel assembling the dataset's numbers into
///          one engine call and inserting it, plus where the names that call needs sit in the
///          vocabulary and the translation layer. That is a different thing from
///          `calculator_dataset_test.dart` (the store's own four questions: who gets in, the undo
///          stack, how it is written to disk, what it does not do): this file tests **its reader** —
///          how the panel assembles it, what the string sent to the engine looks like, and whether
///          the names are recognised.
///
///          **Not one assertion moved**: every `expect`, every `reason` and both "the engine is absent,
///          the legacy parser answers" cases came across character for character; the fakes moved into
///          `calculator_dataset_fakes.dart` (themselves unchanged, only their private names made
///          public).
void main() {
  group('面板插进去的那一条调用', () {
    test('数据集为空时插的是起手数据——与本轮之前逐字节相同', () {
      final controller =
          datasetController(DatasetFakeDatabase(), engine: DatasetFakeMathEngine(datasetEngineUnavailable));

      expect(controller.datasetCallArguments, '1,2,3,4');
      expect(controller.statisticsCall('mean'), 'mean(1,2,3,4)');
      expect(controller.statisticsCall('stdev'), 'stdev(1,2,3,4)');

      controller.dispose();
    });

    test('数据集非空时插的是它那几个值，顺序就是加入的顺序', () async {
      final controller = datasetController(
        DatasetFakeDatabase(),
        engine: DatasetFakeMathEngine(datasetEngineUnavailable),
        storedDataset: '["5","12","13"]',
      );
      await controller.restoreIfEnabled();

      expect(controller.datasetCallArguments, '5,12,13');
      expect(controller.statisticsCall('mean'), 'mean(5,12,13)');
      expect(controller.statisticsCall('median'), 'median(5,12,13)');

      controller.dispose();
    });

    test('插进去的数逐字是引擎那串十进制，不按精度取整', () async {
      // 中文：按 `AppSettings.precision`（这里是 6）取整会让插进去的调用与数据集里存的那个数不是
      //       同一个数——1/3 会变成 0.333333，引擎算的东西与屏幕上的东西就此分叉。
      // English: rounding by `AppSettings.precision` (6 here) would make the inserted call hold a
      //          different number from the one stored in the dataset — 1/3 would become 0.333333 and
      //          the engine's arithmetic would fork away from what is on screen.
      final engine = DatasetFakeMathEngine(
        const DatasetFakeReply('0.3333333333333333', kind: EngineResultKind.number).reply,
      );
      final controller = datasetController(DatasetFakeDatabase(), engine: engine);

      controller.setExpression('1/3');
      await controller.submit();
      controller.addDatasetValue();

      expect(controller.statisticsCall('mean'), 'mean(0.3333333333333333)');

      controller.dispose();
    });

    // 中文：**同一个数据集的第二种读法**——两行（前一半 X、后一半 Y），给 `pearson`/`covar`/
    //       `spearman` 那三格用。这一组钉的是三件事：形状（一个 `matrix(2,n,…)`）、切法（按行，
    //       前一半是第一行）、以及**读不成两行时拒绝而不是凑一个**。
    // English: **the second reading of the same dataset** — two rows (the first half X, the second
    //          half Y), for the `pearson`/`covar`/`spearman` cells. This group pins three things: the
    //          shape (one `matrix(2,n,…)`), the cut (row by row, the first half is the first row), and
    //          **a refusal rather than a make-do while the dataset cannot be read as two rows**.
    test('数据集读成两行时，插的是一个两行矩阵，前一半是 X、后一半是 Y', () async {
      final controller = datasetController(
        DatasetFakeDatabase(),
        engine: DatasetFakeMathEngine(datasetEngineUnavailable),
        storedDataset: '["1","100","2","200","3","300","4","400"]',
      );
      await controller.restoreIfEnabled();

      expect(controller.datasetPairCount, 4);
      expect(controller.canReadDatasetAsTwoRows, isTrue);
      expect(controller.regressionCall('pearson'),
          'pearson(matrix(2,4,1,100,2,200,3,300,4,400))');
      expect(controller.regressionCall('covar'),
          'covar(matrix(2,4,1,100,2,200,3,300,4,400))');
      expect(controller.regressionCall('spearman'),
          'spearman(matrix(2,4,1,100,2,200,3,300,4,400))');

      // 中文：四格那一边**一个字符都没变**——两种读法读的是同一串值，切法不同而已。
      // English: the four cells' side is **not one character different** — both readings read the same
      //          run of values, only the cut differs.
      expect(
          controller.statisticsCall('mean'), 'mean(1,100,2,200,3,300,4,400)');

      controller.dispose();
    });

    test('读不成两行时拒绝：空、奇数个、只有一对，三种都返回 null 并说出理由', () async {
      // 中文：一对为什么不算数——**量出来的**：宿主 `qalc` 5.12.0 上 `pearson(matrix(2,1,1,2))`
      //       给的是未求值的 `0 / 0`（一个式子，不是数），`covar(matrix(2,1,1,2))` 给一个没有信息
      //       的 `0`。两句都不是用户要的答案，所以这里直接拒绝，而不是把 `0` 放上屏。
      // English: why one pair does not count — **measured**: on the host `qalc` 5.12.0
      //          `pearson(matrix(2,1,1,2))` returns the unevaluated `0 / 0` (an expression, not a
      //          number) and `covar(matrix(2,1,1,2))` returns an uninformative `0`. Neither is the
      //          answer the user wants, so it is refused here rather than putting a `0` on screen.
      for (final stored in <String>[
        '[]',
        '["5"]',
        '["5","12"]',
        '["5","12","13"]'
      ]) {
        final controller = datasetController(
          DatasetFakeDatabase(),
          engine: DatasetFakeMathEngine(datasetEngineUnavailable),
          storedDataset: stored,
        );
        await controller.restoreIfEnabled();

        expect(controller.canReadDatasetAsTwoRows, isFalse,
            reason: '`$stored` 读不成两行');
        expect(controller.regressionCall('pearson'), isNull,
            reason: '读不成两行时不能拼出一条调用来——拼出来就是一条引擎答不出来的式子');
        expect(controller.regressionUnavailableMessage, isNotEmpty,
            reason: '拒绝必须被说出来，否则用户看到的是三格不解释自己的灰键');
        controller.dispose();
      }
    });

    test('四个值（两对）起就成立，上限跟着 kMaxDatasetValues 走', () async {
      final controller = datasetController(
        DatasetFakeDatabase(),
        engine: DatasetFakeMathEngine(datasetEngineUnavailable),
        storedDataset: '["1","3","2","4"]',
      );
      await controller.restoreIfEnabled();

      expect(controller.canReadDatasetAsTwoRows, isTrue);
      expect(controller.regressionCall('covar'), 'covar(matrix(2,2,1,3,2,4))');

      controller.dispose();
    });

    test('送去引擎的那一串里，两行矩阵的逗号一个都没被吃掉', () async {
      // 中文：**这一条钉的是真正会上屏的那个值。** 屏幕上那串文本是原样的（表达式里存的是它），
      //       被归一化吃掉逗号的是**送去引擎的那一份**——所以只断言 `regressionCall` 的文本是
      //       抓不住这个错值的（我第一版就是这样，把 `matrix` 从 `_variadicFunctions` 里删掉之后
      //       它照样绿）。这里钉的是**翻译产物**，也就是引擎真正读到的那个式子。
      //
      //       三个「逗号后面正好三位数字」的组合都在：`1,100`、`2,200`、`3,300`。没有 `matrix`
      //       那一行时它们分别并成 `1100`/`2200`/`3300`——矩阵从 8 个值变成 5 个，而引擎照样
      //       答得出一个数（对两列数据来说那就是**另一个**相关系数）。**看着像答案的错值。**
      // English: **this pins the value that actually reaches the screen.** The text on screen is
      //          verbatim (that is what the expression stores); what the normalisation eats the commas
      //          out of is **the copy sent to the engine** — so asserting on `regressionCall`'s text
      //          alone cannot catch this wrong value (that was my first version, and it stayed green
      //          with `matrix` deleted from `_variadicFunctions`). What is pinned here is the
      //          **translation product**, the expression the engine really reads.
      //
      //          All three "comma followed by exactly three digits" conjunctions are present: `1,100`,
      //          `2,200`, `3,300`. Without the `matrix` line they merge into `1100`/`2200`/`3300` — the
      //          matrix goes from eight values to five, and the engine still answers with a number
      //          (for two columns of data that is a **different** correlation coefficient). **A
      //          plausible-looking wrong value.**
      final controller = datasetController(
        DatasetFakeDatabase(),
        engine: DatasetFakeMathEngine(datasetEngineUnavailable),
        storedDataset: '["1","100","2","200","3","300","4","400"]',
      );
      await controller.restoreIfEnabled();
      final call = controller.regressionCall('pearson')!;

      expect(ExpressionParser.normalizeExpressionInput(call), call,
          reason: '归一化不许动这条调用里的逗号');
      final translated = engineExpressionFor(call);
      expect(translated, isA<TranslatedExpression>());
      expect((translated as TranslatedExpression).text, call,
          reason: '送去引擎的那一串必须是原样的两行矩阵');

      controller.dispose();
    });

    test('三个名字都在词表里，翻译层真的把它们送去引擎', () {
      // 中文：**名字不是猜的**。HiPER 那边叫 `LINEAR_REG`/`PEARSON`…，而引擎里
      //       `grep -rni "regression"` 一处都没有；这三个是 `functions.xml.in` 里的真名
      //       （`<title>Correlation</title>` / `<title>Covariance</title>` 那两节）。
      //       不折进词表的话翻译层会拒绝它们（「标识符不在应用词汇表里，不送去让引擎猜」），
      //       引擎**根本不会被问**，屏幕上是一句错误。
      // English: **the names are not guessed.** HiPER calls them `LINEAR_REG`/`PEARSON`…, while
      //          `grep -rni "regression"` finds nothing at all in the engine; these three are the real
      //          names in `functions.xml.in` (the `<title>Correlation</title>` /
      //          `<title>Covariance</title>` sections). Without the vocabulary entries the translation
      //          layer refuses them ("identifier not in the app's vocabulary, not sent for the engine to
      //          guess at"), the engine is **never asked**, and the screen shows an error.
      for (final name in <String>['pearson', 'covar', 'spearman']) {
        expect(AppEngineVocabulary.identifiers, contains(name));
        final translated = engineExpressionFor(
          '$name(matrix(2,2,1,3,2,4))',
        );
        expect(translated, isA<TranslatedExpression>(),
            reason: '`$name` 本该翻译得了');
        expect(
            AppEngineVocabulary.canRead('$name(matrix(2,2,1,3,2,4))'), isTrue);
      }
    });

    test('三个拟合函数现在提供了，而且只在一种形状下（判决与拒绝都在翻译层）', () {
      // 中文：**这条上一轮钉的是「不提供」，拟合那一轮把它翻了过来。** 现在是三件事：
      //       ① **三个名字都在词表里**，判据（`canRead`/`canExpress`）都不再挡它们；
      //       ② **翻译层只管一种形状**：每个实参都得是一行矩阵，理由与实测表在
      //       `engine_expression.dart` 的 `_seriesShapeRefusal` 上；
      //       ③ **两行形状被拒**——那是两件事共用一个形状：`linearfit(matrix(2,5,…))` 印出向量
      //       `[x 2x 3x 4x 5x]`（`structured`，可显示），`linearfit(matrix(2,2,1,2,3,4))` 印出
      //       `x + 1`（X、Y 反了，正解 `x + 2`，`symbolic`，也可显示）。
      //       断言没有削弱：上一轮那条 `isNot(contains(name))` 在这里**反过来**了，而不是被删掉。
      // English: **this pinned "not provided" last round; the fitting round turned it over.** It is
      //          now three things: ① **all three names are in the vocabulary**, and neither judgement
      //          (`canRead`/`canExpress`) blocks them any more; ② **the translation layer allows one
      //          shape only** — every argument must be a one-row matrix, the reasons and the
      //          measurement table are on `_seriesShapeRefusal` in `engine_expression.dart`; ③ **the
      //          two-row shape is refused**, and that is two things sharing one shape:
      //          `linearfit(matrix(2,5,…))` prints the vector `[x 2x 3x 4x 5x]` (`structured`,
      //          displayable) and `linearfit(matrix(2,2,1,2,3,4))` prints `x + 1` (X and Y swapped; the
      //          answer is `x + 2`; `symbolic`, also displayable). No assertion is weakened: last
      //          round's `isNot(contains(name))` is **inverted** here rather than deleted.
      const fit = 'linearfit(matrix(1,5,1,2,3,4,5),matrix(1,5,2,4,6,8,10))';
      for (final name in <String>['linearfit', 'quadraticfit', 'cubicfit']) {
        expect(AppEngineVocabulary.identifiers, contains(name));
        expect(
            AppEngineVocabulary.identifiers[name]!.oneSeriesPerArgument, isTrue,
            reason: '`$name` 的实参形状要按格判，所以这一列必须为真');
      }
      expect(AppEngineVocabulary.canRead(fit), isTrue);
      expect(AppEngineVocabulary.canExpress(fit), isFalse,
          reason: '应用自己的求值器没有绑定 `linearfit`/`matrix`，所以这份 `symbolic` 答复不再被丢掉');
      expect(engineExpressionFor(fit), isA<TranslatedExpression>(),
          reason: '两个行矩阵正是翻译层认的那一种形状');
      // 中文：两行形状——两种 n 各拒一次（向量那一支与 X/Y 反了那一支）。
      // English: the two-row shape — refused once per n (the vector branch and the swapped-X/Y one).
      for (final twoRow in <String>[
        'linearfit(matrix(2,5,1,2,3,4,5,2,4,6,8,10))',
        'linearfit(matrix(2,2,1,2,3,4))',
      ]) {
        expect(engineExpressionFor(twoRow), isA<UntranslatableExpression>(),
            reason: '`$twoRow` 的两行形状引擎读成另一件事，答案照样上屏');
      }
    });

    test('引擎缺席时，两变量那条调用回落旧解析器并报错——绝不猜一个数', () async {
      // 中文：与上面四格那条逐字同形。旧解析器没有实现 `pearson`/`covar`/`spearman`
      //       （实测：`pearson(1)` 抛 `FormatException: Unknown function pearson`），
      //       所以引擎答不出来时屏幕上是一句错误。
      // English: the same shape, word for word, as the four cells' test above. The legacy parser does
      //          not implement `pearson`/`covar`/`spearman` (measured: `pearson(1)` throws
      //          `FormatException: Unknown function pearson`), so an absent engine means an error on
      //          screen.
      final controller = datasetController(
        DatasetFakeDatabase(),
        engine: DatasetFakeMathEngine(datasetEngineUnavailable),
        storedDataset: '["1","2","3","4","5","6"]',
      );
      await controller.restoreIfEnabled();

      controller.setExpression(controller.regressionCall('pearson')!);
      expect(controller.expression, 'pearson(matrix(2,3,1,2,3,4,5,6))');
      await controller.submit();

      expect(controller.hasError, isTrue,
          reason: '旧解析器读不懂 `pearson`，这一条只能是一句错误');
      expect(controller.result, isNot(contains('1.0')));

      controller.dispose();
    });

    test('引擎缺席时，数据集拼出来的那条调用回落旧解析器并报错——绝不猜一个数', () async {
      // 中文：硬性边界 2 在这一条新路上的形式。数据集拼出来的 `mean(5,12)` 走的是与面板其余各格
      //       完全一样的那条路，而旧解析器**没有实现** `mean`（上一轮逐个量过：八个名字它一律
      //       `throwsA(isA<FormatException>())`）。所以「引擎答不出来」的后果是一句错误，绝不是一个
      //       看起来合理的数字——这正是硬性边界 4 要的 fail closed。
      // English: hard boundary 2's form on this new path. The `mean(5,12)` the dataset builds travels
      //          exactly the path the sheet's other cells do, and the legacy parser **does not
      //          implement** `mean` (measured name by name last round: all eight throw
      //          `FormatException`). So "the engine cannot answer" ends in an error, never in a
      //          plausible-looking number — which is what hard boundary 4 asks for.
      final controller = datasetController(
        DatasetFakeDatabase(),
        engine: DatasetFakeMathEngine(datasetEngineUnavailable),
        storedDataset: '["5","12"]',
      );
      await controller.restoreIfEnabled();

      controller.setExpression(controller.statisticsCall('mean'));
      expect(controller.expression, 'mean(5,12)');
      await controller.submit();

      expect(controller.hasError, isTrue, reason: '旧解析器读不懂 `mean`，这一条只能是一句错误');
      expect(controller.result, isNot(contains('10')));

      controller.dispose();
    });
  });
}
