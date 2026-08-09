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

    test('greedy name match captures multi-word item names', () {
      final data = ReceiptParser.parseLines([
        'Toko ABC',
        'Susu Ultra Milk 15000',
        'Air Mineral 5000',
        'TOTAL  20000',
      ]);

      expect(data.items.length, 2);
      expect(data.items[0].name, 'Susu Ultra Milk');
      expect(data.items[0].total, 15000);
      expect(data.items[1].name, 'Air Mineral');
      expect(data.items[1].total, 5000);
    });

    test('filters date lines from items', () {
      final data = ReceiptParser.parseLines([
        'Toko XYZ',
        'Item Satu  10000',
        '25/12/2026',
        'Item Dua  20000',
        'TOTAL  30000',
      ]);

      expect(data.items.length, 2);
      expect(data.items[0].name, 'Item Satu');
      expect(data.items[1].name, 'Item Dua');
    });

    test('strips leading SKU codes from item lines', () {
      final data = ReceiptParser.parseLines([
        'Toko',
        '899701234567  Nama Barang  15000',
        'TOTAL  15000',
      ]);

      expect(data.items.length, 1);
      expect(data.items[0].name, 'Nama Barang');
      expect(data.items[0].total, 15000);
    });

    test('filters payment method lines from items', () {
      final data = ReceiptParser.parseLines([
        'Toko ABC',
        'Item A  10000',
        'QRIS  10000',
        'TOTAL  10000',
      ]);

      expect(data.items.length, 1);
      expect(data.items[0].name, 'Item A');
    });

    test('parses comma as thousands separator for item amounts', () {
      final data = ReceiptParser.parseLines([
        'Toko Maju',
        'Beras 12,500',
        'Gula 15,000',
        'TOTAL  27,500',
      ]);

      expect(data.items.length, 2);
      expect(data.items[0].total, 12500);
      expect(data.items[1].total, 15000);
      expect(data.amount, 27500);
    });

    test('parses negative discount amounts', () {
      final data = ReceiptParser.parseLines([
        'Toko',
        'Item A  50000',
        'Disc 10%  -5000',
        'TOTAL  45000',
      ]);

      expect(data.items.length, 1);
      expect(data.items[0].name, 'Item A');
      expect(data.items[0].total, 50000);
    });
  });

  group('ReceiptParser multi-line items', () {
    test('wrapped name with qty x unit total on next line', () {
      final data = ReceiptParser.parseLines([
        'Toko',
        'Kopi Susu Gula Aren',
        '2 x 15.000  30.000',
        'TOTAL  30.000',
      ]);

      expect(data.items.length, 1);
      expect(data.items[0].name, 'Kopi Susu Gula Aren');
      expect(data.items[0].quantity, 2);
      expect(data.items[0].unitPrice, 15000);
      expect(data.items[0].total, 30000);
    });

    test('two-line name with amount on next line', () {
      final data = ReceiptParser.parseLines([
        'Toko',
        'Telur Ayam Negeri',
        '32.000',
        'TOTAL  32.000',
      ]);

      expect(data.items.length, 1);
      expect(data.items[0].name, 'Telur Ayam Negeri');
      expect(data.items[0].total, 32000);
    });

    test('back-to-back description then price blocks', () {
      final data = ReceiptParser.parseLines([
        'Toko',
        'Es Teh Manis',
        '4.000',
        'Es Jeruk',
        '5.000',
        'TOTAL  9.000',
      ]);

      expect(data.items.length, 2);
      expect(data.items[0].name, 'Es Teh Manis');
      expect(data.items[0].total, 4000);
      expect(data.items[1].name, 'Es Jeruk');
      expect(data.items[1].total, 5000);
    });

    test('footer labels are not absorbed into items', () {
      final data = ReceiptParser.parseLines([
        'Toko',
        'Roti Tawar  12.000',
        'DISKON MEMBER 10%',
        'PROMO BELANJA',
        'TOTAL  10.800',
      ]);

      expect(data.items.length, 1);
      expect(data.items[0].name, 'Roti Tawar');
      expect(data.items[0].total, 12000);
    });

    test('barcode line between name and price splits the block', () {
      final data = ReceiptParser.parseLines([
        'Toko',
        'Kopi Arabica',
        '8997032100123',
        '45.000',
        'TOTAL  45.000',
      ]);

      expect(data.items, isEmpty);
    });

    test('x<qty> @ unitPrice continuation', () {
      final data = ReceiptParser.parseLines([
        'Toko',
        'Kopi Susu Gula Aren',
        'x2 @ 45.500',
        'TOTAL  91.000',
      ]);

      expect(data.items.length, 1);
      expect(data.items[0].name, 'Kopi Susu Gula Aren');
      expect(data.items[0].quantity, 2);
      expect(data.items[0].unitPrice, 45500);
      expect(data.items[0].total, 91000);
    });

    test('blank line separates pending blocks', () {
      final data = ReceiptParser.parseLines([
        'Toko',
        'Es Teh Manis',
        '4.000',
        '',
        'Es Jeruk',
        '5.000',
        'TOTAL  9.000',
      ]);

      expect(data.items.length, 2);
      expect(data.items[0].name, 'Es Teh Manis');
      expect(data.items[1].name, 'Es Jeruk');
    });
  });

  group('ReceiptParser discounts', () {
    test('subtracts discount from subtotal', () {
      final data = ReceiptParser.parseLines([
        'Toko',
        'Item A  70.000',
        'SUBTOTAL  70.000',
        'DISKON  5.000',
        'TOTAL BAYAR  65.000',
      ]);

      expect(data.amount, 65000);
    });

    test('does not double-subtract an already-net total', () {
      final data = ReceiptParser.parseLines([
        'Toko',
        'Item A  50.000',
        'DISC  -5.000',
        'TOTAL  45.000',
      ]);

      expect(data.amount, 45000);
    });

    test('ignores percentage-only discount lines', () {
      final data = ReceiptParser.parseLines([
        'Toko',
        'Item A  90.000',
        'TOTAL  90.000',
        'DISKON MEMBER 10%',
      ]);

      expect(data.amount, 90000);
    });

    test('discount line is not extracted as an item', () {
      final data = ReceiptParser.parseLines([
        'Toko',
        'Item A  70.000',
        'SUBTOTAL  70.000',
        'POTONGAN  5.000',
        'TOTAL  65.000',
      ]);

      expect(data.items.length, 1);
      expect(data.items[0].name, 'Item A');
      expect(data.amount, 65000);
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

    test('parses the full structured schema', () {
      final data = ReceiptParser.parseGeminiJson('''
{
  "merchant_name": "Co-op",
  "store_address": "1 Main Street",
  "transaction_datetime": "2026-08-01 10:30:00",
  "receipt_id": "TX-001",
  "payment_method": "Debit",
  "subtotal": 70.00,
  "total_discount": 3.00,
  "final_total": 67.00,
  "change_due": 0.00,
  "items": [
    {
      "name": "Milk",
      "item_code": "SKU-001",
      "quantity": 2,
      "unit_price": 4.50,
      "net_line_total": 9.00,
      "status": "PURCHASED"
    },
    {
      "name": "Spoiled Yogurt",
      "net_line_total": 5.00,
      "status": "CANCELLED"
    }
  ]
}
''');

      expect(data.merchant, 'Co-op');
      expect(data.storeAddress, '1 Main Street');
      expect(data.date, DateTime(2026, 8, 1, 10, 30));
      expect(data.receiptId, 'TX-001');
      expect(data.paymentMethod, 'Debit');
      expect(data.subtotal, 70.0);
      expect(data.totalDiscount, 3.0);
      expect(data.amount, 67.0);
      expect(data.changeDue, 0.0);
      expect(data.items.length, 2);
      expect(data.items[0].itemCode, 'SKU-001');
      expect(data.items[0].quantity, 2);
      expect(data.items[0].unitPrice, 4.5);
      expect(data.items[0].total, 9.0);
      expect(data.items[0].status, ReceiptItemStatus.purchased);
      expect(data.items[1].status, ReceiptItemStatus.cancelled);
    });
  });

  group('ReceiptParser structured fields', () {
    test('captures store address, receipt id, and datetime with time', () {
      final data = ReceiptParser.parseLines([
        'Cafe Deluxe',
        '456 Elm Street',
        'Seattle, WA 98101',
        '12/25/2026 14:30',
        'Coffee 2 x 4.50 9.00',
        'Bagel 3.25',
        'SUBTOTAL 12.25',
        'TAX 0.92',
        'TOTAL 13.17',
        'CASH 20.00',
        'CHANGE 6.83',
      ]);

      expect(data.merchant, 'Cafe Deluxe');
      expect(data.storeAddress, '456 Elm Street, Seattle, WA 98101');
      expect(data.date, DateTime(2026, 12, 25, 14, 30));
      expect(data.paymentMethod, 'Cash');
      expect(data.subtotal, 12.25);
      expect(data.amount, 13.17);
      expect(data.changeDue, 6.83);
      expect(data.reconciliationWarning, isNull);
      expect(data.items.length, 2);
      expect(data.items[0].name, 'Coffee');
      expect(data.items[0].quantity, 2);
      expect(data.items[0].unitPrice, 4.5);
      expect(data.items[0].total, 9.0);
      expect(data.items[1].name, 'Bagel');
      expect(data.items[1].total, 3.25);
    });

    test('detects QRIS as the payment method', () {
      final data = ReceiptParser.parseLines([
        'Warung Sejahtera',
        'Nasi Goreng 25000',
        'QRIS 25000',
        'TOTAL 25000',
      ]);

      expect(data.paymentMethod, 'QRIS');
    });

    test('retains leading SKU codes as itemCode', () {
      final data = ReceiptParser.parseLines([
        'Toko',
        '899701234567 Nama Barang 15000',
        'TOTAL 15000',
      ]);

      expect(data.items.length, 1);
      expect(data.items[0].itemCode, '899701234567');
      expect(data.items[0].name, 'Nama Barang');
      expect(data.items[0].total, 15000);
    });

    test('flags cancelled/void lines with status', () {
      final data = ReceiptParser.parseLines([
        'Toko',
        'Kopi Susu 2 x 15.000 30.000',
        'BATAL Telur Ayam 3 x 5.000 15.000',
        'TOTAL 30.000',
      ]);

      expect(data.items.length, 2);
      expect(data.items[0].status, ReceiptItemStatus.purchased);
      expect(data.items[1].status, ReceiptItemStatus.cancelled);
      expect(data.items[1].total, 15000);
    });

    test('emits a reconciliation warning when items do not match subtotal', () {
      final data = ReceiptParser.parseLines([
        'Toko',
        'Item A 10000',
        'SUBTOTAL 99999',
        'TOTAL 10000',
      ]);

      expect(data.reconciliationWarning, isNotNull);
      expect(data.amount, 10000);
    });

    test('no warning when items reconcile with the total', () {
      final data = ReceiptParser.parseLines([
        'Toko',
        'Item A 10000',
        'SUBTOTAL 10000',
        'TOTAL 10000',
      ]);

      expect(data.reconciliationWarning, isNull);
      expect(data.amount, 10000);
    });
  });
}
