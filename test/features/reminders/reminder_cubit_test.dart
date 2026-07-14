// Tests for the daily reminder: ReminderCubit (permission gating, persistence,
// scheduling side-effects) and DailyReminderScheduler (quote picking,
// formatting, empty-book cancellation).
//
// Uses the real LocalEntryRepository + LocalSettingsRepository over an
// in-memory database, with a recording FakeNotificationService.

import 'package:common_place_book/core/database/database.dart';
import 'package:common_place_book/features/entries/data/repositories/entry_repository.dart';
import 'package:common_place_book/features/entries/data/repositories/local_entry_repository.dart';
import 'package:common_place_book/features/reminders/domain/daily_reminder_scheduler.dart';
import 'package:common_place_book/features/reminders/domain/reminder_settings.dart';
import 'package:common_place_book/features/reminders/presentation/bloc/reminder_cubit.dart';
import 'package:common_place_book/features/settings/data/local_settings_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_notification_service.dart';

void main() {
  late AppDatabase db;
  late EntryRepository entryRepository;
  late LocalSettingsRepository settingsRepository;
  late FakeNotificationService notificationService;
  late DailyReminderScheduler scheduler;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    entryRepository = LocalEntryRepository(database: db);
    settingsRepository = LocalSettingsRepository(db);
    notificationService = FakeNotificationService();
    scheduler = DailyReminderScheduler(
      entryRepository: entryRepository,
      notificationService: notificationService,
    );
  });

  tearDown(() async {
    await db.close();
  });

  ReminderCubit buildCubit({
    ReminderSettings initialSettings = const ReminderSettings(
      enabled: false,
      time: ReminderSettings.defaultTime,
    ),
  }) {
    final cubit = ReminderCubit(
      settingsRepository: settingsRepository,
      notificationService: notificationService,
      scheduler: scheduler,
      initialSettings: initialSettings,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  group('ReminderCubit.setEnabled', () {
    test('denied permission: stays disabled, persists nothing, returns false',
        () async {
      notificationService.permissionGranted = false;
      final cubit = buildCubit();

      final granted = await cubit.setEnabled(enabled: true);

      expect(granted, isFalse);
      expect(cubit.state.enabled, isFalse);
      expect(await settingsRepository.loadReminderEnabled(), isFalse);
      expect(notificationService.scheduled, isEmpty);
    });

    test('granted permission: enables, persists, and schedules', () async {
      await entryRepository.createEntry(
        content: 'The unexamined life is not worth living.',
        source: 'Socrates',
      );
      final cubit = buildCubit();

      final granted = await cubit.setEnabled(enabled: true);

      expect(granted, isTrue);
      expect(cubit.state.enabled, isTrue);
      expect(await settingsRepository.loadReminderEnabled(), isTrue);
      expect(notificationService.scheduled, hasLength(1));
      final reminder = notificationService.scheduled.single;
      expect(reminder.time, ReminderSettings.defaultTime);
      expect(reminder.title, '— Socrates');
      expect(reminder.body, 'The unexamined life is not worth living.');
    });

    test('disabling cancels the pending reminder and persists', () async {
      await settingsRepository.saveReminderEnabled(enabled: true);
      final cubit = buildCubit(
        initialSettings: const ReminderSettings(
          enabled: true,
          time: ReminderSettings.defaultTime,
        ),
      );

      await cubit.setEnabled(enabled: false);

      expect(cubit.state.enabled, isFalse);
      expect(await settingsRepository.loadReminderEnabled(), isFalse);
      expect(notificationService.cancelCount, 1);
      // Disabling never re-asks for permission.
      expect(notificationService.permissionRequestCount, 0);
    });

    test('enabling with an empty book cancels instead of scheduling',
        () async {
      final cubit = buildCubit();

      await cubit.setEnabled(enabled: true);

      expect(notificationService.scheduled, isEmpty);
      expect(notificationService.cancelCount, 1);
    });
  });

  group('ReminderCubit.setTime', () {
    test('persists the time and reschedules while enabled', () async {
      await entryRepository.createEntry(content: 'Know thyself.');
      final cubit = buildCubit(
        initialSettings: const ReminderSettings(
          enabled: true,
          time: ReminderSettings.defaultTime,
        ),
      );

      await cubit.setTime(const TimeOfDay(hour: 20, minute: 30));

      expect(cubit.state.time, const TimeOfDay(hour: 20, minute: 30));
      expect(await settingsRepository.loadReminderTimeMinutes(), 20 * 60 + 30);
      expect(notificationService.scheduled, hasLength(1));
      expect(
        notificationService.scheduled.single.time,
        const TimeOfDay(hour: 20, minute: 30),
      );
      // No source on the entry: generic title is used.
      expect(
        notificationService.scheduled.single.title,
        'From your commonplace book',
      );
    });

    test('while disabled only persists (no schedule call)', () async {
      final cubit = buildCubit();

      await cubit.setTime(const TimeOfDay(hour: 7, minute: 0));

      expect(await settingsRepository.loadReminderTimeMinutes(), 7 * 60);
      expect(notificationService.scheduled, isEmpty);
    });
  });

  group('DailyReminderScheduler', () {
    test('truncates a long entry on a word boundary with an ellipsis',
        () async {
      final longContent =
          List<String>.generate(60, (i) => 'word$i').join(' ');
      await entryRepository.createEntry(content: longContent);

      await scheduler.reschedule(
        enabled: true,
        time: ReminderSettings.defaultTime,
      );

      final body = notificationService.scheduled.single.body;
      expect(body.length, lessThanOrEqualTo(181));
      expect(body, endsWith('…'));
      // Cut on a word boundary: no partial word before the ellipsis.
      expect(longContent, contains(body.substring(0, body.length - 1)));
    });

    test('does nothing on unsupported platforms', () async {
      final unsupported = FakeNotificationService(supported: false);
      final guarded = DailyReminderScheduler(
        entryRepository: entryRepository,
        notificationService: unsupported,
      );

      await guarded.reschedule(
        enabled: true,
        time: ReminderSettings.defaultTime,
      );

      expect(unsupported.scheduled, isEmpty);
      expect(unsupported.cancelCount, 0);
    });
  });
}
