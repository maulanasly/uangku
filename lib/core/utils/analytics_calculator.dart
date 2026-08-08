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
  static AnalyticsData compute(List<TransactionEntity> transactions, {int months = 6}) {
    final now = DateTime.now();
    final current = DateTime(now.year, now.month);

    final trends = <MonthlyTrend>[];
    for (var i = months - 1; i >= 0; i--) {
      final month = DateTime(current.year, current.month - i);
      trends.add(MonthlyTrend(month: month, expense: 0));
    }

    final Map<String, double> categorySpending = {};
    final Map<int, int> trendIndex = {
      for (var i = 0; i < trends.length; i++)
        (trends[i].month.year * 100 + trends[i].month.month): i,
    };

    for (final t in transactions) {
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
