import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/transaction_type.dart';
import '../../data/database/database.dart';
import '../../providers/transaction_provider.dart';
import 'receipt_draft.dart';

Future<TransactionsCompanion?> showReviewTransactionDialog(
  BuildContext context, {
  required ReceiptDraft draft,
  required bool usedLocalOcr,
}) {
  return showDialog<TransactionsCompanion>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _ReviewTransactionDialog(
      initialDraft: draft,
      usedLocalOcr: usedLocalOcr,
    ),
  );
}

class _ReviewTransactionDialog extends ConsumerStatefulWidget {
  final ReceiptDraft initialDraft;
  final bool usedLocalOcr;

  const _ReviewTransactionDialog({
    required this.initialDraft,
    required this.usedLocalOcr,
  });

  @override
  ConsumerState<_ReviewTransactionDialog> createState() => _ReviewTransactionDialogState();
}

class _ReviewTransactionDialogState extends ConsumerState<_ReviewTransactionDialog> {
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

  void _save() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final draft = _draft.copyWith(
      merchant: _merchantController.text.trim(),
      amountText: _amountController.text.trim(),
      note: _noteController.text.trim(),
    );
    Navigator.pop(context, draft.toCompanion());
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
                widget.usedLocalOcr ? 'Scanned on device (ML Kit)' : 'Scanned with Gemini AI',
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
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                    DropdownMenuItem<String>(value: cat.id, child: Text(cat.name)),
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
                  setState(() => _draft = _draft.copyWith(type: selection.first));
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
}
