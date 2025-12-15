import 'package:drift/drift.dart';
import 'package:drift/web.dart';

/// Opens a database connection for web platform using sql.js + IndexedDB.
QueryExecutor openConnection() {
  return WebDatabase('common_place_book_db');
}
