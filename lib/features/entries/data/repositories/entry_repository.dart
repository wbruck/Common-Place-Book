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

  /// Sets or clears (when [reminderAt] is null) the one-time reminder on an
  /// entry.
  Future<void> setReminder({required String id, required DateTime? reminderAt});

  /// All live entries that currently have a reminder set.
  Future<List<EntryEntity>> getEntriesWithReminders();

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

  Future<List<EntryEntity>> getEntriesByAnyTags(List<String> tagIds);

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
