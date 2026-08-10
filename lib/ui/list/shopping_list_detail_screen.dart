import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/models/transaction_type.dart';
import '../../core/services/receipt_ocr_service.dart';
import '../../core/utils/money_format.dart';
import '../../core/utils/ocr_image_prep.dart';
import '../../data/database/database.dart';
import '../../providers/database_provider.dart';
import '../../providers/transaction_provider.dart';
import '../scanner/receipt_draft.dart';
import '../scanner/review_transaction_dialog.dart';

class ShoppingListDetailScreen extends ConsumerStatefulWidget {
  final String listId;

  const ShoppingListDetailScreen({super.key, required this.listId});

  @override
  ConsumerState<ShoppingListDetailScreen> createState() =>
      _ShoppingListDetailScreenState();
}

class _ShoppingListDetailScreenState
    extends ConsumerState<ShoppingListDetailScreen> {
  final ImagePicker _picker = ImagePicker();
  final ReceiptOcrService _ocrService = ReceiptOcrService();
  bool _isScanning = false;

  Future<void> _pickScanSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) {
      await _scanList(source);
    }
  }

  Future<void> _scanList(ImageSource source) async {
    final XFile? image =
        await _picker.pickImage(source: source, imageQuality: 80);
    if (image == null) return;

    setState(() => _isScanning = true);
    try {
      final prepared = await prepareImageForOcr(image);
      final mode = await ref.read(ocrModeProvider.future);
      final parsed =
          await _ocrService.parseImage(prepared.path, prepared.bytes, mode: mode);
      if (!mounted) return;

      final repo = ref.read(transactionRepositoryProvider);
      final existing = await repo.watchShoppingListItems(widget.listId).first;
      final scanned = parsed.data.items;
      for (var i = 0; i < scanned.length; i++) {
        final item = scanned[i];
        await repo.addShoppingListItem(
          ShoppingListItemsCompanion.insert(
            id: const Uuid().v4(),
            listId: widget.listId,
            name: item.name,
            quantity: Value(item.quantity),
            unitPrice: Value(item.unitPrice),
            total: Value(item.total),
            position: Value(existing.length + i),
          ),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            scanned.isEmpty
                ? 'No items found in scan'
                : 'Added ${scanned.length} items from scan',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  Future<void> _addItem(List<ShoppingListItemEntity> items) async {
    final result = await showItemEditSheet(context);
    if (result == null || !mounted) return;
    final repo = ref.read(transactionRepositoryProvider);
    await repo.addShoppingListItem(
      ShoppingListItemsCompanion.insert(
        id: const Uuid().v4(),
        listId: widget.listId,
        name: result.name,
        quantity: Value(result.quantity),
        unitPrice: Value(result.unitPrice),
        total: Value(result.total),
        position: Value(items.length),
      ),
    );
  }

  Future<void> _editItem(ShoppingListItemEntity item) async {
    final result = await showItemEditSheet(
      context,
      initialName: item.name,
      initialQuantity: item.quantity,
      initialUnitPrice: item.unitPrice,
    );
    if (result == null || !mounted) return;
    final repo = ref.read(transactionRepositoryProvider);
    await repo.updateShoppingListItem(
      ShoppingListItemsCompanion(
        id: Value(item.id),
        name: Value(result.name),
        quantity: Value(result.quantity),
        unitPrice: Value(result.unitPrice),
        total: Value(result.total),
        checked: Value(item.checked),
      ),
    );
  }

  Future<void> _toggleChecked(ShoppingListItemEntity item, bool checked) async {
    final repo = ref.read(transactionRepositoryProvider);
    await repo.updateShoppingListItem(
      ShoppingListItemsCompanion(
        id: Value(item.id),
        name: Value(item.name),
        quantity: Value(item.quantity),
        unitPrice: Value(item.unitPrice),
        total: Value(item.total),
        checked: Value(checked),
      ),
    );
  }

  Future<void> _deleteItem(String id) async {
    final repo = ref.read(transactionRepositoryProvider);
    await repo.deleteShoppingListItems([id]);
  }

  Future<void> _createExpense(
    ShoppingListEntity list,
    List<ShoppingListItemEntity> checked,
  ) async {
    final drafts = [
      for (final c in checked)
        ReceiptItemDraft(
          id: const Uuid().v4(),
          name: c.name,
          quantity: c.quantity,
          unitPrice: c.unitPrice,
          total: c.total,
        ),
    ];
    final sum = drafts.fold<double>(0, (s, i) => s + i.total);
    final draft = ReceiptDraft(
      merchant: '',
      amountText: _formatAmount(sum),
      date: list.date,
      category: 'cat_food',
      type: TransactionType.expense,
      note: '',
      items: drafts,
    );

    final result = await showReviewTransactionDialog(context, draft: draft);
    if (result == null || !mounted) return;

    final repo = ref.read(transactionRepositoryProvider);
    await repo.addTransactionWithItems(result.transaction, result.items);
    await repo.deleteShoppingListItems([for (final c in checked) c.id]);

    final remaining = await repo.watchShoppingListItems(widget.listId).first;
    if (remaining.isEmpty && !list.completed) {
      await repo.updateShoppingList(list.copyWith(completed: true));
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense created')),
      );
    }
  }

  static String _formatAmount(double value) {
    return value == value.truncateToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final lists = ref.watch(shoppingListsProvider).value ?? [];
    ShoppingListEntity? list;
    for (final l in lists) {
      if (l.id == widget.listId) {
        list = l;
        break;
      }
    }
    final itemsAsync = ref.watch(shoppingListItemsFamily(widget.listId));
    final items = itemsAsync.value ?? [];
    final checked = items.where((i) => i.checked).toList();
    final currencySymbol = ref.watch(currencySymbolProvider).value ?? '\$';
    final currencyFormat = moneyFormat(currencySymbol);
    final checkedTotal = checked.fold<double>(0, (s, i) => s + i.total);
    final estTotal = items.fold<double>(0, (s, i) => s + i.total);

    if (list == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(list.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.document_scanner_outlined),
            tooltip: 'Scan list',
            onPressed: _isScanning ? null : _pickScanSource,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isScanning ? null : () => _addItem(items),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: checked.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  onPressed: () => _createExpense(list!, checked),
                  icon: const Icon(Icons.receipt_long),
                  label: Text(
                    'Create expense (${checked.length} · '
                    '${currencyFormat.format(checkedTotal)})',
                  ),
                ),
              ),
            )
          : null,
      body: _isScanning
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${checked.length} of ${items.length} checked',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Est. total: ${currencyFormat.format(estTotal)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      if (checked.isNotEmpty)
                        TextButton.icon(
                          onPressed: () => _createExpense(list!, checked),
                          icon: const Icon(Icons.receipt_long, size: 18),
                          label: const Text('Create expense'),
                        ),
                    ],
                  ),
                ),
                if (items.isEmpty)
                  Expanded(
                    child: Center(
                      child: Text(
                        'No items yet.\nAdd items manually or scan a list.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return _ListItemCard(
                          item: item,
                          currencyFormat: currencyFormat,
                          onTap: () => _editItem(item),
                          onToggle: (v) => _toggleChecked(item, v),
                          onDelete: () => _deleteItem(item.id),
                        );
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}

typedef ItemEditResult = ({
  String name,
  double quantity,
  double? unitPrice,
  double total,
});

Future<ItemEditResult?> showItemEditSheet(
  BuildContext context, {
  String initialName = '',
  double initialQuantity = 1,
  double? initialUnitPrice,
}) {
  return showModalBottomSheet<ItemEditResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _ItemEditSheet(
      initialName: initialName,
      initialQuantity: initialQuantity,
      initialUnitPrice: initialUnitPrice,
    ),
  );
}

