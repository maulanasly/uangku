import '../models/transaction_type.dart';

enum TransactionSortField {
  date,
  amount,
}

enum SortDirection {
  asc,
  desc,
}

class TransactionQuery {
  final String search;
  final TransactionType? type;
  final String? category;
  final TransactionSortField sortField;
  final SortDirection direction;

  const TransactionQuery({
    this.search = '',
    this.type,
    this.category,
    this.sortField = TransactionSortField.date,
    this.direction = SortDirection.desc,
  });
}
