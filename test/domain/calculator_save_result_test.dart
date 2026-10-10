import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/domain/usecases/calculator_save_result.dart';
import 'package:nekocalc/features/calculator/presentation/calculator_save_message.dart';
import 'package:nekocalc/features/calculator/presentation/calculator_strings.dart';
import 'package:nekocalc/l10n/app_language.dart';

import '../shared/source_scan.dart';

/// 中文：**「这次保存说的是哪件事」与「屏幕上那句话」分家之后，两边都还对得上。**
///
///       `CalculatorSaveNoteResult` 原先自己拼五句话并直接上屏（`calculator_page_sheets.dart` 的
///       `SnackBar` 印 `result.message`），于是英文界面下印的仍是中文——领域对象活得比界面长，
///       界面那张按语言切的表够不着它（`docs/verification.md` §5i）。这一轮把那五句话移进
///       `CalculatorStrings`，领域层只留令牌（[CalculatorSaveNoteStatus]），由
///       `calculatorSaveNoteMessage` 在呈现边缘取。这份测试是那次改动的锁，五段各管一件事：
///
///       1. **令牌与它那句话一一对应**（[legacySentences]）：六个结局逐条渲染，中文侧必须与
///          迁移前源码里那句话**逐字节相同**；两个方向都查（枚举里每一格都有对照表条目，
///          对照表里每一条都命中一个真的枚举值）。`notWritten` 与 `superseded` **故意共用**
///          同一句话，所以这张表里两格同值——那是迁移前的事实，不是巧合。
///       2. **回执真的跟着语言走**：同一批结果递英文表，渲染出来的既不是那句中文、也不含
///          宽/全角字符（载荷用 ASCII，因为载荷是调用方递进来的、本来就跟着调用方的语言）。
///       3. **两个载荷格真的把载荷拼进句子**：换一个 `errorMessage`，句子里那半截必须跟着换。
///       4. **判据没变**：`saved` 与 `noteId` 的读数与从前一致（迁移一个字都没动它们）。
///       5. **源码里那句话只有一份**：`calculator_save_result.dart` 里**一个宽/全角字面量都不许
///          有**——句子只住在 `CalculatorStrings` 里（与提交路径那条护栏同一把尺子）。
///
///       **中文逐字节相同是被测试量出来的，不是被声明的**：第 1 段那张对照表就是迁移前
///       `calculator_save_result.dart` 里那几条 `message:` 的抄本，故意写死在测试里。
/// English: **once "which thing this save is about" has parted from "the sentence on screen", the two
///          still line up.**
///
///          `CalculatorSaveNoteResult` used to compose five sentences itself and print them straight
///          (`calculator_page_sheets.dart`'s `SnackBar` printed `result.message`), so an English
///          interface still printed Chinese — a domain object outlives the UI and a language-keyed
///          interface table cannot reach it (`docs/verification.md` §5i). This round moved those five
///          sentences into `CalculatorStrings`, leaving the domain layer with only the token
///          ([CalculatorSaveNoteStatus]), resolved at the presentation edge by
///          `calculatorSaveNoteMessage`. This test is that change's lock, in five parts:
///
///          1. **Token and sentence correspond one to one** ([legacySentences]): all six outcomes
///             rendered, the Chinese side **byte-identical** to the sentence in the source before the
///             change, checked in both directions (every enum value has a table entry, every table entry
///             hits a real enum value). `notWritten` and `superseded` **deliberately share** one
///             sentence, so two cells of this table hold the same string — that is what the code did
///             before the move, not a coincidence.
///          2. **The receipt really follows the language**: the same results with the English table
///             render neither the Chinese sentence nor any wide/fullwidth character (payloads are ASCII
///             here, because a payload is handed in by the caller and already follows the caller's
///             language).
///          3. **The two payload cells really splice their payload in**: a different `errorMessage`
///             moves that half of the sentence.
///          4. **The verdicts have not moved**: `saved` and `noteId` read as they did (the change did not
///             touch them by one character).
///          5. **The sentence exists once in the source**: `calculator_save_result.dart` must hold **not
///             one wide/fullwidth literal** — the sentences live in `CalculatorStrings` only (the same
///             ruler as the submit path's guard).
///
///          **The byte-identity is measured, not asserted**: the table in part 1 is a copy of the
///          `message:` lines in `calculator_save_result.dart` before the change, deliberately written
///          out in the test.
void main() {
  final zh = CalculatorStrings.forLanguage(AppLanguage.zh);
  final en = CalculatorStrings.forLanguage(AppLanguage.en);

  /// 中文：**迁移前那五句话本身**（结局 → 它从前印什么）。这份对照表**故意写在测试里**、
  ///       不从 `CalculatorStrings` 生成：它的全部价值就在于它是**旧知识的一份抄本**
  ///       （与 `calculator_submit_result_test.dart` 里那份 `legacySentences` 同一个理由）。
  ///       两个载荷格取一组固定载荷，句子里的其余部分因此逐字节可比。
  ///       **不要拿它去追新文案。**
  /// English: **the sentences from before the change** (outcome → what it used to print). This table is
  ///          **deliberately written in the test** rather than generated from `CalculatorStrings`: its
  ///          whole value is being **a copy of the old knowledge** (the same reason `legacySentences` in
  ///          `calculator_submit_result_test.dart` exists). The two payload cells take one fixed payload
  ///          each so the rest of the sentence is byte-comparable. **Do not bring it up to date with new
  ///          copy.**
  const legacySentences = <CalculatorSaveNoteStatus, String>{
    CalculatorSaveNoteStatus.saved: '已保存到笔记',
    CalculatorSaveNoteStatus.emptyExpression: '请输入有效表达式后再保存',
    CalculatorSaveNoteStatus.invalidExpression: '表达式需要修正：缺少右括号',
    CalculatorSaveNoteStatus.notWritten: '笔记没有写入，请重试',
    CalculatorSaveNoteStatus.failed: '保存笔记失败：Bad state: db locked',
    CalculatorSaveNoteStatus.superseded: '笔记没有写入，请重试',
  };

  test('每个结局一句回执：令牌与那句话一一对应', () {
    // 中文：**中文侧逐字节相同**。断言写成一整张表逐条比，不抽查——抽查漏掉的那一条正好是将来
    //       会漂的那一条，而漂了不会有任何东西抛。
    // English: **the Chinese side is byte-identical.** The assertions walk the whole table rather than
    //          sampling: the entry a spot check skips is the one that drifts, and a drift throws
    //          nothing.
    for (final entry in legacySentences.entries) {
      expect(calculatorSaveNoteMessage(_resultFor(entry.key), zh), entry.value,
          reason: '${entry.key.name} 的回执与迁移前那句话不同了');
    }

    // 中文：**两个方向。** 枚举里每一格都要有对照表条目（漏了就是"令牌多出来"），
    //       对照表里每一条都要命中一个真的枚举值（多一条就是"令牌被删了、文案留着"）。
    //       `notWritten` 与 `superseded` 同值是迁移前的事实：两格指向同一句话是**故意的**。
    // English: **both directions.** Every enum value needs a table entry (a missing one means "a token
    //          appeared from nowhere"), and every table entry has to hit a real enum value (an extra one
    //          means "the token was deleted, the copy stayed"). `notWritten` and `superseded` holding
    //          one string is pre-move fact: the two pointing at one sentence is **deliberate**.
    expect(legacySentences.keys.toSet(), CalculatorSaveNoteStatus.values.toSet(),
        reason: '令牌与旧文案对照表对不上：'
            '${legacySentences.keys.toSet().difference(CalculatorSaveNoteStatus.values.toSet())}');
  });

  test('同一个令牌在英文表下不给中文：回执跟着语言走', () {
    // 中文：**载荷用 ASCII**：`errorMessage` 是调用方递进来的数据，它自己已经跟着调用方的语言走
    //       （控制器经 `CalculatorControllerStrings` 翻好），所以这里量的是**句子**那一层，
    //       不是载荷那一层。
    // English: **the payloads are ASCII here**: `errorMessage` is data handed in by the caller and
    //          already follows the caller's language (the controller translates it through
    //          `CalculatorControllerStrings`), so what is measured here is the **sentence** layer, not
    //          the payload layer.
    final results = <CalculatorSaveNoteResult>[
      const CalculatorSaveNoteResult.saved(7),
      const CalculatorSaveNoteResult.emptyExpression(),
      CalculatorSaveNoteResult.invalidExpression('missing )'),
      const CalculatorSaveNoteResult.notWritten(),
      CalculatorSaveNoteResult.failed(StateError('db locked')),
      const CalculatorSaveNoteResult.superseded(),
    ];
    for (final result in results) {
      final rendered = calculatorSaveNoteMessage(result, en);
      expect(containsWideOrFullwidth(rendered), isFalse,
          reason: '${result.status.name} 的英文回执里还有宽/全角字符：$rendered');
      expect(rendered, isNot(contains('。')));
    }
    // 中文：**英文表不是中文表抄两遍**：六格里没有一格与中文那份相同。
    // English: **the English table is not the Chinese one copied twice**: not one of the six equals its
    //          Chinese counterpart.
    for (final result in results) {
      expect(calculatorSaveNoteMessage(result, en),
          isNot(calculatorSaveNoteMessage(result, zh)),
          reason: '${result.status.name} 在两种语言下印同一句话');
    }
  });

  test('两个载荷格真的把载荷拼进句子：换一个载荷就换一句话', () {
    // 中文：载荷不是装饰：同一个令牌换一个 `errorMessage`，句子里那半截必须跟着换
    //       （`'表达式需要修正：结果不是有限数值'` 正是控制器那条非有限闸上屏的那句）。
    // English: the payload is not decoration: the same token with a different `errorMessage` has to
    //          move that half of the sentence (`'表达式需要修正：结果不是有限数值'` is exactly what the
    //          controller's non-finite gate puts on screen).
    final invalid = CalculatorSaveNoteResult.invalidExpression('结果不是有限数值');
    expect(calculatorSaveNoteMessage(invalid, zh), '表达式需要修正：结果不是有限数值');
    expect(invalid.errorMessage, '结果不是有限数值');

    final failed =
        CalculatorSaveNoteResult.failed(StateError('db locked'));
    expect(calculatorSaveNoteMessage(failed, zh), '保存笔记失败：Bad state: db locked');
    expect(failed.errorMessage, 'Bad state: db locked');
  });

  test('结局那两条读数没有跟着文案一起动', () {
    const saved = CalculatorSaveNoteResult.saved(42);
    expect(saved.saved, isTrue);
    expect(saved.status, CalculatorSaveNoteStatus.saved);
    expect(saved.noteId, 42);
    expect(saved.errorMessage, isNull);

    const empty = CalculatorSaveNoteResult.emptyExpression();
    expect(empty.saved, isFalse);
    expect(empty.status, CalculatorSaveNoteStatus.emptyExpression);
    expect(empty.noteId, isNull);
    expect(empty.errorMessage, isNull);
  });

  test('a superseded save writes nothing and says so', () {
    // 中文：保存在引擎往返期间被更新的输入取代时走这一条：结果没有落地，笔记也没有写。它是一条独立
    //       的状态而不是复用「没有写入」，因为原因不同——用户该做的是再按一次，而「为什么这一次没写」
    //       不该被一个刚好也说得通的文案掩盖过去。
    //       **屏幕上它说的是 `notWritten` 那句话**（领域层那两格共用一个文案格），断言因此比的是
    //       那两句相等，而不是「非空」——比「非空」宽，也比它诚实。
    // English: This is the case where a save is overtaken by newer input during the engine round trip:
    //          the result did not land and no note was written. It is its own status rather than a reuse
    //          of "not written", because the cause differs — pressing the button again is what the user
    //          should do, and "why this attempt wrote nothing" should not be papered over with a message
    //          that happens to also be true. **On screen it says what `notWritten` says** (the two
    //          domain values share one copy cell), so the assertion compares the two renderings for
    //          equality rather than asking for "non-empty" — wider than "non-empty", and more honest
    //          than it.
    const superseded = CalculatorSaveNoteResult.superseded();
    expect(superseded.saved, isFalse);
    expect(superseded.status, CalculatorSaveNoteStatus.superseded);
    expect(superseded.noteId, isNull);
    expect(calculatorSaveNoteMessage(superseded, zh),
        calculatorSaveNoteMessage(const CalculatorSaveNoteResult.notWritten(), zh));
    expect(calculatorSaveNoteMessage(superseded, zh),
        legacySentences[CalculatorSaveNoteStatus.superseded]);
  });

  test('源码里那句话只有一份：领域文件里一个宽/全角字面量都没有', () {
    // 中文：**扫的是"这个文件里有没有给人看的字"**，不是"有没有整句相同"：五句话已经全搬进
    //       `CalculatorStrings`，这个文件里再出现任何一个宽/全角字面量，都说明有人把文案抄了回来
    //       （或者新写了一句），而抄回来的那一份不会跟着语言走。尺子与提交路径、设置页、计算器页、
    //       控制器那几条护栏**同一把**（`containsWideOrFullwidth`）。
    // English: **the scan asks "does this file hold any human-facing character"**, not "is a whole
    //          sentence identical": all five sentences have moved into `CalculatorStrings`, so any
    //          wide/fullwidth literal reappearing here means somebody copied copy back (or wrote a new
    //          sentence), and the copy will not follow the language. The ruler is **the same one** as the
    //          submit path, settings page, calculator page and controller guards
    //          (`containsWideOrFullwidth`).
    final file = File('lib/domain/usecases/calculator_save_result.dart');
    expect(file.existsSync(), isTrue, reason: '测试的工作目录应当是包的根目录');
    final source = stripComments(file.readAsStringSync());
    final offenders =
        stringLiterals(source).where(containsWideOrFullwidth).toList();
    expect(offenders, isEmpty,
        reason: '这些字面量应当走 CalculatorStrings（句子只住在那里）：\n'
            '${offenders.join('\n')}');
  });
}

