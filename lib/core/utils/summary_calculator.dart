import '../../data/database/database.dart';

class MonthlySummary {
  final double totalSpent;
  final Map<String, double> categoryBreakdown;

  const MonthlySummary({
    required this.totalSpent,
    required this.categoryBreakdown,
  });
}

class BudgetSummary {
  final double totalSpent;
  final double totalBudget;
  final double remaining;
  final Map<String, double> categorySpent;
  final Map<String, double> categoryBudget;

  const BudgetSummary({
    required this.totalSpent,
    required this.totalBudget,
    required this.remaining,
    required this.categorySpent,
    required this.categoryBudget,
  });

  double spentRatio() {
    if (totalBudget <= 0) return 0;
    return totalSpent / totalBudget;
  }
}

class SummaryCalculator {
  static MonthlySummary forMonth(List<TransactionEntity> transactions, DateTime month) {
    double totalSpent = 0;
    final Map<String, double> breakdown = {};

    for (final t in transactions) {
      if (!isSameMonth(t.date, month)) {
        continue;
      }
      totalSpent += t.amount;
      breakdown.update(t.category, (v) => v + t.amount, ifAbsent: () => t.amount);
    }

    return MonthlySummary(
      totalSpent: totalSpent,
      categoryBreakdown: breakdown,
    );
  }

  static BudgetSummary budgetForMonth(
    List<TransactionEntity> transactions,
    List<BudgetEntity> budgets,
    DateTime month,
  ) {
    final monthly = forMonth(transactions, month);
    final Map<String, double> categoryBudget = {
      for (final b in budgets) b.categoryId: b.monthlyLimit,
    };
    final totalBudget = categoryBudget.values.fold<double>(0, (a, b) => a + b);

    return BudgetSummary(
      totalSpent: monthly.totalSpent,
      totalBudget: totalBudget,
      remaining: totalBudget - monthly.totalSpent,
      categorySpent: monthly.categoryBreakdown,
      categoryBudget: categoryBudget,
    );
  }

  static bool isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }

  static DateTime shiftMonth(DateTime month, int delta) {
    return DateTime(month.year, month.month + delta);
  }

  static List<TransactionEntity> filterByMonth(
    List<TransactionEntity> transactions,
    DateTime month,
  ) {
    return transactions.where((t) => isSameMonth(t.date, month)).toList();
  }

  static int daysInMonth(DateTime month) {
    return DateTime(month.year, month.month + 1, 0).day;
  }

  static int daysLeftInMonth(DateTime date) {
    final daysLeft = daysInMonth(date) - date.day + 1;
    return daysLeft < 1 ? 1 : daysLeft;
  }

  static double dailyAllowance(double remaining, DateTime today) {
    return remaining / daysLeftInMonth(today);
  }
}
