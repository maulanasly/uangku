import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';

import '../../providers/transaction_provider.dart';
import '../../providers/database_provider.dart';
import '../../data/database/database.dart';
import '../models/transaction_type.dart';

final exportServiceProvider = Provider((ref) {
  return ExportService(ref);
});

class ExportService {
  final Ref _ref;

  ExportService(this._ref);

  Future<void> exportTransactionsToCsv() async {
    // 1. Fetch transactions directly (not using stream for a one-off export)
    // Actually, our repository only exposes a stream for all transactions.
    // Let's just watch the stream and take the first emission, or we can use the provider.
    
    // We'll use the async value from the transactionsProvider
    final asyncTransactions = _ref.read(transactionsProvider);
    
    // We must ensure the data is loaded. If we are triggering this from UI, 
    // it's likely already loaded.
    final transactions = asyncTransactions.valueOrNull;
    if (transactions == null || transactions.isEmpty) {
      throw Exception('No transactions to export');
    }

    // 2. Map to 2D Array
    List<List<dynamic>> rows = [];
    
    // Add Header
    rows.add([
      'Date',
      'Merchant',
      'Category',
      'Type',
      'Amount',
      'Note',
    ]);

    // Add Data
    for (final t in transactions) {
      rows.add([
        t.date.toIso8601String(),
        t.merchant,
        t.category,
        t.type.name,
        t.amount,
        t.note,
      ]);
    }

    // 3. Convert to CSV string
    String csvData = Csv().encode(rows);

    // 4. Share / Export
    final filename = 'uangku_transactions_${DateTime.now().millisecondsSinceEpoch}.csv';

    if (kIsWeb) {
      // On the web, we can just share the string as a file using share_plus
      final bytes = utf8.encode(csvData);
      final file = XFile.fromData(
        Uint8List.fromList(bytes),
        mimeType: 'text/csv',
        name: filename,
      );
      // ignore: deprecated_member_use
      await Share.shareXFiles([file], text: 'My Uangku Transactions');
    } else {
      // On mobile, we write to a temporary file first
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/$filename';
      final file = File(path);
      await file.writeAsString(csvData);

      final xFile = XFile(path);
      // ignore: deprecated_member_use
      await Share.shareXFiles([xFile], text: 'My Uangku Transactions');
    }
  }

  Future<void> importTransactionsFromCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.single;
    final Uint8List bytes;
    if (file.bytes != null) {
      bytes = file.bytes!;
    } else {
      bytes = await File(file.path!).readAsBytes();
    }

    final content = utf8.decode(bytes);
    final rows = Csv().decode(content);
    if (rows.length <= 1) {
      throw Exception('CSV has no data rows');
    }

    final categories = await _ref.read(transactionRepositoryProvider).getCategories();
    final byId = {for (final c in categories) c.id: c};
    final byName = {for (final c in categories) c.name: c};
    final fallback = categories.isNotEmpty ? categories.first.id : null;

    String? resolveCategory(String value) {
      final v = value.trim();
      if (byId.containsKey(v)) {
        return v;
      }
      if (byName.containsKey(v)) {
        return byName[v]!.id;
      }
      return fallback;
    }

    final repo = _ref.read(transactionRepositoryProvider);
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < 6) {
        continue;
      }
      final date = DateTime.tryParse(row[0].toString());
      final amount = double.tryParse(row[4].toString());
      if (date == null || amount == null) {
        continue;
      }
      // Income is no longer supported; all imported rows become expenses.
      const type = TransactionType.expense;
      final category = resolveCategory(row[2].toString());
      if (category == null) {
        continue;
      }
      await repo.addTransaction(
        TransactionsCompanion.insert(
          id: 'import_${DateTime.now().microsecondsSinceEpoch}_$i',
          date: date,
          amount: amount,
          category: category,
          merchant: row[1].toString(),
          note: row[5].toString(),
          type: type,
        ),
      );
    }
  }
}
