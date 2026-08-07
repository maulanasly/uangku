import 'dart:io';
import 'dart:typed_data';

import 'package:apple_vision_recognize_text/apple_vision_recognize_text.dart';
import 'package:flutter/painting.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'
    hide RecognizedText;

import 'ocr_service.dart';

class MlKitOcrService implements OcrService {
  @override
  Future<String> extractText(String path, Uint8List bytes) async {
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

class AppleVisionOcrService implements OcrService {
  final AppleVisionRecognizeTextController _controller =
      AppleVisionRecognizeTextController();

  @override
  Future<String> extractText(String path, Uint8List bytes) async {
    final uiImage = await decodeImageFromList(bytes);
    final imageSize = Size(uiImage.width.toDouble(), uiImage.height.toDouble());
    uiImage.dispose();

    final result = await _controller.processImage(
      RecognizeTextData(
        image: bytes,
        imageSize: imageSize,
        recognitionLevel: RecognitionLevel.accurate,
      ),
    );
    if (result == null) {
      throw Exception('Apple Vision returned no text');
    }
    return joinRecognizedLines(result);
  }
}

String joinRecognizedLines(List<RecognizedText> observations) {
  return observations
      .where((o) => o.listText.isNotEmpty)
      .map((o) => o.listText.first)
      .join('\n');
}

OcrService createOcrService() {
  if (Platform.isIOS || Platform.isMacOS) {
    return AppleVisionOcrService();
  }
  return MlKitOcrService();
}
