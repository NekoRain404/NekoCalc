/// A selected range in an expression, using zero-based string offsets.
class ExpressionSelection {
  const ExpressionSelection(this.start, this.end);

  const ExpressionSelection.collapsed(int offset) : this(offset, offset);

  final int start;
  final int end;

  bool get isCollapsed => start == end;

  ExpressionSelection clamp(int expressionLength) {
    final length = expressionLength < 0 ? 0 : expressionLength;
    final clampedStart = start.clamp(0, length).toInt();
    final clampedEnd = end.clamp(0, length).toInt();
    if (clampedStart <= clampedEnd) {
      return ExpressionSelection(clampedStart, clampedEnd);
    }
    return ExpressionSelection(clampedEnd, clampedStart);
  }

  @override
  bool operator ==(Object other) {
    return other is ExpressionSelection &&
        other.start == start &&
        other.end == end;
  }

  @override
  int get hashCode => Object.hash(start, end);
}
