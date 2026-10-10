import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/domain/usecases/notes_clipboard_import.dart';
import 'package:nekocalc/domain/usecases/notes_delete_result.dart';
import 'package:nekocalc/features/notes/presentation/notes_receipt_message.dart';
import 'package:nekocalc/features/notes/presentation/notes_strings.dart';
import 'package:nekocalc/l10n/app_language.dart';

import '../shared/source_scan.dart';

/// 中文：**「这次回执说的是哪件事」与「屏幕上那句话」分家之后，两边都还对得上。**
///
///       `NotesClipboardImportPlan` / `NotesClipboardImportResult` / `NotesDeleteResult` 原先自己拼
///       那几句中文并直接上屏（导入对话框里的 `plan.summary`，以及 `notes_page_actions.dart` 四处
///       `SnackBar` 印的 `result.message` / `result.importedMessage`），于是英文界面下印的仍是中文——
///       领域对象活得比界面长，界面那张按语言切的表够不着它（`docs/verification.md` §5i）。这一轮把
///       那些句子移进 `NotesStrings`，领域层只留令牌（`NotesImportPlanStatus` /
///       `NotesImportReceiptStatus` / `NotesDeleteStatus`），由 `notes_receipt_message.dart` 在呈现
///       边缘取。这份测试是那次改动的锁，五段各管一件事：
///
///       1. **令牌与它那句话一一对应**（三张 `legacy*Sentences` 对照表）：每一种结局逐条渲染，中文侧
///          必须与迁移前源码里那句话**逐字节相同**；两个方向都查（枚举里每一格都有对照表条目，
///          对照表里每一条都命中一个真的枚举值）。**表里只放头部那一句**——可选的两根尾巴
///          （「跳过 N 段…」「未写入 N 条」「N 项未找到或已被删除」）由第 3 段单独量。
///       2. **回执真的跟着语言走**：同一批结果递英文表，渲染出来的既不是那句中文、也不含宽/全角
///          字符（载荷用 ASCII，因为载荷是调用方递进来的、本来就跟着调用方的语言）。
///       3. **载荷真的拼进句子**：换计数、加尾巴，句子里那半截必须跟着换；尾巴只在计数非零时出现。
///       4. **判据没变**：三个 `status` 令牌与它们背后的旧读数（`canImport` / `hasDeletedRecords` /
///          `missingCount`…）与从前一致（迁移一个字都没动它们）。
///       5. **源码里那句话只有一份**：两个领域文件里**一个宽/全角字面量都不许有**（下面那段说明
///          为什么 `notes_clipboard_import.dart` 只量结果类那一段），且迁移前那几句句子在两个文件里
///          一个字都不许留。
///
///       **中文逐字节相同是被测试量出来的，不是被声明的**：三张对照表就是迁移前那两个文件里那几条
///       `return` 的抄本，故意写死在测试里。**不要拿它们去追新文案。**
/// English: **once "which thing this receipt is about" has parted from "the sentence on screen", the two
///          still line up.**
///
///          `NotesClipboardImportPlan` / `NotesClipboardImportResult` / `NotesDeleteResult` used to
///          compose those Chinese sentences themselves and print them straight (`plan.summary` in the
///          import dialog, `result.message` / `result.importedMessage` in four `SnackBar`s in
///          `notes_page_actions.dart`), so an English interface still printed Chinese — a domain object
///          outlives the UI and a language-keyed interface table cannot reach it
///          (`docs/verification.md` §5i). This round moved those sentences into `NotesStrings`, leaving
///          the domain layer with only the tokens (`NotesImportPlanStatus` / `NotesImportReceiptStatus`
///          / `NotesDeleteStatus`), resolved at the presentation edge by `notes_receipt_message.dart`.
///          This test is that change's lock, in five parts:
///
///          1. **Token and sentence correspond one to one** (three `legacy*Sentences` tables): every
///             outcome rendered, the Chinese side **byte-identical** to the sentence in the source
///             before the change, checked in both directions (every enum value has a table entry, every
///             entry hits a real enum value). **The tables hold the head sentence only** — the optional
///             tails ("skipped N blocks…", "N not written", "N not found or already deleted") are
///             measured separately in part 3.
///          2. **The receipt really follows the language**: the same results with the English table
///             render neither the Chinese sentence nor any wide/fullwidth character (payloads are ASCII
///             here, because a payload is handed in by the caller and already follows the caller's
///             language).
///          3. **The payloads really splice into the sentence**: a different count, or an added tail,
///             moves that half of the sentence; a tail appears only when its count is non-zero.
///          4. **The verdicts have not moved**: the three `status` tokens and the old readings behind
///             them (`canImport` / `hasDeletedRecords` / `missingCount` …) read as they did.
///          5. **The sentence exists once in the source**: the two domain files must hold **not one
///             wide/fullwidth literal** (the note under part 5 explains why only the result classes'
///             stretch of `notes_clipboard_import.dart` is measured), and the pre-move sentences must
///             not survive anywhere in either file.
///
///          **The byte-identity is measured, not asserted**: the three tables are copies of those
///          `return`s in the two domain files before the change, deliberately written out in the test.
///          **Do not bring them up to date with new copy.**
void main() {
  final zh = NotesStrings.forLanguage(AppLanguage.zh);
  final en = NotesStrings.forLanguage(AppLanguage.en);

  /// 中文：**迁移前那三句话本身**（结局 → 它从前印什么）。这三张表**故意写在测试里**、不从
  ///       `NotesStrings` 生成：它们的全部价值就在于它们是**旧知识的一份抄本**（与
  ///       `calculator_save_result_test.dart` 里那份 `legacySentences` 同一个理由）。载荷取一组固定
  ///       值，句子里的其余部分因此逐字节可比。
  /// English: **the sentences from before the change** (outcome → what it used to print). These three
  ///          tables are **deliberately written in the test** rather than generated from
  ///          `NotesStrings`: their whole value is being **a copy of the old knowledge** (the same
  ///          reason `legacySentences` in `calculator_save_result_test.dart` exists). The payloads take
  ///          one fixed set each, so the rest of the sentence is byte-comparable.
  const legacyPlanSentences = <NotesImportPlanStatus, String>{
    NotesImportPlanStatus.clipboardEmpty: '剪贴板没有文本内容',
    NotesImportPlanStatus.nothingRecognised: '未识别到可导入的笔记或历史导出',
    NotesImportPlanStatus.willImport: '将导入 1 条历史、2 条笔记',
  };
  const legacyReceiptSentences = <NotesImportReceiptStatus, String>{
    NotesImportReceiptStatus.imported: '已导入 1 条历史、2 条笔记',
    NotesImportReceiptStatus.nothingNew: '没有导入新内容',
  };
  const legacyDeleteSentences = <NotesDeleteStatus, String>{
    NotesDeleteStatus.nothingRequested: '没有选择要删除的记录',
    NotesDeleteStatus.deleted: '已删除 1 条历史、2 条笔记',
    // 中文：**这一格躲不开那根尾巴**：`nothingDeleted` 意味着「请求了东西、一条都没删掉」，
    //       于是 `missingCount` 必然非零，迁移前那句话也必然带上「，N 项未找到或已被删除」。
    //       这是迁移前的事实（不是这一轮的选择），所以对照表里连尾巴一起写。
    // English: **this cell cannot dodge that tail**: `nothingDeleted` means "something was requested and
    //          nothing was deleted", so `missingCount` is necessarily non-zero and the pre-move sentence
    //          necessarily carried ", N not found or already deleted". That is pre-move fact (not a
    //          choice this round made), so the table spells the tail out too.
    NotesDeleteStatus.nothingDeleted: '没有删除记录，1 项未找到或已被删除',
  };

  test('每个结局一句回执：令牌与那句话一一对应', () {
    // 中文：**中文侧逐字节相同**。断言写成一整张表逐条比，不抽查——抽查漏掉的那一条正好是将来
    //       会漂的那一条，而漂了不会有任何东西抛。
    // English: **the Chinese side is byte-identical.** The assertions walk the whole table rather than
    //          sampling: the entry a spot check skips is the one that drifts, and a drift throws
    //          nothing.
    for (final entry in legacyPlanSentences.entries) {
      expect(notesImportPlanSummary(_planFor(entry.key), zh), entry.value,
          reason: '${entry.key.name} 的计划摘要与迁移前那句话不同了');
    }
    for (final entry in legacyReceiptSentences.entries) {
      expect(notesImportMessage(_resultFor(entry.key), zh), entry.value,
          reason: '${entry.key.name} 的导入回执与迁移前那句话不同了');
    }
    for (final entry in legacyDeleteSentences.entries) {
      expect(notesDeleteMessage(_deleteFor(entry.key), zh), entry.value,
          reason: '${entry.key.name} 的删除回执与迁移前那句话不同了');
    }

    // 中文：**两个方向。** 枚举里每一格都要有对照表条目（漏了就是"令牌多出来"），对照表里每一条
    //       都要命中一个真的枚举值（多一条就是"令牌被删了、文案留着"）。
    // English: **both directions.** Every enum value needs a table entry (a missing one means "a token
    //          appeared from nowhere"), and every table entry has to hit a real enum value (an extra one
    //          means "the token was deleted, the copy stayed").
    expect(legacyPlanSentences.keys.toSet(), NotesImportPlanStatus.values.toSet(),
        reason: '计划令牌与旧文案对照表对不上：'
            '${legacyPlanSentences.keys.toSet().difference(NotesImportPlanStatus.values.toSet())}');
    expect(legacyReceiptSentences.keys.toSet(),
        NotesImportReceiptStatus.values.toSet(),
        reason: '导入回执令牌与旧文案对照表对不上：'
            '${legacyReceiptSentences.keys.toSet().difference(NotesImportReceiptStatus.values.toSet())}');
    expect(legacyDeleteSentences.keys.toSet(), NotesDeleteStatus.values.toSet(),
        reason: '删除令牌与旧文案对照表对不上：'
            '${legacyDeleteSentences.keys.toSet().difference(NotesDeleteStatus.values.toSet())}');
  });

  test('同一个令牌在英文表下不给中文：回执跟着语言走', () {
    // 中文：**载荷用 ASCII**：计数是调用方递进来的数据、本来就跟着调用方的语言，所以这里量的是
    //       **句子**那一层，不是载荷那一层。三张表里的每一种结局都过一遍。
    // English: **the payloads are ASCII here**: the counts are data handed in by the caller and already
    //          follow the caller's language, so what is measured here is the **sentence** layer, not the
    //          payload layer. Every outcome of the three tables goes through.
    final rendered = <String>[
      for (final status in NotesImportPlanStatus.values)
        notesImportPlanSummary(_planFor(status), en),
      for (final status in NotesImportReceiptStatus.values)
        notesImportMessage(_resultFor(status), en),
      for (final status in NotesDeleteStatus.values)
        notesDeleteMessage(_deleteFor(status), en),
    ];
    for (final message in rendered) {
      expect(containsWideOrFullwidth(message), isFalse,
          reason: '英文回执里还有宽/全角字符：$message');
      expect(message, isNot(contains('。')));
    }
    // 中文：**英文表不是中文表抄两遍**：每一种结局在两种语言下都不同。
    // English: **the English table is not the Chinese one copied twice**: every outcome differs between
    //          the two languages.
    for (final status in NotesImportPlanStatus.values) {
      expect(notesImportPlanSummary(_planFor(status), en),
          isNot(notesImportPlanSummary(_planFor(status), zh)),
          reason: '${status.name} 在两种语言下印同一句话');
    }
    for (final status in NotesImportReceiptStatus.values) {
      expect(notesImportMessage(_resultFor(status), en),
          isNot(notesImportMessage(_resultFor(status), zh)),
          reason: '${status.name} 在两种语言下印同一句话');
    }
    for (final status in NotesDeleteStatus.values) {
      expect(notesDeleteMessage(_deleteFor(status), en),
          isNot(notesDeleteMessage(_deleteFor(status), zh)),
          reason: '${status.name} 在两种语言下印同一句话');
    }
  });

  test('载荷真的拼进句子：换一个计数、加一根尾巴，句子就跟着换', () {
    // 中文：**尾巴只在计数非零时出现。** 三种尾巴各量一次「出现」与「不出现」——两条断言比"有字"
    //       与"没字"诚实：只查出现的话，一个永远追加的尾巴也过。
    // English: **a tail appears only when its count is non-zero.** Each of the three tails is measured
    //          once for "appears" and once for "does not appear" — comparing the two is more honest than
    //          asking for "some text": with only the positive check, a tail that is always appended
    //          would pass.
    final plan = _planFor(NotesImportPlanStatus.willImport);
    expect(notesImportPlanSummary(plan, zh), '将导入 1 条历史、2 条笔记');
    final noisyPlan = _planFor(NotesImportPlanStatus.willImport, skipped: 3);
    expect(notesImportPlanSummary(noisyPlan, zh), '将导入 1 条历史、2 条笔记，跳过 3 段无法识别内容');
    expect(notesImportPlanMessage(plan, zh), '已导入 1 条历史、2 条笔记');
    // 中文：计划那条回执与结果那条的措辞**故意不同**（「跳过 N 段」对「跳过 N 段无法识别内容」）——
    //       两句都是迁移前的原样，各钉一条。
    // English: the plan-side receipt and the result-side one deliberately word the skip differently
    //          ("skipping N blocks" against "skipping N unrecognised blocks") — both are as they were
    //          before the move, and each is pinned by its own line.
    expect(notesImportPlanMessage(noisyPlan, zh), '已导入 1 条历史、2 条笔记，跳过 3 段');

    final imported = _resultFor(NotesImportReceiptStatus.imported);
    expect(notesImportMessage(imported, zh), '已导入 1 条历史、2 条笔记');
    final withTails = NotesClipboardImportResult(
      plan: noisyPlan,
      historyIds: imported.historyIds,
      noteIds: imported.noteIds,
      skippedNoteWrites: 2,
    );
    expect(notesImportMessage(withTails, zh),
        '已导入 1 条历史、2 条笔记，跳过 3 段无法识别内容，未写入 2 条');
    expect(
      notesImportMessage(
        NotesClipboardImportResult(
          plan: _planFor(NotesImportPlanStatus.nothingRecognised),
          historyIds: const [],
          noteIds: const [],
          skippedNoteWrites: 1,
        ),
        zh,
      ),
      '没有导入新内容，未写入 1 条',
    );

    // 中文：计数那一格跟着真的删掉的条数走，不跟着请求的条数走：请求 5 条、删掉 1 条历史与 2 条笔记时，
    //       句子里写的是 1 与 2（缺的那些走尾巴，见下一条）。
    // English: the counts cell follows the records really deleted, not the requested ones: with 5
    //          requested and 1 history record plus 2 notes actually deleted, the sentence says 1 and 2
    //          (the missing ones go into the tail, the next assertion).
    const deleted = NotesDeleteResult(
      requestedHistoryCount: 5,
      requestedNoteCount: 5,
      deletedHistoryCount: 1,
      deletedNoteCount: 2,
    );
    expect(notesDeleteMessage(deleted, zh), '已删除 1 条历史、2 条笔记，7 项未找到或已被删除');
    const allDeleted = NotesDeleteResult(
      requestedHistoryCount: 1,
      requestedNoteCount: 2,
      deletedHistoryCount: 1,
      deletedNoteCount: 2,
    );
    expect(notesDeleteMessage(allDeleted, zh), '已删除 1 条历史、2 条笔记');
    const partlyMissing = NotesDeleteResult(
      requestedHistoryCount: 2,
      requestedNoteCount: 1,
      deletedHistoryCount: 1,
      deletedNoteCount: 0,
    );
    expect(notesDeleteMessage(partlyMissing, zh), '已删除 1 条历史，2 项未找到或已被删除');
  });

  test('结局那几条读数没有跟着文案一起动', () {
    // 中文：令牌是**派生**的，不是新的一份状态：`status` 与它背后的旧读数必须永远同源。
    //       （这正是模板里那条"判据与文案是同一个字段"：两者由同一个字段回答，不可能对不上。）
    // English: the token is **derived**, not a second copy of the state: `status` and the old readings
    //          behind it must always come from one source. (That is the template's rule "verdict and
    //          wording are one field": one field answers both, so they cannot disagree.)
    final importable = _planFor(NotesImportPlanStatus.willImport);
    expect(importable.canImport, isTrue);
    expect(importable.status, NotesImportPlanStatus.willImport);
    expect(_planFor(NotesImportPlanStatus.clipboardEmpty).sourceTextEmpty, isTrue);
    expect(_planFor(NotesImportPlanStatus.clipboardEmpty).status,
        NotesImportPlanStatus.clipboardEmpty);
    expect(_planFor(NotesImportPlanStatus.nothingRecognised).canImport, isFalse);
    expect(_planFor(NotesImportPlanStatus.nothingRecognised).status,
        NotesImportPlanStatus.nothingRecognised);

    final imported = _resultFor(NotesImportReceiptStatus.imported);
    expect(imported.hasImportedRecords, isTrue);
    expect(imported.receiptStatus, NotesImportReceiptStatus.imported);
    final nothingNew = _resultFor(NotesImportReceiptStatus.nothingNew);
    expect(nothingNew.hasImportedRecords, isFalse);
    expect(nothingNew.receiptStatus, NotesImportReceiptStatus.nothingNew);

    final deleted = _deleteFor(NotesDeleteStatus.deleted);
    expect(deleted.hasDeletedRecords, isTrue);
    expect(deleted.missingCount, 0);
    expect(deleted.status, NotesDeleteStatus.deleted);
    final nothingDeleted = _deleteFor(NotesDeleteStatus.nothingDeleted);
    expect(nothingDeleted.requestedCount, 1);
    expect(nothingDeleted.hasDeletedRecords, isFalse);
    expect(nothingDeleted.status, NotesDeleteStatus.nothingDeleted);
  });

  test('源码里那句话只有一份：两个领域文件里的结果类一个宽/全角字面量都没有', () {
    // 中文：**扫的是"这里有没有给人看的字"**，不是"有没有整句相同"：句子已经全搬进 `NotesStrings`，
    //       结果类那一段里再出现任何一个宽/全角字面量，都说明有人把文案抄了回来（或者新写了一句），
    //       而抄回来的那一份不会跟着语言走。尺子与提交路径、保存路径那两条护栏**同一把**
    //       （`containsWideOrFullwidth`）。
    //
    //       **`notes_clipboard_import.dart` 只量"结果类那一段"**，不是整个文件：这个文件同时装着
    //       **剪贴板往返的格式**——解析器认的那九个标签（`'笔记:'`、`'表达式:'`、`'结果:'`、
    //       `'工具历史:'`、`'计算历史'`、`'NekoCalc 批量导出'`…）与两个草稿的兜底标题。它们是**数据
    //       格式**，不是给用户看的句子：跟着界面语言翻掉，粘贴就不再认得自己写出来的导出文本
    //       （同一个坑，`calculator_report_labels.dart` 的文件头上写着）。所以这一段从
    //       `class NotesClipboardImportPlan {` 量到 `NotesClipboardImportPlan
    //       buildNotesClipboardImportPlan(String text) {` 之前——**两个端点都必须找得到**，否则
    //       扫的就可能是一段空字符串（那种"全过"最危险）。
    //
    //       两条底线的第二条：迁移前那几句句子**在两个文件里一个字都不许留**，不管它藏在哪一段。
    // English: **the scan asks "does this file hold any human-facing character"**, not "is a whole
    //          sentence identical": the sentences have moved into `NotesStrings`, so any wide/fullwidth
    //          literal reappearing in the result classes' stretch means somebody copied copy back (or
    //          wrote a new sentence), and the copy will not follow the language. The ruler is **the same
    //          one** as the submit and save paths' guards (`containsWideOrFullwidth`).
    //
    //          **Only the result classes' stretch of `notes_clipboard_import.dart` is measured**, not the
    //          whole file: that file also carries the **clipboard round-trip format** — the nine labels
    //          the parser knows (`'笔记:'`, `'表达式:'`, `'结果:'`, `'工具历史:'`, `'计算历史'`,
    //          `'NekoCalc 批量导出'` …) and the two drafts' fallback titles. Those are a **data format**,
    //          not sentences for a user: translate them with the interface and a paste would no longer
    //          recognise the export this app itself wrote (the same trap, written on
    //          `calculator_report_labels.dart`'s file head). So the stretch runs from
    //          `class NotesClipboardImportPlan {` up to (but not including)
    //          `NotesClipboardImportPlan buildNotesClipboardImportPlan(String text) {` — **both endpoints
    //          must be found**, or the scan could be measuring an empty string (the kind of "all pass"
    //          that is the most dangerous).
    //
    //          The second floor: the pre-move sentences must **not survive anywhere** in the two files,
    //          whatever stretch they hide in.
    final importFile = File('lib/domain/usecases/notes_clipboard_import.dart');
    final deleteFile = File('lib/domain/usecases/notes_delete_result.dart');
    expect(importFile.existsSync() && deleteFile.existsSync(), isTrue,
        reason: '测试的工作目录应当是包的根目录');

    final importSource = stripComments(importFile.readAsStringSync());
    const startMarker = 'class NotesClipboardImportPlan {';
    const endMarker =
        'NotesClipboardImportPlan buildNotesClipboardImportPlan(String text) {';
    final start = importSource.indexOf(startMarker);
    final end = importSource.indexOf(endMarker);
    expect(start, isNot(-1), reason: '找不到结果类的起点：$startMarker');
    expect(end, isNot(-1), reason: '找不到结果类的终点：$endMarker');
    expect(end, greaterThan(start), reason: '结果类那一段的两个端点顺序反了');

    final deleteSource = stripComments(deleteFile.readAsStringSync());
    final offenders = <String>[
      ...stringLiterals(importSource.substring(start, end))
          .where(containsWideOrFullwidth)
          .map((literal) => 'notes_clipboard_import.dart: $literal'),
      ...stringLiterals(deleteSource)
          .where(containsWideOrFullwidth)
          .map((literal) => 'notes_delete_result.dart: $literal'),
    ];
    expect(offenders, isEmpty,
        reason: '这些字面量应当走 NotesStrings（句子只住在那里）：\n'
            '${offenders.join('\n')}');

    // 中文：**旧句子一个字都不许留**（整份文件，含注释被剥掉后的正文）。列表就是那三张对照表里
    //       的句子去重——将来有人把某一句抄回领域文件，这条会红。
    // English: **not one word of the old sentences may stay** (the whole file, comments stripped). The
    //          list is the three legacy tables' sentences, de-duplicated — if somebody copies one back
    //          into a domain file, this goes red.
    final legacySentences = <String>{
      ...legacyPlanSentences.values,
      ...legacyReceiptSentences.values,
      ...legacyDeleteSentences.values,
      // 中文：对照表只放头部那两句，尾巴单独列——它们是同一个函数拼出来的另一半。
      // English: the tables hold the heads only; the tails are listed apart — they are the other half
      //          the same functions compose.
      '跳过 3 段无法识别内容',
      '跳过 3 段',
      '未写入 2 条',
      '2 项未找到或已被删除',
    };
    for (final sentence in legacySentences) {
      expect(importSource.contains(sentence), isFalse,
          reason: '领域文件 notes_clipboard_import.dart 里还留着旧句子：$sentence');
      expect(deleteSource.contains(sentence), isFalse,
          reason: '领域文件 notes_delete_result.dart 里还留着旧句子：$sentence');
    }
  });
}

