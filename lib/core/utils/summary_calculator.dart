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
      if (t.date.year != month.year || t.date.month != month.month) {
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
}
