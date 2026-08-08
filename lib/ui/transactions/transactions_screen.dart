import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/transaction_query.dart';
import '../../core/models/transaction_type.dart';
import '../../core/ui/receipt_image_dialog.dart';
import '../../data/database/database.dart';
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
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(transactionsProvider);
                ref.invalidate(categoriesProvider);
                ref.invalidate(filteredTransactionsProvider);
                ref.invalidate(currencySymbolProvider);
              },
              child: transactionsAsync.when(
              data: (transactions) {
                if (transactions.isEmpty) {
                  return ListView(
                    children: const [
                      SizedBox(height: 200),
                      Center(child: Text('No transactions found')),
                    ],
                  );
                }
                final currencyFormat = NumberFormat.currency(symbol: currencySymbol, decimalDigits: 2);
                return ListView.builder(
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final t = transactions[index];
                    final isExpense = t.type == TransactionType.expense;
                    final itemsAsync =
                        ref.watch(transactionItemsFamily(t.id));
                    return ExpansionTile(
                      onExpansionChanged: (expanded) {},
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
                      subtitle: Row(
                        children: [
                          if (t.receiptImagePath != null)
                            InkWell(
                              onTap: () => showReceiptImageDialog(context, t),
                              child: const Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: Icon(Icons.photo, size: 14, color: Colors.grey),
                              ),
                            ),
                          Text(
                            '${DateFormat.yMMMd().format(t.date)} · ${t.category}',
                          ),
                        ],
                      ),
                      trailing: Text(
                        '${isExpense ? "-" : "+"}${currencyFormat.format(t.amount)}',
                        style: TextStyle(
                          color: isExpense ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      children: [
                        itemsAsync.when(
                          data: (items) => _buildItemDetails(items, currencyFormat),
                          loading: () => const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                      ],
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
            ),
          ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemDetails(
    List<TransactionItemEntity> items,
    NumberFormat currencyFormat,
  ) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Text('No line items', style: TextStyle(color: Colors.grey)),
      );
    }
    final total = items.fold<double>(0, (s, i) => s + i.total);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(item.name, style: const TextStyle(fontSize: 13)),
                  ),
                  SizedBox(
                    width: 56,
                    child: Text(
                      item.quantity == item.quantity.truncateToDouble()
                          ? '${item.quantity.toInt()}x'
                          : '${item.quantity}x',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text(
                      currencyFormat.format(item.total),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          const Divider(),
          Row(
            children: [
              const Spacer(),
              SizedBox(
                width: 80,
                child: Text(
                  currencyFormat.format(total),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
