import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app/app.dart';
import 'app/router.dart';
import 'app/theme/app_theme.dart';
import 'core/app_info.dart';
import 'core/database/database.dart';
import 'core/database/database_provider.dart';
import 'core/database/tombstone_purge_service.dart';
import 'core/notifications/notification_service.dart';
import 'core/share/share_intent_service.dart';
import 'core/utils/app_logger.dart';
import 'features/entries/data/repositories/local_entry_repository.dart';
import 'features/reminders/domain/daily_reminder_scheduler.dart';
import 'features/reminders/domain/entry_reminder_scheduler.dart';
import 'features/reminders/domain/reminder_settings.dart';
import 'features/settings/data/local_settings_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Apply the brand status bar style before the first frame so screens
  // without an AppBar (which would re-apply it via the theme) still get it.
  SystemChrome.setSystemUIOverlayStyle(AppTheme.systemOverlayStyle);

  // Initialize the database
  final database = AppDatabase();
  DatabaseProvider.initialize(database);

  // Hard-delete stale soft-delete tombstones once per app session, off the UI
  // thread: this is fire-and-forget so it never blocks first paint, and any
  // failure is logged rather than crashing startup (US-003).
  unawaited(
    TombstonePurgeService(database).runOnce().catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      AppLogger.error(
        'Tombstone purge failed on startup',
        tag: 'Startup',
        error: error,
        stackTrace: stackTrace,
      );
      return 0;
    }),
  );

  // Resolve the app version once so it has a single source of truth.
  final packageInfo = await PackageInfo.fromPlatform();

  // Read the persisted theme mode before the first frame so the app paints in
  // the chosen theme immediately (no flash of the wrong theme on launch).
  final settingsRepository = LocalSettingsRepository(database);
  final initialThemeMode = await settingsRepository.loadThemeMode();

  // Resolve first-visit state up front so the welcome dialog decision is made
  // before the first frame, alongside the theme.
  final hasSeenIntro = await settingsRepository.hasSeenIntro();

  final entryRepository = LocalEntryRepository(database: database);

  // Daily reminder notifications (Android/iOS only; a no-op elsewhere).
  final notificationService = LocalNotificationService();
  var reminderSettings = const ReminderSettings(
    enabled: false,
    time: ReminderSettings.defaultTime,
  );
  if (notificationService.isSupported) {
    await notificationService.init(
      onNotificationTap: (payload) => appRouter.push('/entry/$payload'),
    );

    // When the app was cold-started by tapping the reminder, open that entry.
    final launchPayload = await notificationService.getLaunchPayload();
    if (launchPayload != null) {
      notificationLaunchLocation = '/entry/$launchPayload';
    }

    final reminderEnabled = await settingsRepository.loadReminderEnabled();
    final reminderMinutes =
        await settingsRepository.loadReminderTimeMinutes();
    reminderSettings = ReminderSettings(
      enabled: reminderEnabled,
      time: TimeOfDay(
        hour: reminderMinutes ~/ 60,
        minute: reminderMinutes % 60,
      ),
    );

    // Re-pick the reminder's quote on every launch (and cancel it when the
    // book is empty or the reminder is off). Fire-and-forget, like the
    // tombstone purge: it must never block first paint.
    unawaited(
      DailyReminderScheduler(
        entryRepository: entryRepository,
        notificationService: notificationService,
      )
          .reschedule(
        enabled: reminderSettings.enabled,
        time: reminderSettings.time,
      )
          .catchError((Object error, StackTrace stackTrace) {
        AppLogger.error(
          'Daily reminder reschedule failed on startup',
          tag: 'Startup',
          error: error,
          stackTrace: stackTrace,
        );
      }),
    );

    // Re-sync per-entry reminders: reschedule any still in the future (Android
    // drops pending alarms on reboot) and clear ones whose time has passed.
    // Fire-and-forget so it never blocks first paint.
    unawaited(
      EntryReminderScheduler(
        entryRepository: entryRepository,
        notificationService: notificationService,
      ).syncAll().catchError((Object error, StackTrace stackTrace) {
        AppLogger.error(
          'Entry reminder sync failed on startup',
          tag: 'Startup',
          error: error,
          stackTrace: stackTrace,
        );
      }),
    );
  }

  // Native Android share sheet (ACTION_SEND). A share can cold-start the app
  // (becomes the router's start location, opening the pre-filled new-entry
  // form) or arrive while it is already running (pushed onto the navigator).
  final shareIntentService = ShareIntentService();
  if (shareIntentService.isSupported) {
    final initialShare = await shareIntentService.getInitialShare();
    if (initialShare != null) {
      shareLaunchLocation = shareTargetLocation(initialShare);
    }
    shareIntentService.setOnShareReceived((params) {
      final location = shareTargetLocation(params);
      if (location != null) appRouter.push(location);
    });
  }

  runApp(
    CommonPlaceBookApp(
      appInfo: AppInfo(version: packageInfo.version),
      settingsRepository: settingsRepository,
      entryRepository: entryRepository,
      notificationService: notificationService,
      initialThemeMode: initialThemeMode,
      initialReminderSettings: reminderSettings,
      showIntroOnLaunch: !hasSeenIntro,
    ),
  );
}
