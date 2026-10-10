import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/domain/usecases/tool_save_result.dart';
import 'package:nekocalc/features/tools/presentation/tool_save_message.dart';
import 'package:nekocalc/features/tools/presentation/tools_strings.dart';
import 'package:nekocalc/l10n/app_language.dart';

import '../shared/source_scan.dart';

/// 中文：**「这次保存说的是哪件事」与「屏幕上那句话」分家之后，两边都还对得上。**
///
///       `ToolSaveResult` 原先自己拼那几句话并直接上屏（工具详情页、文本工具详情页、拟合页三处
///       `SnackBar` 都印 `result.message`），于是英文界面下印的仍是中文——领域对象活得比界面长，
///       界面那张按语言切的表够不着它（`docs/verification.md` §5i）。这一轮把那几句话移进
///       `ToolsStrings`，领域层只留两个令牌（[ToolSaveStatus] × [ToolSaveTarget]），由
///       `toolSaveMessage` 在呈现边缘取。这份测试是那次改动的锁，五段各管一件事：
///
///       1. **令牌与它那句话一一对应**（[legacySentences]）：五种结局 × 两个去处逐条渲染，中文侧
///          必须与迁移前源码里那句话**逐字节相同**；两个方向都查（十种组合每一种都有对照表条目，
///          对照表里每一条都命中一个真的组合）。`noResult` 与 `inputInvalid` 两句话与去处无关，
///          所以两个去处同值——那是迁移前的事实。
///       2. **回执真的跟着语言走**：同一批结果递英文表，渲染出来的既不是那句中文、也不含
///          宽/全角字符（载荷用 ASCII，因为载荷是调用方递进来的、本来就跟着调用方的语言）。
///       3. **两个载荷格真的把载荷拼进句子**：换一个 `summary` / `error`，句子里那半截必须跟着换；
///          `summary` 去掉空白后为空时**不加那个冒号**（与迁移前那条判据逐字节相同）。
///       4. **判据没变**：`saved` / `needsAttention` / `target` / `recordId` 的读数与从前一致。
///       5. **源码里那句话只有一份**：`tool_save_result.dart` 里**一个宽/全角字面量都不许有**——
///          句子只住在 `ToolsStrings` 里（与提交路径、保存笔记路径那两条护栏同一把尺子）。
///
///       **中文逐字节相同是被测试量出来的，不是被声明的**：第 1 段那张对照表就是迁移前
///       `tool_save_result.dart` 里那几条 `message:` 的抄本，故意写死在测试里。
/// English: **once "which thing this save is about" has parted from "the sentence on screen", the two
///          still line up.**
///
///          `ToolSaveResult` used to compose those sentences itself and print them straight (three
///          `SnackBar`s — the tool detail screen, the text tool detail screen and the fit screen — all
///          printed `result.message`), so an English interface still printed Chinese — a domain object
///          outlives the UI and a language-keyed interface table cannot reach it
///          (`docs/verification.md` §5i). This round moved those sentences into `ToolsStrings`, leaving
///          the domain layer with only the two tokens ([ToolSaveStatus] × [ToolSaveTarget]), resolved at
///          the presentation edge by `toolSaveMessage`. This test is that change's lock, in five parts:
///
///          1. **Token and sentence correspond one to one** ([legacySentences]): all five outcomes × two
///             destinations rendered, the Chinese side **byte-identical** to the sentence in the source
///             before the change, checked in both directions (every one of the ten combinations has a
///             table entry, every table entry hits a real combination). `noResult` and `inputInvalid` do
///             not depend on the destination, so both destinations hold the same string — that is what
///             the code did before the move, not a coincidence.
///          2. **The receipt really follows the language**: the same results with the English table
///             render neither the Chinese sentence nor any wide/fullwidth character (payloads are ASCII
///             here, because a payload is handed in by the caller and already follows the caller's
///             language).
///          3. **The two payload cells really splice their payload in**: a different `summary` / `error`
///             moves that half of the sentence, and a `summary` that is empty after trimming drops the
///             colon (the same rule as before, byte for byte).
///          4. **The verdicts have not moved**: `saved` / `needsAttention` / `target` / `recordId` read
///             as they did.
///          5. **The sentence exists once in the source**: `tool_save_result.dart` must hold **not one
///             wide/fullwidth literal** — the sentences live in `ToolsStrings` only (the same ruler as
///             the submit path's and the save-to-note path's guards).
///
///          **The byte-identity is measured, not asserted**: the table in part 1 is a copy of the
///          `message:` lines in `tool_save_result.dart` before the change, deliberately written out in
///          the test.
void main() {
  final zh = ToolsStrings.forLanguage(AppLanguage.zh);
  final en = ToolsStrings.forLanguage(AppLanguage.en);

  /// 中文：**迁移前那几句话本身**（结局 × 去处 → 它从前印什么）。这份对照表**故意写在测试里**、
  ///       不从 `ToolsStrings` 生成：它的全部价值就在于它是**旧知识的一份抄本**。
  ///       载荷格取一组固定载荷（`'电阻 R（Ω）: 无法解析数值或表达式'` 与
  ///       `'Bad state: … locked'`），句子里的其余部分因此逐字节可比。
  ///       **不要拿它去追新文案。**
  /// English: **the sentences from before the change** (outcome × destination → what it used to print).
  ///          This table is **deliberately written in the test** rather than generated from
  ///          `ToolsStrings`: its whole value is being **a copy of the old knowledge**. The payload
  ///          cells take one fixed payload each (`'电阻 R（Ω）: 无法解析数值或表达式'` and
  ///          `'Bad state: … locked'`) so the rest of the sentence is byte-comparable. **Do not bring it
  ///          up to date with new copy.**
  const legacySentences = <(ToolSaveStatus, ToolSaveTarget), String>{
    (ToolSaveStatus.saved, ToolSaveTarget.history): '结果已保存到历史记录',
    (ToolSaveStatus.saved, ToolSaveTarget.note): '已保存到笔记',
    (ToolSaveStatus.inputInvalid, ToolSaveTarget.history):
        '请先修正输入参数：电阻 R（Ω）: 无法解析数值或表达式',
    (ToolSaveStatus.inputInvalid, ToolSaveTarget.note):
        '请先修正输入参数：电阻 R（Ω）: 无法解析数值或表达式',
    (ToolSaveStatus.noResult, ToolSaveTarget.history): '没有可保存的计算结果',
    (ToolSaveStatus.noResult, ToolSaveTarget.note): '没有可保存的计算结果',
    (ToolSaveStatus.notWritten, ToolSaveTarget.history): '历史记录没有写入，请重试',
    (ToolSaveStatus.notWritten, ToolSaveTarget.note): '笔记没有写入，请重试',
    (ToolSaveStatus.failed, ToolSaveTarget.history):
        '保存历史失败：Bad state: history locked',
    (ToolSaveStatus.failed, ToolSaveTarget.note):
        '保存笔记失败：Bad state: note locked',
  };

  test('每个结局一句回执：令牌与那句话一一对应', () {
    // 中文：**中文侧逐字节相同**。断言写成一整张表逐条比，不抽查——抽查漏掉的那一条正好是将来
    //       会漂的那一条，而漂了不会有任何东西抛。
    // English: **the Chinese side is byte-identical.** The assertions walk the whole table rather than
    //          sampling: the entry a spot check skips is the one that drifts, and a drift throws
    //          nothing.
    for (final entry in legacySentences.entries) {
      final (status, target) = entry.key;
      expect(toolSaveMessage(_resultFor(status, target), zh), entry.value,
          reason: '${status.name} / ${target.name} 的回执与迁移前那句话不同了');
    }

    // 中文：**两个方向。** 五种结局 × 两个去处，十种组合每一种都要有对照表条目（漏了就是"令牌
    //       多出来"），对照表里每一条都要命中一个真的组合（多一条就是"令牌被删了、文案留着"）。
    // English: **both directions.** Five outcomes × two destinations: each of the ten combinations needs
    //          a table entry (a missing one means "a token appeared from nowhere"), and every table entry
    //          has to hit a real combination (an extra one means "the token was deleted, the copy
    //          stayed").
    final allCombinations = <(ToolSaveStatus, ToolSaveTarget)>{
      for (final status in ToolSaveStatus.values)
        for (final target in ToolSaveTarget.values) (status, target),
    };
    expect(legacySentences.keys.toSet(), allCombinations,
        reason: '令牌与旧文案对照表对不上：'
            '${legacySentences.keys.toSet().difference(allCombinations)}');
  });

  test('同一个令牌在英文表下不给中文：回执跟着语言走', () {
    // 中文：**载荷用 ASCII**：`summary` 与 `errorMessage` 是调用方递进来的数据，它们自己已经跟着
    //       调用方的语言走，所以这里量的是**句子**那一层，不是载荷那一层。
    // English: **the payloads are ASCII here**: `summary` and `errorMessage` are data handed in by the
    //          caller and already follow the caller's language, so what is measured here is the
    //          **sentence** layer, not the payload layer.
    final results = <ToolSaveResult>[
      const ToolSaveResult.savedHistory(3),
      const ToolSaveResult.savedNote(7),
      ToolSaveResult.inputInvalid(
          target: ToolSaveTarget.history, summary: 'R: bad value'),
      ToolSaveResult.inputInvalid(target: ToolSaveTarget.note, summary: '  '),
      ToolSaveResult.noResult(ToolSaveTarget.history),
      ToolSaveResult.noResult(ToolSaveTarget.note),
      ToolSaveResult.notWritten(ToolSaveTarget.history),
      ToolSaveResult.notWritten(ToolSaveTarget.note),
      ToolSaveResult.failed(
          target: ToolSaveTarget.history, error: StateError('history locked')),
      ToolSaveResult.failed(
          target: ToolSaveTarget.note, error: StateError('note locked')),
    ];
    for (final result in results) {
      final rendered = toolSaveMessage(result, en);
      expect(containsWideOrFullwidth(rendered), isFalse,
          reason: '${result.status.name} / ${result.target.name} 的英文回执里还有宽/全角字符：'
              '$rendered');
      expect(rendered, isNot(contains('。')));
    }
    // 中文：**英文表不是中文表抄两遍**：十种组合里没有一种与中文那份相同。
    // English: **the English table is not the Chinese one copied twice**: not one of the ten
    //          combinations equals its Chinese counterpart.
    for (final result in results) {
      expect(toolSaveMessage(result, en), isNot(toolSaveMessage(result, zh)),
          reason: '${result.status.name} / ${result.target.name} 在两种语言下印同一句话');
    }
  });

  test('两个载荷格真的把载荷拼进句子：换一个载荷就换一句话', () {
    // 中文：**`summary` 去掉空白后为空时不加那个冒号**——这条判据与迁移前领域层里那一条逐字节
    //       相同（它当时在构造里判，现在在呈现边缘判，因为那是文案的形状而不是结局）。
    // English: **a `summary` that is empty after trimming drops the colon** — the same rule, byte for
    //          byte, as the one the domain layer used to apply in the constructor; it now lives at the
    //          presentation edge, because it is the shape of the wording rather than the outcome.
    final bare = ToolSaveResult.inputInvalid(
        target: ToolSaveTarget.history, summary: '   ');
    expect(toolSaveMessage(bare, zh), '请先修正输入参数');

    final withSummary = ToolSaveResult.inputInvalid(
      target: ToolSaveTarget.note,
      summary: '电阻 R（Ω）: 无法解析数值或表达式',
    );
    expect(toolSaveMessage(withSummary, zh),
        '请先修正输入参数：电阻 R（Ω）: 无法解析数值或表达式');
    expect(withSummary.summary, '电阻 R（Ω）: 无法解析数值或表达式');

    final failed = ToolSaveResult.failed(
        target: ToolSaveTarget.history, error: StateError('db locked'));
    expect(toolSaveMessage(failed, zh), '保存历史失败：Bad state: db locked');
    expect(failed.errorMessage, 'Bad state: db locked');
  });

  test('结局那几条判据没有跟着文案一起动', () {
    const history = ToolSaveResult.savedHistory(3);
    expect(history.saved, isTrue);
    expect(history.needsAttention, isFalse);
    expect(history.target, ToolSaveTarget.history);
    expect(history.status, ToolSaveStatus.saved);
    expect(history.recordId, 3);

    const note = ToolSaveResult.savedNote(7);
    expect(note.saved, isTrue);
    expect(note.target, ToolSaveTarget.note);
    expect(note.recordId, 7);

    final invalid = ToolSaveResult.inputInvalid(
      target: ToolSaveTarget.history,
      summary: '电阻 R（Ω）: 无法解析数值或表达式',
    );
    expect(invalid.saved, isFalse);
    expect(invalid.needsAttention, isTrue);
    expect(invalid.status, ToolSaveStatus.inputInvalid);
    expect(toolSaveMessage(invalid, zh), contains('请先修正输入参数'));

    final noResult = ToolSaveResult.noResult(ToolSaveTarget.note);
    expect(noResult.saved, isFalse);
    expect(noResult.needsAttention, isTrue);
    expect(noResult.status, ToolSaveStatus.noResult);

    final notWritten = ToolSaveResult.notWritten(ToolSaveTarget.note);
    expect(notWritten.saved, isFalse);
    expect(notWritten.status, ToolSaveStatus.notWritten);
    expect(toolSaveMessage(notWritten, zh), '笔记没有写入，请重试');
  });

  test('源码里那句话只有一份：领域文件里一个宽/全角字面量都没有', () {
    // 中文：**扫的是"这个文件里有没有给人看的字"**，不是"有没有整句相同"：那几句话已经全搬进
    //       `ToolsStrings`，这个文件里再出现任何一个宽/全角字面量，都说明有人把文案抄了回来
    //       （或者新写了一句），而抄回来的那一份不会跟着语言走。尺子与提交路径、保存笔记路径、
    //       设置页、计算器页、控制器那几条护栏**同一把**（`containsWideOrFullwidth`）。
    // English: **the scan asks "does this file hold any human-facing character"**, not "is a whole
    //          sentence identical": the sentences have all moved into `ToolsStrings`, so any
    //          wide/fullwidth literal reappearing here means somebody copied copy back (or wrote a new
    //          sentence), and the copy will not follow the language. The ruler is **the same one** as the
    //          submit path, save-to-note path, settings page, calculator page and controller guards
    //          (`containsWideOrFullwidth`).
    final file = File('lib/domain/usecases/tool_save_result.dart');
    expect(file.existsSync(), isTrue, reason: '测试的工作目录应当是包的根目录');
    final source = stripComments(file.readAsStringSync());
    final offenders =
        stringLiterals(source).where(containsWideOrFullwidth).toList();
    expect(offenders, isEmpty,
        reason: '这些字面量应当走 ToolsStrings（句子只住在那里）：\n'
            '${offenders.join('\n')}');
  });
}

