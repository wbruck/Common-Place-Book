import 'package:common_place_book/core/notifications/notification_service.dart';
import 'package:flutter/material.dart' show TimeOfDay;

/// Records a scheduled daily reminder for assertions.
class ScheduledReminder {
  const ScheduledReminder({
    required this.time,
    required this.title,
    required this.body,
    required this.payload,
  });

  final TimeOfDay time;
  final String title;
  final String body;
  final String payload;
}

/// Records a scheduled per-entry reminder for assertions.
class ScheduledEntryReminder {
  const ScheduledEntryReminder({
    required this.entryId,
    required this.dateTime,
    required this.title,
    required this.body,
    required this.payload,
  });

  final String entryId;
  final DateTime dateTime;
  final String title;
  final String body;
  final String payload;
}

/// In-memory [NotificationService] for tests: records schedule/cancel calls
/// and answers permission requests with a configurable [permissionGranted].
class FakeNotificationService implements NotificationService {
  FakeNotificationService({
    this.supported = true,
    this.permissionGranted = true,
  });

  final bool supported;
  bool permissionGranted;

  final List<ScheduledReminder> scheduled = [];
  int cancelCount = 0;
  int permissionRequestCount = 0;

  final List<ScheduledEntryReminder> scheduledEntryReminders = [];
  final List<String> canceledEntryReminders = [];

  @override
  bool get isSupported => supported;

  @override
  Future<void> init({
    required void Function(String payload) onNotificationTap,
  }) async {}

  @override
  Future<bool> requestPermissions() async {
    permissionRequestCount++;
    return permissionGranted;
  }

  @override
  Future<String?> getLaunchPayload() async => null;

  @override
  Future<void> scheduleDailyReminder({
    required TimeOfDay time,
    required String title,
    required String body,
    required String payload,
  }) async {
    scheduled.add(
      ScheduledReminder(
        time: time,
        title: title,
        body: body,
        payload: payload,
      ),
    );
  }

  @override
  Future<void> cancelDailyReminder() async {
    cancelCount++;
  }

  @override
  Future<void> scheduleEntryReminder({
    required String entryId,
    required DateTime dateTime,
    required String title,
    required String body,
    required String payload,
  }) async {
    scheduledEntryReminders.add(
      ScheduledEntryReminder(
        entryId: entryId,
        dateTime: dateTime,
        title: title,
        body: body,
        payload: payload,
      ),
    );
  }

  @override
  Future<void> cancelEntryReminder(String entryId) async {
    canceledEntryReminders.add(entryId);
  }
}
