import 'package:flutter_test/flutter_test.dart';

import 'source_scan.dart';

/// 中文：**护栏那把尺子本身的测试。** 十一个护栏测试都靠 `containsWideOrFullwidth` 回答
///       「这里还有没有没走文案表的界面文案」，所以"它到底认哪些字"这件事得单独钉住——
///       否则下一轮把尺子改窄一点，十一个护栏会一起变松，而没有一个地方会红。
///
///       三组断言各自钉一件事：
///       1. **它比"含表意文字"宽**：上一轮实测漏掉的两条真界面文案（只有全角标点、没有汉字）
///          现在必须被认出来。这是这把尺子存在的全部理由。
///       2. **它比"非 ASCII 可见字符"窄**：数学记号、单位、字母不算文案。这是刻意的——
///          按字面口径放宽会让 calculator 子树多出 93 条键帽与数学记号、实体表多出 239 个
///          解码结果，理由与实测数见 `source_scan.dart` 开头。
///       3. **中文排版里就是标点的那十个歧义宽度字符算文案**（`… “ ” ‘ ’ · — – ′ ″`），
///          它们与汉字排在一起就是中文标点。
///
/// English: **a test for the guards' ruler itself.** All eleven guard tests lean on
///          `containsWideOrFullwidth` to answer "is there interface copy here that never went
///          through a copy table?", so which characters it recognises has to be pinned on its own —
///          otherwise a later round could narrow it a little, all eleven guards would go slack
///          together, and nothing would turn red.
///
///          The three groups each pin one thing:
///          1. **It is wider than "contains an ideograph"**: the two genuine interface strings the
///             previous round measured as slipping through (full-width punctuation only, no Han) must
///             now be recognised. That is this ruler's entire reason to exist.
///          2. **It is narrower than "non-ASCII visible character"**: mathematical signs, units and
///             letters are not copy. That narrowing is deliberate — the literal ruler would add 93
///             key caps and mathematical signs to the calculator subtree and 239 decoded values to
///             the entity table; the reasoning and the numbers are at the head of `source_scan.dart`.
///          3. **The ten ambiguous-width characters that typeset as Chinese punctuation count**
///             (`… “ ” ‘ ’ · — – ′ ″`) — standing next to Han they are Chinese punctuation.
void main() {
  test('比「含表意文字」宽：上一轮漏掉的那两条现在认得出来', () {
    // 中文：上一轮报告里那两条**只有全角标点、一个汉字都没有**的真界面文案。
    // English: the two genuine interface strings from the previous round's report — **full-width
    //          punctuation only, not one Han character**.
    expect(containsWideOrFullwidth(r"'$notation，$suffixNotation'"), isTrue,
        reason: '全角逗号那条（`text_tool_integer_tools.dart` 曾经的 129 行）');
    expect(containsWideOrFullwidth(')}。'), isTrue,
        reason: '扫描器在 `join`, ` 处断掉之后剩下的那一段（`text_tool_url_query_tools.dart`）');

    // 中文：判据认出它们靠的是"标点"这一维，不是碰巧含了某个汉字。
    for (final punctuation in <String>[
      '，',
      '。',
      '、',
      '：',
      '；',
      '（',
      '）',
      '【',
      '】'
    ]) {
      expect(containsWideOrFullwidth(punctuation), isTrue, reason: punctuation);
    }
    // 中文：全角字母数字也算——它们同样只出现在中文排版里。
    // English: fullwidth alphanumerics count too — they appear only in Chinese typesetting.
    for (final fullwidth in <String>['０', '９', '％', '＃']) {
      expect(containsWideOrFullwidth(fullwidth), isTrue, reason: fullwidth);
    }
  });

  test('比「非 ASCII 可见字符」窄：记号、单位、字母不算文案', () {
    // 中文：**这一组就是那把没有采用的尺子会多认出来的东西。** 它们是键帽上的记号与数学符号，
    //       不是句子；把它们当文案会让 calculator 子树的豁免表长到把护栏淹掉。
    // English: **this group is exactly what the ruler that was not adopted would recognise extra.**
    //          They are key-cap marks and mathematical signs rather than sentences; counting them as
    //          copy would swell the calculator subtree's exemption list until it drowned the guard.
    const marks = <String>[
      '√', '∛', 'π', '°', '×', '÷', '−', '≈', '∞', '∠', '∫', '∑', 'Π', '⌫', '✓',
      '▶', '◀',
      // 中文：实体表里那些**字母**（`&AElig;` 的解码结果）同样不是文案。
      // English: the entity table's **letters** (the decoded `&AElig;`) are not copy either.
      'Æ', 'Δ', '€', 'Œ', 'μ',
      // 中文：单位写法也不算——`Ω` 是希腊字母（歧义宽度），`²` 是上标数字，都不是文案。
      //       注意 `N·m` **不在这里**：它中间那个 `·` 正是上面那组中文排版标点之一，
      //       所以它会被认出来（`data_fit_cards.dart` 里那个 `' · '` 就是这么露出来的）。
      // English: units do not count either — `Ω` is a Greek letter (ambiguous width) and `²` a
      //          superscript digit, neither of them copy. Note `N·m` is **not** in this list: the
      //          `·` inside it is one of the Chinese typographic punctuation above, so it is
      //          recognised (that is how the `' · '` in `data_fit_cards.dart` surfaced).
      'abc', 'Ω', 'm/s²', 'J/kg', '',
    ];
    for (final mark in marks) {
      expect(containsWideOrFullwidth(mark), isFalse, reason: '「$mark」是记号，不是文案');
    }
    // 中文：而汉字与假名当然还是算的——尺子收窄的是"记号"那一侧，不是"文字"那一侧。
    // English: Han and kana still count of course — what narrowed is the "glyph" side, not the
    //          "writing" side.
    for (final writing in <String>['中', '无效', 'あ', '한']) {
      expect(containsWideOrFullwidth(writing), isTrue, reason: writing);
    }
  });

  test('中文排版里就是标点的那十个歧义宽度字符算文案', () {
    // 中文：**正是这一组让 HTML 实体表那十个解码结果露了出来**（`… “ ” ‘ ’ ·` 是上一轮点名的
    //       六条，`— – ′ ″` 是本轮实测同一类里的另外四条），它们由
    //       `text_tool_strings_test.dart` 里的 `_htmlEntityValues` 逐条豁免。
    // English: **this is the group that exposes the entity table's ten decoded values** (`… “ ” ‘ ’
    //          ·` are the six the previous round named, `— – ′ ″` the four more measured this round
    //          in the same class); `text_tool_strings_test.dart` exempts them one by one in
    //          `_htmlEntityValues`.
    const typographic = <String>[
      '·',
      '–',
      '—',
      '‘',
      '’',
      '“',
      '”',
      '…',
      '′',
      '″'
    ];
    for (final punctuation in typographic) {
      expect(containsWideOrFullwidth(punctuation), isTrue, reason: punctuation);
    }
    expect(typographic.length, 10, reason: '这一组多一个少一个都要在这里说一声');
  });
}
