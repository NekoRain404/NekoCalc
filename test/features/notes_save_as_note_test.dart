import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/app_settings.dart';
import 'package:nekocalc/data/local/app_database.dart';
import 'package:nekocalc/data/models/history_item.dart';
import 'package:nekocalc/data/models/note_item.dart';
import 'package:nekocalc/features/notes/presentation/notes_page.dart';

/// 中文：**「长按一条历史 → 保存为笔记」这条界面路，笔记真的被建出来。**
///
///       填的是哪一格：笔记的**内容**早就钉住了 ✓（`notes_controller_test.dart` 断言了建出来的标题、
///       描述与时间那句 ✓），但**用户点得到吗**只有字符串覆盖 ✗ —— 也就是说，一个把那个菜单项接错的实现
///       （改个 `onTap` 返回的字符串、或者漏掉那层串行保护）能让所有内容测试继续全绿 ✓，而那条路断掉 ✗。
///       这里走的是**真界面**：长按历史行 → 动作面板 → 点「保存为笔记」✓。
///
///       ⚠️ **断言只写"被建出来了、且带上了这条历史的表达式与结果"**，不复述控制器的措辞 ✓ ——
///       那些句子属于 `NotesStrings`，把它们复制到这里，就等于让两处各自维护同一句话（§5r 抓过的那一族）。
///
///       **它住在一个新文件里是刻意的**：`notes_page_test.dart` 已经 **767 行**，贴着 800 那条线
///       （护栏见 `file_size_limit_test.dart`）——加进去就过线，而按职责拆、自带一个最小假库，
///       与 `notes_search_reach_test.dart` 同一个做法。
/// English: **the "long-press a history row → save as note" road through the real UI, with the note really
///          created.**
///
///          The cell this fills: the note's **content** was pinned long ago (`notes_controller_test.dart`
///          asserts the created title, description and the timestamp sentence), but **"can a user reach it"**
///          had only string coverage — meaning an implementation that mis-wired that menu item (returning the
///          wrong action string, or dropping the serialisation guard) would keep every content test green
///          while the road itself is broken. This one drives the **real screen**: long-press the history row →
///          the action sheet → tap 「保存为笔记」.
///
///          ⚠️ **The assertions say only "it was created, carrying this history's expression and result"**, and
///          do not restate the controller's wording — those sentences belong to `NotesStrings`, and copying
///          them here would mean two places maintaining one sentence (the family §5r kept catching).
///
///          **It lives in its own file on purpose**: `notes_page_test.dart` is **767 lines**, against the
///          800-line ceiling (`file_size_limit_test.dart` guards it) — folding this in would cross it, and
///          splitting by responsibility with a minimal fake is what `notes_search_reach_test.dart` does too.
void main() {
  testWidgets('长按一条历史 → 「保存为笔记」：笔记真的被建出来', (tester) async {
    final db = _SaveAsNoteDatabase([
      HistoryItem(
        id: 1,
        expression: '8*9',
        result: '72',
        resultKind: HistoryResultKind.number,
        createdAt: DateTime(2026, 6, 8, 9, 30),
      ),
    ]);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NotesPage(
          db: db,
          toolResultLabel: (label) => label,
          settings: AppSettings.fallback,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('8*9'), findsOneWidget, reason: '历史行没渲染出来，这条测试的前提就不成立');

    // 中文：**是 `tap`，不是 `longPress`。** 实测（`notes_page_sections.dart:103-106`）：
    //       `onTap` 才是打开单条动作面板的（不在多选态时 ✓）；**长按进的是多选** ✓——
    //       所以长按之后屏幕上根本没有「保存为笔记」，只有「选择当前列表」那一套 ✓。
    // English: **`tap`, not `longPress`.** Measured (`notes_page_sections.dart:103-106`): `onTap` is what opens
    //          the single-item action sheet (when not in selection mode ✓); **a long press enters selection**
    //          ✓ — which is why a long press finds no 「保存为笔记」 on screen, only the selection controls ✓.
    await tester.tap(find.text('8*9'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存为笔记'));
    await tester.pumpAndSettle();

    expect(db.createdNotes, hasLength(1),
        reason: '点了「保存为笔记」，笔记必须真的被建出来——菜单项接错了，内容侧那些测试全绿也照样绿');
    final note = db.createdNotes.single;
    expect(note.body, contains('表达式: 8*9'),
        reason: '建出来的笔记里必须带着这条历史的表达式');
    expect(note.body, contains('结果: 72'),
        reason: '建出来的笔记里必须带着这条历史的结果');
    expect(note.title, isNotEmpty, reason: '笔记没有标题');
    expect(note.description, isNotEmpty, reason: '笔记没有描述（时间那句）');
  });
}

/// 中文：只实现这条界面路真正走到的四个方法，其余交给 `noSuchMethod`——与本仓库其它测试同一个写法。
///       **记录下来的 `addNote` 参数就是断言对象**：这个假库不做别的，只是把"界面真的调了它"记下来。
/// English: implements only the four methods this road actually reaches; `noSuchMethod` covers the rest, as
///          other tests here do. **The recorded `addNote` arguments are the assertion target**: this fake does
///          nothing else but record that the screen really called it.
class _SaveAsNoteDatabase implements AppDatabase {
  _SaveAsNoteDatabase(this._history);

  final List<HistoryItem> _history;
  final List<({String title, String body, String description})> createdNotes = [];

  @override
  Future<List<HistoryItem>> history({
    int limit = 50,
    int offset = 0,
    String? query,
    String? toolId,
  }) async =>
      _history;

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

  @override
  Future<int> addNote(String title, String body,
      {String description = '', List<String> tags = const []}) async {
    createdNotes.add((title: title, body: body, description: description));
    return createdNotes.length;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
