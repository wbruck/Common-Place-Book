import '../../../core/notifications/notification_service.dart';
import '../../entries/data/repositories/entry_repository.dart';
import '../../entries/domain/entities/entry_entity.dart';

/// Composes "format → (re)schedule / cancel" for per-entry reminders, keeping
/// the scheduled local notification in sync with an entry's `reminderAt`.
///
/// Mirrors [DailyReminderScheduler]: features program to this, and every method
/// no-ops when the platform can't deliver scheduled notifications.
class EntryReminderScheduler {
  EntryReminderScheduler({
    required EntryRepository entryRepository,
    required NotificationService notificationService,
  })  : _entryRepository = entryRepository,
        _notificationService = notificationService;

  /// Longest notification body before truncating on a word boundary.
  static const int _maxBodyLength = 180;

  final EntryRepository _entryRepository;
  final NotificationService _notificationService;

  /// Schedules (or cancels, when [EntryEntity.reminderAt] is null) the reminder
  /// notification for [entry].
  Future<void> schedule(EntryEntity entry) async {
    if (!_notificationService.isSupported) return;

    final reminderAt = entry.reminderAt;
    if (reminderAt == null) {
      await _notificationService.cancelEntryReminder(entry.id);
      return;
    }

    final source = entry.source;
    await _notificationService.scheduleEntryReminder(
      entryId: entry.id,
      dateTime: reminderAt,
      title: (source == null || source.trim().isEmpty)
          ? 'Reminder from your commonplace book'
          : '— ${source.trim()}',
      body: _truncate(entry.content),
      payload: entry.id,
    );
  }

  /// Cancels the pending reminder for [entryId], if any.
  Future<void> cancel(String entryId) async {
    if (!_notificationService.isSupported) return;
    await _notificationService.cancelEntryReminder(entryId);
  }

  /// Re-syncs every persisted reminder on startup: future reminders are
  /// (re)scheduled because Android drops pending alarms on reboot, while
  /// reminders whose time has already passed are cleared so a one-shot that
  /// already fired (or was missed) doesn't linger on the entry.
  Future<void> syncAll() async {
    if (!_notificationService.isSupported) return;

    final entries = await _entryRepository.getEntriesWithReminders();
    final now = DateTime.now();
    for (final entry in entries) {
      final reminderAt = entry.reminderAt;
      if (reminderAt == null) continue;
      if (reminderAt.isAfter(now)) {
        await schedule(entry);
      } else {
        await _entryRepository.setReminder(id: entry.id, reminderAt: null);
        await _notificationService.cancelEntryReminder(entry.id);
      }
    }
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
