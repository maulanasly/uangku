import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/receipt_parser.dart';
import '../../core/services/gemini_service.dart';
import '../../providers/database_provider.dart';
import '../../data/database/database.dart';
import '../../core/models/transaction_type.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  final ImagePicker _picker = ImagePicker();
  final GeminiService _geminiService = GeminiService();
  bool _isProcessing = false;

  Future<void> _processImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source, imageQuality: 80);
    if (image == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final bytes = await image.readAsBytes();
      final parsedData = await _geminiService.parseReceiptFromBytes(bytes, mimeType: image.mimeType ?? 'image/jpeg');

      if (mounted) {
        _showReviewDialog(parsedData);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showReviewDialog(ReceiptData data) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Review Transaction'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Merchant: ${data.merchant ?? "Not found"}'),
                Text('Amount: ${data.amount != null ? data.amount.toString() : "Not found"}'),
                Text('Date: ${data.date != null ? data.date.toString().split(" ")[0] : "Not found"}'),
                const SizedBox(height: 16),
                const Text('Does this look correct?'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final repo = ref.read(transactionRepositoryProvider);
                final transaction = TransactionsCompanion.insert(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  date: data.date ?? DateTime.now(),
                  amount: data.amount ?? 0.0,
                  category: 'cat_food', // Defaulting for now
                  merchant: data.merchant ?? 'Unknown',
                  note: 'Scanned from receipt (Gemini AI)',
                  type: TransactionType.expense,
                );
                repo.addTransaction(transaction);

                Navigator.pop(context);
                context.pop(); // Go back to dashboard
              },
              child: const Text('Save Transaction'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Receipt')),
      body: Center(
        child: _isProcessing
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Analyzing Receipt with Gemini AI...'),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Capture Image'),
                    onPressed: () => _processImage(ImageSource.camera),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Select from Gallery'),
                    onPressed: () => _processImage(ImageSource.gallery),
                  ),
                ],
              ),
      ),
    );
  }
}
