import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/transaction_provider.dart';
import '../../providers/database_provider.dart';
import '../../data/database/database.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

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
    const icons = {
      'restaurant': Icons.restaurant,
      'directions_car': Icons.directions_car,
      'payments': Icons.payments,
      'shopping_cart': Icons.shopping_cart,
      'fitness_center': Icons.fitness_center,
      'movie': Icons.movie,
      'home': Icons.home,
    };
    return icons[name] ?? Icons.category;
  }

  Future<void> _deleteCategory(BuildContext context, WidgetRef ref, CategoryEntity category) async {
    final repo = ref.read(transactionRepositoryProvider);
    try {
      await repo.deleteCategory(category.id);
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
    final iconController = TextEditingController(text: category?.icon ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(category == null ? 'Add Category' : 'Edit Category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: iconController,
                decoration: const InputDecoration(
                  labelText: 'Icon',
                  hintText: 'e.g. restaurant',
                  border: OutlineInputBorder(),
                ),
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

    if (saved == true) {
      final repo = ref.read(transactionRepositoryProvider);
      final name = nameController.text.trim();
      final icon = iconController.text.trim().isEmpty ? 'category' : iconController.text.trim();

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
    }
  }
}
