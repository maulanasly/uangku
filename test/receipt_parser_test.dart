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
  });
}
