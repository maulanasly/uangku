import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
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
            icon: const Icon(Icons.receipt_long),
            onPressed: () => context.push('/transactions'),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
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
                            child: Text('No expenses in ${DateFormat.yMMMM().format(selectedMonth)}'),
                          ),
                        )
                      else
                        SizedBox(
                          height: 220,
                          child: PieChart(
                            PieChartData(
                              sections: _buildSections(summary.categoryBreakdown, categoryName),
                            ),
                          ),
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
                        child: ListTile(
                          onTap: () => context.push('/add_transaction', extra: t),
                          leading: CircleAvatar(
                            backgroundColor: isExpense ? Colors.red.withValues(alpha: 0.2) : Colors.green.withValues(alpha: 0.2),
                            child: Icon(
                              isExpense ? Icons.arrow_downward : Icons.arrow_upward,
                              color: isExpense ? Colors.red : Colors.green,
                            ),
                          ),
                          title: Text(t.merchant),
                          subtitle: Text(DateFormat.yMMMd().format(t.date)),
                          trailing: Text(
                            '${isExpense ? "-" : "+"}${currencyFormat.format(t.amount)}',
                            style: TextStyle(
                              color: isExpense ? Colors.red : Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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

  List<PieChartSectionData> _buildSections(
    Map<String, double> breakdown,
    String Function(String) categoryName,
  ) {
    const palette = [
      Colors.blue,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.lime,
      Colors.brown,
    ];

    final total = breakdown.values.fold<double>(0, (a, b) => a + b);
    final sorted = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return [
      for (var i = 0; i < sorted.length; i++)
        PieChartSectionData(
          color: palette[i % palette.length],
          value: sorted[i].value,
          title: '${categoryName(sorted[i].key)}\n${((sorted[i].value / total) * 100).toStringAsFixed(0)}%',
          radius: 50,
          titleStyle: const TextStyle(fontSize: 11, color: Colors.white),
        ),
    ];
  }
}
