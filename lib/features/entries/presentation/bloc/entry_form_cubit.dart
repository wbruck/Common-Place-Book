import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/entry_repository.dart';
import '../../domain/entities/entry_entity.dart';

// ============ States ============

sealed class EntryFormState {
  const EntryFormState();
}

class EntryFormInitial extends EntryFormState {
  const EntryFormInitial();
}

class EntryFormLoading extends EntryFormState {
  const EntryFormLoading();
}

class EntryFormReady extends EntryFormState {

  const EntryFormReady({
    this.content = '',
    this.source = '',
    this.categoryId,
    this.tagIds = const [],
    this.isEditing = false,
    this.existingEntryId,
  });
  final String content;
  final String source;
  final String? categoryId;
  final List<String> tagIds;
  final bool isEditing;
  final String? existingEntryId;

  EntryFormReady copyWith({
    String? content,
    String? source,
    String? categoryId,
    List<String>? tagIds,
    bool? isEditing,
    String? existingEntryId,
  }) {
    return EntryFormReady(
      content: content ?? this.content,
      source: source ?? this.source,
      categoryId: categoryId ?? this.categoryId,
      tagIds: tagIds ?? this.tagIds,
      isEditing: isEditing ?? this.isEditing,
      existingEntryId: existingEntryId ?? this.existingEntryId,
    );
  }

  bool get isValid => content.trim().isNotEmpty;

  bool get hasChanges =>
      content.trim().isNotEmpty ||
      source.trim().isNotEmpty ||
      tagIds.isNotEmpty ||
      categoryId != null;
}

class EntryFormSaving extends EntryFormState {
  const EntryFormSaving();
}

class EntryFormSaved extends EntryFormState {

  const EntryFormSaved(this.entry);
  final EntryEntity entry;
}

class EntryFormError extends EntryFormState {

  const EntryFormError(this.message);
  final String message;
}

// ============ Cubit ============

class EntryFormCubit extends Cubit<EntryFormState> {

  EntryFormCubit({
    required EntryRepository entryRepository,
  })  : _entryRepository = entryRepository,
        super(const EntryFormInitial());
  final EntryRepository _entryRepository;

  void initNewEntry({String initialContent = '', String initialSource = ''}) {
    emit(EntryFormReady(content: initialContent, source: initialSource));
  }

  Future<void> initEditEntry(String entryId) async {
    emit(const EntryFormLoading());

    try {
      final entry = await _entryRepository.getEntryById(entryId);
      if (entry == null) {
        emit(const EntryFormError('Entry not found'));
        return;
      }

      emit(EntryFormReady(
        content: entry.content,
        source: entry.source ?? '',
        categoryId: entry.categoryId,
        tagIds: entry.tags.map((t) => t.id).toList(),
        isEditing: true,
        existingEntryId: entryId,
      ),);
    } on Object catch (e) {
      emit(EntryFormError('Failed to load entry: $e'));
    }
  }

  void updateContent(String content) {
    final currentState = state;
    if (currentState is EntryFormReady) {
      emit(currentState.copyWith(content: content));
    }
  }

  void updateSource(String source) {
    final currentState = state;
    if (currentState is EntryFormReady) {
      emit(currentState.copyWith(source: source));
    }
  }

  void updateCategory(String? categoryId) {
    final currentState = state;
    if (currentState is EntryFormReady) {
      emit(currentState.copyWith(categoryId: categoryId));
    }
  }

  void updateTags(List<String> tagIds) {
    final currentState = state;
    if (currentState is EntryFormReady) {
      emit(currentState.copyWith(tagIds: tagIds));
    }
  }

  void addTag(String tagId) {
    final currentState = state;
    if (currentState is EntryFormReady) {
      if (!currentState.tagIds.contains(tagId)) {
        emit(currentState.copyWith(
          tagIds: [...currentState.tagIds, tagId],
        ),);
      }
    }
  }

  void removeTag(String tagId) {
    final currentState = state;
    if (currentState is EntryFormReady) {
      emit(currentState.copyWith(
        tagIds: currentState.tagIds.where((id) => id != tagId).toList(),
      ),);
    }
  }

  Future<void> save() async {
    final currentState = state;
    if (currentState is! EntryFormReady) return;

    if (!currentState.isValid) {
      emit(const EntryFormError('Content is required'));
      emit(currentState);
      return;
    }

    emit(const EntryFormSaving());

    try {
      EntryEntity entry;

      if (currentState.isEditing && currentState.existingEntryId != null) {
        // Update existing entry
        await _entryRepository.updateEntry(
          id: currentState.existingEntryId!,
          content: currentState.content.trim(),
          source: currentState.source.trim().isEmpty
              ? null
              : currentState.source.trim(),
          categoryId: currentState.categoryId,
          tagIds: currentState.tagIds,
        );
        entry = (await _entryRepository.getEntryById(
          currentState.existingEntryId!,
        ))!;
      } else {
        // Create new entry
        entry = await _entryRepository.createEntry(
          content: currentState.content.trim(),
          source: currentState.source.trim().isEmpty
              ? null
              : currentState.source.trim(),
          categoryId: currentState.categoryId,
          tagIds: currentState.tagIds,
        );
      }

      emit(EntryFormSaved(entry));
    } on Object catch (e) {
      emit(EntryFormError('Failed to save entry: $e'));
      emit(currentState);
    }
  }
}
