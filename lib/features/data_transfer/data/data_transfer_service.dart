import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/database.dart';
import '../../../core/utils/app_logger.dart';

/// The on-disk backup format version this service reads and writes.
const int kBackupFormatVersion = 1;

const String _logTag = 'DataTransfer';

/// Summary of the rows written during an [DataTransferService.importFromJson]
/// operation.
class ImportSummary {
  const ImportSummary({
    required this.categories,
    required this.tags,
    required this.entries,
    required this.entryTags,
  });

  final int categories;
  final int tags;
  final int entries;
  final int entryTags;

  @override
  String toString() =>
      'ImportSummary(categories: $categories, tags: $tags, '
      'entries: $entries, entryTags: $entryTags)';
}

/// Serializes the local database to / from the JSON backup format.
///
/// The backup mirrors the four user-data tables 1:1 (categories, tags, entries,
/// entry_tags). Many-to-many relationships live in the `entryTags` array; tag
/// ids are NOT embedded inside entries. `settings` is intentionally excluded.
/// All timestamps are stored as their raw millisecond-since-epoch integers.
class DataTransferService {
  DataTransferService(this._db);

  final AppDatabase _db;

  /// The application identifier embedded in exports.
  static const String _appId = 'common_place_book';

  /// The application version embedded in exports.
  static const String _appVersion = '1.0.0';

  /// Reads every user-data table and returns a pretty-printed JSON string in
  /// the backup format.
  Future<String> exportToJson() async {
    final categories = await _db.select(_db.categories).get();
    final tags = await _db.select(_db.tags).get();
    final entries = await _db.select(_db.entries).get();
    final entryTags = await _db.select(_db.entryTags).get();

    final map = <String, Object?>{
      'formatVersion': kBackupFormatVersion,
      'app': _appId,
      'appVersion': _appVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'counts': <String, Object?>{
        'categories': categories.length,
        'tags': tags.length,
        'entries': entries.length,
        'entryTags': entryTags.length,
      },
      'categories': [
        for (final c in categories)
          <String, Object?>{
            'id': c.id,
            'name': c.name,
            'parentId': c.parentId,
            'icon': c.icon,
            'createdAt': c.createdAt,
          },
      ],
      'tags': [
        for (final t in tags)
          <String, Object?>{
            'id': t.id,
            'name': t.name,
            'color': t.color,
            'createdAt': t.createdAt,
          },
      ],
      'entries': [
        for (final e in entries)
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
        for (final et in entryTags)
          <String, Object?>{
            'entryId': et.entryId,
            'tagId': et.tagId,
          },
      ],
    };

    AppLogger.info(
      'Exported ${categories.length} categories, ${tags.length} tags, '
      '${entries.length} entries, ${entryTags.length} entryTags',
      tag: _logTag,
    );

    return const JsonEncoder.withIndent('  ').convert(map);
  }

