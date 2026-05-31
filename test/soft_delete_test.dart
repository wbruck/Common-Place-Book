// Tests for US-002: hard deletes converted to soft deletes, and every read
// path filters out soft-deleted (tombstoned) rows.
//
// Exercises the repositories (the public surface features use) against an
// in-memory database so the DAO read filters and soft-delete writes are
// covered end-to-end.

import 'package:common_place_book/core/database/database.dart';
import 'package:common_place_book/features/entries/data/repositories/local_entry_repository.dart';
import 'package:common_place_book/features/entries/domain/entities/entry_entity.dart';
import 'package:common_place_book/features/tags/data/repositories/local_tag_repository.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late LocalEntryRepository entries;
  late LocalTagRepository tags;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    entries = LocalEntryRepository(database: db);
    tags = LocalTagRepository(database: db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Entry soft delete', () {
    test('delete sets deletedAt + bumps updatedAt instead of removing the row',
        () async {
      final entry = await entries.createEntry(content: 'To be deleted');

      await entries.deleteEntry(entry.id);

      // The physical row survives as a tombstone (queried directly, bypassing
      // the read filter).
      final raw = await (db.select(db.entries)
            ..where((e) => e.id.equals(entry.id)))
          .getSingleOrNull();
      expect(raw, isNotNull, reason: 'row must be retained for sync');
      expect(raw!.deletedAt, isNotNull, reason: 'deletedAt tombstone set');
      expect(
        raw.updatedAt,
        greaterThanOrEqualTo(entry.updatedAt.millisecondsSinceEpoch),
        reason: 'updatedAt bumped on delete',
      );
    });

    test('getEntryById returns null for a soft-deleted entry', () async {
      final entry = await entries.createEntry(content: 'Hidden');
      await entries.deleteEntry(entry.id);

      expect(await entries.getEntryById(entry.id), isNull);
    });

    test('soft-deleted entry is hidden from every read path', () async {
      final tag = await tags.createTag(name: 'philosophy');
      final keep = await entries.createEntry(
        content: 'Keep me searchable',
        source: 'Author K',
        tagIds: [tag.id],
      );
      final drop = await entries.createEntry(
        content: 'Drop me searchable',
        source: 'Author D',
        tagIds: [tag.id],
      );
      // Make both favorites so the favorites read path is exercised.
      await entries.updateEntry(id: keep.id, isFavorite: true);
      await entries.updateEntry(id: drop.id, isFavorite: true);

      await entries.deleteEntry(drop.id);

      bool containsDrop(List<EntryEntity> list) =>
          list.any((e) => e.id == drop.id);

      expect(containsDrop(await entries.getAllEntries()), isFalse);
      expect(containsDrop(await entries.searchEntries('searchable')), isFalse);
      expect(containsDrop(await entries.getFavoriteEntries()), isFalse);
      expect(containsDrop(await entries.getEntriesByTag(tag.id)), isFalse);
      expect(await entries.getEntryCount(), 1);

      // watchAllEntries stream excludes it too.
      final watched = await entries.watchAllEntries().first;
      expect(containsDrop(watched), isFalse);
      expect(watched.map((e) => e.id), [keep.id]);

      // watchEntry on the deleted id emits null.
      expect(await entries.watchEntry(drop.id).first, isNull);

      // Random reads never surface the deleted entry (only `keep` is live).
      final random = await entries.getRandomEntry();
      expect(random?.id, keep.id);
      final randomByTag = await entries.getRandomEntryByTag(tag.id);
      expect(randomByTag?.id, keep.id);
    });

    test('getRandomEntry returns null when the only entry is soft-deleted',
        () async {
      final entry = await entries.createEntry(content: 'Solo');
      await entries.deleteEntry(entry.id);

      expect(await entries.getRandomEntry(), isNull);
    });
  });

  group('Entry-tag link soft delete', () {
    test('soft-deleted links are excluded from related reads', () async {
      final shared = await tags.createTag(name: 'shared');
      final source = await entries.createEntry(
        content: 'Source entry',
        tagIds: [shared.id],
      );
      final related = await entries.createEntry(
        content: 'Related entry',
        tagIds: [shared.id],
      );

      // Sanity: they are related via the shared tag.
      var relatedList = await entries.getRelatedEntries(source.id);
      expect(relatedList.map((e) => e.id), contains(related.id));

      // Remove the shared tag from the related entry (link soft-delete).
      await entries.updateEntry(id: related.id, tagIds: const []);

      relatedList = await entries.getRelatedEntries(source.id);
      expect(
        relatedList.map((e) => e.id),
        isNot(contains(related.id)),
        reason: 'soft-deleted link must not contribute to related reads',
      );

      // The link row is tombstoned, not physically removed.
      final links = await (db.select(db.entryTags)
            ..where((et) => et.entryId.equals(related.id)))
          .get();
      expect(links, isNotEmpty);
      expect(links.every((l) => l.deletedAt != null), isTrue);
    });

    test(
        'partial tag removal tombstones only the dropped link, keeps the kept '
        'one live', () async {
      final a = await tags.createTag(name: 'A');
      final b = await tags.createTag(name: 'B');
      final entry = await entries.createEntry(
        content: 'Entry with two tags',
        tagIds: [a.id, b.id],
      );

      // Drop B, keep A (exercises the isNotIn branch in updateEntry).
      await entries.updateEntry(id: entry.id, tagIds: [a.id]);

      final links = await (db.select(db.entryTags)
            ..where((et) => et.entryId.equals(entry.id)))
          .get();
      final aLink = links.firstWhere((l) => l.tagId == a.id);
      final bLink = links.firstWhere((l) => l.tagId == b.id);
      expect(aLink.deletedAt, isNull, reason: 'kept link stays live');
      expect(bLink.deletedAt, isNotNull, reason: 'dropped link tombstoned');

      final fetched = await entries.getEntryById(entry.id);
      expect(fetched!.tags.map((t) => t.id), [a.id]);
    });

    test(
        'tag count ignores links pointing at a soft-deleted entry (FIX 2)',
        () async {
      final tag = await tags.createTag(name: 'counted');
      final entry = await entries.createEntry(
        content: 'Entry to hide',
        tagIds: [tag.id],
      );

      // Soft-delete ONLY the entry row directly so the link stays live
      // (deleteEntry would also tombstone the link, which is not what we want
      // to exercise here).
      await (db.update(db.entries)..where((e) => e.id.equals(entry.id))).write(
        EntriesCompanion(
          deletedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );

      // The link is still live...
      final liveLinks = await (db.select(db.entryTags)
            ..where(
              (et) => et.entryId.equals(entry.id) & et.deletedAt.isNull(),
            ))
          .get();
      expect(liveLinks, isNotEmpty, reason: 'link intentionally left live');

      // ...but the count must exclude it because the entry is tombstoned.
      final withCounts = await tags.getTagsWithCounts();
      final counted = withCounts.firstWhere((t) => t.tag.id == tag.id);
      expect(counted.entryCount, 0);
    });

    test('re-adding a removed tag revives the link without duplicating it',
        () async {
      final tag = await tags.createTag(name: 'reusable');
      final entry = await entries.createEntry(
        content: 'Entry',
        tagIds: [tag.id],
      );

      // Remove then re-add the same tag.
      await entries.updateEntry(id: entry.id, tagIds: const []);
      await entries.updateEntry(id: entry.id, tagIds: [tag.id]);

      // Exactly one physical link row for the pair (revived, not duplicated).
      final links = await (db.select(db.entryTags)
            ..where((et) => et.entryId.equals(entry.id)))
          .get();
      expect(links.length, 1);
      expect(links.single.deletedAt, isNull, reason: 'link revived');

      final fetched = await entries.getEntryById(entry.id);
      expect(fetched!.tags.map((t) => t.id), [tag.id]);
    });

    test('deleting an entry soft-deletes its tag links', () async {
      final tag = await tags.createTag(name: 'orphan');
      final entry = await entries.createEntry(
        content: 'Entry with tag',
        tagIds: [tag.id],
      );

      await entries.deleteEntry(entry.id);

      final links = await (db.select(db.entryTags)
            ..where((et) => et.entryId.equals(entry.id)))
          .get();
      expect(links, isNotEmpty);
      expect(links.every((l) => l.deletedAt != null), isTrue);

      // The tag itself remains live and its count drops to zero.
      final withCounts = await tags.getTagsWithCounts();
      final orphan = withCounts.firstWhere((t) => t.tag.id == tag.id);
      expect(orphan.entryCount, 0);
    });
  });

  group('Tag soft delete', () {
    test('deleted tag is hidden from every tag read path', () async {
      final keep = await tags.createTag(name: 'keep');
      final drop = await tags.createTag(name: 'drop');

      await tags.deleteTag(drop.id);

      expect(await tags.getTagById(drop.id), isNull);
      expect(await tags.getTagByName('drop'), isNull);
      expect(
        (await tags.getAllTags()).map((t) => t.id),
        isNot(contains(drop.id)),
      );
      expect(
        (await tags.searchTags('drop')).map((t) => t.id),
        isNot(contains(drop.id)),
      );
      expect(
        (await tags.getTagsWithCounts()).map((t) => t.tag.id),
        isNot(contains(drop.id)),
      );
      final watched = await tags.watchAllTags().first;
      expect(watched.map((t) => t.id), [keep.id]);

      // The physical row survives as a tombstone.
      final raw = await (db.select(db.tags)..where((t) => t.id.equals(drop.id)))
          .getSingleOrNull();
      expect(raw, isNotNull);
      expect(raw!.deletedAt, isNotNull);
    });

    test('a deleted tag stops appearing on its entries', () async {
      final tag = await tags.createTag(name: 'tag-to-remove');
      final entry = await entries.createEntry(
        content: 'Tagged entry',
        tagIds: [tag.id],
      );

      await tags.deleteTag(tag.id);

      final fetched = await entries.getEntryById(entry.id);
      expect(fetched!.tags, isEmpty);
    });

    test('getOrCreateTags revives a soft-deleted tag of the same name',
        () async {
      final original = await tags.createTag(name: 'revivable');
      await tags.deleteTag(original.id);

      final revived = await tags.getOrCreateTags(['revivable']);
      expect(revived.single.id, original.id, reason: 'same row revived');
      expect(await tags.getTagByName('revivable'), isNotNull);

      // Only one physical row exists for the name (no duplicate insert).
      final raws =
          await (db.select(db.tags)..where((t) => t.name.equals('revivable')))
              .get();
      expect(raws.length, 1);
    });
  });
}
