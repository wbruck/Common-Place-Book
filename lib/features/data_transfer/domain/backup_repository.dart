import 'backup_data.dart';

/// Read/merge access to the local data used by backup export and import.
///
/// Keeps Drift specifics behind the data layer so [DataTransferService] can
/// program to this interface (per the project's repository convention) instead
/// of driving the database directly.
abstract class BackupRepository {
  /// The database schema version backups are produced against / validated for.
  int get schemaVersion;

  /// Reads every user-data table into a [BackupData] snapshot.
  Future<BackupData> readAll();

  /// Non-destructively merges [data] into the database (UPSERT, never delete),
  /// preserving ids and timestamps.
  ///
  /// Reconciles tag-name collisions (a name already owned by a different id is
  /// reused and its `entryTags` remapped), and validates referential integrity
  /// up front, throwing a [FormatException] that names the offending field when
  /// a row references a parent absent from both the backup and the database.
  ///
  /// Returns the number of rows actually written per table.
  Future<ImportSummary> importMerge(BackupData data);
}
