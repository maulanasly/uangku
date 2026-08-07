import 'ocr_native.dart' if (dart.library.js_interop) 'ocr_web.dart';

abstract class OcrService {
  Future<String> extractTextFromFile(String path);
}

OcrService get ocrService => createOcrService();
