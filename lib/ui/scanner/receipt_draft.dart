import '../../core/models/transaction_type.dart';
import '../../core/utils/receipt_parser.dart';
import '../../data/database/database.dart';

class ReceiptDraft {
  final String merchant;
  final String amountText;
  final DateTime date;
  final String category;
  final TransactionType type;
  final String note;

  const ReceiptDraft({
    required this.merchant,
    required this.amountText,
    required this.date,
    required this.category,
    required this.type,
    required this.note,
  });

  factory ReceiptDraft.fromReceiptData(ReceiptData data) {
    return ReceiptDraft(
      merchant: data.merchant ?? '',
      amountText: data.amount != null ? _formatAmount(data.amount!) : '',
      date: data.date ?? DateTime.now(),
      category: 'cat_food',
      type: TransactionType.expense,
      note: '',
    );
  }

  ReceiptDraft copyWith({
    String? merchant,
    String? amountText,
    DateTime? date,
    String? category,
    TransactionType? type,
    String? note,
  }) {
    return ReceiptDraft(
      merchant: merchant ?? this.merchant,
      amountText: amountText ?? this.amountText,
      date: date ?? this.date,
      category: category ?? this.category,
      type: type ?? this.type,
      note: note ?? this.note,
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
