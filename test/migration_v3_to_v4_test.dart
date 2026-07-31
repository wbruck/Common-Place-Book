// Migration test: v3 -> v4 adds the per-entry reminder column.
//
// Builds a real v3 SQLite database by hand (v3 schema: sync metadata on every
// table, entry_tags with a synthetic id + UNIQUE index, user_version = 3),
// then opens [AppDatabase] (schema v4) over the same file so drift runs the
// v3 -> v4 onUpgrade. Asserts existing data survives and the new reminder_at
// column is present and defaults to NULL.

import 'dart:io';

import 'package:common_place_book/core/database/database.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// Writes the v3 schema and seed rows directly with the sqlite3 C library so
/// the file genuinely starts at schema v3.
void _createV3Database(String path) {
  final db = sqlite3.sqlite3.open(path);
  try {
    db
      ..execute('''
        CREATE TABLE categories (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL,
          parent_id TEXT REFERENCES categories (id),
          icon TEXT,
          created_at INTEGER NOT NULL,
          user_id TEXT,
          deleted_at INTEGER
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
          is_favorite INTEGER NOT NULL DEFAULT 0,
          user_id TEXT,
          deleted_at INTEGER
        );
      ''')
      ..execute('''
        CREATE TABLE tags (
          id TEXT NOT NULL PRIMARY KEY,
          name TEXT NOT NULL UNIQUE,
          color TEXT,
          created_at INTEGER NOT NULL,
          user_id TEXT,
          deleted_at INTEGER
        );
      ''')
      // v3 entry_tags: synthetic id PK + sync columns + UNIQUE(entry_id, tag_id).
      ..execute('''
        CREATE TABLE entry_tags (
          id TEXT NOT NULL PRIMARY KEY,
          entry_id TEXT NOT NULL REFERENCES entries (id) ON DELETE CASCADE,
          tag_id TEXT NOT NULL REFERENCES tags (id) ON DELETE CASCADE,
          user_id TEXT,
          deleted_at INTEGER
        );
      ''')
      ..execute(
        'CREATE UNIQUE INDEX idx_entry_tags_entry_tag '
        'ON entry_tags (entry_id, tag_id);',
      )
      ..execute('''
        CREATE TABLE settings (
          key TEXT NOT NULL PRIMARY KEY,
          value TEXT NOT NULL
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
      ..userVersion = 3;
  } finally {
    db.dispose();
  }
}

void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('cpb_migration_v4_test');
    dbFile = File('${tempDir.path}/common_place_book_v3.db');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('v3 database upgrades to v4, adding reminder_at defaulting to NULL',
      () async {
    _createV3Database(dbFile.path);

    // Sanity check: the file really is at schema version 3 before drift opens.
    final raw = sqlite3.sqlite3.open(dbFile.path);
    expect(raw.userVersion, 3);
    raw.dispose();

    final db = AppDatabase.forTesting(NativeDatabase(dbFile));
    try {
      // The declared schema version drives the v3 -> v4 onUpgrade that the
      // first query below triggers.
      expect(db.schemaVersion, 4);

      final entries = await db.select(db.entries).get()
        ..sort((a, b) => a.id.compareTo(b.id));
      expect(entries.map((e) => e.id), ['e1', 'e2']);

      // Existing content survived and every row's reminder_at defaults to NULL.
      final e1 = entries.firstWhere((e) => e.id == 'e1');
      expect(e1.content, 'First quote');
      expect(e1.isFavorite, true);
      for (final entry in entries) {
        expect(entry.reminderAt, isNull);
      }
    } finally {
      await db.close();
    }
  });

  test('reminder_at is writable after the migration', () async {
    _createV3Database(dbFile.path);

    final db = AppDatabase.forTesting(NativeDatabase(dbFile));
    try {
      expect(db.schemaVersion, 4);

      await (db.update(db.entries)..where((e) => e.id.equals('e1'))).write(
        const EntriesCompanion(reminderAt: Value(5000)),
      );

      final e1 = await (db.select(db.entries)..where((e) => e.id.equals('e1')))
          .getSingle();
      expect(e1.reminderAt, 5000);
    } finally {
      await db.close();
    }
  });
}
