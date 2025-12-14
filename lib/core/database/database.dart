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

  @override
  Set<Column> get primaryKey => {id};
}

class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().unique()();
  TextColumn get color => text().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class EntryTags extends Table {
  TextColumn get entryId =>
      text().references(Entries, #id, onDelete: KeyAction.cascade)();
  TextColumn get tagId =>
      text().references(Tags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {entryId, tagId};
}

class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get parentId => text().nullable().references(Categories, #id)();
  TextColumn get icon => text().nullable()();
  IntColumn get createdAt => integer()();

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

  @override
  int get schemaVersion => 2;

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
