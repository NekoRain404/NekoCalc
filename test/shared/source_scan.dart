/// 中文：**源码扫描用的那一把尺子。** 十一个"护栏"测试各自扫一棵子树，问的都是同一个问题：
///       「这里还有没有没走文案表、直接写在源码里的界面文案？」本轮之前那把尺子是
///       "含表意文字"（`[一-鿿]`），于是**只由全角标点与 ASCII 拼成的句子既进不了计数也进不了
///       护栏**——上一轮实测到两条真正的界面文案就是这样躲过去的
///       （`'$notation，$suffixNotation'` 与 `'…join(', ')}。'`）。
///
///       **本轮把尺子换成"含宽/全角字符或中文排版标点"。** 具体是：东亚宽度为 W 或 F 的那些
///       字符（汉字、假名、谚文、中文标点、全角字母数字），再加十个**歧义宽度**但中文排版里
///       就是中文标点的字符（`· – — ‘ ’ “ ” … ′ ″`）。默认语言是中文，界面文案就是用这套字
///       写出来的，所以"这套字"才是"这里有没有文案"的判据。
///
///       **为什么不是字面上的"非 ASCII 可见字符"。** 那条口径把**记号**也算成文案。实测
///       （口径见本文件末尾那条注释里的命令）：calculator 子树会多出 93 条键帽与数学记号
///       （`√ ∛ π ° × ÷ − ⌫ ▶ ◀ ✓ ∞ ∠ ∫ 📷`），`text_tool_html_entities.dart` 会多出
///       239 个**实体表的解码结果**（`Æ Δ € ∞ …`），两者都不是句子。豁免表会长到把护栏淹掉。
///       收窄到"这套字"之后，多出来的一共只有 **29 条**，逐条带理由写在各自的护栏里。
///
///       ⚠️ 这一段原先还列了**第三条**理由：「而且 `text_tool_strings_test.dart`（720 行）
///       会越过 800 行的硬线」。**那条已经不成立了**——那个文件经拆分现在是 **519 行**，
///       再装 239 条豁免也离 800 很远。所以它被删掉了，**但上面两条与体积无关的理由照旧成立**
///       （记号与实体解码值不是句子，这一条不会因为文件变小而改变）。
///       留这段是因为：**理由被删掉时该说一声**，免得下一页的读者以为这条口径从来只有一个依据。
/// English: **the ruler the source scans use.** Eleven "guard" tests each sweep a subtree asking one
///          question: "is there interface copy still written straight into the source instead of
///          going through a copy table?" Before this round the ruler was "contains an ideograph"
///          (`[一-鿿]`), so **a sentence made only of full-width punctuation and ASCII was invisible
///          both to the count and to the guards** — the previous round measured two genuine interface
///          strings slipping through that way (`'$notation，$suffixNotation'` and
///          `'…join(', ')}。'`).
///
///          **This round the ruler becomes "contains a Wide/Fullwidth character or Chinese
///          typographic punctuation"**: characters whose East Asian Width is W or F (Han, kana,
///          hangul, CJK punctuation, fullwidth alphanumerics), plus the ten ambiguous-width
///          characters that typeset as Chinese punctuation (`· – — ‘ ’ “ ” … ′ ″`). The default
///          language is Chinese and interface copy is written in exactly that set, so that set is
///          what "is there copy here" means.
///
///          **Why not the literal "non-ASCII visible character".** That ruler counts **glyphs** as
///          copy. Measured (command at the end of this file): the calculator subtree would gain 93
///          key caps and mathematical signs (`√ ∛ π ° × ÷ − ⌫ ▶ ◀ ✓ ∞ ∠ ∫ 📷`) and
///          `text_tool_html_entities.dart` would gain 239 **decoded entity values** (`Æ Δ € ∞ …`),
///          none of which is a sentence. The exemption lists would drown the guards. Narrowed
///          to "that set of characters", the total added is **29**, each with its reason written
///          beside it in its own guard.
///
///          ⚠️ A **third** reason used to stand here: "and `text_tool_strings_test.dart` (720 lines)
///          would cross the hard 800-line limit". **That one no longer holds** — splitting the file
///          took it to **519 lines**, and 239 exemptions would still leave it far from 800. So it was
///          deleted — but **the two reasons above are about correctness, not size** (a glyph and a
///          decoded entity value are not sentences), and they do not weaken because a file got
///          smaller. The note is kept because **a reason that is removed should say so**, so the next
///          reader does not think this ruler ever rested on one ground.
library;

