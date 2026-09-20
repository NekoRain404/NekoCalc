import 'package:flutter/widgets.dart';

import '../../../l10n/app_language.dart';
import 'tool_field_strings.dart';

/// 中文：**一次数值输入解析失败时写给用户的那几句话。** 它们在 `tool_detail_input_parsing.dart`
///       里产出，而那个文件是**静态方法**的地盘——`ToolDetailController.parseNumericInputForUnit`
///       与 `parseNumericInputDetailed` 没有实例，拿不到挂在控制器上的那张表。所以这一张**必须跟着
///       参数走**，而参数既然要递，就干脆让它成为一张**能被两家共用的表**。
///
///       **为什么它是独立的一张表，而不是并进 `ToolDetailStrings`。** 它有两个产出方：工程工具详情页
///       （`tool_detail_input_parsing.dart`）与文本工具里的自定义公式
///       （`text_tool_custom_formula_tools.dart` 用同一个解析器算 `a`/`b`/`c`）。并进任何一家，
///       另一家要么去 import 别人家的表（两族从此互相咬住），要么把那四句话再抄一遍（同一句中文
///       两个地方各自漂）。**同一句话只留一个源**，与 `test/shared/source_scan.dart` 那把尺子、
///       `roboto_regular_advances.dart` 当初搬家的理由是同一条。
///
///       **`NumericInputParseResult` 里的字段从"一句话"变成了"一个判据"。** 原先它是
///       `String? error`，值就是这四句中文本身；于是**一句要显示给用户的话同时是数据**——英文界面下
///       它该变成 `Cannot parse a number or expression`，而那一串同时也是调用方 `??` 的兜底依据。
///       现在字段是 `NumericInputIssue`（一个穷尽枚举）加两个载荷格（`unitMismatch` 要的那两个单位
///       名），**渲染发生在显示侧**：`NumericInputParseResult.issueMessage(这张表)`。判据与文案从此
///       各归各位，这与 `TextToolOutput.hasError` 从"比字符串"改成真字段是同一件事。
///
///       **表里没有 `'单位 ${a} 与 ${b} 不匹配'` 那样的半句话。** 那一条是一个函数，两个槽由调用方
///       填——**而这两个槽不是同一种东西，本轮把这一点分开了**：
///
///       * **`unitLabel`：用户打进来的那串。** 它是**数据**，不进表也不翻——中文模式打了 `5万元`，
///         英文界面上那一格仍是 `5万元`，因为那是他打的字。
///       * **`targetUnit`：目录给这个参数声明的单位**（`tool_detail_controller.dart:425` 的
///         `_inputUnit(key)`，取的就是工具定义里的 `input.unit`）。**它是文案，本来就有表**——
///         `ToolFieldStrings.inputUnit` 那 11 条（`元`/`万元`/`天`/`齿`/…）。
///         **本轮起这一格过那张表**：英文界面上 `Unit L does not match 万元` 变成
///         `Unit L does not match 10k ¥`。
///
///       ⚠️ **本文件此前写着「两个槽都是数据，不进表也不许翻」，而且括号里把来源写反了**
///       （原文：`unitLabel` 来自工具定义、`targetUnit` 来自参数）。**实测正好相反**：
///       `unitLabel` 是 `ToolUnitConversion.splitAnyKnownUnitSuffix` 从**用户输入**里切出来的
///       （`displayUnitAlias(alias)`），`targetUnit` 才是目录那一个。
///       反的那一半正是"所以两个都不许翻"的依据——**依据站不住，结论就只对了一半**。
///       留这段是因为：**一个理由被推翻时该说一声**，免得下一页的读者以为这里从来没有分错过。
/// English: **the sentences a failed numeric parse writes for the user.** They are produced in
///          `tool_detail_input_parsing.dart`, and that file belongs to **static methods** —
///          `ToolDetailController.parseNumericInputForUnit` and `parseNumericInputDetailed` have no
///          instance and cannot reach a table hung on the controller. So this one **has to travel
///          through the parameter list**, and once it travels it may as well be **one table both
///          families share**.
///
///          **Why it is a table of its own rather than folded into `ToolDetailStrings`.** It has two
///          producers: the engineering tool detail screen (`tool_detail_input_parsing.dart`) and the
///          custom-formula text tool (`text_tool_custom_formula_tools.dart` evaluates `a`/`b`/`c` with
///          the same parser). Folded into either, the other would have to import a sibling family's
///          table (the two families would then bite each other) or copy the four sentences again (one
///          Chinese sentence drifting in two places). **One sentence, one source** — the same rule
///          that moved `test/shared/source_scan.dart`'s ruler and `roboto_regular_advances.dart`.
///
///          **The field on `NumericInputParseResult` changed from "a sentence" to "a verdict".** It
///          used to be `String? error`, whose value was these four Chinese sentences themselves — so
///          **a sentence meant for the user doubled as data**: in an English interface it should read
///          `Cannot parse a number or expression`, yet that same string was also what the caller's
///          `??` fell back on. The field is now `NumericInputIssue` (an exhaustive enum) plus two
///          payload slots (the two unit names `unitMismatch` needs), and **rendering happens on the
///          display side**: `NumericInputParseResult.issueMessage(thisTable)`. Verdict and wording go
///          back to being separate things — item for item what happened to `TextToolOutput.hasError`
///          when it stopped being a string comparison.
///
///          **There is no half-sentence such as `'单位 ${a} 与 ${b} 不匹配'` in this table.** That one
///          is a function whose two slots the caller fills — **and the two slots are not the same kind
///          of thing, which this round separates**:
///
///          * **`unitLabel`: the string the user typed.** It is **data**; it enters no table and is never
///            translated. If someone typed `5万元` in Chinese, an English screen still shows `5万元` —
///            those are their characters.
///          * **`targetUnit`: the unit the catalogue declares for that parameter** (`_inputUnit(key)` at
///            `tool_detail_controller.dart:425`, whose value is the tool definition's `input.unit`).
///            **It is copy and it already had a table** — `ToolFieldStrings.inputUnit`, those eleven
///            entries (`元`/`万元`/`天`/`齿`/…). **From this round that cell goes through it**: on an
///            English screen `Unit L does not match 万元` becomes `Unit L does not match 10k ¥`.
///
///          ⚠️ **This file used to read "both slots are data; they enter no table and are never
///          translated", and its parenthetical had the sources backwards** (it read "`unitLabel` comes
///          from the tool definition, `targetUnit` from the parameter list"). **Measured, it is the
///          other way round**: `unitLabel` is cut out of **the user's input** by
///          `ToolUnitConversion.splitAnyKnownUnitSuffix` (`displayUnitAlias(alias)`), and `targetUnit`
///          is the catalogue's. The reversed half was exactly the ground for "so neither may be
///          translated" — **a ground that does not hold leaves a conclusion only half right.** The note
///          is kept because **a reason that is overturned should say so**, so the next reader does not
///          think these sources were never mixed up.
@immutable
class NumericInputStrings {
  const NumericInputStrings({
    required this.inputRequired,
    required this.inputNotFinite,
    required this.inputUnparsable,
    required this.inputUnitMismatch,
  });

