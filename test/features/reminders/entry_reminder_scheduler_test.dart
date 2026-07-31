// Tests for per-entry reminders: the repository persistence of `reminderAt`
// and the EntryReminderScheduler that keeps scheduled notifications in sync.
//
// Runs the real repository against an in-memory database and a fake
// notification service, so the DAO column, mapper, scheduler formatting and
// the startup re-sync are all covered end-to-end.

import 'package:common_place_book/core/database/database.dart';
import 'package:common_place_book/features/entries/data/repositories/local_entry_repository.dart';
import 'package:common_place_book/features/reminders/domain/entry_reminder_scheduler.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_notification_service.dart';

void main() {
  late AppDatabase db;
  late LocalEntryRepository entries;
  late FakeNotificationService notifications;
  late EntryReminderScheduler scheduler;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    entries = LocalEntryRepository(database: db);
    notifications = FakeNotificationService();
    scheduler = EntryReminderScheduler(
      entryRepository: entries,
      notificationService: notifications,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('repository reminder persistence', () {
    test('setReminder stores the timestamp and getEntryById returns it',
        () async {
      final entry = await entries.createEntry(content: 'Remember me');
      final when = DateTime.now().add(const Duration(days: 1));

      await entries.setReminder(id: entry.id, reminderAt: when);

      final reloaded = await entries.getEntryById(entry.id);
      expect(
        reloaded!.reminderAt!.millisecondsSinceEpoch,
        when.millisecondsSinceEpoch,
      );
    });

    test('setReminder(null) clears the reminder', () async {
      final entry = await entries.createEntry(content: 'Remember me');
      await entries.setReminder(
        id: entry.id,
        reminderAt: DateTime.now().add(const Duration(days: 1)),
      );

      await entries.setReminder(id: entry.id, reminderAt: null);

      final reloaded = await entries.getEntryById(entry.id);
      expect(reloaded!.reminderAt, isNull);
    });

    test('getEntriesWithReminders returns only entries that have one',
        () async {
      final withReminder = await entries.createEntry(content: 'Has reminder');
      await entries.createEntry(content: 'No reminder');
      await entries.setReminder(
        id: withReminder.id,
        reminderAt: DateTime.now().add(const Duration(hours: 2)),
      );

      final result = await entries.getEntriesWithReminders();

      expect(result.map((e) => e.id), [withReminder.id]);
    });
  });

  group('EntryReminderScheduler.schedule', () {
    test('schedules a notification carrying the entry id as payload',
        () async {
      final entry = await entries.createEntry(
        content: 'A profound thought',
        source: 'Someone',
      );
      final when = DateTime.now().add(const Duration(hours: 3));
      await entries.setReminder(id: entry.id, reminderAt: when);
      final loaded = await entries.getEntryById(entry.id);

      await scheduler.schedule(loaded!);

      expect(notifications.scheduledEntryReminders, hasLength(1));
      final scheduled = notifications.scheduledEntryReminders.single;
      expect(scheduled.entryId, entry.id);
      expect(scheduled.payload, entry.id);
      expect(
        scheduled.dateTime.millisecondsSinceEpoch,
        when.millisecondsSinceEpoch,
      );
      expect(scheduled.title, '— Someone');
      expect(scheduled.body, 'A profound thought');
    });

    test('cancels instead of scheduling when the entry has no reminder',
        () async {
      final entry = await entries.createEntry(content: 'No reminder set');
      final loaded = await entries.getEntryById(entry.id);

      await scheduler.schedule(loaded!);

      expect(notifications.scheduledEntryReminders, isEmpty);
      expect(notifications.canceledEntryReminders, [entry.id]);
    });

    test('does nothing when notifications are unsupported', () async {
      final unsupported = FakeNotificationService(supported: false);
      final offlineScheduler = EntryReminderScheduler(
        entryRepository: entries,
        notificationService: unsupported,
      );
      final entry = await entries.createEntry(content: 'x');
      await entries.setReminder(
        id: entry.id,
        reminderAt: DateTime.now().add(const Duration(hours: 1)),
      );
      final loaded = await entries.getEntryById(entry.id);

      await offlineScheduler.schedule(loaded!);

      expect(unsupported.scheduledEntryReminders, isEmpty);
      expect(unsupported.canceledEntryReminders, isEmpty);
    });
  });

  group('EntryReminderScheduler.syncAll', () {
    test('reschedules future reminders and leaves them persisted', () async {
      final entry = await entries.createEntry(content: 'Future');
      final when = DateTime.now().add(const Duration(days: 2));
      await entries.setReminder(id: entry.id, reminderAt: when);

      await scheduler.syncAll();

      expect(
        notifications.scheduledEntryReminders.map((r) => r.entryId),
        [entry.id],
      );
      final reloaded = await entries.getEntryById(entry.id);
      expect(reloaded!.reminderAt, isNotNull);
    });

    test('clears past-due reminders instead of scheduling them', () async {
      final entry = await entries.createEntry(content: 'Past');
      // Persist a reminder in the past directly (setReminder accepts any time;
      // the scheduler decides what to do with it on sync).
      await entries.setReminder(
        id: entry.id,
        reminderAt: DateTime.now().subtract(const Duration(hours: 1)),
      );

      await scheduler.syncAll();

      expect(notifications.scheduledEntryReminders, isEmpty);
      expect(notifications.canceledEntryReminders, contains(entry.id));
      final reloaded = await entries.getEntryById(entry.id);
      expect(
        reloaded!.reminderAt,
        isNull,
        reason: 'a past-due one-shot should be cleared',
      );
    });
  });

  group('EntryReminderScheduler.cancel', () {
    test('forwards the cancel to the notification service', () async {
      await scheduler.cancel('entry-123');
      expect(notifications.canceledEntryReminders, ['entry-123']);
    });
  });
}
