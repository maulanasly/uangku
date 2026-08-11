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

    final prices = [for (final p in history.points) p.effectiveUnitPrice];
    final average = prices.fold<double>(0, (a, b) => a + b) / prices.length;
    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
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
                  height: 220,
                  child: LineChart(
                    _chartData(
                      history,
                      color: Theme.of(context).colorScheme.primary,
                      currencyFormat: currencyFormat,
                      average: average,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _ChartLegend(
                  dataColor: Theme.of(context).colorScheme.primary,
                  averageColor: Colors.grey,
                  latestColor: _latestColor,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      '${history.purchaseCount} purchase${history.purchaseCount == 1 ? '' : 's'}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const Spacer(),
                    Text(
                      'Avg ${currencyFormat.format(average)} · Min ${currencyFormat.format(minPrice)} · Max ${currencyFormat.format(maxPrice)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
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
                const Text(
                  'Purchase history',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

  static const _latestColor = Colors.orange;

  LineChartData _chartData(
    ItemPriceHistory history, {
    required Color color,
    required NumberFormat currencyFormat,
    required double average,
  }) {
    final firstDate = history.points.first.date;
    final latestPrice = history.points.last.effectiveUnitPrice;

    double xFor(PricePoint point) =>
        point.date.difference(firstDate).inMinutes / 60.0;

    final lastX = xFor(history.points.last);
    final spanX = lastX;
    final minX = spanX <= 0 ? -1.0 : -spanX * 0.05;
    final maxX = spanX <= 0 ? 1.0 : lastX + spanX * 0.05;

    final yValues = [
      for (final p in history.points) p.effectiveUnitPrice,
      average,
      latestPrice,
    ];
    final rawMinY = yValues.reduce((a, b) => a < b ? a : b);
    final rawMaxY = yValues.reduce((a, b) => a > b ? a : b);
    final yRange = rawMaxY - rawMinY;
    final minY = (rawMinY - yRange * 0.2).clamp(0.0, double.infinity);
    final maxY = rawMaxY + yRange * 0.2;

    PricePoint? nearestPoint(double x) {
      PricePoint? best;
      var bestDelta = double.infinity;
      for (final point in history.points) {
        final delta = (xFor(point) - x).abs();
        if (delta < bestDelta) {
          bestDelta = delta;
          best = point;
        }
      }
      return best;
    }

    return LineChartData(
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY == minY ? minY + 1 : maxY,
      gridData: const FlGridData(show: true, drawVerticalLine: false),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(),
        topTitles: const AxisTitles(),
        rightTitles: const AxisTitles(),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            interval: spanX <= 0 ? 0.5 : spanX / 5,
            getTitlesWidget: (value, meta) {
              if (value < minX || value > maxX) {
                return const SizedBox.shrink();
              }
              final date = firstDate.add(Duration(minutes: (value * 60).round()));
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  DateFormat.MMMd().format(date),
                  style: const TextStyle(fontSize: 10),
                ),
              );
            },
          ),
        ),
      ),
      lineTouchData: LineTouchData(
        enabled: true,
        touchSpotThreshold: maxX - minX,
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (touchedSpots) {
            final items = <LineTooltipItem>[];
            for (final spot in touchedSpots) {
              final point = nearestPoint(spot.x);
              if (point == null) {
                continue;
              }
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
            for (final point in history.points)
              FlSpot(xFor(point), point.effectiveUnitPrice),
          ],
          color: color,
          barWidth: 3,
          isCurved: true,
          dotData: const FlDotData(show: true),
        ),
        LineChartBarData(
          spots: [FlSpot(minX, average), FlSpot(maxX, average)],
          color: Colors.grey,
          barWidth: 1.5,
          dashArray: const [6, 4],
          isCurved: false,
          dotData: const FlDotData(show: false),
        ),
        LineChartBarData(
          spots: [FlSpot(minX, latestPrice), FlSpot(maxX, latestPrice)],
          color: _latestColor,
          barWidth: 1.5,
          dashArray: const [4, 4],
          isCurved: false,
          dotData: const FlDotData(show: false),
        ),
      ],
    );
  }
}

class _ChartLegend extends StatelessWidget {
  final Color dataColor;
  final Color averageColor;
  final Color latestColor;

  const _ChartLegend({
    required this.dataColor,
    required this.averageColor,
    required this.latestColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _LegendDot(color: dataColor, label: 'Price'),
        const SizedBox(width: 16),
        _LegendDash(color: averageColor, label: 'Average'),
        const SizedBox(width: 16),
        _LegendDash(color: latestColor, label: 'Latest'),
      ],
    );
  }
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
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _LegendDash extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDash({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 20,
          height: 4,
          child: CustomPaint(painter: _DashSwatchPainter(color)),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _DashSwatchPainter extends CustomPainter {
  final Color color;

  const _DashSwatchPainter(this.color);

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
  bool shouldRepaint(_DashSwatchPainter oldDelegate) => oldDelegate.color != color;
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