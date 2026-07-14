import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../utils/app_logger.dart';

/// Contract for the daily-reminder notifications.
///
/// Features program to this interface, never the concrete
/// [LocalNotificationService], so tests can substitute a fake and unsupported
/// platforms can no-op.
abstract class NotificationService {
  /// Whether scheduled local notifications work on this platform.
  /// Callers must check this before using any other member.
  bool get isSupported;

  /// Initializes the timezone database and the notifications plugin.
  /// [onNotificationTap] receives the notification payload (an entry id) when
  /// the user taps a notification while the app is running.
  Future<void> init({
    required void Function(String payload) onNotificationTap,
  });

  /// Prompts for notification permission (Android 13+ / iOS). Returns false
  /// when the user denied or the platform gave no answer.
  Future<bool> requestPermissions();

  /// Payload of the notification that launched the app from a terminated
  /// state, or null when the app was started normally.
  Future<String?> getLaunchPayload();

  /// Schedules the daily repeating reminder at [time], replacing any
  /// previously scheduled one.
  Future<void> scheduleDailyReminder({
    required TimeOfDay time,
    required String title,
    required String body,
    required String payload,
  });

  /// Cancels the pending daily reminder, if any.
  Future<void> cancelDailyReminder();
}

/// [NotificationService] backed by flutter_local_notifications.
/// Mobile-only: all methods no-op (or return negatively) off Android/iOS.
class LocalNotificationService implements NotificationService {
  LocalNotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// Fixed notification id: rescheduling replaces the pending request instead
  /// of stacking a new one (idempotent across launches and hot restarts).
  static const int _dailyReminderId = 1001;

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  bool get isSupported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  Future<void> init({
    required void Function(String payload) onNotificationTap,
  }) async {
    if (!isSupported) return;

    tz_data.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } on Object catch (error, stackTrace) {
      // tz.local falls back to UTC; the reminder still fires, just possibly
      // at the wrong wall-clock hour until the next successful launch.
      AppLogger.error(
        'Could not resolve local timezone',
        tag: 'Notifications',
        error: error,
        stackTrace: stackTrace,
      );
    }

    // All Darwin permission requests deferred: the user is prompted when they
    // enable the reminder in Settings, not at app start.
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          onNotificationTap(payload);
        }
      },
    );
  }

  @override
  Future<bool> requestPermissions() async {
    if (!isSupported) return false;
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      // Pre-Android 13 has no runtime permission; the plugin reports granted.
      return await android?.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        false;
  }

  @override
  Future<String?> getLaunchPayload() async {
    if (!isSupported) return null;
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    final payload = details.notificationResponse?.payload;
    return (payload == null || payload.isEmpty) ? null : payload;
  }

  @override
  Future<void> scheduleDailyReminder({
    required TimeOfDay time,
    required String title,
    required String body,
    required String payload,
  }) async {
    if (!isSupported) return;

    await _plugin.zonedSchedule(
      id: _dailyReminderId,
      title: title,
      body: body,
      payload: payload,
      scheduledDate: _nextInstanceOf(time),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder',
          'Daily reminder',
          channelDescription: 'A daily quote from your commonplace book',
          // Expandable so long quotes are readable in the shade.
          styleInformation: BigTextStyleInformation(body),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      // Inexact avoids the Android exact-alarm special permission; a daily
      // quote drifting by a few minutes is fine.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      // Repeat every day at this wall-clock time.
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  @override
  Future<void> cancelDailyReminder() async {
    if (!isSupported) return;
    await _plugin.cancel(id: _dailyReminderId);
  }

  /// Today at [time] in the local timezone, or tomorrow when that moment has
  /// already passed.
  tz.TZDateTime _nextInstanceOf(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
