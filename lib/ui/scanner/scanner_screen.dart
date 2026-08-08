import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/services/gemini_service.dart';
import '../../core/services/ocr_cloud_service.dart';
import '../../core/services/ocr_service.dart';
import '../../core/services/preferences_service.dart';
import '../../core/utils/receipt_parser.dart';
import '../../core/utils/receipt_storage.dart';
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
  final OcrSpaceService _ocrSpaceService = OcrSpaceService();
  bool _isProcessing = false;

  Future<({String path, Uint8List bytes})> _prepareImage(XFile image) async {
    var bytes = await image.readAsBytes();

    // Convert HEIC to JPEG (most OCR backends don't support HEIC).
    final compressed = await FlutterImageCompress.compressWithList(
      bytes,
      quality: 80,
      format: CompressFormat.jpeg,
    );
    bytes = compressed ?? bytes;

    // Write JPEG bytes to a temp file so ML Kit can read from path.
    final tempDir = await getTemporaryDirectory();
    final tempFile = File(
      '${tempDir.path}/receipt_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await tempFile.writeAsBytes(bytes);

    return (path: tempFile.path, bytes: bytes);
  }

  Future<void> _processImage(ImageSource source) async {
    final XFile? image =
        await _picker.pickImage(source: source, imageQuality: 80);
    if (image == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final prepared = await _prepareImage(image);

      // Save a permanent copy of the receipt image.
      final imagePath = await saveReceiptImage(prepared.bytes);

      final parsed = await _parseImage(prepared.path, prepared.bytes);
      if (mounted) {
        await _showReviewDialog(parsed, imagePath: imagePath);
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

  Future<({ReceiptData data, String? cloudProvider})> _parseImage(
    String path,
    Uint8List bytes,
  ) async {
    final mode = await ref.read(ocrModeProvider.future);

    if (mode == 'gemini') {
      final data = await _geminiService.parseReceiptFromBytes(
        bytes,
        mimeType: 'image/jpeg',
      );
      return (data: data, cloudProvider: 'gemini');
    }
    if (mode == 'ocrspace') {
      final data = await _ocrSpaceService.parseReceiptFromBytes(
        bytes,
        mimeType: 'image/jpeg',
      );
      return (data: data, cloudProvider: 'ocrspace');
    }

    // Auto mode: try local OCR first, fallback to OCR.space.
    try {
      final text = await ocrService.extractText(path, bytes);
      return (data: ReceiptParser.parseLines(text.split('\n')), cloudProvider: null);
    } catch (_) {
      final data = await _ocrSpaceService.parseReceiptFromBytes(
        bytes,
        mimeType: 'image/jpeg',
      );
      return (data: data, cloudProvider: 'ocrspace');
    }
  }

  Future<void> _showReviewDialog(
    ({ReceiptData data, String? cloudProvider}) parsed, {
    String? imagePath,
  }) async {
    final draft = ReceiptDraft.fromReceiptData(parsed.data);
    if (imagePath != null) {
      final draftWithImage = draft.copyWith(receiptImagePath: imagePath);
      final result = await showReviewTransactionDialog(
        context,
        draft: draftWithImage,
        cloudProvider: parsed.cloudProvider,
      );
      if (result == null) return;
      final repo = ref.read(transactionRepositoryProvider);
      await repo.addTransactionWithItems(result.transaction, result.items);
    } else {
      final result = await showReviewTransactionDialog(
        context,
        draft: draft,
        cloudProvider: parsed.cloudProvider,
      );
      if (result == null) return;
      final repo = ref.read(transactionRepositoryProvider);
      await repo.addTransactionWithItems(result.transaction, result.items);
    }
    if (!mounted) return;
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
                            icon: Icon(Icons.auto_awesome),
                          ),
                          ButtonSegment(
                            value: 'ocrspace',
                            label: Text('Cloud'),
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Row(
                      children: [
                        Expanded(
                          child: Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => _processImage(ImageSource.camera),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: Column(
                                  children: [
                                    CircleAvatar(
                                      radius: 34,
                                      backgroundColor: Color(0xFF4F8CFF),
                                      child: Icon(
                                        Icons.camera_alt,
                                        size: 32,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text('Camera'),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => _processImage(ImageSource.gallery),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: Column(
                                  children: [
                                    CircleAvatar(
                                      radius: 34,
                                      backgroundColor: Color(0xFF38C6A0),
                                      child: Icon(
                                        Icons.photo_library,
                                        size: 32,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text('Gallery'),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
