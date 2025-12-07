import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../entries/domain/entities/entry_entity.dart';
import '../../data/repositories/tag_repository.dart';

// ============ States ============

sealed class TagsState {
  const TagsState();
}

class TagsInitial extends TagsState {
  const TagsInitial();
}

class TagsLoading extends TagsState {
  const TagsLoading();
}

class TagsLoaded extends TagsState {
  final List<TagWithEntryCount> tagsWithCounts;

  const TagsLoaded({required this.tagsWithCounts});

  List<TagEntity> get tags => tagsWithCounts.map((t) => t.tag).toList();
}

class TagsEmpty extends TagsState {
  const TagsEmpty();
}

class TagsError extends TagsState {
  final String message;

  const TagsError(this.message);
}

// ============ Cubit ============

class TagsCubit extends Cubit<TagsState> {
  final TagRepository _tagRepository;

  TagsCubit({
    required TagRepository tagRepository,
  })  : _tagRepository = tagRepository,
        super(const TagsInitial());

  Future<void> loadTags() async {
    emit(const TagsLoading());

    try {
      final tagsWithCounts = await _tagRepository.getTagsWithCounts();

      if (tagsWithCounts.isEmpty) {
        emit(const TagsEmpty());
      } else {
        emit(TagsLoaded(tagsWithCounts: tagsWithCounts));
      }
    } catch (e) {
      emit(TagsError('Failed to load tags: $e'));
    }
  }

  Future<TagEntity?> createTag({
    required String name,
    String? color,
  }) async {
    try {
      // Check if tag already exists
      final existing = await _tagRepository.getTagByName(name);
      if (existing != null) {
        return existing;
      }

      final tag = await _tagRepository.createTag(
        name: name,
        color: color,
      );

      // Reload tags to update the list
      await loadTags();

      return tag;
    } catch (e) {
      emit(TagsError('Failed to create tag: $e'));
      return null;
    }
  }

  Future<void> updateTag({
    required String id,
    String? name,
    String? color,
  }) async {
    try {
      await _tagRepository.updateTag(
        id: id,
        name: name,
        color: color,
      );

      await loadTags();
    } catch (e) {
      emit(TagsError('Failed to update tag: $e'));
    }
  }

  Future<void> deleteTag(String id) async {
    try {
      await _tagRepository.deleteTag(id);
      await loadTags();
    } catch (e) {
      emit(TagsError('Failed to delete tag: $e'));
    }
  }

  Future<List<TagEntity>> getOrCreateTags(List<String> tagNames) async {
    try {
      final tags = await _tagRepository.getOrCreateTags(tagNames);
      await loadTags(); // Refresh the list
      return tags;
    } catch (e) {
      emit(TagsError('Failed to get or create tags: $e'));
      return [];
    }
  }

  Future<List<TagEntity>> searchTags(String query) async {
    try {
      return await _tagRepository.searchTags(query);
    } catch (e) {
      return [];
    }
  }
}
