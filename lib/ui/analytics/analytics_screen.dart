import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../core/ui/add_expense_sheet.dart';
import '../../core/ui/empty_state.dart';
import '../../core/utils/analytics_calculator.dart';
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

          final data = AnalyticsCalculator.compute(transactions);
          final categories = categoriesAsync.value ?? [];
          final budgets = budgetsAsync.value ?? [];
          final now = DateTime.now();
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

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(transactionsProvider);
              ref.invalidate(categoriesProvider);
            },
            child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text('Spending vs Budget', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
