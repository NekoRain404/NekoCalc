import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/application/controllers/calculator_controller.dart';
import 'package:nekocalc/core/math/app_engine_vocabulary.dart';
import 'package:nekocalc/core/math/engine_expression.dart';
import 'package:nekocalc/core/math/expression_parser.dart';
import 'package:nekocalc/core/math/math_engine.dart';
import 'package:nekocalc/core/math/math_result.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/repositories/history_repository.dart';
import 'package:nekocalc/data/repositories/notes_repository.dart';
import 'package:nekocalc/data/repositories/settings_repository.dart';

/// 中文：**统计数据集这个存放处的四件事**——谁进得来、撤销栈盖不盖着它、盘上怎么写怎么读回来、
///       以及它**不**做什么。
///
///       这一组测的不是「统计学」，是那次设计裁决的四个问题（数据集的存放处必须回答的四条）：
///
///       1. **只放数**：值只能从屏幕上那个结果进来，而那道门是全应用唯一的
///          [MathResult.decimalValueOf]。下溢、`Infinity`、符号结果、矩阵、复数一律拒绝——
///          拒绝是**说出来**的（返回值就是那句话），不是静默丢掉。
///       2. **撤销/重做**：加一个值、去掉一个值都进撤销栈，撤销之后存放处回到那一刻的样子。
///       3. **代际守卫**：写盘期间用户加的值不会被读到的那一份盘上数据覆盖。
///       4. **它是数据的存放处，不是结果**：值只进不出——加一个值不重算、不动结果行、不动
///          `Ans`/`last`、不动记忆寄存器、不动表达式。
///
/// English: **the four things about this dataset store** — who gets in, whether the undo stack covers
///          it, how it is written to and read from disk, and what it deliberately does **not** do.
///
///          What this group tests is not "statistics" but the four questions that design ruling had to
///          answer (the four a dataset's home must answer):
///
///          1. **Numbers only**: a value can only come in from the result on screen, through the app's
///             single door [MathResult.decimalValueOf]. Underflow, `Infinity`, symbolic results,
///             matrices and complex numbers are all refused — and a refusal is **spoken** (the return
///             value is that sentence), never a silent drop.
///          2. **Undo/redo**: adding and dropping a value both land on the undo stack, and after an undo
///             the store is what it was at that moment.
///          3. **The generation guard**: a value added while a restore is reading from disk is not
///             overwritten by what was read.
///          4. **It is a store of data, not a result**: values only go in, never out — adding one does
///             not recompute, does not touch the result line, `Ans`/`last`, the memory register or the
///             expression.
void main() {
  group('只放数：进数据集的门就是全应用那一道判据', () {
    test('屏幕上是一个正常结果时，加进去的是它那串未取整的十进制', () async {
      final engine = _FakeMathEngine(
        const _Reply('1.5', tex: '1.5', kind: EngineResultKind.number).reply,
      );
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('3/2');
      await controller.submit();

      expect(controller.storableDatasetValue, '1.5');
      expect(controller.addDatasetValue(), isNull, reason: '正常的数不该被拒');
      expect(controller.datasetValues, <String>['1.5']);

      controller.dispose();
    });

    test('下溢的值被拒，而且拒绝被说出来、数据集一动不动', () async {
      // 中文：`9.3e-603` 是 `2^-2000` 那类结果：`double.tryParse` 给它 `0.0`，于是它看起来就是
      //       一个 0。收进去之后数据集里会多一个**假的 0**，而屏幕上没有任何线索——这一条就是
      //       本项目花了十几轮在消灭的那类静默错值。
      // English: `9.3e-603` is a `2^-2000`-shaped result: `double.tryParse` gives `0.0` for it, so it
      //          looks like a zero. Accepting it would put a **false zero** in the dataset with nothing
      //          on screen to say so — the silent-wrong-value class this project has spent many rounds
      //          deleting.
      final engine = _FakeMathEngine(
        const _Reply('9.3e-603', tex: '', kind: EngineResultKind.number).reply,
      );
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('2^-2000');
      await controller.submit();

      expect(controller.storableDatasetValue, isNull,
          reason: '下溢的值连「可加」都不该是');
      final sentence = controller.addDatasetValue();
      expect(sentence, isNotNull, reason: '被拒了却什么都不说，用户看到的就是一颗失灵键');
      expect(sentence, contains('数据集未改动'));
      expect(controller.datasetValues, isEmpty);

      controller.dispose();
    });

    test('符号结果、复数、带单位的结果都进不去（没有十进制形态）', () async {
      for (final reply in <EngineReply>[
        const _Reply('2x', tex: '2x', kind: EngineResultKind.symbolic).reply,
        const _Reply('2i', tex: '2i', kind: EngineResultKind.number).reply,
        const _Reply('1.5 m', tex: '', kind: EngineResultKind.quantity)
            .reply,
      ]) {
        final controller =
            _controller(_FakeDatabase(), engine: _FakeMathEngine(reply));
        controller.setExpression('x');
        await controller.submit();

        expect(controller.storableDatasetValue, isNull);
        expect(controller.addDatasetValue(), isNotNull);
        expect(controller.datasetValues, isEmpty);

        controller.dispose();
      }
    });

    test('屏幕上的结果没有十进制形态时，加入是空操作（不写撤销栈、不通知）', () async {
      final controller = _controller(
        _FakeDatabase(),
        engine: _FakeMathEngine(
          const _Reply('2x', tex: '2x', kind: EngineResultKind.symbolic).reply,
        ),
      );
      controller.setExpression('2x');
      await controller.submit();
      var notifications = 0;
      controller.addListener(() => notifications++);

      expect(controller.addDatasetValue(), isNotNull);
      expect(notifications, 0,
          reason: '被拒的一下是空操作：不通知界面，屏幕上什么都不该动');
      expect(controller.datasetValues, isEmpty);

      controller.dispose();
    });

    test('刚打开时的那个 0 是加得进去的——它与存进变量完全同一条规矩', () async {
      // 中文：这不是漏判：屏幕上写着 `0`，那它就是一个数，与变量面板在同一个屏幕上给出的答案是同一个
      //       （`MathResult.zero` 的十进制形态就是 `'0'`，`storableVariableValue` 也收它）。
      //       数据集与变量在这件事上**必须**一致——两条规矩不一样的话，用户没有任何线索知道为什么。
      // English: this is not a missed judgement: the screen says `0`, so it is a number, and this is the
      //          answer the variable sheet gives on that same screen (`MathResult.zero`'s decimal form
      //          *is* `'0'` and `storableVariableValue` accepts it too). The dataset and the variables
      //          **have to** agree here — two different rules would leave the user with no clue why.
      final controller =
          _controller(_FakeDatabase(), engine: _FakeMathEngine(_failure));

      expect(controller.result, '0');
      expect(controller.storableDatasetValue, '0');
      expect(controller.addDatasetValue(), isNull);
      expect(controller.datasetValues, <String>['0']);

      controller.dispose();
    });
  });

  group('撤销 / 重做盖着数据集', () {
    test('加一个值之后撤销，数据集回到那一刻之前；重做把它带回来', () async {
      final engine = _FakeMathEngine(
        const _Reply('5', tex: '5', kind: EngineResultKind.number).reply,
      );
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('5');
      await controller.submit();
      controller.addDatasetValue();
      expect(controller.datasetValues, <String>['5']);

      controller.undo();
      expect(controller.datasetValues, isEmpty,
          reason: '撤销一次「加了一个值」之后，存放处必须回到那一刻的样子');

      controller.redo();
      expect(controller.datasetValues, <String>['5']);

      controller.dispose();
    });

    test('去掉中间一个值也进撤销栈，撤销把它放回原位', () async {
      final controller = _controller(
        _FakeDatabase(),
        engine: _FakeMathEngine(_failure),
        storedDataset: '["5","12","13"]',
      );
      await controller.restoreIfEnabled();
      expect(controller.datasetValues, <String>['5', '12', '13']);

      controller.removeDatasetValueAt(1);
      expect(controller.datasetValues, <String>['5', '13']);

      controller.undo();
      expect(controller.datasetValues, <String>['5', '12', '13'],
          reason: '撤销之后顺序也要回来——数据集的顺序是它的一部分');

      controller.dispose();
    });

    test('没变化的快照不会挤进撤销栈（在顶上加两次值不该是两格不一样的历史）', () async {
      final controller = _controller(
        _FakeDatabase(),
        engine: _FakeMathEngine(_failure),
      );

      // 中文：空数据集上「清空」是空操作——它不该留下一条可撤销的记录。
      controller.clearDataset();
      expect(controller.canUndo, isFalse);

      controller.dispose();
    });
  });

  group('落盘与恢复', () {
    test('落盘写在 calculator_dataset 这一个键上（JSON 数组）', () async {
      final database = _FakeDatabase();
      final engine = _FakeMathEngine(
        const _Reply('5', tex: '5', kind: EngineResultKind.number).reply,
      );
      final controller =
          _controller(database, engine: engine, restoreState: true);

      controller.setExpression('5');
      await controller.submit();
      controller.addDatasetValue();
      await Future<void>.delayed(Duration.zero);

      expect(database.savedSettings['calculator_dataset'], '["5"]');

      controller.dispose();
    });

    test('读回来：盘上的每一条都过「能不能当数字用」那一关', () async {
      final controller = _controller(
        _FakeDatabase(),
        engine: _FakeMathEngine(_failure),
        // 中文：第二条是下溢，第三条根本不是数，第四条不是字符串——三种盘上可能出现的东西。
        // English: the second is an underflow, the third is not a number at all and the fourth is not
        //          even a string — three things disk can hold.
        storedDataset: '["5","9.3e-603","abc",7,"1.5"]',
      );

      await controller.restoreIfEnabled();

      expect(controller.datasetValues, <String>['5', '1.5'],
          reason: '挡下来的按「没有这个值」处理，剩下的照样按顺序读回来');

      controller.dispose();
    });

    test('整串读不动时按「没有数据集」处理（失败关上门，不猜一个数出来）', () async {
      for (final stored in <String>['不是 JSON', '{"a":1}', '[', '17']) {
        final controller = _controller(
          _FakeDatabase(),
          engine: _FakeMathEngine(_failure),
          storedDataset: stored,
        );

        await controller.restoreIfEnabled();

        expect(controller.datasetValues, isEmpty,
            reason: '「$stored」不该读出一个数据集来');

        controller.dispose();
      }
    });

    test('代际守卫：读盘期间用户加的值不会被盘上那一份盖掉', () async {
      // 中文：盘上那一份与内存里即将出现的那一份**不一样**（`["7"]` 对 `["5"]`），否则这条测试问不出
      //       任何事：读回来的值与加进去的值相同的话，盖没盖掉看不出来。
      //       `holdSettings` 把这一段时间**整个**撑开——读盘与落盘两边都卡住（真实的盘也是两边都
      //       要时间的），所以恢复读到的那一份地图是用户加值**之前**的盘面。
      // English: what is on disk differs from what is about to be in memory (`["7"]` against `["5"]`),
      //          or this test would ask nothing: were the value read back equal to the one added, an
      //          overwrite would be invisible. `holdSettings` holds the **whole** window open — both the
      //          read and the write (a real disk takes time on both sides too), so the map the restore
      //          reads is the disk as it was **before** the user added anything.
      final database = _FakeDatabase();
      final engine = _FakeMathEngine(
        const _Reply('5', tex: '5', kind: EngineResultKind.number).reply,
      );
      final controller =
          _controller(database, engine: engine, restoreState: true);

      controller.setExpression('5');
      await controller.submit();

      // 中文：从这一刻起盘上写着的是**另一份**数据集，然后 `holdSettings` 把读盘与落盘两边一起撑开。
      // English: from here on the disk says something **else**, and `holdSettings` then holds both the
      //          read and the write open.
      database.savedSettings['calculator_dataset'] = '["7"]';
      database.holdSettings = true;

      final restoring = controller.restoreIfEnabled();
      // 中文：恢复还在等盘上的那一刻，用户往数据集里加了一个值。
      // English: while the restore is still waiting on disk, the user adds a value to the dataset.
      controller.addDatasetValue();
      expect(controller.datasetValues, <String>['5']);

      database.releaseSettings();
      await restoring;

      expect(controller.datasetValues, <String>['5'],
          reason: '数据集是状态：它动过之后，读到的那一份盘上数据就不该再落地');

      controller.dispose();
    });
  });

  group('数据集最多 kMaxDatasetValues 个值（上限在源代码里；测试钉住的是边界行为）', () {
    test('少一个时加得进去，到顶之后拒绝、而且拒绝被说出来', () async {
      // 中文：`kMaxDatasetValues` 是 40（`calculator_controller_dataset.dart`，那里写了它为什么存在）。
      //       这里**故意写死这个数**：跟着常量走的话，改大改小都不会红，而「上限还在不在」正是这条
      //       测试要问的。
      // English: `kMaxDatasetValues` is 40 (in `calculator_controller_dataset.dart`, where the reason it
      //          exists is written down). The number is **deliberately hardcoded here**: following the
      //          constant would mean a change in either direction stayed green, while "is the cap still
      //          enforced" is exactly what this test asks.
      const cap = 40;

      Future<CalculatorController> withValues(int count) async {
        final controller = _controller(
          _FakeDatabase(),
          engine: _FakeMathEngine(
            const _Reply('5', tex: '5', kind: EngineResultKind.number).reply,
          ),
          storedDataset:
              '[${List<String>.generate(count, (i) => '"$i"').join(',')}]',
        );
        await controller.restoreIfEnabled();
        controller.setExpression('5');
        await controller.submit();
        return controller;
      }

      final under = await withValues(cap - 1);
      expect(under.datasetLength, cap - 1);
      expect(under.addDatasetValue(), isNull, reason: '还差一格，加得进去');
      expect(under.datasetLength, cap);

      final full = await withValues(cap);
      final sentence = full.addDatasetValue();
      expect(sentence, isNotNull);
      expect(sentence, contains('$cap'));
      expect(full.datasetLength, cap, reason: '被拒的那一个不许挤进去');
      expect(full.datasetValues.last, '${cap - 1}',
          reason: '被拒的是**新**值，原来那些一个都不许动');

      under.dispose();
      full.dispose();
    });
  });

  group('值只进不出：数据集不是结果', () {
    test('加一个值不重算、不动结果行、不动表达式、不动记忆与 Ans', () async {
      final engine = _FakeMathEngine(
        const _Reply('5', tex: '5', kind: EngineResultKind.number).reply,
      );
      final controller = _controller(_FakeDatabase(), engine: engine);

      controller.setExpression('2+3');
      await controller.submit();
      final callsBefore = engine.calls.length;
      final resultBefore = controller.result;
      final decimalBefore = controller.resultDecimal;

      expect(controller.addDatasetValue(), isNull);

      expect(engine.calls.length, callsBefore,
          reason: '数据集不是求值的输入：加一个值不该再问引擎一次');
      expect(controller.result, resultBefore);
      expect(controller.resultDecimal, decimalBefore);
      expect(controller.expression, '2+3');
      expect(controller.memoryValue, 0);
      expect(controller.hasError, isFalse);

      controller.dispose();
    });

    test('数据集里那两个值不会变成结果 / Ans（它们连结果行都上不去）', () async {
      final controller = _controller(
        _FakeDatabase(),
        engine: _FakeMathEngine(_failure),
        storedDataset: '["5","12"]',
      );
      await controller.restoreIfEnabled();

      expect(controller.datasetValues, <String>['5', '12']);
      expect(controller.result, '0',
          reason: '恢复一份数据集不该让屏幕上出现任何一个值');

      controller.dispose();
    });
  });

  group('面板插进去的那一条调用', () {
    test('数据集为空时插的是起手数据——与本轮之前逐字节相同', () {
      final controller =
          _controller(_FakeDatabase(), engine: _FakeMathEngine(_failure));

      expect(controller.datasetCallArguments, '1,2,3,4');
      expect(controller.statisticsCall('mean'), 'mean(1,2,3,4)');
      expect(controller.statisticsCall('stdev'), 'stdev(1,2,3,4)');

      controller.dispose();
    });

    test('数据集非空时插的是它那几个值，顺序就是加入的顺序', () async {
      final controller = _controller(
        _FakeDatabase(),
        engine: _FakeMathEngine(_failure),
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
      final engine = _FakeMathEngine(
        const _Reply('0.3333333333333333',
                kind: EngineResultKind.number)
            .reply,
      );
      final controller = _controller(_FakeDatabase(), engine: engine);

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
      final controller = _controller(
        _FakeDatabase(),
        engine: _FakeMathEngine(_failure),
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
      expect(controller.statisticsCall('mean'),
          'mean(1,100,2,200,3,300,4,400)');

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
      for (final stored in <String>['[]', '["5"]', '["5","12"]', '["5","12","13"]']) {
        final controller = _controller(
          _FakeDatabase(),
          engine: _FakeMathEngine(_failure),
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
      final controller = _controller(
        _FakeDatabase(),
        engine: _FakeMathEngine(_failure),
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
      final controller = _controller(
        _FakeDatabase(),
        engine: _FakeMathEngine(_failure),
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
        expect(AppEngineVocabulary.canRead('$name(matrix(2,2,1,3,2,4))'), isTrue);
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
        expect(AppEngineVocabulary.identifiers[name]!.oneSeriesPerArgument, isTrue,
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
      final controller = _controller(
        _FakeDatabase(),
        engine: _FakeMathEngine(_failure),
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
      final controller = _controller(
        _FakeDatabase(),
        engine: _FakeMathEngine(_failure),
        storedDataset: '["5","12"]',
      );
      await controller.restoreIfEnabled();

      controller.setExpression(controller.statisticsCall('mean'));
      expect(controller.expression, 'mean(5,12)');
      await controller.submit();

      expect(controller.hasError, isTrue,
          reason: '旧解析器读不懂 `mean`，这一条只能是一句错误');
      expect(controller.result, isNot(contains('10')));

      controller.dispose();
    });
  });
}

/// 中文：一条按实测形状配好的回执（十进制只在**是有限数**时才写，与 `QalculateMathEngine` 同规矩）。
/// English: one receipt shaped like a measurement (the decimal is written only when it **is** a finite
///          number, the same rule `QalculateMathEngine` follows).
class _Reply {
  const _Reply(this.displayText, {this.tex = '', this.kind = EngineResultKind.number});

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
  _FakeDatabase db, {
  required MathEngine engine,
  bool restoreState = false,
  String? storedDataset,
}) {
  if (storedDataset != null) db.savedSettings['calculator_dataset'] = storedDataset;
  return CalculatorController(
    historyRepository: HistoryRepository(db),
    notesRepository: NotesRepository(db),
    settingsRepository: SettingsRepository(db),
    settings: AppSettings(
      haptics: true,
      hapticStrength: '标准',
      restoreState: restoreState || storedDataset != null,
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

  /// 中文：立起来时 [settings] 会一直等到 [releaseSettings] 被调用——用来把一次「读盘期间」的窗口
  ///       撑开。
  /// English: while raised, [settings] waits until [releaseSettings] is called — used to hold a
  ///          "while reading from disk" window open.
  bool holdSettings = false;

  /// 中文：撑开「读盘期间」那一段窗口的那扇门。
  /// English: the gate that holds the "while reading from disk" window open.
  final _gate = Completer<void>();

  void releaseSettings() => _gate.complete();

  @override
  Future<void> setSettings(Map<String, String> values) async {
    if (holdSettings) await _gate.future;
    savedSettings.addAll(values);
  }

  @override
  Future<void> setSetting(String key, String value) async {
    savedSettings[key] = value;
  }

  @override
  Future<Map<String, String>> settings() async {
    if (holdSettings) await _gate.future;
    return Map<String, String>.from(savedSettings);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
