import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:uangku/core/models/transaction_type.dart';
import 'package:uangku/data/database/database.dart';
import 'package:uangku/data/repositories/transaction_repository.dart';
import 'package:uangku/providers/database_provider.dart';
import 'package:uangku/ui/prices/item_price_detail_screen.dart';

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
        id: 'd-1',
        date: DateTime(2026, 1, 5),
        amount: 130,
        category: 'cat_food',
        merchant: 'Alfamart',
        note: '',
        type: TransactionType.expense,
      ),
      [
        TransactionItemsCompanion.insert(
          id: 'd-1-i0',
          transactionId: 'd-1',
          name: 'Milo',
          quantity: const Value<double>(2),
          total: 30.0,
          unitPrice: const Value<double>(15),
        ),
      ],
    );
    await repo.addTransactionWithItems(
      TransactionsCompanion.insert(
        id: 'd-2',
        date: DateTime(2026, 2, 10),
        amount: 20,
        category: 'cat_food',
        merchant: 'Indomaret',
        note: '',
        type: TransactionType.expense,
      ),
      [
        TransactionItemsCompanion.insert(
          id: 'd-2-i0',
          transactionId: 'd-2',
          name: 'milo',
          quantity: const Value<double>(1),
          total: 18.0,
          unitPrice: const Value<double>(18),
        ),
      ],
    );
  }

  Future<void> pumpDetail(WidgetTester tester, {String itemName = 'Milo'}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          home: ItemPriceDetailScreen(itemName: itemName),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows price chart and purchase rows', (tester) async {
    await seedHistory();

    await pumpDetail(tester);

    expect(find.text('Milo'), findsOneWidget);
    expect(find.text('Price over time'), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);
    expect(find.text('2 purchases'), findsOneWidget);
    expect(find.text('Alfamart'), findsOneWidget);
    expect(find.text('Indomaret'), findsOneWidget);
    expect(find.text('total 30'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('single purchase hides the chart', (tester) async {
    await repo.addTransactionWithItems(
      TransactionsCompanion.insert(
        id: 'd-3',
        date: DateTime(2026, 1, 5),
        amount: 10,
        category: 'cat_food',
        merchant: 'Alfamart',
        note: '',
        type: TransactionType.expense,
      ),
      [
        TransactionItemsCompanion.insert(
          id: 'd-3-i0',
          transactionId: 'd-3',
          name: 'Roti',
          quantity: const Value<double>(1),
          total: 10.0,
        ),
      ],
    );

    await pumpDetail(tester, itemName: 'Roti');

    expect(find.byType(LineChart), findsNothing);
    expect(find.text('1 purchase'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
  });
}