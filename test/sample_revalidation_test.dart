import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:uangku/core/utils/receipt_parser.dart';

List<String> _readFixture(String name) =>
    File('test/fixtures/$name').readAsLinesSync();

void main() {
  group('ReceiptParser YOGYA JUNCTION (multi-line ITEM # blocks)', () {
    test('parses qty/unit carry, item codes, and folded discount mirrors', () {
      final data =
          ReceiptParser.parseLines(_readFixture('yogya_junction_receipt.txt'));

      expect(data.merchant, 'YOGYA JUNCTION');
      expect(data.date, DateTime(2026, 8, 5, 20, 31, 28));
      expect(data.paymentMethod, 'Debit');
      expect(data.subtotal, 47000);
      expect(data.totalDiscount, 4600);
      expect(data.amount, 42400);
      expect(data.reconciliationWarning, isNull);

      expect(data.items.length, 3);

      final muffin = data.items[0];
      expect(muffin.name, 'MO BKR CHOCO MUFFIN');
      expect(muffin.quantity, 2);
      expect(muffin.unitPrice, 12000);
      expect(muffin.total, 24000);
      expect(muffin.itemCode, '03022559');
      expect(muffin.discountAmount, isNull);
      expect(muffin.status, ReceiptItemStatus.purchased);

      final choco = data.items[1];
      expect(choco.name, 'MO BKR CHOCOLATE DNT');
      expect(choco.total, 12000);
      expect(choco.itemCode, '03022368');
      expect(choco.discountAmount, 2400);

      final kelit = data.items[2];
      expect(kelit.name, 'MO FD KELIT 40GR');
      expect(kelit.quantity, 2);
      expect(kelit.unitPrice, 5500);
      expect(kelit.total, 11000);
      expect(kelit.itemCode, '02431796');
      expect(kelit.discountAmount, 2200);
    });
  });

  group('ReceiptParser YOGYA JUNCTION DISC50% (repeated item code)', () {
    test('keeps four purchased items and folds each DISC 50% row', () {
      final data = ReceiptParser.parseLines(
        _readFixture('yogya_junction_disc50_receipt.txt'),
      );

      expect(data.merchant, 'YOGYA JUNCTION');
      expect(data.date, DateTime(2026, 8, 7, 20, 43, 56));
      expect(data.paymentMethod, 'Debit');
      expect(data.subtotal, 665000);
      expect(data.totalDiscount, 332500);
      expect(data.amount, 332500);
      expect(data.reconciliationWarning, isNull);

      expect(data.items.length, 4);
      final totals = [230000, 95000, 110000, 230000];
      final discounts = [115000, 47500, 55000, 115000];
      for (int k = 0; k < 4; k++) {
        final item = data.items[k];
        expect(item.name, 'P CRDN UWL, DISC50%');
        expect(item.itemCode, '90004568');
        expect(item.total, totals[k]);
        expect(item.discountAmount, discounts[k]);
        expect(item.status, ReceiptItemStatus.purchased);
      }
    });
  });

  group('ReceiptParser Indomaret (verbatim split-line OCR)', () {
    test('keeps cancelled voids and flags the scrambled item totals', () {
      final data = ReceiptParser.parseLines(
        _readFixture('indomaret_voucher_receipt.txt'),
      );

      expect(data.merchant, 'OMARCU PRISMATAMA');
      expect(data.date, DateTime(2018, 5, 16, 17, 8));
      expect(data.subtotal, 130650);
      expect(data.totalDiscount, 13000);
      expect(data.amount, 117650);
      // The raw OCR scrambles sold/display price pairs, so a few totals shift
      // between items — the reconciliation warning is the designed safety net.
      expect(data.reconciliationWarning, isNotNull);

      expect(data.items.length, 10);
      expect(data.items[0].name, 'ABC ORANGE 525ML');
      expect(data.items[0].total, 13500);
      expect(data.items[1].name, 'I/F BISC. WNDRLND 300');
      expect(data.items[1].total, 20900);
      expect(data.items[2].name, 'LEXUS SANDW COKL 190');
      expect(data.items[2].total, 26800);
      expect(data.items[3].name, 'LUWAK WHT ORGL 20X20');
      expect(data.items[3].total, 25400);
      expect(data.items[4].name, 'OREO CHO & VAN 2X137');
      expect(data.items[4].total, 19800);
      expect(data.items[5].name, 'TONG TJI JASM T/A.25');
      expect(data.items[5].total, 9300);
      expect(data.items[6].name, 'KOPIKO 78C 240ML');
      expect(data.items[6].quantity, 2);

      final sovia = data.items[8];
      expect(sovia.name, 'SOVIA M/GORENG 2L');
      expect(sovia.status, ReceiptItemStatus.purchased);

      final cancel = data.items[9];
      expect(cancel.name, 'SOVIA M/GORENG 2L');
      expect(cancel.total, -26950);
      expect(cancel.status, ReceiptItemStatus.cancelled);
    });
  });

  group('ReceiptParser Alfamart (verbatim OCR typos kept)', () {
    test('parses dot-thousands, cash payment, and dotted date', () {
      final data =
          ReceiptParser.parseLines(_readFixture('alfamart_jogja_receipt.txt'));

      expect(data.merchant, 'Alfamart');
      expect(data.date, DateTime(2024, 7, 18, 8, 49));
      expect(data.receiptId, '281');
      expect(data.paymentMethod, 'Cash');
      expect(data.subtotal, isNull);
      expect(data.amount, 38000);
      expect(data.reconciliationWarning, isNull);

      expect(data.items.length, 6);
      expect(data.items[0].name, 'Cimory');
      expect(data.items[0].total, 2000);
      expect(data.items[1].name, 'Cinory hazelnut');
      expect(data.items[1].total, 9000);
      expect(data.items[2].name, 'Frestea madu');
      expect(data.items[2].total, 8000);
      expect(data.items[3].name, 'Ice cream alce');
      expect(data.items[3].total, 5000);
      expect(data.items[4].name, 'Kanz ler');
      expect(data.items[4].total, 10000);
      expect(data.items[5].name, 'Le Minerale');
      expect(data.items[5].total, 4000);
    });
  });

  group('ReceiptParser IKEA (QR-noise header, Item No. blocks)', () {
    test('prefers brand over legal entity and reconciles with tax', () {
      final data = ReceiptParser.parseLines(
        _readFixture('ikea_kota_baru_parahyangan_receipt.txt'),
      );

      expect(data.merchant, 'IKEA KOTA BARU PARAHYANGAN');
      expect(data.date, DateTime(2026, 8, 9, 11, 54));
      expect(data.receiptId, '1000213355');
      expect(data.paymentMethod, 'Card');
      expect(data.subtotal, 293243);
      expect(data.amount, 325500);
      expect(data.totalDiscount, isNull);
      expect(data.reconciliationWarning, isNull);

      expect(data.items.length, 2);
      final latthet = data.items[0];
      expect(latthet.name, 'LATTHET susp rl 60 A pc');
      expect(latthet.total, 45500);
      expect(latthet.itemCode, '80386376');
      expect(latthet.status, ReceiptItemStatus.purchased);

      final platsa = data.items[1];
      expect(platsa.name, 'PLATSA frame 60x40x6 pc');
      expect(platsa.total, 280000);
      expect(platsa.itemCode, '30387477');
      expect(platsa.status, ReceiptItemStatus.purchased);
    });
  });
}
