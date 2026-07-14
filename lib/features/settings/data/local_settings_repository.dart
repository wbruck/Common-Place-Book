import 'package:drift/drift.dart';
import 'package:flutter/material.dart' show ThemeMode;

import '../../../core/database/database.dart';
import '../domain/settings_repository.dart';

/// Drift-backed [SettingsRepository] over the key/value `settings` table.
///
/// The table accessors are already code-generated on [AppDatabase], so this
/// reads via `select` and writes via `insertOnConflictUpdate` (upsert) without
/// needing a dedicated DAO.
class LocalSettingsRepository implements SettingsRepository {
  LocalSettingsRepository(this._db);

  final AppDatabase _db;

  /// Stable key under which the theme mode is stored.
  static const String _themeModeKey = 'theme_mode';

  /// Stable key under which the "welcome shown" flag is stored.
  static const String _hasSeenIntroKey = 'has_seen_intro';

  /// Stable key under which the daily-reminder toggle is stored.
  static const String _reminderEnabledKey = 'reminder_enabled';

  /// Stable key under which the daily-reminder time (minutes since midnight)
  /// is stored.
  static const String _reminderTimeKey = 'reminder_time';

  /// 9:00 AM, the fallback when no reminder time is persisted.
  static const int _defaultReminderTimeMinutes = 9 * 60;

  @override
  Future<ThemeMode> loadThemeMode() async {
    final value = await _getValue(_themeModeKey);
    return _themeModeFromString(value);
  }

  @override
  Future<void> saveThemeMode(ThemeMode mode) async {
    await _setValue(_themeModeKey, _themeModeToString(mode));
  }

  @override
  Future<bool> hasSeenIntro() async {
    return await _getValue(_hasSeenIntroKey) == 'true';
  }

  @override
  Future<void> markIntroSeen() async {
    await _setValue(_hasSeenIntroKey, 'true');
  }

  @override
  Future<bool> loadReminderEnabled() async {
    return await _getValue(_reminderEnabledKey) == 'true';
  }

  @override
  Future<void> saveReminderEnabled({required bool enabled}) async {
    await _setValue(_reminderEnabledKey, enabled ? 'true' : 'false');
  }

  @override
  Future<int> loadReminderTimeMinutes() async {
    final value = await _getValue(_reminderTimeKey);
    final minutes = value == null ? null : int.tryParse(value);
    if (minutes == null || minutes < 0 || minutes >= 24 * 60) {
      return _defaultReminderTimeMinutes;
    }
    return minutes;
  }

  @override
  Future<void> saveReminderTimeMinutes(int minutes) async {
    await _setValue(_reminderTimeKey, minutes.toString());
  }

  Future<String?> _getValue(String key) async {
    final row = await (_db.select(_db.settings)
          ..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> _setValue(String key, String value) async {
    await _db.into(_db.settings).insertOnConflictUpdate(
          SettingsCompanion(key: Value(key), value: Value(value)),
        );
  }

  /// Maps a stored string to a [ThemeMode]; unknown/missing values fall back to
  /// [ThemeMode.system].
  static ThemeMode _themeModeFromString(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  static String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}
