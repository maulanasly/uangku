import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:uangku/data/database/database.dart';
import 'package:uangku/data/repositories/transaction_repository.dart';
import 'package:uangku/providers/database_provider.dart';
import 'package:uangku/ui/transactions/add_transaction_screen.dart';

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

  Finder field(String label) {
    final decorator = find.byWidgetPredicate(
      (w) => w is InputDecorator && w.decoration.labelText == label,
    );
    return find.ancestor(of: decorator, matching: find.byType(TextFormField));
  }

  testWidgets('saves a transaction with multiple items and auto-summed total', (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('home')),
        ),
        GoRoute(
          path: '/add_transaction',
          builder: (context, state) => const AddTransactionScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    router.push('/add_transaction');
    await tester.pumpAndSettle();

    await tester.enterText(field('Merchant / Title'), 'Toko Makmur');

    // First item: weight-based.
    await tester.enterText(field('Item name'), 'Apples');
    await tester.enterText(field('Weight (kg)'), '2.5');
    await tester.enterText(field('Qty'), '2');
    await tester.enterText(field('Unit price'), '30');
    await tester.pump();

    // Second item.
    await tester.tap(find.text('Add Item'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Item name').at(1), 'Bread');
    await tester.enterText(field('Qty').at(1), '1');
    await tester.enterText(field('Unit price').at(1), '4.5');
    await tester.pump();

    await tester.ensureVisible(find.text('Save Transaction'));
    await tester.tap(find.text('Save Transaction'));
    await tester.pumpAndSettle();

    final result = await tester.runAsync<
        ({TransactionEntity tx, List<TransactionItemEntity> items})>(() async {
      final transactions = await repo.watchAllTransactions().first;
      final transaction = transactions.single;
      final itemList = await repo.watchItemsFor(transaction.id).first;
      return (tx: transaction, items: itemList);
    });
    expect(result, isNotNull);
    final tx = result!.tx;
    final items = result.items;

    expect(tx.merchant, 'Toko Makmur');
    expect(tx.amount, 64.5);
    expect(tx.category, 'cat_food');
    expect(tx.type.name, 'expense');

    expect(items.length, 2);
    expect(items[0].name, 'Apples');
    expect(items[0].quantity, 2);
    expect(items[0].weight, 2.5);
    expect(items[0].unitPrice, 30);
    expect(items[0].total, 60);
    expect(items[1].name, 'Bread');
    expect(items[1].total, 4.5);
    expect(items[1].weight, isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
  });
}
