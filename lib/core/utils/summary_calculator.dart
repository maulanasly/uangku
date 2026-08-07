import '../../data/database/database.dart';
import '../models/transaction_type.dart';

class MonthlySummary {
  final double income;
  final double expense;
  final double balance;
  final Map<String, double> categoryBreakdown;

  const MonthlySummary({
    required this.income,
    required this.expense,
    required this.balance,
    required this.categoryBreakdown,
  });
}

class SummaryCalculator {
  static MonthlySummary forMonth(List<TransactionEntity> transactions, DateTime month) {
    double income = 0;
    double expense = 0;
    final Map<String, double> breakdown = {};

    for (final t in transactions) {
      if (!isSameMonth(t.date, month)) {
        continue;
      }
      if (t.type == TransactionType.income) {
        income += t.amount;
      } else {
        expense += t.amount;
        breakdown.update(t.category, (v) => v + t.amount, ifAbsent: () => t.amount);
      }
    }

    return MonthlySummary(
      income: income,
      expense: expense,
      balance: income - expense,
      categoryBreakdown: breakdown,
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
}
