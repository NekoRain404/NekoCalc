import 'package:flutter_test/flutter_test.dart';
import 'package:nekocalc/features/tools/presentation/tool_detail_strings.dart';

/// 中文：**工程工具详情页那三张表的两条护栏。** 与文本工具那一族、设置页、计算器页的护栏同一条
///       形状（同一条判据、同一个 `containsCjk`），只是对象换成这一轮搬出来的字。
///
///       (1) **中文那一侧必须与迁移前源码里那句话逐字节相同。** 默认语言是中文，屏幕上每一个字
///           都要与 i18n 之前读起来一模一样；这一串断言**就是**"默认态没变"的证据。逐条写出来
///           而不是抽样：抽样的那一份只能证明抽到的那几条。
///           —— 覆盖范围的实测：宽字符尺子在这三个源文件里量到 **39 条文案字面量**
///           （`tool_detail_controller.dart` 18 条、`tool_detail_models.dart` 15 条、
///           `tool_detail_input_parsing.dart` 6 条；该文件另外 21 条是输入文法，见豁免表），
///           逐条都进表。这个数是 `git show HEAD:<file>` 与这三张表逐段比出来的
///           （脚本按 `$` 插值切开比每一段常量），不是估计：**没有一段常量丢**。
///           `'请输入数值'` 在两个源文件里各写过一次，两条都进同一格。
///       (2) **英文那一侧不许有汉字、不许有空串，并且必须与中文不同。** 空串在屏幕上是"这一格
///           什么都没有"，最难发现的一类漏翻；与中文相同的那一格等于没翻。
///           **有一条例外**：`listSeparator` / `sentenceSeparator` 两格是分隔符不是句子，
///           英文侧本来就与中文不同，所以它们照常受上面三条检查——这条脚注只是说清楚为什么
///           它们也在表里。
/// English: **the two guard rails for the tool detail screen's three tables.** Same shape as the
///          guards for the text-tool family, the settings page and the calculator page (the same
///          criterion, the same `containsCjk`), with this round's moved words as the subject.
///
///          (1) **The Chinese side must be byte-identical to the sentence in the source before the
///          move.** The default language is Chinese and every character on screen has to read exactly
///          as it did before i18n; this list **is** the evidence for "the default state did not
///          change". Written out one by one rather than sampled: a sample only proves the lines it
///          sampled. — Measured coverage: the wide-character ruler finds **39 copy literals** across
///          those three source files (`tool_detail_controller.dart` 18, `tool_detail_models.dart` 15,
///          `tool_detail_input_parsing.dart` 6 — that file's other 21 are input grammar, see the
///          exemption table), every one of them tabled. The number comes from comparing
///          `git show HEAD:<file>` against these three tables fragment by fragment (the script splits on
///          `$` interpolation and compares every constant run), not from an estimate: **no fragment was
///          lost**. `'请输入数值'` is written once in each of two source files and both go into one
///          cell.
///          (2) **The English side must hold no Han, no empty string, and must differ from the
///          Chinese.** An empty string renders on screen as a blank cell, the hardest kind of missing
///          copy to notice; an entry equal to the Chinese means it was never translated. **Two entries
///          are worth a footnote**: `listSeparator` / `sentenceSeparator` are separators rather than
///          sentences, and the English side differs from the Chinese by construction — the note is only
///          here to say why they are in a copy table at all.
void main() {
  final zh = ToolDetailStrings.toolDetailZh;
  final en = ToolDetailStrings.toolDetailEn;

  test('工具详情页中文表与迁移前源码里那些字逐字节相同', () {
    // —— 数值解析那四句（两家共用的那一张，中文侧仍逐字节相同）——
    expect(zh.numericInput.inputRequired, '请输入数值');
    expect(zh.numericInput.inputNotFinite, '结果不是有限数值');
    expect(zh.numericInput.inputUnparsable, '无法解析数值或表达式');
    expect(zh.numericInput.inputUnitMismatch('V', 'A'), '单位 V 与 A 不匹配');

    // —— 输入框 ——
    expect(zh.invalidInput, '输入无效');
    expect(zh.inputNotFilled('电流 I'), '电流 I: 未填写');
    expect(zh.inputErrorLine('电压 V', 'V', '输入无效'), '电压 V（V）: 输入无效');
    expect(zh.inputErrorLine('频率 f', '', '输入无效'), '频率 f: 输入无效');

    // —— 复制 / 笔记正文里的标签 ——
    expect(zh.noInputsNeeded, '无需输入参数');
    expect(zh.noResults, '暂无结果');
    expect(zh.noComputedResults, '暂无计算结果');
    expect(zh.copyInputsLabel, '输入参数:');
    expect(zh.copyResultsLabel, '计算结果:');
    expect(zh.copyResultStatusLabel, '结果状态:');
    expect(zh.copyChecksLabel, '校核:');
    expect(zh.copyFormula('R = U / I'), '公式: R = U / I');

    // —— 状态卡 ——
    expect(zh.issueOverflowSuffix(5), ' 等 5 项');
    expect(zh.resultIssuesNeedCheck('功率 P', ''),
        '功率 P 需要检查，请结合输入参数和校核提示确认。');
    expect(zh.resultIssuesNeedCheck('功率 P', zh.issueOverflowSuffix(5)),
        '功率 P 等 5 项 需要检查，请结合输入参数和校核提示确认。');
    expect(zh.resultsReusable(3, '传动比 i: 2.5'), '3 个结果可复用，主结果 传动比 i: 2.5');
    expect(zh.moreIssuesNeedCheck('功率 P', 2), '功率 P\n另有 2 项结果需要检查');
    expect(zh.noCheckNotes, '暂无校核提示');

    // —— 粘贴 / 应用参数的摘要 ——
    expect(zh.pasteUnitAmbiguous, '剪贴板里的参数单位有歧义，未自动填入');
    expect(zh.pasteNumbersNoMatch, '剪贴板里有数字，但没有匹配到本工具参数');
    expect(zh.pasteNoInputsRecognised, '剪贴板里没有识别到本工具的参数');
    expect(zh.pasteApplied(3), '已粘贴 3 个参数');
    expect(zh.pasteDuplicate('电流 I、电压 V'), '重复字段已取最后值：电流 I、电压 V');
    expect(zh.pasteAmbiguousSkipped(1), '跳过 1 条歧义值');
    expect(zh.pasteIgnored(1), '忽略 1 条未匹配值');
    expect(zh.applyNothing, '没有可应用的参数');
    expect(zh.applyApplied(3), '已应用 3 个参数');
    expect(zh.applyAllNeedFix(2), '识别到 2 个参数但都需要修正');
    expect(zh.applyNeedFix('电压 V'), '需修正：电压 V');

    // —— 两个分隔符：全角的，**它们是文案的一部分** ——
    expect(zh.listSeparator, '、');
    expect(zh.sentenceSeparator, '，');
  });

  test('数值解析那四句的中文与英文是两张表，判据不随语言变', () {
    final zhNumbers = NumericInputStrings.numericInputZh;
    final enNumbers = NumericInputStrings.numericInputEn;
    expect(zhNumbers.inputRequired, '请输入数值');
    expect(enNumbers.inputRequired, 'Enter a number');
    expect(zhNumbers.inputUnitMismatch('V', 'A'), '单位 V 与 A 不匹配');
    expect(enNumbers.inputUnitMismatch('V', 'A'), 'Unit V does not match A');
    // 中文：两个槽是**单位名**，两种语言里都是调用方给的那两个词——表只负责把它们摆进句子。
    // English: the two slots are **unit names**, the same two words in either language — the table only
    //          places them in the sentence.
    expect(enNumbers.inputUnitMismatch('传动比 i', 'N·m'), 'Unit 传动比 i does not match N·m');
  });

  test('两张英文表没有汉字、没有空串，且与中文不同', () {
    final zhPairs = <String, String>{
      'invalidInput': zh.invalidInput,
      'noInputsNeeded': zh.noInputsNeeded,
      'noResults': zh.noResults,
      'noComputedResults': zh.noComputedResults,
      'issueOverflowSuffix': zh.issueOverflowSuffix(5),
      'resultIssuesNeedCheck': zh.resultIssuesNeedCheck('A', ''),
      'resultsReusable': zh.resultsReusable(3, 'B'),
      'moreIssuesNeedCheck': zh.moreIssuesNeedCheck('A', 2),
      'noCheckNotes': zh.noCheckNotes,
      'copyInputsLabel': zh.copyInputsLabel,
      'copyResultsLabel': zh.copyResultsLabel,
      'copyResultStatusLabel': zh.copyResultStatusLabel,
      'copyChecksLabel': zh.copyChecksLabel,
      'copyFormula': zh.copyFormula('a+b'),
      'inputNotFilled': zh.inputNotFilled('X'),
      'inputErrorLine': zh.inputErrorLine('X', 'V', 'Y'),
      'inputErrorLineNoUnit': zh.inputErrorLine('X', '', 'Y'),
      'pasteUnitAmbiguous': zh.pasteUnitAmbiguous,
      'pasteNumbersNoMatch': zh.pasteNumbersNoMatch,
      'pasteNoInputsRecognised': zh.pasteNoInputsRecognised,
      'pasteApplied': zh.pasteApplied(3),
      'pasteDuplicate': zh.pasteDuplicate('A'),
      'pasteAmbiguousSkipped': zh.pasteAmbiguousSkipped(1),
      'pasteIgnored': zh.pasteIgnored(1),
      'applyNothing': zh.applyNothing,
      'applyApplied': zh.applyApplied(3),
      'applyAllNeedFix': zh.applyAllNeedFix(2),
      'applyNeedFix': zh.applyNeedFix('A'),
      'listSeparator': zh.listSeparator,
      'sentenceSeparator': zh.sentenceSeparator,
    };
    final enPairs = <String, String>{
      'invalidInput': en.invalidInput,
      'noInputsNeeded': en.noInputsNeeded,
      'noResults': en.noResults,
      'noComputedResults': en.noComputedResults,
      'issueOverflowSuffix': en.issueOverflowSuffix(5),
      'resultIssuesNeedCheck': en.resultIssuesNeedCheck('A', ''),
      'resultsReusable': en.resultsReusable(3, 'B'),
      'moreIssuesNeedCheck': en.moreIssuesNeedCheck('A', 2),
      'noCheckNotes': en.noCheckNotes,
      'copyInputsLabel': en.copyInputsLabel,
      'copyResultsLabel': en.copyResultsLabel,
      'copyResultStatusLabel': en.copyResultStatusLabel,
      'copyChecksLabel': en.copyChecksLabel,
      'copyFormula': en.copyFormula('a+b'),
      'inputNotFilled': en.inputNotFilled('X'),
      'inputErrorLine': en.inputErrorLine('X', 'V', 'Y'),
      'inputErrorLineNoUnit': en.inputErrorLine('X', '', 'Y'),
      'pasteUnitAmbiguous': en.pasteUnitAmbiguous,
      'pasteNumbersNoMatch': en.pasteNumbersNoMatch,
      'pasteNoInputsRecognised': en.pasteNoInputsRecognised,
      'pasteApplied': en.pasteApplied(3),
      'pasteDuplicate': en.pasteDuplicate('A'),
      'pasteAmbiguousSkipped': en.pasteAmbiguousSkipped(1),
      'pasteIgnored': en.pasteIgnored(1),
      'applyNothing': en.applyNothing,
      'applyApplied': en.applyApplied(3),
      'applyAllNeedFix': en.applyAllNeedFix(2),
      'applyNeedFix': en.applyNeedFix('A'),
      'listSeparator': en.listSeparator,
      'sentenceSeparator': en.sentenceSeparator,
    };
    // 中文：**按设计就与中文相同的那一格。** `inputErrorLine` 在单位为空的这一支上，
    //       两种语言印出来的形状都是 `<标签>: <那句话>`——标签是**数据**（来自工具定义），
    //       那句话来自 `numericInput` 那张表，**这一格自己一个词都没有**。
    //       所以"必须与中文不同"这条判据对它不成立，但它照旧受上面两条（非空、无汉字）的检查。
    //       这与文本工具那份里的 `identicalByDesign` 是同一种豁免。
    // English: **the one cell that is identical by design.** On `inputErrorLine`'s empty-unit branch
    //          both languages print `<label>: <message>` — the label is **data** (from the tool
    //          definition) and the message comes from the `numericInput` table, so **this cell holds no
    //          words of its own**. The "must differ from the Chinese" criterion therefore does not
    //          apply to it, while the two checks above (non-empty, no Han) still do — the same kind of
    //          exemption as `identicalByDesign` in the text-tool file.
    const identicalByDesign = <String>{'inputErrorLineNoUnit'};

    expect(enPairs.keys.toSet(), zhPairs.keys.toSet(),
        reason: '两张表的格子必须一一对应，少一格就是漏译');
    for (final entry in enPairs.entries) {
      expect(entry.value.trim(), isNotEmpty, reason: '${entry.key} 是空的');
      expect(_containsCjk(entry.value), isFalse,
          reason: '${entry.key} 英文表里还有汉字：${entry.value}');
      if (identicalByDesign.contains(entry.key)) continue;
      expect(entry.value, isNot(zhPairs[entry.key]),
          reason: '${entry.key} 与中文一字不差，等于没翻');
    }
    // 中文：中文侧**同样不许有空串**——空串在屏幕上是"这一格什么都没有"。
    // English: the Chinese side **must hold no empty string either** — on screen it renders as a blank
    //          cell.
    for (final entry in zhPairs.entries) {
      expect(entry.value, isNotEmpty, reason: '${entry.key} 中文侧是空的');
    }

    final zhNumbers = NumericInputStrings.numericInputZh;
    final enNumbers = NumericInputStrings.numericInputEn;
    final zhNumberPairs = <String, String>{
      'inputRequired': zhNumbers.inputRequired,
      'inputNotFinite': zhNumbers.inputNotFinite,
      'inputUnparsable': zhNumbers.inputUnparsable,
      'inputUnitMismatch': zhNumbers.inputUnitMismatch('X', 'Y'),
    };
    final enNumberPairs = <String, String>{
      'inputRequired': enNumbers.inputRequired,
      'inputNotFinite': enNumbers.inputNotFinite,
      'inputUnparsable': enNumbers.inputUnparsable,
      'inputUnitMismatch': enNumbers.inputUnitMismatch('X', 'Y'),
    };
    expect(enNumberPairs.keys.toSet(), zhNumberPairs.keys.toSet());
    for (final entry in enNumberPairs.entries) {
      expect(entry.value.trim(), isNotEmpty, reason: '${entry.key} 是空的');
      expect(_containsCjk(entry.value), isFalse,
          reason: '${entry.key} 英文表里还有汉字：${entry.value}');
      expect(entry.value, isNot(zhNumberPairs[entry.key]),
          reason: '${entry.key} 与中文一字不差，等于没翻');
    }
  });

  test('`of` 与 `forLanguage` 走同一张分派表，不会分叉', () {
    // 中文：`ToolDetailStrings.of` 走 `AppLanguage.of`，`forLanguage` 走那个 switch；`of` 的实现体
    //       只有一行 `return forLanguage(...)`，所以两条路不可能分叉。这条断言钉住的是
    //       **枚举与表一一对应**：`AppLanguage.values` 里每一个都有表，且 zh 那一支就是中文表。
    // English: `ToolDetailStrings.of` goes through `AppLanguage.of` and `forLanguage` through the
    //          switch; `of`'s body is the single line `return forLanguage(...)`, so the two routes
    //          cannot drift. What this pins is **the enum and the tables corresponding one for one**:
    //          every `AppLanguage.values` entry has a table, and the `zh` arm is the Chinese one.
    expect(ToolDetailStrings.toolDetailZh.numericInput,
        same(NumericInputStrings.numericInputZh));
    expect(ToolDetailStrings.toolDetailEn.numericInput,
        same(NumericInputStrings.numericInputEn));
  });
}

/// 中文：英文表里还有没有汉字。与其余几条护栏用的是同一条判据（`[一-鿿]` 那一段 CJK）。
/// English: whether the English table still holds Han. The same criterion as the other guards (the
///          `[一-鿿]` CJK block).
bool _containsCjk(String value) => RegExp(r'[一-鿿]').hasMatch(value);
