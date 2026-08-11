import '../../data/database/database.dart';

class PricePoint {
  final DateTime date;
  final String merchant;
  final double quantity;
  final double? unitPrice;
  final double total;
  final double? weight;

  const PricePoint({
    required this.date,
    required this.merchant,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    required this.weight,
  });

  /// Unit price, falling back to the implied unit price when the receipt
  /// scanner did not record an explicit one.
  double get effectiveUnitPrice {
    final explicit = unitPrice;
    if (explicit != null) {
      return explicit;
    }
    if (quantity > 0) {
      return total / quantity;
    }
    return total;
  }
}

class ItemPriceHistory {
  final String name;
  final List<PricePoint> points;

  const ItemPriceHistory({
    required this.name,
    required this.points,
  });

  int get purchaseCount => points.length;

  double? get latestPrice => points.isEmpty ? null : points.last.effectiveUnitPrice;
}

class PriceHistoryCalculator {
  /// Groups all line items by their normalized name (case/trim insensitive),
  /// joining each item to its parent transaction for date and merchant. Points
  /// are sorted chronologically. Sorted by latest price descending.
  static List<ItemPriceHistory> buildPriceHistory(
    List<TransactionEntity> transactions,
    List<TransactionItemEntity> items,
  ) {
    final txById = {for (final t in transactions) t.id: t};
    final displayByKey = <String, String>{};
    final grouped = <String, List<PricePoint>>{};

    for (final item in items) {
      final tx = txById[item.transactionId];
      if (tx == null) {
        continue;
      }
      final key = _normalize(item.name);
      displayByKey.putIfAbsent(key, () => item.name.trim());
      grouped.putIfAbsent(key, () => []).add(
            PricePoint(
              date: tx.date,
              merchant: tx.merchant,
              quantity: item.quantity,
              unitPrice: item.unitPrice,
              total: item.total,
              weight: item.weight,
            ),
          );
    }

    final histories = [
      for (final entry in grouped.entries)
        ItemPriceHistory(
          name: displayByKey[entry.key] ?? entry.key,
          points: entry.value
            ..sort((a, b) => a.date.compareTo(b.date)),
        ),
    ]..sort((a, b) => (b.latestPrice ?? 0).compareTo(a.latestPrice ?? 0));

    return histories;
  }

  static String _normalize(String name) => name.trim().toLowerCase();
}