/// 中文：对照表里的固定载荷。两格是函数，所以渲染前得有个具体的 [CalculatorSaveNoteResult]；
///       载荷与 [legacySentences] 里那两句对得上（`'缺少右括号'`、`'Bad state: db locked'`）。
/// English: the fixed payloads of the legacy table. Two cells are functions, so rendering needs a
///          concrete [CalculatorSaveNoteResult]; the payloads match the sentences in [legacySentences]
///          (`'缺少右括号'`, `'Bad state: db locked'`).
CalculatorSaveNoteResult _resultFor(CalculatorSaveNoteStatus status) {
  return switch (status) {
    CalculatorSaveNoteStatus.saved => const CalculatorSaveNoteResult.saved(7),
    CalculatorSaveNoteStatus.emptyExpression =>
      const CalculatorSaveNoteResult.emptyExpression(),
    CalculatorSaveNoteStatus.invalidExpression =>
      CalculatorSaveNoteResult.invalidExpression('缺少右括号'),
    CalculatorSaveNoteStatus.notWritten =>
      const CalculatorSaveNoteResult.notWritten(),
    CalculatorSaveNoteStatus.failed =>
      CalculatorSaveNoteResult.failed(StateError('db locked')),
    CalculatorSaveNoteStatus.superseded =>
      const CalculatorSaveNoteResult.superseded(),
  };
}