/// 中文：东亚宽度 W（宽）与 F（全角）的区间。取自 Unicode 的 `EastAsianWidth.txt`，
///       收进来的正是"中文界面会用到的那套字"。
/// English: the East Asian Width W (wide) and F (fullwidth) ranges, from Unicode's
///          `EastAsianWidth.txt`; what goes in is exactly the set a Chinese interface is written in.
const List<List<int>> _wideOrFullwidthRanges = <List<int>>[
  <int>[0x1100, 0x115F], // 谚文字母
  <int>[0x2E80, 0x303E], // 康熙部首 / 中日韩符号与标点（`、`「」『』【】…… 都在这里）
  <int>[0x3041, 0x33FF], // 假名 / 注音 / 谚文兼容字母 / 中日韩兼容
  <int>[0x3400, 0x4DBF], // 汉字扩展 A
  <int>[0x4E00, 0x9FFF], // 汉字
  <int>[0xA000, 0xA4CF], // 彝文
  <int>[0xA960, 0xA97F],
  <int>[0xAC00, 0xD7A3], // 谚文音节
  <int>[0xF900, 0xFAFF], // 中日韩兼容表意文字
  <int>[0xFE10, 0xFE19], // 竖排形式（全角标点）
  <int>[0xFE30, 0xFE6F], // 中日韩兼容形式 / 小写变体
  <int>[0xFF00, 0xFF60], // 全角形式（`，：；？！（）` 与全角字母数字）
  <int>[0xFFE0, 0xFFE6], // 全角符号（`％￥￦`）
  <int>[0x1F300, 0x1F64F], // 表情符号（宽）——键帽上那个相机图标住在这里
  <int>[0x1F900, 0x1F9FF],
  <int>[0x20000, 0x2FFFD], // 汉字扩展 B 及以后
  <int>[0x30000, 0x3FFFD],
];

/// 中文：**歧义宽度（A）但中文排版里就是标点**的那十个。它们与汉字排在一起就是中文标点，
///       所以跟上面那批一起算；其余歧义宽度的字符是数学记号与单位（`× ÷ − ° √ ∞ ≈`），
///       那些是记号不是文案，不收。
/// English: the ten characters that are **ambiguous width (A) but typeset as punctuation** in
///          Chinese. Standing next to Han they are Chinese punctuation, so they count with the rest;
///          the other ambiguous-width characters are mathematical signs and units
///          (`× ÷ − ° √ ∞ ≈`), which are glyphs rather than copy, and are not collected.
const Set<int> _typographicPunctuation = <int>{
  0x00B7, // ·
  0x2013, // –
  0x2014, // —
  0x2018, // ‘
  0x2019, // ’
  0x201C, // “
  0x201D, // ”
  0x2026, // …
  0x2032, // ′
  0x2033, // ″
};

/// 中文：这个字符会不会出现在中文界面文案里。
/// English: whether this character occurs in Chinese interface copy.
bool isUiCopyRune(int rune) {
  if (_typographicPunctuation.contains(rune)) return true;
  for (final range in _wideOrFullwidthRanges) {
    if (rune >= range[0] && rune <= range[1]) return true;
  }
  return false;
}

/// 中文：**护栏用的判据。** 这一段字符串里有没有"界面文案会用到的那种字"。
///       **比"含表意文字"宽**（全角标点、全角字母数字都算），**比"非 ASCII 可见字符"窄**
///       （数学记号、键帽图标、HTML 实体表的解码结果不算）——理由见本文件开头。
/// English: **the ruler the guards use.** Whether this string contains "a character interface copy
///          is written with". **Wider than "contains an ideograph"** (full-width punctuation and
///          fullwidth alphanumerics count too), **narrower than "non-ASCII visible character"**
///          (mathematical signs, key-cap icons and the HTML entity table's decoded values do not) —
///          the reasoning is at the head of this file.
bool containsWideOrFullwidth(String text) {
  for (final rune in text.runes) {
    if (isUiCopyRune(rune)) return true;
  }
  return false;
}

