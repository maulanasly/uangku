import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../providers/transaction_provider.dart';
import '../../providers/database_provider.dart';
import '../../core/ui/receipt_image_dialog.dart';
import '../../core/utils/money_format.dart';
import '../../core/utils/summary_calculator.dart';
import '../../data/database/database.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final budgetsAsync = ref.watch(budgetsProvider);
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

          final budgets = budgetsAsync.valueOrNull ?? [];
          final budgetSummary = SummaryCalculator.budgetForMonth(
            transactions,
            budgets,
            selectedMonth,
          );
          final monthTransactions = SummaryCalculator.filterByMonth(transactions, selectedMonth);

          final categories = categoriesAsync.valueOrNull ?? [];
          String categoryName(String id) {
            return categories.firstWhere(
              (c) => c.id == id,
              orElse: () => categories.isEmpty
                  ? CategoryEntity(id: id, name: id, icon: 'category')
                  : categories.first,
            ).name;
          }

          final currencyFormat = moneyFormat(currencySymbol);
          final isCurrentMonth = SummaryCalculator.isSameMonth(selectedMonth, DateTime.now());

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(transactionsProvider);
              ref.invalidate(categoriesProvider);
              ref.invalidate(budgetsProvider);
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
                            '${DateFormat.yMMMM().format(selectedMonth)} spending',
                            style: const TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          Text(
                            currencyFormat.format(budgetSummary.totalSpent),
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          if (budgetSummary.totalBudget > 0) ...[
                            Text(
                              'of ${currencyFormat.format(budgetSummary.totalBudget)} budget',
                              style: const TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                            const SizedBox(height: 12),
                            _BudgetProgressBar(summary: budgetSummary),
                            const SizedBox(height: 8),
                            Text(
                              budgetSummary.remaining >= 0
                                  ? '${currencyFormat.format(budgetSummary.remaining)} remaining'
                                  : '${currencyFormat.format(-budgetSummary.remaining)} over budget',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: budgetSummary.remaining >= 0
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                              ),
                            ),
                          ] else
                            const Text(
                              'No budgets set yet',
                              style: TextStyle(fontSize: 13, color: Colors.grey),
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
                      if (budgetSummary.categorySpent.isEmpty)
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
                          spent: budgetSummary.categorySpent,
                          budget: budgetSummary.categoryBudget,
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
                              leading: const CircleAvatar(
                                backgroundColor: Color(0x33F44336),
                                child: Icon(
                                  Icons.arrow_downward,
                                  color: Colors.red,
                                ),
                              ),
                              title: Text(t.merchant),
                              subtitle: itemsAsync.when(
                                data: (items) => Row(
                                  children: [
                                    if (t.receiptImagePath != null)
                                      InkWell(
                                        onTap: () => showReceiptImageDialog(context, t),
                                        child: const Padding(
                                          padding: EdgeInsets.only(right: 4),
                                          child: Icon(Icons.photo, size: 14, color: Colors.grey),
                                        ),
                                      ),
                                    Text(items.isEmpty
                                        ? DateFormat.yMMMd().format(t.date)
                                        : '${DateFormat.yMMMd().format(t.date)} · ${items.length} items',
                                    ),
                                  ],
                                ),
                                loading: () => Text(DateFormat.yMMMd().format(t.date)),
                                error: (_, __) => Text(DateFormat.yMMMd().format(t.date)),
                              ),
                              trailing: Text(
                                '-${currencyFormat.format(t.amount)}',
                                style: const TextStyle(
                                  color: Colors.red,
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
                    child: Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  SizedBox(
                    width: 56,
                    child: Text(
                      item.quantity == item.quantity.truncateToDouble()
                          ? '${item.quantity.toInt()}x'
                          : '${item.quantity}x',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text(
                      currencyFormat.format(item.total),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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

class _BudgetProgressBar extends StatelessWidget {
  final BudgetSummary summary;

  const _BudgetProgressBar({required this.summary});

  @override
  Widget build(BuildContext context) {
    final ratio = summary.spentRatio().clamp(0.0, 1.0);
    final over = summary.totalSpent > summary.totalBudget;
    final color = over ? Colors.red.shade400 : Theme.of(context).colorScheme.primary;

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        value: ratio,
        minHeight: 12,
        backgroundColor: color.withValues(alpha: 0.15),
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}

class _HorizontalCategoryBars extends StatelessWidget {
  final Map<String, double> spent;
  final Map<String, double> budget;
  final String Function(String) categoryName;
  final NumberFormat currencyFormat;

  const _HorizontalCategoryBars({
    required this.spent,
    required this.budget,
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
    final sorted = spent.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: [
        for (var i = 0; i < sorted.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _CategoryBarRow(
            label: categoryName(sorted[i].key),
            amount: sorted[i].value,
            limit: budget[sorted[i].key],
            color: _palette[i % _palette.length],
            currencyFormat: currencyFormat,
          ),
        ],
      ],
    );
  }
}

class _CategoryBarRow extends StatelessWidget {
  final String label;
  final double amount;
  final double? limit;
  final Color color;
  final NumberFormat currencyFormat;

  const _CategoryBarRow({
    required this.label,
    required this.amount,
    required this.limit,
    required this.color,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context) {
    final hasBudget = limit != null && limit! > 0;
    final fraction = hasBudget ? amount / limit! : 0.0;
    final over = hasBudget && amount > limit!;
    final percent = hasBudget
        ? ((fraction.clamp(0.0, 1.0)) * 100).toStringAsFixed(0)
        : '';

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
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: hasBudget ? fraction.clamp(0.0, 1.0) : 0.0,
              heightFactor: 1,
              child: Container(
                height: 18,
                decoration: BoxDecoration(
                  color: over ? Colors.red.shade400 : color.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: hasBudget ? 100 : 72,
          child: Text(
            hasBudget
                ? '${currencyFormat.format(amount)}/${currencyFormat.format(limit!)}'
                : currencyFormat.format(amount),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: over ? Colors.red.shade700 : null,
            ),
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 36,
          child: Text(
            hasBudget ? '$percent%' : '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ),
      ],
    );
  }
}
