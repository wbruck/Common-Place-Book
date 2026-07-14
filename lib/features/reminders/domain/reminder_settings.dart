import 'package:flutter/material.dart' show TimeOfDay;

/// User configuration for the daily reminder notification.
class ReminderSettings {
  const ReminderSettings({
    required this.enabled,
    required this.time,
  });

  /// 9:00 AM — the default when the user has never picked a time.
  static const TimeOfDay defaultTime = TimeOfDay(hour: 9, minute: 0);

  final bool enabled;
  final TimeOfDay time;

  ReminderSettings copyWith({bool? enabled, TimeOfDay? time}) {
    return ReminderSettings(
      enabled: enabled ?? this.enabled,
      time: time ?? this.time,
    );
  }
}
