import '../../domain/entities/tool_definition.dart';
import '../../features/tools/presentation/tool_detail_strings.dart';

/// 中文：**一次数值输入解析为什么没成——是一个判据，不是一句话。**
///
///       它原先不是枚举：`NumericInputParseResult.error` 是一个 `String`，值就是那四句中文本身。
///       于是**一句要显示给用户的话同时是数据**——英文界面下那句话该变，而调用方还拿它做 `??` 的
///       兜底。改成枚举之后，判据与文案各归各位，渲染发生在显示侧
///       （[NumericInputParseResult.issueMessage]）。这与 `TextToolOutput.hasError` 从"比字符串"
///       改成真字段是同一件事，理由与实测写在 `numeric_input_strings.dart` 的文件头上。
///
///       **枚举必须穷尽**：加一种失败原因时，[NumericInputParseResult.issueMessage] 的 switch
///       编译不过，而不是静默回落到一句别的什么。
/// English: **why a numeric input parse failed — a verdict, not a sentence.**
///
///          It was not an enum before: `NumericInputParseResult.error` was a `String` whose value was
///          these four Chinese sentences themselves. So **a sentence meant for the user doubled as
///          data** — in an English interface that sentence has to change, yet the caller also used it
///          as the `??` fallback. With the enum, verdict and wording go back to being separate things
///          and rendering happens on the display side (`NumericInputParseResult.issueMessage`) — item
///          for item what happened to `TextToolOutput.hasError` when it stopped being a string
///          comparison; the reasoning and measurements are on `numeric_input_strings.dart`'s head.
///
///          **The enum must be exhaustive**: adding a failure reason breaks the switch in
///          `NumericInputParseResult.issueMessage` at compile time rather than silently falling back
///          to some other sentence.
enum NumericInputIssue {
  /// 中文：空的输入（`parseNumericInputForUnit` 的第一道门）。
  /// English: The input was empty (the first gate in `parseNumericInputForUnit`).
  empty,

  /// 中文：解析出来了，但不是有限值（`Infinity` / `NaN`）。
  /// English: It parsed, but the value is not finite (`Infinity` / `NaN`).
  notFinite,

  /// 中文：读不动——既不是数字，也不是一个能算的表达式。
  /// English: Unreadable — neither a number nor an evaluable expression.
  unparsable,

  /// 中文：读得动，但单位与目标参数不相容。两个单位名在 [NumericInputParseResult.unitLabel] 与
  ///       [NumericInputParseResult.targetUnit] 里。
  /// English: It reads fine, but the unit is incommensurable with the target parameter. The two unit
  ///          names are in [NumericInputParseResult.unitLabel] and
  ///          [NumericInputParseResult.targetUnit].
  unitMismatch,
}

class NumericInputParseResult {
  const NumericInputParseResult({
    required this.value,
    this.issue,
    this.unitLabel = '',
    this.targetUnit = '',
  });

  final double? value;

  /// 中文：`null` = 这一次读成了。**判据在这里，字在表里。**
  /// English: `null` means this parse succeeded. **The verdict is here; the words are in the table.**
  final NumericInputIssue? issue;

  /// 中文：[NumericInputIssue.unitMismatch] 的两个槽。**这一层只负责"原样留住读到的那个值"，
  ///       一个字符都不翻**——**而"不翻"的射程到此为止，显示侧怎么渲染是显示侧的事**：
  ///       `unitLabel` 是用户打的（显示侧也原样出），`targetUnit` 是目录声明的
  ///       （显示侧过 `ToolFieldStrings.inputUnit`，见 `numeric_input_strings.dart` 的文件头）。
  ///
  ///       ⚠️ **本文件此前写着"两个都是数据，不进表也不许翻"。** 前半句对（解析层确实不许翻），
  ///       **后半句越界了**——它把一条**本层的**规矩说成了全局的，于是显示侧那 88 行中文
  ///       被这条判据挡了好几轮。**判据的射程要写在判据旁边**，否则下一个读者会以为它管到底。
  /// English: the two slots of [NumericInputIssue.unitMismatch]. **This layer's whole job is to keep the
  ///          value it read, verbatim — it translates nothing** — **and that "nothing" reaches no
  ///          further than this layer: how the display side renders them is the display side's
  ///          business.** `unitLabel` is what the user typed (the display side shows it as-is too) and
  ///          `targetUnit` is the catalogue's (the display side passes it through
  ///          `ToolFieldStrings.inputUnit`; see `numeric_input_strings.dart`'s head).
  ///
  ///          ⚠️ **This used to read "both are data; they enter no table and must never be translated".**
  ///          The first half is right (this layer indeed must not translate) and **the second half
  ///          overreached** — it stated a rule **of this layer** as if it were global, and that ruling
  ///          held back those 88 Chinese lines on the display side for several rounds. **A ruling's
  ///          reach belongs beside the ruling**, or the next reader thinks it governs all the way down.
  final String unitLabel;
  final String targetUnit;

  bool get hasError => issue != null;

