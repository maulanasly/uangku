import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:uangku/core/models/transaction_query.dart';
import 'package:uangku/core/models/transaction_type.dart';
import 'package:uangku/data/database/database.dart';
import 'package:uangku/data/repositories/transaction_repository.dart';

void main() {
  late AppDatabase db;
  late TransactionRepository repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.customStatement('PRAGMA foreign_keys = ON');
    repo = TransactionRepository(db);

    final batch = db.batch(
      (b) => b.insertAll(
        db.transactions,
        [
          TransactionsCompanion.insert(
            id: '1',
            date: DateTime(2026, 7, 1),
            amount: 50,
            category: 'cat_food',
            merchant: 'Starbucks',
            note: 'Morning coffee',
            type: TransactionType.expense,
          ),
          TransactionsCompanion.insert(
            id: '2',
            date: DateTime(2026, 7, 2),
            amount: 2000,
            category: 'cat_salary',
            merchant: 'Acme Corp',
            note: 'Monthly salary',
            type: TransactionType.income,
          ),
          TransactionsCompanion.insert(
            id: '3',
            date: DateTime(2026, 7, 3),
            amount: 300,
            category: 'cat_transport',
            merchant: 'Grab',
            note: 'Taxi ride',
            type: TransactionType.expense,
          ),
          TransactionsCompanion.insert(
            id: '4',
            date: DateTime(2026, 7, 4),
            amount: 20,
            category: 'cat_food',
            merchant: 'Co-op',
            note: 'Snacks',
            type: TransactionType.expense,
          ),
        ],
      ),
    );
    await batch;
  });

  tearDown(() async {
    await db.close();
  });

  Future<List<TransactionEntity>> read(TransactionQuery query) async {
    return repo.watchTransactions(query).first;
  }

  group('TransactionRepository.watchTransactions', () {
    test('returns all transactions without filters', () async {
      final result = await read(const TransactionQuery());
      expect(result.length, 4);
    });

    test('filters by search text on merchant and note', () async {
      final byMerchant = await read(const TransactionQuery(search: 'grab'));
      expect(byMerchant.single.id, '3');

      final byNote = await read(const TransactionQuery(search: 'coffee'));
      expect(byNote.single.id, '1');
    });

    test('filters by type', () async {
      final expenses = await read(const TransactionQuery(type: TransactionType.expense));
      expect(expenses.length, 3);

      final income = await read(const TransactionQuery(type: TransactionType.income));
      expect(income.single.id, '2');
    });

    test('filters by category', () async {
      final food = await read(const TransactionQuery(category: 'cat_food'));
      expect(food.length, 2);
      expect(food.map((t) => t.id).toSet(), {'1', '4'});
    });

    test('sorts by amount ascending and descending', () async {
      final asc = await read(
        const TransactionQuery(
          sortField: TransactionSortField.amount,
          direction: SortDirection.asc,
        ),
      );
      expect(asc.first.amount, 20);
      expect(asc.last.amount, 2000);

      final desc = await read(const TransactionQuery(sortField: TransactionSortField.amount));
      expect(desc.first.amount, 2000);
    });

    test('sorts by date descending by default', () async {
      final result = await read(const TransactionQuery());
      expect(result.first.id, '4');
    });
  });

  group('TransactionRepository CRUD', () {
    test('adds and deletes a transaction', () async {
      await repo.addTransaction(
        TransactionsCompanion.insert(
          id: '5',
          date: DateTime(2026, 7, 5),
          amount: 10,
          category: 'cat_food',
          merchant: 'Test',
          note: '',
          type: TransactionType.expense,
        ),
      );
      expect((await repo.watchAllTransactions().first).length, 5);

      await repo.deleteTransaction('5');
      expect((await repo.watchAllTransactions().first).length, 4);
    });
  });

  group('TransactionRepository items', () {
    test('adds transaction with items', () async {
      await repo.addTransactionWithItems(
        TransactionsCompanion.insert(
          id: '5',
          date: DateTime(2026, 7, 5),
          amount: 67,
          category: 'cat_food',
          merchant: 'Co-op',
          note: '',
          type: TransactionType.expense,
        ),
        [
          TransactionItemsCompanion.insert(
            id: '5-0',
            transactionId: '5',
            name: 'Milk',
            quantity: Value(2),
            unitPrice: Value(4.5),
            total: 9,
          ),
          TransactionItemsCompanion.insert(
            id: '5-1',
            transactionId: '5',
            name: 'Bread',
            quantity: Value(1),
            total: 4.5,
          ),
        ],
      );

      final items = await repo.watchItemsFor('5').first;
      expect(items.length, 2);
      expect(items[0].name, 'Milk');
      expect(items[0].total, 9);
      expect(items[1].name, 'Bread');
    });

    test('items cascade delete with transaction', () async {
      // from the add test above, '5' has items
      await repo.deleteTransaction('5');
      final items = await repo.watchItemsFor('5').first;
      expect(items, isEmpty);
    });

    test('updateTransactionWithItems replaces existing items', () async {
      await repo.addTransactionWithItems(
        TransactionsCompanion.insert(
          id: '5',
          date: DateTime(2026, 7, 5),
          amount: 67,
          category: 'cat_food',
          merchant: 'Co-op',
          note: '',
          type: TransactionType.expense,
        ),
        [
          TransactionItemsCompanion.insert(
            id: '5-0',
            transactionId: '5',
            name: 'Milk',
            quantity: const Value(2),
            unitPrice: const Value(4.5),
            total: 9,
          ),
        ],
      );

      final tx = (await repo.watchAllTransactions().first).firstWhere((t) => t.id == '5');
      await repo.updateTransactionWithItems(
        tx.copyWith(amount: 13.5, merchant: 'Co-op Updated'),
        [
          TransactionItemsCompanion.insert(
            id: '5-1',
            transactionId: '5',
            name: 'Bread',
            quantity: const Value(1),
            weight: const Value(0.5),
            total: 4.5,
          ),
          TransactionItemsCompanion.insert(
            id: '5-2',
            transactionId: '5',
            name: 'Milk',
            quantity: const Value(2),
            unitPrice: const Value(4.5),
            total: 9,
          ),
        ],
      );

      final updatedTx =
          (await repo.watchAllTransactions().first).firstWhere((t) => t.id == '5');
      expect(updatedTx.merchant, 'Co-op Updated');
      expect(updatedTx.amount, 13.5);

      final items = await repo.watchItemsFor('5').first;
      expect(items.length, 2);
      expect(items.map((i) => i.id).toSet(), {'5-1', '5-2'});
      expect(items.firstWhere((i) => i.id == '5-1').weight, 0.5);
      expect(items.firstWhere((i) => i.id == '5-2').weight, isNull);
    });
  });

  group('TransactionRepository budgets', () {
    test('setBudget inserts a new budget', () async {
      await repo.setBudget('cat_food', 1000);

      final budgets = await repo.watchAllBudgets().first;
      expect(budgets.length, 1);
      expect(budgets.single.categoryId, 'cat_food');
      expect(budgets.single.monthlyLimit, 1000);
      expect(await repo.getBudgetForCategory('cat_food'), 1000);
    });

    test('setBudget upserts the same category', () async {
      await repo.setBudget('cat_food', 1000);
      await repo.setBudget('cat_food', 1200);

      final budgets = await repo.watchAllBudgets().first;
      expect(budgets.length, 1);
      expect(budgets.single.monthlyLimit, 1200);
    });

    test('getBudgetForCategory returns null when not set', () async {
      expect(await repo.getBudgetForCategory('cat_transport'), isNull);
    });

    test('deleteBudget removes the limit', () async {
      await repo.setBudget('cat_food', 1000);
      await repo.deleteBudget('cat_food');

      expect(await repo.getBudgetForCategory('cat_food'), isNull);
      expect(await repo.watchAllBudgets().first, isEmpty);
    });
  });
}
