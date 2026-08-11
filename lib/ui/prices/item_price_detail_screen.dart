import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/utils/money_format.dart';
import '../../core/utils/price_history_calculator.dart';
import '../../providers/transaction_provider.dart';

class ItemPriceDetailScreen extends ConsumerWidget {
  final String itemName;

  const ItemPriceDetailScreen({super.key, required this.itemName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final itemsAsync = ref.watch(allTransactionItemsProvider);
    final currencySymbol = ref.watch(currencySymbolProvider).value ?? '\$';
    final currencyFormat = moneyFormat(currencySymbol);

    return Scaffold(
      appBar: AppBar(title: Text(itemName)),
      body: transactionsAsync.when(
        data: (transactions) {
          return itemsAsync.when(
            data: (items) {
              final histories = PriceHistoryCalculator.buildPriceHistory(
                transactions,
                items,
              );
              final history = histories.firstWhere(
                (h) => h.name == itemName,
                orElse: () => ItemPriceHistory(name: itemName, points: const []),
              );
              return _buildBody(history, currencyFormat, context);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildBody(
    ItemPriceHistory history,
    NumberFormat currencyFormat,
    BuildContext context,
  ) {
    final dateFormat = DateFormat.yMMMd();

    if (history.points.isEmpty) {
      return const Center(
        child: Text('No purchase history for this item', style: TextStyle(color: Colors.grey)),
      );
    }

    final chartHeight = history.points.length > 1 ? 220.0 : 0.0;

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        if (chartHeight > 0) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Price over time',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: chartHeight,
                    child: LineChart(
                      _chartData(
                        history,
                        color: Theme.of(context).colorScheme.primary,
                        currencyFormat: currencyFormat,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${history.purchaseCount} purchase${history.purchaseCount == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < history.points.length; i++) ...[
                  if (i > 0) const Divider(),
                  _PurchaseRow(
                    point: history.points[i],
                    dateFormat: dateFormat,
                    currencyFormat: currencyFormat,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  LineChartData _chartData(
  ItemPriceHistory history, {
  required Color color,
  required NumberFormat currencyFormat,
}) {
    final minY = history.points.map((p) => p.effectiveUnitPrice).reduce((a, b) => a < b ? a : b);
    final maxY = history.points.map((p) => p.effectiveUnitPrice).reduce((a, b) => a > b ? a : b);
    final range = maxY - minY;
    final lower = (minY - range * 0.2).clamp(0.0, double.infinity);
    final upper = maxY + range * 0.2;

    return LineChartData(
      minY: lower,
      maxY: upper == lower ? lower + 1 : upper,
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
              final index = value.toInt();
              if (index < 0 || index >= history.points.length) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  DateFormat.MMMd().format(history.points[index].date),
                  style: const TextStyle(fontSize: 10),
                ),
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
            for (final spot in touchedSpots) {
              final index = spot.x.toInt();
              if (index < 0 || index >= history.points.length) {
                continue;
              }
              final point = history.points[index];
              items.add(
                LineTooltipItem(
                  '${DateFormat.yMMMd().format(point.date)}\n${point.merchant}',
                  const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              );
              items.add(
                LineTooltipItem(
                  '\n${currencyFormat.format(point.effectiveUnitPrice)}',
                  const TextStyle(
                    color: Colors.blueGrey,
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
            for (var i = 0; i < history.points.length; i++)
              FlSpot(
                i.toDouble(),
                history.points[i].effectiveUnitPrice,
              ),
          ],
          color: color,
          barWidth: 3,
          isCurved: true,
          dotData: const FlDotData(show: true),
        ),
      ],
    );
  }
}

class _PurchaseRow extends StatelessWidget {
  final PricePoint point;
  final DateFormat dateFormat;
  final NumberFormat currencyFormat;

  const _PurchaseRow({
    required this.point,
    required this.dateFormat,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context) {
    final weight = point.weight;
    final qtyLabel = point.quantity == point.quantity.truncateToDouble()
        ? '${point.quantity.toInt()}x'
        : '${point.quantity}x';
    final weightLabel = weight == null
        ? null
        : (weight == weight.truncateToDouble()
            ? '${weight.toInt()}kg'
            : '${weight}kg');

    final quantitySuffix = [
      qtyLabel,
      if (weightLabel != null) weightLabel,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateFormat.format(point.date),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      point.merchant,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                quantitySuffix,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 96,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      currencyFormat.format(point.effectiveUnitPrice),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'total ${currencyFormat.format(point.total)}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}