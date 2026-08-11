import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/ui/add_expense_sheet.dart';
import '../../core/ui/empty_state.dart';
import '../../core/utils/analytics_calculator.dart';
import '../../core/utils/item_analytics_calculator.dart';
import '../../core/utils/money_format.dart';
import '../../core/utils/summary_calculator.dart';
import '../../providers/transaction_provider.dart';
import '../../data/database/database.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final budgetsAsync = ref.watch(budgetsProvider);
    final itemsAsync = ref.watch(allTransactionItemsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: transactionsAsync.when(
        data: (transactions) {
          if (transactions.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(transactionsProvider);
                ref.invalidate(categoriesProvider);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 120),
                  EmptyState(
                    icon: Icons.insights,
                    title: 'No data to analyze',
                    subtitle: 'Add expenses to unlock spending insights and trends.',
                    actionLabel: 'Add Expense',
                    onAction: () => showAddExpenseSheet(context),
                  ),
                ],
              ),
            );
          }

          final rangeSelection = ref.watch(analyticsRangeProvider);
          final now = DateTime.now();
          final range = rangeSelection.effectiveRange(now);
          final scoped = range == null
              ? transactions
              : transactions
                  .where(
                    (t) =>
                        !t.date.isBefore(range.start) &&
                        !t.date.isAfter(range.end),
                  )
                  .toList();

          if (scoped.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(transactionsProvider);
                ref.invalidate(categoriesProvider);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 16),
                  const _AnalyticsRangeChips(),
                  const SizedBox(height: 120),
                  EmptyState(
                    icon: Icons.event_busy,
                    title: 'No spending in this period',
                    subtitle: 'Try a wider date range or reset the filter.',
                    actionLabel: 'Reset filter',
                    onAction: () =>
                        ref.read(analyticsRangeProvider.notifier).reset(),
                  ),
                ],
              ),
            );
          }

          final data = AnalyticsCalculator.compute(scoped, range: range);
          final categories = categoriesAsync.value ?? [];
          final budgets = budgetsAsync.value ?? [];
          final budgetSummary = SummaryCalculator.budgetForMonth(
            transactions,
            budgets,
            DateTime(now.year, now.month),
          );
          String categoryName(String id) {
            return categories.firstWhere(
              (c) => c.id == id,
              orElse: () => categories.isEmpty
                  ? CategoryEntity(id: id, name: id, icon: 'category')
                  : categories.first,
            ).name;
          }

          final currencySymbol = ref.watch(currencySymbolProvider).value ?? '\$';
          final currencyFormat = moneyFormat(currencySymbol);
          final budgetColor = Theme.of(context).colorScheme.primary;
          final totalBudget = budgetSummary.totalBudget;
          final hasBudget = totalBudget > 0;

          final items = itemsAsync.value ?? const <TransactionItemEntity>[];
          final topItems = ItemAnalyticsCalculator.topItemsByCategory(scoped, items);
          final categoryTrends = range == null
              ? const <CategoryTrend>[]
              : ItemAnalyticsCalculator.categoryTrendForRange(transactions, range);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(transactionsProvider);
              ref.invalidate(categoriesProvider);
            },
            child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              const _AnalyticsRangeChips(),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text('Spending vs Budget', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(
                        _rangeLabel(range),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 220,
                        child: LineChart(
                          LineChartData(
                            minY: 0,
                            gridData: const FlGridData(show: true, drawVerticalLine: false),
                            titlesData: FlTitlesData(
                              leftTitles: const AxisTitles(),
                              topTitles: const AxisTitles(),
                              rightTitles: const AxisTitles(),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 28,
                                  getTitlesWidget: (value, meta) {
                                    if (value.toInt() < 0 || value.toInt() >= data.trends.length) {
                                      return const SizedBox.shrink();
                                    }
                                    final month = data.trends[value.toInt()].month;
                                    return Text(
                                      DateFormat.MMM().format(month),
                                      style: const TextStyle(fontSize: 10),
                                    );
                                  },
                                ),
                              ),
                            ),
                            lineTouchData: LineTouchData(
                              enabled: true,
                              touchTooltipData: LineTouchTooltipData(
                                getTooltipItems: (touchedSpots) {
                                  final items = <LineTooltipItem>[];
                                  if (touchedSpots.isEmpty) {
                                    return items;
                                  }
                                  final x = touchedSpots.first.x.toInt();
                                  if (x < 0 || x >= data.trends.length) {
                                    return items;
                                  }
                                  items.add(
                                    LineTooltipItem(
                                      DateFormat.yMMMd().format(data.trends[x].month),
                                      const TextStyle(
                                        color: Colors.black87,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  );
                                  items.add(
                                    LineTooltipItem(
                                      '\nExpense: ${currencyFormat.format(data.trends[x].expense)}',
                                      const TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  );
                                  if (hasBudget) {
                                    items.add(
                                      LineTooltipItem(
                                        '\nBudget: ${currencyFormat.format(totalBudget)}',
                                        TextStyle(
                                          color: budgetColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    );
                                  }
                                  return items;
                                },
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: [
                                  for (var i = 0; i < data.trends.length; i++)
                                    FlSpot(i.toDouble(), data.trends[i].expense),
                                ],
                                color: Colors.red,
                                barWidth: 3,
                                isCurved: true,
                                dotData: const FlDotData(show: true),
                              ),
                              if (hasBudget)
                                LineChartBarData(
                                  spots: [
                                    for (var i = 0; i < data.trends.length; i++)
                                      FlSpot(i.toDouble(), totalBudget),
                                  ],
                                  color: budgetColor,
                                  barWidth: 3,
                                  dashArray: [8, 4],
                                  isCurved: false,
                                  dotData: const FlDotData(show: false),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Wrap(
                          spacing: 16,
                          children: [
                            const _LegendDot(color: Colors.red, label: 'Expense'),
                            if (hasBudget)
                              _LegendDot(
                                color: budgetColor,
                                label: 'Budget',
                                dashed: true,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Spending', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        currencyFormat.format(data.totalExpense),
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _BudgetVsSpentCard(
                summary: budgetSummary,
                categoryName: categoryName,
                currencyFormat: currencyFormat,
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Spending by Category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      if (data.categorySpending.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: Text('No expenses in the last 6 months')),
                        )
                      else ...[
                        _CategoryDonutChart(
                          spending: data.categorySpending,
                          categoryName: categoryName,
                          currencyFormat: currencyFormat,
                        ),
                        const SizedBox(height: 16),
                        _AnalyticsCategoryBars(
                          spending: data.categorySpending,
                          categoryName: categoryName,
                          currencyFormat: currencyFormat,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _TopItemsCard(
                topItems: topItems,
                categoryName: categoryName,
                currencyFormat: currencyFormat,
              ),
              const SizedBox(height: 16),
              if (range != null)
                _CategoryTrendCard(
                  trends: categoryTrends,
                  categoryName: categoryName,
                  currencyFormat: currencyFormat,
                  range: range,
                ),
            ],
          ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _AnalyticsRangeChips extends ConsumerWidget {
  const _AnalyticsRangeChips();

  static const _presets = [
    AnalyticsRangePreset.allTime,
    AnalyticsRangePreset.last30Days,
    AnalyticsRangePreset.last90Days,
    AnalyticsRangePreset.last6Months,
    AnalyticsRangePreset.thisYear,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(analyticsRangeProvider);
    final now = DateTime.now();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final preset in _presets)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(
                  selection.preset == preset
                      ? selection.label(now)
                      : _shortLabel(preset),
                ),
                selected: selection.preset == preset,
                onSelected: (_) =>
                    ref.read(analyticsRangeProvider.notifier).selectPreset(preset),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                selection.preset == AnalyticsRangePreset.custom
                    ? selection.label(now)
                    : 'Custom',
              ),
              selected: selection.preset == AnalyticsRangePreset.custom,
              onSelected: (_) => _pickCustomRange(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  static String _shortLabel(AnalyticsRangePreset preset) {
    switch (preset) {
      case AnalyticsRangePreset.allTime:
        return 'All time';
      case AnalyticsRangePreset.last30Days:
        return '30d';
      case AnalyticsRangePreset.last90Days:
        return '90d';
      case AnalyticsRangePreset.last6Months:
        return '6mo';
      case AnalyticsRangePreset.thisYear:
        return 'This year';
      case AnalyticsRangePreset.custom:
        return 'Custom';
    }
  }

  Future<void> _pickCustomRange(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final current = ref.read(analyticsRangeProvider);
    final initial = current.customRange ??
        DateTimeRange(start: DateTime(now.year, now.month - 1), end: now);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: initial,
    );
    if (picked != null) {
      ref.read(analyticsRangeProvider.notifier).selectCustom(picked);
    }
  }
}

String _rangeLabel(DateTimeRange? range) {
  if (range == null) {
    return 'All time';
  }
  final fmt = DateFormat.yMMMd();
  return '${fmt.format(range.start)} – ${fmt.format(range.end)}';
}

class _TopItemsCard extends StatelessWidget {
  final Map<String, List<CategoryItemStat>> topItems;
  final String Function(String) categoryName;
  final NumberFormat currencyFormat;

  const _TopItemsCard({
    required this.topItems,
    required this.categoryName,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = topItems.entries.toList()
      ..sort((a, b) => b.value.first.total.compareTo(a.value.first.total));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Items by Category',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (sorted.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No item data yet',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ),
              )
            else
              for (var i = 0; i < sorted.length; i++) ...[
                if (i > 0) const Divider(),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  title: Text(
                    categoryName(sorted[i].key),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Top ${sorted[i].value.length} items',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  children: [
                    for (var j = 0; j < sorted[i].value.length; j++)
                      _TopItemRow(
                        rank: j + 1,
                        stat: sorted[i].value[j],
                        currencyFormat: currencyFormat,
                      ),
                  ],
                ),
              ],
            if (sorted.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => context.push('/item_prices'),
                    icon: const Icon(Icons.history, size: 18),
                    label: const Text('View price history'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TopItemRow extends StatelessWidget {
  final int rank;
  final CategoryItemStat stat;
  final NumberFormat currencyFormat;

  const _TopItemRow({
    required this.rank,
    required this.stat,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              stat.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'x${stat.purchaseCount}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 88,
            child: Text(
              currencyFormat.format(stat.total),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTrendCard extends StatelessWidget {
  final List<CategoryTrend> trends;
  final String Function(String) categoryName;
  final NumberFormat currencyFormat;
  final DateTimeRange range;

  const _CategoryTrendCard({
    required this.trends,
    required this.categoryName,
    required this.currencyFormat,
    required this.range,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Category Trend',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              '${DateFormat.yMMM().format(range.start)} vs ${DateFormat.yMMM().format(range.end)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            if (trends.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No spending in the selected period',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ),
              )
            else
              for (var i = 0; i < trends.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _CategoryTrendRow(
                  trend: trends[i],
                  color: _AnalyticsCategoryBars._palette[i % _AnalyticsCategoryBars._palette.length],
                  categoryName: categoryName,
                  currencyFormat: currencyFormat,
                ),
              ],
          ],
        ),
      ),
    );
  }
}

class _CategoryTrendRow extends StatelessWidget {
  final CategoryTrend trend;
  final Color color;
  final String Function(String) categoryName;
  final NumberFormat currencyFormat;

  const _CategoryTrendRow({
    required this.trend,
    required this.color,
    required this.categoryName,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context) {
    final isUp = trend.delta > 0;
    final deltaColor = isUp ? Colors.red.shade700 : Colors.green.shade700;
    final String deltaLabel;
    if (trend.isNew) {
      deltaLabel = 'New';
    } else {
      final pct = trend.percentChange ?? 0;
      deltaLabel = '${isUp ? '↑' : '↓'} ${(pct.abs() * 100).toStringAsFixed(0)}%';
    }

    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            categoryName(trend.categoryId),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${currencyFormat.format(trend.previous)} → ${currencyFormat.format(trend.current)}',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 52,
          child: Text(
            deltaLabel,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: deltaColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _BudgetVsSpentCard extends StatelessWidget {
  final BudgetSummary summary;
  final String Function(String) categoryName;
  final NumberFormat currencyFormat;

  const _BudgetVsSpentCard({
    required this.summary,
    required this.categoryName,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context) {
    if (summary.totalBudget <= 0) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Budget vs Spent',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Set monthly budgets in Settings > Budgets',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final budgetedCategories = summary.categoryBudget.keys.toList()
      ..sort(
        (a, b) =>
            (summary.categorySpent[b] ?? 0).compareTo(summary.categorySpent[a] ?? 0),
      );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Budget vs Spent',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            const Text(
              'This month',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < budgetedCategories.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _BudgetVsRow(
                label: categoryName(budgetedCategories[i]),
                spent: summary.categorySpent[budgetedCategories[i]] ?? 0,
                budget: summary.categoryBudget[budgetedCategories[i]]!,
                currencyFormat: currencyFormat,
              ),
            ],
            const SizedBox(height: 12),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text(
                    '${currencyFormat.format(summary.totalSpent)} of ${currencyFormat.format(summary.totalBudget)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    summary.remaining >= 0
                        ? '${currencyFormat.format(summary.remaining)} left'
                        : '${currencyFormat.format(-summary.remaining)} over',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: summary.remaining >= 0
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetVsRow extends StatelessWidget {
  final String label;
  final double spent;
  final double budget;
  final NumberFormat currencyFormat;

  const _BudgetVsRow({
    required this.label,
    required this.spent,
    required this.budget,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context) {
    final over = spent > budget;
    final ratio = budget > 0 ? spent / budget : 0.0;
    final color = over ? Colors.red.shade400 : Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${currencyFormat.format(spent)} / ${currencyFormat.format(budget)}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        if (over) ...[
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Over by ${currencyFormat.format(spent - budget)}',
              style: const TextStyle(fontSize: 11, color: Colors.red),
            ),
          ),
        ],
      ],
    );
  }
}

class _CategoryDonutChart extends StatefulWidget {
  final Map<String, double> spending;
  final String Function(String) categoryName;
  final NumberFormat currencyFormat;

  const _CategoryDonutChart({
    required this.spending,
    required this.categoryName,
    required this.currencyFormat,
  });

  @override
  State<_CategoryDonutChart> createState() => _CategoryDonutChartState();
}

class _CategoryDonutChartState extends State<_CategoryDonutChart> {
  int? _activeIndex;

  @override
  Widget build(BuildContext context) {
    final sorted = widget.spending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = widget.spending.values.fold<double>(0, (a, b) => a + b);

    final active = _activeIndex != null && _activeIndex! < sorted.length
        ? sorted[_activeIndex!]
        : null;
    final centerTitle = active == null
        ? 'Total'
        : widget.categoryName(active.key);
    final centerValue = active == null
        ? widget.currencyFormat.format(total)
        : widget.currencyFormat.format(active.value);

    return SizedBox(
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 50,
              sections: [
                for (var i = 0; i < sorted.length; i++)
                  PieChartSectionData(
                    value: sorted[i].value,
                    color: _AnalyticsCategoryBars._palette[i % _AnalyticsCategoryBars._palette.length],
                    radius: 72,
                    title: total > 0
                        ? '${((sorted[i].value / total) * 100).toStringAsFixed(0)}%'
                        : '0%',
                    titleStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
              ],
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, PieTouchResponse? response) {
                  if (!event.isInterestedForInteractions ||
                      response?.touchedSection == null) {
                    return;
                  }
                  setState(() {
                    _activeIndex = response!.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                centerTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 2),
              Text(
                centerValue,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnalyticsCategoryBars extends StatelessWidget {
  final Map<String, double> spending;
  final String Function(String) categoryName;
  final NumberFormat currencyFormat;

  const _AnalyticsCategoryBars({
    required this.spending,
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
    final total = spending.values.fold<double>(0, (a, b) => a + b);
    final sorted = spending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: [
        for (var i = 0; i < sorted.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _buildBar(
            label: categoryName(sorted[i].key),
            amount: sorted[i].value,
            total: total,
            color: _palette[i % _palette.length],
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

  Widget _buildBar({
    required String label,
    required double amount,
    required double total,
    required Color color,
  }) {
    final fraction = total > 0 ? amount / total : 0.0;
    final percent = (fraction * 100).toStringAsFixed(0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
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
                widthFactor: fraction.clamp(0.0, 1.0),
                child: Container(
                  height: 18,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: Text(
              currencyFormat.format(amount),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 36,
            child: Text(
              '$percent%',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final bool dashed;

  const _LegendDot({required this.color, required this.label, this.dashed = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dashed)
          SizedBox(
            width: 24,
            height: 4,
            child: CustomPaint(painter: _DashedSwatchPainter(color)),
          )
        else
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

class _DashedSwatchPainter extends CustomPainter {
  final Color color;

  const _DashedSwatchPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const dashWidth = 5.0;
    const dashGap = 3.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset(x + dashWidth, size.height / 2),
        paint,
      );
      x += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(_DashedSwatchPainter oldDelegate) => oldDelegate.color != color;
}
