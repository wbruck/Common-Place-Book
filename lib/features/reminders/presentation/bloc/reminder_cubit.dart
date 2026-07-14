import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/notifications/notification_service.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../settings/domain/settings_repository.dart';
import '../../domain/daily_reminder_scheduler.dart';
import '../../domain/reminder_settings.dart';

/// Holds the daily-reminder configuration (enabled + time) and keeps the
/// scheduled notification in sync with it.
///
/// Follows the [ThemeCubit] shape: seeded from persistence in `main`,
/// emit-first, persistence/scheduling failures logged rather than surfaced.
class ReminderCubit extends Cubit<ReminderSettings> {
  ReminderCubit({
    required SettingsRepository settingsRepository,
    required NotificationService notificationService,
    required DailyReminderScheduler scheduler,
    required ReminderSettings initialSettings,
  })  : _settingsRepository = settingsRepository,
        _notificationService = notificationService,
        _scheduler = scheduler,
        super(initialSettings);

  final SettingsRepository _settingsRepository;
  final NotificationService _notificationService;
  final DailyReminderScheduler _scheduler;

  /// Enables or disables the daily reminder. Enabling first requests
  /// notification permission; when denied, nothing is emitted or persisted
  /// and this returns false so the UI can point the user at system settings.
  Future<bool> setEnabled({required bool enabled}) async {
    if (enabled) {
      final granted = await _notificationService.requestPermissions();
      if (!granted) return false;
    }
    emit(state.copyWith(enabled: enabled));
    try {
      await _settingsRepository.saveReminderEnabled(enabled: enabled);
    } on Object catch (error, stackTrace) {
      AppLogger.error(
        'Failed to persist reminder toggle',
        tag: 'ReminderCubit',
        error: error,
        stackTrace: stackTrace,
      );
    }
    await _reschedule();
    return true;
  }

  /// Persists the new reminder [time] and, when the reminder is enabled,
  /// reschedules the pending notification for it.
  Future<void> setTime(TimeOfDay time) async {
    emit(state.copyWith(time: time));
    try {
      await _settingsRepository.saveReminderTimeMinutes(
        time.hour * 60 + time.minute,
      );
    } on Object catch (error, stackTrace) {
      AppLogger.error(
        'Failed to persist reminder time',
        tag: 'ReminderCubit',
        error: error,
        stackTrace: stackTrace,
      );
    }
    await _reschedule();
  }

  Future<void> _reschedule() async {
    try {
      await _scheduler.reschedule(enabled: state.enabled, time: state.time);
    } on Object catch (error, stackTrace) {
      AppLogger.error(
        'Failed to (re)schedule daily reminder',
        tag: 'ReminderCubit',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
