import 'package:flutter/foundation.dart';

@immutable
class EntryEntity {
  final String id;
  final String content;
  final String? source;
  final String? categoryId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastViewedAt;
  final int viewCount;
  final bool isFavorite;
  final List<TagEntity> tags;

  const EntryEntity({
    required this.id,
    required this.content,
    this.source,
    this.categoryId,
    required this.createdAt,
    required this.updatedAt,
    this.lastViewedAt,
    this.viewCount = 0,
    this.isFavorite = false,
    this.tags = const [],
  });

  EntryEntity copyWith({
    String? id,
    String? content,
    String? source,
    String? categoryId,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastViewedAt,
    int? viewCount,
    bool? isFavorite,
    List<TagEntity>? tags,
  }) {
    return EntryEntity(
      id: id ?? this.id,
      content: content ?? this.content,
      source: source ?? this.source,
      categoryId: categoryId ?? this.categoryId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastViewedAt: lastViewedAt ?? this.lastViewedAt,
      viewCount: viewCount ?? this.viewCount,
      isFavorite: isFavorite ?? this.isFavorite,
      tags: tags ?? this.tags,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is EntryEntity &&
        other.id == id &&
        other.content == content &&
        other.source == source &&
        other.categoryId == categoryId &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.lastViewedAt == lastViewedAt &&
        other.viewCount == viewCount &&
        other.isFavorite == isFavorite &&
        listEquals(other.tags, tags);
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      content,
      source,
      categoryId,
      createdAt,
      updatedAt,
      lastViewedAt,
      viewCount,
      isFavorite,
      Object.hashAll(tags),
    );
  }

  @override
  String toString() {
    return 'EntryEntity(id: $id, content: ${content.substring(0, content.length > 50 ? 50 : content.length)}...)';
  }
}

@immutable
class TagEntity {
  final String id;
  final String name;
  final String? color;
  final DateTime createdAt;

  const TagEntity({
    required this.id,
    required this.name,
    this.color,
    required this.createdAt,
  });

  TagEntity copyWith({
    String? id,
    String? name,
    String? color,
    DateTime? createdAt,
  }) {
    return TagEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is TagEntity &&
        other.id == id &&
        other.name == name &&
        other.color == color &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(id, name, color, createdAt);

  @override
  String toString() => 'TagEntity(id: $id, name: $name)';
}

@immutable
class CategoryEntity {
  final String id;
  final String name;
  final String? parentId;
  final String? icon;
  final DateTime createdAt;

  const CategoryEntity({
    required this.id,
    required this.name,
    this.parentId,
    this.icon,
    required this.createdAt,
  });

  CategoryEntity copyWith({
    String? id,
    String? name,
    String? parentId,
    String? icon,
    DateTime? createdAt,
  }) {
    return CategoryEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
      icon: icon ?? this.icon,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is CategoryEntity &&
        other.id == id &&
        other.name == name &&
        other.parentId == parentId &&
        other.icon == icon &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(id, name, parentId, icon, createdAt);

  @override
  String toString() => 'CategoryEntity(id: $id, name: $name)';
}
