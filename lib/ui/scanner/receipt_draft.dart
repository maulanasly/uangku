import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/models/transaction_type.dart';
import '../../core/utils/receipt_parser.dart';
import '../../data/database/database.dart';

class ReceiptItemDraft {
  String id;
  String name;
  double quantity;
  double? unitPrice;
  double? weight;
  double total;

  ReceiptItemDraft({
    required this.id,
    required this.name,
    this.quantity = 1,
    this.unitPrice,
    this.weight,
    required this.total,
  });

  double? get unitPriceFromTotal => quantity > 0 ? total / quantity : null;

  TransactionItemsCompanion toCompanion(String transactionId) {
    return TransactionItemsCompanion.insert(
      id: id,
      transactionId: transactionId,
      name: name,
      quantity: Value(quantity),
      unitPrice: Value(unitPrice ?? unitPriceFromTotal),
      weight: Value(weight),
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
  final String? receiptImagePath;
  final List<ReceiptItemDraft> items;

  ReceiptDraft({
    required this.merchant,
    required this.amountText,
    required this.date,
    required this.category,
    required this.type,
    required this.note,
    this.receiptImagePath,
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
        for (final item in data.items)
          ReceiptItemDraft(
            id: const Uuid().v4(),
            name: item.name,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
            weight: item.weight,
            total: item.total,
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
    String? receiptImagePath,
    List<ReceiptItemDraft>? items,
  }) {
    return ReceiptDraft(
      merchant: merchant ?? this.merchant,
      amountText: amountText ?? this.amountText,
      date: date ?? this.date,
      category: category ?? this.category,
      type: type ?? this.type,
      note: note ?? this.note,
      receiptImagePath: receiptImagePath ?? this.receiptImagePath,
      items: items ?? this.items,
    );
  }

  TransactionsCompanion toCompanion() {
    return TransactionsCompanion.insert(
      id: const Uuid().v4(),
      date: date,
      amount: double.parse(amountText),
      category: category,
      merchant: merchant.isEmpty ? 'Unknown' : merchant,
      note: note,
      type: type,
      receiptImagePath: Value(receiptImagePath),
    );
  }

  static String _formatAmount(double value) {
    return value == value.truncateToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }
}
