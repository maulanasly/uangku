import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/export_service.dart';
import '../../core/services/preferences_service.dart';
import '../../providers/transaction_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Analytics'),
            leading: const Icon(Icons.bar_chart),
            onTap: () => context.push('/analytics'),
          ),
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
        ],
      ),
    );
  }

  Future<void> _selectCurrency(BuildContext context, WidgetRef ref) async {
    final current = ref.read(currencySymbolProvider).valueOrNull ?? '\$';
    final selected = await showDialog<String>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Currency Symbol'),
          children: [
            for (final symbol in PreferencesService.supportedSymbols)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, symbol),
                child: Row(
                  children: [
                    Icon(
                      symbol == current
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                    ),
                    const SizedBox(width: 12),
                    Text(symbol),
                  ],
                ),
              ),
          ],
        );
      },
    );

    if (selected != null && selected != current) {
      await PreferencesService().setCurrencySymbol(selected);
      ref.invalidate(currencySymbolProvider);
    }
  }
}
