import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/entry_repository.dart';
import '../../domain/entities/entry_entity.dart';

// ============ States ============

sealed class EntryDetailState {
  const EntryDetailState();
}

class EntryDetailInitial extends EntryDetailState {
  const EntryDetailInitial();
}

class EntryDetailLoading extends EntryDetailState {
  const EntryDetailLoading();
}

class EntryDetailLoaded extends EntryDetailState {

  const EntryDetailLoaded({
    required this.entry,
    this.relatedEntries = const [],
  });
  final EntryEntity entry;
  final List<EntryEntity> relatedEntries;

  EntryDetailLoaded copyWith({
    EntryEntity? entry,
    List<EntryEntity>? relatedEntries,
  }) {
    return EntryDetailLoaded(
      entry: entry ?? this.entry,
      relatedEntries: relatedEntries ?? this.relatedEntries,
    );
  }
}

class EntryDetailNotFound extends EntryDetailState {
  const EntryDetailNotFound();
}

class EntryDetailError extends EntryDetailState {

  const EntryDetailError(this.message);
  final String message;
}

// ============ Cubit ============

class EntryDetailCubit extends Cubit<EntryDetailState> {

  EntryDetailCubit({
    required EntryRepository entryRepository,
    required this.entryId,
  })  : _entryRepository = entryRepository,
        super(const EntryDetailInitial());
  final EntryRepository _entryRepository;
  final String entryId;

  Future<void> loadEntry() async {
    emit(const EntryDetailLoading());

    try {
      final entry = await _entryRepository.getEntryById(entryId);

      if (entry == null) {
        emit(const EntryDetailNotFound());
        return;
      }

      // Mark as viewed
      await _entryRepository.markAsViewed(entryId);

      // Load related entries
      final relatedEntries = await _entryRepository.getRelatedEntries(
        entryId,
        limit: 5,
      );

      // Reload entry to get updated view count
      final updatedEntry = await _entryRepository.getEntryById(entryId);

      emit(EntryDetailLoaded(
        entry: updatedEntry ?? entry,
        relatedEntries: relatedEntries,
      ),);
    } on Object catch (e) {
      emit(EntryDetailError('Failed to load entry: $e'));
    }
  }

  Future<void> toggleFavorite() async {
    final currentState = state;
    if (currentState is! EntryDetailLoaded) return;

    try {
      final newFavoriteStatus = !currentState.entry.isFavorite;
      await _entryRepository.updateEntry(
        id: entryId,
        isFavorite: newFavoriteStatus,
      );

      emit(currentState.copyWith(
        entry: currentState.entry.copyWith(isFavorite: newFavoriteStatus),
      ),);
    } on Object catch (e) {
      emit(EntryDetailError('Failed to update favorite status: $e'));
    }
  }

  Future<void> deleteEntry() async {
    try {
      await _entryRepository.deleteEntry(entryId);
      emit(const EntryDetailNotFound());
    } on Object catch (e) {
      emit(EntryDetailError('Failed to delete entry: $e'));
    }
  }
}
