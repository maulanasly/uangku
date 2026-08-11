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

  Future<void> seedExpenseWithItems({
    required String id,
    required DateTime date,
    required double amount,
    required String category,
    required List<({String name, double total})> items,
  }) async {
    final companion = TransactionsCompanion.insert(
      id: id,
      date: date,
      amount: amount,
      category: category,
      merchant: 'Merchant $id',
      note: '',
      type: TransactionType.expense,
    );
    if (items.isEmpty) {
      await repo.addTransaction(companion);
      return;
    }
    await repo.addTransactionWithItems(
      companion,
      [
        for (var i = 0; i < items.length; i++)
          TransactionItemsCompanion.insert(
            id: '$id-item$i',
            transactionId: id,
            name: items[i].name,
            total: items[i].total,
          ),
      ],
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

    await tester.drag(find.byType(ListView), const Offset(0, -100));
    await tester.pumpAndSettle();

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

    await tester.drag(find.byType(ListView), const Offset(0, -100));
    await tester.pumpAndSettle();

    expect(find.text('Budget vs Spent'), findsOneWidget);
    expect(
      find.text('Set monthly budgets in Settings > Budgets'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('shows expense vs budget legend when budgets exist', (tester) async {
    await seedCurrentMonthExpense();
    await repo.setBudget('cat_food', 100);

    await pumpAnalytics(tester);

    expect(find.text('Spending vs Budget'), findsOneWidget);
    expect(find.text('Expense'), findsOneWidget);
    expect(find.text('Budget'), findsOneWidget);
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData.length, 2);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('hides budget line when no budgets are set', (tester) async {
    await seedCurrentMonthExpense();

    await pumpAnalytics(tester);

    expect(find.text('Spending vs Budget'), findsOneWidget);
    expect(find.text('Expense'), findsOneWidget);
    expect(find.text('Budget'), findsNothing);
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData.length, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('shows top items by category when items exist', (tester) async {
    final now = DateTime.now();
    await seedExpenseWithItems(
      id: 'ti-1',
      date: DateTime(now.year, now.month, 3),
      amount: 100,
      category: 'cat_food',
      items: [
        (name: 'Nasi Goreng', total: 45),
        (name: 'Ayam Bakar', total: 35),
        (name: 'Es Teh', total: 20),
      ],
    );

    await pumpAnalytics(tester);

    await tester.drag(find.byType(ListView), const Offset(0, -1400));
    await tester.pumpAndSettle();

    expect(find.text('Top Items by Category'), findsOneWidget);
    expect(find.text('No item data yet'), findsNothing);

    await tester.tap(find.widgetWithText(ExpansionTile, 'Food & Dining'));
    await tester.pumpAndSettle();

    expect(find.text('Nasi Goreng'), findsOneWidget);
    expect(find.text('Ayam Bakar'), findsOneWidget);
    expect(find.text('Es Teh'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('shows no item data hint when transactions have no items', (tester) async {
    await seedCurrentMonthExpense();

    await pumpAnalytics(tester);

    await tester.drag(find.byType(ListView), const Offset(0, -1400));
    await tester.pumpAndSettle();

    expect(find.text('Top Items by Category'), findsOneWidget);
    expect(find.text('No item data yet'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('shows category trend delta for period vs previous period', (tester) async {
    final now = DateTime.now();
    await seedExpenseWithItems(
      id: 'tr-cur',
      date: DateTime(now.year, now.month, 3),
      amount: 100,
      category: 'cat_food',
      items: [(name: 'Nasi Goreng', total: 100)],
    );
    await repo.addTransaction(
      TransactionsCompanion.insert(
        id: 'tr-prev',
        date: DateTime(now.year, now.month - 9, 10),
        amount: 40,
        category: 'cat_food',
        merchant: 'Prev Shop',
        note: '',
        type: TransactionType.expense,
      ),
    );

    await pumpAnalytics(tester);

    await tester.tap(find.text('6mo'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -1800));
    await tester.pumpAndSettle();

    expect(find.text('Category Trend'), findsOneWidget);
    expect(find.textContaining(' vs '), findsOneWidget);
    expect(find.text('↑ 150%'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('shows range chips and filters spending by preset', (tester) async {
    final now = DateTime.now();
    await seedCurrentMonthExpense();
    await repo.addTransaction(
      TransactionsCompanion.insert(
        id: 'tr-old',
        date: DateTime(now.year, now.month - 2, 10),
        amount: 200,
        category: 'cat_food',
        merchant: 'Old Shop',
        note: '',
        type: TransactionType.expense,
      ),
    );

    await pumpAnalytics(tester);

    expect(find.text('All time'), findsWidgets);
    expect(find.text('30d'), findsOneWidget);
    expect(find.text('90d'), findsOneWidget);
    expect(find.text('6mo'), findsOneWidget);
    expect(find.text('This year'), findsOneWidget);
    expect(find.text('Custom'), findsOneWidget);

    await tester.tap(find.text('30d'));
    await tester.pumpAndSettle();

    expect(find.text('Last 30 days'), findsOneWidget);
    expect(find.text('No spending in this period'), findsNothing);
    expect(find.textContaining('60'), findsWidgets);
    expect(find.textContaining('200'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
  });

  testWidgets('shows empty state when preset filters out all spending', (tester) async {
    final now = DateTime.now();
    await repo.addTransaction(
      TransactionsCompanion.insert(
        id: 'tr-old',
        date: DateTime(now.year, now.month - 2, 10),
        amount: 200,
        category: 'cat_food',
        merchant: 'Old Shop',
        note: '',
        type: TransactionType.expense,
      ),
    );

    await pumpAnalytics(tester);

    await tester.tap(find.text('30d'));
    await tester.pumpAndSettle();

    expect(find.text('No spending in this period'), findsOneWidget);
    expect(find.text('Reset filter'), findsOneWidget);

    await tester.tap(find.text('Reset filter'));
    await tester.pumpAndSettle();

    expect(find.text('No spending in this period'), findsNothing);
    expect(find.text('All time'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 10));
  });
}
