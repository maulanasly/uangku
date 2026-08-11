import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:uangku/core/models/transaction_type.dart';
import 'package:uangku/data/database/database.dart';
import 'package:uangku/data/repositories/transaction_repository.dart';
import 'package:uangku/providers/database_provider.dart';
import 'package:uangku/router/app_router.dart';
import 'package:uangku/ui/analytics/analytics_screen.dart';
import 'package:uangku/ui/prices/item_price_detail_screen.dart';
import 'package:uangku/ui/prices/item_price_history_screen.dart';
import 'package:uangku/ui/settings/settings_screen.dart';

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

  Future<void> seedItems() async {
    await repo.addTransactionWithItems(
      TransactionsCompanion.insert(
        id: 'n-1',
        date: DateTime.now().subtract(const Duration(days: 3)),
        amount: 30,
        category: 'cat_food',
        merchant: 'Alfamart',
        note: '',
        type: TransactionType.expense,
      ),
      [
        TransactionItemsCompanion.insert(
          id: 'n-1-i0',
          transactionId: 'n-1',
          name: 'Milo',
          quantity: const Value<double>(2),
          total: 30.0,
          unitPrice: const Value<double>(15),
        ),
      ],
    );
  }

  Future<void> pumpRouter(WidgetTester tester, String initial) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp.router(
          routerConfig: appRouter,
        ),
      ),
    );
    if (initial != '/') {
      appRouter.go(initial);
      await tester.pumpAndSettle();
    }
  }

  testWidgets('item price history opens from top items card', (tester) async {
    await seedItems();

    await pumpRouter(tester, '/analytics');

    await tester.pumpAndSettle();

    expect(find.byType(AnalyticsScreen), findsOneWidget);

    await tester.drag(find.byType(ListView).first, const Offset(0, -1400));
    await tester.pumpAndSettle();

    await tester.tap(find.text('View price history'));
    await tester.pumpAndSettle();

    expect(find.byType(ItemPriceHistoryScreen), findsOneWidget);
    expect(find.text('Milo'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('item price history opens from settings', (tester) async {
    await seedItems();

    await pumpRouter(tester, '/settings');

    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);

    await tester.tap(find.text('Item Price History'));
    await tester.pumpAndSettle();

    expect(find.byType(ItemPriceHistoryScreen), findsOneWidget);
    expect(find.text('Milo'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('history row opens the item detail screen', (tester) async {
    await seedItems();

    await pumpRouter(tester, '/item_prices');

    expect(find.byType(ItemPriceHistoryScreen), findsOneWidget);
    expect(find.text('Milo'), findsOneWidget);

    await tester.tap(find.text('Milo'));
    await tester.pumpAndSettle();

    expect(find.byType(ItemPriceDetailScreen), findsOneWidget);
    expect(find.text('Alfamart'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
  });
}