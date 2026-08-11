import '../../data/database/database.dart';
import 'summary_calculator.dart';

class CategoryItemStat {
  final String name;
  final double total;
  final int purchaseCount;

  const CategoryItemStat({
    required this.name,
    required this.total,
    required this.purchaseCount,
  });
}

class CategoryTrend {
  final String categoryId;
  final double previous;
  final double current;

  const CategoryTrend({
    required this.categoryId,
    required this.previous,
    required this.current,
  });

  double get delta => current - previous;

  double? get percentChange {
    if (previous <= 0) return null;
    return delta / previous;
  }

  bool get isNew => previous <= 0 && current > 0;
  bool get isStopped => previous > 0 && current <= 0;
}

class ItemAnalyticsCalculator {
  static const int topItemLimit = 5;

  static Map<String, List<CategoryItemStat>> topItemsByCategory(
    List<TransactionEntity> transactions,
    List<TransactionItemEntity> items,
  ) {
    final txById = {for (final t in transactions) t.id: t};
    final totals = <String, Map<String, ({String name, double total, int count})>>{};

    for (final item in items) {
      final tx = txById[item.transactionId];
      if (tx == null) {
        continue;
      }
      final key = _normalize(item.name);
      final byName = totals.putIfAbsent(tx.category, () => {});
      final prev = byName[key];
      byName[key] = (
        name: prev?.name ?? item.name.trim(),
        total: (prev?.total ?? 0) + item.total,
        count: (prev?.count ?? 0) + 1,
      );
    }

    return {
      for (final entry in totals.entries)
        entry.key: [
          for (final item
              in (entry.value.entries.toList()
                ..sort((a, b) => b.value.total.compareTo(a.value.total))))
            CategoryItemStat(
              name: item.value.name,
              total: item.value.total,
              purchaseCount: item.value.count,
            ),
        ].take(topItemLimit).toList(),
    };
  }

  static List<CategoryTrend> categoryTrend(
    List<TransactionEntity> transactions,
    DateTime selectedMonth,
  ) {
    final current = SummaryCalculator.forMonth(transactions, selectedMonth);
    final previous = SummaryCalculator.forMonth(
      transactions,
      SummaryCalculator.shiftMonth(selectedMonth, -1),
    );

    final keys = {...current.categoryBreakdown.keys, ...previous.categoryBreakdown.keys};
    final trends = [
      for (final key in keys)
        CategoryTrend(
          categoryId: key,
          previous: previous.categoryBreakdown[key] ?? 0,
          current: current.categoryBreakdown[key] ?? 0,
        ),
    ]..sort((a, b) => b.current.compareTo(a.current));

    return trends;
  }

  static String _normalize(String name) => name.trim().toLowerCase();
}
