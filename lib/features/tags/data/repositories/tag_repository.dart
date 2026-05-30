import '../../../entries/domain/entities/entry_entity.dart';

class TagWithEntryCount {

  const TagWithEntryCount({
    required this.tag,
    required this.entryCount,
  });
  final TagEntity tag;
  final int entryCount;
}

abstract class TagRepository {
  // CRUD
  Future<TagEntity> createTag({
    required String name,
    String? color,
  });

  Future<void> updateTag({
    required String id,
    String? name,
    String? color,
  });

  Future<void> deleteTag(String id);

  Future<TagEntity?> getTagById(String id);

  Future<TagEntity?> getTagByName(String name);

  // Queries
  Future<List<TagEntity>> getAllTags();

  Future<List<TagWithEntryCount>> getTagsWithCounts();

  Future<List<TagEntity>> searchTags(String query);

  // Bulk operations
  Future<List<TagEntity>> getOrCreateTags(List<String> tagNames);

  // Streams
  Stream<List<TagEntity>> watchAllTags();
}
