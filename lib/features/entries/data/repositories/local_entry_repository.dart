import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/database.dart';
import '../../../../core/database/daos/entries_dao.dart';
import '../../domain/entities/entry_entity.dart';
import '../mappers/entry_mapper.dart';
import 'entry_repository.dart';

class LocalEntryRepository implements EntryRepository {
  final AppDatabase _database;
  final Uuid _uuid = const Uuid();

  late final EntriesDao _entriesDao;

  LocalEntryRepository({required AppDatabase database}) : _database = database {
    _entriesDao = EntriesDao(_database);
  }

  @override
  Future<EntryEntity> createEntry({
    required String content,
    String? source,
    String? categoryId,
    List<String> tagIds = const [],
  }) async {
    final id = _uuid.v4();
    final entry = await _entriesDao.createEntry(
      id: id,
      content: content,
      source: source,
      categoryId: categoryId,
      tagIds: tagIds,
    );
    final tags = await _entriesDao.getTagsForEntry(id);
    return EntryMapper.fromDatabase(entry, tags: tags);
  }

  @override
  Future<void> updateEntry({
    required String id,
    String? content,
    String? source,
    String? categoryId,
    List<String>? tagIds,
    bool? isFavorite,
  }) async {
    await _entriesDao.updateEntry(
      id: id,
      content: content,
      source: source,
      categoryId: categoryId,
      tagIds: tagIds,
      isFavorite: isFavorite,
    );
  }

  @override
  Future<void> deleteEntry(String id) async {
    await _entriesDao.deleteEntry(id);
  }

  @override
  Future<EntryEntity?> getEntryById(String id) async {
    final entry = await _entriesDao.getEntryById(id);
    if (entry == null) return null;

    final tags = await _entriesDao.getTagsForEntry(id);
    return EntryMapper.fromDatabase(entry, tags: tags);
  }

  @override
  Future<List<EntryEntity>> getAllEntries({
    int? limit,
    int? offset,
    String orderBy = 'createdAt',
    bool descending = true,
  }) async {
    final entries = await _entriesDao.getAllEntries(
      limit: limit,
      offset: offset,
      orderColumn: orderBy,
      orderBy: descending ? OrderingMode.desc : OrderingMode.asc,
    );

    return Future.wait(
      entries.map((entry) async {
        final tags = await _entriesDao.getTagsForEntry(entry.id);
        return EntryMapper.fromDatabase(entry, tags: tags);
      }),
    );
  }

  @override
  Future<List<EntryEntity>> getEntriesByTag(
    String tagId, {
    int? limit,
    int? offset,
  }) async {
    final entries = await _entriesDao.getEntriesByTag(
      tagId,
      limit: limit,
      offset: offset,
    );

    return Future.wait(
      entries.map((entry) async {
        final tags = await _entriesDao.getTagsForEntry(entry.id);
        return EntryMapper.fromDatabase(entry, tags: tags);
      }),
    );
  }

  @override
  Future<List<EntryEntity>> searchEntries(String query, {int? limit}) async {
    final entries = await _entriesDao.searchEntries(query, limit: limit);

    return Future.wait(
      entries.map((entry) async {
        final tags = await _entriesDao.getTagsForEntry(entry.id);
        return EntryMapper.fromDatabase(entry, tags: tags);
      }),
    );
  }

  @override
  Future<EntryEntity?> getRandomEntry() async {
    final entry = await _entriesDao.getRandomEntry();
    if (entry == null) return null;

    final tags = await _entriesDao.getTagsForEntry(entry.id);
    return EntryMapper.fromDatabase(entry, tags: tags);
  }

  @override
  Future<EntryEntity?> getRandomEntryByTag(String tagId) async {
    final entry = await _entriesDao.getRandomEntryByTag(tagId);
    if (entry == null) return null;

    final tags = await _entriesDao.getTagsForEntry(entry.id);
    return EntryMapper.fromDatabase(entry, tags: tags);
  }

  @override
  Future<List<EntryEntity>> getRelatedEntries(
    String entryId, {
    int limit = 5,
  }) async {
    final entries = await _entriesDao.getRelatedEntries(entryId, limit: limit);

    return Future.wait(
      entries.map((entry) async {
        final tags = await _entriesDao.getTagsForEntry(entry.id);
        return EntryMapper.fromDatabase(entry, tags: tags);
      }),
    );
  }

  @override
  Future<List<EntryEntity>> getFavoriteEntries({int? limit}) async {
    final entries = await _entriesDao.getFavoriteEntries(limit: limit);

    return Future.wait(
      entries.map((entry) async {
        final tags = await _entriesDao.getTagsForEntry(entry.id);
        return EntryMapper.fromDatabase(entry, tags: tags);
      }),
    );
  }

  @override
  Future<void> markAsViewed(String id) async {
    await _entriesDao.updateLastViewed(id);
  }

  @override
  Future<int> getEntryCount() async {
    return _entriesDao.getEntryCount();
  }

  @override
  Stream<List<EntryEntity>> watchAllEntries() {
    return _entriesDao.watchAllEntries().asyncMap((entries) async {
      return Future.wait(
        entries.map((entry) async {
          final tags = await _entriesDao.getTagsForEntry(entry.id);
          return EntryMapper.fromDatabase(entry, tags: tags);
        }),
      );
    });
  }

  @override
  Stream<EntryEntity?> watchEntry(String id) {
    return _entriesDao.watchEntry(id).asyncMap((entry) async {
      if (entry == null) return null;
      final tags = await _entriesDao.getTagsForEntry(entry.id);
      return EntryMapper.fromDatabase(entry, tags: tags);
    });
  }
}
