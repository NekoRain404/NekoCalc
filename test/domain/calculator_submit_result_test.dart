import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/domain/usecases/calculator_submit_result.dart';
import 'package:nekocalc/features/calculator/presentation/calculator_strings.dart';
import 'package:nekocalc/features/calculator/presentation/calculator_submit_message.dart';
import 'package:nekocalc/l10n/app_language.dart';

import '../shared/source_scan.dart';

/// 中文：**「这次提交说的是哪件事」与「屏幕上那句话」分家之后，两边都还对得上。**
///
///       `CalculatorSubmitResult` 原先自己拼八句话并直接上屏（`calculator_key_dispatch.dart` 的
///       `SnackBar` 印 `result.message`），于是英文界面下印的仍是中文——领域对象活得比界面长，
///       界面那张按语言切的表够不着它（`docs/verification.md` §5i）。这一轮把那八句话移进
///       `CalculatorStrings`，领域层只留令牌（[CalculatorSubmitStatus]），由
///       `calculatorSubmitMessage` 在呈现边缘取。这份测试是那次改动的锁，四段各管一件事：
///
///       1. **令牌与它那句话一一对应**（[legacySentences]）：八个结局逐条渲染，中文侧必须与
///          迁移前源码里那句话**逐字节相同**；两个方向都查（枚举里每一格都有对照表条目，
///          对照表里每一条都命中一个真的枚举值）。这就是「产出方漏写令牌」与
///          「令牌多出来」的唯一防线——两样都不会抛，只会静默少一句或错一句。
///       2. **回执真的跟着语言走**：同一批结果递英文表，渲染出来的既不是那句中文、也不含
///          宽/全角字符（载荷用 ASCII，因为载荷是调用方递进来的、本来就跟着调用方的语言）。
///       3. **判据没变**：`submitted` / `needsAttention` / `savedToHistory` 三条行为判据的宽度
///          与从前一致（迁移一个字都没动它们）。
///       4. **源码里那句话只有一份**：`calculator_submit_result.dart` 里**一个宽/全角字面量都不许
///          有**——句子只住在 `CalculatorStrings` 里。（比工具结果那份「整句相同」的扫描更严：
///          八句话里有六句不带载荷，但载荷那两句的**半句**（`'表达式需要修正：'`）抄回去也不会
///          跟语言走，所以那一整个文件按"零宽字符"来守。）
///
///       **中文逐字节相同是被测试量出来的，不是被声明的**：第 1 段那张对照表就是迁移前
///       `calculator_submit_result.dart` 里八条 `message:` 的抄本，故意写死在测试里。
/// English: **once "which thing this submit is about" has parted from "the sentence on screen", the
///          two still line up.**
///
///          `CalculatorSubmitResult` used to compose eight sentences itself and print them straight
///          (`calculator_key_dispatch.dart`'s `SnackBar` printed `result.message`), so an English
///          interface still printed Chinese — a domain object outlives the UI and a language-keyed
///          interface table cannot reach it (`docs/verification.md` §5i). This round moved those eight
///          sentences into `CalculatorStrings`, leaving the domain layer with only the token
///          ([CalculatorSubmitStatus]), resolved at the presentation edge by `calculatorSubmitMessage`.
///          This test is that change's lock, in four parts:
///
///          1. **Token and sentence correspond one to one** ([legacySentences]): all eight outcomes
///             rendered, the Chinese side **byte-identical** to the sentence in the source before the
///             change, checked in both directions (every enum value has a table entry, every table
///             entry hits a real enum value). This is the only defence against "a producer forgot the
///             token" and "a token appeared from nowhere" — neither throws, they only silently drop or
///             swap a sentence.
///          2. **The receipt really follows the language**: the same results with the English table
///             render neither the Chinese sentence nor any wide/fullwidth character (payloads are
///             ASCII here, because a payload is handed in by the caller and already follows the
///             caller's language).
///          3. **The verdicts have not moved**: `submitted` / `needsAttention` / `savedToHistory` keep
///             the width they had (the change did not touch them by one character).
///          4. **The sentence exists once in the source**: `calculator_submit_result.dart` must hold
///             **not one wide/fullwidth literal** — the sentences live in `CalculatorStrings` only.
///             (Stricter than the tool-result scan's "equal to a whole sentence": six of the eight
///             sentences carry no payload, but copying even the **half sentence** of the other two
///             (`'表达式需要修正：'`) back would not follow the language, so the whole file is held to
///             "zero wide characters".)
///
///          **The byte-identity is measured, not asserted**: the table in part 1 is a copy of the eight
///          `message:` lines in `calculator_submit_result.dart` before the change, deliberately written
///          out in the test.
void main() {
  final zh = CalculatorStrings.forLanguage(AppLanguage.zh);
  final en = CalculatorStrings.forLanguage(AppLanguage.en);

  /// 中文：**迁移前那八句话本身**（结局 → 它从前印什么）。这份对照表**故意写在测试里**、
  ///       不从 `CalculatorStrings` 生成：它的全部价值就在于它是**旧知识的一份抄本**
  ///       （与 `tool_result_conclusion_test.dart` 里那份 `legacySentences` 同一个理由）。
  ///       两个载荷格取一组固定载荷，句子里的其余部分因此逐字节可比。
  ///       **不要拿它去追新文案。**
  /// English: **the eight sentences from before the change** (outcome → what it used to print). This
  ///          table is **deliberately written in the test** rather than generated from
  ///          `CalculatorStrings`: its whole value is being **a copy of the old knowledge** (the same
  ///          reason `legacySentences` in `tool_result_conclusion_test.dart` exists). The two payload
  ///          cells take one fixed payload each so the rest of the sentence is byte-comparable.
  ///          **Do not bring it up to date with new copy.**
  const legacySentences = <CalculatorSubmitStatus, String>{
    CalculatorSubmitStatus.emptyExpression: '请输入表达式后再计算',
    CalculatorSubmitStatus.invalidExpression: '表达式需要修正：缺少右括号',
    CalculatorSubmitStatus.calculated: '已计算结果',
    CalculatorSubmitStatus.historySaved: '已计算并保存到历史',
    CalculatorSubmitStatus.historySkippedDuplicate: '已计算，重复历史已跳过',
    CalculatorSubmitStatus.historyNotWritten: '已计算，但历史没有写入，请重试',
    CalculatorSubmitStatus.historyFailed: '已计算，但保存历史失败：Bad state: db locked',
    CalculatorSubmitStatus.superseded: '输入已更新，本次计算结果未采用',
  };

  test('每个结局一句回执：令牌与那句话一一对应', () {
    // 中文：**中文侧逐字节相同**。断言写成一整张表逐条比，不抽查——抽查漏掉的那一条正好是将来
    //       会漂的那一条，而漂了不会有任何东西抛。
    // English: **the Chinese side is byte-identical.** The assertions walk the whole table rather than
    //          sampling: the entry a spot check skips is the one that drifts, and a drift throws
    //          nothing.
    for (final entry in legacySentences.entries) {
      expect(calculatorSubmitMessage(_resultFor(entry.key), zh), entry.value,
          reason: '${entry.key.name} 的回执与迁移前那句话不同了');
    }

    // 中文：**两个方向。** 枚举里每一格都要有对照表条目（漏了就是"令牌多出来"），
    //       对照表里每一条都要命中一个真的枚举值（多一条就是"令牌被删了、文案留着"）。
    // English: **both directions.** Every enum value needs a table entry (a missing one means "a token
    //          appeared from nowhere"), and every table entry has to hit a real enum value (an extra
    //          one means "the token was deleted, the copy stayed").
    expect(legacySentences.keys.toSet(), CalculatorSubmitStatus.values.toSet(),
        reason: '令牌与旧文案对照表对不上：'
            '${legacySentences.keys.toSet().difference(CalculatorSubmitStatus.values.toSet())}');
  });

  test('同一个令牌在英文表下不给中文：回执跟着语言走', () {
    // 中文：**载荷用 ASCII**：`errorMessage` 是调用方递进来的数据，它自己已经跟着调用方的语言走
    //       （控制器经 `CalculatorControllerStrings` 翻好），所以这里量的是**句子**那一层，
    //       不是载荷那一层。
    // English: **the payloads are ASCII here**: `errorMessage` is data handed in by the caller and
    //          already follows the caller's language (the controller translates it through
    //          `CalculatorControllerStrings`), so what is measured here is the **sentence** layer, not
    //          the payload layer.
    final results = <CalculatorSubmitResult>[
      const CalculatorSubmitResult.emptyExpression(),
      CalculatorSubmitResult.invalidExpression('missing )'),
      const CalculatorSubmitResult.calculated(expression: '1+2', result: '3'),
      const CalculatorSubmitResult.historySaved(
          expression: '6×7', result: '42', historyId: 7),
      const CalculatorSubmitResult.historySkippedDuplicate(
          expression: '6*7', result: '42'),
      const CalculatorSubmitResult.historyNotWritten(
          expression: '9+1', result: '10'),
      CalculatorSubmitResult.historyFailed(
          expression: '4*5', result: '20', error: StateError('db locked')),
      const CalculatorSubmitResult.superseded(),
    ];
    for (final result in results) {
      final rendered = calculatorSubmitMessage(result, en);
      expect(containsWideOrFullwidth(rendered), isFalse,
          reason: '${result.status.name} 的英文回执里还有宽/全角字符：$rendered');
      expect(rendered, isNot(contains('。')));
    }
    // 中文：**英文表不是中文表抄两遍**：八句里没有一句与中文那份相同。
    // English: **the English table is not the Chinese one copied twice**: not one of the eight equals
    //          its Chinese counterpart.
    for (final result in results) {
      expect(calculatorSubmitMessage(result, en),
          isNot(calculatorSubmitMessage(result, zh)),
          reason: '${result.status.name} 在两种语言下印同一句话');
    }
  });

  test('两个载荷格真的把载荷拼进句子：换一个载荷就换一句话', () {
    // 中文：载荷不是装饰：同一个令牌换一个 `errorMessage`，句子里那半截必须跟着换
    //       （`'表达式需要修正：结果不是有限数值'` 正是控制器那条非有限闸上屏的那句）。
    // English: the payload is not decoration: the same token with a different `errorMessage` has to
    //          move that half of the sentence (`'表达式需要修正：结果不是有限数值'` is exactly what the
    //          controller's non-finite gate puts on screen).
    final invalid = CalculatorSubmitResult.invalidExpression('结果不是有限数值');
    expect(calculatorSubmitMessage(invalid, zh), '表达式需要修正：结果不是有限数值');
    expect(invalid.errorMessage, '结果不是有限数值');

    final failed = CalculatorSubmitResult.historyFailed(
        expression: '4*5', result: '20', error: StateError('db locked'));
    expect(calculatorSubmitMessage(failed, zh),
        '已计算，但保存历史失败：Bad state: db locked');
    expect(failed.errorMessage, 'Bad state: db locked');
  });

  test('结局那三条行为判据没有跟着文案一起动', () {
    const empty = CalculatorSubmitResult.emptyExpression();
    expect(empty.submitted, isFalse);
    expect(empty.needsAttention, isTrue);

    final invalid = CalculatorSubmitResult.invalidExpression('缺少右括号');
    expect(invalid.submitted, isFalse);
    expect(invalid.status, CalculatorSubmitStatus.invalidExpression);

    const calculated = CalculatorSubmitResult.calculated(
      expression: '1+2',
      result: '3',
    );
    expect(calculated.submitted, isTrue);
    expect(calculated.savedToHistory, isFalse);
    expect(calculated.needsAttention, isFalse);

    const saved = CalculatorSubmitResult.historySaved(
      expression: '6×7',
      result: '42',
      historyId: 7,
    );
    expect(saved.savedToHistory, isTrue);
    expect(saved.historyId, 7);

    const duplicate = CalculatorSubmitResult.historySkippedDuplicate(
      expression: '6*7',
      result: '42',
    );
    expect(duplicate.submitted, isTrue);
    expect(duplicate.needsAttention, isFalse);
  });

  test('a superseded submit is not a submission and does not ask for attention',
      () {
    // 中文：结果被更新的输入取代时，既没有计算结果可以展示，也没有历史可以保存——`submitted`
    //       为假、`needsAttention` 为假（屏幕上已经是更新那条边打边算的结果，不该再弹提示）。
    // English: When newer input overtook the result there is no calculation to show and no history
    //          to save — `submitted` is false and `needsAttention` is false (the newer as-you-type
    //          result is already on screen, so no banner belongs there).
    const superseded = CalculatorSubmitResult.superseded();

    expect(superseded.status, CalculatorSubmitStatus.superseded);
    expect(superseded.submitted, isFalse);
    expect(superseded.needsAttention, isFalse);
    expect(superseded.savedToHistory, isFalse);
    expect(superseded.result, isNull);
    expect(superseded.expression, isNull);
  });

  test('源码里那句话只有一份：领域文件里一个宽/全角字面量都没有', () {
    // 中文：**扫的是"这个文件里有没有给人看的字"**，不是"有没有整句相同"：八句话已经全搬进
    //       `CalculatorStrings`，这个文件里再出现任何一个宽/全角字面量，都说明有人把文案抄了回来
    //       （或者新写了一句），而抄回来的那一份不会跟着语言走。尺子与设置页、计算器页、控制器
    //       那三条护栏**同一把**（`containsWideOrFullwidth`）。
    // English: **the scan asks "does this file hold any human-facing character"**, not "is a whole
    //          sentence identical": all eight sentences have moved into `CalculatorStrings`, so any
    //          wide/fullwidth literal reappearing here means somebody copied copy back (or wrote a new
    //          sentence), and the copy will not follow the language. The ruler is **the same one** as
    //          the settings page, calculator page and controller guards (`containsWideOrFullwidth`).
    final file = File('lib/domain/usecases/calculator_submit_result.dart');
    expect(file.existsSync(), isTrue, reason: '测试的工作目录应当是包的根目录');
    final source = stripComments(file.readAsStringSync());
    final offenders =
        stringLiterals(source).where(containsWideOrFullwidth).toList();
    expect(offenders, isEmpty,
        reason: '这些字面量应当走 CalculatorStrings（句子只住在那里）：\n'
            '${offenders.join('\n')}');
  });
}

