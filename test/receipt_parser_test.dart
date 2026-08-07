import 'package:flutter_test/flutter_test.dart';

import 'package:uangku/core/utils/receipt_parser.dart';

void main() {
  group('ReceiptParser.parseLines', () {
    test('extracts merchant from first meaningful text line', () {
      final data = ReceiptParser.parseLines([
        'NPWP: 01.234.567.8-901.000',
        '08-1234567890',
        'Toko Makmur Jaya',
        'Item 1       10.00',
        'TOTAL      10.00',
      ]);

      expect(data.merchant, 'Toko Makmur Jaya');
    });

    test('ignores pure numeric and empty lines for merchant', () {
      final data = ReceiptParser.parseLines([
        '',
        '12345678',
        'Warung Sejahtera',
        'TOTAL      5.00',
      ]);

      expect(data.merchant, 'Warung Sejahtera');
    });

    test('parses dd/MM/yyyy date', () {
      final data = ReceiptParser.parseLines([
        'Indomaret',
        'Date: 25/12/2026',
        'TOTAL 50',
      ]);

      expect(data.date, DateTime(2026, 12, 25));
    });

    test('parses dd-MM-yyyy date', () {
      final data = ReceiptParser.parseLines([
        'Indomaret',
        '25-12-2026',
        'TOTAL 50',
      ]);

      expect(data.date, DateTime(2026, 12, 25));
    });

    test('parses yyyy-MM-dd date', () {
      final data = ReceiptParser.parseLines([
        'Indomaret',
        '2026-12-25',
        'TOTAL 50',
      ]);

      expect(data.date, DateTime(2026, 12, 25));
    });

    test('extracts amount near TOTAL label', () {
      final data = ReceiptParser.parseLines([
        'Toko Makmur',
        'Item 1     20.00',
        'Item 2     30.00',
        'GRAND TOTAL  50.00',
      ]);

      expect(data.amount, 50.0);
    });

    test('extracts amount near TOTAL BAYAR label', () {
      final data = ReceiptParser.parseLines([
        'Toko Makmur',
        'TOTAL BAYAR: 12500',
      ]);

      expect(data.amount, 12500.0);
    });

    test('extracts amount near JUMLAH label', () {
      final data = ReceiptParser.parseLines([
        'Toko Makmur',
        'JUMLAH: 75.50',
      ]);

      expect(data.amount, 75.5);
    });

    test('prefers largest amount near total labels', () {
      final data = ReceiptParser.parseLines([
        'Toko Makmur',
        'TOTAL BELANJA: 10000',
        'TOTAL BAYAR: 5000',
      ]);

      expect(data.amount, 10000.0);
    });

    test('returns nulls when nothing is found', () {
      final data = ReceiptParser.parseLines([
        '',
        '0821 1234 5678',
        '',
      ]);

      expect(data.merchant, isNull);
      expect(data.date, isNull);
      expect(data.amount, isNull);
    });

    test('extracts line items between merchant and total', () {
      final data = ReceiptParser.parseLines([
        'Toko Makmur',
        'Beras 5kg     75.00',
        'Minyak Goreng  25.00',
        'Gula Pasir    15.50',
        'TOTAL        115.50',
      ]);

      expect(data.items.length, 3);
      expect(data.items[0].name, 'Beras 5kg');
      expect(data.items[0].total, 75.0);
      expect(data.items[1].name, 'Minyak Goreng');
      expect(data.items[1].total, 25.0);
      expect(data.items[2].name, 'Gula Pasir');
      expect(data.items[2].total, 15.5);
      expect(data.amount, 115.5);
    });

    test('filters subtotal/tax/total rows from items', () {
      final data = ReceiptParser.parseLines([
        'Toko ABC',
        'Item A  10.00',
        'Subtotal  10.00',
        'PPN 11%    1.10',
        'TOTAL    11.10',
      ]);

      expect(data.items.length, 1);
      expect(data.items[0].name, 'Item A');
    });

    test('parses qty x unitPrice pattern with indonesian format', () {
      final data = ReceiptParser.parseLines([
        'Toko Sejahtera',
        'Kopi Susu 2 x 15.500 31.000',
        'Teh Manis 1 x 5.000  5.000',
        'TOTAL  36.000',
      ]);

      expect(data.items.length, 2);
      expect(data.items[0].name, 'Kopi Susu');
      expect(data.items[0].quantity, 2);
      expect(data.items[0].unitPrice, 15500);
      expect(data.items[0].total, 31000);
      expect(data.items[1].name, 'Teh Manis');
      expect(data.items[1].total, 5000);
    });

    test('handles indonesian thousands separator in amounts', () {
      final data = ReceiptParser.parseLines([
        'Toko Maju',
        'Kompor Gas    250.000',
        'Selang        15.500',
        'TOTAL  265.500',
      ]);

      expect(data.items.length, 2);
      expect(data.items[0].total, 250000);
      expect(data.items[1].total, 15500);
      expect(data.amount, 265500);
    });
  });

  group('ReceiptParser.parseGeminiJson', () {
    test('parses plain JSON', () {
      final data = ReceiptParser.parseGeminiJson(
        '{"merchant": "Target", "amount": 25.5, "date": "2026-10-25"}',
      );

      expect(data.merchant, 'Target');
      expect(data.amount, 25.5);
      expect(data.date, DateTime(2026, 10, 25));
    });

    test('parses JSON wrapped in markdown code fences', () {
      final data = ReceiptParser.parseGeminiJson(
        '```json\n{"merchant": "Coffee Shop", "amount": 12, "date": "2026-01-02"}\n```',
      );

      expect(data.merchant, 'Coffee Shop');
      expect(data.amount, 12);
      expect(data.date, DateTime(2026, 1, 2));
    });

    test('returns empty data for invalid JSON', () {
      final data = ReceiptParser.parseGeminiJson('not json at all');

      expect(data.merchant, isNull);
      expect(data.amount, isNull);
      expect(data.date, isNull);
    });

    test('parses items array from Gemini response', () {
      final data = ReceiptParser.parseGeminiJson('''
{
  "merchant": "Co-op",
  "amount": 67.00,
  "date": "2026-08-01",
  "items": [
    { "name": "Milk", "quantity": 2, "unitPrice": 4.50, "total": 9.00 },
    { "name": "Bread", "quantity": 1, "total": 4.50 },
    { "name": "Eggs", "total": 53.50 }
  ]
}
''');

      expect(data.merchant, 'Co-op');
      expect(data.amount, 67.0);
      expect(data.items.length, 3);
      expect(data.items[0].name, 'Milk');
      expect(data.items[0].quantity, 2);
      expect(data.items[0].unitPrice, 4.5);
      expect(data.items[0].total, 9.0);
      expect(data.items[1].total, 4.5);
      expect(data.items[1].unitPrice, isNull);
      expect(data.items[2].total, 53.5);
    });
  });
}
