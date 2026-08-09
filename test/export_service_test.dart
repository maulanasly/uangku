import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:uangku/core/models/transaction_type.dart';
import 'package:uangku/core/services/export_service.dart';
import 'package:uangku/data/database/database.dart';

void main() {
  test('buildCsvRows writes header with Items column', () {
    final rows = buildCsvRows([], {});

    expect(rows.length, 1);
    expect(rows.first, [
      'Date',
      'Merchant',
      'Category',
      'Type',
      'Amount',
      'Note',
      'Items',
    ]);
  });

  test('buildCsvRows encodes line items as a JSON column', () {
    final tx = TransactionEntity(
      id: 't1',
      date: DateTime(2026, 7, 6),
      amount: 13.5,
      category: 'cat_food',
      merchant: 'Co-op',
      note: 'groceries',
      type: TransactionType.expense,
    );
    final items = [
      const TransactionItemEntity(
        id: 't1-0',
        transactionId: 't1',
        name: 'Milk',
        quantity: 2,
        unitPrice: 4.5,
        weight: null,
        total: 9,
        position: 0,
      ),
      const TransactionItemEntity(
        id: 't1-1',
        transactionId: 't1',
        name: 'Bread',
        quantity: 1,
        unitPrice: null,
        weight: 0.5,
        total: 4.5,
        position: 1,
      ),
    ];

    final rows = buildCsvRows([tx], {'t1': items});

    expect(rows.length, 2);
    final row = rows[1];
    expect(row[0], '2026-07-06T00:00:00.000');
    expect(row[1], 'Co-op');
    expect(row[2], 'cat_food');
    expect(row[4], 13.5);

    final decoded = jsonDecode(row[6].toString()) as List;
    expect(decoded.length, 2);
    final milk = decoded[0] as Map;
    expect(milk['name'], 'Milk');
    expect(milk['quantity'], 2);
    expect(milk['unitPrice'], 4.5);
    expect(milk['weight'], isNull);
    expect(milk['total'], 9);
    final bread = decoded[1] as Map;
    expect(bread['name'], 'Bread');
    expect(bread['unitPrice'], isNull);
    expect(bread['weight'], 0.5);
  });

  test('buildCsvRows writes empty items for a transaction without items', () {
    final tx = TransactionEntity(
      id: 't2',
      date: DateTime(2026, 7, 7),
      amount: 5,
      category: 'cat_food',
      merchant: 'Bakery',
      note: '',
      type: TransactionType.expense,
    );

    final rows = buildCsvRows([tx], {});

    expect(rows.length, 2);
    expect(rows[1][6], '[]');
  });
}
