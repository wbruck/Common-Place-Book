import 'database.dart';

class DatabaseProvider {
  DatabaseProvider._();

  static AppDatabase? _database;

  static void initialize(AppDatabase database) {
    _database = database;
  }

  static AppDatabase get instance {
    if (_database == null) {
      throw StateError(
        'Database has not been initialized. '
        'Call DatabaseProvider.initialize() first.',
      );
    }
    return _database!;
  }

  static Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
