class NoteItem {
  const NoteItem({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
  });

  final int id;
  final String title;
  final String body;
  final DateTime createdAt;

  factory NoteItem.fromMap(Map<String, Object?> map) {
    return NoteItem(
      id: map['id'] as int,
      title: map['title'] as String,
      body: map['body'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}
