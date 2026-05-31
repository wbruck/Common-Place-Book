import 'package:drift/drift.dart';

import 'connection/connection.dart'
    if (dart.library.io) 'connection/native.dart'
    if (dart.library.html) 'connection/web.dart' as connection;

part 'database.g.dart';

// ============ Table Definitions ============

class Entries extends Table {
  TextColumn get id => text()();
  TextColumn get content => text()();
  TextColumn get source => text().nullable()();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get lastViewedAt => integer().nullable()();
  IntColumn get viewCount => integer().withDefault(const Constant(0))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();

  /// Owning user id once synced. NULL means "local-only, not yet synced".
  TextColumn get userId => text().nullable()();

  /// Soft-delete tombstone (epoch ms). NULL means the row is live.
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().unique()();
  TextColumn get color => text().nullable()();
  IntColumn get createdAt => integer()();

  /// Owning user id once synced. NULL means "local-only, not yet synced".
  TextColumn get userId => text().nullable()();

  /// Soft-delete tombstone (epoch ms). NULL means the row is live.
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(
  name: 'idx_entry_tags_entry_tag',
  columns: {#entryId, #tagId},
  unique: true,
)
class EntryTags extends Table {
  /// Synthetic single-column primary key. PowerSync requires every synced
  /// table to have a single text `id` PK, so the old composite PK on
  /// (entryId, tagId) is replaced with this id plus a UNIQUE index that
  /// preserves the original uniqueness constraint (see [AppDatabase]).
  TextColumn get id => text()();
  TextColumn get entryId =>
      text().references(Entries, #id, onDelete: KeyAction.cascade)();
  TextColumn get tagId =>
      text().references(Tags, #id, onDelete: KeyAction.cascade)();

  /// Owning user id once synced. NULL means "local-only, not yet synced".
  TextColumn get userId => text().nullable()();

  /// Soft-delete tombstone (epoch ms). NULL means the row is live.
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get parentId => text().nullable().references(Categories, #id)();
  TextColumn get icon => text().nullable()();
  IntColumn get createdAt => integer()();

  /// Owning user id once synced. NULL means "local-only, not yet synced".
  TextColumn get userId => text().nullable()();

  /// Soft-delete tombstone (epoch ms). NULL means the row is live.
  IntColumn get deletedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

// ============ Database Class ============

@DriftDatabase(tables: [Entries, Tags, EntryTags, Categories, Settings])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Creates a database backed by the given [executor]. Intended for tests,
  /// where an in-memory executor (e.g. `NativeDatabase.memory()`) is supplied
  /// instead of the platform connection.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

  static QueryExecutor _openConnection() {
    return connection.openConnection();
  }

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
        // Seed default categories
        await _seedDefaultCategories();
      },
      onUpgrade: (m, from, to) async {
        // Migration from v1 to v2: Added ON DELETE CASCADE to EntryTags
        // SQLite doesn't support ALTER TABLE for foreign keys, so we need to
        // recreate the table. For existing apps, this is handled by drift.
        if (from < 2) {
          // The cascade constraints are enforced on new databases.
          // For existing databases, the manual deletion in DAOs handles cleanup.
        }

        // Migration from v2 to v3: add sync metadata (userId, deletedAt) to
        // every syncable table and give EntryTags a synthetic single-column
        // text primary key (PowerSync requires one), preserving the old
        // (entryId, tagId) uniqueness via a UNIQUE index.
        if (from < 3) {
          // Plain ALTER TABLE ADD COLUMN works for the new nullable columns.
          await m.addColumn(entries, entries.userId);
          await m.addColumn(entries, entries.deletedAt);
          await m.addColumn(tags, tags.userId);
          await m.addColumn(tags, tags.deletedAt);
          await m.addColumn(categories, categories.userId);
          await m.addColumn(categories, categories.deletedAt);

          // SQLite cannot ALTER a primary key, so EntryTags must be rebuilt.
          // Foreign keys are toggled OFF for the rebuild (dropping/renaming a
          // table that participates in FK relationships would otherwise trip
          // integrity checks); beforeOpen re-enables them for the live
          // connection.
          await customStatement('PRAGMA foreign_keys = OFF');

          // 1. Move the old composite-PK table aside.
          await customStatement(
            'ALTER TABLE entry_tags RENAME TO _entry_tags_old',
          );

          // 2. Create the new table shape (id PK + sync columns), then the
          //    declared UNIQUE(entryId, tagId) index (createTable does not
          //    create indexes on its own).
          await m.createTable(entryTags);
          await m.createIndex(idxEntryTagsEntryTag);

          // 3. Copy existing rows, generating a unique id per row via SQLite's
          //    randomblob so every migrated link gets a non-null id while
          //    keeping its original (entry_id, tag_id) pairing.
          await customStatement(
            'INSERT INTO entry_tags (id, entry_id, tag_id, user_id, deleted_at) '
            'SELECT lower(hex(randomblob(16))), entry_id, tag_id, NULL, NULL '
            'FROM _entry_tags_old',
          );

          // 4. Drop the old table.
          await customStatement('DROP TABLE _entry_tags_old');

          await customStatement('PRAGMA foreign_keys = ON');
        }
      },
      beforeOpen: (details) async {
        // Enable foreign-key enforcement so the ON DELETE CASCADE constraints
        // on EntryTags are actually active (SQLite defaults this OFF per
        // connection). PRAGMA does not validate pre-existing rows, so this is
        // safe to turn on for existing databases.
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _seedDefaultCategories() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final defaultCategories = [
      CategoriesCompanion.insert(
        id: 'philosophy',
        name: 'Philosophy',
        icon: const Value('lightbulb'),
        createdAt: now,
      ),
      CategoriesCompanion.insert(
        id: 'literature',
        name: 'Literature',
        icon: const Value('book'),
        createdAt: now,
      ),
      CategoriesCompanion.insert(
        id: 'science',
        name: 'Science',
        icon: const Value('science'),
        createdAt: now,
      ),
      CategoriesCompanion.insert(
        id: 'personal',
        name: 'Personal',
        icon: const Value('person'),
        createdAt: now,
      ),
      CategoriesCompanion.insert(
        id: 'wisdom',
        name: 'Wisdom',
        icon: const Value('star'),
        createdAt: now,
      ),
    ];

    for (final category in defaultCategories) {
      await into(categories).insert(category, mode: InsertMode.insertOrIgnore);
    }
  }
}
