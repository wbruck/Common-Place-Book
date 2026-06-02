// Tests for theme selection persistence (Goal A):
//   - LocalSettingsRepository round-trips the theme mode (save -> load) via the
//     key/value `settings` table.
//   - ThemeCubit seeds from the persisted value and setThemeMode persists +
//     emits the new mode.
//
// Runs against an in-memory database via
// `AppDatabase.forTesting(NativeDatabase.memory())` so nothing touches the
// platform connection.

import 'package:common_place_book/core/database/database.dart';
import 'package:common_place_book/features/settings/data/local_settings_repository.dart';
import 'package:common_place_book/features/settings/domain/settings_repository.dart';
import 'package:common_place_book/features/settings/presentation/bloc/theme_cubit.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late SettingsRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = LocalSettingsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('LocalSettingsRepository theme mode', () {
    test('defaults to system when nothing is persisted', () async {
      expect(await repository.loadThemeMode(), ThemeMode.system);
    });

    test('round-trips each theme mode (save -> load)', () async {
      for (final mode in ThemeMode.values) {
        await repository.saveThemeMode(mode);
        expect(await repository.loadThemeMode(), mode);
      }
    });

    test('saving overwrites the previous value (upsert, no duplicate rows)',
        () async {
      await repository.saveThemeMode(ThemeMode.dark);
      await repository.saveThemeMode(ThemeMode.light);

      expect(await repository.loadThemeMode(), ThemeMode.light);

      // The key/value table holds exactly one row for the theme key.
      final rows = await db.select(db.settings).get();
      expect(rows.length, 1);
    });
  });

  group('ThemeCubit', () {
    test('starts at the seeded initial mode', () {
      final cubit = ThemeCubit(
        settingsRepository: repository,
        initialMode: ThemeMode.dark,
      );
      addTearDown(cubit.close);

      expect(cubit.state, ThemeMode.dark);
    });

    test('setThemeMode persists and emits the new mode', () async {
      final cubit = ThemeCubit(settingsRepository: repository);
      addTearDown(cubit.close);

      final emitted = expectLater(cubit.stream, emits(ThemeMode.dark));

      await cubit.setThemeMode(ThemeMode.dark);
      await emitted;

      expect(cubit.state, ThemeMode.dark);
      // The choice is durably persisted, so a fresh load sees it.
      expect(await repository.loadThemeMode(), ThemeMode.dark);
    });

    test('a fresh cubit seeded from persistence reflects the saved mode',
        () async {
      await repository.saveThemeMode(ThemeMode.light);

      final cubit = ThemeCubit(
        settingsRepository: repository,
        initialMode: await repository.loadThemeMode(),
      );
      addTearDown(cubit.close);

      expect(cubit.state, ThemeMode.light);
    });
  });
}
