import 'package:flutter_test/flutter_test.dart';

import 'package:uangku/core/models/transaction_type.dart';
import 'package:uangku/core/utils/price_history_calculator.dart';
import 'package:uangku/data/database/database.dart';

TransactionEntity _tx({
  required String id,
  required DateTime date,
  required String category,
  String merchant = 'Shop',
}) {
  return TransactionEntity(
    id: id,
    date: date,
    amount: 0,
    category: category,
    merchant: merchant,
    note: '',
    type: TransactionType.expense,
  );
}

TransactionItemEntity _item({
  required String id,
  required String transactionId,
  required String name,
  double quantity = 1,
  double? unitPrice,
  double total = 10,
  double? weight,
}) {
  return TransactionItemEntity(
    id: id,
    transactionId: transactionId,
    name: name,
    quantity: quantity,
    unitPrice: unitPrice,
    weight: weight,
    total: total,
    position: 0,
  );
}

void main() {
  final t1 = _tx(id: 't1', date: DateTime(2026, 1, 5), category: 'c1');
  final t2 = _tx(id: 't2', date: DateTime(2026, 2, 10), category: 'c1');
  final t3 = _tx(id: 't3', date: DateTime(2026, 3, 15), category: 'c2');

  group('PriceHistoryCalculator', () {
    test('groups items by normalized name across transactions', () {
      final histories = PriceHistoryCalculator.buildPriceHistory(
        [t1, t2],
        [
          _item(id: 'i1', transactionId: 't1', name: 'Milo', unitPrice: 10, total: 20, quantity: 2),
          _item(id: 'i2', transactionId: 't2', name: ' milo ', unitPrice: 12, total: 12),
        ],
      );

      expect(histories.length, 1);
      expect(histories.first.name, 'Milo');
      expect(histories.first.purchaseCount, 2);
    });

    test('sorts points chronologically', () {
      final histories = PriceHistoryCalculator.buildPriceHistory(
        [t1, t2],
        [
          _item(id: 'i1', transactionId: 't2', name: 'Milo', unitPrice: 12, total: 12),
          _item(id: 'i2', transactionId: 't1', name: 'Milo', unitPrice: 10, total: 10),
        ],
      );

      expect(histories.first.points.length, 2);
      expect(histories.first.points.first.merchant.contains('Shop'), isTrue);
      expect(histories.first.points.first.date, DateTime(2026, 1, 5));
      expect(histories.first.points.last.date, DateTime(2026, 2, 10));
      expect(histories.first.latestPrice, 12);
    });

    test('skips orphan items without a parent transaction', () {
      final histories = PriceHistoryCalculator.buildPriceHistory(
        [t1],
        [
          _item(id: 'i1', transactionId: 'missing', name: 'Ghost', unitPrice: 5, total: 5),
          _item(id: 'i2', transactionId: 't1', name: 'Milo', unitPrice: 10, total: 10),
        ],
      );

      expect(histories.length, 1);
      expect(histories.first.name, 'Milo');
    });

    test('effectiveUnitPrice falls back to total / quantity', () {
      final histories = PriceHistoryCalculator.buildPriceHistory(
        [t1],
        [
          _item(id: 'i1', transactionId: 't1', name: 'Milo', quantity: 4, total: 20),
        ],
      );

      expect(histories.first.points.first.unitPrice, isNull);
      expect(histories.first.points.first.effectiveUnitPrice, 5);
    });

    test('uses explicit unitPrice when present', () {
      final histories = PriceHistoryCalculator.buildPriceHistory(
        [t1],
        [
          _item(id: 'i1', transactionId: 't1', name: 'Milo', quantity: 2, unitPrice: 25, total: 50),
        ],
      );

      expect(histories.first.points.first.effectiveUnitPrice, 25);
    });

    test('carries merchant and weight onto points', () {
      final tx = _tx(id: 't1', date: DateTime(2026, 1, 5), category: 'c1', merchant: 'YOGYA');
      final histories = PriceHistoryCalculator.buildPriceHistory(
        [tx],
        [
          _item(
            id: 'i1',
            transactionId: 't1',
            name: 'Apples',
            quantity: 1,
            unitPrice: 8,
            total: 8,
            weight: 1.5,
          ),
        ],
      );

      final point = histories.first.points.first;
      expect(point.merchant, 'YOGYA');
      expect(point.weight, 1.5);
    });

    test('sorts histories by latest price descending', () {
      final histories = PriceHistoryCalculator.buildPriceHistory(
        [t1, t2, t3],
        [
          _item(id: 'i1', transactionId: 't1', name: 'Cheap', unitPrice: 1, total: 1),
          _item(id: 'i2', transactionId: 't2', name: 'Pricey', unitPrice: 50, total: 50),
          _item(id: 'i3', transactionId: 't3', name: 'Mid', unitPrice: 20, total: 20),
        ],
      );

      expect(histories.map((h) => h.name).toList(), ['Pricey', 'Mid', 'Cheap']);
    });

    test('handles multi-purchase items merged across categories', () {
      final histories = PriceHistoryCalculator.buildPriceHistory(
        [t2, t3],
        [
          _item(id: 'i1', transactionId: 't2', name: 'Milo', unitPrice: 12, total: 12),
          _item(id: 'i2', transactionId: 't3', name: ' Milo ', unitPrice: 14, total: 14),
        ],
      );

      expect(histories.length, 1);
      expect(histories.first.purchaseCount, 2);
      expect(histories.first.latestPrice, 14);
    });
  });
}