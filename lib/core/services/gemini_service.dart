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
- amount: (double) The final total amount of the transaction (after tax and discounts).
- date: (string) The date in YYYY-MM-DD format.
- items: (array) Every purchased line item on the receipt. Skip subtotal, tax, discount, total, cash, change, and other summary rows.

Each item is an object with:
- name: (string) Item description as printed.
- quantity: (double) Number of units purchased. Default to 1 if not shown.
- unitPrice: (double, optional) Price per unit if shown, otherwise omit.
- total: (double) Line total (quantity * unitPrice).

Example JSON output:
{
  "merchant": "Target",
  "amount": 25.50,
  "date": "2023-10-25",
  "items": [
    { "name": "Milk 1L", "quantity": 2, "unitPrice": 3.50, "total": 7.00 },
    { "name": "Bread", "quantity": 1, "unitPrice": 4.50, "total": 4.50 }
  ]
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
