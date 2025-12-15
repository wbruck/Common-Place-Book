import 'package:drift/drift.dart';
import 'package:drift/web.dart';

/// Opens a database connection for web platform using sql.js + IndexedDB.
QueryExecutor openConnection() {
  return WebDatabase(
    'common_place_book_db',
    initializer: () async {
      // sql.js files are loaded automatically from web/ directory
    },
  );
}
