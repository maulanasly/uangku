import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/models/transaction_query.dart';
import '../../core/models/transaction_type.dart';
import '../../providers/transaction_provider.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _update(TransactionQuery Function(TransactionQuery) change) {
    ref.read(transactionQueryProvider.notifier).state = change(ref.read(transactionQueryProvider));
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(transactionQueryProvider);
    final transactionsAsync = ref.watch(filteredTransactionsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final categories = categoriesAsync.valueOrNull ?? [];
    final currencySymbol = ref.watch(currencySymbolProvider).valueOrNull ?? '\$';

    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search merchant or note',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => _update(
                    (q) => TransactionQuery(
                      search: value,
                      type: q.type,
                      category: q.category,
                      sortField: q.sortField,
                      direction: q.direction,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<TransactionType?>(
                  segments: const [
                    ButtonSegment(value: null, label: Text('All')),
                    ButtonSegment(value: TransactionType.expense, label: Text('Expense')),
                    ButtonSegment(value: TransactionType.income, label: Text('Income')),
                  ],
                  selected: {query.type},
                  onSelectionChanged: (selection) => _update(
                    (q) => TransactionQuery(
                      search: q.search,
                      type: selection.first,
                      category: q.category,
                      sortField: q.sortField,
                      direction: q.direction,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        initialValue: query.category,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All'),
                          ),
                          for (final c in categories)
                            DropdownMenuItem<String?>(
                              value: c.id,
                              child: Text(c.name),
                            ),
                        ],
                        onChanged: (value) => _update(
                          (q) => TransactionQuery(
                            search: q.search,
                            type: q.type,
                            category: value,
                            sortField: q.sortField,
                            direction: q.direction,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<TransactionSortField>(
                        initialValue: query.sortField,
                        decoration: const InputDecoration(
                          labelText: 'Sort by',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: TransactionSortField.date, child: Text('Date')),
                          DropdownMenuItem(value: TransactionSortField.amount, child: Text('Amount')),
                        ],
                        onChanged: (value) => _update(
                          (q) => TransactionQuery(
                            search: q.search,
                            type: q.type,
                            category: q.category,
                            sortField: value ?? q.sortField,
                            direction: q.direction,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: query.direction == SortDirection.desc ? 'Descending' : 'Ascending',
                      icon: Icon(
                        query.direction == SortDirection.desc
                            ? Icons.arrow_downward
                            : Icons.arrow_upward,
                      ),
                      onPressed: () => _update(
                        (q) => TransactionQuery(
                          search: q.search,
                          type: q.type,
                          category: q.category,
                          sortField: q.sortField,
                          direction: q.direction == SortDirection.desc
                              ? SortDirection.asc
                              : SortDirection.desc,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: transactionsAsync.when(
              data: (transactions) {
                if (transactions.isEmpty) {
                  return const Center(child: Text('No transactions found'));
                }
                final currencyFormat = NumberFormat.currency(symbol: currencySymbol, decimalDigits: 2);
                return ListView.builder(
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final t = transactions[index];
                    final isExpense = t.type == TransactionType.expense;
                    return ListTile(
                      onTap: () => context.push('/add_transaction', extra: t),
                      leading: CircleAvatar(
                        backgroundColor: isExpense
                            ? Colors.red.withValues(alpha: 0.2)
                            : Colors.green.withValues(alpha: 0.2),
                        child: Icon(
                          isExpense ? Icons.arrow_downward : Icons.arrow_upward,
                          color: isExpense ? Colors.red : Colors.green,
                        ),
                      ),
                      title: Text(t.merchant),
                      subtitle: Text(
                        '${DateFormat.yMMMd().format(t.date)} · ${t.category}',
                      ),
                      trailing: Text(
                        '${isExpense ? "-" : "+"}${currencyFormat.format(t.amount)}',
                        style: TextStyle(
                          color: isExpense ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}
