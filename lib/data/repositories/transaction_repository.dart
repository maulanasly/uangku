import 'package:drift/drift.dart';
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

  Future<void> updateTransaction(TransactionEntity transaction) {
    return _db.update(_db.transactions).replace(transaction);
  }

  Future<void> deleteTransaction(String id) {
    return (_db.delete(_db.transactions)..where((t) => t.id.equals(id))).go();
  }
}
