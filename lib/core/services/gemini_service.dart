import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../utils/receipt_parser.dart';

class GeminiService {
  final GenerativeModel _model;

  GeminiService()
      : _model = GenerativeModel(
          model: 'gemini-1.5-flash',
          apiKey: dotenv.env['GEMINI_API_KEY'] ?? '',
        );

  Future<ReceiptData> parseReceiptFromImage(String imagePath) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY is missing from .env');
    }

    late DataPart imagePart;

    if (kIsWeb) {
      // In web, the imagePath might be a blob URI or we need to fetch bytes
      // But typically, image picker on web gives us an XFile where we can read bytes directly.
      // Wait, the caller is passing image.path, which on web is a blob URL.
      // Let's modify the signature to accept Uint8List so it works smoothly on both platforms.
      throw Exception('Use parseReceiptFromBytes for web support');
    } else {
      final bytes = await File(imagePath).readAsBytes();
      imagePart = DataPart('image/jpeg', bytes);
    }

    return _generateReceiptData(imagePart);
  }
  
  Future<ReceiptData> parseReceiptFromBytes(Uint8List bytes, {String mimeType = 'image/jpeg'}) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY is missing from .env');
    }

    final imagePart = DataPart(mimeType, bytes);
    return _generateReceiptData(imagePart);
  }

  Future<ReceiptData> _generateReceiptData(DataPart imagePart) async {
    final prompt = TextPart(
        '''
Analyze this receipt image and extract the following information.
Return the result strictly as a valid JSON object without any markdown wrapping or extra text.

Fields to extract:
- merchant: (string) The name of the store or merchant.
- amount: (double) The total amount of the transaction.
- date: (string) The date in YYYY-MM-DD format.

Example JSON output:
{
  "merchant": "Target",
  "amount": 25.50,
  "date": "2023-10-25"
}
''');

    final response = await _model.generateContent([
      Content.multi([prompt, imagePart]),
    ]);

    final text = response.text;
    if (text == null || text.isEmpty) {
      throw Exception('Gemini returned an empty response');
    }

    return ReceiptParser.parseGeminiJson(text);
  }
}
