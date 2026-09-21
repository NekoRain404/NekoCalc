import '../local/app_database.dart';
import '../models/note_item.dart';

class NotesRepository {
  const NotesRepository(this._db);

  final AppDatabase _db;

  Future<int> create({
    required String title,
    required String body,
    String description = '',
    List<String> tags = const [],
  }) {
    return _db.addNote(title, body, description: description, tags: tags);
  }

  Future<void> update({
    required int id,
    required String title,
    required String description,
    required String body,
    List<String> tags = const [],
  }) {
    return _db.updateNote(
      id: id,
      title: title,
      description: description,
      body: body,
      tags: tags,
    );
  }

  Future<List<NoteItem>> list({
    int limit = 200,
    int offset = 0,
    String? query,
    String? tag,
    NoteArchiveFilter archiveFilter = NoteArchiveFilter.active,
    NoteSort sort = NoteSort.updatedNewest,
  }) {
    return _db.notes(
      limit: limit,
      offset: offset,
      query: query,
      tag: tag,
      archiveFilter: archiveFilter,
      sort: sort,
    );
  }

  Future<int> count({
    String? query,
    String? tag,
    NoteArchiveFilter archiveFilter = NoteArchiveFilter.active,
  }) =>
      _db.noteCount(
        query: query,
        tag: tag,
        archiveFilter: archiveFilter,
      );

  Future<void> setPinned(int id, bool value) => _db.setNotePinned(id, value);

  Future<void> setArchived(int id, bool value) =>
      _db.setNoteArchived(id, value);

  Future<List<String>> tags({
    NoteArchiveFilter archiveFilter = NoteArchiveFilter.active,
  }) =>
      _db.noteTags(archiveFilter: archiveFilter);

  Future<int> delete(int id) => _db.deleteNote(id);

  Future<int> deleteMany(Iterable<int> ids) => _db.deleteNotes(ids);
}
