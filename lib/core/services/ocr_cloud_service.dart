import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../utils/receipt_parser.dart';

class OcrSpaceService {
  static const String _defaultApiKey = 'helloworld';
  static const String _endpoint = 'https://api.ocr.space/parse/image';

  final String? apiKey;

  OcrSpaceService({this.apiKey});

  Future<ReceiptData> parseReceiptFromBytes(
    Uint8List bytes, {
    String mimeType = 'image/jpeg',
  }) async {
    final key = apiKey ?? _defaultApiKey;

    final request = http.MultipartRequest('POST', Uri.parse(_endpoint));
    request.fields['apikey'] = key;
    request.fields['language'] = 'eng';
    request.fields['OCREngine'] = '2';
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: 'receipt.jpg'),
    );

    final response = await request.send();
    final body = await response.stream.bytesToString();
    final decoded = jsonDecode(body) as Map<String, dynamic>;

    if (decoded['IsErroredOnProcessing'] == true || decoded['ErrorMessage'] != null) {
      throw Exception(
        'OCR.space error: ${decoded['ErrorMessage'] ?? decoded['ErrorDetails'] ?? 'Unknown error'}',
      );
    }

    final results = decoded['ParsedResults'] as List?;
    if (results == null || results.isEmpty) {
      throw Exception('OCR.space returned no results');
    }

    final text = results.first['ParsedText'] as String? ?? '';
    if (text.trim().isEmpty) {
      throw Exception('OCR.space returned empty text');
    }

    return ReceiptParser.parseLines(text.split('\n'));
  }
}