/// 中文：**中文那一侧里"非 CJK 的连续段"**——即语言无关的记号。空格去掉，纯 ASCII 标点段丢掉
///       （`生成/校验 UUID` 里那个孤零零的 `/`、`CSV / TSV 转 JSON` 里那个 `/` 都不是记号，
///       是分隔符，英文一侧本来就会换一种写法）。`℃`/`℉`/`°R` 这种**不含字母数字的符号段**照留。
///
///       **这把尺子原先长在 `tool_description_strings_test.dart` 里，本轮原样搬到这里。** 理由与
///       `roboto_regular_advances.dart` 当初搬过来的那条一样：**第二张表需要同一把尺子**——
///       `tool_field_strings_test.dart` 要拿它量参数标签、单位、公式与解释里的记号，而两处各留
///       一份就会各自漂移，漏改的那一份不报错，只会悄悄放过一段记号。
///       两个判据共用的是**同一个函数**，不是同一段文字。
/// English: **the Chinese's non-CJK runs** — the language-neutral notation. Spaces trimmed, runs made
///          only of ASCII punctuation dropped (the lone `/` in `生成/校验 UUID` and in
///          `CSV / TSV 转 JSON` is a separator, not notation, and the English side writes it
///          differently); symbol-only runs such as `℃` / `℉` / `°R` are kept.
///
///          **This ruler used to live inside `tool_description_strings_test.dart` and was moved here
///          unchanged this round**, for the same reason `roboto_regular_advances.dart` was moved
///          before it: **a second table needs the same ruler** — `tool_field_strings_test.dart`
///          measures the notation in labels, units, formulas and explanations with it, and two copies
///          would drift, with the missed one failing silently instead of catching a lost run. What the
///          two guards share is **one function**, not one paragraph of prose.
Iterable<String> notationRuns(String source) sync* {
  final buffer = StringBuffer();
  for (final rune in source.runes) {
    if (_isCjkOrFullWidth(rune)) {
      final run = _takeNotationRun(buffer);
      if (run != null) yield run;
    } else {
      buffer.writeCharCode(rune);
    }
  }
  final run = _takeNotationRun(buffer);
  if (run != null) yield run;
}

String? _takeNotationRun(StringBuffer buffer) {
  final run = buffer.toString().trim();
  buffer.clear();
  if (run.isEmpty) return null;
  if (_asciiPunctuationOnly.hasMatch(run)) return null;
  return run;
}

/// 中文：**断点**：汉字、假名、谚文、中文标点、全角形式。与上面那把 `isUiCopyRune`
///       （"这里有没有界面文案"）量的是同一批字，用途不同。
/// English: **the cut points**: Han, kana, hangul, Chinese punctuation, full-width forms. The same
///          characters the `isUiCopyRune` ruler above ("is there interface copy here") measures — a
///          different question.
bool _isCjkOrFullWidth(int rune) =>
    (rune >= 0x2E80 && rune <= 0x9FFF) ||
    (rune >= 0x3000 && rune <= 0x303F) ||
    (rune >= 0x3400 && rune <= 0x4DBF) ||
    (rune >= 0xF900 && rune <= 0xFAFF) ||
    (rune >= 0xFF00 && rune <= 0xFFEF);

/// 中文：只由空白与 ASCII 标点组成的段。这类段在两种语言里本来就是两套写法（`、` 对 `, `）。
/// English: a run made only of whitespace and ASCII punctuation. Those runs are written differently in
///          each language by construction (`、` against `, `).
final RegExp _asciiPunctuationOnly =
    RegExp(r'^[\x20-\x2F\x3A-\x40\x5B-\x60\x7B-\x7E]+$');