/// 中文：对照表里的固定载荷。两格是函数，所以渲染前得有个具体的 [ToolSaveResult]；载荷与
///       [legacySentences] 里那两句对得上（`'电阻 R（Ω）: 无法解析数值或表达式'` 与
///       `'Bad state: … locked'`）。
/// English: the fixed payloads of the legacy table. Two cells are functions, so rendering needs a
///          concrete [ToolSaveResult]; the payloads match the sentences in [legacySentences]
///          (`'电阻 R（Ω）: 无法解析数值或表达式'` and `'Bad state: … locked'`).
ToolSaveResult _resultFor(ToolSaveStatus status, ToolSaveTarget target) {
  return switch (status) {
    ToolSaveStatus.saved => target == ToolSaveTarget.history
        ? const ToolSaveResult.savedHistory(3)
        : const ToolSaveResult.savedNote(7),
    ToolSaveStatus.inputInvalid => ToolSaveResult.inputInvalid(
        target: target,
        summary: '电阻 R（Ω）: 无法解析数值或表达式',
      ),
    ToolSaveStatus.noResult => ToolSaveResult.noResult(target),
    ToolSaveStatus.notWritten => ToolSaveResult.notWritten(target),
    ToolSaveStatus.failed => ToolSaveResult.failed(
        target: target,
        error: target == ToolSaveTarget.history
            ? StateError('history locked')
            : StateError('note locked'),
      ),
  };
}
