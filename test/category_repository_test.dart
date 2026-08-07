import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:uangku/data/database/database.dart';
import 'package:uangku/data/repositories/transaction_repository.dart';

void main() {
  late AppDatabase db;
  late TransactionRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = TransactionRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('TransactionRepository categories', () {
    test('seeds default categories on create', () async {
      final categories = await repo.getCategories();
      expect(categories.length, 3);
      expect(categories.map((c) => c.id), contains('cat_food'));
    });

    test('adds a category', () async {
      await repo.addCategory(
        CategoriesCompanion.insert(
          id: 'cat_test',
          name: 'Test',
          icon: 'category',
        ),
      );
      final categories = await repo.getCategories();
      expect(categories.length, 4);
    });

    test('updates a category', () async {
      await repo.addCategory(
        CategoriesCompanion.insert(
          id: 'cat_test',
          name: 'Test',
          icon: 'category',
        ),
      );
      final added = (await repo.getCategories()).firstWhere((c) => c.id == 'cat_test');

      await repo.updateCategory(added.copyWith(name: 'Updated', icon: 'home'));

      final updated = (await repo.getCategories()).firstWhere((c) => c.id == 'cat_test');
      expect(updated.name, 'Updated');
      expect(updated.icon, 'home');
    });

    test('deletes a category', () async {
      await repo.addCategory(
        CategoriesCompanion.insert(
          id: 'cat_test',
          name: 'Test',
          icon: 'category',
        ),
      );
      await repo.deleteCategory('cat_test');

      final categories = await repo.getCategories();
      expect(categories.any((c) => c.id == 'cat_test'), isFalse);
    });
  });
}
