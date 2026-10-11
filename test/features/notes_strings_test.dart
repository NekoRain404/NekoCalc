import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/models/history_item.dart';
import 'package:nekocalc/data/models/note_item.dart';
import 'package:nekocalc/domain/usecases/notes_clipboard_import.dart';
import 'package:nekocalc/features/notes/presentation/notes_import_draft_message.dart';
import 'package:nekocalc/features/notes/presentation/notes_page.dart';
import 'package:nekocalc/features/notes/presentation/notes_strings.dart';
import 'package:nekocalc/l10n/app_language.dart';

import '../shared/source_scan.dart';

/// 中文：笔记页文案表的几条护栏，形状与设置页 / 计算页那两张表的护栏相同。
///       1) 中文表的每一条都要与翻译前源码里那一句**逐字节相同**——默认语言是中文，所以屏幕上
///          每一个字都得和接入多语言之前一模一样。逐条写出来而不是抽查几条：这一份就是"默认态
///          不变"的**证据本身**，抽查漏掉的那一条正好是将来会漂的那一条。
///       2) 英文表里不许出现汉字、也不许出现空串。
///       3) 笔记页源码里（除了这张表本身）不许再留中文字符串字面量。
///       4) **写进库、画在对话框里的那几句**（空标题兜底、历史笔记的标题与描述、剪贴板导入生成的
///          标题与描述、导入对话框两行预览用的三格）：英文侧不含宽/全角字符，中文侧正是那些字
///          （两把方向相反的断言互为反证）。
///       5) **`notes_controller.dart` 里不再有那些句子**，且那几格真的被接上（令牌与拼装函数都在）
///          ——扫的是那几条具体的句子，因为那个文件还装着故意留下的剪贴板往返格式。
///       6) **英文这条路的成品是英文**：剪贴板导入的草稿递英文表，拼出来的标题与描述是英文句子
///          （`notes_import_draft_message.dart`），与领域测试里那条保存路径的证明同源。
///
///       **第 3 条有一处明写的例外**，写在下面 `_nonUiLiterals` 上：按笔记内容挑图标用的那三条
///       内容探针。它们是**拿用户的笔记内容去比**，不是屏幕上印的字。
/// English: The guard rails for the notes page's copy table, the same shape as the settings and
///          calculator tables'. (1) Every Chinese entry must be **byte-identical** to the sentence in
///          the source before translation — the default language is Chinese, so every character on
///          screen has to read exactly as it did before i18n existed. Written out one by one rather
///          than sampled: this list **is** the evidence for "the default state does not change", and
///          the one entry a spot check skips is the one that drifts. (2) The English table must hold
///          no CJK and no empty string. (3) No Chinese string literal may remain in the notes page's
///          sources other than this table. (4) **The sentences written into the database and painted in
///          the dialog** (the blank-title fallback, the history note's title and description, the
///          clipboard import's generated title and description, and the three cells behind the import
///          dialog's two preview rows): the English side holds no wide/fullwidth character and the
///          Chinese side holds exactly those (two opposite assertions proving each other). (5) **not
///          one of those sentences is left in `notes_controller.dart`**, and those cells are really
///          wired in (the tokens and the composer both present) — the scan asks about those specific
///          sentences, because that file also carries the deliberately kept clipboard round-trip
///          format. (6) **the English road's output is English**: a clipboard import draft handed the
///          English table composes an English title and description
///          (`notes_import_draft_message.dart`) — the same proof as the save path's in the domain test.
///
///          **Clause 3 has one stated exception**, on `_nonUiLiterals` below: the three content
///          probes used to pick a note's icon. They are compared against **the user's own note text**,
///          not printed anywhere.
String _identityLabel(String label) => label;

