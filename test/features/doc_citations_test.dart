import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 中文：**文档里的 `文件:行号` 引用，不许指到那个文件的末尾之外。**
///
///       ⚠️ **这条护栏是今天最值钱的那个发现长出来的。** 2026-10-12，同一条引用被追了**三次**：
///       `calculator_controller_evaluation.dart` 里"计算器按角度制求值"那处，从 `762` → `780`
///       （定义判定那次插入顶下去）→ **`735`**（**同一午后**把等待职责搬走，又顶一次）——
///       **让行号腐烂的，正是描述它的那几笔修复。** 而检查它一次只花了三秒 ✓。
///
///       **判据故意窄，只有一条**：文件**存在**、且引用的行号**大于**它的行数 ⇒ 算腐烂。
///       ⚠️ 两条特意**不报**：
///       1. **文件不存在**——历史提及是合法的（"那个文件当时在……"），报它就是误报；
///       2. **移动记录**——`762 → 780 → 735` 这种链是"它挪过"的记录，**不是引用**。
///          这条是**实测**得来的：第一版扫描**报了它** ✗，而**一个会误报的护栏会被关掉，关掉之后
///          就不会有第二次了**（`math_reachability_test.dart` 那条同款）。
///
///       ⚠️ 读数与 `wc -l` 一致（同 `file_size_limit_test.dart` 那条规矩）：**判据的读数必须与它执行的那条
///       规矩说同一种语言**，否则误报。
///
/// English: **a `file:line` citation in the docs must not point past the end of that file.**
///
///          ⚠️ **This guard grew out of the day's most valuable finding.** On 2026-10-12 one citation was
///          chased **three times**: the calculator's degree-mode evaluation in
///          `calculator_controller_evaluation.dart` moved `762` → `780` (the definitions verdict's insertion
///          pushed it down) → **`735`** (the **same afternoon's** extraction of the wait responsibility moved
///          it again) — **the fixes are what rot the lines that document them.** Checking took three seconds.
///
///          **The judgement is deliberately one sentence**: the file **exists** and the cited line is
///          **greater than** its length ⇒ rotted. ⚠️ Two things deliberately do **not** fire:
///          1. **a missing file** — a historical mention is legitimate ("that file was here at the time"), and
///             flagging it would be a false positive;
///          2. **a record of movement** — a `762 → 780 → 735` chain records *that it moved* and **is not a
///             citation**. That one was found by measurement: the first version of this sweep **flagged it**,
///             and **a guard that cries wolf gets switched off, after which there is no second chance** (the
///             same sentence as `math_reachability_test.dart`).
///
///          ⚠️ The line count is read the same way as `wc -l` (the rule from `file_size_limit_test.dart`):
///          **an instrument has to speak the language of the rule it enforces**, or it cries wolf.
void main() {
  test('判据：只有"文件存在 + 行号超出"才算腐烂；移动记录与历史提及都不算', () {
    const sizes = <String, int>{'a.dart': 10};
    expect(pastEndCitations(sizes, ['a.dart:11']), ['a.dart:11']);
    expect(pastEndCitations(sizes, ['a.dart:10']), isEmpty, reason: '正好最后一行是合法的');
    expect(pastEndCitations(sizes, ['gone.dart:999']), isEmpty,
        reason: '文件不存在是历史提及，报它就是误报');
    expect(pastEndCitations(sizes, ['a.dart:9', 'a.dart:11', 'b.dart:3']), ['a.dart:11']);

    // 中文：**这一格是实测得来的**：第一版扫描把这条链当成了引用并报出来 ✗。
    // English: **this cell came from measurement**: the first sweep treated that chain as a citation and
    //          flagged it.
    expect(citationsIn('（`a.dart:762 → 780 → 735`）'), isEmpty);
    expect(citationsIn('见 `lib/x/a.dart:12` 与 `b.kt:34`'), ['lib/x/a.dart:12', 'b.kt:34']);
  });

  test('文档里没有引用指到文件末尾之外', () {
    final docs = <File>[
      ...Directory('docs').listSync().whereType<File>().where((f) => f.path.endsWith('.md')),
      if (File('CHANGELOG.md').existsSync()) File('CHANGELOG.md'),
    ];
    expect(docs, isNotEmpty, reason: '一篇文档都没扫到，这条检查的前提就不成立');

    final citations = <String>[];
    for (final doc in docs) {
      citations.addAll(citationsIn(doc.readAsStringSync()));
    }
    // 中文：**先确认自己真的抽到了东西**——"抽到零条"与"条条都好"在结果上长得一样。
    // English: **first confirm the extraction found anything** — "extracted zero" and "all of them fine"
    //          look identical in the result.
    expect(citations.length, greaterThan(20),
        reason: '只抽到 ${citations.length} 条引用，这条检查多半根本没读对');

    final sizes = <String, int>{};
    for (final citation in citations) {
      final path = citation.substring(0, citation.lastIndexOf(':'));
      if (sizes.containsKey(path)) continue;
      final file = _resolve(path);
      if (file != null) sizes[path] = fileLineCount(file);
    }

    expect(pastEndCitations(sizes, citations), isEmpty,
        reason: '有引用指到文件末尾之外——按符号找，别按行号找（docs/verification.md §5s）');
  });

  test('§6 表里的路径必须存在：活检查的登记册，指向不存在的文件就是没人跑的检查', () {
    // 中文：**判据窄到不会误报** ✓ —— 只查 `docs/verification.md` §6 那张表 ✓、只认**带斜杠的完整路径** ✓。
    //       为什么必须这么窄：不带目录的裸文件名（`app_theme.dart`、`architecture.md`…）在文档里到处都是 ✓，
    //       一刀切会在**当场 11 处以上**误报 —— 实测过 ✓✓；而且文档里**故意**引用着已经不在的东西
    //       （`hiper.txt`、`HANDOVER.md`，见 §5u/§5w ✓），那些是**历史记录**，不该报 ✓。
    //       而 §6 那张表不一样 ✓：它是**活检查的登记册** ✓ —— 一行指向一个已经不存在的文件，
    //       就是一条**没人会跑到的检查** ✗（今天新加的四条护栏正是这张表最新的内容 ✓，也最容易漂 ✓）。
    // English: **narrow enough not to cry wolf** — only §6's table in `docs/verification.md`, and only
    //          **slash-qualified** paths. Bare file names are all over these docs and a blanket check cried
    //          wolf in a dozen places when tried; and the docs **deliberately** cite things that are gone
    //          (`hiper.txt`, `HANDOVER.md` — §5u/§5w), which are records and must not fire. That table is
    //          different: it is the register of **live** checks, so a row naming a file that is gone is a check
    //          nobody runs. Four of today's guards are its newest rows, and the newest rows drift first.
    List<String> tablePaths(String doc) {
      final heading = RegExp(r'^## 6\. ', multiLine: true).firstMatch(doc);
      if (heading == null) return const [];
      final after = doc.substring(heading.end);
      final next = after.indexOf(RegExp(r'^## ', multiLine: true));
      final section = next < 0 ? after : after.substring(0, next);
      return <String>[
        for (final row in RegExp(r'^\| `([^`]+)`', multiLine: true).allMatches(section))
          if (row.group(1)!.contains('/')) row.group(1)!,
      ];
    }

    List<String> missingPaths(List<String> paths) =>
        <String>[for (final p in paths) if (!File(p).existsSync()) p];

    // 中文：合成对照——给一条不存在的路径，判据必须报出来 ✓。
    // English: synthetic control — feed it a path that is not there and it has to report it.
    expect(tablePaths('## 6. X\n\n| `a/b.dart` | x |\n'),
        <String>['a/b.dart'], reason: '抽路径这一步本身就不对');
    expect(missingPaths(<String>['test/features/does_not_exist_9f3.dart']),
        <String>['test/features/does_not_exist_9f3.dart']);

    final rows = tablePaths(File('docs/verification.md').readAsStringSync());
    // 中文：**先确认自己真抽到了东西**——"抽到零行"与"行行都在"在结果上长得一样。
    // English: **first confirm the extraction found anything** — "zero rows" and "all rows fine" look alike.
    expect(rows.length, greaterThan(5),
        reason: '只抽到 ${rows.length} 行路径，这条检查多半根本没读对那张表');

    expect(missingPaths(rows), isEmpty,
        reason: '§6 表里这些路径不存在——那几行的检查没人会跑到');
  });
}

