import '../local/app_database.dart';
import '../models/note_item.dart';

class NotesRepository {
  const NotesRepository(this._db);

  final AppDatabase _db;

  Future<int> create({
    required String title,
    required String body,
    String description = '',
  }) {
    return _db.addNote(title, body, description: description);
  }

  Future<void> update({
    required int id,
    required String title,
    required String description,
    required String body,
  }) {
    return _db.updateNote(
        id: id, title: title, description: description, body: body);
  }

  Future<List<NoteItem>> list({
    int limit = 200,
    int offset = 0,
    String? query,
  }) {
    return _db.notes(limit: limit, offset: offset, query: query);
  }

  Future<int> count({String? query}) => _db.noteCount(query: query);

  Future<int> delete(int id) => _db.deleteNote(id);

  Future<int> deleteMany(Iterable<int> ids) => _db.deleteNotes(ids);
}
