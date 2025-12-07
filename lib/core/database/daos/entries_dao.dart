import 'dart:math';

import 'package:drift/drift.dart';

import '../database.dart';

part 'entries_dao.g.dart';

@DriftAccessor(tables: [Entries, Tags, EntryTags])
class EntriesDao extends DatabaseAccessor<AppDatabase> with _$EntriesDaoMixin {
  EntriesDao(super.db);

  // ============ CRUD Operations ============

  Future<Entry> createEntry({
    required String id,
    required String content,
    String? source,
    String? categoryId,
    List<String> tagIds = const [],
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    final entry = EntriesCompanion.insert(
      id: id,
      content: content,
      source: Value(source),
      categoryId: Value(categoryId),
      createdAt: now,
      updatedAt: now,
    );

    await into(entries).insert(entry);

    // Add tag associations
    for (final tagId in tagIds) {
      await into(entryTags).insert(
        EntryTagsCompanion.insert(entryId: id, tagId: tagId),
        mode: InsertMode.insertOrIgnore,
      );
    }

    return (select(entries)..where((e) => e.id.equals(id))).getSingle();
  }

  Future<void> updateEntry({
    required String id,
    String? content,
    String? source,
    String? categoryId,
    List<String>? tagIds,
    bool? isFavorite,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await (update(entries)..where((e) => e.id.equals(id))).write(
      EntriesCompanion(
        content: content != null ? Value(content) : const Value.absent(),
        source: source != null ? Value(source) : const Value.absent(),
        categoryId: categoryId != null ? Value(categoryId) : const Value.absent(),
        isFavorite: isFavorite != null ? Value(isFavorite) : const Value.absent(),
        updatedAt: Value(now),
      ),
    );

    // Update tag associations if provided
    if (tagIds != null) {
      await (delete(entryTags)..where((et) => et.entryId.equals(id))).go();
      for (final tagId in tagIds) {
        await into(entryTags).insert(
          EntryTagsCompanion.insert(entryId: id, tagId: tagId),
          mode: InsertMode.insertOrIgnore,
        );
      }
    }
  }

  Future<void> deleteEntry(String id) async {
    await (delete(entryTags)..where((et) => et.entryId.equals(id))).go();
    await (delete(entries)..where((e) => e.id.equals(id))).go();
  }

  Future<Entry?> getEntryById(String id) {
    return (select(entries)..where((e) => e.id.equals(id))).getSingleOrNull();
  }

  // ============ Query Operations ============

  Future<List<Entry>> getAllEntries({
    int? limit,
    int? offset,
    OrderingMode orderBy = OrderingMode.desc,
    String orderColumn = 'createdAt',
  }) {
    final query = select(entries);

    switch (orderColumn) {
      case 'createdAt':
        query.orderBy([
          (e) => OrderingTerm(
                expression: e.createdAt,
                mode: orderBy,
              ),
        ]);
      case 'updatedAt':
        query.orderBy([
          (e) => OrderingTerm(
                expression: e.updatedAt,
                mode: orderBy,
              ),
        ]);
      case 'viewCount':
        query.orderBy([
          (e) => OrderingTerm(
                expression: e.viewCount,
                mode: orderBy,
              ),
        ]);
      case 'lastViewedAt':
        query.orderBy([
          (e) => OrderingTerm(
                expression: e.lastViewedAt,
                mode: orderBy,
              ),
        ]);
    }

    if (limit != null) {
      query.limit(limit, offset: offset);
    }

    return query.get();
  }

  Future<List<Entry>> getEntriesByTag(
    String tagId, {
    int? limit,
    int? offset,
  }) {
    final query = select(entries).join([
      innerJoin(entryTags, entryTags.entryId.equalsExp(entries.id)),
    ])
      ..where(entryTags.tagId.equals(tagId))
      ..orderBy([OrderingTerm.desc(entries.createdAt)]);

    if (limit != null) {
      query.limit(limit, offset: offset);
    }

    return query.map((row) => row.readTable(entries)).get();
  }

  Future<List<Entry>> searchEntries(String searchTerm, {int? limit}) {
    final query = select(entries)
      ..where((e) => e.content.contains(searchTerm) | e.source.contains(searchTerm))
      ..orderBy([(e) => OrderingTerm.desc(e.createdAt)]);

    if (limit != null) {
      query.limit(limit);
    }

    return query.get();
  }

  Future<Entry?> getRandomEntry() async {
    final allEntries = await (select(entries)).get();
    if (allEntries.isEmpty) return null;

    final random = Random();
    return allEntries[random.nextInt(allEntries.length)];
  }

  Future<Entry?> getRandomEntryByTag(String tagId) async {
    final tagEntries = await getEntriesByTag(tagId);
    if (tagEntries.isEmpty) return null;

    final random = Random();
    return tagEntries[random.nextInt(tagEntries.length)];
  }

  Future<List<Entry>> getRelatedEntries(String entryId, {int limit = 5}) async {
    // Get the tags for the current entry
    final currentEntryTags = await (select(entryTags)
          ..where((et) => et.entryId.equals(entryId)))
        .get();

    if (currentEntryTags.isEmpty) {
      return [];
    }

    final tagIds = currentEntryTags.map((et) => et.tagId).toList();

    // Find entries that share tags with the current entry
    final query = selectOnly(entries)
      ..addColumns([entries.id])
      ..join([
        innerJoin(entryTags, entryTags.entryId.equalsExp(entries.id)),
      ])
      ..where(entryTags.tagId.isIn(tagIds) & entries.id.equals(entryId).not())
      ..groupBy([entries.id])
      ..orderBy([OrderingTerm.desc(entryTags.tagId.count())])
      ..limit(limit);

    final relatedIds =
        await query.map((row) => row.read(entries.id)!).get();

    if (relatedIds.isEmpty) return [];

    return (select(entries)..where((e) => e.id.isIn(relatedIds))).get();
  }

  // ============ View Tracking ============

  Future<void> updateLastViewed(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final entry = await getEntryById(id);

    if (entry != null) {
      await (update(entries)..where((e) => e.id.equals(id))).write(
        EntriesCompanion(
          lastViewedAt: Value(now),
          viewCount: Value(entry.viewCount + 1),
        ),
      );
    }
  }

  // ============ Statistics ============

  Future<int> getEntryCount() async {
    final count = entries.id.count();
    final query = selectOnly(entries)..addColumns([count]);
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  Future<List<Entry>> getFavoriteEntries({int? limit}) {
    final query = select(entries)
      ..where((e) => e.isFavorite.equals(true))
      ..orderBy([(e) => OrderingTerm.desc(e.createdAt)]);

    if (limit != null) {
      query.limit(limit);
    }

    return query.get();
  }

  // ============ Stream Queries ============

  Stream<List<Entry>> watchAllEntries() {
    return (select(entries)..orderBy([(e) => OrderingTerm.desc(e.createdAt)]))
        .watch();
  }

  Stream<Entry?> watchEntry(String id) {
    return (select(entries)..where((e) => e.id.equals(id)))
        .watchSingleOrNull();
  }

  // ============ Tag Helpers ============

  Future<List<Tag>> getTagsForEntry(String entryId) async {
    final query = select(tags).join([
      innerJoin(entryTags, entryTags.tagId.equalsExp(tags.id)),
    ])
      ..where(entryTags.entryId.equals(entryId));

    return query.map((row) => row.readTable(tags)).get();
  }
}