  /// Parses [jsonString] and UPSERTs its rows into the database, preserving ids
  /// and all timestamps exactly.
  ///
  /// Throws a [FormatException] if the payload is not a JSON object, its
  /// `formatVersion` is not [kBackupFormatVersion], a table section is not a
  /// JSON array, or a required field on any row is missing/null/the wrong type.
  ///
  /// Rows are written inside a single transaction with deferred foreign-key
  /// checks so insertion order and category self-references cannot trigger
  /// transient FK violations. Because `Tags.name` is UNIQUE, an incoming tag
  /// whose name already belongs to a different existing id is reconciled by
  /// reusing the existing id (and remapping its `entryTags`) rather than failing
  /// the whole import.
  Future<ImportSummary> importFromJson(String jsonString) async {
    final decoded = jsonDecode(jsonString) as Object?;
    if (decoded is! Map<String, Object?>) {
      throw const FormatException(
        'Invalid backup: expected a JSON object at the top level.',
      );
    }

    final formatVersion = decoded['formatVersion'];
    if (formatVersion != kBackupFormatVersion) {
      throw FormatException(
        'Unsupported backup formatVersion: $formatVersion '
        '(expected $kBackupFormatVersion).',
      );
    }

    final categories = _asMapList(decoded['categories']);
    final tags = _asMapList(decoded['tags']);
    final entries = _asMapList(decoded['entries']);
    final entryTags = _asMapList(decoded['entryTags']);

    var tagsWritten = 0;
    await _db.transaction(() async {
      // Defer FK enforcement to commit time so the natural insertion order and
      // category parent self-references can't cause transient FK violations.
      await _db.customStatement('PRAGMA defer_foreign_keys = ON');

      for (final m in categories) {
        await _db.into(_db.categories).insertOnConflictUpdate(
              CategoriesCompanion(
                id: Value(_reqStr(m, 'categories', 'id')),
                name: Value(_reqStr(m, 'categories', 'name')),
                parentId: Value(_optStr(m, 'categories', 'parentId')),
                icon: Value(_optStr(m, 'categories', 'icon')),
                createdAt: Value(_reqInt(m, 'categories', 'createdAt')),
              ),
            );
      }

      // Tags carry a UNIQUE(name) constraint in addition to their primary key.
      // `insertOnConflictUpdate` only upserts on the PK (id), so an incoming tag
      // whose name collides with an *existing* tag under a different id would
      // otherwise fall through to SQLite's ABORT and roll the whole import back.
      // To stay non-destructive we first reconcile by name: if the name already
      // exists under a different id, we reuse the existing id and remap any
      // entryTags that referenced the incoming id.
      final tagIdRemap = <String, String>{};
      for (final m in tags) {
        final incomingId = _reqStr(m, 'tags', 'id');
        final name = _reqStr(m, 'tags', 'name');

        final existingByName = await (_db.select(_db.tags)
              ..where((t) => t.name.equals(name)))
            .getSingleOrNull();

        if (existingByName != null && existingByName.id != incomingId) {
          // A different tag already owns this name; reuse it and remap.
          tagIdRemap[incomingId] = existingByName.id;
          continue;
        }

        await _db.into(_db.tags).insertOnConflictUpdate(
              TagsCompanion(
                id: Value(incomingId),
                name: Value(name),
                color: Value(_optStr(m, 'tags', 'color')),
                createdAt: Value(_reqInt(m, 'tags', 'createdAt')),
              ),
            );
        tagsWritten++;
      }

      for (final m in entries) {
        await _db.into(_db.entries).insertOnConflictUpdate(
              EntriesCompanion(
                id: Value(_reqStr(m, 'entries', 'id')),
                content: Value(_reqStr(m, 'entries', 'content')),
                source: Value(_optStr(m, 'entries', 'source')),
                categoryId: Value(_optStr(m, 'entries', 'categoryId')),
                createdAt: Value(_reqInt(m, 'entries', 'createdAt')),
                updatedAt: Value(_reqInt(m, 'entries', 'updatedAt')),
                lastViewedAt: Value(_optInt(m, 'entries', 'lastViewedAt')),
                viewCount: Value(_reqInt(m, 'entries', 'viewCount')),
                isFavorite: Value(_reqBool(m, 'entries', 'isFavorite')),
              ),
            );
      }

      for (final m in entryTags) {
        final tagId = _reqStr(m, 'entryTags', 'tagId');
        await _db.into(_db.entryTags).insertOnConflictUpdate(
              EntryTagsCompanion(
                entryId: Value(_reqStr(m, 'entryTags', 'entryId')),
                // Remap to the surviving tag id when the imported tag's name
                // collided with an existing one (see tag reconciliation above).
                tagId: Value(tagIdRemap[tagId] ?? tagId),
              ),
            );
      }
    });

    final summary = ImportSummary(
      categories: categories.length,
      // Reconciled tags (name already owned by a different id) are skipped, so
      // report the number of tag rows actually written, not the payload length.
      tags: tagsWritten,
      entries: entries.length,
      entryTags: entryTags.length,
    );

    AppLogger.info('Imported $summary', tag: _logTag);

    return summary;
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