  /// 中文：空输入。**它同时也是 `inputIssueEmpty` 的那一句**——源码里本来就只有一个字面量
  ///       （`tool_detail_controller.dart` 与 `tool_detail_input_parsing.dart` 各写了一次，
  ///       值一样），所以这里也只留一格，不造两个名字。
  /// English: The empty input. **It is also the `inputIssueEmpty` sentence** — the source carried
  ///          exactly one literal (written once in `tool_detail_controller.dart` and once in
  ///          `tool_detail_input_parsing.dart`, same value), so there is one slot here, not two
  ///          names for it.
  final String inputRequired;
  final String inputNotFinite;
  final String inputUnparsable;

  /// 中文：单位不相容。**两个槽的来路不同**：`unitLabel` 是用户打的（原样显示），`targetUnit` 是
  ///       目录声明的（过 `ToolFieldStrings.inputUnit`，在下面两个实例里已经包好了）。详见文件头。
  /// English: Incommensurable units. **The two slots come from different places**: `unitLabel` is what
  ///          the user typed (shown as-is) and `targetUnit` is the catalogue's (passed through
  ///          `ToolFieldStrings.inputUnit`, already wrapped in the two instances below). See the head.
  final String Function(String unitLabel, String targetUnit) inputUnitMismatch;

  static NumericInputStrings of(BuildContext context) {
    return forLanguage(AppLanguage.of(context));
  }

  /// 中文：与 [of] 同一张分派表，供不持有 `BuildContext` 的调用方使用。两条路径共用这一个
  ///       switch，不会分叉。
  /// English: The same dispatch as [of], for callers without a `BuildContext`. Both routes share
  ///          this one switch, so they cannot drift apart.
  static NumericInputStrings forLanguage(AppLanguage language) {
    return switch (language) {
      AppLanguage.zh => numericInputZh,
      AppLanguage.en => numericInputEn,
    };
  }

  static final NumericInputStrings numericInputZh = NumericInputStrings(
    inputRequired: '请输入数值',
    inputNotFinite: '结果不是有限数值',
    inputUnparsable: '无法解析数值或表达式',
    inputUnitMismatch: (unitLabel, targetUnit) =>
        // 中文：`targetUnit` 过目录那张表；中文表是空表，查不到原样返回，所以这一句与改动前**逐字节相同**。
        // English: `targetUnit` goes through the catalogue's table; the Chinese table is empty and a miss
        //          returns its argument, so this sentence stays **byte-identical** to the pre-change one.
        '单位 $unitLabel 与 '
        '${ToolFieldStrings.toolFieldsZh.inputUnit(targetUnit)} 不匹配',
  );

  static final NumericInputStrings numericInputEn = NumericInputStrings(
    inputRequired: 'Enter a number',
    inputNotFinite: 'The result is not a finite number',
    inputUnparsable: 'Cannot parse a number or expression',
    inputUnitMismatch: (unitLabel, targetUnit) =>
        'Unit $unitLabel does not match '
        '${ToolFieldStrings.toolFieldsEn.inputUnit(targetUnit)}',
  );
}
