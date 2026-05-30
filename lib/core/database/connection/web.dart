import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

/// Opens a database connection for the web platform using drift's WebAssembly
/// (WASM) backend.
///
/// This replaces the deprecated `WebDatabase` (legacy sql.js) backend, which
/// persisted the entire database into a single `localStorage` key. That backend
/// is unreliable: `localStorage` has a ~5MB cap and overflow throws a
/// `QuotaExceededError` that drift swallowed, silently dropping writes so data
/// was lost on reload.
///
/// [WasmDatabase.open] is the supported drift 2.31 path. It probes the browser
/// and chooses the most durable available storage:
/// - OPFS (Origin Private File System) when the page is cross-origin isolated
///   (requires COOP/COEP headers — see `web/_headers`).
/// - IndexedDB otherwise (durable, no special headers required).
///
/// Required assets in `web/` (must match the drift / sqlite3 versions in
/// pubspec.lock):
/// - `sqlite3.wasm`     — sqlite3 compiled to WebAssembly.
/// - `drift_worker.js`  — drift web worker compiled from `package:drift`.
///
/// The open call is async, so it is wrapped in a [LazyDatabase] which defers
/// opening until the first query and exposes a synchronous [QueryExecutor],
/// keeping `database.dart` and the rest of the app unchanged.
QueryExecutor openConnection() {
  return LazyDatabase(() async {
    final result = await WasmDatabase.open(
      databaseName: 'common_place_book_db',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.js'),
    );
    return result.resolvedExecutor;
  });
}
