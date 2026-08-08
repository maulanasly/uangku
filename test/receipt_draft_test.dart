import 'package:flutter_test/flutter_test.dart';

import 'package:uangku/core/models/transaction_type.dart';
import 'package:uangku/core/utils/receipt_parser.dart';
import 'package:uangku/ui/scanner/receipt_draft.dart';

void main() {
  group('ReceiptDraft.fromReceiptData', () {
    test('maps parsed fields into editable form values', () {
      final draft = ReceiptDraft.fromReceiptData(
        ReceiptData(
          merchant: 'Toko Makmur',
          amount: 50.5,
          date: DateTime(2026, 7, 25),
        ),
      );

      expect(draft.merchant, 'Toko Makmur');
      expect(draft.amountText, '50.50');
      expect(draft.date, DateTime(2026, 7, 25));
      expect(draft.category, 'cat_food');
      expect(draft.type, TransactionType.expense);
      expect(draft.note, '');
    });

    test('formats whole-number amounts without decimals', () {
      final draft = ReceiptDraft.fromReceiptData(ReceiptData(amount: 12500));
      expect(draft.amountText, '12500');
    });

    test('falls back to empty strings and today when fields are missing', () {
      final draft = ReceiptDraft.fromReceiptData(ReceiptData());
      expect(draft.merchant, '');
      expect(draft.amountText, '');
    });
  });

  group('ReceiptDraft.toCompanion', () {
    test('uses Unknown merchant when merchant is empty', () {
      final draft = ReceiptDraft.fromReceiptData(ReceiptData()).copyWith(
        amountText: '10',
        date: DateTime(2026, 7, 1),
      );
      final companion = draft.toCompanion();
      expect(companion.merchant.value, 'Unknown');
      expect(companion.amount.value, 10.0);
    });
  });

  group('ReceiptItemDraft', () {
    test('unitPriceFromTotal is derived from total / quantity', () {
      final item = ReceiptItemDraft(id: 'i1', name: 'Tea', quantity: 3, total: 45);
      expect(item.unitPriceFromTotal, 15.0);
    });

    test('unitPriceFromTotal is null when quantity is 0', () {
      final item = ReceiptItemDraft(id: 'i1', name: 'Tea', quantity: 0, total: 45);
      expect(item.unitPriceFromTotal, isNull);
    });

    test('toCompanion stores weight when present', () {
      final item = ReceiptItemDraft(
        id: 'i1',
        name: 'Apples',
        quantity: 2,
        unitPrice: 30,
        weight: 2.5,
        total: 60,
      );
      final companion = item.toCompanion('tx1');
      expect(companion.weight.value, 2.5);
      expect(companion.unitPrice.value, 30.0);
    });

    test('toCompanion stores a null weight when not set', () {
      final item = ReceiptItemDraft(id: 'i1', name: 'Tea', quantity: 3, total: 45);
      expect(item.toCompanion('tx1').weight.value, isNull);
    });
  });

  group('ReceiptDraft items from ReceiptData', () {
    test('populates items from ReceiptData', () {
      final data = ReceiptData(
        merchant: 'Toko',
        amount: 100,
        items: [
          const ReceiptItem(name: 'Item A', total: 60),
          const ReceiptItem(name: 'Item B', total: 40),
        ],
      );
      final draft = ReceiptDraft.fromReceiptData(data);
      expect(draft.items.length, 2);
      expect(draft.items[0].name, 'Item A');
      expect(draft.items[0].total, 60);
    });

    test('preserves items through copyWith', () {
      final data = ReceiptData(
        merchant: 'Toko',
        amount: 50,
        items: [const ReceiptItem(name: 'Item A', total: 50)],
      );
      final draft = ReceiptDraft.fromReceiptData(data).copyWith(amountText: '55');
      expect(draft.items.length, 1);
      expect(draft.items[0].name, 'Item A');
    });

    test('maps weight and unitPrice from ReceiptData', () {
      final data = ReceiptData(
        merchant: 'Toko',
        amount: 60,
        items: [
          const ReceiptItem(
            name: 'Apples',
            quantity: 2,
            unitPrice: 30,
            weight: 2.5,
            total: 60,
          ),
        ],
      );
      final draft = ReceiptDraft.fromReceiptData(data);
      expect(draft.items[0].weight, 2.5);
      expect(draft.items[0].unitPrice, 30.0);
    });
  });
}
