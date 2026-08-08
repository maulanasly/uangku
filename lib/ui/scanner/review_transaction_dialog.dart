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
  return showDialog<
      ({TransactionsCompanion transaction, List<TransactionItemsCompanion> items})>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _ReviewTransactionDialog(
      initialDraft: draft,
      cloudProvider: cloudProvider,
    ),
  );
}

class _ReviewTransactionDialog extends ConsumerStatefulWidget {
  final ReceiptDraft initialDraft;
  final String? cloudProvider;

  const _ReviewTransactionDialog({
    required this.initialDraft,
    this.cloudProvider,
  });

  @override
  ConsumerState<_ReviewTransactionDialog> createState() =>
      _ReviewTransactionDialogState();
}

class _ReviewTransactionDialogState
    extends ConsumerState<_ReviewTransactionDialog> {
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
          ReceiptItemDraft(
            id: const Uuid().v4(),
            name: '',
            total: 0,
          ),
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

    return AlertDialog(
      title: const Text('Review Transaction'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _ocrLabel(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
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
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(),
                  suffixIcon: Tooltip(
                    message: 'Sum item totals',
                    child: Icon(Icons.functions),
                  ),
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
              if (_draft.items.isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Items',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: _sumItemsToAmount,
                          icon: const Icon(Icons.functions, size: 16),
                          label: const Text('Sum'),
                        ),
                        const SizedBox(width: 4),
                        TextButton.icon(
                          onPressed: _addItem,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._buildItemEditors(),
              ] else ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add),
                  label: const Text('Add item'),
                ),
              ],
              const SizedBox(height: 12),
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
                    setState(() => _draft = _draft.copyWith(category: value));
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
                    () => _draft = _draft.copyWith(type: selection.first),
                  );
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save Transaction'),
        ),
      ],
    );
  }

  List<Widget> _buildItemEditors() {
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
                initialValue: item.name,
                decoration: const InputDecoration(
                  hintText: 'Item name',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                ),
                onChanged: (v) =>
                    _updateItem(i, ReceiptItemDraft(id: item.id, name: v, total: item.total)),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 56,
              child: TextFormField(
                initialValue: item.quantity == item.quantity.truncateToDouble()
                    ? item.quantity.toStringAsFixed(0)
                    : item.quantity.toString(),
                decoration: const InputDecoration(
                  hintText: 'Qty',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) {
                  final qty = double.tryParse(v) ?? 1;
                  final unitPrice = item.unitPrice ?? item.total;
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
                initialValue: item.total == item.total.truncateToDouble()
                    ? item.total.toStringAsFixed(0)
                    : item.total.toStringAsFixed(2),
                decoration: const InputDecoration(
                  hintText: 'Total',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
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
