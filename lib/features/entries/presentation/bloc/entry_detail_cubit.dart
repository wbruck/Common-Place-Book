import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/notifications/notification_service.dart';
import '../../../reminders/domain/entry_reminder_scheduler.dart';
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
    required NotificationService notificationService,
    required EntryReminderScheduler reminderScheduler,
    required this.entryId,
  })  : _entryRepository = entryRepository,
        _notificationService = notificationService,
        _reminderScheduler = reminderScheduler,
        super(const EntryDetailInitial());
  final EntryRepository _entryRepository;
  final NotificationService _notificationService;
  final EntryReminderScheduler _reminderScheduler;
  final String entryId;

  /// Whether this platform can deliver scheduled reminders. The UI hides the
  /// reminder affordances entirely when false (web/desktop).
  bool get remindersSupported => _notificationService.isSupported;

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

  /// Sets a one-time reminder for this entry at [dateTime].
  ///
  /// Requests notification permission first; when denied, nothing is persisted
  /// and this returns false so the UI can point the user at system settings.
  Future<bool> setReminder(DateTime dateTime) async {
    final currentState = state;
    if (currentState is! EntryDetailLoaded) return false;

    final granted = await _notificationService.requestPermissions();
    if (!granted) return false;

    try {
      await _entryRepository.setReminder(id: entryId, reminderAt: dateTime);
      final refreshed = await _entryRepository.getEntryById(entryId);
      if (refreshed != null) {
        await _reminderScheduler.schedule(refreshed);
        emit(currentState.copyWith(entry: refreshed));
      }
      return true;
    } on Object catch (e) {
      emit(EntryDetailError('Failed to set reminder: $e'));
      return false;
    }
  }

  /// Clears this entry's reminder and cancels its pending notification.
  Future<void> clearReminder() async {
    final currentState = state;
    if (currentState is! EntryDetailLoaded) return;

    try {
      await _entryRepository.setReminder(id: entryId, reminderAt: null);
      await _reminderScheduler.cancel(entryId);
      final refreshed = await _entryRepository.getEntryById(entryId);
      if (refreshed != null) {
        emit(currentState.copyWith(entry: refreshed));
      }
    } on Object catch (e) {
      emit(EntryDetailError('Failed to clear reminder: $e'));
    }
  }

  Future<void> deleteEntry() async {
    try {
      await _reminderScheduler.cancel(entryId);
      await _entryRepository.deleteEntry(entryId);
      emit(const EntryDetailNotFound());
    } on Object catch (e) {
      emit(EntryDetailError('Failed to delete entry: $e'));
    }
  }
}
