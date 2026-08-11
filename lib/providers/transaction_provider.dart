import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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

final showOcrDebugProvider = FutureProvider<bool>((ref) {
  return PreferencesService().getShowOcrDebug();
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

final selectedMonthProvider =
    NotifierProvider<SelectedMonthNotifier, DateTime>(SelectedMonthNotifier.new);

class SelectedMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  void select(DateTime month) => state = DateTime(month.year, month.month);
}

/// Presets for the analytics date filter. `custom` holds a user-picked range.
enum AnalyticsRangePreset {
  allTime,
  last30Days,
  last90Days,
  last6Months,
  thisYear,
  custom,
}

class AnalyticsRangeSelection {
  final AnalyticsRangePreset preset;
  final DateTimeRange? customRange;

  const AnalyticsRangeSelection({
    required this.preset,
    this.customRange,
  });

  DateTimeRange? effectiveRange(DateTime now) {
    switch (preset) {
      case AnalyticsRangePreset.allTime:
        return null;
      case AnalyticsRangePreset.last30Days:
        return DateTimeRange(
          start: now.subtract(const Duration(days: 30)),
          end: now,
        );
      case AnalyticsRangePreset.last90Days:
        return DateTimeRange(
          start: now.subtract(const Duration(days: 90)),
          end: now,
        );
      case AnalyticsRangePreset.last6Months:
        return DateTimeRange(
          start: DateTime(now.year, now.month - 6),
          end: now,
        );
      case AnalyticsRangePreset.thisYear:
        return DateTimeRange(start: DateTime(now.year), end: now);
      case AnalyticsRangePreset.custom:
        return customRange;
    }
  }

  String label(DateTime now) {
    if (preset == AnalyticsRangePreset.custom) {
      final range = customRange;
      if (range == null) return 'Custom';
      final fmt = DateFormat.yMMMd();
      return '${fmt.format(range.start)} – ${fmt.format(range.end)}';
    }
    switch (preset) {
      case AnalyticsRangePreset.allTime:
        return 'All time';
      case AnalyticsRangePreset.last30Days:
        return 'Last 30 days';
      case AnalyticsRangePreset.last90Days:
        return 'Last 90 days';
      case AnalyticsRangePreset.last6Months:
        return 'Last 6 months';
      case AnalyticsRangePreset.thisYear:
        return 'This year';
      case AnalyticsRangePreset.custom:
        return 'Custom';
    }
  }
}

final analyticsRangeProvider =
    NotifierProvider<AnalyticsRangeNotifier, AnalyticsRangeSelection>(
  AnalyticsRangeNotifier.new,
);

class AnalyticsRangeNotifier extends Notifier<AnalyticsRangeSelection> {
  @override
  AnalyticsRangeSelection build() =>
      const AnalyticsRangeSelection(preset: AnalyticsRangePreset.last30Days);

  void selectPreset(AnalyticsRangePreset preset) {
    state = AnalyticsRangeSelection(preset: preset);
  }

  void selectCustom(DateTimeRange range) {
    state = AnalyticsRangeSelection(
      preset: AnalyticsRangePreset.custom,
      customRange: range,
    );
  }

  void reset() => state = build();
}

final transactionQueryProvider =
    NotifierProvider<TransactionQueryNotifier, TransactionQuery>(
  TransactionQueryNotifier.new,
);

class TransactionQueryNotifier extends Notifier<TransactionQuery> {
  @override
  TransactionQuery build() => const TransactionQuery();

  void update(TransactionQuery Function(TransactionQuery) change) {
    state = change(state);
  }
}

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

final allTransactionItemsProvider =
    FutureProvider<List<TransactionItemEntity>>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.getAllItems();
});

final filteredTransactionsProvider =
    StreamProvider<List<TransactionEntity>>((ref) {
  final query = ref.watch(transactionQueryProvider);
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.watchTransactions(query);
});

final budgetsProvider = StreamProvider<List<BudgetEntity>>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.watchAllBudgets();
});

final shoppingListsProvider = StreamProvider<List<ShoppingListEntity>>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.watchShoppingLists();
});

final shoppingListItemsFamily =
    StreamProvider.family<List<ShoppingListItemEntity>, String>((ref, listId) {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.watchShoppingListItems(listId);
});
