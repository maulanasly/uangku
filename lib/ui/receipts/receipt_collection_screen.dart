import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/transaction_type.dart';
import '../../core/utils/money_format.dart';
import '../../data/database/database.dart';
import '../../providers/transaction_provider.dart';

class ReceiptCollectionScreen extends ConsumerStatefulWidget {
  const ReceiptCollectionScreen({super.key});

  @override
  ConsumerState<ReceiptCollectionScreen> createState() =>
      _ReceiptCollectionScreenState();
}

class _ReceiptCollectionScreenState
    extends ConsumerState<ReceiptCollectionScreen> {
  final PageController _pageController = PageController();
  var _showGrid = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final receiptsAsync = ref.watch(receiptTransactionsProvider);
    final currencySymbol =
        ref.watch(currencySymbolProvider).valueOrNull ?? '\$';
    final currencyFormat = moneyFormat(currencySymbol);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipts'),
        actions: [
          receiptsAsync.when(
            data: (receipts) => receipts.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: Icon(
                        _showGrid ? Icons.view_carousel : Icons.grid_view),
                    tooltip: _showGrid ? 'Stack view' : 'Grid view',
                    onPressed: () =>
                        setState(() => _showGrid = !_showGrid),
                  ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: receiptsAsync.when(
        data: (receipts) {
          if (receipts.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.collections_bookmark,
                        size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No receipt images yet.\nScan a receipt to start your collection.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 15),
                    ),
                  ],
                ),
              ),
            );
          }
          if (_showGrid) {
            return GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
              itemCount: receipts.length,
              itemBuilder: (context, index) =>
                  _buildGridCard(receipts[index], currencyFormat),
            );
          }
          return Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: receipts.length,
                  itemBuilder: (context, index) {
                    final remaining = receipts.length - index - 1;
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        for (int i = 1;
                            i <= remaining.clamp(0, 3);
                            i++)
                          Positioned(
                            top: 8.0 * i,
                            child: Transform.rotate(
                              angle: (i % 2 == 0 ? 1 : -1) * 0.02,
                              child: Container(
                                width:
                                    MediaQuery.of(context).size.width - 80,
                                height: 160,
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outline,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        _buildCardStackCard(
                            receipts[index], currencyFormat),
                      ],
                    );
                  },
                ),
              ),
              if (receipts.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int i = 0; i < receipts.length; i++)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i ==
                                  (_pageController.hasClients
                                      ? _pageController.page?.round() ?? 0
                                      : 0)
                              ? 10
                              : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i ==
                                    (_pageController.hasClients
                                        ? _pageController.page?.round() ?? 0
                                        : 0)
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outline,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildCardStackCard(TransactionEntity t, NumberFormat format) {
    final isExpense = t.type == TransactionType.expense;
    final file = t.receiptImagePath != null ? File(t.receiptImagePath!) : null;

    return GestureDetector(
      onTap: () => _showFullReceipt(context, t, format),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (file != null && file.existsSync())
              SizedBox(
                width: double.infinity,
                height: 280,
                child: Image.file(file, fit: BoxFit.cover),
              )
            else
              Container(
                width: double.infinity,
                height: 280,
                color:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.broken_image,
                    size: 48, color: Colors.grey),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.merchant,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat.yMMMd().format(t.date),
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${isExpense ? "-" : "+"}${format.format(t.amount)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isExpense ? Colors.red : Colors.green,
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

  Widget _buildGridCard(TransactionEntity t, NumberFormat format) {
    final isExpense = t.type == TransactionType.expense;
    final file = t.receiptImagePath != null ? File(t.receiptImagePath!) : null;

    return GestureDetector(
      onTap: () => _showFullReceipt(context, t, format),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (file != null && file.existsSync())
              SizedBox(
                width: double.infinity,
                height: 128,
                child: Image.file(file, fit: BoxFit.cover),
              )
            else
              Container(
                width: double.infinity,
                height: 128,
                color:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.broken_image,
                    size: 32, color: Colors.grey),
              ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.merchant,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(
                    '${isExpense ? "-" : "+"}${format.format(t.amount)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isExpense ? Colors.red : Colors.green,
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

  void _showFullReceipt(
      BuildContext context, TransactionEntity t, NumberFormat format) {
    final isExpense = t.type == TransactionType.expense;
    final file = t.receiptImagePath != null ? File(t.receiptImagePath!) : null;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (file != null && file.existsSync())
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                child: Image.file(file, fit: BoxFit.contain),
              )
            else
              const Padding(
                padding: EdgeInsets.all(48),
                child:
                    Icon(Icons.broken_image, size: 64, color: Colors.grey),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.merchant,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 4),
                  Text(DateFormat.yMMMd().format(t.date),
                      style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text(
                    '${isExpense ? "-" : "+"}${format.format(t.amount)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isExpense ? Colors.red : Colors.green,
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
