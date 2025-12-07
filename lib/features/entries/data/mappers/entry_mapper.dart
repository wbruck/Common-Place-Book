import '../../../../core/database/database.dart';
import '../../domain/entities/entry_entity.dart';

class EntryMapper {
  EntryMapper._();

  static EntryEntity fromDatabase(Entry entry, {List<Tag> tags = const []}) {
    return EntryEntity(
      id: entry.id,
      content: entry.content,
      source: entry.source,
      categoryId: entry.categoryId,
      createdAt: DateTime.fromMillisecondsSinceEpoch(entry.createdAt),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(entry.updatedAt),
      lastViewedAt: entry.lastViewedAt != null
          ? DateTime.fromMillisecondsSinceEpoch(entry.lastViewedAt!)
          : null,
      viewCount: entry.viewCount,
      isFavorite: entry.isFavorite,
      tags: tags.map(TagMapper.fromDatabase).toList(),
    );
  }
}

class TagMapper {
  TagMapper._();

  static TagEntity fromDatabase(Tag tag) {
    return TagEntity(
      id: tag.id,
      name: tag.name,
      color: tag.color,
      createdAt: DateTime.fromMillisecondsSinceEpoch(tag.createdAt),
    );
  }
}

class CategoryMapper {
  CategoryMapper._();

  static CategoryEntity fromDatabase(Category category) {
    return CategoryEntity(
      id: category.id,
      name: category.name,
      parentId: category.parentId,
      icon: category.icon,
      createdAt: DateTime.fromMillisecondsSinceEpoch(category.createdAt),
    );
  }
}
