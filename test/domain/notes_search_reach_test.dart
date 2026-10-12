import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/controllers/notes_controller.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/models/history_item.dart';
import 'package:nekocalc/data/models/note_item.dart';
import 'package:nekocalc/data/repositories/history_repository.dart';
import 'package:nekocalc/data/repositories/notes_repository.dart';
import 'package:nekocalc/features/notes/presentation/notes_strings.dart';
import 'package:nekocalc/l10n/app_language.dart';

/// 中文：**本地过滤能看多远——这里放的是那个后果，不是那条决定。**
///
///       隔壁 `notes_controller_test.dart` 钉着决定本身：默认加载只读一页
///       （`loads the first note page instead of reading every matching note`），以及日期查询**不进 SQL 的
///       LIKE**（`keeps date queries out of SQL prefiltering and matches note dates`）。两条都对，也都留着。
///       可它们合起来有个后果没人管：查询里一旦含日期、工程符号或标点，SQL 那层就帮不上忙，过滤只能在
///       内存里跑——而内存里如果只有默认那一页，匹配项落在第 2 页之后时，用户看到的是「搜了，没有」。
///       **那不是"没找全"，那是一句假话。**
///
///       这个文件单独存在，一是因为职责不同（这边是"够不够得到"，那边是"读多少"），二是因为把这条塞回去
///       会把那个文件顶过 800 行——本项目的规矩是**按职责拆，而不是删掉理由**。
///
/// English: **how far local filtering can see — this file holds the consequence, not the decision.**
///
///          The neighbouring `notes_controller_test.dart` pins the decision itself: the default load reads
///          one page (`loads the first note page instead of reading every matching note`), and a date query
///          **never reaches the SQL LIKE** (`keeps date queries out of SQL prefiltering and matches note
///          dates`). Both are right, and both stay. But together they left one consequence unhandled: once
///          a query holds a date, an engineering symbol or punctuation, SQL cannot help, so the filter runs
///          in memory — and if memory only holds the default page, a match past it reads to the user as
///          「searched, nothing there」. **That is not an incomplete answer, it is a false one.**
///
///          This file exists separately because the responsibility differs (here: *reach*, there: *how
///          much is read*), and because folding it back would push that file over 800 lines — this
///          project's rule is to **split by responsibility, not to delete the reasoning**.
void main() {
  test('a date query still finds a note that lives past the first page',
      () async {
    // 中文：151 条笔记，**只有最后一条**带那个日期——它落在默认那一页之外。
    // English: 151 notes, and **only the last** carries the date — it lives past the default page.
    final db = _SearchReachDatabase(
      List.generate(
        151,
        (index) => NoteItem(
          id: index + 1,
          title: '笔记 ${index + 1}',
          description: '',
          body: '内容 ${index + 1}',
          createdAt:
              index == 150 ? DateTime(2026, 6, 8, 12) : DateTime(2026, 6, 1),
          updatedAt:
              index == 150 ? DateTime(2026, 6, 8, 12) : DateTime(2026, 6, 1),
        ),
      ),
    );
    final controller = NotesController(
      historyRepository: HistoryRepository(db),
      notesRepository: NotesRepository(db),
      strings: NotesStrings.forLanguage(AppLanguage.zh),
    );

    await controller.load();
    expect(controller.visibleNotes, hasLength(100),
        reason: '默认加载仍是第一页——那个决定没有被改，被改的只是它的后果');

    controller.setQuery('2026/06/08');
    await Future<void>.delayed(Duration.zero);

    expect(db.queries.last, isNull,
        reason: '日期查询仍然不进 SQL：预过滤那条决定没被改动');
    expect(controller.visibleNotes.map((item) => item.id), contains(151),
        reason: '匹配项在第 2 页之后，本地过滤必须够得到它，否则用户看到的是"搜过了，没有"');
    controller.dispose();
  });
}

/// 中文：只实现这个文件真正走到的三个方法（`notes` / `history` / `noteTags`），其余交给 `noSuchMethod`
///       ——与本仓库其它测试同一个写法。`notes` 里的 `skip/take` 是**真的分页**：正因为它是真的，上面那条
///       测试在没有修复时才会红。
/// English: implements only the three methods this file actually reaches (`notes` / `history` /
///          `noteTags`) and lets `noSuchMethod` cover the rest, as other tests here do. The `skip`/`take`
///          in `notes` is **real paging**: precisely because it is real, the test above was red before the
///          fix rather than passing by accident.
class _SearchReachDatabase implements AppDatabase {
  _SearchReachDatabase(this._notes);

  final List<NoteItem> _notes;

  /// 中文：仓库交给 SQL 的查询串，按调用顺序记下来——上面那条"日期不进 SQL"的断言读的就是它。
  /// English: the query strings handed to SQL, in call order — the "a date never reaches SQL" assertion
  ///          above reads this.
  final List<String?> queries = [];

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
  }) async {
    queries.add(query);
    return _notes
        .where((item) => !item.isArchived)
        .skip(offset)
        .take(limit)
        .toList(growable: false);
  }

  @override
  Future<List<String>> noteTags({
    NoteArchiveFilter archiveFilter = NoteArchiveFilter.active,
  }) async =>
      const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
