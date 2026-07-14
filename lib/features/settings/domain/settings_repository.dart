import 'package:flutter/material.dart' show ThemeMode;

/// Domain contract for reading and writing user settings.
///
/// Backed by the key/value `settings` table; features program to this
/// interface, never the concrete Drift implementation.
abstract class SettingsRepository {
  /// Loads the persisted theme mode, mapping a missing or unrecognised value
  /// to [ThemeMode.system].
  Future<ThemeMode> loadThemeMode();

  /// Persists the chosen theme mode.
  Future<void> saveThemeMode(ThemeMode mode);

  /// Whether the one-time welcome/intro has already been shown. Defaults to
  /// `false` (treat as a first visit) when nothing is persisted.
  Future<bool> hasSeenIntro();

  /// Marks the welcome/intro as shown so it does not appear on later launches.
  Future<void> markIntroSeen();

  /// Whether the daily reminder notification is enabled. Defaults to `false`
  /// when nothing is persisted.
  Future<bool> loadReminderEnabled();

  /// Persists whether the daily reminder notification is enabled.
  Future<void> saveReminderEnabled({required bool enabled});

  /// The daily reminder time as minutes since midnight, mapping a missing or
  /// unparseable value to 540 (9:00 AM).
  Future<int> loadReminderTimeMinutes();

  /// Persists the daily reminder time as minutes since midnight.
  Future<void> saveReminderTimeMinutes(int minutes);
}
