// Tests for US-003: periodic purge of old tombstones.
//
// The purge hard-deletes soft-deleted rows whose deletedAt is older than a
// configurable retention threshold, while keeping fresher tombstones (which
// still need time to propagate) and all live rows. Runs against an in-memory
// database with controlled timestamps so age boundaries are deterministic.

import 'package:common_place_book/core/database/database.dart';
import 'package:common_place_book/core/database/tombstone_purge_service.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late TombstonePurgeService service;

  // Fixed "now" so the age boundary is deterministic regardless of wall clock.
  final now = DateTime.utc(2026, 5, 30, 12);
  int msAgo(Duration d) => now.subtract(d).millisecondsSinceEpoch;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = TombstonePurgeService(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> insertEntry(
    String id, {
    int? deletedAt,
  }) async {
    await db.into(db.entries).insert(
          EntriesCompanion.insert(
            id: id,
            content: 'content-$id',
            createdAt: 0,
            updatedAt: 0,
            deletedAt: Value(deletedAt),
          ),
        );
  }

  Set<String> liveIds(List<Entry> rows) => rows.map((e) => e.id).toSet();

  group('TombstonePurgeService.purge', () {
    test('keeps tombstones newer than the threshold, purges older ones',
        () async {
      // Live row (no tombstone) — must always survive.
      await insertEntry('live');
      // Tombstoned 10 days ago — newer than the 30-day default, must survive.
      await insertEntry('recent', deletedAt: msAgo(const Duration(days: 10)));
      // Tombstoned 40 days ago — older than the default, must be purged.
      await insertEntry('stale', deletedAt: msAgo(const Duration(days: 40)));

      final purged = await service.purge(now: now);

      expect(purged, 1, reason: 'only the stale tombstone is purged');

      final remaining = await db.select(db.entries).get();
      expect(liveIds(remaining), {'live', 'recent'});
    });

    test('a tombstone exactly at the threshold is kept (strictly older purged)',
        () async {
      // Exactly 30 days old: cutoff is deletedAt < (now - 30d), so equal is
      // NOT strictly older and must be kept.
      await insertEntry('boundary', deletedAt: msAgo(const Duration(days: 30)));

      final purged = await service.purge(now: now);

      expect(purged, 0);
      expect(liveIds(await db.select(db.entries).get()), {'boundary'});
    });

    test('respects a custom retention threshold', () async {
      await insertEntry('two-days', deletedAt: msAgo(const Duration(days: 2)));
      await insertEntry('ten-days', deletedAt: msAgo(const Duration(days: 10)));

      // With a 5-day retention, the 10-day-old tombstone is stale but the
      // 2-day-old one is kept.
      final purged =
          await service.purge(retention: const Duration(days: 5), now: now);

      expect(purged, 1);
      expect(liveIds(await db.select(db.entries).get()), {'two-days'});
    });

    test('purges stale tombstones across every syncable table', () async {
      final stale = msAgo(const Duration(days: 40));

      await db.into(db.categories).insert(
            CategoriesCompanion.insert(
              id: 'cat',
              name: 'Stale Category',
              createdAt: 0,
              deletedAt: Value(stale),
            ),
          );
      await db.into(db.tags).insert(
            TagsCompanion.insert(
              id: 'tag',
              name: 'stale-tag',
              createdAt: 0,
              deletedAt: Value(stale),
            ),
          );
      // An entry plus a link, both tombstoned, so entry_tags is purged too.
      await insertEntry('entry', deletedAt: stale);
      await db.into(db.entryTags).insert(
            EntryTagsCompanion.insert(
              id: 'link',
              entryId: 'entry',
              tagId: 'tag',
              deletedAt: Value(stale),
            ),
          );

      final purged = await service.purge(now: now);

      expect(purged, 4, reason: 'one stale row from each of the four tables');
      expect(await db.select(db.entries).get(), isEmpty);
      expect(await db.select(db.tags).get(), isEmpty);
      expect(await db.select(db.entryTags).get(), isEmpty);
      // Default seed categories are absent in forTesting (no onCreate seeding
      // happens for an in-memory DB created via createAll), so the only
      // category was the stale one.
      expect(
        (await db.select(db.categories).get())
            .where((c) => c.id == 'cat')
            .toList(),
        isEmpty,
      );
    });
  });

  group('TombstonePurgeService.runOnce', () {
    test('runs the purge on first call', () async {
      await insertEntry('stale', deletedAt: msAgo(const Duration(days: 40)));

      final purged = await service.runOnce(now: now);

      expect(purged, 1);
      expect(await db.select(db.entries).get(), isEmpty);
    });

    test('is a no-op on subsequent calls within the same session', () async {
      await insertEntry('stale-a', deletedAt: msAgo(const Duration(days: 40)));
      expect(await service.runOnce(now: now), 1);

      // A new stale row appears, but runOnce must not act a second time.
      await insertEntry('stale-b', deletedAt: msAgo(const Duration(days: 40)));
      final second = await service.runOnce(now: now);

      expect(second, 0, reason: 'runOnce purges at most once per session');
      expect(liveIds(await db.select(db.entries).get()), {'stale-b'});
    });
  });
}