void main() {
  final zh = NotesStrings.forLanguage(AppLanguage.zh);
  final en = NotesStrings.forLanguage(AppLanguage.en);

  test('中文表与迁移前源码里那些字逐字节相同', () {
    // —— 页头、搜索与胶囊 ——
    expect(zh.pageTitle, '笔记');
    expect(zh.searchHint, '搜索笔记、历史、公式...');
    expect(zh.clearSearchTooltip, '清除');
    expect(zh.tabAll, '全部');
    expect(zh.tabNotes, '笔记');
    expect(zh.tabHistory, '历史');
    expect(zh.tabFormulas, '公式');
    expect(zh.tabTools, '工具');
    expect(zh.historySectionTitle, '计算历史');
    expect(zh.notesSectionTitle, '个人笔记');
    // —— 多选态 ——
    expect(zh.cancelSelection, '取消选择');
    expect(zh.selectedCount(1), '已选择 1 项');
    expect(zh.selectVisible, '选择当前列表');
    expect(zh.copySelected, '复制所选');
    expect(zh.deleteSelected, '删除所选');
    expect(zh.deleteSelectedConfirm(2, 3), '确认删除 2 条历史和 3 条笔记？此操作无法撤销。');
    expect(zh.copiedItems(4), '已复制 4 项');
    // —— 历史：单条动作与清空 ——
    expect(zh.copyResult, '复制结果');
    expect(zh.saveAsNote, '保存为笔记');
    expect(zh.deleteHistoryEntry, '删除记录');
    expect(zh.deleteHistoryTooltip, '删除');
    expect(zh.historyResultCopied, '已复制历史结果');
    expect(zh.savedToNotes, '已保存到笔记');
    expect(zh.clearHistory, '清空历史');
    expect(zh.clearHistoryConfirm, '确认删除全部计算历史？笔记不会受影响。');
    // —— 笔记：单条动作 ——
    expect(zh.pinNote, '置顶笔记');
    expect(zh.unpinNote, '取消置顶');
    expect(zh.pinned, '已置顶笔记');
    expect(zh.unpinned, '已取消置顶');
    expect(zh.archiveNote, '归档笔记');
    expect(zh.unarchiveNote, '取消归档');
    expect(zh.archived, '已归档笔记');
    expect(zh.unarchived, '已取消归档');
    expect(zh.editNote, '编辑笔记');
    expect(zh.copyNote, '复制笔记');
    expect(zh.noteCopied, '已复制笔记');
    expect(zh.deleteNote, '删除笔记');
    expect(zh.deleteNoteConfirm('标题'), '确认删除“标题”？此操作无法撤销。');
    expect(zh.moreTooltip, '更多');
    // —— 删除确认（共用）——
    expect(zh.cancel, '取消');
    expect(zh.delete, '删除');
    expect(zh.clear, '清空');
    // —— 剪贴板导入 ——
    expect(zh.clipboardImportTitle, '从剪贴板导入');
    expect(zh.importButton, '导入');
    expect(zh.hiddenCount(3), '还有 3 条未显示');
    // —— 导入 / 删除回执（迁移前它们住在领域层，逐字节搬过来）——
    expect(zh.importClipboardEmpty, '剪贴板没有文本内容');
    expect(zh.importNothingRecognised, '未识别到可导入的笔记或历史导出');
    expect(zh.importWillImport('1 条历史、1 条笔记'), '将导入 1 条历史、1 条笔记');
    expect(zh.imported('1 条历史、1 条笔记'), '已导入 1 条历史、1 条笔记');
    expect(zh.importNothingNew, '没有导入新内容');
    expect(zh.importSkippedUnrecognised(2), '跳过 2 段无法识别内容');
    expect(zh.importPlanSkipped(2), '跳过 2 段');
    expect(zh.importSkippedWrites(3), '未写入 3 条');
    expect(zh.recordCounts(1, 2), '1 条历史、2 条笔记');
    expect(zh.recordCounts(0, 2), '2 条笔记');
    expect(zh.clauseSeparator, '，');
    expect(zh.deleteNothingRequested, '没有选择要删除的记录');
    expect(zh.deletedRecords('1 条历史、1 条笔记'), '已删除 1 条历史、1 条笔记');
    expect(zh.deleteNothingDeleted, '没有删除记录');
    expect(zh.deleteMissing(2), '2 项未找到或已被删除');
    // —— 笔记编辑器 ——
    expect(zh.newNote, '新增笔记');
    expect(zh.fieldTitle, '标题');
    expect(zh.fieldDescription, '描述');
    expect(zh.fieldDescriptionHint, '写清用途、来源或下一步处理');
    expect(zh.fieldBody, '内容');
    expect(zh.tagLabel, '标签');
    expect(zh.fieldTagsHint, '用逗号分隔，例如：实验, 待处理');
    expect(zh.save, '保存');
    // —— 筛选面板 ——
    expect(zh.noteFilterTitle, '笔记筛选');
    expect(zh.archiveFilterLabel, '状态');
    expect(zh.archiveActive, '未归档');
    expect(zh.archiveArchived, '已归档');
    expect(zh.archiveAll, '全部状态');
    expect(zh.sortLabel, '排序');
    expect(zh.sortUpdatedNewest, '最近更新');
    expect(zh.sortUpdatedOldest, '最早更新');
    expect(zh.sortTitleAscending, '标题 A-Z');
    expect(zh.allTags, '全部标签');
    expect(zh.apply, '应用');
    // —— 空态与加载 ——
    expect(zh.loadingHistory, '正在加载历史记录。');
    expect(zh.historyLoadFailed('x'), '历史读取失败：x');
    expect(zh.historyEmpty, '暂无历史记录。');
    expect(zh.historyEmptyFiltered, '当前筛选下没有历史记录。');
    expect(zh.loadingNotes, '正在加载笔记。');
    expect(zh.notesLoadFailed('x'), '笔记读取失败：x');
    expect(zh.notesEmpty, '暂无个人笔记。');
    expect(zh.notesEmptyFiltered, '当前筛选下没有个人笔记。');
    expect(zh.loadingMoreNotes, '正在加载');
    expect(zh.loadMoreNotes, '加载更多笔记');
    // —— 筛选摘要条（迁移前住在 `NotesVisibleSummary.label` 里，逐字节搬过来）——
    expect(zh.summaryTabAll, '全部记录');
    expect(zh.summaryTabNotes, '笔记');
    expect(zh.summaryTabHistory, '历史');
    expect(zh.summaryTabFormulas, '公式');
    expect(zh.summaryTabTools, '工具');
    expect(zh.summarySearching('Ω'), '搜索“Ω”');
    expect(zh.summaryNoMatch, '无匹配');
    expect(zh.summaryHistoryCount(2), '历史 2');
    expect(zh.summaryNoteCount(1), '笔记 1');
    expect(zh.summaryPartsSeparator, ' · ');
    // —— 保存时生成、写进库的标题与描述（迁移前硬编码在 `NotesController` 里，逐字节搬过来）——
    expect(zh.untitledNote, '未命名笔记');
    expect(zh.historyNoteTitle, '历史结果');
    expect(zh.historyNoteDescription('2026/06/08 09:30'), '由计算历史保存，时间 2026/06/08 09:30');
    // —— 剪贴板导入生成、写进库的标题与描述（迁移前硬编码在 `notes_clipboard_import.dart` 里，
    //    逐字节搬过来；拼接改由 `notes_import_draft_message.dart` 在保存边缘做）——
    expect(zh.importedNoteTitle, '导入笔记');
    expect(zh.clipboardNoteTitle('临时想法'), '剪贴板笔记 · 临时想法');
    expect(zh.clipboardNoteBlankFirstLine, '剪贴板内容');
    expect(zh.clipboardNoteDescription, '从剪贴板导入的文本');
    // —— 导入对话框的预览行（同一批句子，也从那个文件搬来；画那一行时按语言取）——
    expect(zh.historyPreviewTitle('2+3'), '计算历史 · 2+3');
    expect(zh.toolHistoryPreviewTitle('2+3'), '工具历史 · 2+3');
    expect(zh.historyPreviewDescription('ohms_law', '2026/06/08 10:15'),
        '工具 ohms_law · 原时间 2026/06/08 10:15');
    // 中文：两截都可缺：只有一段时不带分隔符，两段都缺时是空串（画的时候不留副标题）。
    // English: either half may be missing: a lone half carries no separator, and both missing gives the
    //          empty string (no subtitle is drawn).
    expect(zh.historyPreviewDescription('ohms_law', null), '工具 ohms_law');
    expect(zh.historyPreviewDescription(null, null), '');

    // 中文：而英文侧真的换了——否则上面那些"逐字节相同"只是把中文抄了两遍。
    // English: and the English side really differs, otherwise the byte-identical checks above would
    //          just be the Chinese copied out twice.
    for (final pair in <List<String>>[
      [zh.pageTitle, en.pageTitle],
      [zh.searchHint, en.searchHint],
      [zh.clearSearchTooltip, en.clearSearchTooltip],
      [zh.tabAll, en.tabAll],
      [zh.tabNotes, en.tabNotes],
      [zh.tabHistory, en.tabHistory],
      [zh.tabFormulas, en.tabFormulas],
      [zh.tabTools, en.tabTools],
      [zh.historySectionTitle, en.historySectionTitle],
      [zh.notesSectionTitle, en.notesSectionTitle],
      [zh.cancelSelection, en.cancelSelection],
      [zh.selectedCount(1), en.selectedCount(1)],
      [zh.selectVisible, en.selectVisible],
      [zh.copySelected, en.copySelected],
      [zh.deleteSelected, en.deleteSelected],
      [zh.deleteSelectedConfirm(2, 3), en.deleteSelectedConfirm(2, 3)],
      [zh.copiedItems(4), en.copiedItems(4)],
      [zh.copyResult, en.copyResult],
      [zh.saveAsNote, en.saveAsNote],
      [zh.deleteHistoryEntry, en.deleteHistoryEntry],
      [zh.deleteHistoryTooltip, en.deleteHistoryTooltip],
      [zh.historyResultCopied, en.historyResultCopied],
      [zh.savedToNotes, en.savedToNotes],
      [zh.clearHistory, en.clearHistory],
      [zh.clearHistoryConfirm, en.clearHistoryConfirm],
      [zh.pinNote, en.pinNote],
      [zh.unpinNote, en.unpinNote],
      [zh.pinned, en.pinned],
      [zh.unpinned, en.unpinned],
      [zh.archiveNote, en.archiveNote],
      [zh.unarchiveNote, en.unarchiveNote],
      [zh.archived, en.archived],
      [zh.unarchived, en.unarchived],
      [zh.editNote, en.editNote],
      [zh.copyNote, en.copyNote],
      [zh.noteCopied, en.noteCopied],
      [zh.deleteNote, en.deleteNote],
      [zh.deleteNoteConfirm('标题'), en.deleteNoteConfirm('标题')],
      [zh.moreTooltip, en.moreTooltip],
      [zh.cancel, en.cancel],
      [zh.delete, en.delete],
      [zh.clear, en.clear],
      [zh.clipboardImportTitle, en.clipboardImportTitle],
      [zh.importButton, en.importButton],
      [zh.hiddenCount(3), en.hiddenCount(3)],
      [zh.importClipboardEmpty, en.importClipboardEmpty],
      [zh.importNothingRecognised, en.importNothingRecognised],
      [zh.importWillImport('1 条历史、1 条笔记'),
        en.importWillImport('1 history entry and 1 note')],
      [zh.imported('1 条历史、1 条笔记'), en.imported('1 history entry and 1 note')],
      [zh.importNothingNew, en.importNothingNew],
      [zh.importSkippedUnrecognised(2), en.importSkippedUnrecognised(2)],
      [zh.importPlanSkipped(2), en.importPlanSkipped(2)],
      [zh.importSkippedWrites(3), en.importSkippedWrites(3)],
      [zh.recordCounts(1, 2), en.recordCounts(1, 2)],
      [zh.deleteNothingRequested, en.deleteNothingRequested],
      [zh.deletedRecords('1 条历史、1 条笔记'), en.deletedRecords('1 history entry')],
      [zh.deleteNothingDeleted, en.deleteNothingDeleted],
      [zh.deleteMissing(2), en.deleteMissing(2)],
      [zh.newNote, en.newNote],
      [zh.fieldTitle, en.fieldTitle],
      [zh.fieldDescription, en.fieldDescription],
      [zh.fieldDescriptionHint, en.fieldDescriptionHint],
      [zh.fieldBody, en.fieldBody],
      [zh.tagLabel, en.tagLabel],
      [zh.fieldTagsHint, en.fieldTagsHint],
      [zh.save, en.save],
      [zh.noteFilterTitle, en.noteFilterTitle],
      [zh.archiveFilterLabel, en.archiveFilterLabel],
      [zh.archiveActive, en.archiveActive],
      [zh.archiveArchived, en.archiveArchived],
      [zh.archiveAll, en.archiveAll],
      [zh.sortLabel, en.sortLabel],
      [zh.sortUpdatedNewest, en.sortUpdatedNewest],
      [zh.sortUpdatedOldest, en.sortUpdatedOldest],
      [zh.sortTitleAscending, en.sortTitleAscending],
      [zh.allTags, en.allTags],
      [zh.apply, en.apply],
      [zh.loadingHistory, en.loadingHistory],
      [zh.historyLoadFailed('x'), en.historyLoadFailed('x')],
      [zh.historyEmpty, en.historyEmpty],
      [zh.historyEmptyFiltered, en.historyEmptyFiltered],
      [zh.loadingNotes, en.loadingNotes],
      [zh.notesLoadFailed('x'), en.notesLoadFailed('x')],
      [zh.notesEmpty, en.notesEmpty],
      [zh.notesEmptyFiltered, en.notesEmptyFiltered],
      [zh.loadingMoreNotes, en.loadingMoreNotes],
      [zh.loadMoreNotes, en.loadMoreNotes],
      [zh.summaryTabAll, en.summaryTabAll],
      [zh.summaryTabNotes, en.summaryTabNotes],
      [zh.summaryTabHistory, en.summaryTabHistory],
      [zh.summaryTabFormulas, en.summaryTabFormulas],
      [zh.summaryTabTools, en.summaryTabTools],
      [zh.summarySearching('Ω'), en.summarySearching('Ω')],
      [zh.summaryNoMatch, en.summaryNoMatch],
      [zh.summaryHistoryCount(2), en.summaryHistoryCount(2)],
      [zh.summaryNoteCount(1), en.summaryNoteCount(1)],
      [zh.untitledNote, en.untitledNote],
      [zh.historyNoteTitle, en.historyNoteTitle],
      [zh.historyNoteDescription('2026/06/08 09:30'),
        en.historyNoteDescription('2026/06/08 09:30')],
      [zh.importedNoteTitle, en.importedNoteTitle],
      [zh.clipboardNoteTitle('临时想法'), en.clipboardNoteTitle('AB')],
      [zh.clipboardNoteBlankFirstLine, en.clipboardNoteBlankFirstLine],
      [zh.clipboardNoteDescription, en.clipboardNoteDescription],
      [zh.historyPreviewTitle('2+3'), en.historyPreviewTitle('2+3')],
      [zh.toolHistoryPreviewTitle('2+3'), en.toolHistoryPreviewTitle('2+3')],
      [zh.historyPreviewDescription('ohms_law', '2026/06/08 10:15'),
        en.historyPreviewDescription('ohms_law', '2026/06/08 10:15')],
    ]) {
      expect(pair[0], isNot(pair[1]), reason: '「${pair[0]}」在英文表里没换');
    }
  });

  test('英文表里没有汉字，也没有空串', () {
    final copy = <String, String>{
      'pageTitle': en.pageTitle,
      'searchHint': en.searchHint,
      'clearSearchTooltip': en.clearSearchTooltip,
      'tabAll': en.tabAll,
      'tabNotes': en.tabNotes,
      'tabHistory': en.tabHistory,
      'tabFormulas': en.tabFormulas,
      'tabTools': en.tabTools,
      'historySectionTitle': en.historySectionTitle,
      'notesSectionTitle': en.notesSectionTitle,
      'cancelSelection': en.cancelSelection,
      'selectedCount': en.selectedCount(1),
      'selectVisible': en.selectVisible,
      'copySelected': en.copySelected,
      'deleteSelected': en.deleteSelected,
      'deleteSelectedConfirm': en.deleteSelectedConfirm(2, 3),
      'copiedItems': en.copiedItems(4),
      'copyResult': en.copyResult,
      'saveAsNote': en.saveAsNote,
      'deleteHistoryEntry': en.deleteHistoryEntry,
      'deleteHistoryTooltip': en.deleteHistoryTooltip,
      'historyResultCopied': en.historyResultCopied,
      'savedToNotes': en.savedToNotes,
      'clearHistory': en.clearHistory,
      'clearHistoryConfirm': en.clearHistoryConfirm,
      'pinNote': en.pinNote,
      'unpinNote': en.unpinNote,
      'pinned': en.pinned,
      'unpinned': en.unpinned,
      'archiveNote': en.archiveNote,
      'unarchiveNote': en.unarchiveNote,
      'archived': en.archived,
      'unarchived': en.unarchived,
      'editNote': en.editNote,
      'copyNote': en.copyNote,
      'noteCopied': en.noteCopied,
      'deleteNote': en.deleteNote,
      'deleteNoteConfirm': en.deleteNoteConfirm('T'),
      'moreTooltip': en.moreTooltip,
      'cancel': en.cancel,
      'delete': en.delete,
      'clear': en.clear,
      'clipboardImportTitle': en.clipboardImportTitle,
      'importButton': en.importButton,
      'hiddenCount': en.hiddenCount(3),
      'importClipboardEmpty': en.importClipboardEmpty,
      'importNothingRecognised': en.importNothingRecognised,
      'importWillImport': en.importWillImport('1 history entry'),
      'imported': en.imported('1 history entry'),
      'importNothingNew': en.importNothingNew,
      'importSkippedUnrecognised': en.importSkippedUnrecognised(2),
      'importPlanSkipped': en.importPlanSkipped(2),
      'importSkippedWrites': en.importSkippedWrites(3),
      'recordCounts': en.recordCounts(1, 2),
      'clauseSeparator': en.clauseSeparator,
      'deleteNothingRequested': en.deleteNothingRequested,
      'deletedRecords': en.deletedRecords('1 history entry'),
      'deleteNothingDeleted': en.deleteNothingDeleted,
      'deleteMissing': en.deleteMissing(2),
      'newNote': en.newNote,
      'fieldTitle': en.fieldTitle,
      'fieldDescription': en.fieldDescription,
      'fieldDescriptionHint': en.fieldDescriptionHint,
      'fieldBody': en.fieldBody,
      'tagLabel': en.tagLabel,
      'fieldTagsHint': en.fieldTagsHint,
      'save': en.save,
      'noteFilterTitle': en.noteFilterTitle,
      'archiveFilterLabel': en.archiveFilterLabel,
      'archiveActive': en.archiveActive,
      'archiveArchived': en.archiveArchived,
      'archiveAll': en.archiveAll,
      'sortLabel': en.sortLabel,
      'sortUpdatedNewest': en.sortUpdatedNewest,
      'sortUpdatedOldest': en.sortUpdatedOldest,
      'sortTitleAscending': en.sortTitleAscending,
      'allTags': en.allTags,
      'apply': en.apply,
      'loadingHistory': en.loadingHistory,
      'historyLoadFailed': en.historyLoadFailed('x'),
      'historyEmpty': en.historyEmpty,
      'historyEmptyFiltered': en.historyEmptyFiltered,
      'loadingNotes': en.loadingNotes,
      'notesLoadFailed': en.notesLoadFailed('x'),
      'notesEmpty': en.notesEmpty,
      'notesEmptyFiltered': en.notesEmptyFiltered,
      'loadingMoreNotes': en.loadingMoreNotes,
      'loadMoreNotes': en.loadMoreNotes,
      'summaryTabAll': en.summaryTabAll,
      'summaryTabNotes': en.summaryTabNotes,
      'summaryTabHistory': en.summaryTabHistory,
      'summaryTabFormulas': en.summaryTabFormulas,
      'summaryTabTools': en.summaryTabTools,
      'summarySearching': en.summarySearching('Ω'),
      'summaryNoMatch': en.summaryNoMatch,
      'summaryHistoryCount': en.summaryHistoryCount(2),
      'summaryNoteCount': en.summaryNoteCount(1),
      'untitledNote': en.untitledNote,
      'historyNoteTitle': en.historyNoteTitle,
      'historyNoteDescription': en.historyNoteDescription('2026/06/08 09:30'),
      'importedNoteTitle': en.importedNoteTitle,
      'clipboardNoteTitle': en.clipboardNoteTitle('AB'),
      'clipboardNoteBlankFirstLine': en.clipboardNoteBlankFirstLine,
      'clipboardNoteDescription': en.clipboardNoteDescription,
      'historyPreviewTitle': en.historyPreviewTitle('2+3'),
      'toolHistoryPreviewTitle': en.toolHistoryPreviewTitle('2+3'),
      'historyPreviewDescription':
          en.historyPreviewDescription('ohms_law', '2026/06/08 10:15'),
    };
    for (final entry in copy.entries) {
      expect(entry.value.trim(), isNotEmpty, reason: '${entry.key} 是空的');
      expect(_containsCjk(entry.value), isFalse,
          reason: '${entry.key} 英文表里还有汉字：${entry.value}');
    }
    // 中文：中文侧同样不许有空串——空串在屏幕上是"这一格什么都没有"，最难发现的一类漏翻。
    // English: the Chinese side must hold no empty string either: on screen it renders as a blank
    //          cell, the hardest kind of missing copy to notice.
    expect(zh.fieldDescriptionHint.trim(), isNotEmpty);
    expect(zh.searchHint.trim(), isNotEmpty);
  });

  test('写进库的那几句：英文不含宽/全角字符，中文侧正是那些字', () {
    // 中文：这几格是**写进库**的字（标题留空时的兜底、从历史保存时的标题与描述、剪贴板导入时生成的
    //       标题与描述、外加导入对话框那两行预览用的三格），所以"哪一侧用了哪套字"要单独量：英文侧用
    //       与其它护栏**同一把尺子**（`containsWideOrFullwidth`，连 `·` 一起算），而中文侧必须**真的**
    //       含宽/全角字符——否则"英文侧没有"那一天尺子坏了就成了假通过。两条方向相反的断言互为反证。
    //       **这一条也是"中文侧保留了那个 `·`"的证人**：中文句子里的 `·` 在这把尺子下算宽/全角，
    //       英文侧换成 ASCII 的 `: ` 与 `, `，两边都过。
    // English: these cells are **written into the database** (the blank-title fallback, the
    //          title/description used when saving from history, the title/description generated by a
    //          clipboard import, plus the three cells behind the import dialog's two preview rows), so
    //          which side uses which character set is measured on its own: the English side with **the
    //          same ruler** as the other guards (`containsWideOrFullwidth`, which counts `·` too), and
    //          the Chinese side must **really** hold wide/fullwidth characters — otherwise "the English
    //          side has none" would be a false pass the day the ruler broke. Two opposite assertions
    //          prove each other. **This is also the witness that the Chinese side kept its `·`**: the
    //          Chinese sentences' `·` is wide/fullwidth under this ruler, the English side uses ASCII
    //          `: ` and `, ` instead, and both pass.
    const timestamp = '2026/06/08 09:30';
    final englishCells = <String>[
      en.untitledNote,
      en.historyNoteTitle,
      en.historyNoteDescription(timestamp),
      en.importedNoteTitle,
      en.clipboardNoteTitle('AB'),
      en.clipboardNoteBlankFirstLine,
      en.clipboardNoteDescription,
      en.historyPreviewTitle('2+3'),
      en.toolHistoryPreviewTitle('2+3'),
      en.historyPreviewDescription('ohms_law', timestamp),
    ];
    final chineseCells = <String>[
      zh.untitledNote,
      zh.historyNoteTitle,
      zh.historyNoteDescription(timestamp),
      zh.importedNoteTitle,
      zh.clipboardNoteTitle('临时想法'),
      zh.clipboardNoteBlankFirstLine,
      zh.clipboardNoteDescription,
      zh.historyPreviewTitle('2+3'),
      zh.toolHistoryPreviewTitle('2+3'),
      zh.historyPreviewDescription('ohms_law', timestamp),
    ];
    for (final cell in englishCells) {
      expect(containsWideOrFullwidth(cell), isFalse,
          reason: '英文这一格还有宽/全角字符：$cell');
    }
    for (final cell in chineseCells) {
      expect(containsWideOrFullwidth(cell), isTrue,
          reason: '中文这一格居然一个宽/全角字符都没有，尺子可能坏了：$cell');
    }
  });

  test('英文这条路：剪贴板导入的草稿递英文表，拼出来的就是英文句子', () {
    // 中文：**这一条是那笔具名欠账的成品证明**（`docs/verification.md` §5m）：同一条草稿——领域层
    //       给的是令牌与载荷，一个汉字都没有——递中文表出中文、递英文表出**英文**。第三段（旧句子
    //       不许留在控制器里）证明"字搬走了"，这一条证明"搬到了能跟着语言走的地方"。
    // English: **this is the finished-product proof for that named debt** (`docs/verification.md`
    //          §5m): the same draft — the domain hands over a token and payloads, not one Chinese
    //          character — gives Chinese with the Chinese table and **English** with the English one.
    //          The third clause (old sentences must not stay in the controller) proves "the words
    //          moved"; this proves "they moved somewhere that follows the language".
    final plan = buildNotesClipboardImportPlan('Temporary idea\ncheck units next');
    final draft = plan.noteDrafts.single;
    expect(draft.wording, NotesNoteDraftWording.clipboard);
    expect(draft.title, 'Temporary idea');

    expect(notesNoteDraftTitle(draft, zh), '剪贴板笔记 · Temporary idea');
    expect(notesNoteDraftDescription(draft, zh), '从剪贴板导入的文本');
    expect(notesNoteDraftTitle(draft, en), 'Clipboard note: Temporary idea');
    expect(notesNoteDraftDescription(draft, en), 'Text imported from the clipboard');
    // 中文：**保存边缘拼出来的那一份不许再含宽/全角**——它要写进库，英文界面下存进去的就是这一份。
    // English: **what the save edge composes must hold no wide/fullwidth character** — it goes into the
    //          database, and under an English interface this is the copy that lands there.
    expect(containsWideOrFullwidth(notesNoteDraftTitle(draft, en)), isFalse);
    expect(containsWideOrFullwidth(notesNoteDraftDescription(draft, en)), isFalse);

    // 中文：没有标题的导出块（`parsed` 那一支）同一条路：中文 `'导入笔记'`、英文 `'Imported note'`。
    // English: an export block with no title (the `parsed` branch) takes the same road: `'导入笔记'` in
    //          Chinese, `'Imported note'` in English.
    const untitled = NotesNoteImportDraft(
      wording: NotesNoteDraftWording.parsed,
      title: '',
      description: '',
      body: '',
    );
    expect(notesNoteDraftTitle(untitled, zh), '导入笔记');
    expect(notesNoteDraftTitle(untitled, en), 'Imported note');
    expect(containsWideOrFullwidth(notesNoteDraftTitle(untitled, en)), isFalse);

    // 中文：对话框那两行预览（历史行）同样：递英文表就是英文，载荷（表达式、工具名、原时间）原样。
    // English: the dialog's two preview rows (the history one) behave the same: the English table gives
    //          English while the payloads (expression, tool name, original time) pass through as they
    //          are.
    final historyPlan = buildNotesClipboardImportPlan('''
NekoCalc 批量导出
历史: 1 条

---

工具历史: ohms_law
表达式: 电流=2A
结果: 电压: 10V
时间: 2026/06/08 10:15
''');
    final historyPreview =
        NotesHistoryImportPreview(historyPlan.historyDrafts.single);
    expect(notesImportPreviewTitle(historyPreview, en), 'Tool history: 电流=2A');
    expect(notesImportPreviewDescription(historyPreview, en),
        'Tool ohms_law, Original time 2026/06/08 10:15');
    expect(notesImportPreviewTitle(historyPreview, zh), '工具历史 · 电流=2A');
  });

  test('笔记控制器里不再有生成标题与描述的中文（它们只住在文案表里）', () {
    // 中文：**扫的是那几条具体的句子**，不是整个文件的宽/全角字面量——那个文件还装着**剪贴板
    //       往返的格式**（`'表达式: '`、`'NekoCalc 批量导出'`… 与 `_noteReport` /
    //       `_historyReport` / `_selectionSummary` 拼出来的正文），它们是数据格式，故意留着
    //       （理由在 `notes_strings.dart` 的文件头）。所以这里问两个问题：**搬走的那几句一个字
    //       都不许留**，而**表里的那几格必须真的被接上**（`strings.untitledNote` … 与
    //       `notesNoteDraftTitle` / `notesNoteDraftDescription`——剪贴板导入那两句现在是那边拼的）——
    //       只查前一条的话，把句子删掉、标题硬编码成空串也能过。
    //
    //       **扫描非空这件事有佐证**：控制器里仍应找得到那套故意留下的往返标签；找不到就说明扫错
    //       了文件或路径，那种"全过"最危险。
    // English: **the scan asks about those specific sentences**, not about every wide/fullwidth
    //          literal in the file — the file also carries the **clipboard round-trip format**
    //          (`'表达式: '`, `'NekoCalc 批量导出'` …, and the bodies composed by `_noteReport` /
    //          `_historyReport` / `_selectionSummary`), which is a data format deliberately kept (see
    //          `notes_strings.dart`'s head). So two questions are asked: **not one word of the moved
    //          sentences may stay**, and **the table's cells must really be wired in**
    //          (`strings.untitledNote` … plus `notesNoteDraftTitle` / `notesNoteDraftDescription` — the
    //          clipboard import's two sentences are composed over there now) — with only the first,
    //          deleting the sentences and hard-coding an empty title would pass.
    //
    //          **Non-vacuity has its own evidence**: the round-trip labels that are deliberately kept
    //          must still be found in the controller; if they are not, the wrong file or path was
    //          scanned, and that kind of "all pass" is the most dangerous.
    final controllerFile = File('lib/application/controllers/notes_controller.dart');
    expect(controllerFile.existsSync(), isTrue, reason: '测试的工作目录应当是包的根目录');

    final source = stripComments(controllerFile.readAsStringSync());
    final literals = stringLiterals(source).toList(growable: false);
    expect(literals.any((literal) => literal.startsWith('表达式: ')), isTrue,
        reason: '控制器里应当仍留着剪贴板往返格式的标签——找不到说明扫错了文件');
    expect(literals.any((literal) => literal.startsWith('NekoCalc 批量导出')), isTrue,
        reason: '控制器里应当仍留着批量导出的头——找不到说明扫错了文件');

    // 中文：**旧句子一个字都不许留。** 列表是迁移前硬编码的那些句子（截到分辨得出的片段）：前三句
    //       是 §5l 那三句，后面的是剪贴板导入那一家（`notes_import_draft_message.dart` 现在拼它们）。
    // English: **not one word of the old sentences may stay.** The list is the sentences that used to be
    //          hard-coded (cut to distinctive fragments): the first three are §5l's, the rest are the
    //          clipboard import family (now composed by `notes_import_draft_message.dart`).
    const movedFragments = <String>[
      '未命名笔记',
      '历史结果',
      '由计算历史保存',
      '剪贴板笔记',
      '从剪贴板导入的文本',
      '导入笔记',
      '剪贴板内容',
      '计算历史 · ',
      '工具历史 · ',
      '原时间 ',
    ];
    for (final fragment in movedFragments) {
      expect(source.contains(fragment), isFalse,
          reason: '控制器里还留着应当住在 NotesStrings 里的旧句子：$fragment');
    }

    // 中文：而那几格**真的被接上了**（令牌在）。
    // English: and those cells are **really wired in** (the tokens are present).
    expect(source.contains('strings.untitledNote'), isTrue,
        reason: '空标题兜底没有接上文案表');
    expect(source.contains('strings.historyNoteTitle'), isTrue,
        reason: '历史笔记标题没有接上文案表');
    expect(source.contains('strings.historyNoteDescription'), isTrue,
        reason: '历史笔记描述没有接上文案表');
    expect(source.contains('notesNoteDraftTitle'), isTrue,
        reason: '剪贴板导入的标题没有接上保存边缘的拼装处');
    expect(source.contains('notesNoteDraftDescription'), isTrue,
        reason: '剪贴板导入的描述没有接上保存边缘的拼装处');
  });

  test('笔记页源码里除了文案表再没有中文字符串字面量', () {
    final directory = Directory('lib/features/notes/presentation');
    expect(directory.existsSync(), isTrue, reason: '测试的工作目录应当是包的根目录');

    final offenders = <String>[];
    for (final entity in directory.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final name = entity.uri.pathSegments.last;
      // 中文：文案表自己就是汉字住的地方，跳过它。
      // English: the table is where the Chinese is *supposed* to live; skip it.
      if (name == 'notes_strings.dart') continue;
      final source = stripComments(entity.readAsStringSync());
      for (final literal in stringLiterals(source)) {
        if (!_containsCjk(literal)) continue;
        if (_nonUiLiterals[name]?.contains(literal) ?? false) continue;
        offenders.add('${entity.path}: $literal');
      }
    }

    expect(offenders, isEmpty,
        reason: '这些界面字面量还没走 NotesStrings：\n${offenders.join('\n')}');
  });

  testWidgets('没有装作用域时笔记页仍渲染中文（默认态不变）', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: NotesPage(db: _EmptyDatabase(), toolResultLabel: _identityLabel, settings: AppSettings.fallback)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('笔记'), findsWidgets);
    expect(find.text('全部'), findsOneWidget);
    expect(find.text('历史'), findsOneWidget);
    expect(find.text('公式'), findsOneWidget);
    expect(find.text('工具'), findsOneWidget);
  });

  testWidgets('装上 AppLanguageScope(en) 之后同一个页面渲染英文', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: AppLanguageScope(
        language: AppLanguage.en,
        child: Scaffold(body: NotesPage(db: _EmptyDatabase(), toolResultLabel: _identityLabel, settings: AppSettings.fallback)),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Notes'), findsWidgets);
    expect(find.text('All'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Formulas'), findsOneWidget);
    expect(find.text('Tools'), findsOneWidget);
    expect(find.text('全部'), findsNothing);
    expect(find.text('笔记'), findsNothing);
  });
}

/// 中文：**不是界面文案**的那几条字面量，逐文件列出：按笔记内容挑图标用的内容探针。
///       它们拿**用户自己写的**笔记标题 / 描述 / 正文去 `contains`，决定那一行显示哪个图标。
///       跟着界面语言翻掉，中文界面下这些图标会立刻全变回默认，而且不会有任何报错——
///       它们是数据分类，不是文案。**别把界面文案加进这个表。**
/// English: **never user-facing** literals, listed per file: the content probes that pick a note's
///          icon. They `contains`-match **the user's own** note title / description / body to decide
///          which icon that row draws. Translating them with the interface would flip every such icon
///          back to the default in a Chinese interface, with no error anywhere — they are data
///          classification, not copy. **Do not add UI copy to this map.**
const Map<String, Set<String>> _nonUiLiterals = <String, Set<String>>{
  'notes_page_sections.dart': <String>{'公式', '公式：', '工具'},
  // 中文：**判据放宽到"含宽/全角字符或中文排版标点"（`test/shared/source_scan.dart`）之后，
  //       本目录新露出来的只有这一条，而且它不是句子**：`notes_page_dialogs.dart` 里那个
  //       `[,，\n]` 是**切分剪贴板文本的正则**——它认得的是"英文逗号、中文逗号、换行"三种
  //       分隔符，`，` 是那个文法的一个记号。
  //       **别把界面文案加进这个表**：入选条件是上面这条理由，不是方便。
  // English: **after widening the ruler to "contains a Wide/Fullwidth character or Chinese
  //          typographic punctuation" (`test/shared/source_scan.dart`) this directory yields exactly
  //          one more literal, and it is not a sentence**: `[,，\n]` in `notes_page_dialogs.dart` is
  //          the **regular expression that splits clipboard text** — it recognises three separators
  //          (ASCII comma, Chinese comma, newline) and `，` is one of that grammar's marks.
  //          **Do not add interface copy to this set**: the reason above is what qualifies an entry,
  //          not convenience.
  'notes_page_dialogs.dart': <String>{r'[,，\n]'},
};

/// 中文：一份什么都答"空"的库；护栏测试只关心首帧那几个字，不关心记录。
/// English: A database that answers empty to everything; the guard tests care about the first frame's
///          copy, not about records.
class _EmptyDatabase implements AppDatabase {
  const _EmptyDatabase();

  /// 中文：`implements` 只列出真会被调用的那几个；其余的交给 `noSuchMethod` 抛错——真被调到
  ///       说明页面比这份假库以为的读得多，那时应当红，而不是悄悄返回空。
  /// English: `implements` lists only the members actually reached; everything else falls to
  ///          `noSuchMethod` and throws — if one of them is reached, the page reads more than this
  ///          fake assumed and the test should go red rather than quietly answer empty.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<Map<String, String>> settings() async => const {};

  @override
  Future<void> setSettings(Map<String, String> values) async {}

  @override
  Future<void> setSetting(String key, String value) async {}

  @override
  Future<List<HistoryItem>> history({
    int limit = 50,
    int offset = 0,
    String? query,
    String? toolId,
  }) async =>
      const [];

  @override
  Future<List<NoteItem>> notes({
    int limit = 200,
    int offset = 0,
    String? query,
    String? tag,
    NoteArchiveFilter archiveFilter = NoteArchiveFilter.active,
    NoteSort sort = NoteSort.updatedNewest,
  }) async =>
      const [];

  @override
  Future<List<String>> noteTags({
    NoteArchiveFilter archiveFilter = NoteArchiveFilter.active,
  }) async =>
      const [];
}

/// 中文：CJK 统一表意文字区（含扩展 A）。够用了：本项目的界面文案都落在这里。
/// English: The CJK Unified Ideographs block (plus Extension A) — enough, since this project's UI
///          copy lives there.
bool _containsCjk(String text) {
  for (final rune in text.runes) {
    if ((rune >= 0x4E00 && rune <= 0x9FFF) ||
        (rune >= 0x3400 && rune <= 0x4DBF)) {
      return true;
    }
  }
  return false;
}
