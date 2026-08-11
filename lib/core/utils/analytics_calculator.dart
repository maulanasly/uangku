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

  /// True when [trends] is bucketed by calendar day (short ranges),
  /// false when bucketed by calendar month.
  final bool isDaily;

  const AnalyticsData({
    required this.trends,
    required this.categorySpending,
    required this.totalExpense,
    this.isDaily = false,
  });
}

class AnalyticsCalculator {
  /// Computes monthly expense trends and category spending for the given
  /// transactions. When [range] is null, all transactions are bucketed by
  /// month from the earliest to the latest transaction. When a range is
  /// provided, only transactions within it count.
  /// Ranges spanning at most this many days are bucketed by calendar day so
  /// short windows (e.g. last 30 days) render a meaningful line chart instead
  /// of one or two monthly points.
  static const int dailyBucketThresholdDays = 60;

  static AnalyticsData compute(
    List<TransactionEntity> transactions, {
    DateTimeRange? range,
  }) {
    final start = range?.start;
    final end = range?.end;
    final isDaily = range != null &&
        range.end.difference(range.start).inDays <= dailyBucketThresholdDays;

    DateTime first;
    DateTime last;
    int Function(DateTime) keyFor;
    DateTime Function(DateTime current) advancedBy;

    if (isDaily) {
      final start = range.start;
      final end = range.end;
      first = DateTime(start.year, start.month, start.day);
      last = DateTime(end.year, end.month, end.day);
      keyFor = (d) => d.year * 10000 + d.month * 100 + d.day;
      advancedBy = (c) => DateTime(c.year, c.month, c.day + 1);
    } else if (range != null) {
      first = DateTime(range.start.year, range.start.month);
      last = DateTime(range.end.year, range.end.month);
      keyFor = (d) => d.year * 100 + d.month;
      advancedBy = (c) => DateTime(c.year, c.month + 1);
    } else if (transactions.isEmpty) {
      final now = DateTime.now();
      first = DateTime(now.year, now.month);
      last = first;
      keyFor = (d) => d.year * 100 + d.month;
      advancedBy = (c) => DateTime(c.year, c.month + 1);
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
      keyFor = (d) => d.year * 100 + d.month;
      advancedBy = (c) => DateTime(c.year, c.month + 1);
    }

    final trends = <MonthlyTrend>[];
    var bucket = first;
    while (!bucket.isAfter(last)) {
      trends.add(MonthlyTrend(month: bucket, expense: 0));
      bucket = advancedBy(bucket);
    }

    final Map<String, double> categorySpending = {};
    final Map<int, int> trendIndex = {
      for (var i = 0; i < trends.length; i++)
        keyFor(trends[i].month): i,
    };

    for (final t in transactions) {
      if (start != null && t.date.isBefore(start)) {
        continue;
      }
      if (end != null && t.date.isAfter(end)) {
        continue;
      }
      final idx = trendIndex[keyFor(t.date)];
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
      isDaily: isDaily,
    );
  }
}
