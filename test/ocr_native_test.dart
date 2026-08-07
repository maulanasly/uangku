import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:apple_vision_recognize_text/apple_vision_recognize_text.dart';

import 'package:uangku/core/services/ocr_native.dart';

void main() {
  group('joinRecognizedLines', () {
    test('joins each observation using its best candidate', () {
      final observations = [
        RecognizedText(
          const Rect.fromLTWH(0, 0, 10, 10),
          ['Toko Makmur', 'Toko Makmur 2'],
        ),
        RecognizedText(
          const Rect.fromLTWH(0, 10, 10, 10),
          ['Rp 25.000', '25.000'],
        ),
      ];

      expect(joinRecognizedLines(observations), 'Toko Makmur\nRp 25.000');
    });

    test('returns empty string for no observations', () {
      expect(joinRecognizedLines(const []), '');
    });

    test('skips empty candidate lists', () {
      final observations = [
        RecognizedText(const Rect.fromLTWH(0, 0, 10, 10), ['Header']),
        RecognizedText(const Rect.fromLTWH(0, 10, 10, 10), const []),
      ];

      expect(joinRecognizedLines(observations), 'Header');
    });
  });
}
