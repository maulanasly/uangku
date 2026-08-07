import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'ocr_service.dart';

class MlKitOcrService implements OcrService {
  @override
  Future<String> extractTextFromFile(String path) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(path);
      final text = await recognizer.processImage(inputImage);
      return text.blocks.map((block) => block.text).join('\n');
    } finally {
      recognizer.close();
    }
  }
}

OcrService createOcrService() => MlKitOcrService();
