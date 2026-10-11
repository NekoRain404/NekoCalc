import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/application/controllers/notes_controller.dart';
import 'package:nekocalc/domain/usecases/record_filter.dart';
import 'package:nekocalc/features/notes/presentation/notes_strings.dart';
import 'package:nekocalc/features/notes/presentation/notes_summary_message.dart';
import 'package:nekocalc/l10n/app_language.dart';

import '../shared/source_scan.dart';

/// 中文：**筛选摘要那条 `label` 与屏幕上那句话分家之后，两边都还对得上。**
///
///       `NotesVisibleSummary.label` 原先在应用层自己拼那句中文（`'全部记录 · 历史 2 · 笔记 1'`、
///       `'搜索“Ω” · 无匹配'`）并直接印在笔记页筛选摘要条上，于是英文界面下印的仍是中文——
///       应用层对象活得比界面长，界面那张按语言切的表够不着它（`docs/verification.md` §5i）。
///       这一轮把那句话移进 `NotesStrings`，`NotesVisibleSummary` 只留令牌与读数（`tab` 与两根计数），
///       由 `notes_summary_message.dart` 在呈现边缘取。这份测试是那次改动的锁，四段各管一件事：
///
///       1. **令牌与那句话一一对应**：五格 tab 逐条渲染，中文侧必须与迁移前那句**逐字节相同**；
///          两个方向都查（`RecordTab` 每一格都有对照表条目，对照表里每一条都命中一个真的枚举值）。
///          「全部记录」「笔记」「历史」「公式」「工具」五个辖域标签住在这一格里。
///       2. **摘要真的跟着语言走**：同一批摘要递英文表，渲染出来的既不是那句中文、也不含宽/全角
///          字符（载荷用 ASCII，因为载荷是调用方递进来的、本来就跟着调用方的语言）。
///       3. **载荷真的拼进句子**：换 tab、换查询字、换计数，句子里那半截必须跟着换；
///          「无匹配」与两根计数尾巴按存在的读数出现或消失。
///       4. **源码里那句话只有一份**：`NotesVisibleSummary` 那一段里一个宽/全角字面量都不许有
///          （下面那段说明为什么只量这一段，而不是整个 `notes_controller.dart`——那个文件还装着
///          **剪贴板往返的格式**），且迁移前那句 `label` 的各个组成片段一个都不许留。
///
///       **中文逐字节相同是被测试量出来的，不是被声明的**：对照表就是迁移前 `label` 里那几条
///       `return` 的抄本，故意写死在测试里。**不要拿它们去追新文案。**
/// English: **once the filter summary's `label` has parted from the sentence on screen, the two still
///          line up.**
///
///          `NotesVisibleSummary.label` used to compose that Chinese sentence itself in the application
///          layer (`'全部记录 · 历史 2 · 笔记 1'`, `'搜索“Ω” · 无匹配'`) and print it straight onto the
///          notes page's filter summary bar, so an English interface still printed Chinese — an
///          application-layer object outlives the UI and a language-keyed interface table cannot reach
///          it (`docs/verification.md` §5i). This round moved that sentence into `NotesStrings`, leaving
///          `NotesVisibleSummary` with the token and the readings only (`tab` and the two counts), read
///          at the presentation edge by `notes_summary_message.dart`. This test is that change's lock,
///          in four parts:
///
///          1. **Token and sentence correspond one to one**: the five tabs rendered one by one, the
///             Chinese side **byte-identical** to the sentence before the change, checked in both
///             directions (every `RecordTab` has a table entry, every entry hits a real enum value). The
///             "全部记录" / "笔记" / "历史" / "公式" / "工具" scope labels live in this cell.
///          2. **The summary really follows the language**: the same summaries with the English table
///             render neither the Chinese sentence nor any wide/fullwidth character (payloads are ASCII
///             here, because a payload is handed in by the caller and already follows the caller's
///             language).
///          3. **The payloads really splice into the sentence**: a different tab, query or count moves
///             that half of the sentence; "no matches" and the two count tails appear or vanish with the
///             readings behind them.
///          4. **The sentence exists once in the source**: the `NotesVisibleSummary` stretch must hold
///             **not one wide/fullwidth literal** (the note under part 4 explains why only that stretch
///             is measured, not the whole `notes_controller.dart` — that file also carries the
///             **clipboard round-trip format**), and none of the pre-move `label`'s fragments may
///             survive.
///
///          **The byte-identity is measured, not asserted**: the tables are copies of those `return`s in
///          `label` before the change, deliberately written out in the test. **Do not bring them up to
///          date with new copy.**
void main() {
  final zh = NotesStrings.forLanguage(AppLanguage.zh);
  final en = NotesStrings.forLanguage(AppLanguage.en);

  /// 中文：**迁移前那五格辖域标签本身**——`NotesVisibleSummary._tabLabel` 的抄本。**不要拿它去追
  ///       新文案。**
  /// English: **the five scope labels from before the change** — a copy of
  ///          `NotesVisibleSummary._tabLabel`. **Do not bring it up to date with new copy.**
  const legacyTabLabels = <RecordTab, String>{
    RecordTab.all: '全部记录',
    RecordTab.notes: '笔记',
    RecordTab.history: '历史',
    RecordTab.formulas: '公式',
    RecordTab.tools: '工具',
  };

  test('每个辖域一句摘要：tab 与那句头一一对应', () {
    // 中文：**中文侧逐字节相同。** 每格 tab 只带一根历史尾巴，句子其余部分因此逐字节可比。
    // English: **the Chinese side is byte-identical.** Each tab carries one history tail only, so the
    //          rest of the sentence is byte-comparable.
    for (final entry in legacyTabLabels.entries) {
      expect(
        notesSummaryLabel(
          NotesVisibleSummary(
            tab: entry.key,
            query: '',
            historyCount: 1,
            noteCount: 0,
          ),
          zh,
        ),
        '${entry.value} · 历史 1',
        reason: '${entry.key.name} 的摘要与迁移前那句话不同了',
      );
    }

    // 中文：**两个方向。** 枚举里每一格都要有对照表条目，对照表里每一条都要命中一个真的枚举值。
    // English: **both directions.** Every enum value needs a table entry, and every entry has to hit a
    //          real enum value.
    expect(legacyTabLabels.keys.toSet(), RecordTab.values.toSet(),
        reason: 'tab 令牌与旧标签对照表对不上：'
            '${legacyTabLabels.keys.toSet().difference(RecordTab.values.toSet())}');
  });

  test('同一个摘要递英文表不给中文：摘要跟着语言走', () {
    // 中文：**载荷用 ASCII**：查询字与计数是调用方递进来的数据、本来就跟着调用方的语言，所以这里
    //       量的是**句子**那一层。四个形状各过一遍：纯计数、带查询、无匹配、带查询且无匹配。
    // English: **the payloads are ASCII here**: the query and the counts are data handed in by the
    //          caller and already follow the caller's language, so what is measured here is the
    //          **sentence** layer. Four shapes go through: counts only, with a query, no match, and a
    //          query with no match.
    final rendered = [
      for (final tab in RecordTab.values)
        notesSummaryLabel(
          NotesVisibleSummary(
            tab: tab,
            query: '',
            historyCount: 2,
            noteCount: 1,
          ),
          en,
        ),
      notesSummaryLabel(
        const NotesVisibleSummary(
          tab: RecordTab.all,
          query: 'sqrt',
          historyCount: 1,
          noteCount: 0,
        ),
        en,
      ),
      notesSummaryLabel(
        const NotesVisibleSummary(
          tab: RecordTab.notes,
          query: 'sqrt',
          historyCount: 0,
          noteCount: 0,
        ),
        en,
      ),
    ];
    for (final message in rendered) {
      expect(containsWideOrFullwidth(message), isFalse,
          reason: '英文摘要里还有宽/全角字符：$message');
      expect(message, isNot(contains('·')), reason: '英文摘要里还留着中文分隔符：$message');
    }
    // 中文：**英文表不是中文表抄两遍**：每一个形状在两种语言下都不同。
    // English: **the English table is not the Chinese one copied twice**: every shape differs between
    //          the two languages.
    for (final tab in RecordTab.values) {
      final summary = NotesVisibleSummary(
        tab: tab,
        query: '',
        historyCount: 2,
        noteCount: 1,
      );
      expect(notesSummaryLabel(summary, en), isNot(notesSummaryLabel(summary, zh)),
          reason: '${tab.name} 在两种语言下印同一句话');
    }
  });

  test('载荷真的拼进句子：换 tab、查询字、计数，句子就跟着换', () {
    // 中文：**头跟着 tab 走**；**有查询字时头换成「搜索“…”」那一格**（与迁移前同一个判据：
    //       `hasQuery` 优先）。
    // English: **the head follows the tab**; **with a query it is replaced by the "Searching …" cell**
    //          (the same verdict as before the change: `hasQuery` wins).
    expect(
      notesSummaryLabel(
        const NotesVisibleSummary(
          tab: RecordTab.all,
          query: '',
          historyCount: 2,
          noteCount: 1,
        ),
        zh,
      ),
      '全部记录 · 历史 2 · 笔记 1',
    );
    expect(
      notesSummaryLabel(
        const NotesVisibleSummary(
          tab: RecordTab.all,
          query: 'Ω',
          historyCount: 1,
          noteCount: 0,
        ),
        zh,
      ),
      '搜索“Ω” · 历史 1',
    );

    // 中文：**「无匹配」只在总数为零时出现**——量一次出现与一次不出现，两条断言比"有字"诚实：
    //       只查出现的话，一个永远追加「无匹配」的实现也能过。
    // English: **"no matches" appears only when the total is zero** — measured once appearing and once
    //          not; comparing the two is more honest than asking for "some text": with only the
    //          positive check, an implementation that always appends it would pass.
    expect(
      notesSummaryLabel(
        const NotesVisibleSummary(
          tab: RecordTab.notes,
          query: 'Ω',
          historyCount: 0,
          noteCount: 0,
        ),
        zh,
      ),
      '搜索“Ω” · 无匹配',
    );
    expect(
      notesSummaryLabel(
        const NotesVisibleSummary(
          tab: RecordTab.tools,
          query: '',
          historyCount: 0,
          noteCount: 0,
        ),
        zh,
      ),
      '工具 · 无匹配',
    );

    // 中文：**两根计数尾巴各自按"是否大于零"出现**：只要历史的形状，与只要笔记的形状，
    //       尾巴的条数都跟着载荷换。
    // English: **each of the two count tails appears by whether it is greater than zero**: the
    //          history-only shape and the notes-only shape, and the tail's number follows the payload.
    expect(
      notesSummaryLabel(
        const NotesVisibleSummary(
          tab: RecordTab.notes,
          query: '',
          historyCount: 0,
          noteCount: 3,
        ),
        zh,
      ),
      '笔记 · 笔记 3',
    );
    expect(
      notesSummaryLabel(
        const NotesVisibleSummary(
          tab: RecordTab.history,
          query: '',
          historyCount: 7,
          noteCount: 0,
        ),
        zh,
      ),
      '历史 · 历史 7',
    );
  });

  test('判据没变：令牌是派生读数，不另存一份状态', () {
    // 中文：令牌是**派生**的，不是新的一份状态：`tab` 与两根计数就是全部，`totalCount` /
    //       `hasQuery` / `isEmpty` 都由它们回答，不可能与屏幕上那句对不上。
    // English: the token is **derived**, not a second copy of the state: `tab` and the two counts are
    //          all there is, and `totalCount` / `hasQuery` / `isEmpty` are answered from them, so they
    //          cannot disagree with the sentence on screen.
    const withQuery = NotesVisibleSummary(
      tab: RecordTab.notes,
      query: 'Ω',
      historyCount: 1,
      noteCount: 0,
    );
    expect(withQuery.hasQuery, isTrue);
    expect(withQuery.totalCount, 1);
    expect(withQuery.isEmpty, isFalse);
    const empty = NotesVisibleSummary(
      tab: RecordTab.all,
      query: '',
      historyCount: 0,
      noteCount: 0,
    );
    expect(empty.isEmpty, isTrue);
    expect(empty.hasQuery, isFalse);
  });

  test('源码里那句话只有一份：`NotesVisibleSummary` 那一段一个宽/全角字面量都没有', () {
    // 中文：**扫的是"这一段里有没有给人看的字"**，不是"有没有整句相同"：那句话已经搬进
    //       `NotesStrings`，`NotesVisibleSummary` 那一段里再出现任何一个宽/全角字面量，都说明有人
    //       把文案抄了回来（或者新写了一句），而抄回来的那一份不会跟着语言走。尺子与其他护栏
    //       **同一把**（`containsWideOrFullwidth`）。
    //
    //       **只量 `NotesVisibleSummary` 那一段**，不是整个 `notes_controller.dart`：那个文件还装着
    //       **剪贴板往返的格式**（`'计算历史'`、`'表达式:'`、`'NekoCalc 批量导出'`… 与
    //       `_noteReport` / `_historyReport` / `_selectionSummary` 拼出来的正文）。它们是**数据
    //       格式**，不是给用户看的句子：跟着界面语言翻掉，粘贴就不再认得自己写出来的导出文本
    //       （同一个坑，`notes_strings.dart` 的文件头上写着）。所以这一段从
    //       `class NotesVisibleSummary {` 量到文件末尾——**两个端点都必须找得到、且顺序正确**，
    //       否则扫的就可能是一段空字符串（那种"全过"最危险）。
    //
    //       两条底线的第二条：迁移前那句 `label` 的各个组成片段**在整份文件里一个字都不许留**。
    // English: **the scan asks "does this stretch hold any human-facing character"**, not "is a whole
    //          sentence identical": the sentence has moved into `NotesStrings`, so any wide/fullwidth
    //          literal reappearing in the `NotesVisibleSummary` stretch means somebody copied copy back
    //          (or wrote a new sentence), and the copy will not follow the language. The ruler is **the
    //          same one** as the other guards (`containsWideOrFullwidth`).
    //
    //          **Only the `NotesVisibleSummary` stretch is measured**, not the whole
    //          `notes_controller.dart`: that file also carries the **clipboard round-trip format**
    //          (`'计算历史'`, `'表达式:'`, `'NekoCalc 批量导出'`, … and the bodies composed by `_noteReport`
    //          / `_historyReport` / `_selectionSummary`). Those are a **data format**, not sentences for a
    //          user: translate them with the interface and a paste would no longer recognise the export
    //          this app itself wrote (the same trap, written on `notes_strings.dart`'s file head). So the
    //          stretch runs from `class NotesVisibleSummary {` to the end of the file — **both endpoints
    //          must be found, in that order**, or the scan could be measuring an empty string (the kind of
    //          "all pass" that is the most dangerous).
    //
    //          The second floor: none of the pre-move `label`'s fragments may stay **anywhere in the whole
    //          file**.
    final controllerFile = File('lib/application/controllers/notes_controller.dart');
    expect(controllerFile.existsSync(), isTrue,
        reason: '测试的工作目录应当是包的根目录');

    final source = stripComments(controllerFile.readAsStringSync());
    const startMarker = 'class NotesVisibleSummary {';
    final start = source.indexOf(startMarker);
    expect(start, isNot(-1), reason: '找不到摘要类的起点：$startMarker');
    expect(source.length, greaterThan(start),
        reason: '摘要类那一段的终点在起点之前');

    final offenders = stringLiterals(source.substring(start))
        .where(containsWideOrFullwidth)
        .map((literal) => 'notes_controller.dart: $literal')
        .toList(growable: false);
    expect(offenders, isEmpty,
        reason: '这些字面量应当走 NotesStrings（句子只住在那里）：\n'
            '${offenders.join('\n')}');

    // 中文：**旧句子一个字都不许留**（整份文件，含注释被剥掉后的正文）。列表就是迁移前那句
    //       `label` 的各个片段——将来有人把某一段抄回应用层，这条会红。
    // English: **not one word of the old sentence may stay** (the whole file, comments stripped). The
    //          list is the fragments of the pre-move `label` — if somebody copies one back into the
    //          application layer, this goes red.
    const legacyLabelFragments = <String>[
      '全部记录',
      '搜索“',
      ' · 无匹配',
      ' · 历史 ',
      ' · 笔记 ',
    ];
    for (final fragment in legacyLabelFragments) {
      expect(source.contains(fragment), isFalse,
          reason: '应用层文件 notes_controller.dart 里还留着旧摘要的片段：$fragment');
    }
  });
}