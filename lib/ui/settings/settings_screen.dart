import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/export_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Categories'),
            leading: const Icon(Icons.category),
            onTap: () {},
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
        ],
      ),
    );
  }
}