/// 中文：对照表里的固定载荷。三张表按令牌取值，所以渲染前得有一个具体的计划 / 结果；
///       载荷与那三张对照表里的句子对得上（1 条历史、2 条笔记，没有尾巴）。
/// English: the fixed payloads of the legacy tables. The tables are keyed by token, so rendering needs
///          a concrete plan / result; the payloads match the sentences in the three tables (1 history
///          record, 2 notes, no tails).
NotesClipboardImportPlan _planFor(NotesImportPlanStatus status, {int skipped = 0}) {
  switch (status) {
    case NotesImportPlanStatus.clipboardEmpty:
      return const NotesClipboardImportPlan(
        noteDrafts: [],
        historyDrafts: [],
        skippedBlockCount: 0,
        fromBatchExport: false,
        sourceTextEmpty: true,
      );
    case NotesImportPlanStatus.nothingRecognised:
      return const NotesClipboardImportPlan(
        noteDrafts: [],
        historyDrafts: [],
        skippedBlockCount: 0,
        fromBatchExport: true,
        sourceTextEmpty: false,
      );
    case NotesImportPlanStatus.willImport:
      return NotesClipboardImportPlan(
        noteDrafts: List<NotesNoteImportDraft>.filled(2, _noteDraft),
        historyDrafts: const [_historyDraft],
        skippedBlockCount: skipped,
        fromBatchExport: true,
        sourceTextEmpty: false,
      );
  }
}

