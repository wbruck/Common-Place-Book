// Tests for [DataTransferService] export/import round-trip, idempotency, and
// payload validation. Each test builds a fresh in-memory SQLite database via
// `AppDatabase.forTesting(NativeDatabase.memory())` so nothing touches the
// platform connection.

import 'dart:convert';

import 'package:common_place_book/core/database/database.dart';
import 'package:common_place_book/features/data_transfer/data/data_transfer_service.dart';
import 'package:common_place_book/features/data_transfer/data/local_backup_repository.dart';
import 'package:common_place_book/features/data_transfer/domain/backup_data.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Non-default, distinguishable timestamps so fidelity is observable.
const int kCategoryCreatedAt = 100000;
const int kTagACreatedAt = 111111;
const int kTagBCreatedAt = 222222;
const int kEntryCreatedAt = 333333;
const int kEntryUpdatedAt = 444444;
const int kEntryLastViewedAt = 555555;

/// Creates a fresh in-memory database.
AppDatabase newDb() => AppDatabase.forTesting(NativeDatabase.memory());

/// Seeds [db] with one custom category, two tags, an entry referencing the
/// category, and entry_tags linking the entry to both tags. Returns nothing;
/// callers read back through the service / DAOs.
Future<void> seedSampleData(AppDatabase db) async {
  await db.into(db.categories).insert(
        CategoriesCompanion.insert(
          id: 'cat-1',
          name: 'Stoicism',
          parentId: const Value('philosophy'),
          icon: const Value('temple'),
          createdAt: kCategoryCreatedAt,
        ),
      );

  await db.into(db.tags).insert(
        TagsCompanion.insert(
          id: 'tag-a',
          name: 'inspiration',
          color: const Value('#FF0000'),
          createdAt: kTagACreatedAt,
        ),
      );
  await db.into(db.tags).insert(
        TagsCompanion.insert(
          id: 'tag-b',
          name: 'memento-mori',
          createdAt: kTagBCreatedAt,
        ),
      );

  await db.into(db.entries).insert(
        EntriesCompanion.insert(
          id: 'entry-1',
          content: 'You have power over your mind, not outside events.',
          source: const Value('Marcus Aurelius, Meditations'),
          categoryId: const Value('cat-1'),
          createdAt: kEntryCreatedAt,
          updatedAt: kEntryUpdatedAt,
          lastViewedAt: const Value(kEntryLastViewedAt),
          viewCount: const Value(7),
          isFavorite: const Value(true),
        ),
      );

  await db.into(db.entryTags).insert(
        const EntryTagsCompanion(
          entryId: Value('entry-1'),
          tagId: Value('tag-a'),
        ),
      );
  await db.into(db.entryTags).insert(
        const EntryTagsCompanion(
          entryId: Value('entry-1'),
          tagId: Value('tag-b'),
        ),
      );
}

/// Builds a service backed by the given database's [LocalBackupRepository].
DataTransferService _service(AppDatabase db) =>
    DataTransferService(LocalBackupRepository(db));

/// Exports [db], unwrapping the [Result] (fails the test on error).
Future<String> _export(AppDatabase db) async =>
    (await _service(db).exportToJson()).getOrThrow();

/// Imports [json] into [db], unwrapping the [Result] (fails the test on error).
Future<ImportSummary> _import(AppDatabase db, String json) async =>
    (await _service(db).importFromJson(json)).getOrThrow();

