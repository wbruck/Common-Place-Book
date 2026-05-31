// Migration test for US-001: v2 -> v3 sync-metadata migration.
//
// Builds a *real* populated v2 SQLite database by hand (the exact v2 schema:
// composite-PK entry_tags, no userId/deletedAt columns, user_version = 2),
// then opens [AppDatabase] (schema v3) over that same file so drift runs the
// onUpgrade(v2 -> v3) migration. Asserts no data is lost: existing entries,
// tags and categories survive with userId/deletedAt = NULL, and every
// entry_tags row gets a non-null id while keeping its (entryId, tagId)
// pairing.

import 'dart:io';

import 'package:common_place_book/core/database/database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// Writes the v2 schema and seed rows directly with the sqlite3 C library,
/// bypassing drift entirely so the file genuinely starts at schema v2.
void _createV2Database(String path) {
  final db = sqlite3.sqlite3.open(path);
  try {
    db
      ..execute('''
        CREATE TABLE categories (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL,
          parent_id TEXT REFERENCES categories (id),
          icon TEXT,
          created_at INTEGER NOT NULL
        );
      ''')
      ..execute('''
        CREATE TABLE entries (
          id TEXT NOT NULL PRIMARY KEY,
          content TEXT NOT NULL,
          source TEXT,
          category_id TEXT REFERENCES categories (id),
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          last_viewed_at INTEGER,
          view_count INTEGER NOT NULL DEFAULT 0,
          is_favorite INTEGER NOT NULL DEFAULT 0
        );
      ''')
      ..execute('''
        CREATE TABLE tags (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL UNIQUE,
          color TEXT,
          created_at INTEGER NOT NULL
        );
      ''')
      // v2 entry_tags: composite primary key, no synthetic id, no sync columns.
      ..execute('''
        CREATE TABLE entry_tags (
          entry_id TEXT NOT NULL REFERENCES entries (id) ON DELETE CASCADE,
          tag_id TEXT NOT NULL REFERENCES tags (id) ON DELETE CASCADE,
          PRIMARY KEY (entry_id, tag_id)
        );
      ''')
      // Seed data.
      ..execute(
        'INSERT INTO categories (id, name, icon, created_at) '
        "VALUES ('philosophy', 'Philosophy', 'lightbulb', 1000);",
      )
      ..execute(
        'INSERT INTO entries '
        '(id, content, source, category_id, created_at, updated_at, '
        'view_count, is_favorite) VALUES '
        "('e1', 'First quote', 'Author A', 'philosophy', 1000, 1000, 3, 1), "
        "('e2', 'Second quote', NULL, NULL, 2000, 2000, 0, 0);",
      )
      ..execute(
        'INSERT INTO tags (id, name, color, created_at) VALUES '
        "('t1', 'wisdom', '#ff0000', 1000), "
        "('t2', 'life', NULL, 1000);",
      )
      ..execute(
        'INSERT INTO entry_tags (entry_id, tag_id) VALUES '
        "('e1', 't1'), ('e1', 't2'), ('e2', 't1');",
      )
      ..userVersion = 2;
  } finally {
    db.dispose();
  }
}

void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('cpb_migration_test');
    dbFile = File('${tempDir.path}/common_place_book_v2.db');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('v2 database upgrades to v3 with no data loss', () async {
    _createV2Database(dbFile.path);

    // Sanity check: the file really is at schema version 2 before drift opens.
    final raw = sqlite3.sqlite3.open(dbFile.path);
    expect(raw.userVersion, 2);
    raw.dispose();

    final db = AppDatabase.forTesting(NativeDatabase(dbFile));
    try {
      // The declared schema version drives the v2 -> v3 onUpgrade that the
      // first query below triggers.
      expect(db.schemaVersion, 3);

      // --- Entries survived, with new columns defaulting to NULL ---
      final entries = await db.select(db.entries).get()
        ..sort((a, b) => a.id.compareTo(b.id));
      expect(entries.map((e) => e.id), ['e1', 'e2']);

      final e1 = entries.firstWhere((e) => e.id == 'e1');
      expect(e1.content, 'First quote');
      expect(e1.source, 'Author A');
      expect(e1.categoryId, 'philosophy');
      expect(e1.viewCount, 3);
      expect(e1.isFavorite, true);
      expect(e1.userId, isNull);
      expect(e1.deletedAt, isNull);

      // --- Tags survived ---
      final tags = await db.select(db.tags).get()
        ..sort((a, b) => a.id.compareTo(b.id));
      expect(tags.map((t) => t.id), ['t1', 't2']);
      expect(tags.firstWhere((t) => t.id == 't1').color, '#ff0000');
      for (final tag in tags) {
        expect(tag.userId, isNull);
        expect(tag.deletedAt, isNull);
      }

      // --- Categories survived ---
      final categories = await db.select(db.categories).get();
      expect(categories.map((c) => c.id), contains('philosophy'));
      for (final category in categories) {
        expect(category.userId, isNull);
        expect(category.deletedAt, isNull);
      }

      // --- entry_tags: every row gets a non-null id and keeps its pairing ---
      final links = await db.select(db.entryTags).get();
      expect(links.length, 3);
      for (final link in links) {
        expect(link.id, isNotNull);
        expect(link.id, isNotEmpty);
        expect(link.userId, isNull);
        expect(link.deletedAt, isNull);
      }
      // Synthetic ids are unique.
      expect(links.map((l) => l.id).toSet().length, 3);
      // The original (entryId, tagId) pairs are exactly preserved.
      final pairs =
          links.map((l) => '${l.entryId}:${l.tagId}').toSet();
      expect(pairs, {'e1:t1', 'e1:t2', 'e2:t1'});
    } finally {
      await db.close();
    }
  });

  test('migrated entry_tags still enforces the (entryId, tagId) unique index',
      () async {
    _createV2Database(dbFile.path);

    final db = AppDatabase.forTesting(NativeDatabase(dbFile));
    try {
      expect(db.schemaVersion, 3);

      // Re-inserting an existing (entry_id, tag_id) pair must be rejected by
      // the UNIQUE index that replaced the old composite primary key.
      await expectLater(
        db.into(db.entryTags).insert(
              EntryTagsCompanion.insert(
                id: 'brand-new-id',
                entryId: 'e1',
                tagId: 't1',
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
    } finally {
      await db.close();
    }
  });

  test('foreign-key cascade still works after migration', () async {
    _createV2Database(dbFile.path);

    final db = AppDatabase.forTesting(NativeDatabase(dbFile));
    try {
      expect(db.schemaVersion, 3);

      // beforeOpen sets PRAGMA foreign_keys = ON; deleting an entry should
      // cascade to its entry_tags links.
      await (db.delete(db.entries)..where((e) => e.id.equals('e1'))).go();

      final remainingLinks = await db.select(db.entryTags).get();
      expect(remainingLinks.map((l) => l.entryId), everyElement('e2'));
      expect(remainingLinks.length, 1);
    } finally {
      await db.close();
    }
  });
}
