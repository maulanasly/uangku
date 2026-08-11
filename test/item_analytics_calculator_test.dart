import 'package:flutter_test/flutter_test.dart';

import 'package:uangku/core/models/transaction_type.dart';
import 'package:uangku/core/utils/item_analytics_calculator.dart';
import 'package:uangku/data/database/database.dart';

void main() {
  TransactionEntity tx(String id, DateTime date, String category, double amount) {
    return TransactionEntity(
      id: id,
      date: date,
      amount: amount,
      category: category,
      merchant: 'Merchant $id',
      note: '',
      type: TransactionType.expense,
    );
  }

  TransactionItemEntity item(String id, String txId, String name, double total) {
    return TransactionItemEntity(
      id: id,
      transactionId: txId,
      name: name,
      quantity: 1,
      unitPrice: null,
      weight: null,
      total: total,
      position: 0,
    );
  }

  group('topItemsByCategory', () {
    test('ranks items by total amount per category and limits to 5', () {
      final transactions = [
        tx('a', DateTime(2026, 8, 1), 'cat_food', 100),
        tx('b', DateTime(2026, 8, 2), 'cat_food', 100),
      ];
      final items = [
        for (var i = 0; i < 7; i++)
          item('a-$i', 'a', 'Item ${i + 1}', (i + 1) * 10.0),
      ];

      final result = ItemAnalyticsCalculator.topItemsByCategory(transactions, items);

      expect(result.keys, ['cat_food']);
      final top = result['cat_food']!;
      expect(top.length, 5);
      expect(top.first.name, 'Item 7');
      expect(top.first.total, 70);
      expect(top.last.name, 'Item 3');
    });

    test('aggregates repeated names and merges across transactions', () {
      final transactions = [
        tx('a', DateTime(2026, 8, 1), 'cat_food', 100),
        tx('b', DateTime(2026, 8, 2), 'cat_food', 100),
      ];
      final items = [
        item('a-0', 'a', '  Ayam Geprek  ', 20),
        item('a-1', 'a', 'ayam geprek', 10),
        item('b-0', 'b', 'Nasi Goreng', 5),
      ];

      final result = ItemAnalyticsCalculator.topItemsByCategory(transactions, items);
      final top = result['cat_food']!;

      expect(top[0].name, 'Ayam Geprek');
      expect(top[0].total, 30);
      expect(top[0].purchaseCount, 2);
      expect(top[1].name, 'Nasi Goreng');
      expect(top[1].total, 5);
    });

    test('groups by category from the parent transaction', () {
      final transactions = [
        tx('a', DateTime(2026, 8, 1), 'cat_food', 100),
        tx('b', DateTime(2026, 8, 2), 'cat_transport', 100),
      ];
      final items = [
        item('a-0', 'a', 'Bread', 20),
        item('b-0', 'b', 'Fuel', 50),
      ];

      final result = ItemAnalyticsCalculator.topItemsByCategory(transactions, items);

      expect(result.keys.toSet(), {'cat_food', 'cat_transport'});
      expect(result['cat_food']!.single.name, 'Bread');
      expect(result['cat_transport']!.single.name, 'Fuel');
    });

    test('skips items whose parent transaction is missing', () {
      final transactions = [tx('a', DateTime(2026, 8, 1), 'cat_food', 100)];
      final items = [
        item('a-0', 'a', 'Bread', 20),
        item('orphan', 'missing', 'Ghost', 99),
      ];

      final result = ItemAnalyticsCalculator.topItemsByCategory(transactions, items);

      expect(result['cat_food']!.single.name, 'Bread');
      expect(result.values.every((l) => l.every((s) => s.name != 'Ghost')), isTrue);
    });
  });

  group('categoryTrend', () {
    test('computes previous vs current delta and percent', () {
      final transactions = [
        tx('a', DateTime(2026, 7, 10), 'cat_food', 50), // previous month
        tx('b', DateTime(2026, 8, 10), 'cat_food', 80), // selected month
      ];

      final trends = ItemAnalyticsCalculator.categoryTrend(
        transactions,
        DateTime(2026, 8, 1),
      );

      expect(trends, hasLength(1));
      final trend = trends.first;
      expect(trend.previous, 50);
      expect(trend.current, 80);
      expect(trend.delta, 30);
      expect(trend.percentChange, 0.6);
      expect(trend.isNew, isFalse);
    });

    test('marks a category as new when there was no previous spending', () {
      final transactions = [tx('b', DateTime(2026, 8, 10), 'cat_food', 80)];

      final trends = ItemAnalyticsCalculator.categoryTrend(
        transactions,
        DateTime(2026, 8, 1),
      );

      final trend = trends.single;
      expect(trend.previous, 0);
      expect(trend.isNew, isTrue);
      expect(trend.percentChange, isNull);
    });

    test('marks a stopped category at -100 percent', () {
      final transactions = [tx('a', DateTime(2026, 7, 10), 'cat_food', 80)];

      final trends = ItemAnalyticsCalculator.categoryTrend(
        transactions,
        DateTime(2026, 8, 1),
      );

      final trend = trends.single;
      expect(trend.current, 0);
      expect(trend.isStopped, isTrue);
      expect(trend.percentChange, -1.0);
    });

    test('includes categories present in either month and sorts by current', () {
      final transactions = [
        tx('a', DateTime(2026, 7, 10), 'cat_food', 50),
        tx('b', DateTime(2026, 8, 10), 'cat_transport', 120),
        tx('c', DateTime(2026, 7, 10), 'cat_shopping', 30),
      ];

      final trends = ItemAnalyticsCalculator.categoryTrend(
        transactions,
        DateTime(2026, 8, 1),
      );

      expect(
        trends.map((t) => t.categoryId).toList(),
        ['cat_transport', 'cat_food', 'cat_shopping'],
      );
      expect(trends.first.previous, 0);
      expect(trends.first.isNew, isTrue);
      expect(trends[1].previous, 50);
      expect(trends[2].current, 0);
      expect(trends[2].isStopped, isTrue);
    });
  });
}
