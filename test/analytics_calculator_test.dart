import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:uangku/core/models/transaction_type.dart';
import 'package:uangku/core/utils/analytics_calculator.dart';
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
  final now = DateTime.now();
  final thisMonth = DateTime(now.year, now.month);
  final lastMonth = DateTime(now.year, now.month - 1);

  group('AnalyticsCalculator.compute', () {
    test('aggregates expense per month within the window', () {
      final transactions = [
        _tx(id: '1', date: thisMonth, amount: 100, category: 'cat_food'),
        _tx(id: '3', date: lastMonth, amount: 50, category: 'cat_transport'),
        _tx(id: '4', date: DateTime(now.year - 1, now.month), amount: 500, category: 'cat_food'),
      ];

      final data = AnalyticsCalculator.compute(
        transactions,
        range: DateTimeRange(start: lastMonth, end: thisMonth),
      );

      expect(data.trends.length, 2);
      final currentTrend = data.trends.last;
      expect(currentTrend.expense, 100);
      expect(data.totalExpense, 150);
    });

    test('ignores transactions outside the window', () {
      final transactions = [
        _tx(
          id: '1',
          date: DateTime(now.year, now.month - 12),
          amount: 999,
          category: 'cat_food',
        ),
      ];

      final data = AnalyticsCalculator.compute(
        transactions,
        range: DateTimeRange(start: lastMonth, end: thisMonth),
      );

      expect(data.totalExpense, 0);
      expect(data.categorySpending, isEmpty);
    });

    test('groups category spending within the window', () {
      final transactions = [
        _tx(id: '1', date: thisMonth, amount: 40, category: 'cat_food'),
        _tx(id: '2', date: thisMonth, amount: 60, category: 'cat_food'),
        _tx(id: '3', date: lastMonth, amount: 30, category: 'cat_transport'),
      ];

      final data = AnalyticsCalculator.compute(
        transactions,
        range: DateTimeRange(start: lastMonth, end: thisMonth),
      );

      expect(data.categorySpending['cat_food'], 100);
      expect(data.categorySpending['cat_transport'], 30);
    });

    test('includes all transactions when range is null', () {
      final transactions = [
        _tx(id: '1', date: thisMonth, amount: 100, category: 'cat_food'),
        _tx(id: '2', date: DateTime(now.year - 2, now.month), amount: 250, category: 'cat_transport'),
      ];

      final data = AnalyticsCalculator.compute(transactions);

      expect(data.totalExpense, 350);
      expect(data.categorySpending['cat_transport'], 250);
      expect(data.trends.length, 25);
    });
  });
}
