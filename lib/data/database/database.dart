import 'package:drift/drift.dart';

import 'tables.dart';
import '../../core/models/transaction_type.dart';
import 'connection/connection.dart' as impl;

part 'database.g.dart';

@DriftDatabase(tables: [Categories, Transactions, TransactionItems])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? impl.openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();

        // Seed default categories
        await batch((batch) {
          batch.insertAll(categories, [
            CategoriesCompanion.insert(
              id: 'cat_food',
              name: 'Food & Dining',
              icon: 'restaurant',
            ),
            CategoriesCompanion.insert(
              id: 'cat_transport',
              name: 'Transportation',
              icon: 'directions_car',
            ),
            CategoriesCompanion.insert(
              id: 'cat_salary',
              name: 'Salary',
              icon: 'payments',
            ),
          ]);
        });
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.createTable(transactionItems);
        }
      },
    );
  }
}

