import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/gemini_service.dart';
import '../../core/services/ocr_service.dart';
import '../../core/services/preferences_service.dart';
import '../../core/utils/receipt_parser.dart';
import '../../providers/database_provider.dart';
import '../../providers/transaction_provider.dart';
import 'receipt_draft.dart';
import 'review_transaction_dialog.dart';

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
      final parsed = await _parseImage(image);
      if (mounted) {
        await _showReviewDialog(parsed);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<({ReceiptData data, bool usedLocalOcr})> _parseImage(XFile image) async {
    final bytes = await image.readAsBytes();
    final mode = await ref.read(ocrModeProvider.future);

    // Gemini mode: skip local OCR entirely.
    if (mode == 'gemini') {
      final data = await _geminiService.parseReceiptFromBytes(
        bytes,
        mimeType: image.mimeType ?? 'image/jpeg',
      );
      return (data: data, usedLocalOcr: false);
    }

    // Auto mode: try local OCR first, fallback to Gemini.
    try {
      final text = await ocrService.extractText(image.path, bytes);
      return (data: ReceiptParser.parseLines(text.split('\n')), usedLocalOcr: true);
    } catch (_) {
      final data = await _geminiService.parseReceiptFromBytes(
        bytes,
        mimeType: image.mimeType ?? 'image/jpeg',
      );
      return (data: data, usedLocalOcr: false);
    }
  }

  Future<void> _showReviewDialog(
    ({ReceiptData data, bool usedLocalOcr}) parsed,
  ) async {
    final result = await showReviewTransactionDialog(
      context,
      draft: ReceiptDraft.fromReceiptData(parsed.data),
      usedLocalOcr: parsed.usedLocalOcr,
    );

    if (result == null) {
      return;
    }

    final repo = ref.read(transactionRepositoryProvider);
    await repo.addTransactionWithItems(result.transaction, result.items);
    if (!mounted) {
      return;
    }
    context.pop();
  }

  Future<void> _toggleMode(String mode) async {
    await PreferencesService().setOcrMode(mode);
    ref.invalidate(ocrModeProvider);
  }

  @override
  Widget build(BuildContext context) {
    final modeAsync = ref.watch(ocrModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Scan Receipt')),
      body: Center(
        child: _isProcessing
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Analyzing Receipt...'),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: modeAsync.when(
                      data: (mode) => SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'auto',
                            label: Text('Auto'),
                            icon: Icon(Icons.phone_android),
                          ),
                          ButtonSegment(
                            value: 'gemini',
                            label: Text('Gemini'),
                            icon: Icon(Icons.cloud),
                          ),
                        ],
                        selected: {mode},
                        onSelectionChanged: (selection) =>
                            _toggleMode(selection.first),
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ),
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
