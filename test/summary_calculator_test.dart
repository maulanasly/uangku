import 'package:flutter_test/flutter_test.dart';

import 'package:uangku/core/models/transaction_type.dart';
import 'package:uangku/core/utils/summary_calculator.dart';
import 'package:uangku/data/database/database.dart';

TransactionEntity _tx({
  required String id,
  required DateTime date,
  required double amount,
  required String category,
  TransactionType type = TransactionType.expense,
}) {
  return TransactionEntity(
    id: id,
    date: date,
    amount: amount,
    category: category,
    merchant: 'Merchant $id',
    note: '',
    type: type,
  );
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

      expect(summary.expense, 50);
    });

    test('computes income, expense and balance', () {
      final transactions = [
        _tx(
          id: '1',
          date: DateTime(2026, 7, 1),
          amount: 200,
          category: 'cat_food',
        ),
        _tx(
          id: '2',
          date: DateTime(2026, 7, 5),
          amount: 1500,
          category: 'cat_salary',
          type: TransactionType.income,
        ),
        _tx(
          id: '3',
          date: DateTime(2026, 7, 20),
          amount: 100,
          category: 'cat_transport',
        ),
      ];

      final summary = SummaryCalculator.forMonth(transactions, month);

      expect(summary.income, 1500);
      expect(summary.expense, 300);
      expect(summary.balance, 1200);
    });

    test('groups expenses by category', () {
      final transactions = [
        _tx(id: '1', date: DateTime(2026, 7, 1), amount: 40, category: 'cat_food'),
        _tx(id: '2', date: DateTime(2026, 7, 2), amount: 60, category: 'cat_food'),
        _tx(id: '3', date: DateTime(2026, 7, 3), amount: 30, category: 'cat_transport'),
        _tx(id: '4', date: DateTime(2026, 7, 4), amount: 5000, category: 'cat_salary', type: TransactionType.income),
      ];

      final summary = SummaryCalculator.forMonth(transactions, month);

      expect(summary.categoryBreakdown['cat_food'], 100);
      expect(summary.categoryBreakdown['cat_transport'], 30);
      expect(summary.categoryBreakdown.containsKey('cat_salary'), isFalse);
    });

    test('returns empty summary for a month with no transactions', () {
      final summary = SummaryCalculator.forMonth([], month);

      expect(summary.income, 0);
      expect(summary.expense, 0);
      expect(summary.balance, 0);
      expect(summary.categoryBreakdown, isEmpty);
    });
  });
}
