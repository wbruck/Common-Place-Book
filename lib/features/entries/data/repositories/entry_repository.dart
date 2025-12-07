import '../../domain/entities/entry_entity.dart';

abstract class EntryRepository {
  // CRUD
  Future<EntryEntity> createEntry({
    required String content,
    String? source,
    String? categoryId,
    List<String> tagIds,
  });

  Future<void> updateEntry({
    required String id,
    String? content,
    String? source,
    String? categoryId,
    List<String>? tagIds,
    bool? isFavorite,
  });

  Future<void> deleteEntry(String id);

  Future<EntryEntity?> getEntryById(String id);

  // Queries
  Future<List<EntryEntity>> getAllEntries({
    int? limit,
    int? offset,
    String orderBy,
    bool descending,
  });

  Future<List<EntryEntity>> getEntriesByTag(
    String tagId, {
    int? limit,
    int? offset,
  });

  Future<List<EntryEntity>> searchEntries(String query, {int? limit});

  Future<EntryEntity?> getRandomEntry();

  Future<EntryEntity?> getRandomEntryByTag(String tagId);

  Future<List<EntryEntity>> getRelatedEntries(String entryId, {int limit});

  Future<List<EntryEntity>> getFavoriteEntries({int? limit});

  // View tracking
  Future<void> markAsViewed(String id);

  // Statistics
  Future<int> getEntryCount();

  // Streams
  Stream<List<EntryEntity>> watchAllEntries();

  Stream<EntryEntity?> watchEntry(String id);
}
