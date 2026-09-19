import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/application/controllers/calculator_controller.dart';
import 'package:nekocalc/core/math/math_result.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/repositories/history_repository.dart';
import 'package:nekocalc/data/repositories/notes_repository.dart';
import 'package:nekocalc/data/repositories/settings_repository.dart';

/// 中文：结果三形态在重启时的判别（3c 评审的第 3 条）。
///
///       判别依据是**十进制键在不在**，不是值空不空：旧行（拆分之前写的）没有这个键，要从显示
///       文本推导；新行只要写下了这个键，哪怕值是空串，也代表「这一次没有十进制形态」这个事实
///       本身，必须原样保留。
///
/// English: How the three forms are told apart across a restart (finding 3 of the 3c review).
///
///          The discriminator is whether the decimal *key* exists, not whether its value is empty:
///          a row written before the split has no such key and derives its decimal from the display
///          text; a new row that wrote the key — even with an empty value — is recording the fact
///          "there is no decimal form this time", and that has to survive as it stands.
void main() {
  test('a row with an empty decimal field keeps it empty after a restart',
      () async {
    // 中文：`calculator_result_decimal` **键在、值为空**：引擎这一次没有给出十进制形态，而显示
    //       形态恰好是一个能解析成数字的字符串。若按值空不空来判别，重启后十进制形态会被从显示
    //       文本重新推导出来——一个引擎从没给过的数字。
    // English: The `calculator_result_decimal` *key is present with an empty value*: the engine
    //          produced no decimal form this time, while the display form happens to be a string
    //          that parses as a number. Judging by the value's emptiness would re-derive the decimal
    //          form from the display text after the restart — a number the engine never produced.
    final db = _FakeDatabase()
      ..savedSettings.addAll({
        'restore_state': 'true',
        'angle_mode': '弧度',
        'digits': '6 位',
        'calculator_expression': '',
        'calculator_result': '42',
        'calculator_result_tex': r'6 \times 7',
        'calculator_result_decimal': '',
        'calculator_angle': 'RAD',
        'calculator_memory': '0',
      });
    final controller = _controller(db);

    await controller.reloadSettingsAndRestore();

    expect(controller.result, '42');
    expect(controller.resultTex, r'6 \times 7');
    expect(controller.resultDecimal, isEmpty);

    // 中文：`Ans`/`last` 因此不再解析得到——与「引擎没有给出十进制形态」时的行为一致，而不是
    //       悄悄用显示文本顶上。
    // English: `Ans`/`last` therefore stop resolving — the same behaviour as whenever the engine
    //          produced no decimal form, rather than quietly substituting the display text.
    controller.setExpression('ans + 1');
    expect(controller.evaluate, returnsNormally);
    expect(controller.hasError, isTrue);

    controller.dispose();
  });

  test('a persisted memory value that is not usable is not restored', () async {
    // 中文：历史数据里可能存着一个 `Infinity`（本轮之前是可以造出来的，而且会一直活到重启），
    //       恢复时它必须被挡在入口——「不再制造它」不等于「不再信任它」。
    //       `decimalValueOf` 同时挡掉 `NaN` 与下溢；挡下来的按「没有可用的记忆值」处理（0），
    //       与键缺失、值不可解析时的行为一致。
    // English: Old data may hold an `Infinity` (producible before this round, and it survived
    //          restarts); the restore has to stop it at the entrance — "we no longer create it" is
    //          not "we no longer trust it". `decimalValueOf` also rejects `NaN` and underflow, and
    //          what it rejects is treated as "no usable memory value" (0), the same as a missing or
    //          unparseable one.
    for (final (stored, expected) in [
      ('Infinity', 0.0),
      ('-Infinity', 0.0),
      ('NaN', 0.0),
      ('9.303768583076e-603', 0.0),
      ('7.5', 7.5),
      ('-2.25', -2.25),
    ]) {
      final db = _FakeDatabase()
        ..savedSettings.addAll({
          'restore_state': 'true',
          'angle_mode': '弧度',
          'digits': '6 位',
          'calculator_expression': '',
          'calculator_result': '0',
          'calculator_memory': stored,
        });
      final controller = _controller(db);

      await controller.reloadSettingsAndRestore();

      expect(controller.memoryValue, expected, reason: 'stored: $stored');
      controller.dispose();
    }
  });

  test('a row written before the split still derives its decimal', () async {
    // 中文：没有十进制键的旧行，行为与拆分前逐字节一致。
    // English: An old row with no decimal key behaves byte-for-byte as it did before the split.
    final db = _FakeDatabase()
      ..savedSettings.addAll({
        'restore_state': 'true',
        'angle_mode': '弧度',
        'digits': '6 位',
        'calculator_expression': '',
        'calculator_result': '1,234.5',
        'calculator_angle': 'RAD',
        'calculator_memory': '0',
      });
    final controller = _controller(db);

    await controller.reloadSettingsAndRestore();

    expect(controller.result, '1,234.5');
    expect(controller.resultDecimal, '1234.5');
    expect(controller.reusableResult, '1234.5');

    controller.dispose();
  });

  test('a stored placeholder row is still "no usable result" after a restart',
      () async {
    // 中文：**这一条是重启用例里唯一能观察到「占位」那一格的地方。** 上一次会话在一条算不出来的
    //       表达式上结束时，落盘的那一行 `calculator_result` 就是占位文本（`2+` 会在
    //       `evaluate()` 里抛错、于是写 `MathResult.pending`）。重启之后「这一份是不是占位」
    //       必须活过来，否则「继续使用」会把一句话写进表达式。
    //
    //       两种策略都跑，但**只有 (A) `engineOnly` 能把这件事故意暴露出来**：策略 (B) 下
    //       `evaluate()` 会立刻用旧解析器的结果盖掉盘上那一份（`2+` 又抛一次错，于是结果又回到
    //       占位、并且带上 `hasError`）；(A) 下 `evaluate()` 不上旧结果，盘上这一份会**一直留在
    //       屏幕上**直到引擎回答——那一段窗口里判据读的正是这一格。
    //
    //       判据本身不读那句话了（`MathResult.isPlaceholder`）；恢复写这一格的地方是**唯一**拿
    //       那句文本当**存储层令牌**比的边界，见 `_restoredResult` 的注释。
    // English: **the one place among the restore cases where the placeholder cell is observable.** When
    //          the last session ended on an expression that cannot be evaluated, the persisted
    //          `calculator_result` row *is* the placeholder text (`2+` throws inside `evaluate()`,
    //          which is what writes `MathResult.pending`). After a restart, "is this the placeholder"
    //          has to survive, or "continue with result" writes a sentence into the expression.
    //
    //          Both policies run, but **only (A) `engineOnly` exposes this deliberately**: under (B)
    //          `evaluate()` immediately overwrites the stored row with the legacy parser's result
    //          (`2+` throws again, so the result is the placeholder once more, this time with
    //          `hasError`); under (A) `evaluate()` puts no legacy result up, so the stored row **stays
    //          on screen** until the engine answers — and in that window the judgement reads exactly
    //          this cell.
    //
    //          The judgement itself no longer reads that sentence (`MathResult.isPlaceholder`); where
    //          the restore raises that cell is the **only** boundary that compares the sentence as a
    //          **storage-layer token**, see the note on `_restoredResult`.
    for (final policy in LiveResultPolicy.values) {
      final db = _FakeDatabase()
        ..savedSettings.addAll({
          'restore_state': 'true',
          'angle_mode': '弧度',
          'digits': '6 位',
          'calculator_expression': '2+',
          'calculator_result': '等待输入',
          'calculator_result_tex': '',
          'calculator_result_decimal': '',
          'calculator_angle': 'RAD',
          'calculator_memory': '0',
        });
      final controller = CalculatorController(
        historyRepository: HistoryRepository(db),
        notesRepository: NotesRepository(db),
        settingsRepository: SettingsRepository(db),
        settings: const AppSettings(
          haptics: true,
          hapticStrength: '标准',
          restoreState: true,
          autoSaveHistory: false,
          angleMode: 'RAD',
          precision: 6,
          themeModeLabel: '跟随系统',
          expressionDisplayMode: '数学符号',
        ),
        liveResultPolicy: policy,
        liveEvaluationDelay: const Duration(minutes: 10),
        liveEngineFollowUpDelay: const Duration(minutes: 10),
      );

      await controller.reloadSettingsAndRestore();

      // 中文：盘上那一行原样在屏幕上——显示一个字都没动（三格文本照旧带上）。
      // English: the stored row is on screen as it was — the display did not move by a character
      //          (the three text cells travel untouched).
      expect(controller.result, '等待输入', reason: policy.name);
      expect(controller.resultDecimal, isEmpty, reason: policy.name);
      // 中文：而判据说「没有可用的结果」：写回的是 `0`，「继续使用」不写表达式。
      // English: while the judgement says "no usable result": `0` is what would be written back, and
      //          "continue with result" writes no expression.
      expect(controller.reusableResult, '0', reason: policy.name);
      expect(controller.canContinueWithResult, isFalse, reason: policy.name);
      controller.continueWithResult();
      expect(controller.expression, '2+', reason: policy.name);

      controller.dispose();
    }
  });

  test('a restored row reading zero still makes AC a no-op', () async {
    // 中文：**清空那道「没什么可清」的判据读的是结果行的读数，不是"这条结果就是 `MathResult.zero`
    //       那一份对象"。** 这条测试钉住这句话在**一个可达的状态**上的后果：盘上那一行是
    //       `calculator_result: '0'` 且十进制键在、值为空（`4√2` 那类结果就长这样），恢复出来的
    //       结果读数正是零，而它的 `decimalText` 是空串——**与 `MathResult.zero` 不是同一份值**。
    //       今天按 AC 在这里是**空操作**（不记撤销快照）；换成值相等就会开始记快照，
    //       那就是行为变了，所以判据留在读数上（`MathResult.showsZero`，零的写法只有一处）。
    // English: **the "nothing to clear" judgement reads the result line's reading, not "this result is
    //          the `MathResult.zero` object".** This test pins what that means on a **reachable**
    //          state: the stored row has `calculator_result: '0'` with the decimal key present and
    //          empty (what a result like `4√2` looks like), so the restored result reads zero while its
    //          `decimalText` is the empty string — **not the same value as `MathResult.zero`**. Pressing
    //          AC here is a **no-op** today (no undo snapshot recorded); value equality would start
    //          recording one, which is a behaviour change, so the judgement stays on the reading
    //          (`MathResult.showsZero`, with the spelling of zero living in one place).
    final db = _FakeDatabase()
      ..savedSettings.addAll({
        'restore_state': 'true',
        'angle_mode': '弧度',
        'digits': '6 位',
        'calculator_expression': '',
        'calculator_result': '0',
        'calculator_result_tex': '',
        'calculator_result_decimal': '',
        'calculator_angle': 'RAD',
        'calculator_memory': '0',
      });
    final controller = _controller(db);
    await controller.reloadSettingsAndRestore();

    expect(controller.result, '0');
    // 中文：读数一样、对象不一样——下面那条断言就是这个分界。
    // English: same reading, different object — the assertion below is exactly that boundary.
    expect(controller.resultDecimal, isEmpty);
    expect(MathResult.zero.decimalText, '0');

    expect(controller.canUndo, isFalse);
    controller.clear();
    expect(controller.canUndo, isFalse,
        reason: '零读数上的 AC 记下了撤销快照——「没什么可清」的判据换了，那是行为变了');
    expect(controller.result, '0');
    expect(controller.hasError, isFalse);

    controller.dispose();
  });

  test('every persisted result writes the decimal key, even when it is empty',
      () async {
    // 中文：判别依据能成立的前提——新行**一定**会写下这个键。空十进制被写成一个空值，而不是
    //       被省略，否则下一次启动又会退回到「没有键」那条推导分支。
    // English: What makes the discriminator work — a new row *always* writes the key. An empty
    //          decimal is written as an empty value rather than omitted, or the next launch would
    //          fall back into the "no key" derivation branch again.
    final db = _FakeDatabase()
      ..savedSettings.addAll({
        'restore_state': 'true',
        'angle_mode': '弧度',
        'digits': '6 位',
      });
    final controller = _controller(db);
    await controller.reloadSettingsAndRestore();

    // 中文：装上「精确形式 + 没有十进制形态」的结果，再用一个会落盘的动作把它写下去
    //       （`applyMathResult` 只改状态、不落盘，它是给引擎接线用的那个写入点）。
    //       触发落盘用的是一次**只带元数据的粘贴**：它写盘、但不碰结果，也不碰表达式。
    //       （`memoryAdd` 从前也能当触发器，直到它学会在值放不进 double 时**拒绝**——正是这个
    //       测试用的那种结果。）
    // English: Install an "exact form with no decimal form" result, then persist it with an action
    //          that writes state (`applyMathResult` only changes state and does not persist — it is
    //          the write point the engine wiring uses). The persist is triggered by a
    //          *metadata-only paste*: it writes state without touching the result or the expression.
    //          (`memoryAdd` used to serve as that trigger until it learned to *refuse* when the
    //          value does not fit a double — which is exactly the kind of result this test uses.)
    controller.applyMathResult(const MathResult(displayText: r'4\sqrt{2}'));
    controller.applyPastedText('角度模式: RAD');
    await Future<void>.delayed(Duration.zero);

    expect(db.savedSettings.containsKey('calculator_result_decimal'), isTrue);
    expect(db.savedSettings['calculator_result_decimal'], isEmpty);
    expect(db.savedSettings['calculator_result'], r'4\sqrt{2}');
    expect(db.savedSettings['calculator_result_tex'], isEmpty);

    controller.dispose();
  });
}

CalculatorController _controller(_FakeDatabase db) {
  return CalculatorController(
    historyRepository: HistoryRepository(db),
    notesRepository: NotesRepository(db),
    settingsRepository: SettingsRepository(db),
    settings: const AppSettings(
      haptics: true,
      hapticStrength: '标准',
      restoreState: true,
      autoSaveHistory: false,
      angleMode: 'RAD',
      precision: 6,
      themeModeLabel: '跟随系统',
      expressionDisplayMode: '数学符号',
    ),
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
  Future<Map<String, String>> settings() async {
    return Map<String, String>.from(savedSettings);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
