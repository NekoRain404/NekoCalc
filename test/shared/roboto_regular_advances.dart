/// 中文：**Roboto-Regular 的字宽尺**（单位 **1/1000 em**，ASCII 32–126 全量，95 条），外加一条
///       按它算宽度的函数。这把尺子原先长在 `tools_match_hint_visible_test.dart` 里，本轮
///       **原样搬到这里**——因为第二条护栏（`tool_description_strings_test.dart`，量的是卡片上
///       描述那一行装不装得下）需要**同一把尺子**。两处各留一份就会各自漂移：字重、字号、
///       字距任何一处改动都要两边同时改，而漏改的那一份不会报错，只会悄悄量错。
///
///       **为什么不共用隔壁那张 Black 表**（`tool_catalog_strings_test.dart` 里的
///       `_robotoBlackPerMille`）：副标题是 w400、分类卡标题是 w800，**一个字重一把尺**；
///       共用会把英文标签量宽 5% 以上（`Custom Tools` 上 Black 90.3dp / Regular 87.3dp）。
///
///       **刻度对不对有一处设备上的旁证**：`Custom Tools`（w800，14sp）在设备上是 **91.0dp**，
///       用 Black 版算出来是 90.3dp（差 0.8%）。本表是 Regular，同一串算出 87.3dp——不宽于设备值，
///       也就是个**上限**。
///
///       **生成方式**（把文件换成 `Roboto-Regular.ttf`）：
///       `python3 -c "from fontTools.ttLib import TTFont; p='$FLUTTER_ROOT/bin/cache/artifacts/`
///       `material_fonts/Roboto-Regular.ttf'; f=TTFont(p); upm=f['head'].unitsPerEm;`
///       `cmap=f.getBestCmap(); hmtx=f['hmtx']; print({chr(c): round(hmtx[cmap[c]][0]/upm*1000)`
///       ` for c in cmap if 32<=c<127})"`
/// English: **the Roboto-Regular ruler** (in **1/1000 em**, all of ASCII 32–126, 95 entries) plus a
///          function that measures with it. It used to live inside
///          `tools_match_hint_visible_test.dart`; this round it was **moved here unchanged**, because a
///          second guard rail (`tool_description_strings_test.dart`, which asks whether the card's
///          description line holds the text) needs **the same ruler**. Two copies would drift: a change
///          to weight, size or letter spacing would have to be made in both, and the copy that is
///          missed does not fail — it silently measures the wrong thing.
///
///          **Why it is not shared with the Black table next door** (`_robotoBlackPerMille` in
///          `tool_catalog_strings_test.dart`): the subtitle is w400 and the category card title is
///          w800, **one ruler per weight**; sharing would over-measure an English label by more than 5%
///          (`Custom Tools`: 90.3dp Black against 87.3dp Regular).
///
///          **The graduations have a device-measured witness**: `Custom Tools` (w800, 14sp) is
///          **91.0dp** on the device, and the Black table computes 90.3dp for it (0.8% off). This
///          table is Regular and computes 87.3dp for the same string — narrower than the device value,
///          i.e. an **upper bound**.
///
///          **How it was generated** (over `Roboto-Regular.ttf`):
///          `python3 -c "from fontTools.ttLib import TTFont; p='$FLUTTER_ROOT/bin/cache/artifacts/`
///          `material_fonts/Roboto-Regular.ttf'; f=TTFont(p); upm=f['head'].unitsPerEm;`
///          `cmap=f.getBestCmap(); hmtx=f['hmtx']; print({chr(c): round(hmtx[cmap[c]][0]/upm*1000)`
///          ` for c in cmap if 32<=c<127})"`
library;

/// 中文：按真 Roboto 的字宽算宽度，外加逐字符的字距——Flutter 连**最后一个字符**也加字距。
///       **表外的字符按 1em**：走这条路的剩下的是 CJK 与全角标点（含 `：`、`、`），
///       而 Noto Sans CJK 的全宽字形 advance 就是一个 em。
/// English: width in real Roboto advances plus per-character letter spacing — Flutter adds the spacing
///          after the **last** character too. **Anything off-table counts as 1em**: what reaches it is
///          CJK and full-width punctuation (`：`, `、`), and a full-width glyph in Noto Sans CJK
///          advances exactly one em.
double advanceWidth(String text, double fontSize, double letterSpacing) {
  var width = 0.0;
  for (final rune in text.runes) {
    final character = String.fromCharCode(rune);
    final advance = robotoRegularPerMille[character] ??
        nonAsciiPerMille[character] ??
        1000;
    width += advance / 1000 * fontSize;
  }
  return width + letterSpacing * text.runes.length;
}

/// 中文：Roboto-Regular 的逐字符 advance 表，单位 1/1000 em，ASCII 32–126 全量。
/// English: Roboto-Regular's per-character advances, in 1/1000 em, all of ASCII 32–126.
const Map<String, int> robotoRegularPerMille = {
  ' ': 248, '!': 257, '"': 320, '#': 616, '\$': 562, '%': 732, '&': 622,
  "'": 174, '(': 342, ')': 348, '*': 431, '+': 567, ',': 196, '-': 276,
  '.': 263, '/': 412, '0': 562, '1': 562, '2': 562, '3': 562, '4': 562,
  '5': 562, '6': 562, '7': 562, '8': 562, '9': 562, ':': 242, ';': 211,
  '<': 508, '=': 549, '>': 522, '?': 472, '@': 898, 'A': 652, 'B': 623,
  'C': 651, 'D': 656, 'E': 568, 'F': 553, 'G': 681, 'H': 713, 'I': 272,
  'J': 552, 'K': 627, 'L': 538, 'M': 873, 'N': 713, 'O': 688, 'P': 631,
  'Q': 688, 'R': 616, 'S': 593, 'T': 597, 'U': 648, 'V': 636, 'W': 887,
  'X': 627, 'Y': 601, 'Z': 599, '[': 265, '\\': 410, ']': 265, '^': 418,
  '_': 451, '`': 309, 'a': 544, 'b': 561, 'c': 523, 'd': 564, 'e': 530,
  'f': 347, 'g': 561, 'h': 551, 'i': 243, 'j': 239, 'k': 507, 'l': 243,
  'm': 876, 'n': 552, 'o': 570, 'p': 561, 'q': 568, 'r': 338, 's': 516,
  't': 327, 'u': 551, 'v': 484, 'w': 751, 'x': 496, 'y': 473, 'z': 496,
  '{': 338, '|': 244, '}': 338, '~': 680,
};

/// 中文：界面文案里会出现、又不在 ASCII 那 95 条里的几个字形；CJK 与全角不列，按 1em 记。
///       `σ` 与 `λ` 是本轮描述表新引入的两个（`统计计算`、`矩阵计算`），
///       两条字形都不在 Roboto-Regular 的 cmap 里，按旁的希腊字母同宽记。
/// English: the few non-ASCII glyphs interface copy can carry that are not among the 95 ASCII
///          entries; CJK and full-width are not listed and count as 1em. `σ` and `λ` arrive with this
///          round's description table (`statistics`, `matrix`); neither is in Roboto-Regular's cmap,
///          so they are recorded at the width of the neighbouring Greek letters.
const Map<String, int> nonAsciiPerMille = {
  '·': 375, '°': 463, '±': 583, '×': 584, '÷': 584, 'Ω': 736, 'μ': 583,
  '²': 351, '³': 351, 'Δ': 733, '→': 793, '′': 275, '″': 275, '…': 1000,
  '℃': 1000, '℉': 1000, 'σ': 455, 'λ': 1000,
};
