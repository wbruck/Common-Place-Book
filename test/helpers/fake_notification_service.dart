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
}
