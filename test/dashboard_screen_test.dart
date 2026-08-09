import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:uangku/core/models/transaction_type.dart';
import 'package:uangku/data/database/database.dart';
import 'package:uangku/data/repositories/transaction_repository.dart';
import 'package:uangku/providers/database_provider.dart';
import 'package:uangku/ui/dashboard/dashboard_screen.dart';
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

  Future<void> seedCurrentMonthExpense() async {
    final now = DateTime.now();
    await repo.addTransaction(
      TransactionsCompanion.insert(
        id: 'dash-1',
        date: DateTime(now.year, now.month, 1),
        amount: 50,
        category: 'cat_food',
        merchant: 'Starbucks',
        note: '',
        type: TransactionType.expense,
      ),
    );
    await repo.setBudget('cat_food', 1000);
  }

  testWidgets('renders spending-by-category bars and recent transactions', (tester) async {
    await seedCurrentMonthExpense();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Spending by Category'), findsOneWidget);
    expect(find.text('Recent Transactions'), findsOneWidget);
    expect(find.text('Starbucks'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('undoing a swipe-delete restores the transaction with its items', (tester) async {
    final now = DateTime.now();
    await repo.addTransactionWithItems(
      TransactionsCompanion.insert(
        id: 'dash-2',
        date: DateTime(now.year, now.month, 2),
        amount: 50,
        category: 'cat_food',
        merchant: 'Starbucks',
        note: '',
        type: TransactionType.expense,
      ),
      [
        TransactionItemsCompanion.insert(
          id: 'dash-2-item',
          transactionId: 'dash-2',
          name: 'Latte',
          total: 50,
          quantity: const Value(1),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Starbucks'), findsOneWidget);

    final restoredItems = await tester.runAsync(() async {
      await tester.drag(find.text('Starbucks'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.text('Transaction deleted'), findsOneWidget);
      expect(find.text('Starbucks'), findsNothing);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      return repo.watchItemsFor('dash-2').first;
    });

    expect(restoredItems!.length, 1);
    expect(restoredItems.first.name, 'Latte');
    expect(find.text('Starbucks'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
  });
}
