import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/database/database.dart';

/// Shows a full-screen dialog with the receipt image and transaction details.
void showReceiptImageDialog(BuildContext context, TransactionEntity t) {
  final file = t.receiptImagePath != null ? File(t.receiptImagePath!) : null;

  showDialog(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (file != null && file.existsSync())
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: Image.file(file, fit: BoxFit.contain),
            )
          else
            const Padding(
              padding: EdgeInsets.all(48),
              child: Icon(Icons.broken_image, size: 64, color: Colors.grey),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.merchant,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      DateFormat.yMMMd().format(t.date),
                      style: const TextStyle(color: Colors.grey),
                    ),
                    if (t.receiptImagePath != null) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.check_circle, size: 14, color: Colors.green),
                      const SizedBox(width: 4),
                      const Text(
                        'Receipt saved',
                        style: TextStyle(fontSize: 12, color: Colors.green),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
