import 'package:drift/drift.dart';

/// Returns the appropriate database connection for the current platform.
/// This is a stub that gets replaced by conditional imports.
QueryExecutor openConnection() {
  throw UnsupportedError(
    'Cannot create a database connection without dart:io or dart:html',
  );
}
