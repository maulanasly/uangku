import 'package:drift/native.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:uangku/core/models/transaction_type.dart';
import 'package:uangku/data/database/database.dart';
import 'package:uangku/data/repositories/transaction_repository.dart';
import 'package:uangku/providers/database_provider.dart';
import 'package:uangku/ui/analytics/analytics_screen.dart';

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
        id: 'an-1',
        date: DateTime(now.year, now.month, 5),
        amount: 60,
        category: 'cat_food',
        merchant: 'Kopi Kenangan',
        note: '',
        type: TransactionType.expense,
      ),
    );
  }

  Future<void> pumpAnalytics(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
        child: const MaterialApp(home: AnalyticsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows donut chart and category breakdown', (tester) async {
    await seedCurrentMonthExpense();

    await pumpAnalytics(tester);

    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(find.text('Spending by Category'), findsOneWidget);
    expect(find.byType(PieChart), findsOneWidget);
    expect(find.text('Kopi Kenangan'), findsNothing);
    expect(find.text('Food & Dining'), findsOneWidget);
    expect(find.textContaining('Total'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('shows budget vs spent card when budgets exist', (tester) async {
    await seedCurrentMonthExpense();
    await repo.setBudget('cat_food', 100);

    await pumpAnalytics(tester);

    expect(find.text('Budget vs Spent'), findsOneWidget);
    expect(find.text('This month'), findsOneWidget);
    expect(find.textContaining('60'), findsWidgets);
    expect(find.textContaining('100'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('shows hint when no budgets are set', (tester) async {
    await seedCurrentMonthExpense();

    await pumpAnalytics(tester);

    expect(find.text('Budget vs Spent'), findsOneWidget);
    expect(
      find.text('Set monthly budgets in Settings > Budgets'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
  });
}
