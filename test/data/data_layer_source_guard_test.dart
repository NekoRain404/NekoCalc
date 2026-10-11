import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../shared/source_scan.dart';

/// 中文：**核心常量与数据层那三个文件的源码护栏。**
///
///       **它为什么存在。** 仓库里那些同形状的护栏各自扫一棵**界面**子树，而 `lib/core/**` 与
///       `lib/data/**` **一条都没有**。于是 §5l 把控制器修好之后，同一句 `'未命名笔记'` 还留在
///       `app_database.dart` 里当兜底——界面下的这一层存的是**要写进库的值**，英文界面会把它冻成
///       中文，而没有任何一把尺子量过这里。
///
///       **它扫的是一张写死的短名单，不是一棵树。** 名单就是本轮动过的那几个文件（含同一个
///       library 的 part 文件）。**故意不扫整个 `lib/data/**` 或 `lib/core/**`**：那两棵树里现在
///       还有大量中文（异常载荷、SQL、日志），一刀扫下去豁免表会长到把判据淹掉；这里先把**刚刚
///       修好的那条路**钉住，扩面是以后的事。
///
///       **豁免的每一条都带理由写在下面**，并且**逐条查死条目**——只会放行、永不命中的豁免与一句
///       界面文案一样危险（与 `data_fit_copy_test.dart` / `tool_field_strings_test.dart` 同一条
///       规矩）。豁免表真的命中，同时就是"尺子确实量到了这几个文件里的宽/全角字符"这一层非空转
///       证据；第二层是下面那条**正对照**：把旧的那句中文种进合成源码，它必须被抓出来。
/// English: **the source guard for those three core/data files.**
///
///          **Why it exists.** The repository's other guards of this shape each sweep an **interface**
///          subtree, while `lib/core/**` and `lib/data/**` had **none**. So after §5l fixed the
///          controller, the same `'未命名笔记'` stayed behind in `app_database.dart` as a fallback —
///          this layer below the interface stores **values written into the database**, an English
///          interface freezes them in Chinese, and no ruler had ever measured here.
///
///          **What it sweeps is a short hard-coded list, not a tree.** The list is the files this slice
///          touched (plus the part files of the same library). **It deliberately does not sweep all of
///          `lib/data/**` or `lib/core/**`**: those trees still hold plenty of Chinese (exception
///          payloads, SQL, logging), and one broad stroke would grow the exemption list until it drowns
///          the criterion. This pins **the road that was just fixed**; widening is a later slice.
///
///          **Every exemption carries its reason below**, and **dead entries are checked one by one** —
///          an exemption that only permits and never matches is as dangerous as a line of interface copy
///          (the same rule as `data_fit_copy_test.dart` / `tool_field_strings_test.dart`). The exemption
///          list really firing is itself the claim that "the ruler did measure the wide/fullwidth
///          characters in these files"; the second layer is the **positive control** below: the old
///          Chinese sentence planted into a synthetic source must be caught.
void main() {
  test('核心常量与数据层：这三个文件里没有界面文案字面量', () {
    final used = <String>{};
    final offenders = <String>[];
    for (final path in _guardedFiles) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '护栏名单里的文件不在了：$path');
      for (final literal in _offendersIn(file.readAsStringSync(), used)) {
        offenders.add('$path: $literal');
      }
    }

    expect(offenders, isEmpty,
        reason: '这些字面量还没走文案表：\n${offenders.join('\n')}');
    expect(_deliberateLiterals.difference(used), isEmpty,
        reason: '豁免表里这些条目一条都没用到，是死条目：'
            '\n${_deliberateLiterals.difference(used).join('\n')}');
  });

  test('护栏不是空转的：旧标题兜底会被抓住，记号不会被误伤', () {
    // 中文：**正对照。** 这句话就是本轮修掉的形状（数据层自己拼 `'未命名笔记'`）——它必须落进
    //       offenders；同一个源里那个中性记号必须被豁免掉。没有这一条，"扫描通过"既可能是
    //       "真的干净"，也可能是"尺子根本没量"。
    // English: **the positive control.** This sentence is the shape this slice removed (the data layer
    //          composing `'未命名笔记'` itself) — it must land in `offenders`, while the neutral mark
    //          in the same source must be exempted. Without it, "the scan passed" could mean "it is
    //          really clean" or "the ruler never measured".
    final used = <String>{};
    final offenders = _offendersIn(
        "final title = normalized ?? '未命名笔记';\nconst mark = '…';\n", used);

    expect(offenders, ['未命名笔记'], reason: '尺子没抓住本轮的旧形状——护栏是空转的');
    expect(used, {'…'}, reason: '记号没有被豁免，或者别的豁免条目被误命中');
  });
}

