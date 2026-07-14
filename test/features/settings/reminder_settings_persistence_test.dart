// Tests for daily-reminder settings persistence:
//   - LocalSettingsRepository round-trips the enabled flag and time via the
//     key/value `settings` table.
//   - Missing or corrupt values fall back to the defaults (off, 9:00 AM).
//
// Runs against an in-memory database via
// `AppDatabase.forTesting(NativeDatabase.memory())` so nothing touches the
// platform connection.

import 'package:common_place_book/core/database/database.dart';
import 'package:common_place_book/features/settings/data/local_settings_repository.dart';
import 'package:common_place_book/features/settings/domain/settings_repository.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
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

  group('reminder enabled flag', () {
    test('defaults to false when nothing is persisted', () async {
      expect(await repository.loadReminderEnabled(), isFalse);
    });

    test('round-trips (save -> load)', () async {
      await repository.saveReminderEnabled(enabled: true);
      expect(await repository.loadReminderEnabled(), isTrue);

      await repository.saveReminderEnabled(enabled: false);
      expect(await repository.loadReminderEnabled(), isFalse);
    });
  });

  group('reminder time', () {
    test('defaults to 9:00 AM (540 minutes) when nothing is persisted',
        () async {
      expect(await repository.loadReminderTimeMinutes(), 540);
    });

    test('round-trips (save -> load)', () async {
      await repository.saveReminderTimeMinutes(20 * 60 + 15);
      expect(await repository.loadReminderTimeMinutes(), 1215);
    });

    test('midnight (0 minutes) is a valid persisted value', () async {
      await repository.saveReminderTimeMinutes(0);
      expect(await repository.loadReminderTimeMinutes(), 0);
    });

    test('an unparseable stored value falls back to the default', () async {
      await db.into(db.settings).insertOnConflictUpdate(
            const SettingsCompanion(
              key: Value('reminder_time'),
              value: Value('not-a-number'),
            ),
          );
      expect(await repository.loadReminderTimeMinutes(), 540);
    });

    test('an out-of-range stored value falls back to the default', () async {
      await db.into(db.settings).insertOnConflictUpdate(
            const SettingsCompanion(
              key: Value('reminder_time'),
              value: Value('1500'),
            ),
          );
      expect(await repository.loadReminderTimeMinutes(), 540);
    });
  });
}
