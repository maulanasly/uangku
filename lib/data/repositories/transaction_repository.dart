import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/database.dart';
import '../../core/models/transaction_query.dart';

class TransactionRepository {
  final AppDatabase _db;

  TransactionRepository(this._db);

  // Categories
  Future<List<CategoryEntity>> getCategories() => _db.select(_db.categories).get();

  Future<void> addCategory(CategoriesCompanion category) => _db.into(_db.categories).insert(category);

  Future<void> updateCategory(CategoryEntity category) {
    return _db.update(_db.categories).replace(category);
  }

  Future<void> deleteCategory(String id) {
    return (_db.delete(_db.categories)..where((c) => c.id.equals(id))).go();
  }

  // Transactions
  Stream<List<TransactionEntity>> watchAllTransactions() {
    final query = _db.select(_db.transactions)
      ..orderBy([(t) => OrderingTerm.desc(t.date)]);
    return query.watch();
  }

  Stream<List<TransactionEntity>> watchTransactions(TransactionQuery query) {
    final q = _db.select(_db.transactions);

    if (query.search.isNotEmpty) {
      final pattern = '%${query.search.toLowerCase()}%';
      q.where(
        (t) => t.merchant.lower().like(pattern) | t.note.lower().like(pattern),
      );
    }
    if (query.type != null) {
      q.where((t) => t.type.equalsValue(query.type!));
    }
    if (query.category != null) {
      q.where((t) => t.category.equals(query.category!));
    }

    q.orderBy([
      (t) {
        final column = query.sortField == TransactionSortField.amount ? t.amount : t.date;
        return query.direction == SortDirection.asc
            ? OrderingTerm.asc(column)
            : OrderingTerm.desc(column);
      },
    ]);

    return q.watch();
  }

  Future<void> addTransaction(Insertable<TransactionEntity> transaction) {
    return _db.into(_db.transactions).insert(transaction);
  }

  Future<void> addTransactionWithItems(
    Insertable<TransactionEntity> transaction,
    List<TransactionItemsCompanion> items,
  ) {
    return _db.transaction(() async {
      await _db.into(_db.transactions).insert(transaction);
      for (final item in items) {
        await _db.into(_db.transactionItems).insert(item);
      }
    });
  }

  Stream<List<TransactionItemEntity>> watchItemsFor(String transactionId) {
    return (_db.select(_db.transactionItems)
          ..where((t) => t.transactionId.equals(transactionId))
          ..orderBy([(t) => OrderingTerm.asc(t.position)]))
        .watch();
  }

  Future<void> updateTransaction(TransactionEntity transaction) {
    return _db.update(_db.transactions).replace(transaction);
  }

  Future<void> deleteTransaction(String id) {
    return (_db.delete(_db.transactions)..where((t) => t.id.equals(id))).go();
  }

  Future<void> resetData() {
    return _db.transaction(() async {
      await _db.delete(_db.transactionItems).go();
      await _db.delete(_db.transactions).go();
    });
  }

  // Budgets
  Stream<List<BudgetEntity>> watchAllBudgets() => _db.select(_db.budgets).watch();

  Future<double?> getBudgetForCategory(String categoryId) async {
    final budget = await (_db.select(_db.budgets)
          ..where((b) => b.categoryId.equals(categoryId)))
        .getSingleOrNull();
    return budget?.monthlyLimit;
  }

  Future<void> setBudget(String categoryId, double monthlyLimit) async {
    final existing = await (_db.select(_db.budgets)
          ..where((b) => b.categoryId.equals(categoryId)))
        .getSingleOrNull();
    if (existing == null) {
      await _db.into(_db.budgets).insert(
            BudgetsCompanion.insert(
              id: const Uuid().v4(),
              categoryId: categoryId,
              monthlyLimit: monthlyLimit,
            ),
          );
    } else {
      await (_db.update(_db.budgets)..where((b) => b.categoryId.equals(categoryId)))
          .write(BudgetsCompanion(monthlyLimit: Value(monthlyLimit)));
    }
  }

  Future<void> deleteBudget(String categoryId) {
    return (_db.delete(_db.budgets)..where((b) => b.categoryId.equals(categoryId))).go();
  }
}
