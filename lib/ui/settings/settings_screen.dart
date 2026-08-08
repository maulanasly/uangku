import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/export_service.dart';
import '../../core/services/preferences_service.dart';
import '../../providers/database_provider.dart';
import '../../providers/transaction_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _currencyOptions = [
    ('\$', 'Dollar'),
    ('Rp', 'Rupiah'),
    ('€', 'Euro'),
    ('£', 'Pound'),
    ('¥', 'Yen'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Categories'),
            leading: const Icon(Icons.category),
            onTap: () => context.push('/categories'),
          ),
          ListTile(
            title: const Text('Export Data'),
            leading: const Icon(Icons.file_download),
            onTap: () async {
              try {
                final exportService = ref.read(exportServiceProvider);
                await exportService.exportTransactionsToCsv();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error exporting data: $e')),
                  );
                }
              }
            },
          ),
          ListTile(
            title: const Text('Import Data'),
            leading: const Icon(Icons.file_upload),
            onTap: () async {
              try {
                final exportService = ref.read(exportServiceProvider);
                await exportService.importTransactionsFromCsv();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Transactions imported')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error importing data: $e')),
                  );
                }
              }
            },
          ),
          ListTile(
            title: const Text('Currency'),
            leading: const Icon(Icons.currency_exchange),
            onTap: () => _selectCurrency(context, ref),
          ),
          ListTile(
            title: const Text('Theme'),
            leading: const Icon(Icons.palette),
            onTap: () {},
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ref.watch(themeModeProvider).when(
              data: (mode) => SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode)),
                  ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto)),
                  ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode)),
                ],
                selected: {mode},
                onSelectionChanged: (selection) async {
                  final selected = selection.first;
                  final label = switch (selected) {
                    ThemeMode.dark => 'dark',
                    ThemeMode.light => 'light',
                    _ => 'system',
                  };
                  await PreferencesService().setThemeModePref(label);
                  ref.invalidate(themeModeProvider);
                },
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('Reset Data'),
            subtitle: const Text('Delete all transactions and items'),
            leading: const Icon(Icons.delete_sweep, color: Colors.red),
            onTap: () => _resetData(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _selectCurrency(BuildContext context, WidgetRef ref) async {
    final current = ref.read(currencySymbolProvider).valueOrNull ?? '\$';

    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Currency Symbol',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              for (final entry in _currencyOptions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: entry.$1 == current
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.pop(context, entry.$1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: entry.$1 == current
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                entry.$1,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: entry.$1 == current
                                      ? Colors.white
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              entry.$2,
                              style: const TextStyle(fontSize: 16),
                            ),
                            const Spacer(),
                            if (entry.$1 == current)
                              Icon(
                                Icons.check_circle,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );

    if (selected != null && selected != current) {
      await PreferencesService().setCurrencySymbol(selected);
      ref.invalidate(currencySymbolProvider);
    }
  }

  Future<void> _resetData(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Data'),
        content: const Text(
          'Delete all transactions and items? Categories and preferences will be kept. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final repo = ref.read(transactionRepositoryProvider);
      await repo.resetData();
      ref.invalidate(transactionsProvider);
      ref.invalidate(filteredTransactionsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data has been reset')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error resetting data: $e')),
        );
      }
    }
  }
}
