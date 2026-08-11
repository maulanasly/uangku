import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'package:uangku/data/database/database.dart';
import 'package:uangku/data/repositories/transaction_repository.dart';

void main() {
  late AppDatabase db;
  late TransactionRepository repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.customStatement('PRAGMA foreign_keys = ON');
    repo = TransactionRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<String> createList(String name) async {
    final id = const Uuid().v4();
    await repo.addShoppingListWithItems(
      ShoppingListsCompanion.insert(id: id, name: name, date: DateTime(2026, 8, 1)),
      [],
    );
    return id;
  }

  ShoppingListItemsCompanion item(String id, String listId, String name,
      {double quantity = 1,
      double? unitPrice,
      double total = 0,
      bool checked = false,
      int position = 0,}) {
    return ShoppingListItemsCompanion.insert(
      id: id,
      listId: listId,
      name: name,
      quantity: Value(quantity),
      unitPrice: Value(unitPrice),
      total: Value(total),
      checked: Value(checked),
      position: Value(position),
    );
  }

  group('Shopping list repository', () {
    test('creates a list with items and watches them in order', () async {
      final listId = await createList('Weekend groceries');
      await repo.addShoppingListItem(
        item('i1', listId, 'Milk', unitPrice: 3.5, total: 7, quantity: 2, position: 0),
      );
      await repo.addShoppingListItem(
        item('i2', listId, 'Bread', unitPrice: 2, total: 2, position: 1),
      );

      final lists = await repo.watchShoppingLists().first;
      expect(lists.single.name, 'Weekend groceries');

      final items = await repo.watchShoppingListItems(listId).first;
      expect(items.map((i) => i.name).toList(), ['Milk', 'Bread']);
      expect(items.first.quantity, 2);
    });

    test('updates an item (toggle checked and edit quantity/price)', () async {
      final listId = await createList('Groceries');
      await repo.addShoppingListItem(
        item('i1', listId, 'Milk', unitPrice: 3.5, total: 7, quantity: 2, position: 0),
      );

      await repo.updateShoppingListItem(
        const ShoppingListItemsCompanion(
          id: Value('i1'),
          name: Value('Milk 2L'),
          quantity: Value(1),
          unitPrice: Value(4.0),
          total: Value(4.0),
          checked: Value(true),
        ),
      );

      final items = await repo.watchShoppingListItems(listId).first;
      final milk = items.single;
      expect(milk.name, 'Milk 2L');
      expect(milk.checked, isTrue);
      expect(milk.quantity, 1);
      expect(milk.unitPrice, 4.0);
      expect(milk.total, 4.0);
    });

    test('marks a list completed via updateShoppingList', () async {
      await createList('Groceries');
      final list = (await repo.watchShoppingLists().first).single;

      await repo.updateShoppingList(list.copyWith(completed: true));

      final updated = (await repo.watchShoppingLists().first).single;
      expect(updated.completed, isTrue);
    });

    test('deletes specific items from a list', () async {
      final listId = await createList('Groceries');
      await repo.addShoppingListItem(
        item('i1', listId, 'Milk', total: 3.5, position: 0),
      );
      await repo.addShoppingListItem(
        item('i2', listId, 'Bread', total: 2, position: 1),
      );

      await repo.deleteShoppingListItems(['i1']);

      final items = await repo.watchShoppingListItems(listId).first;
      expect(items.single.name, 'Bread');
    });

    test('deleting a list cascades to its items', () async {
      final listId = await createList('Groceries');
      await repo.addShoppingListItem(
        item('i1', listId, 'Milk', total: 3.5, position: 0),
      );

      await repo.deleteShoppingList(listId);

      final lists = await repo.watchShoppingLists().first;
      expect(lists, isEmpty);
      final items = await repo.watchShoppingListItems(listId).first;
      expect(items, isEmpty);
    });
  });
}