// 中文：**口径成本是怎么量出来的**（两棵树都能跑，命令逐字如下）——
//       `dart run tool/ncs_probe/scan.dart <目录>`，判据是"非 ASCII 且不是空白/格式/控制字符"。
//       在 HEAD 上量到的数：`lib/features/calculator/presentation` 93 条（键帽与数学记号）、
//       `lib/application/controllers` 的 `text_tool_*.dart` 253 条（其中 239 条是
//       `text_tool_html_entities.dart` 的实体解码结果）、`lib/features/tools/presentation` 8 条、
//       `lib/features/notes/presentation` 1 条。换成 `containsWideOrFullwidth` 之后是
//       3 / 21 / 4 / 1，合计 29 条，全部逐条带理由豁免。
// English: **how the cost of the ruler was measured** (it runs on both trees; the command is
//          `dart run tool/ncs_probe/scan.dart <dir>`, whose ruler is "non-ASCII and not a
//          space/format/control character"). Measured on HEAD: `lib/features/calculator/presentation`
//          93 (key caps and mathematical signs), the `text_tool_*.dart` family under
//          `lib/application/controllers` 253 (239 of them the entity table's decoded values in
//          `text_tool_html_entities.dart`), `lib/features/tools/presentation` 8,
//          `lib/features/notes/presentation` 1. Under `containsWideOrFullwidth`: 3 / 21 / 4 / 1 —
//          29 in all, each exempted by name with its reason.
//
// 中文：**第二个需要同一把尺子的地方。** 下面这两把尺子原先长在
//       `test/features/tools_source_guard_test.dart` 里（私有名 `_stripComments` /
//       `_stringLiterals`），本轮搬到这里，理由与 `notationRuns` 当初搬过来那条一样：
//       **拟合领域层那条护栏要问同一个问题**（`test/domain/data_fit_copy_test.dart` 扫
//       `lib/domain/usecases/data_fit_*.dart`），而两处各留一份就会各自漂移，漏改的那一份不报错，
//       只会悄悄放过一条中文。**搬过来只改了名字与可见性**：判据、跳过注释与引号的顺序、
//       返回值一个字都没动，原调用方（`tools_source_guard_test.dart`）的断言因此逐字节未变。
// English: **the second place that needs the same ruler.** These two used to live inside
//          `test/features/tools_source_guard_test.dart` (privately named `_stripComments` /
//          `_stringLiterals`) and moved here this round for the same reason `notationRuns` moved
//          before them: **the fit domain layer's guard asks the same question**
//          (`test/domain/data_fit_copy_test.dart` scans `lib/domain/usecases/data_fit_*.dart`), and
//          two copies would drift, with the missed one failing silently instead of catching a Chinese
//          literal. **Only the names and their visibility changed in the move**: the criteria, the
//          order in which comments and quotes are skipped, and the return values are untouched, which
//          is why the original caller's (`tools_source_guard_test.dart`) assertion is byte-identical.

/// 中文：去掉 `//` 与 `/* */` 注释，**但保留字符串字面量原样**——注释里会出现引号
///       （本项目的中文注释就常写 `'关闭'`），先按引号整体跳过，注释才不会被截错。
/// English: Strips `//` and `/* */` comments while **copying string literals verbatim**: this
///          project's Chinese comments quote literals such as `'关闭'`, so quotes are skipped as whole
///          units first; otherwise the comment stripper would cut in the wrong place.
String stripComments(String source) {
  final out = StringBuffer();
  var i = 0;
  while (i < source.length) {
    final ch = source[i];
    if (ch == "'" || ch == '"') {
      final quote = ch;
      // 中文：三引号原样成块跳过。
      // English: Triple quotes are skipped as a block.
      final triple = source.startsWith(quote * 3, i);
      final delimiter = triple ? quote * 3 : quote;
      out.write(delimiter);
      i += delimiter.length;
      while (i < source.length) {
        if (source[i] == r'\') {
          out.write(source.substring(i, i + 2));
          i += 2;
          continue;
        }
        if (source.startsWith(delimiter, i)) {
          out.write(delimiter);
          i += delimiter.length;
          break;
        }
        out.write(source[i]);
        i++;
      }
      continue;
    }
    if (ch == '/' && i + 1 < source.length && source[i + 1] == '/') {
      while (i < source.length && source[i] != '\n') {
        i++;
      }
      continue;
    }
    if (ch == '/' && i + 1 < source.length && source[i + 1] == '*') {
      i += 2;
      while (i + 1 < source.length &&
          !(source[i] == '*' && source[i + 1] == '/')) {
        i++;
      }
      i += 2;
      continue;
    }
    out.write(ch);
    i++;
  }
  return out.toString();
}

/// 中文：取出源码里所有单/双引号字符串字面量的内容。
/// English: Extracts the contents of every single- and double-quoted string literal in the source.
Iterable<String> stringLiterals(String source) sync* {
  var i = 0;
  while (i < source.length) {
    final ch = source[i];
    if (ch != "'" && ch != '"') {
      i++;
      continue;
    }
    final quote = ch;
    final triple = source.startsWith(quote * 3, i);
    final delimiter = triple ? quote * 3 : quote;
    i += delimiter.length;
    final buffer = StringBuffer();
    while (i < source.length) {
      if (source[i] == r'\') {
        buffer.write(source.substring(i, i + 2));
        i += 2;
        continue;
      }
      if (source.startsWith(delimiter, i)) {
        i += delimiter.length;
        break;
      }
      buffer.write(source[i]);
      i++;
    }
    yield buffer.toString();
  }
}
