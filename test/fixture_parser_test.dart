import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:uangku/core/utils/receipt_parser.dart';

List<String> _readFixture(String name) =>
    File('test/fixtures/$name').readAsLinesSync();

void main() {
  group('ReceiptParser YOGYA fixture', () {
    test('extracts metadata, items, and reconciled totals', () {
      final data = ReceiptParser.parseLines(_readFixture('yogya_receipt.txt'));

      expect(data.merchant, 'YOGYA DEPARTMENT STORE');
      expect(data.storeAddress, 'JL. RAJAWALI NO. 1, BANDUNG');
      expect(data.date, DateTime(2026, 8, 9, 14, 32, 5));
      expect(data.receiptId, '00012345');
      expect(data.paymentMethod, 'Cash');
      expect(data.subtotal, 92800);
      expect(data.totalDiscount, 3800);
      expect(data.amount, 98790);
      expect(data.changeDue, 1210);
      expect(data.reconciliationWarning, isNull);

      expect(data.items.length, 4);
      final kopi = data.items[0];
      expect(kopi.name, 'KOPI ABC 25GR');
      expect(kopi.quantity, 2);
      expect(kopi.unitPrice, 2900);
      expect(kopi.total, 5800);
      expect(kopi.status, ReceiptItemStatus.purchased);

      final susu = data.items[1];
      expect(susu.name, 'SUSU ULTRA 1L');
      expect(susu.quantity, 1);
      expect(susu.unitPrice, 18500);
      expect(susu.total, 18500);

      final apel = data.items[2];
      expect(apel.name, 'APEL FUJI');
      expect(apel.quantity, 0.5);
      expect(apel.unitPrice, 25000);
      expect(apel.weight, 0.5);
      expect(apel.total, 12500);

      final telur = data.items[3];
      expect(telur.name, 'TELUR AYAM');
      expect(telur.quantity, 2);
      expect(telur.unitPrice, 28000);
      expect(telur.total, 56000);
    });
  });

  group('ReceiptParser GRIYA fixture', () {
    test('extracts metadata, items, and reconciled totals', () {
      final data = ReceiptParser.parseLines(_readFixture('griya_receipt.txt'));

      expect(data.merchant, 'GRIYA');
      expect(data.storeAddress, 'JL. CIATEUL NO. 23, BANDUNG');
      expect(data.date, DateTime(2026, 8, 14, 16, 4, 22));
      expect(data.receiptId, '887621');
      expect(data.paymentMethod, 'Cash');
      expect(data.subtotal, 205500);
      expect(data.totalDiscount, 3500);
      expect(data.amount, 202000);
      expect(data.changeDue, 8000);
      expect(data.reconciliationWarning, isNull);

      expect(data.items.length, 4);
      expect(data.items[0].name, 'TELUR AYAM 1KG');
      expect(data.items[0].quantity, 2);
      expect(data.items[0].unitPrice, 28000);
      expect(data.items[0].total, 56000);
      expect(data.items[1].name, 'BERAS ROJOLELE PREMIUM');
      expect(data.items[1].quantity, 1);
      expect(data.items[1].total, 68000);
      expect(data.items[2].name, 'MINYAK GORENG 2L');
      expect(data.items[2].quantity, 3);
      expect(data.items[2].unitPrice, 21500);
      expect(data.items[2].total, 64500);
      expect(data.items[3].name, 'GULA PASIR 1KG');
      expect(data.items[3].quantity, 1);
      expect(data.items[3].total, 17000);
    });
  });

  group('ReceiptParser minimarket fixture', () {
    test('skips barcode rows and marks starred lines as cancelled', () {
      final data =
          ReceiptParser.parseLines(_readFixture('minimarket_receipt.txt'));

      expect(data.merchant, 'INDOMARET');
      expect(data.storeAddress, 'JL. SUDIRMAN NO. 12, BANDUNG');
      expect(data.date, DateTime(2026, 8, 10, 8, 12, 44));
      expect(data.receiptId, '000000015');
      expect(data.paymentMethod, 'Cash');
      expect(data.subtotal, 25500);
      expect(data.totalDiscount, 1275);
      expect(data.amount, 24225);

      expect(data.items.length, 3);
      expect(data.items[0].name, 'GULA PASIR 1KG');
      expect(data.items[0].quantity, 1);
      expect(data.items[0].total, 15500);
      expect(data.items[0].status, ReceiptItemStatus.purchased);
      expect(data.items[1].name, 'TEH SOSRO 500ML');
      expect(data.items[1].quantity, 2);
      expect(data.items[1].unitPrice, 5000);
      expect(data.items[1].total, 10000);
      expect(data.items[2].name, 'ROTI TAWAR');
      expect(data.items[2].total, -12000);
      expect(data.items[2].status, ReceiptItemStatus.cancelled);
    });
  });

  group('ReceiptParser restaurant fixture', () {
    test('parses x qty layouts, service/tax, and QRIS payment', () {
      final data =
          ReceiptParser.parseLines(_readFixture('restaurant_receipt.txt'));

      expect(data.merchant, 'WARUNG PADANG SEDERHANA');
      expect(data.storeAddress, 'JL. DIPATIUKUR NO. 8, BANDUNG');
      expect(data.date, DateTime(2026, 8, 15, 19, 45));
      expect(data.paymentMethod, 'QRIS');
      expect(data.subtotal, 65000);
      expect(data.amount, 75400);
      expect(data.reconciliationWarning, isNull);

      expect(data.items.length, 4);
      expect(data.items[0].name, 'NASI PUTIH');
      expect(data.items[0].quantity, 2);
      expect(data.items[0].unitPrice, 5000);
      expect(data.items[0].total, 10000);
      expect(data.items[1].name, 'RENDANG');
      expect(data.items[1].quantity, 1);
      expect(data.items[1].total, 25000);
      expect(data.items[2].name, 'AYAM POP');
      expect(data.items[2].total, 22000);
      expect(data.items[3].name, 'ES TEH MANIS');
      expect(data.items[3].quantity, 2);
      expect(data.items[3].total, 8000);
    });
  });

  group('ReceiptParser US retail fixture', () {
    test('parses cents, MM/DD/YYYY dates, and card payments', () {
      final data =
          ReceiptParser.parseLines(_readFixture('us_retail_receipt.txt'));

      expect(data.merchant, 'TARGET');
      expect(data.storeAddress, '1000 AVE OF THE AMERICAS, NEW YORK, NY 10013');
      expect(data.date, DateTime(2026, 8, 13, 15, 20, 11));
      expect(data.paymentMethod, 'Card');
      expect(data.subtotal, 25.97);
      expect(data.amount, 28.05);
      expect(data.changeDue, isNull);
      expect(data.reconciliationWarning, isNull);

      expect(data.items.length, 3);
      expect(data.items[0].name, 'MILK');
      expect(data.items[0].quantity, 2);
      expect(data.items[0].unitPrice, 4.99);
      expect(data.items[0].total, 9.98);
      expect(data.items[1].name, 'BAGELS');
      expect(data.items[1].quantity, 4);
      expect(data.items[1].total, 10.0);
      expect(data.items[2].name, 'SALAD');
      expect(data.items[2].total, 5.99);
    });
  });
}
