import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/local_entry_repository.dart';
import '../../domain/entities/entry_entity.dart';

// ============ States ============

sealed class EntriesListState {
  const EntriesListState();
}

class EntriesListInitial extends EntriesListState {
  const EntriesListInitial();
}

class EntriesListLoading extends EntriesListState {
  const EntriesListLoading();
}

class EntriesListLoaded extends EntriesListState {
  final List<EntryEntity> entries;
  final String? filterTagId;
  final String? searchQuery;
  final int totalCount;

  const EntriesListLoaded({
    required this.entries,
    this.filterTagId,
    this.searchQuery,
    required this.totalCount,
  });

  EntriesListLoaded copyWith({
    List<EntryEntity>? entries,
    String? filterTagId,
    String? searchQuery,
    int? totalCount,
  }) {
    return EntriesListLoaded(
      entries: entries ?? this.entries,
      filterTagId: filterTagId ?? this.filterTagId,
      searchQuery: searchQuery ?? this.searchQuery,
      totalCount: totalCount ?? this.totalCount,
    );
  }
}

class EntriesListEmpty extends EntriesListState {
  final String? filterTagId;
  final String? searchQuery;

  const EntriesListEmpty({
    this.filterTagId,
    this.searchQuery,
  });
}

class EntriesListError extends EntriesListState {
  final String message;

  const EntriesListError(this.message);
}

// ============ Cubit ============

class EntriesListCubit extends Cubit<EntriesListState> {
  final LocalEntryRepository _entryRepository;

  String? _currentFilterTagId;
  String? _currentSearchQuery;

  EntriesListCubit({
    required LocalEntryRepository entryRepository,
  })  : _entryRepository = entryRepository,
        super(const EntriesListInitial());

  Future<void> loadEntries() async {
    emit(const EntriesListLoading());

    try {
      final entries = await _entryRepository.getAllEntries();
      final count = await _entryRepository.getEntryCount();

      if (entries.isEmpty) {
        emit(const EntriesListEmpty());
      } else {
        emit(EntriesListLoaded(
          entries: entries,
          totalCount: count,
        ));
      }
    } catch (e) {
      emit(EntriesListError('Failed to load entries: $e'));
    }
  }

  Future<void> filterByTag(String? tagId) async {
    _currentFilterTagId = tagId;
    _currentSearchQuery = null;

    emit(const EntriesListLoading());

    try {
      List<EntryEntity> entries;

      if (tagId == null) {
        entries = await _entryRepository.getAllEntries();
      } else {
        entries = await _entryRepository.getEntriesByTag(tagId);
      }

      final count = entries.length;

      if (entries.isEmpty) {
        emit(EntriesListEmpty(filterTagId: tagId));
      } else {
        emit(EntriesListLoaded(
          entries: entries,
          filterTagId: tagId,
          totalCount: count,
        ));
      }
    } catch (e) {
      emit(EntriesListError('Failed to filter entries: $e'));
    }
  }

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      await loadEntries();
      return;
    }

    _currentSearchQuery = query;
    _currentFilterTagId = null;

    emit(const EntriesListLoading());

    try {
      final entries = await _entryRepository.searchEntries(query);
      final count = entries.length;

      if (entries.isEmpty) {
        emit(EntriesListEmpty(searchQuery: query));
      } else {
        emit(EntriesListLoaded(
          entries: entries,
          searchQuery: query,
          totalCount: count,
        ));
      }
    } catch (e) {
      emit(EntriesListError('Failed to search entries: $e'));
    }
  }

  Future<void> refresh() async {
    if (_currentFilterTagId != null) {
      await filterByTag(_currentFilterTagId);
    } else if (_currentSearchQuery != null) {
      await search(_currentSearchQuery!);
    } else {
      await loadEntries();
    }
  }

  void clearFilters() {
    _currentFilterTagId = null;
    _currentSearchQuery = null;
    loadEntries();
  }
}
