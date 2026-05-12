import '../local/app_database.dart';

class SettingsRepository {
  const SettingsRepository(this._db);

  final AppDatabase _db;

  Future<Map<String, String>> load() => _db.settings();

  Future<void> set(String key, String value) => _db.setSetting(key, value);

  Future<void> setMany(Map<String, String> values) => _db.setSettings(values);
}
