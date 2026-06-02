import 'dart:convert';

import '../../../core/utils/app_logger.dart';
import '../../../core/utils/result.dart';
import '../domain/backup_data.dart';
import '../domain/backup_repository.dart';

/// The on-disk backup format version this service reads and writes.
const int kBackupFormatVersion = 1;

const String _logTag = 'DataTransfer';

/// Serializes the local database to / from the JSON backup format.
///
/// The backup mirrors the four user-data tables 1:1 (categories, tags, entries,
/// entry_tags). Many-to-many relationships live in the `entryTags` array; tag
/// ids are NOT embedded inside entries. `settings` is intentionally excluded.
/// All timestamps are stored as their raw millisecond-since-epoch integers.
///
/// Persistence is delegated to a [BackupRepository] so this service stays free
/// of Drift specifics; results are returned as a [Result] rather than thrown.
class DataTransferService {
  DataTransferService(this._repo, {this.appVersion = 'unknown'});

  final BackupRepository _repo;

  /// The application version embedded in exports (injected from `package_info`
  /// at the composition root so it tracks the real build).
  final String appVersion;

  /// The application identifier embedded in exports.
  static const String _appId = 'common_place_book';

  /// Reads every user-data table and returns a pretty-printed JSON string in
  /// the backup format, or a [DataTransferFailure] if the read fails.
  Future<Result<String, DataTransferFailure>> exportToJson() async {
    try {
      final data = await _repo.readAll();

      final map = <String, Object?>{
        'formatVersion': kBackupFormatVersion,
        'app': _appId,
        'appVersion': appVersion,
        'schemaVersion': data.schemaVersion,
        'exportedAt': DateTime.now().toIso8601String(),
        'counts': <String, Object?>{
          'categories': data.categories.length,
          'tags': data.tags.length,
          'entries': data.entries.length,
          'entryTags': data.entryTags.length,
        },
        'categories': [
          for (final c in data.categories)
            <String, Object?>{
              'id': c.id,
              'name': c.name,
              'parentId': c.parentId,
              'icon': c.icon,
              'createdAt': c.createdAt,
            },
        ],
        'tags': [
          for (final t in data.tags)
            <String, Object?>{
              'id': t.id,
              'name': t.name,
              'color': t.color,
              'createdAt': t.createdAt,
            },
        ],
        'entries': [
          for (final e in data.entries)
            <String, Object?>{
              'id': e.id,
              'content': e.content,
              'source': e.source,
              'categoryId': e.categoryId,
              'createdAt': e.createdAt,
              'updatedAt': e.updatedAt,
              'lastViewedAt': e.lastViewedAt,
              'viewCount': e.viewCount,
              'isFavorite': e.isFavorite,
            },
        ],
        'entryTags': [
          for (final et in data.entryTags)
            <String, Object?>{'entryId': et.entryId, 'tagId': et.tagId},
        ],
      };

      AppLogger.info(
        'Exported ${data.categories.length} categories, ${data.tags.length} '
        'tags, ${data.entries.length} entries, ${data.entryTags.length} '
        'entryTags',
        tag: _logTag,
      );

      return Success(const JsonEncoder.withIndent('  ').convert(map));
    } on Object catch (e) {
      AppLogger.error('Export failed', tag: _logTag, error: e);
      return const Failure(
        DataTransferFailure.unexpected('Could not create the backup.'),
      );
    }
  }

