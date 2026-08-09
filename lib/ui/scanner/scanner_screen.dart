import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/receipt_ocr_service.dart';
import '../../core/services/preferences_service.dart';
import '../../core/utils/ocr_image_prep.dart';
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
  final ReceiptOcrService _ocrService = ReceiptOcrService();
  bool _isProcessing = false;
  Uint8List? _processingImageBytes;

  Future<void> _processImage(ImageSource source) async {
    final XFile? image =
        await _picker.pickImage(source: source, imageQuality: 80);
    if (image == null) return;

    setState(() {
      _isProcessing = true;
      _processingImageBytes = null;
    });

    try {
      final prepared = await prepareImageForOcr(image);

      // Show captured image behind the processing state.
      if (mounted) {
        setState(() => _processingImageBytes = prepared.bytes);
      }

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
    return _ocrService.parseImage(path, bytes, mode: mode);
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

    return PopScope(
      canPop: !_isProcessing,
      child: Scaffold(
        appBar: AppBar(title: const Text('Scan Receipt')),
        body: Center(
          child: _isProcessing
              ? _ScannerLoadingOverlay(imageBytes: _processingImageBytes)
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
      ),
    );
  }
}

/// Full-screen overlay shown while the receipt is being processed. Stages
/// advance on a fixed timeline (no real progress callbacks available), with a
/// scan line sweeping across the captured image.
class _ScannerLoadingOverlay extends StatefulWidget {
  const _ScannerLoadingOverlay({required this.imageBytes});

  final Uint8List? imageBytes;

  @override
  State<_ScannerLoadingOverlay> createState() => _ScannerLoadingOverlayState();
}

class _ScannerLoadingOverlayState extends State<_ScannerLoadingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _stageDuration = Duration(milliseconds: 900);

  static const List<({String label, IconData icon})> _stages = [
    (label: 'Preparing image…', icon: Icons.image_outlined),
    (label: 'Reading text…', icon: Icons.text_snippet_outlined),
    (label: 'Detecting items…', icon: Icons.receipt_long_outlined),
    (label: 'Reconciling totals…', icon: Icons.fact_check_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _stageDuration * _stages.length,
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _stageIndex =>
      (_controller.value * _stages.length).floor().clamp(0, _stages.length - 1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.imageBytes != null)
          Image.memory(
            widget.imageBytes!,
            fit: BoxFit.cover,
            color: Colors.black.withValues(alpha: 0.6),
            colorBlendMode: BlendMode.darken,
          )
        else
          const ColoredBox(color: Color(0xFF1A1C20)),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final y = -0.9 + 1.8 * _controller.value;
            return Align(
              alignment: Alignment(0, y),
              child: FractionallySizedBox(
                heightFactor: 0.002,
                widthFactor: 1,
                child: Container(
                  color: theme.colorScheme.primary.withValues(alpha: 0.55),
                ),
              ),
            );
          },
        ),
        Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final stage = _stages[_stageIndex];
              return Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Row(
                          key: ValueKey(stage.label),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(stage.icon, color: theme.colorScheme.primary),
                            const SizedBox(width: 12),
                            Text(
                              stage.label,
                              style: theme.textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: 240,
                        child: LinearProgressIndicator(
                          value: _controller.value,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
