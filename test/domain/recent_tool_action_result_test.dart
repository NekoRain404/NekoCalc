import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/domain/usecases/recent_tool_action_result.dart';
import 'package:nekocalc/features/tools/presentation/recent_tool_action_message.dart';
import 'package:nekocalc/features/tools/presentation/tools_strings.dart';
import 'package:nekocalc/l10n/app_language.dart';

import '../shared/source_scan.dart';

/// 中文：**「这次最近使用动作说的是哪件事」与「屏幕上那句话」分家之后，两边都还对得上。**
///
///       `RecentToolActionResult` 原先自己拼那五句话并直接上屏（`tools_home_page.dart` 的
///       `SnackBar` 印 `result.message`），于是英文界面下印的仍是中文——领域对象活得比界面长，
///       界面那张按语言切的表够不着它（`docs/verification.md` §5i）。这一轮把那几句话移进
///       `ToolsStrings`，领域层只留令牌（[RecentToolActionStatus]，`failed` 那一格再靠
///       [RecentToolAction] 分两支），由 `recentToolActionMessage` 在呈现边缘取。这份测试是那次
///       改动的锁，四段各管一件事：
///
///       1. **令牌与它那句话一一对应**（[legacySentences]）：**六个**结局逐条渲染——五个状态里
///          `failed` 有「移除失败」与「清空失败」两种印法，所以对照表的键是
///          `(状态, 动作)` 二元组，六格。中文侧必须与迁移前源码里那句话**逐字节相同**；
///          两个方向都查（每个状态、每个动作都有对照表条目，对照表里每一条都命中真的枚举值）。
///          这就是「产出方漏写令牌」与「令牌多出来」的唯一防线——两样都不会抛，只会静默少一句
///          或错一句。
///       2. **回执真的跟着语言走**：同一批结果递英文表，渲染出来的既不是那句中文、也不含
///          宽/全角字符（载荷用 ASCII，因为载荷是调用方递进来的、本来就跟着调用方的语言）。
///       3. **判据没变**：`succeeded` / `needsAttention` / `changed` 三条行为判据的宽度与从前
///          一致（迁移一个字都没动它们），负数条数归零那两条归一化也算判据的一部分。
///       4. **源码里那句话只有一份**：`recent_tool_action_result.dart` 里**一个宽/全角字面量都不许
///          有**——句子只住在 `ToolsStrings` 里。（与计算器那条同口径：有一句带载荷，抄回半句
///          `'已从最近使用移除「'` 这类前缀同样不会跟语言走，所以整个文件按"零宽字符"来守。）
///
///       **中文逐字节相同是被测试量出来的，不是被声明的**：第 1 段那张对照表就是迁移前
///       `recent_tool_action_result.dart` 里那几行 `message:` 的抄本，故意写死在测试里。
/// English: **once "which thing this recently-used action is about" has parted from "the sentence on
///          screen", the two still line up.**
///
///          `RecentToolActionResult` used to compose those five sentences itself and print them
///          straight (`tools_home_page.dart`'s `SnackBar` printed `result.message`), so an English
///          interface still printed Chinese — a domain object outlives the UI and a language-keyed
///          interface table cannot reach it (`docs/verification.md` §5i). This round moved those
///          sentences into `ToolsStrings`, leaving the domain layer with only the token
///          ([RecentToolActionStatus], with [RecentToolAction] splitting the `failed` cell in two),
///          resolved at the presentation edge by `recentToolActionMessage`. This test is that change's
///          lock, in four parts:
///
///          1. **Token and sentence correspond one to one** ([legacySentences]): **six** outcomes
///             rendered — of the five statuses, `failed` prints either "remove failed" or "clear
///             failed", so the table is keyed by a `(status, action)` pair with six cells. The Chinese
///             side must be **byte-identical** to the sentence in the source before the change, checked
///             in both directions (every status and every action has a table entry, every table entry
///             hits a real enum value). This is the only defence against "a producer forgot the token"
///             and "a token appeared from nowhere" — neither throws, they only silently drop or swap a
///             sentence.
///          2. **The receipt really follows the language**: the same results with the English table
///             render neither the Chinese sentence nor any wide/fullwidth character (payloads are
///             ASCII here, because a payload is handed in by the caller and already follows the
///             caller's language).
///          3. **The verdicts have not moved**: `succeeded` / `needsAttention` / `changed` keep the
///             width they had (the change did not touch them by one character), and the two
///             negative-count normalisations count as verdicts too.
///          4. **The sentence exists once in the source**: `recent_tool_action_result.dart` must hold
///             **not one wide/fullwidth literal** — the sentences live in `ToolsStrings` only. (The
///             same rule as the calculator guard: one sentence carries a payload, but copying even its
///             half sentence back would not follow the language, so the whole file is held to "zero
///             wide characters".)
///
///          **The byte-identity is measured, not asserted**: the table in part 1 is a copy of the
///          `message:` lines in `recent_tool_action_result.dart` before the change, deliberately
///          written out in the test.
void main() {
  final zh = ToolsStrings.forLanguage(AppLanguage.zh);
  final en = ToolsStrings.forLanguage(AppLanguage.en);

  /// 中文：**迁移前那几句话本身**（(状态, 动作) → 它从前印什么）。这份对照表**故意写在测试里**、
  ///       不从 `ToolsStrings` 生成：它的全部价值就在于它是**旧知识的一份抄本**（与
  ///       `calculator_submit_result_test.dart` 里那份 `legacySentences` 同一个理由）。载荷格取
  ///       固定载荷，句子里的其余部分因此逐字节可比。**不要拿它去追新文案。**
  /// English: **the sentences from before the change** ((status, action) → what it used to print). This
  ///          table is **deliberately written in the test** rather than generated from `ToolsStrings`:
  ///          its whole value is being **a copy of the old knowledge** (the same reason
  ///          `legacySentences` in `calculator_submit_result_test.dart` exists). The payload cells take
  ///          one fixed payload each so the rest of the sentence is byte-comparable. **Do not bring it
  ///          up to date with new copy.**
  const legacySentences =
      <(RecentToolActionStatus, RecentToolAction), String>{
    (RecentToolActionStatus.removed, RecentToolAction.remove):
        '已从最近使用移除「JSON格式化」',
    (RecentToolActionStatus.notFound, RecentToolAction.remove):
        '这项最近使用已经不存在',
    (RecentToolActionStatus.cleared, RecentToolAction.clear): '已清空 3 个最近工具',
    (RecentToolActionStatus.alreadyEmpty, RecentToolAction.clear):
        '最近使用已经是空的',
    (RecentToolActionStatus.failed, RecentToolAction.remove):
        '移除最近使用失败：Bad state: db locked',
    (RecentToolActionStatus.failed, RecentToolAction.clear):
        '清空最近使用失败：Bad state: db locked',
  };

  test('每个结局一句回执：令牌与那句话一一对应', () {
    // 中文：**中文侧逐字节相同**。断言写成一整张表逐条比，不抽查——抽查漏掉的那一条正好是将来
    //       会漂的那一条，而漂了不会有任何东西抛。
    // English: **the Chinese side is byte-identical.** The assertions walk the whole table rather than
    //          sampling: the entry a spot check skips is the one that drifts, and a drift throws
    //          nothing.
    for (final entry in legacySentences.entries) {
      expect(
        recentToolActionMessage(_resultFor(entry.key.$1, entry.key.$2), zh),
        entry.value,
        reason: '${entry.key.$1.name}/${entry.key.$2.name} 的回执与迁移前那句话不同了',
      );
    }

    // 中文：**两个方向。** 五个状态、两条动作各自都要有对照表条目（漏了就是"令牌多出来"），
    //       对照表里每一条都要命中真的枚举值（多一条就是"令牌被删了、文案留着"）。
    // English: **both directions.** All five statuses and both actions need a table entry (a missing
    //          one means "a token appeared from nowhere"), and every table entry has to hit a real enum
    //          value (an extra one means "the token was deleted, the copy stayed").
    expect(
      legacySentences.keys.map((key) => key.$1).toSet(),
      RecentToolActionStatus.values.toSet(),
      reason: '状态与旧文案对照表对不上：'
          '${legacySentences.keys.map((key) => key.$1).toSet().difference(RecentToolActionStatus.values.toSet())}',
    );
    expect(
      legacySentences.keys.map((key) => key.$2).toSet(),
      RecentToolAction.values.toSet(),
      reason: '动作与旧文案对照表对不上：'
          '${legacySentences.keys.map((key) => key.$2).toSet().difference(RecentToolAction.values.toSet())}',
    );
  });

  test('同一个令牌在英文表下不给中文：回执跟着语言走', () {
    // 中文：**载荷用 ASCII**：工具名与错误串是调用方递进来的数据，它们自己已经跟着调用方的语言走，
    //       所以这里量的是**句子**那一层，不是载荷那一层。
    // English: **the payloads are ASCII here**: the tool name and the error string are data handed in
    //          by the caller and already follow the caller's language, so what is measured here is the
    //          **sentence** layer, not the payload layer.
    final results = <RecentToolActionResult>[
      RecentToolActionResult.remove(
          toolTitle: 'JSON Formatter', affectedCount: 1),
      RecentToolActionResult.remove(
          toolTitle: 'JSON Formatter', affectedCount: 0),
      RecentToolActionResult.clear(affectedCount: 3),
      RecentToolActionResult.clear(affectedCount: 0),
      RecentToolActionResult.failed(
          action: RecentToolAction.remove, error: StateError('db locked')),
      RecentToolActionResult.failed(
          action: RecentToolAction.clear, error: StateError('db locked')),
    ];
    for (final result in results) {
      final rendered = recentToolActionMessage(result, en);
      expect(containsWideOrFullwidth(rendered), isFalse,
          reason: '${result.status.name}/${result.action.name} 的英文回执里还有宽/全角字符：$rendered');
      expect(rendered, isNot(contains('。')));
    }
    // 中文：**英文表不是中文表抄两遍**：六句里没有一句与中文那份相同。
    // English: **the English table is not the Chinese one copied twice**: not one of the six equals
    //          its Chinese counterpart.
    for (final result in results) {
      expect(recentToolActionMessage(result, en),
          isNot(recentToolActionMessage(result, zh)),
          reason: '${result.status.name}/${result.action.name} 在两种语言下印同一句话');
    }
  });

  test('载荷格真的把载荷拼进句子：换一个载荷就换一句话', () {
    // 中文：载荷不是装饰：同一个令牌换一个工具名 / 条数 / 错误串，句子里那半截必须跟着换。
    // English: the payload is not decoration: the same token with a different tool name, count or
    //          error string has to move that half of the sentence.
    final removed =
        RecentToolActionResult.remove(toolTitle: '奥姆定律', affectedCount: 2);
    expect(removed.toolTitle, '奥姆定律');
    expect(recentToolActionMessage(removed, zh), '已从最近使用移除「奥姆定律」');

    final cleared = RecentToolActionResult.clear(affectedCount: 7);
    expect(cleared.affectedCount, 7);
    expect(recentToolActionMessage(cleared, zh), '已清空 7 个最近工具');

    final failed = RecentToolActionResult.failed(
        action: RecentToolAction.clear, error: StateError('disk full'));
    expect(failed.errorMessage, 'Bad state: disk full');
    expect(recentToolActionMessage(failed, zh), '清空最近使用失败：Bad state: disk full');
  });

  test('结局那三条行为判据没有跟着文案一起动', () {
    final removed = RecentToolActionResult.remove(
      toolTitle: 'JSON格式化',
      affectedCount: 1,
    );
    expect(removed.status, RecentToolActionStatus.removed);
    expect(removed.changed, isTrue);

    final missing = RecentToolActionResult.remove(
      toolTitle: 'JSON格式化',
      affectedCount: 0,
    );
    expect(missing.status, RecentToolActionStatus.notFound);
    expect(missing.succeeded, isTrue);
    expect(missing.changed, isFalse);

    final cleared = RecentToolActionResult.clear(affectedCount: 3);
    expect(cleared.status, RecentToolActionStatus.cleared);
    expect(cleared.changed, isTrue);

    final empty = RecentToolActionResult.clear(affectedCount: 0);
    expect(empty.status, RecentToolActionStatus.alreadyEmpty);
    expect(empty.succeeded, isTrue);
    expect(empty.changed, isFalse);

    final failedResult = RecentToolActionResult.failed(
      action: RecentToolAction.clear,
      error: StateError('db locked'),
    );
    expect(failedResult.status, RecentToolActionStatus.failed);
    expect(failedResult.succeeded, isFalse);
    expect(failedResult.needsAttention, isTrue);
    expect(failedResult.errorMessage, contains('db locked'));

    // 中文：负数条数归一化为零之后落回"没找到 / 本来就是空的"那两格——判据的一部分，一并钉住。
    // English: a negative count normalises to zero and lands back on "not found / already empty" —
    //          part of the verdicts, pinned here too.
    expect(
      RecentToolActionResult.remove(toolTitle: 'JSON格式化', affectedCount: -2)
          .status,
      RecentToolActionStatus.notFound,
    );
    expect(
      RecentToolActionResult.clear(affectedCount: -3).status,
      RecentToolActionStatus.alreadyEmpty,
    );
  });

  test('源码里那句话只有一份：领域文件里一个宽/全角字面量都没有', () {
    // 中文：**扫的是"这个文件里有没有给人看的字"**，不是"有没有整句相同"：那几句话已经全搬进
    //       `ToolsStrings`，这个文件里再出现任何一个宽/全角字面量，都说明有人把文案抄了回来
    //       （或者新写了一句），而抄回来的那一份不会跟着语言走。尺子与计算器、设置页那几条护栏
    //       **同一把**（`containsWideOrFullwidth`）。
    // English: **the scan asks "does this file hold any human-facing character"**, not "is a whole
    //          sentence identical": the sentences have moved into `ToolsStrings`, so any wide/fullwidth
    //          literal reappearing here means somebody copied copy back (or wrote a new sentence), and
    //          the copy will not follow the language. The ruler is **the same one** as the calculator
    //          and settings-page guards (`containsWideOrFullwidth`).
    final file = File('lib/domain/usecases/recent_tool_action_result.dart');
    expect(file.existsSync(), isTrue, reason: '测试的工作目录应当是包的根目录');
    final source = stripComments(file.readAsStringSync());
    final offenders =
        stringLiterals(source).where(containsWideOrFullwidth).toList();
    expect(offenders, isEmpty,
        reason: '这些字面量应当走 ToolsStrings（句子只住在那里）：\n'
            '${offenders.join('\n')}');
  });
}

