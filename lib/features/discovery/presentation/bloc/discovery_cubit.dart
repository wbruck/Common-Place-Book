import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../entries/data/repositories/entry_repository.dart';
import '../../../entries/domain/entities/entry_entity.dart';

// ============ States ============

sealed class DiscoveryState {
  const DiscoveryState();
}

class DiscoveryInitial extends DiscoveryState {
  const DiscoveryInitial();
}

class DiscoveryLoading extends DiscoveryState {
  const DiscoveryLoading();
}

class DiscoveryLoaded extends DiscoveryState {
  final EntryEntity entry;
  final List<EntryEntity> relatedEntries;
  final String? filterTagId;
  final List<EntryEntity> history;

  const DiscoveryLoaded({
    required this.entry,
    this.relatedEntries = const [],
    this.filterTagId,
    this.history = const [],
  });

  DiscoveryLoaded copyWith({
    EntryEntity? entry,
    List<EntryEntity>? relatedEntries,
    String? filterTagId,
    List<EntryEntity>? history,
  }) {
    return DiscoveryLoaded(
      entry: entry ?? this.entry,
      relatedEntries: relatedEntries ?? this.relatedEntries,
      filterTagId: filterTagId ?? this.filterTagId,
      history: history ?? this.history,
    );
  }
}

class DiscoveryEmpty extends DiscoveryState {
  final String? filterTagId;

  const DiscoveryEmpty({this.filterTagId});
}

class DiscoveryError extends DiscoveryState {
  final String message;

  const DiscoveryError(this.message);
}

// ============ Cubit ============

class DiscoveryCubit extends Cubit<DiscoveryState> {
  final EntryRepository _entryRepository;
  final List<EntryEntity> _history = [];
  String? _currentFilterTagId;

  DiscoveryCubit({
    required EntryRepository entryRepository,
  })  : _entryRepository = entryRepository,
        super(const DiscoveryInitial());

  Future<void> loadRandomEntry() async {
    emit(const DiscoveryLoading());

    try {
      EntryEntity? entry;

      if (_currentFilterTagId != null) {
        entry = await _entryRepository.getRandomEntryByTag(_currentFilterTagId!);
      } else {
        entry = await _entryRepository.getRandomEntry();
      }

      if (entry == null) {
        emit(DiscoveryEmpty(filterTagId: _currentFilterTagId));
        return;
      }

      // Add to history
      _history.insert(0, entry);
      if (_history.length > 10) {
        _history.removeLast();
      }

      // Load related entries
      final relatedEntries = await _entryRepository.getRelatedEntries(
        entry.id,
        limit: 3,
      );

      emit(DiscoveryLoaded(
        entry: entry,
        relatedEntries: relatedEntries,
        filterTagId: _currentFilterTagId,
        history: List.from(_history),
      ));
    } catch (e) {
      emit(DiscoveryError('Failed to load random entry: $e'));
    }
  }

  Future<void> shuffle() async {
    await loadRandomEntry();
  }

  void setTagFilter(String? tagId) {
    _currentFilterTagId = tagId;
    loadRandomEntry();
  }

  void clearFilter() {
    _currentFilterTagId = null;
    loadRandomEntry();
  }

  EntryEntity? getPreviousEntry() {
    if (_history.length <= 1) return null;
    return _history.length > 1 ? _history[1] : null;
  }

  Future<void> showEntry(EntryEntity entry) async {
    // Add current entry to history
    _history.insert(0, entry);
    if (_history.length > 10) {
      _history.removeLast();
    }

    // Load related entries for the new entry
    try {
      final relatedEntries = await _entryRepository.getRelatedEntries(
        entry.id,
        limit: 3,
      );

      emit(DiscoveryLoaded(
        entry: entry,
        relatedEntries: relatedEntries,
        filterTagId: _currentFilterTagId,
        history: List.from(_history),
      ));
    } catch (e) {
      emit(DiscoveryLoaded(
        entry: entry,
        filterTagId: _currentFilterTagId,
        history: List.from(_history),
      ));
    }
  }
}