class _ItemEditSheet extends ConsumerStatefulWidget {
  final String initialName;
  final double initialQuantity;
  final double? initialUnitPrice;

  const _ItemEditSheet({
    required this.initialName,
    required this.initialQuantity,
    required this.initialUnitPrice,
  });

  @override
  ConsumerState<_ItemEditSheet> createState() => _ItemEditSheetState();
}

class _ItemEditSheetState extends ConsumerState<_ItemEditSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _qtyController;
  late final TextEditingController _unitPriceController;

  double get _quantity => double.tryParse(_qtyController.text) ?? 1;
  double? get _unitPrice => double.tryParse(_unitPriceController.text);
  double get _total {
    final unitPrice = _unitPrice;
    return unitPrice != null ? unitPrice * _quantity : 0;
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _qtyController = TextEditingController(text: _fmt(widget.initialQuantity));
    _unitPriceController =
        TextEditingController(text: _fmt(widget.initialUnitPrice));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _qtyController.dispose();
    _unitPriceController.dispose();
    super.dispose();
  }

  static String _fmt(double? value) {
    if (value == null) return '';
    return value == value.truncateToDouble()
        ? value.toStringAsFixed(0)
        : value.toString();
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item name is required')),
      );
      return;
    }
    Navigator.pop(
      context,
      (
        name: name,
        quantity: _quantity,
        unitPrice: _unitPrice,
        total: _total,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final currencySymbol =
        ref.watch(currencySymbolProvider).value ?? '\$';

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Item',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Item name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _qtyController,
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _unitPriceController,
                    decoration: InputDecoration(
                      labelText: 'Unit price',
                      prefixText: '$currencySymbol ',
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(_total == 0 ? '—' : _fmt(_total)),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _save,
              child: const Text('Save Item'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListItemCard extends StatelessWidget {
  final ShoppingListItemEntity item;
  final NumberFormat currencyFormat;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  const _ListItemCard({
    required this.item,
    required this.currencyFormat,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final lineTotal = item.quantity * (item.unitPrice ?? 0);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: item.checked
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
          child: Row(
            children: [
              Checkbox(
                value: item.checked,
                onChanged: (v) => onToggle(v ?? false),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: TextStyle(
                        fontSize: 15,
                        decoration: item.checked
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.unitPrice == null
                          ? 'Est: ${currencyFormat.format(item.total)}'
                          : '${_qty(item.quantity)} × '
                              '${currencyFormat.format(item.unitPrice!)}'
                              ' = ${currencyFormat.format(lineTotal)}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _qty(double value) {
    return value == value.truncateToDouble()
        ? value.toStringAsFixed(0)
        : value.toString();
  }
}

