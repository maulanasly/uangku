import 'package:flutter_test/flutter_test.dart';

import 'package:uangku/core/models/transaction_type.dart';
import 'package:uangku/core/utils/summary_calculator.dart';
import 'package:uangku/data/database/database.dart';

TransactionEntity _tx({
  required String id,
  required DateTime date,
  required double amount,
  required String category,
}) {
  return TransactionEntity(
    id: id,
    date: date,
    amount: amount,
    category: category,
    merchant: 'Merchant $id',
    note: '',
    type: TransactionType.expense,
  );
}

BudgetEntity _budget(String categoryId, double limit) {
  return BudgetEntity(id: 'budget_$categoryId', categoryId: categoryId, monthlyLimit: limit);
}

void main() {
  final month = DateTime(2026, 7);

  group('SummaryCalculator.forMonth', () {
    test('filters to the requested month', () {
      final transactions = [
        _tx(id: '1', date: DateTime(2026, 7, 10), amount: 50, category: 'cat_food'),
        _tx(id: '2', date: DateTime(2026, 6, 30), amount: 500, category: 'cat_food'),
        _tx(id: '3', date: DateTime(2026, 8, 1), amount: 500, category: 'cat_food'),
      ];

      final summary = SummaryCalculator.forMonth(transactions, month);

      expect(summary.totalSpent, 50);
    });

    test('computes total spent across categories', () {
      final transactions = [
        _tx(id: '1', date: DateTime(2026, 7, 1), amount: 200, category: 'cat_food'),
        _tx(id: '2', date: DateTime(2026, 7, 5), amount: 1500, category: 'cat_food'),
        _tx(id: '3', date: DateTime(2026, 7, 20), amount: 100, category: 'cat_transport'),
      ];

      final summary = SummaryCalculator.forMonth(transactions, month);

      expect(summary.totalSpent, 1800);
    });

    test('groups expenses by category', () {
      final transactions = [
        _tx(id: '1', date: DateTime(2026, 7, 1), amount: 40, category: 'cat_food'),
        _tx(id: '2', date: DateTime(2026, 7, 2), amount: 60, category: 'cat_food'),
        _tx(id: '3', date: DateTime(2026, 7, 3), amount: 30, category: 'cat_transport'),
      ];

      final summary = SummaryCalculator.forMonth(transactions, month);

      expect(summary.categoryBreakdown['cat_food'], 100);
      expect(summary.categoryBreakdown['cat_transport'], 30);
    });

    test('returns empty summary for a month with no transactions', () {
      final summary = SummaryCalculator.forMonth([], month);

      expect(summary.totalSpent, 0);
      expect(summary.categoryBreakdown, isEmpty);
    });
  });

  group('SummaryCalculator.budgetForMonth', () {
    test('computes spent, budget and remaining', () {
      final transactions = [
        _tx(id: '1', date: DateTime(2026, 7, 1), amount: 200, category: 'cat_food'),
        _tx(id: '2', date: DateTime(2026, 7, 5), amount: 300, category: 'cat_food'),
        _tx(id: '3', date: DateTime(2026, 7, 20), amount: 100, category: 'cat_transport'),
      ];
      final budgets = [
        _budget('cat_food', 1000),
        _budget('cat_transport', 500),
      ];

      final summary = SummaryCalculator.budgetForMonth(transactions, budgets, month);

      expect(summary.totalSpent, 600);
      expect(summary.totalBudget, 1500);
      expect(summary.remaining, 900);
      expect(summary.categoryBudget['cat_food'], 1000);
      expect(summary.categorySpent['cat_food'], 500);
    });

    test('reports negative remaining when over budget', () {
      final transactions = [
        _tx(id: '1', date: DateTime(2026, 7, 1), amount: 1200, category: 'cat_food'),
      ];
      final budgets = [_budget('cat_food', 1000)];

      final summary = SummaryCalculator.budgetForMonth(transactions, budgets, month);

      expect(summary.remaining, -200);
      expect(summary.spentRatio(), 1.2);
    });

    test('handles categories without a budget', () {
      final transactions = [
        _tx(id: '1', date: DateTime(2026, 7, 1), amount: 100, category: 'cat_food'),
      ];

      final summary = SummaryCalculator.budgetForMonth(transactions, const [], month);

      expect(summary.totalBudget, 0);
      expect(summary.spentRatio(), 0);
      expect(summary.remaining, -100);
    });
  });

  group('SummaryCalculator month helpers', () {
    test('isSameMonth compares year and month', () {
      expect(
        SummaryCalculator.isSameMonth(DateTime(2026, 7, 1), DateTime(2026, 7, 31)),
        isTrue,
      );
      expect(
        SummaryCalculator.isSameMonth(DateTime(2026, 7, 1), DateTime(2026, 8, 1)),
        isFalse,
      );
      expect(
        SummaryCalculator.isSameMonth(DateTime(2026, 7, 1), DateTime(2027, 7, 1)),
        isFalse,
      );
    });

    test('shiftMonth wraps across year boundaries', () {
      expect(SummaryCalculator.shiftMonth(DateTime(2026, 1), -1), DateTime(2025, 12));
      expect(SummaryCalculator.shiftMonth(DateTime(2026, 12), 1), DateTime(2027, 1));
      expect(SummaryCalculator.shiftMonth(DateTime(2026, 7), 3), DateTime(2026, 10));
    });

    test('filterByMonth returns only transactions in the given month', () {
      final transactions = [
        _tx(id: '1', date: DateTime(2026, 7, 10), amount: 50, category: 'cat_food'),
        _tx(id: '2', date: DateTime(2026, 6, 30), amount: 30, category: 'cat_food'),
        _tx(id: '3', date: DateTime(2026, 7, 1), amount: 40, category: 'cat_food'),
      ];

      final filtered = SummaryCalculator.filterByMonth(transactions, month);

      expect(filtered.map((t) => t.id), ['1', '3']);
    });
  });
}
