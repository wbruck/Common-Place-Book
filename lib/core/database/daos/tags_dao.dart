import 'package:drift/drift.dart';

import '../database.dart';

part 'tags_dao.g.dart';

class TagWithCount {

  const TagWithCount({
    required this.tag,
    required this.entryCount,
  });
  final Tag tag;
  final int entryCount;
}

@DriftAccessor(tables: [Tags, EntryTags])
class TagsDao extends DatabaseAccessor<AppDatabase> with _$TagsDaoMixin {
  TagsDao(super.db);

  // ============ CRUD Operations ============

  Future<Tag> createTag({
    required String id,
    required String name,
    String? color,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    final tag = TagsCompanion.insert(
      id: id,
      name: name,
      color: Value(color),
      createdAt: now,
    );

    await into(tags).insert(tag);

    return (select(tags)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<void> updateTag({
    required String id,
    String? name,
    String? color,
  }) async {
    await (update(tags)..where((t) => t.id.equals(id))).write(
      TagsCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        color: color != null ? Value(color) : const Value.absent(),
      ),
    );
  }

  Future<void> deleteTag(String id) async {
    // Remove all entry associations first
    await (delete(entryTags)..where((et) => et.tagId.equals(id))).go();
    // Then delete the tag
    await (delete(tags)..where((t) => t.id.equals(id))).go();
  }

  Future<Tag?> getTagById(String id) {
    return (select(tags)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<Tag?> getTagByName(String name) {
    return (select(tags)..where((t) => t.name.equals(name))).getSingleOrNull();
  }

  // ============ Query Operations ============

  Future<List<Tag>> getAllTags() {
    return (select(tags)..orderBy([(t) => OrderingTerm.asc(t.name)])).get();
  }

  Future<List<TagWithCount>> getAllTagsWithCounts() async {
    final query = select(tags).join([
      leftOuterJoin(entryTags, entryTags.tagId.equalsExp(tags.id)),
    ])
      ..groupBy([tags.id])
      ..orderBy([OrderingTerm.asc(tags.name)]);

    final results = await query.get();

    return results.map((row) {
      final tag = row.readTable(tags);
      // Count non-null entry associations
      final entryId = row.readTableOrNull(entryTags)?.entryId;
      return TagWithCount(
        tag: tag,
        entryCount: entryId != null ? 1 : 0,
      );
    }).toList();
  }

  Future<List<TagWithCount>> getTagsWithEntryCounts() async {
    // This is a more accurate count query
    final tagsList = await getAllTags();
    final results = <TagWithCount>[];

    for (final tag in tagsList) {
      final count = await _getEntryCountForTag(tag.id);
      results.add(TagWithCount(tag: tag, entryCount: count));
    }

    // Sort by entry count descending, then by name
    results.sort((a, b) {
      final countCompare = b.entryCount.compareTo(a.entryCount);
      if (countCompare != 0) return countCompare;
      return a.tag.name.compareTo(b.tag.name);
    });

    return results;
  }

  Future<int> _getEntryCountForTag(String tagId) async {
    final count = entryTags.entryId.count();
    final query = selectOnly(entryTags)
      ..addColumns([count])
      ..where(entryTags.tagId.equals(tagId));
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  Future<List<Tag>> searchTags(String searchTerm) {
    return (select(tags)
          ..where((t) => t.name.contains(searchTerm))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  // ============ Stream Queries ============

  Stream<List<Tag>> watchAllTags() {
    return (select(tags)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();
  }

  // ============ Bulk Operations ============

  Future<List<Tag>> getOrCreateTags(List<String> tagNames) async {
    final results = <Tag>[];

    for (final name in tagNames) {
      var tag = await getTagByName(name);
      if (tag == null) {
        final id = name.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '-');
        tag = await createTag(id: id, name: name);
      }
      results.add(tag);
    }

    return results;
  }
}
