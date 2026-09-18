import '../entities/tool_definition.dart';

double? toolResultNumber(List<ToolResult> results, String label) {
  for (final result in results) {
    if (!result.label.contains(label)) continue;
    final normalized = result.value
        .trim()
        .replaceAll(',', '')
        .replaceAll('%', '')
        .replaceAll('−', '-');
    return double.tryParse(normalized);
  }
  return null;
}

String? toolResultText(List<ToolResult> results, String label) {
  for (final result in results) {
    if (result.label.contains(label)) return result.value;
  }
  return null;
}

/// 中文：这条结果**是不是那条「无效」记号本身**——不是「含有它的某句话」。
///       本文件里 119 处 `xText == '无效'` 问的就是这件事，从前是回读那句话问出来的；
///       现在问产出方写下的旗标。**与 [toolResultHasError] 是两个问题**：`(0, 无效)` 那种拼出来
///       的值是错误，但它的值不是那条记号——这正是八个 `tool_insights_*.dart` 需要的区分，
///       照抄 `hasError` 会让「矩阵元素必须有限」那一类提示多冒出来一条。
/// English: Whether this result **is the `无效` marker itself** — not "some sentence containing it".
///          The 119 `xText == '无效'` comparisons in this family ask exactly this, and used to ask it
///          by reading the sentence back; they now ask the flag the producer wrote. **This is a
///          different question from [toolResultHasError]**: an assembled value such as `(0, 无效)` is
///          an error, but its value is not the marker — that is the distinction the eight
///          `tool_insights_*.dart` files need, and using `hasError` would make "matrix entries must
///          be finite"-style hints fire one time too many.
bool toolResultUnavailable(List<ToolResult> results, String label) {
  for (final result in results) {
    if (result.label.contains(label)) return result.isInvalidMarker;
  }
  return false;
}

/// 中文：这条结果**是一条错误，而它的值不是那条记号**——也就是产出方给出的是一个明确的结论
///       （`不可逆`、`对数无效`），而不是「算不出来」。矩阵那一处 `state == '不可逆'` 问的就是
///       它：元素不是有限数时那条状态是「无效」（记号），不是「不可逆」。
/// English: Whether this result **is an error whose value is not the marker** — that is, the producer
///          reached a definite conclusion (`不可逆`, `对数无效`) rather than failing to compute. That
///          is what the matrix site's `state == '不可逆'` asks: when the entries are not finite the
///          state reads the marker, not `不可逆`.
bool toolResultConcludedError(List<ToolResult> results, String label) {
  for (final result in results) {
    if (result.label.contains(label)) {
      return result.hasError && !result.isInvalidMarker;
    }
  }
  return false;
}

/// 中文：这条结果**是不是一条错误**——产出方写下的那个旗标。给下游真正想问「有没有出错」的
///       地方用，别拿它代替 [toolResultUnavailable]。
/// English: Whether this result **is an error** — the flag the producer wrote. For downstream code
///          that really is asking "did this go wrong"; do not use it in place of
///          [toolResultUnavailable].
bool toolResultHasError(List<ToolResult> results, String label) {
  for (final result in results) {
    if (result.label.contains(label)) return result.hasError;
  }
  return false;
}