/// 中文：**判据只有这一句**：在给定的行数表里，引用指向文件末尾之外的（按原顺序返回，输出稳定）。
///       文件不在表里（不存在或没找到）一律**放行**——见文件头那两条"特意不报"。
/// English: **the judgement in one sentence**: citations pointing past the end of a file in the given size
///          table, in the order given. A file absent from the table (missing, or not found) is **let
///          through** — see the two deliberate non-fires in the header.
List<String> pastEndCitations(Map<String, int> linesByPath, List<String> citations) {
  return [
    for (final citation in citations)
      if (linesByPath[citation.substring(0, citation.lastIndexOf(':'))] case final int lines
          when int.parse(citation.substring(citation.lastIndexOf(':') + 1)) > lines)
        citation,
  ];
}

/// 中文：从一段文字里抽出 `path:line`。**先把移动记录整段剔掉**（`762 → 780 → 735`），
///       再按扩展名找——那一步不是优化，是判据的一部分。
/// English: extract `path:line` from a text. **First strip records of movement** (`762 → 780 → 735`), then
///          match by extension — that first step is not an optimisation, it is part of the judgement.
List<String> citationsIn(String text) {
  final withoutChains = text.replaceAll(RegExp(r'[0-9]+(?: → [0-9]+)+'), '');
  return RegExp(r'[A-Za-z0-9_/]+\.(?:dart|kt|java):[0-9]+')
      .allMatches(withoutChains)
      .map((m) => m.group(0)!)
      .toList();
}

/// 中文：把文档里写的路径解析到一个真实文件上（文档里有的带目录、有的只写文件名）。
/// English: resolve a path as written in the docs to a real file (some are written with a directory, some
///          as a bare file name).
File? _resolve(String path) {
  final direct = File(path);
  if (direct.existsSync()) return direct;
  final name = path.split('/').last;
  for (final root in const ['lib', 'test', 'android/app/src', 'tool']) {
    final dir = Directory(root);
    if (!dir.existsSync()) continue;
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('/$name')) return entity;
    }
  }
  return null;
}

/// 中文：与 `wc -l` 逐字一致的行数读法（只数换行符）。理由同 `file_size_limit_test.dart`。
/// English: line count, byte-for-byte the same as `wc -l` (newlines only) — same reason as
///          `file_size_limit_test.dart`.
int fileLineCount(File file) =>
    '\n'.allMatches(file.readAsStringSync()).length;