/// 中文：对照表里的固定载荷。`failed` 两格是同一个状态、两种印法，所以要 [action] 才分得开；
///       载荷与 [legacySentences] 里那几句对得上（`'JSON格式化'`、`3`、`'Bad state: db locked'`）。
/// English: the fixed payloads of the legacy table. The two `failed` cells share a status and differ
///          only in [action]; the payloads match the sentences in [legacySentences] (`'JSON格式化'`,
///          `3`, `'Bad state: db locked'`).
RecentToolActionResult _resultFor(
  RecentToolActionStatus status,
  RecentToolAction action,
) {
  return switch (status) {
    RecentToolActionStatus.removed => RecentToolActionResult.remove(
        toolTitle: 'JSON格式化',
        affectedCount: 1,
      ),
    RecentToolActionStatus.notFound => RecentToolActionResult.remove(
        toolTitle: 'JSON格式化',
        affectedCount: 0,
      ),
    RecentToolActionStatus.cleared =>
      RecentToolActionResult.clear(affectedCount: 3),
    RecentToolActionStatus.alreadyEmpty =>
      RecentToolActionResult.clear(affectedCount: 0),
    RecentToolActionStatus.failed => RecentToolActionResult.failed(
        action: action,
        error: StateError('db locked'),
      ),
  };
}
