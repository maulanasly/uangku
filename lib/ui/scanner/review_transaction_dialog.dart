import 'dart:io';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/models/transaction_type.dart';
import '../../data/database/database.dart';
import '../../providers/transaction_provider.dart';
import 'receipt_draft.dart';

Future<({TransactionsCompanion transaction, List<TransactionItemsCompanion> items})?>
    showReviewTransactionDialog(
  BuildContext context, {
  required ReceiptDraft draft,
  String? cloudProvider,
}) {
  return showModalBottomSheet<
      ({TransactionsCompanion transaction, List<TransactionItemsCompanion> items})>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _ReviewTransactionBottomSheet(
      initialDraft: draft,
      cloudProvider: cloudProvider,
    ),
  );
}

class _ReviewTransactionBottomSheet extends ConsumerStatefulWidget {
  final ReceiptDraft initialDraft;
  final String? cloudProvider;

  const _ReviewTransactionBottomSheet({
    required this.initialDraft,
    this.cloudProvider,
  });

  @override
  ConsumerState<_ReviewTransactionBottomSheet> createState() =>
      _ReviewTransactionBottomSheetState();
}

class _ReviewTransactionBottomSheetState
    extends ConsumerState<_ReviewTransactionBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _merchantController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late ReceiptDraft _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialDraft;
    _merchantController = TextEditingController(text: _draft.merchant);
    _amountController = TextEditingController(text: _draft.amountText);
    _noteController = TextEditingController(text: _draft.note);
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String _ocrLabel() {
    switch (widget.cloudProvider) {
      case 'gemini':
        return 'Scanned with Gemini AI';
      case 'ocrspace':
        return 'Scanned with OCR.space';
      default:
        return 'Scanned on device';
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _draft.date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() => _draft = _draft.copyWith(date: picked));
    }
  }

  void _sumItemsToAmount() {
    final sum = _draft.items.fold<double>(0, (s, i) => s + i.total);
    _amountController.text = sum == sum.truncateToDouble()
        ? sum.toStringAsFixed(0)
        : sum.toStringAsFixed(2);
  }

  void _addItem() {
    setState(() {
      _draft = _draft.copyWith(
        items: [
          ..._draft.items,
          ReceiptItemDraft(id: const Uuid().v4(), name: '', total: 0),
        ],
      );
    });
  }

  void _removeItem(int index) {
    setState(() {
      final updated = [..._draft.items];
      updated.removeAt(index);
      _draft = _draft.copyWith(items: updated);
    });
  }

  void _updateItem(int index, ReceiptItemDraft updated) {
    setState(() {
      final items = [..._draft.items];
      items[index] = updated;
      _draft = _draft.copyWith(items: items);
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final transaction = _draft.copyWith(
      merchant: _merchantController.text.trim(),
      amountText: _amountController.text.trim(),
      note: _noteController.text.trim(),
    );
    final companion = transaction.toCompanion();
    final txId = companion.id.value;
    final itemCompanions = transaction.items
        .where((i) => i.name.isNotEmpty && i.total > 0)
        .toList()
        .asMap()
        .entries
        .map((e) => e.value.toCompanion(txId).copyWith(position: Value(e.key)))
        .toList();
    Navigator.pop(
      context,
      (transaction: companion, items: itemCompanions),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Column(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Receipt image thumbnail
              if (_draft.receiptImagePath != null)
                SizedBox(
                  width: double.infinity,
                  height: 120,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(_draft.receiptImagePath!),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              // Scrollable form content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Review Transaction',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _ocrLabel(),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _merchantController,
                          decoration: const InputDecoration(
                            labelText: 'Merchant',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a merchant';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _amountController,
                          decoration: InputDecoration(
                            labelText: 'Amount',
                            prefixText: '\$ ',
                            border: const OutlineInputBorder(),
                            suffixIcon: _draft.items.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.functions),
                                    tooltip: 'Sum item totals',
                                    onPressed: _sumItemsToAmount,
                                  )
                                : null,
                          ),
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter an amount';
                            }
                            if (double.tryParse(value.trim()) == null) {
                              return 'Please enter a valid number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Text('Items',
                                style: Theme.of(context).textTheme.titleSmall),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: _addItem,
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add'),
                            ),
                          ],
                        ),
                        ..._buildItemEditors(),
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: _selectDate,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Date',
                              border: OutlineInputBorder(),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(DateFormat.yMMMd().format(_draft.date)),
                                const Icon(Icons.calendar_today),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _draft.category,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            for (final cat in categoriesAsync.valueOrNull ?? [])
                              DropdownMenuItem<String>(
                                value: cat.id,
                                child: Text(cat.name),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(
                                  () => _draft = _draft.copyWith(category: value));
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        SegmentedButton<TransactionType>(
                          segments: const [
                            ButtonSegment(
                              value: TransactionType.expense,
                              label: Text('Expense'),
                              icon: Icon(Icons.arrow_downward),
                            ),
                            ButtonSegment(
                              value: TransactionType.income,
                              label: Text('Income'),
                              icon: Icon(Icons.arrow_upward),
                            ),
                          ],
                          selected: {_draft.type},
                          onSelectionChanged: (selection) {
                            setState(
                                () => _draft = _draft.copyWith(type: selection.first));
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _noteController,
                          decoration: const InputDecoration(
                            labelText: 'Note (Optional)',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Bottom action bar
              Container(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: _save,
                          child: const Text('Save Transaction'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildItemEditors() {
    if (_draft.items.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'No items added yet.',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        ),
      ];
    }
    return List.generate(_draft.items.length, (i) {
      final item = _draft.items[i];
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                key: Key(item.id),
                initialValue: item.name,
                decoration: const InputDecoration(
                  hintText: 'Item name',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
                onChanged: (v) => _updateItem(
                  i,
                  ReceiptItemDraft(id: item.id, name: v, total: item.total),
                ),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 56,
              child: TextFormField(
                key: Key('${item.id}_qty'),
                initialValue: item.quantity == item.quantity.truncateToDouble()
                    ? item.quantity.toStringAsFixed(0)
                    : item.quantity.toString(),
                decoration: const InputDecoration(
                  hintText: 'Qty',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) {
                  final qty = double.tryParse(v) ?? 1;
                  final unitPrice = item.unitPrice ?? (item.quantity > 0 ? item.total / item.quantity : item.total);
                  _updateItem(
                    i,
                    ReceiptItemDraft(
                      id: item.id,
                      name: item.name,
                      quantity: qty,
                      total: unitPrice * qty,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 80,
              child: TextFormField(
                key: Key('${item.id}_total'),
                initialValue: item.total == item.total.truncateToDouble()
                    ? item.total.toStringAsFixed(0)
                    : item.total.toStringAsFixed(2),
                decoration: const InputDecoration(
                  hintText: 'Total',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) {
                  final total = double.tryParse(v) ?? 0;
                  _updateItem(
                    i,
                    ReceiptItemDraft(
                      id: item.id,
                      name: item.name,
                      quantity: item.quantity,
                      total: total,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              onPressed: () => _removeItem(i),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      );
    });
  }
}
