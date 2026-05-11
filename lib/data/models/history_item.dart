class HistoryItem {
  const HistoryItem({
    required this.id,
    required this.expression,
    required this.result,
    required this.createdAt,
  });

  final int id;
  final String expression;
  final String result;
  final DateTime createdAt;

  factory HistoryItem.fromMap(Map<String, Object?> map) {
    return HistoryItem(
      id: map['id'] as int,
      expression: map['expression'] as String,
      result: map['result'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}
