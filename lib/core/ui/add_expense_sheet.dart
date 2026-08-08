import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

void showAddExpenseSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    builder: (context) {
      return SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Add Manually'),
              onTap: () {
                Navigator.pop(context);
                context.push('/add_transaction');
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Scan Receipt'),
              onTap: () {
                Navigator.pop(context);
                context.push('/scanner');
              },
            ),
          ],
        ),
      );
    },
  );
}
