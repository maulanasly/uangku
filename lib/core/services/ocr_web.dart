import 'dart:typed_data';

import 'ocr_service.dart';

class WebUnsupportedOcrService implements OcrService {
  @override
  Future<String> extractText(String path, Uint8List bytes) {
    throw UnsupportedError(
      'On-device OCR is not available on web. Use GeminiService instead.',
    );
  }
}

OcrService createOcrService() => WebUnsupportedOcrService();