  /// Parses [jsonString] and merges its rows into the database, preserving ids
  /// and all timestamps exactly.
  ///
  /// This is intentionally a non-destructive **merge**, not a replace: existing
  /// rows are updated and new rows added, but nothing already in the database is
  /// deleted. Categories are matched by id only (no name reconciliation), so a
  /// same-named category created independently on another device imports as a
  /// distinct row by design.
  ///
  /// Returns a [DataTransferFailure] (kind [DataTransferErrorKind.invalidBackup])
  /// when the payload is not a valid/compatible backup, or
  /// [DataTransferErrorKind.unexpected] for an unforeseen database error; on
  /// failure nothing is written (the merge runs in a single transaction).
  Future<Result<ImportSummary, DataTransferFailure>> importFromJson(
    String jsonString,
  ) async {
    final BackupData data;
    try {
      data = _parse(jsonString);
    } on FormatException catch (e) {
      AppLogger.error('Import rejected', tag: _logTag, error: e);
      return Failure(DataTransferFailure.invalidBackup(_friendly(e.message)));
    }

    try {
      final summary = await _repo.importMerge(data);
      AppLogger.info('Imported $summary', tag: _logTag);
      return Success(summary);
    } on FormatException catch (e) {
      // Referential-integrity rejection raised by the repository.
      AppLogger.error('Import rejected', tag: _logTag, error: e);
      return Failure(DataTransferFailure.invalidBackup(_friendly(e.message)));
    } on Object catch (e) {
      AppLogger.error('Import failed', tag: _logTag, error: e);
      return const Failure(
        DataTransferFailure.unexpected(
          'Import failed. Your data was not changed.',
        ),
      );
    }
  }

  String _friendly(String message) =>
      message.isNotEmpty ? message : 'This file is not a valid backup.';

  /// Validates the envelope and parses the payload into a [BackupData].
  /// Throws a [FormatException] describing the first problem encountered.
  BackupData _parse(String jsonString) {
    final Object? decoded;
    try {
      decoded = jsonDecode(jsonString) as Object?;
    } on FormatException {
      throw const FormatException('This file is not valid JSON.');
    }
    if (decoded is! Map<String, Object?>) {
      throw const FormatException(
        'This file is not a valid backup (expected a JSON object).',
      );
    }

    final formatVersion = decoded['formatVersion'];
    if (formatVersion != kBackupFormatVersion) {
      throw FormatException(
        'Unsupported backup formatVersion: $formatVersion '
        '(expected $kBackupFormatVersion).',
      );
    }

    final app = decoded['app'];
    if (app != null && app != _appId) {
      throw FormatException(
        'This backup was created by a different app ("$app").',
      );
    }

    // schemaVersion is optional (older backups predate it). Reject backups from
    // a newer schema we can't safely read; allow same-or-older.
    final schemaVersion = decoded['schemaVersion'];
    if (schemaVersion is int && schemaVersion > _repo.schemaVersion) {
      throw FormatException(
        'This backup was created by a newer version of the app '
        '(schema $schemaVersion > ${_repo.schemaVersion}). Please update first.',
      );
    }

    final categories = _asMapList(decoded['categories']);
    final tags = _asMapList(decoded['tags']);
    final entries = _asMapList(decoded['entries']);
    final entryTags = _asMapList(decoded['entryTags']);

    _checkCounts(decoded['counts'], categories, tags, entries, entryTags);

    return BackupData(
      schemaVersion:
          schemaVersion is int ? schemaVersion : _repo.schemaVersion,
      categories: [
        for (final m in categories)
          BackupCategory(
            id: _reqStr(m, 'categories', 'id'),
            name: _reqStr(m, 'categories', 'name'),
            parentId: _optStr(m, 'categories', 'parentId'),
            icon: _optStr(m, 'categories', 'icon'),
            createdAt: _reqInt(m, 'categories', 'createdAt'),
          ),
      ],
      tags: [
        for (final m in tags)
          BackupTag(
            id: _reqStr(m, 'tags', 'id'),
            name: _reqStr(m, 'tags', 'name'),
            color: _optStr(m, 'tags', 'color'),
            createdAt: _reqInt(m, 'tags', 'createdAt'),
          ),
      ],
      entries: [
        for (final m in entries)
          BackupEntry(
            id: _reqStr(m, 'entries', 'id'),
            content: _reqStr(m, 'entries', 'content'),
            source: _optStr(m, 'entries', 'source'),
            categoryId: _optStr(m, 'entries', 'categoryId'),
            createdAt: _reqInt(m, 'entries', 'createdAt'),
            updatedAt: _reqInt(m, 'entries', 'updatedAt'),
            lastViewedAt: _optInt(m, 'entries', 'lastViewedAt'),
            viewCount: _reqInt(m, 'entries', 'viewCount'),
            isFavorite: _reqBool(m, 'entries', 'isFavorite'),
          ),
      ],
      entryTags: [
        for (final m in entryTags)
          BackupEntryTag(
            entryId: _reqStr(m, 'entryTags', 'entryId'),
            tagId: _reqStr(m, 'entryTags', 'tagId'),
          ),
      ],
    );
  }

