import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

/// Opens a database connection for web platform using WASM SQLite.
QueryExecutor openConnection() {
  return DatabaseConnection.delayed(Future(() async {
    final result = await WasmDatabase.open(
      databaseName: 'common_place_book.db',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.js'),
    );

    if (result.missingFeatures.isNotEmpty) {
      // ignore: avoid_print
      print('Using ${result.chosenImplementation} due to missing browser features: '
          '${result.missingFeatures}');
    }

    return result.resolvedExecutor;
  }));
}
