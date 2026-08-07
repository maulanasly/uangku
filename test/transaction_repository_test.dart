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
}
