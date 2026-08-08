import 'package:flutter/material.dart';
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

final ocrModeProvider = FutureProvider<String>((ref) {
  return PreferencesService().getOcrMode();
});

final themeModeProvider = FutureProvider<ThemeMode>((ref) async {
  final pref = await PreferencesService().getThemeModePref();
  switch (pref) {
    case 'dark':
      return ThemeMode.dark;
    case 'light':
      return ThemeMode.light;
    default:
      return ThemeMode.system;
  }
});

final selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

final transactionQueryProvider =
    StateProvider<TransactionQuery>((ref) => const TransactionQuery());

/// Transactions that have a saved receipt image.
final receiptTransactionsProvider =
    FutureProvider<List<TransactionEntity>>((ref) async {
  final transactions = await ref.watch(transactionsProvider.future);
  return transactions.where((t) => t.receiptImagePath != null).toList();
});

final transactionItemsFamily =
    FutureProvider.family<List<TransactionItemEntity>, String>(
  (ref, id) async {
    final repo = ref.watch(transactionRepositoryProvider);
    return repo.watchItemsFor(id).first;
  },
);

final filteredTransactionsProvider = StreamProvider<List<TransactionEntity>>((ref) {
  final query = ref.watch(transactionQueryProvider);
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.watchTransactions(query);
});

final budgetsProvider = StreamProvider<List<BudgetEntity>>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.watchAllBudgets();
});
