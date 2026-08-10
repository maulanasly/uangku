import 'dart:typed_data';

import '../utils/receipt_parser.dart';
import 'gemini_service.dart';
import 'ocr_cloud_service.dart';
import 'ocr_service.dart';

class ReceiptOcrService {
  final GeminiService _geminiService;
  final OcrSpaceService _ocrSpaceService;

  ReceiptOcrService({
    GeminiService? geminiService,
    OcrSpaceService? ocrSpaceService,
  })  : _geminiService = geminiService ?? GeminiService(),
        _ocrSpaceService = ocrSpaceService ?? OcrSpaceService();

  /// Parses an image using the configured mode ('auto' | 'gemini' | 'ocrspace').
  Future<({ReceiptData data, String? cloudProvider})> parseImage(
    String path,
    Uint8List bytes, {
    required String mode,
  }) async {
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
      return (
        data:
            ReceiptParser.parseLines(text.split('\n')).copyWith(rawText: text),
        cloudProvider: null,
      );
    } catch (_) {
      final data = await _ocrSpaceService.parseReceiptFromBytes(
        bytes,
        mimeType: 'image/jpeg',
      );
      return (data: data, cloudProvider: 'ocrspace');
    }
  }
}
