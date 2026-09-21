enum NoteArchiveFilter { active, archived, all }

enum NoteSort { updatedNewest, updatedOldest, titleAscending }

class NoteItem {
  const NoteItem({
    required this.id,
    required this.title,
    required this.description,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    this.tags = const [],
    this.isPinned = false,
    this.isArchived = false,
  });

  final int id;
  final String title;
  final String description;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> tags;
  final bool isPinned;
  final bool isArchived;

  factory NoteItem.fromMap(Map<String, Object?> map) {
    return NoteItem(
      id: map['id'] as int,
      title: map['title'] as String,
      description: (map['description'] as String?) ?? '',
      body: map['body'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['updated_at'] as int?) ?? (map['created_at'] as int),
      ),
      tags: noteTagsFromStorage(map['tags'] as String? ?? ''),
      isPinned: (map['is_pinned'] as int? ?? 0) != 0,
      isArchived: (map['is_archived'] as int? ?? 0) != 0,
    );
  }

  NoteItem copyWith({
    String? title,
    String? description,
    String? body,
    DateTime? updatedAt,
    List<String>? tags,
    bool? isPinned,
    bool? isArchived,
  }) {
    return NoteItem(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      body: body ?? this.body,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
    );
  }
}

List<String> normalizeNoteTags(Iterable<String> values) {
  final seen = <String>{};
  final tags = <String>[];
  for (final value in values) {
    final tag = value.trim().replaceAll('|', '');
    if (tag.isEmpty || !seen.add(tag.toLowerCase())) continue;
    tags.add(tag);
  }
  return tags;
}

String noteTagsToStorage(Iterable<String> values) {
  final tags = normalizeNoteTags(values);
  return tags.isEmpty ? '' : '|${tags.join('|')}|';
}

List<String> noteTagsFromStorage(String value) {
  return normalizeNoteTags(value.split('|'));
}