  /// 中文：这一次失败在屏幕上要说的话。**调用方递表进来，自己不留中文兜底**——与
  ///       `TextToolOutput.statusMessage(strings)` 同一条形状。
  /// English: what this failure says on screen. **The caller hands the table in; nothing here keeps a
  ///          Chinese fallback** — the same shape as `TextToolOutput.statusMessage(strings)`.
  String issueMessage(NumericInputStrings strings) {
    return switch (issue) {
      null => '',
      NumericInputIssue.empty => strings.inputRequired,
      NumericInputIssue.notFinite => strings.inputNotFinite,
      NumericInputIssue.unparsable => strings.inputUnparsable,
      NumericInputIssue.unitMismatch =>
        strings.inputUnitMismatch(unitLabel, targetUnit),
    };
  }
}

class ToolInputPasteResult {
  const ToolInputPasteResult({
    required this.values,
    required this.ignoredSegments,
    required this.ambiguousSegments,
    required this.duplicateKeys,
    required this.segmentCount,
  });

  factory ToolInputPasteResult.empty() => const ToolInputPasteResult(
        values: {},
        ignoredSegments: [],
        ambiguousSegments: [],
        duplicateKeys: {},
        segmentCount: 0,
      );

  final Map<String, String> values;
  final List<String> ignoredSegments;
  final List<String> ambiguousSegments;
  final Set<String> duplicateKeys;
  final int segmentCount;

  bool get hasValues => values.isNotEmpty;

  int get matchedCount => values.length;

  int get issueCount =>
      ignoredSegments.length + ambiguousSegments.length + duplicateKeys.length;

  bool get hasIssues => issueCount > 0;

  /// 中文：粘贴摘要。**表是必填参数，没有中文兜底**——一个忘了递表的新调用点编译不过，
  ///       而不是在英文界面上悄悄吐出一句中文。
  /// English: the paste summary. **The table is a required parameter with no Chinese fallback** — a
  ///          new call site that forgets it fails to compile rather than quietly emitting a Chinese
  ///          sentence into an English interface.
  String summaryForTool(ToolDefinition tool, ToolDetailStrings strings) {
    if (!hasValues) {
      if (ambiguousSegments.isNotEmpty) {
        return strings.pasteUnitAmbiguous;
      }
      if (ignoredSegments.isNotEmpty) {
        return strings.pasteNumbersNoMatch;
      }
      return strings.pasteNoInputsRecognised;
    }
    final parts = <String>[
      strings.pasteApplied(matchedCount),
    ];
    if (duplicateKeys.isNotEmpty) {
      parts.add(strings.pasteDuplicate(
          _inputLabels(tool, duplicateKeys).join(strings.listSeparator)));
    }
    if (ambiguousSegments.isNotEmpty) {
      parts.add(strings.pasteAmbiguousSkipped(ambiguousSegments.length));
    }
    if (ignoredSegments.isNotEmpty) {
      parts.add(strings.pasteIgnored(ignoredSegments.length));
    }
    return parts.join(strings.sentenceSeparator);
  }

  static List<String> _inputLabels(ToolDefinition tool, Iterable<String> keys) {
    final byKey = {for (final input in tool.inputs) input.key: input.label};
    return keys.map((key) => byKey[key] ?? key).toList(growable: false);
  }
}

class ToolInputApplyResult {
  const ToolInputApplyResult({
    required this.inputTexts,
    required this.filledKeys,
    required this.validKeys,
    required this.invalidKeyErrors,
    this.pasteResult,
  });

  final Map<String, String> inputTexts;
  final Set<String> filledKeys;
  final Set<String> validKeys;
  final Map<String, String> invalidKeyErrors;
  final ToolInputPasteResult? pasteResult;

  bool get hasValues => filledKeys.isNotEmpty;

  bool get hasInvalidValues => invalidKeyErrors.isNotEmpty;

  bool get hasValidValues => validKeys.isNotEmpty;

  /// 中文：与 [ToolInputPasteResult.summaryForTool] 同一条：表必填，没有中文兜底。
  /// English: the same rule as [ToolInputPasteResult.summaryForTool]: the table is required and there
  ///          is no Chinese fallback.
  String summaryForTool(ToolDefinition tool, ToolDetailStrings strings) {
    final paste = pasteResult;
    if (!hasValues) {
      return paste?.summaryForTool(tool, strings) ?? strings.applyNothing;
    }
    final parts = <String>[
      if (hasValidValues)
        strings.applyApplied(validKeys.length)
      else
        strings.applyAllNeedFix(filledKeys.length),
    ];
    if (hasInvalidValues) {
      parts.add(strings.applyNeedFix(_inputLabels(tool, invalidKeyErrors.keys)
          .join(strings.listSeparator)));
    }
    if (paste != null) {
      if (paste.duplicateKeys.isNotEmpty) {
        parts.add(strings.pasteDuplicate(
            _inputLabels(tool, paste.duplicateKeys).join(strings.listSeparator)));
      }
      if (paste.ambiguousSegments.isNotEmpty) {
        parts.add(strings.pasteAmbiguousSkipped(paste.ambiguousSegments.length));
      }
      if (paste.ignoredSegments.isNotEmpty) {
        parts.add(strings.pasteIgnored(paste.ignoredSegments.length));
      }
    }
    return parts.join(strings.sentenceSeparator);
  }

  static List<String> _inputLabels(ToolDefinition tool, Iterable<String> keys) {
    final byKey = {for (final input in tool.inputs) input.key: input.label};
    return keys.map((key) => byKey[key] ?? key).toList(growable: false);
  }
}