void main() {
  group('DataTransferService', () {
    test('round-trip preserves all rows and field values exactly', () async {
      final db1 = newDb();
      final db2 = newDb();
      try {
        await seedSampleData(db1);

        final json = await _export(db1);
        final summary = await _import(db2, json);

        // Summary reflects what the export contained. db1 was created with the
        // 5 default seed categories, plus the 1 custom category we inserted, so
        // the export (and therefore the import summary) carries 6 categories.
        expect(summary.categories, 6);
        expect(summary.tags, 2);
        expect(summary.entries, 1);
        expect(summary.entryTags, 2);

        // ---- Categories: the custom one round-trips with its exact fields ----
        final cat = await (db2.select(db2.categories)
              ..where((t) => t.id.equals('cat-1')))
            .getSingle();
        expect(cat.name, 'Stoicism');
        expect(cat.parentId, 'philosophy');
        expect(cat.icon, 'temple');
        expect(cat.createdAt, kCategoryCreatedAt);

        // ---- Tags: both tags preserved exactly ----
        final tags = await (db2.select(db2.tags)
              ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
            .get();
        expect(tags.length, 2);
        final tagA = tags.firstWhere((t) => t.id == 'tag-a');
        expect(tagA.name, 'inspiration');
        expect(tagA.color, '#FF0000');
        expect(tagA.createdAt, kTagACreatedAt);
        final tagB = tags.firstWhere((t) => t.id == 'tag-b');
        expect(tagB.name, 'memento-mori');
        expect(tagB.color, isNull);
        expect(tagB.createdAt, kTagBCreatedAt);

        // ---- Entry: every field preserved EXACTLY ----
        final entries = await db2.select(db2.entries).get();
        expect(entries.length, 1);
        final entry = entries.single;
        expect(entry.id, 'entry-1');
        expect(
          entry.content,
          'You have power over your mind, not outside events.',
        );
        expect(entry.source, 'Marcus Aurelius, Meditations');
        expect(entry.categoryId, 'cat-1');
        expect(entry.createdAt, kEntryCreatedAt);
        expect(entry.updatedAt, kEntryUpdatedAt);
        expect(entry.lastViewedAt, kEntryLastViewedAt);
        expect(entry.viewCount, 7);
        expect(entry.isFavorite, isTrue);

        // ---- EntryTags: both relationships preserved ----
        final entryTags = await db2.select(db2.entryTags).get();
        expect(entryTags.length, 2);
        final pairs = entryTags.map((et) => '${et.entryId}:${et.tagId}').toSet();
        expect(pairs, {'entry-1:tag-a', 'entry-1:tag-b'});
      } finally {
        await db1.close();
        await db2.close();
      }
    });

    test('round-trip preserves null source/lastViewedAt and defaults',
        () async {
      final db1 = newDb();
      final db2 = newDb();
      try {
        await db1.into(db1.entries).insert(
              EntriesCompanion.insert(
                id: 'plain',
                content: 'A bare entry.',
                createdAt: 1,
                updatedAt: 2,
                // source, categoryId, lastViewedAt left null; viewCount &
                // isFavorite take their column defaults (0 / false).
              ),
            );

        final json = await _export(db1);
        await _import(db2, json);

        final entry = await db2.select(db2.entries).getSingle();
        expect(entry.id, 'plain');
        expect(entry.source, isNull);
        expect(entry.categoryId, isNull);
        expect(entry.lastViewedAt, isNull);
        expect(entry.viewCount, 0);
        expect(entry.isFavorite, isFalse);
      } finally {
        await db1.close();
        await db2.close();
      }
    });

    test('import is idempotent (re-importing does not duplicate rows)',
        () async {
      final db1 = newDb();
      final db2 = newDb();
      try {
        await seedSampleData(db1);
        final json = await _export(db1);

        await _import(db2, json);
        await _import(db2, json); // second import == upsert

        // Custom category present exactly once (plus the 5 default seeds).
        final categoryCount = (await db2.select(db2.categories).get()).length;
        expect(categoryCount, 6);
        expect((await db2.select(db2.tags).get()).length, 2);
        expect((await db2.select(db2.entries).get()).length, 1);
        expect((await db2.select(db2.entryTags).get()).length, 2);

        // Values are still intact after the second upsert.
        final entry = await db2.select(db2.entries).getSingle();
        expect(entry.viewCount, 7);
        expect(entry.isFavorite, isTrue);
        expect(entry.updatedAt, kEntryUpdatedAt);
      } finally {
        await db1.close();
        await db2.close();
      }
    });

    test('import updates existing rows on conflict (upsert semantics)',
        () async {
      final db = newDb();
      try {
        // Pre-existing entry with the same id but different values.
        await db.into(db.entries).insert(
              EntriesCompanion.insert(
                id: 'entry-1',
                content: 'OLD content',
                createdAt: 1,
                updatedAt: 1,
                viewCount: const Value(0),
                isFavorite: const Value(false),
              ),
            );

        final json = jsonEncode(<String, Object?>{
          'formatVersion': kBackupFormatVersion,
          'app': 'common_place_book',
          'appVersion': '1.0.0',
          'exportedAt': DateTime.now().toIso8601String(),
          'categories': const <Object?>[],
          'tags': const <Object?>[],
          'entries': <Object?>[
            <String, Object?>{
              'id': 'entry-1',
              'content': 'NEW content',
              'source': 'imported',
              'categoryId': null,
              'createdAt': 1,
              'updatedAt': 999,
              'lastViewedAt': null,
              'viewCount': 42,
              'isFavorite': true,
            },
          ],
          'entryTags': const <Object?>[],
        });

        await _import(db, json);

        final entry = await db.select(db.entries).getSingle();
        expect(entry.content, 'NEW content');
        expect(entry.source, 'imported');
        expect(entry.updatedAt, 999);
        expect(entry.viewCount, 42);
        expect(entry.isFavorite, isTrue);
      } finally {
        await db.close();
      }
    });

    test('importing an unsupported formatVersion throws FormatException',
        () async {
      final db = newDb();
      try {
        final json = jsonEncode(<String, Object?>{
          'formatVersion': 99,
          'app': 'common_place_book',
          'categories': const <Object?>[],
          'tags': const <Object?>[],
          'entries': const <Object?>[],
          'entryTags': const <Object?>[],
        });

        final result = await _service(db).importFromJson(json);
        expect(result.isFailure, isTrue);
        expect(result.errorOrNull?.kind, DataTransferErrorKind.invalidBackup);
      } finally {
        await db.close();
      }
    });

    test('importing a non-object top-level payload throws FormatException',
        () async {
      final db = newDb();
      try {
        final result =
            await _service(db).importFromJson('[1, 2, 3]');
        expect(result.isFailure, isTrue);
        expect(result.errorOrNull?.kind, DataTransferErrorKind.invalidBackup);
      } finally {
        await db.close();
      }
    });

    test('importing malformed JSON throws', () async {
      final db = newDb();
      try {
        final result =
            await _service(db).importFromJson('{not valid json');
        expect(result.isFailure, isTrue);
        expect(result.errorOrNull?.kind, DataTransferErrorKind.invalidBackup);
      } finally {
        await db.close();
      }
    });

    test(
        'importing a tag whose name collides with a different existing id '
        'does not abort the import and remaps entryTags', () async {
      final db1 = newDb();
      final db2 = newDb();
      try {
        await seedSampleData(db1);
        final json = await _export(db1);

        // Pre-seed db2 with a tag named 'inspiration' but under a DIFFERENT id
        // than the one in the backup ('tag-a'). The backup also contains an
        // entry tagged with 'tag-a'. The old PK-only upsert would hit
        // `UNIQUE constraint failed: tags.name` and roll the entire import back.
        await db2.into(db2.tags).insert(
              TagsCompanion.insert(
                id: 'existing-inspiration',
                name: 'inspiration',
                createdAt: 999,
              ),
            );

        final summary = await _import(db2, json);

        // The import succeeded for all tables (no rollback / data loss).
        expect(summary.entries, 1);
        // Only the non-colliding tag-b was written; tag-a was reconciled onto
        // the existing 'inspiration' row, so the count reflects rows written.
        expect(summary.tags, 1);
        expect(
          (await db2.select(db2.categories).get()).length,
          6,
        );

        // 'inspiration' still exists exactly once, under the pre-existing id;
        // its createdAt was NOT overwritten because we reused the existing row.
        final inspirationTags = await (db2.select(db2.tags)
              ..where((t) => t.name.equals('inspiration')))
            .get();
        expect(inspirationTags.length, 1);
        expect(inspirationTags.single.id, 'existing-inspiration');
        expect(inspirationTags.single.createdAt, 999);

        // The imported 'tag-a' id was NOT inserted (its name was reconciled).
        final tagA = await (db2.select(db2.tags)
              ..where((t) => t.id.equals('tag-a')))
            .getSingleOrNull();
        expect(tagA, isNull);

        // The entry's relationship to 'inspiration' was remapped onto the
        // surviving id, and the non-colliding tag-b relationship is intact.
        final pairs = (await db2.select(db2.entryTags).get())
            .map((et) => '${et.entryId}:${et.tagId}')
            .toSet();
        expect(pairs, {'entry-1:existing-inspiration', 'entry-1:tag-b'});
      } finally {
        await db1.close();
        await db2.close();
      }
    });

    test('import tolerates integral JSON doubles for int fields', () async {
      final db = newDb();
      try {
        final json = jsonEncode(<String, Object?>{
          'formatVersion': kBackupFormatVersion,
          'app': 'common_place_book',
          'categories': const <Object?>[],
          'tags': const <Object?>[],
          'entries': <Object?>[
            <String, Object?>{
              'id': 'dbl',
              'content': 'double timestamps',
              'source': null,
              'categoryId': null,
              // Numbers a hand-edited / third-party backup might serialize as
              // doubles.
              'createdAt': 333333.0,
              'updatedAt': 444444.0,
              'lastViewedAt': 555555.0,
              'viewCount': 7.0,
              'isFavorite': true,
            },
          ],
          'entryTags': const <Object?>[],
        });

        await _import(db, json);

        final entry = await db.select(db.entries).getSingle();
        expect(entry.createdAt, 333333);
        expect(entry.updatedAt, 444444);
        expect(entry.lastViewedAt, 555555);
        expect(entry.viewCount, 7);
      } finally {
        await db.close();
      }
    });

    test('import rejects a non-integral double for an int field', () async {
      final db = newDb();
      try {
        final json = jsonEncode(<String, Object?>{
          'formatVersion': kBackupFormatVersion,
          'app': 'common_place_book',
          'categories': const <Object?>[],
          'tags': const <Object?>[],
          'entries': <Object?>[
            <String, Object?>{
              'id': 'bad',
              'content': 'fractional timestamp',
              'createdAt': 333333.5,
              'updatedAt': 1,
              'viewCount': 0,
              'isFavorite': false,
            },
          ],
          'entryTags': const <Object?>[],
        });

        final result = await _service(db).importFromJson(json);
        expect(result.isFailure, isTrue);
        expect(result.errorOrNull?.kind, DataTransferErrorKind.invalidBackup);
      } finally {
        await db.close();
      }
    });

    test('import throws FormatException when entries[].content is missing',
        () async {
      final db = newDb();
      try {
        final json = jsonEncode(<String, Object?>{
          'formatVersion': kBackupFormatVersion,
          'app': 'common_place_book',
          'categories': const <Object?>[],
          'tags': const <Object?>[],
          'entries': <Object?>[
            <String, Object?>{
              'id': 'no-content',
              // 'content' deliberately omitted.
              'createdAt': 1,
              'updatedAt': 2,
              'viewCount': 0,
              'isFavorite': false,
            },
          ],
          'entryTags': const <Object?>[],
        });

        final result = await _service(db).importFromJson(json);
        expect(result.isFailure, isTrue);
        expect(result.errorOrNull?.kind, DataTransferErrorKind.invalidBackup);
      } finally {
        await db.close();
      }
    });

    test('import throws FormatException when categories[].createdAt is missing',
        () async {
      final db = newDb();
      try {
        final json = jsonEncode(<String, Object?>{
          'formatVersion': kBackupFormatVersion,
          'app': 'common_place_book',
          'categories': <Object?>[
            <String, Object?>{
              'id': 'cat-x',
              'name': 'No createdAt',
              'parentId': null,
              'icon': null,
              // 'createdAt' deliberately omitted.
            },
          ],
          'tags': const <Object?>[],
          'entries': const <Object?>[],
          'entryTags': const <Object?>[],
        });

        final result = await _service(db).importFromJson(json);
        expect(result.isFailure, isTrue);
        expect(result.errorOrNull?.kind, DataTransferErrorKind.invalidBackup);
      } finally {
        await db.close();
      }
    });

    test(
        'a FormatException mid-import rolls back so no partial rows are written',
        () async {
      final db = newDb();
      try {
        // First category is valid; second is missing createdAt. The whole
        // transaction must roll back, leaving only the default seeds.
        final json = jsonEncode(<String, Object?>{
          'formatVersion': kBackupFormatVersion,
          'app': 'common_place_book',
          'categories': <Object?>[
            <String, Object?>{
              'id': 'good',
              'name': 'Good',
              'parentId': null,
              'icon': null,
              'createdAt': 1,
            },
            <String, Object?>{
              'id': 'bad',
              'name': 'Bad',
              // missing createdAt
            },
          ],
          'tags': const <Object?>[],
          'entries': const <Object?>[],
          'entryTags': const <Object?>[],
        });

        final result = await _service(db).importFromJson(json);
        expect(result.isFailure, isTrue);
        expect(result.errorOrNull?.kind, DataTransferErrorKind.invalidBackup);

        final good = await (db.select(db.categories)
              ..where((t) => t.id.equals('good')))
            .getSingleOrNull();
        expect(good, isNull, reason: 'partial import must be rolled back');
      } finally {
        await db.close();
      }
    });

    test('exported JSON has the authoritative shape and counts', () async {
      final db = newDb();
      try {
        await seedSampleData(db);
        final json = await _export(db);
        final map = jsonDecode(json) as Map<String, Object?>;

        expect(map['formatVersion'], kBackupFormatVersion);
        expect(map['app'], 'common_place_book');
        expect(map['appVersion'], '1.0.0');
        expect(map['exportedAt'], isA<String>());

        final counts = map['counts']! as Map<String, Object?>;
        // 1 custom + 5 default seeds.
        expect(counts['categories'], 6);
        expect(counts['tags'], 2);
        expect(counts['entries'], 1);
        expect(counts['entryTags'], 2);

        // Relationships live in entryTags, not embedded in entries.
        final entries = map['entries']! as List<Object?>;
        final firstEntry = entries.single! as Map<String, Object?>;
        expect(firstEntry.containsKey('tagIds'), isFalse);
        expect(firstEntry.containsKey('tags'), isFalse);

        // Timestamps are raw ints, not strings.
        expect(firstEntry['createdAt'], isA<int>());
        expect(firstEntry['createdAt'], kEntryCreatedAt);

        final entryTags = map['entryTags']! as List<Object?>;
        expect(entryTags.length, 2);
        final firstPair = entryTags.first! as Map<String, Object?>;
        expect(firstPair.keys.toSet(), {'entryId', 'tagId'});
      } finally {
        await db.close();
      }
    });

    test('export stamps the database schemaVersion', () async {
      final db = newDb();
      try {
        final json = await _export(db);
        final map = jsonDecode(json) as Map<String, Object?>;
        expect(map['schemaVersion'], db.schemaVersion);
      } finally {
        await db.close();
      }
    });

    test('import rejects a backup created by a different app', () async {
      final db = newDb();
      try {
        final json = jsonEncode(<String, Object?>{
          'formatVersion': kBackupFormatVersion,
          'app': 'some_other_app',
          'categories': const <Object?>[],
          'tags': const <Object?>[],
          'entries': const <Object?>[],
          'entryTags': const <Object?>[],
        });
        final result = await _service(db).importFromJson(json);
        expect(result.isFailure, isTrue);
        expect(result.errorOrNull?.kind, DataTransferErrorKind.invalidBackup);
      } finally {
        await db.close();
      }
    });

    test('import rejects a backup from a newer schemaVersion', () async {
      final db = newDb();
      try {
        final json = jsonEncode(<String, Object?>{
          'formatVersion': kBackupFormatVersion,
          'app': 'common_place_book',
          'schemaVersion': db.schemaVersion + 1,
          'categories': const <Object?>[],
          'tags': const <Object?>[],
          'entries': const <Object?>[],
          'entryTags': const <Object?>[],
        });
        final result = await _service(db).importFromJson(json);
        expect(result.isFailure, isTrue);
        expect(result.errorOrNull?.kind, DataTransferErrorKind.invalidBackup);
      } finally {
        await db.close();
      }
    });

    test('import rejects a backup whose counts disagree with its arrays',
        () async {
      final db = newDb();
      try {
        final json = jsonEncode(<String, Object?>{
          'formatVersion': kBackupFormatVersion,
          'app': 'common_place_book',
          'counts': const <String, Object?>{
            'categories': 0,
            'tags': 5, // lies: the tags array below is empty
            'entries': 0,
            'entryTags': 0,
          },
          'categories': const <Object?>[],
          'tags': const <Object?>[],
          'entries': const <Object?>[],
          'entryTags': const <Object?>[],
        });
        final result = await _service(db).importFromJson(json);
        expect(result.isFailure, isTrue);
        expect(result.errorOrNull?.kind, DataTransferErrorKind.invalidBackup);
      } finally {
        await db.close();
      }
    });

    test('import rejects a dangling entry.categoryId without writing rows',
        () async {
      final db = newDb();
      try {
        final json = jsonEncode(<String, Object?>{
          'formatVersion': kBackupFormatVersion,
          'app': 'common_place_book',
          'categories': const <Object?>[],
          'tags': const <Object?>[],
          'entries': <Object?>[
            <String, Object?>{
              'id': 'orphan',
              'content': 'references a missing category',
              'categoryId': 'does-not-exist',
              'createdAt': 1,
              'updatedAt': 1,
              'viewCount': 0,
              'isFavorite': false,
            },
          ],
          'entryTags': const <Object?>[],
        });

        final result = await _service(db).importFromJson(json);
        expect(result.isFailure, isTrue);
        expect(result.errorOrNull?.kind, DataTransferErrorKind.invalidBackup);

        // The bad reference is rejected up front, before any write.
        final orphan = await (db.select(db.entries)
              ..where((t) => t.id.equals('orphan')))
            .getSingleOrNull();
        expect(orphan, isNull);
      } finally {
        await db.close();
      }
    });
  });
}
