import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database.dart';

part 'entries_dao.g.dart';

@DriftAccessor(tables: [Entries, Tags, EntryTags])
class EntriesDao extends DatabaseAccessor<AppDatabase> with _$EntriesDaoMixin {
  EntriesDao(super.db);

  static const Uuid _uuid = Uuid();

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

    // Add tag associations.
    for (final tagId in tagIds) {
      await _linkTag(entryId: id, tagId: tagId);
    }

    return (select(entries)..where((e) => e.id.equals(id))).getSingle();
  }

  /// Creates (or revives) a live entry_tag link for the given pair.
  ///
  /// A previously soft-deleted link with the same (entryId, tagId) is revived
  /// in place rather than inserted again: the UNIQUE index on (entryId, tagId)
  /// covers soft-deleted rows too, so a plain insert would conflict. Reviving
  /// clears [deletedAt] (and keeps the existing synthetic id) so the link
  /// reappears in reads.
  Future<void> _linkTag({
    required String entryId,
    required String tagId,
  }) async {
    final existing = await (select(entryTags)
          ..where((et) => et.entryId.equals(entryId) & et.tagId.equals(tagId)))
        .getSingleOrNull();

    if (existing != null) {
      if (existing.deletedAt != null) {
        await (update(entryTags)..where((et) => et.id.equals(existing.id)))
            .write(const EntryTagsCompanion(deletedAt: Value(null)));
      }
      return;
    }

    await into(entryTags).insert(
      EntryTagsCompanion.insert(
        id: _uuid.v4(),
        entryId: entryId,
        tagId: tagId,
      ),
      mode: InsertMode.insertOrIgnore,
    );
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

    // Update tag associations if provided. Links are soft-deleted (never
    // physically removed) so the change can propagate to other devices.
    if (tagIds != null) {
      // Soft-delete any currently-live link whose tag is no longer in the set.
      final removeLinks = update(entryTags)
        ..where((et) => et.entryId.equals(id) & et.deletedAt.isNull());
      if (tagIds.isNotEmpty) {
        removeLinks.where((et) => et.tagId.isNotIn(tagIds));
      }
      await removeLinks.write(EntryTagsCompanion(deletedAt: Value(now)));

      // Add or revive a live link for every tag in the new set.
      for (final tagId in tagIds) {
        await _linkTag(entryId: id, tagId: tagId);
      }
    }
  }

  /// Soft-deletes an entry by setting its [Entries.deletedAt] tombstone (and
  /// bumping [Entries.updatedAt]) instead of physically removing the row, and
  /// soft-deletes the entry's links so they stop appearing in reads. The row
  /// is retained so the delete can be synced to other devices.
  Future<void> deleteEntry(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await (update(entryTags)
          ..where((et) => et.entryId.equals(id) & et.deletedAt.isNull()))
        .write(EntryTagsCompanion(deletedAt: Value(now)));

    await (update(entries)
          ..where((e) => e.id.equals(id) & e.deletedAt.isNull()))
        .write(
      EntriesCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  Future<Entry?> getEntryById(String id) {
    return (select(entries)
          ..where((e) => e.id.equals(id) & e.deletedAt.isNull()))
        .getSingleOrNull();
  }

  // ============ Query Operations ============

  Future<List<Entry>> getAllEntries({
    int? limit,
    int? offset,
    OrderingMode orderBy = OrderingMode.desc,
    String orderColumn = 'createdAt',
  }) {
    final query = select(entries)..where((e) => e.deletedAt.isNull());

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
      innerJoin(
        entryTags,
        entryTags.entryId.equalsExp(entries.id) & entryTags.deletedAt.isNull(),
      ),
    ])
      ..where(entryTags.tagId.equals(tagId) & entries.deletedAt.isNull())
      ..orderBy([OrderingTerm.desc(entries.createdAt)]);

    if (limit != null) {
      query.limit(limit, offset: offset);
    }

    return query.map((row) => row.readTable(entries)).get();
  }

  /// Returns entries that have a live link to ANY tag id in [tagIds] (OR
  /// filter), sorted by [Entries.createdAt] descending. Soft-deleted links and
  /// soft-deleted entries are excluded. Grouping de-duplicates entries that
  /// match more than one of the selected tags.
  Future<List<Entry>> getEntriesByAnyTags(List<String> tagIds) {
    final query = select(entries).join([
      innerJoin(
        entryTags,
        entryTags.entryId.equalsExp(entries.id) & entryTags.deletedAt.isNull(),
      ),
    ])
      ..where(entryTags.tagId.isIn(tagIds) & entries.deletedAt.isNull())
      ..groupBy([entries.id])
      ..orderBy([OrderingTerm.desc(entries.createdAt)]);

    return query.map((row) => row.readTable(entries)).get();
  }

  Future<List<Entry>> searchEntries(String searchTerm, {int? limit}) {
    final query = select(entries)
      ..where(
        (e) =>
            (e.content.contains(searchTerm) |
                e.source.contains(searchTerm)) &
            e.deletedAt.isNull(),
      )
      ..orderBy([(e) => OrderingTerm.desc(e.createdAt)]);

    if (limit != null) {
      query.limit(limit);
    }

    return query.get();
  }

  Future<Entry?> getRandomEntry() async {
    // Use SQL RANDOM() for efficient random selection without loading all entries
    final query = select(entries)
      ..where((e) => e.deletedAt.isNull())
      ..orderBy([(_) => OrderingTerm(expression: const CustomExpression('RANDOM()'))])
      ..limit(1);

    final results = await query.get();
    return results.isEmpty ? null : results.first;
  }

  Future<Entry?> getRandomEntryByTag(String tagId) async {
    // Use SQL RANDOM() for efficient random selection
    final query = select(entries).join([
      innerJoin(
        entryTags,
        entryTags.entryId.equalsExp(entries.id) & entryTags.deletedAt.isNull(),
      ),
    ])
      ..where(entryTags.tagId.equals(tagId) & entries.deletedAt.isNull())
      ..orderBy([OrderingTerm(expression: const CustomExpression('RANDOM()'))])
      ..limit(1);

    final results = await query.map((row) => row.readTable(entries)).get();
    return results.isEmpty ? null : results.first;
  }

  Future<List<Entry>> getRelatedEntries(String entryId, {int limit = 5}) async {
    // Get the tags for the current entry (live links only).
    final currentEntryTags = await (select(entryTags)
          ..where((et) => et.entryId.equals(entryId) & et.deletedAt.isNull()))
        .get();

    if (currentEntryTags.isEmpty) {
      return [];
    }

    final tagIds = currentEntryTags.map((et) => et.tagId).toList();

    // Find entries that share tags with the current entry. Soft-deleted links
    // and soft-deleted entries are excluded.
    final query = selectOnly(entries)
      ..addColumns([entries.id])
      ..join([
        innerJoin(
          entryTags,
          entryTags.entryId.equalsExp(entries.id) &
              entryTags.deletedAt.isNull(),
        ),
      ])
      ..where(
        entryTags.tagId.isIn(tagIds) &
            entries.id.equals(entryId).not() &
            entries.deletedAt.isNull(),
      )
      ..groupBy([entries.id])
      ..orderBy([OrderingTerm.desc(entryTags.tagId.count())])
      ..limit(limit);

    final relatedIds =
        await query.map((row) => row.read(entries.id)!).get();

    if (relatedIds.isEmpty) return [];

    return (select(entries)
          ..where((e) => e.id.isIn(relatedIds) & e.deletedAt.isNull()))
        .get();
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
    final query = selectOnly(entries)
      ..addColumns([count])
      ..where(entries.deletedAt.isNull());
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  Future<List<Entry>> getFavoriteEntries({int? limit}) {
    final query = select(entries)
      ..where((e) => e.isFavorite.equals(true) & e.deletedAt.isNull())
      ..orderBy([(e) => OrderingTerm.desc(e.createdAt)]);

    if (limit != null) {
      query.limit(limit);
    }

    return query.get();
  }

  // ============ Stream Queries ============

  Stream<List<Entry>> watchAllEntries() {
    return (select(entries)
          ..where((e) => e.deletedAt.isNull())
          ..orderBy([(e) => OrderingTerm.desc(e.createdAt)]))
        .watch();
  }

  Stream<Entry?> watchEntry(String id) {
    return (select(entries)
          ..where((e) => e.id.equals(id) & e.deletedAt.isNull()))
        .watchSingleOrNull();
  }

  // ============ Tag Helpers ============

  Future<List<Tag>> getTagsForEntry(String entryId) async {
    // Only live links to live tags.
    final query = select(tags).join([
      innerJoin(
        entryTags,
        entryTags.tagId.equalsExp(tags.id) & entryTags.deletedAt.isNull(),
      ),
    ])
      ..where(entryTags.entryId.equals(entryId) & tags.deletedAt.isNull());

    return query.map((row) => row.readTable(tags)).get();
  }
}
