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
}
