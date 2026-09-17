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
