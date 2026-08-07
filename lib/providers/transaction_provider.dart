import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database_provider.dart';
import '../data/database/database.dart';
import '../core/models/transaction_query.dart';
import '../core/services/preferences_service.dart';

final transactionsProvider = StreamProvider<List<TransactionEntity>>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.watchAllTransactions();
});

final categoriesProvider = FutureProvider<List<CategoryEntity>>((ref) async {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.getCategories();
});

final currencySymbolProvider = FutureProvider<String>((ref) {
  return PreferencesService().getCurrencySymbol();
});

final transactionQueryProvider =
    StateProvider<TransactionQuery>((ref) => const TransactionQuery());

final filteredTransactionsProvider = StreamProvider<List<TransactionEntity>>((ref) {
  final query = ref.watch(transactionQueryProvider);
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.watchTransactions(query);
});
