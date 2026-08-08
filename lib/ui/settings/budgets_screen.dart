import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/database_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../data/database/database.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  static const _iconOptions = [
    ('restaurant', Icons.restaurant),
    ('payments', Icons.payments),
    ('shopping_cart', Icons.shopping_cart),
    ('directions_car', Icons.directions_car),
    ('home', Icons.home),
    ('movie', Icons.movie),
    ('fitness_center', Icons.fitness_center),
    ('flight', Icons.flight),
    ('school', Icons.school),
    ('medical_services', Icons.medical_services),
    ('pets', Icons.pets),
    ('shopping_bag', Icons.shopping_bag),
  ];

  IconData _iconFor(String name) {
    for (final entry in _iconOptions) {
      if (entry.$1 == name) return entry.$2;
    }
    return Icons.category;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final budgetsAsync = ref.watch(budgetsProvider);
    final currencySymbol = ref.watch(currencySymbolProvider).valueOrNull ?? '\$';

    return Scaffold(
      appBar: AppBar(title: const Text('Monthly Budgets')),
      body: categoriesAsync.when(
        data: (categories) {
          if (categories.isEmpty) {
            return const Center(child: Text('No categories yet'));
          }
          final budgets = budgetsAsync.valueOrNull ?? [];
          final budgetByCategory = {
            for (final b in budgets) b.categoryId: b.monthlyLimit,
          };
          final currencyFormat =
              NumberFormat.currency(symbol: currencySymbol, decimalDigits: 0);

          return ListView.builder(
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final limit = budgetByCategory[category.id];
              return ListTile(
                leading: CircleAvatar(child: Icon(_iconFor(category.icon))),
                title: Text(category.name),
                subtitle: Text(
                  limit == null
                      ? 'No budget set'
                      : '${currencyFormat.format(limit)} / month',
                  style: TextStyle(
                    color: limit == null
                        ? Theme.of(context).colorScheme.outline
                        : null,
                  ),
                ),
                trailing: limit == null
                    ? const Icon(Icons.chevron_right)
                    : IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Clear budget',
                        onPressed: () => _clearBudget(ref, category.id),
                      ),
                onTap: () => _editBudget(context, ref, category, limit),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _editBudget(
    BuildContext context,
    WidgetRef ref,
    CategoryEntity category,
    double? current,
  ) async {
    final controller = TextEditingController(
      text: current != null && current == current.truncateToDouble()
          ? current.toInt().toString()
          : current?.toString() ?? '',
    );
    final currencySymbol = ref.read(currencySymbolProvider).valueOrNull ?? '\$';

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Budget for ${category.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Monthly limit ($currencySymbol)',
            hintText: 'e.g. 1000',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              if (value != null && value > 0) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved == true) {
      final value = double.parse(controller.text);
      final repo = ref.read(transactionRepositoryProvider);
      await repo.setBudget(category.id, value);
      ref.invalidate(budgetsProvider);
    }
  }

  Future<void> _clearBudget(WidgetRef ref, String categoryId) async {
    final repo = ref.read(transactionRepositoryProvider);
    await repo.deleteBudget(categoryId);
    ref.invalidate(budgetsProvider);
  }
}
