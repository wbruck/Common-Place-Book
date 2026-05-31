import 'package:drift/drift.dart';

import '../database.dart';

part 'categories_dao.g.dart';

@DriftAccessor(tables: [Categories])
class CategoriesDao extends DatabaseAccessor<AppDatabase>
    with _$CategoriesDaoMixin {
  CategoriesDao(super.db);

  // ============ CRUD Operations ============

  Future<Category> createCategory({
    required String id,
    required String name,
    String? parentId,
    String? icon,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    final category = CategoriesCompanion.insert(
      id: id,
      name: name,
      parentId: Value(parentId),
      icon: Value(icon),
      createdAt: now,
    );

    await into(categories).insert(category);

    return (select(categories)..where((c) => c.id.equals(id))).getSingle();
  }

  Future<void> updateCategory({
    required String id,
    String? name,
    String? parentId,
    String? icon,
  }) async {
    await (update(categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        parentId: parentId != null ? Value(parentId) : const Value.absent(),
        icon: icon != null ? Value(icon) : const Value.absent(),
      ),
    );
  }

  /// Soft-deletes a category by setting its [Categories.deletedAt] tombstone
  /// instead of physically removing the row, so the delete can be synced to
  /// other devices. Live child categories are first reparented to the root
  /// (their [Categories.parentId] is nulled) so they are not orphaned under a
  /// tombstoned parent.
  Future<void> deleteCategory(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    // Reparent any live child categories to the root so they remain visible.
    await (update(categories)
          ..where((c) => c.parentId.equals(id) & c.deletedAt.isNull()))
        .write(const CategoriesCompanion(parentId: Value(null)));

    // Soft-delete the category itself.
    await (update(categories)
          ..where((c) => c.id.equals(id) & c.deletedAt.isNull()))
        .write(CategoriesCompanion(deletedAt: Value(now)));
  }

  Future<Category?> getCategoryById(String id) {
    return (select(categories)
          ..where((c) => c.id.equals(id) & c.deletedAt.isNull()))
        .getSingleOrNull();
  }

  // ============ Query Operations ============

  Future<List<Category>> getAllCategories() {
    return (select(categories)
          ..where((c) => c.deletedAt.isNull())
          ..orderBy([(c) => OrderingTerm.asc(c.name)]))
        .get();
  }

  Future<List<Category>> getRootCategories() {
    return (select(categories)
          ..where((c) => c.parentId.isNull() & c.deletedAt.isNull())
          ..orderBy([(c) => OrderingTerm.asc(c.name)]))
        .get();
  }

  Future<List<Category>> getChildCategories(String parentId) {
    return (select(categories)
          ..where((c) => c.parentId.equals(parentId) & c.deletedAt.isNull())
          ..orderBy([(c) => OrderingTerm.asc(c.name)]))
        .get();
  }

  // ============ Stream Queries ============

  Stream<List<Category>> watchAllCategories() {
    return (select(categories)
          ..where((c) => c.deletedAt.isNull())
          ..orderBy([(c) => OrderingTerm.asc(c.name)]))
        .watch();
  }
}
