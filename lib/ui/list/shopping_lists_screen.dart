import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/money_format.dart';
import '../../data/database/database.dart';
import '../../providers/database_provider.dart';
import '../../providers/transaction_provider.dart';

class ShoppingListsScreen extends ConsumerStatefulWidget {
  const ShoppingListsScreen({super.key});

  @override
  ConsumerState<ShoppingListsScreen> createState() => _ShoppingListsScreenState();
}

class _ShoppingListsScreenState extends ConsumerState<ShoppingListsScreen> {
  Future<void> _createList() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const _NewListDialog(),
    );
    if (name == null || name.trim().isEmpty || !mounted) return;

    final id = const Uuid().v4();
    final repo = ref.read(transactionRepositoryProvider);
    await repo.addShoppingListWithItems(
      ShoppingListsCompanion.insert(
        id: id,
        name: name.trim(),
        date: DateTime.now(),
      ),
      [],
    );
    if (!mounted) return;
    context.push('/shopping_list/$id');
  }

  @override
  Widget build(BuildContext context) {
    final listsAsync = ref.watch(shoppingListsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Shopping Lists')),
      floatingActionButton: FloatingActionButton(
        onPressed: _createList,
        child: const Icon(Icons.add),
      ),
      body: listsAsync.when(
        data: (lists) => lists.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.checklist,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No shopping lists yet.\nCreate one to plan a trip.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                itemCount: lists.length,
                itemBuilder: (context, index) => _ListCard(list: lists[index]),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Failed to load lists')),
      ),
    );
  }
}

class _NewListDialog extends StatefulWidget {
  const _NewListDialog();

  @override
  State<_NewListDialog> createState() => _NewListDialogState();
}

class _NewListDialogState extends State<_NewListDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Shopping List'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'List name',
          hintText: 'e.g. Weekend groceries',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _ListCard extends ConsumerWidget {
  final ShoppingListEntity list;

  const _ListCard({required this.list});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(shoppingListItemsFamily(list.id));
    final items = itemsAsync.value ?? [];
    final checkedCount = items.where((i) => i.checked).length;
    final currencyFormat =
        moneyFormat(ref.watch(currencySymbolProvider).value ?? '\$');
    final estTotal = items.fold<double>(0, (s, i) => s + i.total);
    final completed = list.completed;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: completed
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Icon(
            completed ? Icons.check : Icons.checklist,
            color: completed
                ? Theme.of(context).colorScheme.onPrimary
                : null,
          ),
        ),
        title: Text(
          list.name,
          style: TextStyle(
            decoration: completed ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text(
          completed
              ? 'Completed · ${DateFormat.yMMMd().format(list.date)}'
              : '${DateFormat.yMMMd().format(list.date)}'
                  ' · $checkedCount/${items.length} checked'
                  ' · ${currencyFormat.format(estTotal)}',
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'delete') {
              ref
                  .read(transactionRepositoryProvider)
                  .deleteShoppingList(list.id);
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'delete',
              child: Text('Delete'),
            ),
          ],
        ),
        onTap: () => context.push('/shopping_list/${list.id}'),
      ),
    );
  }
}
