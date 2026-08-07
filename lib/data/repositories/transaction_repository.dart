import 'package:drift/drift.dart';
import '../database/database.dart';

class TransactionRepository {
  final AppDatabase _db;

  TransactionRepository(this._db);

  // Categories
  Future<List<CategoryEntity>> getCategories() => _db.select(_db.categories).get();
  
  Future<void> addCategory(CategoriesCompanion category) => _db.into(_db.categories).insert(category);

  // Transactions
  Stream<List<TransactionEntity>> watchAllTransactions() {
    final query = _db.select(_db.transactions)
      ..orderBy([(t) => OrderingTerm.desc(t.date)]);
    return query.watch();
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
