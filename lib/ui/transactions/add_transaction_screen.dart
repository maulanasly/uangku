import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/models/transaction_type.dart';
import '../../providers/database_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../data/database/database.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  final TransactionEntity? transaction;

  const AddTransactionScreen({super.key, this.transaction});

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _merchantController;
  late final TextEditingController _noteController;
  
  late TransactionType _selectedType;
  late DateTime _selectedDate;
  late String _selectedCategory;

  @override
  void initState() {
    super.initState();
    final t = widget.transaction;
    _amountController = TextEditingController(text: t?.amount.toString() ?? '');
    _merchantController = TextEditingController(text: t?.merchant ?? '');
    _noteController = TextEditingController(text: t?.note ?? '');
    _selectedType = t?.type ?? TransactionType.expense;
    _selectedDate = t?.date ?? DateTime.now();
    _selectedCategory = t?.category ?? 'cat_food';
  }

  @override
  void dispose() {
    _amountController.dispose();
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

  void _saveTransaction() {
    if (_formKey.currentState!.validate()) {
      final repo = ref.read(transactionRepositoryProvider);
      
      if (widget.transaction != null) {
        // Update existing
        final transaction = widget.transaction!.copyWith(
          date: _selectedDate,
          amount: double.parse(_amountController.text),
          category: _selectedCategory,
          merchant: _merchantController.text,
          note: _noteController.text,
          type: _selectedType,
        );
        repo.updateTransaction(transaction);
      } else {
        // Insert new
        final transaction = TransactionsCompanion.insert(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          date: _selectedDate,
          amount: double.parse(_amountController.text),
          category: _selectedCategory,
          merchant: _merchantController.text,
          note: _noteController.text,
          type: _selectedType,
        );
        repo.addTransaction(transaction);
      }
      
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
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
              // Type Selection
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
                selected: {_selectedType},
                onSelectionChanged: (Set<TransactionType> newSelection) {
                  setState(() {
                    _selectedType = newSelection.first;
                  });
                },
              ),
              const SizedBox(height: 24),

              // Amount
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an amount';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
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

              // Category
              DropdownButtonFormField<String>(
                initialValue: _selectedCategoryFor(categoriesAsync.valueOrNull),
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
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedCategory = newValue;
                    });
                  }
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

              // Note
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Note (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 32),

              // Save Button
              FilledButton(
                onPressed: _saveTransaction,
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
