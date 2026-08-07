import 'package:drift/drift.dart';

import '../../core/models/transaction_type.dart';
import '../../core/utils/receipt_parser.dart';
import '../../data/database/database.dart';

class ReceiptItemDraft {
  String id;
  String name;
  double quantity;
  double total;

  ReceiptItemDraft({
    required this.id,
    required this.name,
    this.quantity = 1,
    required this.total,
  });

  double? get unitPrice => quantity > 0 ? total / quantity : null;

  TransactionItemsCompanion toCompanion(String transactionId) {
    return TransactionItemsCompanion.insert(
      id: id,
      transactionId: transactionId,
      name: name,
      quantity: Value(quantity),
      unitPrice: Value(unitPrice),
      total: total,
    );
  }
}

class ReceiptDraft {
  final String merchant;
  final String amountText;
  final DateTime date;
  final String category;
  final TransactionType type;
  final String note;
  final List<ReceiptItemDraft> items;

  ReceiptDraft({
    required this.merchant,
    required this.amountText,
    required this.date,
    required this.category,
    required this.type,
    required this.note,
    this.items = const [],
  });

  factory ReceiptDraft.fromReceiptData(ReceiptData data) {
    return ReceiptDraft(
      merchant: data.merchant ?? '',
      amountText: data.amount != null ? _formatAmount(data.amount!) : '',
      date: data.date ?? DateTime.now(),
      category: 'cat_food',
      type: TransactionType.expense,
      note: '',
      items: [
        for (int i = 0; i < data.items.length; i++)
          ReceiptItemDraft(
            id: 'item_$i',
            name: data.items[i].name,
            quantity: data.items[i].quantity,
            total: data.items[i].total,
          ),
      ],
    );
  }

  ReceiptDraft copyWith({
    String? merchant,
    String? amountText,
    DateTime? date,
    String? category,
    TransactionType? type,
    String? note,
    List<ReceiptItemDraft>? items,
  }) {
    return ReceiptDraft(
      merchant: merchant ?? this.merchant,
      amountText: amountText ?? this.amountText,
      date: date ?? this.date,
      category: category ?? this.category,
      type: type ?? this.type,
      note: note ?? this.note,
      items: items ?? this.items,
    );
  }

  TransactionsCompanion toCompanion() {
    return TransactionsCompanion.insert(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: date,
      amount: double.parse(amountText),
      category: category,
      merchant: merchant.isEmpty ? 'Unknown' : merchant,
      note: note,
      type: type,
    );
  }

  static String _formatAmount(double value) {
    return value == value.truncateToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }
}
