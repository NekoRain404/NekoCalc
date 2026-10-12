import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 中文：**标题里那个数，必须等于它下面那张表的行数。**
///
///       ⚠️ **这条护栏是被今天四次数错逼出来的。** `docs/verification.md` §6 的标题是
///       「`Seven` mechanical checks …」✓ —— 而它**今天被我手改了四次** ✗（Four → Five → Six → Seven ✓，
///       每加一条检查就改一次 ✓）。手改没出错 ✓ 是运气 ✓：标题写「七个」而表里六行，**读起来完全正常** ✗，
///       而且**没有任何东西会红** ✓ —— 这正是这份文档一直在追的那类腐烂 ✓（§5x 的"测量只活在正文里"、
///       §5s 的"写时真、读时假"），只不过主体换成了**一个数** ✓。
///
///       **判据故意窄** ✓：只认「`## 6. <数词> mechanical checks …`」这一种标题 ✓，
///       数的是它下面到下一个 `## ` 之前、以 ``| ` `` 开头的表格行 ✓。同 `doc_citations_test.dart`
///       与 `math_reachability_test.dart` 那两句：**窄判据不会误报，而误报的护栏会被关掉** ✓✓。
///
///       **判据提成纯函数** ✓，好让合成文档证明它**真的会响**（六行配「Six」不响 ✓、六行配「Seven」要响 ✓）。
/// English: **the number in a heading has to equal the number of rows in the table under it.**
///
///          ⚠️ **This guard was forced by four manual edits today.** §6's heading reads
///          「`Seven` mechanical checks …」 and was hand-edited **four times** (Four → Five → Six → Seven) as
///          checks were added. Doing that by hand worked, which is luck: a heading that says *seven* over a
///          table of six **reads perfectly normally** and **nothing goes red** — the rot this document keeps
///          chasing (§5x's measurements in prose, §5s's true-when-written), with a **number** as the subject.
///
///          **Deliberately narrow**: it recognises only a `## 6. <number word> mechanical checks …` heading and
///          counts the ``| ` ``-prefixed table rows beneath it up to the next `## `. Same sentence as the
///          citation and reachability guards: **a narrow test cannot cry wolf, and a test that cries wolf gets
///          switched off.**
///
///          The judgement is a pure function so synthetic documents can prove it **fires**.
void main() {
  test('判据在合成文档上会响：六行配「Six」不响，六行配「Seven」要响', () {
    const sixRows = '''
## 6. Six mechanical checks that exist because of repeated mistakes

| Check | Guards against |
|---|---|
| `a.dart` | one |
| `b.dart` | two |
| `c.dart` | three |
| `d.dart` | four |
| `e.dart` | five |
| `f.dart` | six |
''';
    expect(countMismatches(sixRows), isEmpty, reason: '六行配 Six 是对的，不该响');

    const sevenRows = '''
## 6. Seven mechanical checks that exist because of repeated mistakes

| Check | Guards against |
|---|---|
| `a.dart` | one |
| `b.dart` | two |
| `c.dart` | three |
| `d.dart` | four |
| `e.dart` | five |
| `f.dart` | six |
''';
    expect(countMismatches(sevenRows), hasLength(1),
        reason: '标题说七个、表里六行——这正是手改漏一次的样子，必须响');

    // 中文：**标题里换一个判据不认识的数词，也要响** ✓ —— 否则新写法会静默地从护栏下滑过去 ✗。
    // English: an unrecognised number word must fire too, or a new spelling would slip through silently.
    expect(countMismatches('## 6. Several mechanical checks\n\n| `a.dart` | x |\n'), hasLength(1),
        reason: '认不出的数词必须报出来，而不是当成"没有这一节"放过去');
  });

  test('真实文档：§6 标题里那个数等于表里的行数', () {
    final doc = File('docs/verification.md');
    expect(doc.existsSync(), isTrue, reason: '文档不在，这条检查的前提就不成立');
    final text = doc.readAsStringSync();

    // 中文：**先确认自己真的找到了那一节** ✓ —— "没找到"与"找到了且没问题"在结果上长得一模一样。
    // English: **first confirm the section was found** — "not found" and "found and fine" look identical.
    expect(text, contains('mechanical checks that exist because of repeated mistakes'),
        reason: '那一节的标题不在文档里，这条检查多半没读对');

    expect(countMismatches(text), isEmpty,
        reason: '标题里的数词与表格行数对不上——加一条检查时忘了改标题，或改了标题没加行');
  });
}

/// 中文：**判据只有这几句**：在 `## 6. <数词> mechanical checks` 这一节里，把「数词」翻成整数 ✓，
///       数它下面到下一个 `## ` 之前以 ``| ` `` 开头的行 ✓，两者不等就报一条 ✓（认不出的数词也报 ✓）。
/// English: **the judgement, in full**: inside a `## 6. <number word> mechanical checks` section, translate
///          the word, count the ``| ` ``-prefixed rows beneath it up to the next `## `, and report a mismatch —
///          including an unrecognised number word.
List<String> countMismatches(String doc) {
  final problems = <String>[];
  final heading = RegExp(r'^## 6\. (\S+) mechanical checks', multiLine: true)
      .firstMatch(doc);
  if (heading == null) return <String>[];

  final word = heading.group(1)!;
  final expected = _numberWords[word.toLowerCase()];
  if (expected == null) {
    return <String>['标题里的「$word」不是一个认得出的数词——护栏认不出它，就不会替它把关'];
  }

  final after = doc.substring(heading.end);
  final nextHeading = after.indexOf(RegExp(r'^## ', multiLine: true));
  final section = nextHeading < 0 ? after : after.substring(0, nextHeading);
  final rows = RegExp(r'^\| `', multiLine: true).allMatches(section).length;

  if (rows != expected) {
    problems.add('标题说 $expected 条（$word），表里数出 $rows 行');
  }
  return problems;
}

/// 中文：**护栏只认这些数词** ✓（够用到「Ten」✓；超出就报"认不出"，而不是猜 ✓）。
/// English: **the guard knows these words only** (up to Ten is ample; anything else is reported, not guessed).
const Map<String, int> _numberWords = <String, int>{
  'one': 1,
  'two': 2,
  'three': 3,
  'four': 4,
  'five': 5,
  'six': 6,
  'seven': 7,
  'eight': 8,
  'nine': 9,
  'ten': 10,
};
