import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/models/transaction_type.dart';
import '../../core/ui/receipt_image_dialog.dart';
import '../../core/utils/money_format.dart';
import '../../providers/database_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../data/database/database.dart';
import '../scanner/receipt_draft.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  final TransactionEntity? transaction;

  const AddTransactionScreen({super.key, this.transaction});

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _merchantController;
  late final TextEditingController _noteController;

  late DateTime _selectedDate;
  late String _selectedCategory;
  late List<ReceiptItemDraft> _items;
  bool _itemsLoaded = true;

  double get _total {
    return _items.fold<double>(0, (s, i) => s + i.total);
  }

  @override
  void initState() {
    super.initState();
    final t = widget.transaction;
    _merchantController = TextEditingController(text: t?.merchant ?? '');
    _noteController = TextEditingController(text: t?.note ?? '');
    _selectedDate = t?.date ?? DateTime.now();
    _selectedCategory = t?.category ?? 'cat_food';

    if (t != null) {
      _itemsLoaded = false;
      final id = t.id;
      ref.read(transactionRepositoryProvider).watchItemsFor(id).first.then((entities) {
        if (!mounted) return;
        setState(() {
          _items = entities.isEmpty
              ? [ReceiptItemDraft(id: const Uuid().v4(), name: '', total: 0)]
              : [
                  for (final e in entities)
                    ReceiptItemDraft(
                      id: e.id,
                      name: e.name,
                      quantity: e.quantity,
                      unitPrice: e.unitPrice,
                      weight: e.weight,
                      total: e.total,
                    ),
                ];
          _itemsLoaded = true;
        });
      });
    } else {
      _items = [ReceiptItemDraft(id: const Uuid().v4(), name: '', total: 0)];
    }
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  String _selectedCategoryFor(List<CategoryEntity>? categories) {
    if (categories == null || categories.isEmpty) {
      return _selectedCategory;
    }
    if (categories.any((c) => c.id == _selectedCategory)) {
      return _selectedCategory;
    }
    return categories.first.id;
  }

  void _addItem() {
    setState(() {
      _items = [..._items, ReceiptItemDraft(id: const Uuid().v4(), name: '', total: 0)];
    });
  }

  void _removeItem(int index) {
    setState(() {
      final updated = [..._items];
      updated.removeAt(index);
      _items = updated;
    });
  }

  void _updateItem(int index, ReceiptItemDraft updated) {
    setState(() {
      final items = [..._items];
      items[index] = updated;
      _items = items;
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final validItems = _items
        .where((i) => i.name.trim().isNotEmpty && i.total > 0)
        .toList();
    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one item with a name and amount')),
      );
      return;
    }

    final repo = ref.read(transactionRepositoryProvider);
    final amount = validItems.fold<double>(0, (s, i) => s + i.total);

    if (widget.transaction != null) {
      final t = widget.transaction!;
      final transaction = t.copyWith(
        date: _selectedDate,
        amount: amount,
        category: _selectedCategory,
        merchant: _merchantController.text.trim(),
        note: _noteController.text.trim(),
        type: TransactionType.expense,
      );
      final items = validItems
          .asMap()
          .entries
          .map(
            (e) => e.value.toCompanion(t.id).copyWith(position: Value(e.key)),
          )
          .toList();
      repo.updateTransactionWithItems(transaction, items);
    } else {
      final txId = const Uuid().v4();
      final transaction = TransactionsCompanion.insert(
        id: txId,
        date: _selectedDate,
        amount: amount,
        category: _selectedCategory,
        merchant: _merchantController.text.trim(),
        note: _noteController.text.trim(),
        type: TransactionType.expense,
      );
      final items = validItems
          .asMap()
          .entries
          .map(
            (e) => e.value.toCompanion(txId).copyWith(position: Value(e.key)),
          )
          .toList();
      repo.addTransactionWithItems(transaction, items);
    }

    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final currencySymbol = ref.watch(currencySymbolProvider).value ?? '\$';
    final currencyFormat = moneyFormat(currencySymbol);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.transaction != null ? 'Edit Transaction' : 'Add Transaction'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Category
              DropdownButtonFormField<String>(
                initialValue: _selectedCategoryFor(categoriesAsync.value),
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final cat in categoriesAsync.value ?? [])
                    DropdownMenuItem<String>(
                      value: cat.id,
                      child: Text(cat.name),
                    ),
                ],
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedCategory = newValue;
                    });
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a category';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Merchant/Title
              TextFormField(
                controller: _merchantController,
                decoration: const InputDecoration(
                  labelText: 'Merchant / Title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title or merchant';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Date Picker
              InkWell(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat.yMMMd().format(_selectedDate)),
                      const Icon(Icons.calendar_today),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Items
              Row(
                children: [
                  Text('Items', style: Theme.of(context).textTheme.titleSmall),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Item'),
                  ),
                ],
              ),
              if (!_itemsLoaded)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else if (_items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No items added yet.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                )
              else
                for (final entry in _items.asMap().entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ItemInputCard(
                      key: ValueKey(entry.value.id),
                      item: entry.value,
                      currencySymbol: currencySymbol,
                      onChanged: (updated) => _updateItem(entry.key, updated),
                      onRemove: () => _removeItem(entry.key),
                    ),
                  ),

              // Total (auto-summed)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    currencyFormat.format(_total),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Note
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Note (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // View Receipt
              if (widget.transaction?.receiptImagePath != null) ...[
                OutlinedButton.icon(
                  onPressed: () => showReceiptImageDialog(context, widget.transaction!),
                  icon: const Icon(Icons.photo),
                  label: const Text('View Receipt'),
                ),
                const SizedBox(height: 16),
              ],

              // Save Button
              FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Save Transaction', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemInputCard extends StatefulWidget {
  final ReceiptItemDraft item;
  final String currencySymbol;
  final ValueChanged<ReceiptItemDraft> onChanged;
  final VoidCallback onRemove;

  const _ItemInputCard({
    super.key,
    required this.item,
    required this.currencySymbol,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_ItemInputCard> createState() => _ItemInputCardState();
}

class _ItemInputCardState extends State<_ItemInputCard> {
  late final TextEditingController _nameController;
  late final TextEditingController _weightController;
  late final TextEditingController _qtyController;
  late final TextEditingController _unitPriceController;
  late final TextEditingController _totalController;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameController = TextEditingController(text: item.name);
    _weightController = TextEditingController(text: _fmt(item.weight));
    _qtyController = TextEditingController(text: _fmt(item.quantity));
    _unitPriceController = TextEditingController(text: _fmt(item.unitPrice));
    _totalController = TextEditingController(text: _fmt(item.total));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    _qtyController.dispose();
    _unitPriceController.dispose();
    _totalController.dispose();
    super.dispose();
  }

  static String _fmt(double? value) {
    if (value == null) return '';
    return value == value.truncateToDouble()
        ? value.toStringAsFixed(0)
        : value.toString();
  }

  ReceiptItemDraft _currentDraft() {
    return ReceiptItemDraft(
      id: widget.item.id,
      name: _nameController.text,
      quantity: double.tryParse(_qtyController.text) ?? 1,
      unitPrice: double.tryParse(_unitPriceController.text),
      weight: double.tryParse(_weightController.text),
      total: double.tryParse(_totalController.text) ?? 0,
    );
  }

  void _commit() {
    widget.onChanged(_currentDraft());
  }

  void _onQtyChanged(String _) {
    final qty = double.tryParse(_qtyController.text) ?? 1;
    final unitPrice = double.tryParse(_unitPriceController.text) ??
        widget.item.unitPrice ??
        (widget.item.quantity > 0 ? widget.item.total / widget.item.quantity : null);
    if (unitPrice != null) {
      _totalController.text = _fmt(qty * unitPrice);
    }
    _commit();
  }

  void _onUnitPriceChanged(String _) {
    final qty = double.tryParse(_qtyController.text) ?? 1;
    final unitPrice = double.tryParse(_unitPriceController.text);
    if (unitPrice != null) {
      _totalController.text = _fmt(qty * unitPrice);
    }
    _commit();
  }

  void _onNameChanged(String _) => _commit();
  void _onWeightChanged(String _) => _commit();
  void _onTotalChanged(String _) => _commit();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Item name',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    ),
                    onChanged: _onNameChanged,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: widget.onRemove,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _weightController,
                    decoration: const InputDecoration(
                      labelText: 'Weight (kg)',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: _onWeightChanged,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _qtyController,
                    decoration: const InputDecoration(
                      labelText: 'Qty',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: _onQtyChanged,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _unitPriceController,
                    decoration: InputDecoration(
                      labelText: 'Unit price',
                      prefixText: '${widget.currencySymbol} ',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: _onUnitPriceChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _totalController,
              decoration: InputDecoration(
                labelText: 'Total',
                prefixText: '${widget.currencySymbol} ',
                border: const OutlineInputBorder(),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: _onTotalChanged,
            ),
          ],
        ),
      ),
    );
  }
}
