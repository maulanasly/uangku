import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../core/utils/analytics_calculator.dart';
import '../../providers/transaction_provider.dart';
import '../../data/database/database.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

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
                children: const [
                  SizedBox(height: 200),
                  Center(child: Text('No transactions yet')),
                ],
              ),
            );
          }

          final data = AnalyticsCalculator.compute(transactions);
          final categories = categoriesAsync.valueOrNull ?? [];
          String categoryName(String id) {
            return categories.firstWhere(
              (c) => c.id == id,
              orElse: () => categories.isEmpty
                  ? CategoryEntity(id: id, name: id, icon: 'category')
                  : categories.first,
            ).name;
          }

          final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

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
                      const Text('Last 6 Months', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: [
                                  for (var i = 0; i < data.trends.length; i++)
                                    FlSpot(i.toDouble(), data.trends[i].income),
                                ],
                                color: Colors.green,
                                barWidth: 3,
                                isCurved: true,
                                dotData: const FlDotData(show: true),
                              ),
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
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _LegendDot(color: Colors.green, label: 'Income'),
                          SizedBox(width: 16),
                          _LegendDot(color: Colors.red, label: 'Expense'),
                        ],
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
                      const Text('Income vs Expense', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        'Income: ${currencyFormat.format(data.totalIncome)}',
                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Expense: ${currencyFormat.format(data.totalExpense)}',
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
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
                      const Text('Spending by Category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      if (data.categorySpending.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: Text('No expenses in the last 6 months')),
                        )
                      else
                        SizedBox(
                          height: data.categorySpending.length * 44.0,
                          child: BarChart(
                            BarChartData(
                              gridData: const FlGridData(show: false),
                              borderData: FlBorderData(show: false),
                              barTouchData: BarTouchData(
                                touchTooltipData: BarTouchTooltipData(
                                  tooltipBgColor: Colors.black87,
                                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                    final value = rod.toY;
                                    return BarTooltipItem(
                                      currencyFormat.format(value),
                                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    );
                                  },
                                ),
                              ),
                              titlesData: const FlTitlesData(
                                leftTitles: AxisTitles(),
                                rightTitles: AxisTitles(),
                                topTitles: AxisTitles(),
                                bottomTitles: AxisTitles(),
                              ),
                              barGroups: [
                                for (var i = 0; i < data.categorySpending.length; i++)
                                  BarChartGroupData(
                                    x: i,
                                    barRods: [
                                      BarChartRodData(
                                        toY: data.categorySpending.values.elementAt(i),
                                        color: _categoryColor(i),
                                        width: 18,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (data.categorySpending.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < data.categorySpending.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: _categoryColor(i),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(categoryName(data.categorySpending.keys.elementAt(i))),
                            ],
                          ),
                        ),
                    ],
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

  static const _palette = [
    Colors.blue,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
    Colors.lime,
    Colors.brown,
  ];

  Color _categoryColor(int index) => _palette[index % _palette.length];
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
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
