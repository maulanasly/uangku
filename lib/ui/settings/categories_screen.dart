import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/transaction_provider.dart';
import '../../providers/database_provider.dart';
import '../../data/database/database.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategoryDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: categoriesAsync.when(
        data: (categories) {
          if (categories.isEmpty) {
            return const Center(child: Text('No categories yet'));
          }
          return ListView.builder(
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return ListTile(
                leading: CircleAvatar(child: Icon(_iconFor(category.icon))),
                title: Text(category.name),
                subtitle: Text(category.id),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteCategory(context, ref, category),
                ),
                onTap: () => _showCategoryDialog(context, ref, category),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }

  IconData _iconFor(String name) {
    for (final entry in _iconOptions) {
      if (entry.$1 == name) return entry.$2;
    }
    return Icons.category;
  }

  Future<void> _deleteCategory(
    BuildContext context,
    WidgetRef ref,
    CategoryEntity category,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Delete "${category.name}"? Transactions using it will also be deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final repo = ref.read(transactionRepositoryProvider);
    try {
      await repo.deleteCategory(category.id);
      ref.invalidate(categoriesProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot delete: category is in use')),
        );
      }
    }
  }

  Future<void> _showCategoryDialog(
    BuildContext context,
    WidgetRef ref, [
    CategoryEntity? category,
  ]) async {
    final nameController = TextEditingController(text: category?.name ?? '');
    var selectedIcon = category?.icon ?? _iconOptions.first.$1;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(category == null ? 'Add Category' : 'Edit Category'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Icon', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in _iconOptions)
                        ChoiceChip(
                          label: Icon(entry.$2, size: 20),
                          selected: selectedIcon == entry.$1,
                          onSelected: (_) {
                            setDialogState(() => selectedIcon = entry.$1);
                          },
                          showCheckmark: false,
                          selectedColor: Theme.of(context).colorScheme.primaryContainer,
                        ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    if (nameController.text.trim().isNotEmpty) {
                      Navigator.pop(context, true);
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true) {
      final repo = ref.read(transactionRepositoryProvider);
      final name = nameController.text.trim();
      final icon = selectedIcon;

      if (category == null) {
        await repo.addCategory(
          CategoriesCompanion.insert(
            id: 'cat_${DateTime.now().millisecondsSinceEpoch}',
            name: name,
            icon: icon,
          ),
        );
      } else {
        await repo.updateCategory(
          category.copyWith(name: name, icon: icon),
        );
      }
      ref.invalidate(categoriesProvider);
    }
  }
}
