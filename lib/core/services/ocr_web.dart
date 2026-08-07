import 'ocr_service.dart';

class WebUnsupportedOcrService implements OcrService {
  @override
  Future<String> extractTextFromFile(String path) {
    throw UnsupportedError(
      'On-device OCR is not available on web. Use GeminiService instead.',
    );
  }
}

OcrService createOcrService() => WebUnsupportedOcrService();
