import 'package:flutter/material.dart' show TimeOfDay;

import '../../../core/notifications/notification_service.dart';
import '../../entries/data/repositories/entry_repository.dart';

/// Composes "pick a random entry → format → (re)schedule" for the daily
/// reminder. Shared by [ReminderCubit] (settings changes) and app startup
/// (rotates the quote on every launch).
class DailyReminderScheduler {
  DailyReminderScheduler({
    required EntryRepository entryRepository,
    required NotificationService notificationService,
  })  : _entryRepository = entryRepository,
        _notificationService = notificationService;

  /// Longest notification body before truncating on a word boundary.
  static const int _maxBodyLength = 180;

  final EntryRepository _entryRepository;
  final NotificationService _notificationService;

  /// Reschedules the reminder with a freshly picked random entry, or cancels
  /// it when [enabled] is false or the book is empty (an empty book gets no
  /// nag notification — and this same path cleans up a stale reminder after
  /// the last entry is deleted).
  Future<void> reschedule({
    required bool enabled,
    required TimeOfDay time,
  }) async {
    if (!_notificationService.isSupported) return;

    if (!enabled) {
      await _notificationService.cancelDailyReminder();
      return;
    }

    final entry = await _entryRepository.getRandomEntry();
    if (entry == null) {
      await _notificationService.cancelDailyReminder();
      return;
    }

    final source = entry.source;
    await _notificationService.scheduleDailyReminder(
      time: time,
      title: (source == null || source.trim().isEmpty)
          ? 'From your commonplace book'
          : '— ${source.trim()}',
      body: _truncate(entry.content),
      payload: entry.id,
    );
  }

  static String _truncate(String text) {
    final collapsed = text.trim();
    if (collapsed.length <= _maxBodyLength) return collapsed;
    final cut = collapsed.substring(0, _maxBodyLength);
    final lastSpace = cut.lastIndexOf(' ');
    final head = lastSpace > 0 ? cut.substring(0, lastSpace) : cut;
    return '$head…';
  }
}
