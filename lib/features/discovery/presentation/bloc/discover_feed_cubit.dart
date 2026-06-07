import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../entries/data/repositories/entry_repository.dart';
import '../../../entries/domain/entities/entry_entity.dart';

// ============ States ============

sealed class DiscoverFeedState {
  const DiscoverFeedState();
}

class DiscoverFeedInitial extends DiscoverFeedState {
  const DiscoverFeedInitial();
}

class DiscoverFeedLoading extends DiscoverFeedState {
  const DiscoverFeedLoading();
}

class DiscoverFeedLoaded extends DiscoverFeedState {

  const DiscoverFeedLoaded({
    required this.entries,
    required this.selectedTagIds,
  });
  final List<EntryEntity> entries;
  final Set<String> selectedTagIds;
}

class DiscoverFeedEmpty extends DiscoverFeedState {

  const DiscoverFeedEmpty({required this.selectedTagIds});
  final Set<String> selectedTagIds;
}

class DiscoverFeedError extends DiscoverFeedState {

  const DiscoverFeedError(this.message);
  final String message;
}

// ============ Cubit ============

class DiscoverFeedCubit extends Cubit<DiscoverFeedState> {

  DiscoverFeedCubit({
    required EntryRepository entryRepository,
    Set<String> initialTagIds = const {},
  })  : _entryRepository = entryRepository,
        _selectedTagIds = {...initialTagIds},
        super(const DiscoverFeedInitial());
  final EntryRepository _entryRepository;
  final Set<String> _selectedTagIds;

  Set<String> get selectedTagIds => Set.unmodifiable(_selectedTagIds);

  Future<void> load() async {
    emit(const DiscoverFeedLoading());

    try {
      final List<EntryEntity> entries;
      if (_selectedTagIds.isEmpty) {
        entries = await _entryRepository.getAllEntries(
          orderBy: 'createdAt',
          descending: true,
        );
      } else {
        entries = await _entryRepository.getEntriesByAnyTags(
          _selectedTagIds.toList(),
        );
      }

      if (entries.isEmpty) {
        emit(DiscoverFeedEmpty(selectedTagIds: {..._selectedTagIds}));
      } else {
        emit(DiscoverFeedLoaded(
          entries: entries,
          selectedTagIds: {..._selectedTagIds},
        ),);
      }
    } on Object catch (e) {
      emit(DiscoverFeedError('Failed to load feed: $e'));
    }
  }

  void toggleTag(String tagId) {
    if (_selectedTagIds.contains(tagId)) {
      _selectedTagIds.remove(tagId);
    } else {
      _selectedTagIds.add(tagId);
    }
    load();
  }

  void clearTags() {
    _selectedTagIds.clear();
    load();
  }
}