NotesClipboardImportResult _resultFor(NotesImportReceiptStatus status) {
  switch (status) {
    case NotesImportReceiptStatus.imported:
      return NotesClipboardImportResult(
        plan: _planFor(NotesImportPlanStatus.willImport),
        historyIds: const [1],
        noteIds: const [2, 3],
      );
    case NotesImportReceiptStatus.nothingNew:
      return NotesClipboardImportResult(
        plan: _planFor(NotesImportPlanStatus.nothingRecognised),
        historyIds: const [],
        noteIds: const [],
      );
  }
}

NotesDeleteResult _deleteFor(NotesDeleteStatus status) {
  switch (status) {
    case NotesDeleteStatus.nothingRequested:
      return NotesDeleteResult.none();
    case NotesDeleteStatus.deleted:
      return const NotesDeleteResult(
        requestedHistoryCount: 1,
        requestedNoteCount: 2,
        deletedHistoryCount: 1,
        deletedNoteCount: 2,
      );
    case NotesDeleteStatus.nothingDeleted:
      return const NotesDeleteResult(
        requestedHistoryCount: 1,
        requestedNoteCount: 0,
        deletedHistoryCount: 0,
        deletedNoteCount: 0,
      );
  }
}

/// 中文：两个草稿只是**载荷**（数量与正文都不进这三张对照表里量到的那半句），内容取最短的一对。
/// English: the two drafts are **payload** only (neither their count nor their body enters the half of
///          the sentence the three legacy tables measure); the shortest pair will do.
const NotesNoteImportDraft _noteDraft = NotesNoteImportDraft(
  title: 'T',
  description: '',
  body: '',
  source: NotesImportSource.note,
);

const NotesHistoryImportDraft _historyDraft = NotesHistoryImportDraft(
  expression: '2+3',
  result: '5',
  toolId: null,
  createdAt: null,
  sourceTimeLabel: null,
);
