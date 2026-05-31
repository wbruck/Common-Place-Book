// Tests for the US-002 follow-up: CategoriesDao converted from hard delete to
// soft delete, with every read/watch path filtering out tombstoned rows.
//
// Categories have no repository; CategoriesDao is the public surface, so the
// DAO is exercised directly against an in-memory database.

import 'package:common_place_book/core/database/daos/categories_dao.dart';
import 'package:common_place_book/core/database/database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late CategoriesDao categories;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    categories = CategoriesDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Category soft delete', () {
    test('deleteCategory tombstones the row instead of removing it', () async {
      final category = await categories.createCategory(
        id: 'c1',
        name: 'Doomed',
      );

      await categories.deleteCategory(category.id);

      // The physical row survives as a tombstone (queried directly, bypassing
      // the read filter).
      final raw = await (db.select(db.categories)
            ..where((c) => c.id.equals(category.id)))
          .getSingleOrNull();
      expect(raw, isNotNull, reason: 'row must be retained for sync');
      expect(raw!.deletedAt, isNotNull, reason: 'deletedAt tombstone set');
    });

    test('deleteCategory is idempotent and keeps the original tombstone',
        () async {
      await categories.createCategory(id: 'c1', name: 'Doomed');

      await categories.deleteCategory('c1');
      final first = await (db.select(db.categories)
            ..where((c) => c.id.equals('c1')))
          .getSingle();

      await categories.deleteCategory('c1');
      final second = await (db.select(db.categories)
            ..where((c) => c.id.equals('c1')))
          .getSingle();

      expect(
        second.deletedAt,
        first.deletedAt,
        reason: 'guarded by deletedAt.isNull(): second delete is a no-op',
      );
    });

    test('deleted category is hidden from every read/watch path', () async {
      final keep = await categories.createCategory(id: 'keep', name: 'Keep');
      final drop = await categories.createCategory(id: 'drop', name: 'Drop');

      await categories.deleteCategory(drop.id);

      expect(await categories.getCategoryById(drop.id), isNull);
      expect(
        (await categories.getAllCategories()).map((c) => c.id),
        isNot(contains(drop.id)),
      );
      expect(
        (await categories.getRootCategories()).map((c) => c.id),
        isNot(contains(drop.id)),
      );
      final watched = await categories.watchAllCategories().first;
      expect(watched.map((c) => c.id), isNot(contains(drop.id)));
      expect(watched.map((c) => c.id), contains(keep.id));
    });

    test('live children are reparented to the root, not orphaned', () async {
      final parent = await categories.createCategory(
        id: 'parent',
        name: 'Parent',
      );
      final child = await categories.createCategory(
        id: 'child',
        name: 'Child',
        parentId: parent.id,
      );

      await categories.deleteCategory(parent.id);

      // The child stays live and is now a root (parentId nulled).
      final refetched = await categories.getCategoryById(child.id);
      expect(refetched, isNotNull, reason: 'child not deleted');
      expect(refetched!.parentId, isNull, reason: 'child reparented to root');
      expect(
        (await categories.getRootCategories()).map((c) => c.id),
        contains(child.id),
      );
      // It no longer reports as a child of the tombstoned parent.
      expect(await categories.getChildCategories(parent.id), isEmpty);
    });

    test('getChildCategories excludes tombstoned children', () async {
      final parent = await categories.createCategory(
        id: 'parent',
        name: 'Parent',
      );
      final liveChild = await categories.createCategory(
        id: 'live',
        name: 'Live child',
        parentId: parent.id,
      );
      await categories.createCategory(
        id: 'dead',
        name: 'Dead child',
        parentId: parent.id,
      );

      await categories.deleteCategory('dead');

      final children = await categories.getChildCategories(parent.id);
      expect(children.map((c) => c.id), [liveChild.id]);
    });
  });
}