/// 中文：对照表里的固定载荷。两格是函数，所以渲染前得有个具体的 [CalculatorSubmitResult]；
///       载荷与 [legacySentences] 里那两句对得上（`'缺少右括号'`、`'Bad state: db locked'`）。
/// English: the fixed payloads of the legacy table. Two cells are functions, so rendering needs a
///          concrete [CalculatorSubmitResult]; the payloads match the sentences in [legacySentences]
///          (`'缺少右括号'`, `'Bad state: db locked'`).
CalculatorSubmitResult _resultFor(CalculatorSubmitStatus status) {
  return switch (status) {
    CalculatorSubmitStatus.emptyExpression =>
      const CalculatorSubmitResult.emptyExpression(),
    CalculatorSubmitStatus.invalidExpression =>
      CalculatorSubmitResult.invalidExpression('缺少右括号'),
    CalculatorSubmitStatus.calculated =>
      const CalculatorSubmitResult.calculated(expression: '1+2', result: '3'),
    CalculatorSubmitStatus.historySaved =>
      const CalculatorSubmitResult.historySaved(
          expression: '6×7', result: '42', historyId: 7),
    CalculatorSubmitStatus.historySkippedDuplicate =>
      const CalculatorSubmitResult.historySkippedDuplicate(
          expression: '6*7', result: '42'),
    CalculatorSubmitStatus.historyNotWritten =>
      const CalculatorSubmitResult.historyNotWritten(
          expression: '9+1', result: '10'),
    CalculatorSubmitStatus.historyFailed =>
      CalculatorSubmitResult.historyFailed(
          expression: '4*5', result: '20', error: StateError('db locked')),
    CalculatorSubmitStatus.superseded =>
      const CalculatorSubmitResult.superseded(),
  };
}
