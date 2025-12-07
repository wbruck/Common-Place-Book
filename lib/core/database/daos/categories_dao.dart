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

  Future<void> deleteCategory(String id) async {
    // Set parentId to null for any child categories
    await (update(categories)..where((c) => c.parentId.equals(id))).write(
      const CategoriesCompanion(parentId: Value(null)),
    );
    // Delete the category
    await (delete(categories)..where((c) => c.id.equals(id))).go();
  }

  Future<Category?> getCategoryById(String id) {
    return (select(categories)..where((c) => c.id.equals(id)))
        .getSingleOrNull();
  }

  // ============ Query Operations ============

  Future<List<Category>> getAllCategories() {
    return (select(categories)..orderBy([(c) => OrderingTerm.asc(c.name)]))
        .get();
  }

  Future<List<Category>> getRootCategories() {
    return (select(categories)
          ..where((c) => c.parentId.isNull())
          ..orderBy([(c) => OrderingTerm.asc(c.name)]))
        .get();
  }

  Future<List<Category>> getChildCategories(String parentId) {
    return (select(categories)
          ..where((c) => c.parentId.equals(parentId))
          ..orderBy([(c) => OrderingTerm.asc(c.name)]))
        .get();
  }

  // ============ Stream Queries ============

  Stream<List<Category>> watchAllCategories() {
    return (select(categories)..orderBy([(c) => OrderingTerm.asc(c.name)]))
        .watch();
  }
}
