import '../../data/database/database.dart';
import '../models/transaction_type.dart';

class MonthlyTrend {
  final DateTime month;
  final double income;
  final double expense;

  const MonthlyTrend({
    required this.month,
    required this.income,
    required this.expense,
  });
}

class AnalyticsData {
  final List<MonthlyTrend> trends;
  final Map<String, double> categorySpending;
  final double totalIncome;
  final double totalExpense;

  const AnalyticsData({
    required this.trends,
    required this.categorySpending,
    required this.totalIncome,
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
      trends.add(MonthlyTrend(month: month, income: 0, expense: 0));
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
      if (t.type == TransactionType.income) {
        trends[idx] = MonthlyTrend(
          month: trends[idx].month,
          income: trends[idx].income + t.amount,
          expense: trends[idx].expense,
        );
      } else {
        trends[idx] = MonthlyTrend(
          month: trends[idx].month,
          income: trends[idx].income,
          expense: trends[idx].expense + t.amount,
        );
        categorySpending.update(t.category, (v) => v + t.amount, ifAbsent: () => t.amount);
      }
    }

    double totalIncome = 0;
    double totalExpense = 0;
    for (final trend in trends) {
      totalIncome += trend.income;
      totalExpense += trend.expense;
    }

    return AnalyticsData(
      trends: trends,
      categorySpending: categorySpending,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
    );
  }
}