  /// Cross-checks the optional `counts` block against the actual array lengths
  /// so a truncated/corrupt backup is rejected instead of silently importing.
  void _checkCounts(
    Object? counts,
    List<Map<String, Object?>> categories,
    List<Map<String, Object?>> tags,
    List<Map<String, Object?>> entries,
    List<Map<String, Object?>> entryTags,
  ) {
    if (counts == null) {
      return;
    }
    if (counts is! Map<String, Object?>) {
      throw const FormatException('Invalid backup: "counts" must be an object.');
    }
    void check(String key, int actual) {
      final declared = counts[key];
      if (declared is int && declared != actual) {
        throw FormatException(
          'Invalid backup: counts.$key says $declared but the file contains '
          '$actual (the backup looks truncated or corrupt).',
        );
      }
    }

    check('categories', categories.length);
    check('tags', tags.length);
    check('entries', entries.length);
    check('entryTags', entryTags.length);
  }

  /// Coerces a JSON array of objects into a typed list of maps, treating a
  /// missing/null value as an empty list.
  List<Map<String, Object?>> _asMapList(Object? value) {
    if (value == null) {
      return const [];
    }
    if (value is! List) {
      throw const FormatException(
        'Invalid backup: expected a JSON array for a table section.',
      );
    }
    return [
      for (final item in value)
        if (item is Map<String, Object?>)
          item
        else
          throw const FormatException(
            'Invalid backup: array entry is not a JSON object.',
          ),
    ];
  }

  /// Reads a required string field, throwing a descriptive [FormatException]
  /// when it is missing, null, or the wrong type.
  String _reqStr(Map<String, Object?> m, String table, String key) {
    final v = m[key];
    if (v is String) {
      return v;
    }
    throw FormatException(
      'Invalid backup: $table.$key must be a non-null string '
      '(got ${v.runtimeType}).',
    );
  }

  /// Reads an optional string field, allowing null but rejecting wrong types.
  String? _optStr(Map<String, Object?> m, String table, String key) {
    final v = m[key];
    if (v == null || v is String) {
      return v as String?;
    }
    throw FormatException(
      'Invalid backup: $table.$key must be a string or null '
      '(got ${v.runtimeType}).',
    );
  }

  /// Reads a required integer field. Tolerates JSON numbers decoded as `double`
  /// as long as they are integral; rejects missing/null/non-integral values.
  int _reqInt(Map<String, Object?> m, String table, String key) {
    final v = m[key];
    if (v is num) {
      return _toInt(v, table, key);
    }
    throw FormatException(
      'Invalid backup: $table.$key must be a non-null integer '
      '(got ${v.runtimeType}).',
    );
  }

  /// Reads an optional integer field, allowing null. Tolerates integral doubles.
  int? _optInt(Map<String, Object?> m, String table, String key) {
    final v = m[key];
    if (v == null) {
      return null;
    }
    if (v is num) {
      return _toInt(v, table, key);
    }
    throw FormatException(
      'Invalid backup: $table.$key must be an integer or null '
      '(got ${v.runtimeType}).',
    );
  }

  /// Reads a required boolean field, throwing on missing/null/wrong type.
  bool _reqBool(Map<String, Object?> m, String table, String key) {
    final v = m[key];
    if (v is bool) {
      return v;
    }
    throw FormatException(
      'Invalid backup: $table.$key must be a non-null boolean '
      '(got ${v.runtimeType}).',
    );
  }

  /// Coerces a JSON [num] into an [int], rejecting non-integral doubles so a
  /// hand-edited backup with e.g. `333333.5` fails loudly instead of silently
  /// truncating.
  int _toInt(num v, String table, String key) {
    if (v is int) {
      return v;
    }
    if (v is double && v == v.roundToDouble() && v.isFinite) {
      return v.toInt();
    }
    throw FormatException(
      'Invalid backup: $table.$key must be an integral number (got $v).',
    );
  }
}
