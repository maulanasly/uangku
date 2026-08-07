import 'dart:convert';

class ReceiptData {
  final String? merchant;
  final DateTime? date;
  final double? amount;

  ReceiptData({this.merchant, this.date, this.amount});
}

class ReceiptParser {
  /// Extracts transaction data from a list of text lines.
  static ReceiptData parseLines(List<String> lines) {
    String? merchant;
    DateTime? date;
    double? amount;

    final dateRegex = RegExp(r'(\d{2})[-/](\d{2})[-/](\d{4})|(\d{4})[-/](\d{2})[-/](\d{2})');
    final totalKeywords = ['total', 'grand total', 'total bayar', 'total belanja', 'jumlah'];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim().toLowerCase();
      if (line.isEmpty) continue;

      // Merchant: First meaningful text line (assuming phone/tax are filtered or below)
      if (merchant == null && !line.contains(RegExp(r'\d')) && line.length > 3) {
        merchant = lines[i].trim();
      }

      // Date
      if (date == null) {
        final match = dateRegex.firstMatch(line);
        if (match != null) {
          try {
            if (match.group(1) != null) {
              // dd/mm/yyyy
              date = DateTime(int.parse(match.group(3)!), int.parse(match.group(2)!), int.parse(match.group(1)!));
            } else {
              // yyyy/mm/dd
              date = DateTime(int.parse(match.group(4)!), int.parse(match.group(5)!), int.parse(match.group(6)!));
            }
          } catch (_) {}
        }
      }

      // Amount: Near TOTAL keywords
      if (amount == null) {
        final containsTotal = totalKeywords.any((kw) => line.contains(kw));
        if (containsTotal) {
          // Look for numbers in the current line or next few lines and pick the largest
          double? best;
          for (int j = i; j < i + 3 && j < lines.length; j++) {
            final textToSearch = lines[j].replaceAll(RegExp(r'[^\d.]'), '');
            final parsedAmount = double.tryParse(textToSearch);
            if (parsedAmount != null && parsedAmount > 0) {
              if (best == null || parsedAmount > best) {
                best = parsedAmount;
              }
            }
          }
          if (best != null) {
            amount = best;
          }
        }
      }
    }

    return ReceiptData(merchant: merchant, date: date, amount: amount);
  }

  /// Extracts transaction data from a Gemini JSON response.
  static ReceiptData parseGeminiJson(String jsonString) {
    // Clean up potential markdown formatting from Gemini
    String cleanJson = jsonString.trim();
    if (cleanJson.startsWith('```json')) {
      cleanJson = cleanJson.substring(7);
    }
    if (cleanJson.endsWith('```')) {
      cleanJson = cleanJson.substring(0, cleanJson.length - 3);
    }
    cleanJson = cleanJson.trim();

    try {
      final Map<String, dynamic> data = jsonDecode(cleanJson);
      
      DateTime? parsedDate;
      if (data['date'] != null) {
        try {
          parsedDate = DateTime.parse(data['date'].toString());
        } catch (_) {}
      }

      double? parsedAmount;
      if (data['amount'] != null) {
        parsedAmount = double.tryParse(data['amount'].toString());
      }

      return ReceiptData(
        merchant: data['merchant']?.toString(),
        date: parsedDate,
        amount: parsedAmount,
      );
    } catch (e) {
      return ReceiptData(); // Return empty if parsing fails
    }
  }
}