/// 中文：**本轮动过的几个文件**（`app_database_rows.dart` 与 `app_database.dart` 同属一个 library，
///       本轮也改到了它）。这份名单是**故意写死的**——理由见文件头。
/// English: **the files this slice touched** (`app_database_rows.dart` is a part of the same library as
///          `app_database.dart` and was touched too). The list is **deliberately hard-coded** — see the
///          head of this file.
const List<String> _guardedFiles = <String>[
  'lib/core/constants/app_info.dart',
  'lib/data/local/app_database.dart',
  'lib/data/local/app_database_rows.dart',
];

/// 中文：**豁免表。** 只放"故意留着、且不是界面文案"的字面量，逐条写理由；入选条件是理由，
///       不是方便。
/// English: **the exemption table.** Only literals that are deliberately kept and are not interface
///          copy, each with its reason; the reason qualifies an entry, not convenience.
const Set<String> _deliberateLiterals = <String>{
  // 中文：**内部异常载荷。** 这两句是 `FormatException` 的正文——导入备份时"这一行不是一个列表 /
  //       缺少 tables 字段"的诊断信息，判的是**文件内容**，不是屏幕上的文案。让它们跟着语言走是
  //       另一刀的事（得先决定它们到底上不上屏、上屏时走哪张表）；本轮不动它们，但写进豁免表，
  //       免得下一个人把这里当成漏扫。
  // English: **internal exception payloads.** These two are `FormatException` messages — diagnostics
  //          for "this row is not a list / the tables field is missing" while importing a backup; they
  //          judge **file content**, not copy on a screen. Making them follow the language is a separate
  //          slice (it first has to decide whether they ever reach the screen and which table they would
  //          use); this slice leaves them alone but writes them into the exemption table so the next
  //          reader does not mistake them for a missed sweep.
  '备份数据缺少 tables 字段',
  '\$table 不是有效列表',
  // 中文：**无标题笔记的记号**（定义在 `lib/data/local/app_database.dart`）。它不是文案，是"这条记录
  //       没有名字"的占位；数据层不知道语言，那句按语言生成的文案住在 `NotesStrings` 里，由控制器
  //       在保存那一刻拼好再传下来。
  // English: **the untitled-note mark** (defined in `lib/data/local/app_database.dart`). It is not copy
  //          but the placeholder for "this record has no name"; the data layer does not know the
  //          language, and the language-dependent sentence lives in `NotesStrings`, put together by the
  //          controller at save time and passed down.
  '…',
};

/// 中文：从一段源码里挑出**没走文案表的宽/全角字面量**；命中的豁免记进 [used]（查死条目用）。
///       先 [stripComments] 再 [stringLiterals]，与本仓库另外几条护栏同一顺序——注释里会引用带引号
///       的中文，顺序反了就把注释截错。
/// English: picks the **wide/fullwidth literals that did not go through a copy table** out of one
///          source text; exemptions that fire are recorded in [used] (for the dead-entry check).
///          [stripComments] before [stringLiterals], the same order as the repository's other guards:
///          comments quote Chinese inside quotes, and the wrong order cuts the comment in the wrong
///          place.
List<String> _offendersIn(String source, Set<String> used) {
  final offenders = <String>[];
  for (final literal in stringLiterals(stripComments(source))) {
    if (!containsWideOrFullwidth(literal)) continue;
    if (_deliberateLiterals.contains(literal)) {
      used.add(literal);
      continue;
    }
    offenders.add(literal);
  }
  return offenders;
}
