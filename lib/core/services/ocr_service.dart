import 'dart:typed_data';

import 'ocr_native.dart' if (dart.library.js_interop) 'ocr_web.dart';

abstract class OcrService {
  Future<String> extractText(String path, Uint8List bytes);
}

OcrService get ocrService => createOcrService();
