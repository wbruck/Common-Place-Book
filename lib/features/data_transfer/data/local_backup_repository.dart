import 'package:drift/drift.dart';

import '../../../core/database/daos/categories_dao.dart';
import '../../../core/database/daos/entries_dao.dart';
import '../../../core/database/daos/tags_dao.dart';
import '../../../core/database/database.dart';
import '../domain/backup_data.dart';
import '../domain/backup_repository.dart';

/// Drift-backed [BackupRepository]. Reads through the existing DAOs and writes
/// raw upserts inside a single transaction, preserving ids/timestamps.
class LocalBackupRepository implements BackupRepository {
  LocalBackupRepository(this._db)
      : _entriesDao = EntriesDao(_db),
        _tagsDao = TagsDao(_db),
        _categoriesDao = CategoriesDao(_db);

  final AppDatabase _db;
  final EntriesDao _entriesDao;
  final TagsDao _tagsDao;
  final CategoriesDao _categoriesDao;

  @override
  int get schemaVersion => _db.schemaVersion;

  @override
  Future<BackupData> readAll() async {
    final categories = await _categoriesDao.getAllCategories();
    final tags = await _tagsDao.getAllTags();
    final entries = await _entriesDao.getAllEntries();
    // There is no DAO listing for the junction table, so read it directly.
    final entryTags = await _db.select(_db.entryTags).get();

    return BackupData(
      schemaVersion: _db.schemaVersion,
      categories: [
        for (final c in categories)
          BackupCategory(
            id: c.id,
            name: c.name,
            parentId: c.parentId,
            icon: c.icon,
            createdAt: c.createdAt,
          ),
      ],
      tags: [
        for (final t in tags)
          BackupTag(
            id: t.id,
            name: t.name,
            color: t.color,
            createdAt: t.createdAt,
          ),
      ],
      entries: [
        for (final e in entries)
          BackupEntry(
            id: e.id,
            content: e.content,
            source: e.source,
            categoryId: e.categoryId,
            createdAt: e.createdAt,
            updatedAt: e.updatedAt,
            lastViewedAt: e.lastViewedAt,
            viewCount: e.viewCount,
            isFavorite: e.isFavorite,
          ),
      ],
      entryTags: [
        for (final et in entryTags)
          BackupEntryTag(entryId: et.entryId, tagId: et.tagId),
      ],
    );
  }

  @override
  Future<ImportSummary> importMerge(BackupData data) async {
    // Prefetch existing rows once (this also removes the per-tag N+1 lookup the
    // previous implementation did inside the loop).
    final existingTags = await _tagsDao.getAllTags();
    final existingCategories = await _categoriesDao.getAllCategories();
    final existingEntries = await _entriesDao.getAllEntries();

    // Reconcile tags by their UNIQUE name: when the name already belongs to a
    // different id, reuse the existing row (keeping its local metadata) and
    // remap any entry_tags that referenced the incoming id.
    final existingIdByName = {for (final t in existingTags) t.name: t.id};
    final tagIdRemap = <String, String>{};
    final tagsToWrite = <BackupTag>[];
    final survivingTagIds = {for (final t in existingTags) t.id};
    for (final t in data.tags) {
      final existingId = existingIdByName[t.name];
      if (existingId != null && existingId != t.id) {
        tagIdRemap[t.id] = existingId;
      } else {
        tagsToWrite.add(t);
        survivingTagIds.add(t.id);
      }
    }

    // Validate referential integrity up front so a dangling reference fails with
    // a precise message rather than an opaque COMMIT-time SQLite error.
    final categoryIds = <String>{
      for (final c in existingCategories) c.id,
      for (final c in data.categories) c.id,
    };
    final entryIds = <String>{
      for (final e in existingEntries) e.id,
      for (final e in data.entries) e.id,
    };
    for (final c in data.categories) {
      final parentId = c.parentId;
      if (parentId != null && !categoryIds.contains(parentId)) {
        throw FormatException(
          'Invalid backup: category "${c.id}" has parentId "$parentId" that is '
          'not present in the backup or the app.',
        );
      }
    }
    for (final e in data.entries) {
      final categoryId = e.categoryId;
      if (categoryId != null && !categoryIds.contains(categoryId)) {
        throw FormatException(
          'Invalid backup: entry "${e.id}" references categoryId "$categoryId" '
          'that is not present in the backup or the app.',
        );
      }
    }
    for (final et in data.entryTags) {
      if (!entryIds.contains(et.entryId)) {
        throw FormatException(
          'Invalid backup: an entryTag references entryId "${et.entryId}" that '
          'is not present in the backup or the app.',
        );
      }
      final resolvedTagId = tagIdRemap[et.tagId] ?? et.tagId;
      if (!survivingTagIds.contains(resolvedTagId)) {
        throw FormatException(
          'Invalid backup: an entryTag references tagId "${et.tagId}" that is '
          'not present in the backup or the app.',
        );
      }
    }

    await _db.transaction(() async {
      // Defer FK enforcement to commit so insertion order and category
      // self-references can't cause transient violations.
      await _db.customStatement('PRAGMA defer_foreign_keys = ON');

      for (final c in data.categories) {
        await _db.into(_db.categories).insertOnConflictUpdate(
              CategoriesCompanion(
                id: Value(c.id),
                name: Value(c.name),
                parentId: Value(c.parentId),
                icon: Value(c.icon),
                createdAt: Value(c.createdAt),
              ),
            );
      }
      for (final t in tagsToWrite) {
        await _db.into(_db.tags).insertOnConflictUpdate(
              TagsCompanion(
                id: Value(t.id),
                name: Value(t.name),
                color: Value(t.color),
                createdAt: Value(t.createdAt),
              ),
            );
      }
      for (final e in data.entries) {
        await _db.into(_db.entries).insertOnConflictUpdate(
              EntriesCompanion(
                id: Value(e.id),
                content: Value(e.content),
                source: Value(e.source),
                categoryId: Value(e.categoryId),
                createdAt: Value(e.createdAt),
                updatedAt: Value(e.updatedAt),
                lastViewedAt: Value(e.lastViewedAt),
                viewCount: Value(e.viewCount),
                isFavorite: Value(e.isFavorite),
              ),
            );
      }
      for (final et in data.entryTags) {
        await _db.into(_db.entryTags).insertOnConflictUpdate(
              EntryTagsCompanion(
                entryId: Value(et.entryId),
                tagId: Value(tagIdRemap[et.tagId] ?? et.tagId),
              ),
            );
      }
    });

    return ImportSummary(
      categories: data.categories.length,
      tags: tagsToWrite.length,
      entries: data.entries.length,
      entryTags: data.entryTags.length,
    );
  }
}
