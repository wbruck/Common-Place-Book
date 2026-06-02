import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/app_logger.dart';
import '../../domain/settings_repository.dart';

/// Holds the active [ThemeMode] (System / Light / Dark) for the app.
///
/// The state is just an enum, so a plain `Cubit<ThemeMode>` is sufficient (no
/// sealed-state hierarchy needed). [setThemeMode] persists the choice through
/// the [SettingsRepository] before emitting, so the selection survives restarts.
class ThemeCubit extends Cubit<ThemeMode> {
  /// Seeds the cubit with [initialMode] (resolved from persistence in `main`
  /// before `runApp`, avoiding a flash of the wrong theme).
  ThemeCubit({
    required SettingsRepository settingsRepository,
    ThemeMode initialMode = ThemeMode.system,
  })  : _settingsRepository = settingsRepository,
        super(initialMode);

  final SettingsRepository _settingsRepository;

  /// Emits [mode] immediately so the UI reflects the choice, then persists it.
  /// Emitting first means a persistence failure never blocks the in-session
  /// switch; such a failure is logged rather than swallowed. A no-op emit is
  /// skipped automatically by Cubit when the value is unchanged.
  Future<void> setThemeMode(ThemeMode mode) async {
    emit(mode);
    try {
      await _settingsRepository.saveThemeMode(mode);
    } on Object catch (error, stackTrace) {
      AppLogger.error(
        'Failed to persist theme mode',
        tag: 'ThemeCubit',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
