import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../providers/transaction_provider.dart';
import '../../providers/database_provider.dart';
import '../../core/models/transaction_type.dart';
import '../../core/utils/summary_calculator.dart';
import '../../data/database/database.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final currencySymbol = ref.watch(currencySymbolProvider).valueOrNull ?? '\$';
    final selectedMonth = ref.watch(selectedMonthProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Money Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.collections_bookmark),
            onPressed: () => context.push('/receipts'),
          ),
        ],
      ),
      body: transactionsAsync.when(
        data: (transactions) {
          if (transactions.isEmpty) {
            return const Center(child: Text('No transactions yet. Scan a receipt!'));
          }

          final monthTransactions = SummaryCalculator.filterByMonth(transactions, selectedMonth);
          final summary = SummaryCalculator.forMonth(transactions, selectedMonth);

          final categories = categoriesAsync.valueOrNull ?? [];
          String categoryName(String id) {
            return categories.firstWhere(
              (c) => c.id == id,
              orElse: () => categories.isEmpty
                  ? CategoryEntity(id: id, name: id, icon: 'category')
                  : categories.first,
            ).name;
          }

          final currencyFormat = NumberFormat.currency(symbol: currencySymbol, decimalDigits: 2);
          final isCurrentMonth = SummaryCalculator.isSameMonth(selectedMonth, DateTime.now());

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(transactionsProvider);
              ref.invalidate(categoriesProvider);
              ref.invalidate(currencySymbolProvider);
            },
            child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: GestureDetector(
                    onHorizontalDragEnd: (details) {
                      if (details.primaryVelocity == null) return;
                      if (details.primaryVelocity! < -30) {
                        ref.read(selectedMonthProvider.notifier).state =
                            SummaryCalculator.shiftMonth(selectedMonth, 1);
                      } else if (details.primaryVelocity! > 30) {
                        ref.read(selectedMonthProvider.notifier).state =
                            SummaryCalculator.shiftMonth(selectedMonth, -1);
                      }
                    },
                    child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left),
                                onPressed: () => ref.read(selectedMonthProvider.notifier).state =
                                    SummaryCalculator.shiftMonth(selectedMonth, -1),
                              ),
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      DateFormat.yMMMM().format(selectedMonth),
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    if (!isCurrentMonth)
                                      TextButton(
                                        onPressed: () {
                                          final now = DateTime.now();
                                          ref.read(selectedMonthProvider.notifier).state =
                                              DateTime(now.year, now.month);
                                        },
                                        child: const Text('Back to today'),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right),
                                onPressed: () => ref.read(selectedMonthProvider.notifier).state =
                                    SummaryCalculator.shiftMonth(selectedMonth, 1),
                              ),
                            ],
                          ),
                          Text(
                            currencyFormat.format(summary.balance),
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Income', style: TextStyle(color: Colors.green)),
                                  Text(currencyFormat.format(summary.income), style: const TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Expense', style: TextStyle(color: Colors.red)),
                                  Text(currencyFormat.format(summary.expense), style: const TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Spending by Category', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (summary.categoryBreakdown.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'No expenses in ${DateFormat.yMMMM().format(selectedMonth)}',
                            ),
                          ),
                        )
                      else
                        _HorizontalCategoryBars(
                          breakdown: summary.categoryBreakdown,
                          categoryName: categoryName,
                          currencyFormat: currencyFormat,
                        ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Recent Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              if (monthTransactions.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: Text('No transactions in ${DateFormat.yMMMM().format(selectedMonth)}'),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final t = monthTransactions[index];
                      final isExpense = t.type == TransactionType.expense;
                      return Dismissible(
                        key: Key(t.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (direction) {
                          final repo = ref.read(transactionRepositoryProvider);
                          repo.deleteTransaction(t.id);
                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Transaction deleted'),
                              action: SnackBarAction(
                                label: 'Undo',
                                onPressed: () {
                                  repo.addTransaction(t);
                                },
                              ),
                            ),
                          );
                        },
                        child: Consumer(
                          builder: (context, ref, _) {
                            final itemsAsync = ref.watch(transactionItemsFamily(t.id));
                            return ExpansionTile(
                              leading: CircleAvatar(
                                backgroundColor: isExpense ? Colors.red.withValues(alpha: 0.2) : Colors.green.withValues(alpha: 0.2),
                                child: Icon(
                                  isExpense ? Icons.arrow_downward : Icons.arrow_upward,
                                  color: isExpense ? Colors.red : Colors.green,
                                ),
                              ),
                              title: Text(t.merchant),
                              subtitle: itemsAsync.when(
                                data: (items) => Text(items.isEmpty
                                    ? DateFormat.yMMMd().format(t.date)
                                    : '${DateFormat.yMMMd().format(t.date)} · ${items.length} items'),
                                loading: () => Text(DateFormat.yMMMd().format(t.date)),
                                error: (_, __) => Text(DateFormat.yMMMd().format(t.date)),
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
                        ),
                      );
                    },
                    childCount: monthTransactions.length,
                  ),
                ),
            ],
          ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            builder: (context) {
              return SafeArea(
                child: Wrap(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.edit),
                      title: const Text('Add Manually'),
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/add_transaction');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.camera_alt),
                      title: const Text('Scan Receipt'),
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/scanner');
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
        child: const Icon(Icons.add),
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

class _HorizontalCategoryBars extends StatelessWidget {
  final Map<String, double> breakdown;
  final String Function(String) categoryName;
  final NumberFormat currencyFormat;

  const _HorizontalCategoryBars({
    required this.breakdown,
    required this.categoryName,
    required this.currencyFormat,
  });

  static const _palette = [
    Color(0xFF4F8CFF),
    Color(0xFF38C6A0),
    Color(0xFFF59E0B),
    Color(0xFFFF6B6B),
    Color(0xFFA78BFA),
    Color(0xFFF472B6),
    Color(0xFF34D399),
    Color(0xFFFBBF24),
  ];

  @override
  Widget build(BuildContext context) {
    final total = breakdown.values.fold<double>(0, (a, b) => a + b);
    final sorted = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: [
        for (var i = 0; i < sorted.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _CategoryBarRow(
            label: categoryName(sorted[i].key),
            amount: sorted[i].value,
            total: total,
            color: _palette[i % _palette.length],
            currencyFormat: currencyFormat,
          ),
        ],
        const SizedBox(height: 12),
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              const Spacer(),
              SizedBox(
                width: 80,
                child: Text(
                  currencyFormat.format(total),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryBarRow extends StatelessWidget {
  final String label;
  final double amount;
  final double total;
  final Color color;
  final NumberFormat currencyFormat;

  const _CategoryBarRow({
    required this.label,
    required this.amount,
    required this.total,
    required this.color,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = total > 0 ? amount / total : 0.0;
    final percent = (fraction * 100).toStringAsFixed(0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxBarWidth = constraints.maxWidth - 168;
        return Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 100,
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              height: 18,
              width: maxBarWidth * fraction,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: 72,
              child: Text(
                currencyFormat.format(amount),
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: 36,
              child: Text(
                '$percent%',
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
          ],
        );
      },
    );
  }
}
