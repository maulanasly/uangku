import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/utils/money_format.dart';
import '../../core/utils/price_history_calculator.dart';
import '../../data/database/database.dart';
import '../../providers/transaction_provider.dart';

class ItemPriceHistoryScreen extends ConsumerStatefulWidget {
  const ItemPriceHistoryScreen({super.key});

  @override
  ConsumerState<ItemPriceHistoryScreen> createState() =>
      _ItemPriceHistoryScreenState();
}

class _ItemPriceHistoryScreenState extends ConsumerState<ItemPriceHistoryScreen> {
  late final TextEditingController _searchController;
  String _search = '';

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

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final itemsAsync = ref.watch(allTransactionItemsProvider);
    final currencySymbol = ref.watch(currencySymbolProvider).value ?? '\$';
    final currencyFormat = moneyFormat(currencySymbol);

    return Scaffold(
      appBar: AppBar(title: const Text('Item Price History')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search item name',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _search = value.trim()),
            ),
          ),
          Expanded(
            child: transactionsAsync.when(
              data: (transactions) {
                return itemsAsync.when(
                  data: (items) => _buildList(transactions, items, currencyFormat),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, st) => Center(child: Text('Error: $e')),
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

  Widget _buildList(
    List<TransactionEntity> transactions,
    List<TransactionItemEntity> items,
    NumberFormat currencyFormat,
  ) {
    final histories = PriceHistoryCalculator.buildPriceHistory(transactions, items);
    final search = _search.toLowerCase();
    final filtered = search.isEmpty
        ? histories
        : histories
            .where((h) => h.name.toLowerCase().contains(search))
            .toList();

    if (filtered.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Center(
            child: Text(
              search.isEmpty
                  ? 'No item data yet'
                  : 'No items match "$_search"',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
        ],
      );
    }

    final dateFormat = DateFormat.yMMMd();
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final history = filtered[index];
        final latest = history.latestPrice;
        return ListTile(
          leading: const CircleAvatar(
            radius: 20,
            child: Icon(Icons.receipt_long),
          ),
          title: Text(history.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            'Bought ${history.purchaseCount}x · last ${dateFormat.format(history.points.last.date)}',
          ),
          trailing: Text(
            latest == null ? '—' : currencyFormat.format(latest),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          onTap: () => context.push(
            '/item_price_detail',
            extra: history.name,
          ),
        );
      },
    );
  }
}