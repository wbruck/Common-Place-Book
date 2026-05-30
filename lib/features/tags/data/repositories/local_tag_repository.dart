import 'package:uuid/uuid.dart';

import '../../../../core/database/daos/tags_dao.dart';
import '../../../../core/database/database.dart';
import '../../../entries/data/mappers/entry_mapper.dart';
import '../../../entries/domain/entities/entry_entity.dart';
import 'tag_repository.dart';

class LocalTagRepository implements TagRepository {

  LocalTagRepository({required AppDatabase database}) : _database = database {
    _tagsDao = TagsDao(_database);
  }
  final AppDatabase _database;
  final Uuid _uuid = const Uuid();

  late final TagsDao _tagsDao;

  @override
  Future<TagEntity> createTag({
    required String name,
    String? color,
  }) async {
    final id = _uuid.v4();
    final tag = await _tagsDao.createTag(
      id: id,
      name: name,
      color: color,
    );
    return TagMapper.fromDatabase(tag);
  }

  @override
  Future<void> updateTag({
    required String id,
    String? name,
    String? color,
  }) async {
    await _tagsDao.updateTag(
      id: id,
      name: name,
      color: color,
    );
  }

  @override
  Future<void> deleteTag(String id) async {
    await _tagsDao.deleteTag(id);
  }

  @override
  Future<TagEntity?> getTagById(String id) async {
    final tag = await _tagsDao.getTagById(id);
    if (tag == null) return null;
    return TagMapper.fromDatabase(tag);
  }

  @override
  Future<TagEntity?> getTagByName(String name) async {
    final tag = await _tagsDao.getTagByName(name);
    if (tag == null) return null;
    return TagMapper.fromDatabase(tag);
  }

  @override
  Future<List<TagEntity>> getAllTags() async {
    final tags = await _tagsDao.getAllTags();
    return tags.map(TagMapper.fromDatabase).toList();
  }

  @override
  Future<List<TagWithEntryCount>> getTagsWithCounts() async {
    final tagsWithCounts = await _tagsDao.getTagsWithEntryCounts();
    return tagsWithCounts
        .map(
          (twc) => TagWithEntryCount(
            tag: TagMapper.fromDatabase(twc.tag),
            entryCount: twc.entryCount,
          ),
        )
        .toList();
  }

  @override
  Future<List<TagEntity>> searchTags(String query) async {
    final tags = await _tagsDao.searchTags(query);
    return tags.map(TagMapper.fromDatabase).toList();
  }

  @override
  Future<List<TagEntity>> getOrCreateTags(List<String> tagNames) async {
    final tags = await _tagsDao.getOrCreateTags(tagNames);
    return tags.map(TagMapper.fromDatabase).toList();
  }

  @override
  Stream<List<TagEntity>> watchAllTags() {
    return _tagsDao.watchAllTags().map(
          (tags) => tags.map(TagMapper.fromDatabase).toList(),
        );
  }
}
