import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:uangku/core/models/transaction_type.dart';
import 'package:uangku/data/database/database.dart';
import 'package:uangku/data/repositories/transaction_repository.dart';
import 'package:uangku/providers/database_provider.dart';
import 'package:uangku/ui/prices/item_price_history_screen.dart';

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

  Future<void> seedHistory() async {
    await repo.addTransactionWithItems(
      TransactionsCompanion.insert(
        id: 'h-1',
        date: DateTime(2026, 1, 5),
        amount: 130,
        category: 'cat_food',
        merchant: 'Alfamart',
        note: '',
        type: TransactionType.expense,
      ),
      [
        TransactionItemsCompanion.insert(
          id: 'h-1-i0',
          transactionId: 'h-1',
          name: 'Milo',
          quantity: const Value<double>(2),
          total: 30.0,
          unitPrice: const Value<double>(15),
        ),
        TransactionItemsCompanion.insert(
          id: 'h-1-i1',
          transactionId: 'h-1',
          name: 'Roti',
          quantity: const Value<double>(1),
          total: 100.0,
        ),
      ],
    );
    await repo.addTransactionWithItems(
      TransactionsCompanion.insert(
        id: 'h-2',
        date: DateTime(2026, 2, 10),
        amount: 20,
        category: 'cat_food',
        merchant: 'Indomaret',
        note: '',
        type: TransactionType.expense,
      ),
      [
        TransactionItemsCompanion.insert(
          id: 'h-2-i0',
          transactionId: 'h-2',
          name: 'milo',
          quantity: const Value<double>(1),
          total: 18.0,
          unitPrice: const Value<double>(18),
        ),
      ],
    );
  }

  Future<void> pumpHistory(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
        child: const MaterialApp(home: ItemPriceHistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists aggregated items with purchase counts', (tester) async {
    await seedHistory();

    await pumpHistory(tester);

    expect(find.text('Item Price History'), findsOneWidget);
    expect(find.text('Milo'), findsOneWidget);
    expect(find.text('Roti'), findsOneWidget);
    expect(find.textContaining('2x'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('filters items by search query', (tester) async {
    await seedHistory();

    await pumpHistory(tester);

    await tester.enterText(find.byType(TextField), 'mil');
    await tester.pumpAndSettle();

    expect(find.text('Milo'), findsOneWidget);
    expect(find.text('Roti'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('shows no match message for unknown search', (tester) async {
    await seedHistory();

    await pumpHistory(tester);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();

    expect(find.textContaining('No items match'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
  });
}