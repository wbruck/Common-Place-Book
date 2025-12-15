import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

/// Opens a database connection for web platform using WASM SQLite.
QueryExecutor openConnection() {
  return driftDatabase(
    name: 'common_place_book.db',
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.dart.js'),
    ),
  );
}
