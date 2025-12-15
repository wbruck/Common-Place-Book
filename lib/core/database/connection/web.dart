import 'package:drift/drift.dart';
import 'package:drift/web.dart';

/// Opens a database connection for web platform using IndexedDB.
/// This is simpler and more reliable than WASM, though with some limitations.
QueryExecutor openConnection() {
  return WebDatabase.withStorage(
    DriftWebStorage.indexedDb(
      'common_place_book_db',
      migrateFromLocalStorage: false,
      inWebWorker: false,
    ),
  );
}
