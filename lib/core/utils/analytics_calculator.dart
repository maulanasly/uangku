import 'package:flutter/material.dart';

import '../../data/database/database.dart';

class MonthlyTrend {
  final DateTime month;
  final double expense;

  const MonthlyTrend({
    required this.month,
    required this.expense,
  });
}

class AnalyticsData {
  final List<MonthlyTrend> trends;
  final Map<String, double> categorySpending;
  final double totalExpense;

  const AnalyticsData({
    required this.trends,
    required this.categorySpending,
    required this.totalExpense,
  });
}

class AnalyticsCalculator {
  /// Computes monthly expense trends and category spending for the given
  /// transactions. When [range] is null, all transactions are bucketed by
  /// month from the earliest to the latest transaction. When a range is
  /// provided, only transactions within it count.
  static AnalyticsData compute(
    List<TransactionEntity> transactions, {
    DateTimeRange? range,
  }) {
    final start = range?.start;
    final end = range?.end;

    DateTime first;
    DateTime last;
    if (range != null) {
      first = DateTime(range.start.year, range.start.month);
      last = DateTime(range.end.year, range.end.month);
    } else if (transactions.isEmpty) {
      final now = DateTime.now();
      first = DateTime(now.year, now.month);
      last = first;
    } else {
      var minDate = transactions.first.date;
      var maxDate = transactions.first.date;
      for (final t in transactions) {
        if (t.date.isBefore(minDate)) {
          minDate = t.date;
        }
        if (t.date.isAfter(maxDate)) {
          maxDate = t.date;
        }
      }
      first = DateTime(minDate.year, minDate.month);
      last = DateTime(maxDate.year, maxDate.month);
    }

    final trends = <MonthlyTrend>[];
    var month = first;
    while (!month.isAfter(last)) {
      trends.add(MonthlyTrend(month: month, expense: 0));
      month = DateTime(month.year, month.month + 1);
    }

    final Map<String, double> categorySpending = {};
    final Map<int, int> trendIndex = {
      for (var i = 0; i < trends.length; i++)
        (trends[i].month.year * 100 + trends[i].month.month): i,
    };

    for (final t in transactions) {
      if (start != null && t.date.isBefore(start)) {
        continue;
      }
      if (end != null && t.date.isAfter(end)) {
        continue;
      }
      final key = t.date.year * 100 + t.date.month;
      final idx = trendIndex[key];
      if (idx == null) {
        continue;
      }
      trends[idx] = MonthlyTrend(
        month: trends[idx].month,
        expense: trends[idx].expense + t.amount,
      );
      categorySpending.update(t.category, (v) => v + t.amount, ifAbsent: () => t.amount);
    }

    double totalExpense = 0;
    for (final trend in trends) {
      totalExpense += trend.expense;
    }

    return AnalyticsData(
      trends: trends,
      categorySpending: categorySpending,
      totalExpense: totalExpense,
    );
  }
}
