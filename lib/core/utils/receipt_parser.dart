import 'dart:convert';

class ReceiptItem {
  final String name;
  final double quantity;
  final double? unitPrice;
  final double total;

  const ReceiptItem({
    required this.name,
    this.quantity = 1,
    this.unitPrice,
    required this.total,
  });
}

class ReceiptData {
  final String? merchant;
  final DateTime? date;
  final double? amount;
  final List<ReceiptItem> items;

  ReceiptData({
    this.merchant,
    this.date,
    this.amount,
    this.items = const [],
  });
}

class ReceiptParser {
  static const List<String> _labelNoise = [
    'subtotal',
    'sub total',
    'sub-total',
    'total',
    'grand total',
    'jumlah',
    'bayar',
    'tunai',
    'cash',
    'change',
    'kembali',
    'kembalian',
    'ppn',
    'pb1',
    'tax',
    'vat',
    'service',
    'discount',
    'disc',
    'kasir',
    'cashier',
    'npwp',
    'tel:',
    'telp',
    'no.',
    'no:',
    'invoice',
    'struk',
    'faktur',
    'qris',
    'gopay',
    'go-pay',
    'debit',
    'kredit',
    'kartu',
    'sisa',
    'ongkir',
    'biaya',
    'fee',
    'pembulatan',
    'rounding',
  ];

  static const List<String> _totalKeywords = [
    'total',
    'grand total',
    'total bayar',
    'total belanja',
    'jumlah',
  ];

  static final RegExp _dateRegex = RegExp(
    r'(\d{2})[-/](\d{2})[-/](\d{4})|(\d{4})[-/](\d{2})[-/](\d{2})',
  );

  /// qty [xX*] unitPrice → total
  static final RegExp _qtyItemRegex = RegExp(
    r'^(.+?)\s+(\d+(?:[.,]\d+)?)\s*[xX*]\s*([\d.,]+)\s+(-?[\d.,]+)$',
  );

  /// Greedy: name captures everything before the final amount token.
  static final RegExp _simpleItemRegex = RegExp(r'^(.+)\s+(-?[\d.,]+)$');

  /// Leading SKU code: 6+ digits followed by whitespace.
  static final RegExp _skuPrefixRegex = RegExp(r'^\d{6,}\s+');

  /// Lines dominated by payment method noise — treat as not an item.
  static final List<String> _paymentNoise = [
    'qris', 'gopay', 'go-pay', 'debit', 'kredit', 'kartu',
    'tunai', 'cash', 'kembali', 'sisa', 'mested',
  ];

  /// Extracts transaction data from a list of text lines.
  static ReceiptData parseLines(List<String> lines) {
    String? merchant;
    DateTime? date;
    double? amount;
    int? merchantIndex;
    int? totalIndex;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim().toLowerCase();
      if (line.isEmpty) continue;

      // Merchant
      if (merchant == null && !line.contains(RegExp(r'\d')) && line.length > 3) {
        merchant = lines[i].trim();
        merchantIndex = i;
      }

      // Date
      if (date == null) {
        final match = _dateRegex.firstMatch(line);
        if (match != null) {
          try {
            if (match.group(1) != null) {
              date = DateTime(
                int.parse(match.group(3)!),
                int.parse(match.group(2)!),
                int.parse(match.group(1)!),
              );
            } else {
              date = DateTime(
                int.parse(match.group(4)!),
                int.parse(match.group(5)!),
                int.parse(match.group(6)!),
              );
            }
          } catch (_) {}
        }
      }

      // Amount near TOTAL keywords
      if (amount == null) {
        final containsTotal = _totalKeywords.any((kw) => line.contains(kw));
        if (containsTotal) {
          double? best;
          for (int j = i; j < i + 3 && j < lines.length; j++) {
            final parsed = _parseAmount(lines[j]);
            if (parsed != null && parsed > 0) {
              if (best == null || parsed > best) {
                best = parsed;
              }
            }
          }
          if (best != null) {
            amount = best;
            totalIndex = i;
          }
        }
      }
    }

    final items = _extractItems(
      lines,
      fromIndex: (merchantIndex ?? -1) + 1,
      toIndex: totalIndex ?? lines.length,
    );

    return ReceiptData(
      merchant: merchant,
      date: date,
      amount: amount,
      items: items,
    );
  }

  static List<ReceiptItem> _extractItems(
    List<String> lines, {
    required int fromIndex,
    required int toIndex,
  }) {
    final items = <ReceiptItem>[];
    for (int i = fromIndex; i < toIndex && i < lines.length; i++) {
      var raw = lines[i].trim();
      if (raw.isEmpty) continue;
      final lower = raw.toLowerCase();

      // Skip date lines.
      if (_dateRegex.hasMatch(raw)) continue;

      // Skip label rows.
      if (_labelNoise.any((kw) => lower.contains(kw))) continue;

      // Skip payment-method-dominant lines.
      if (_paymentNoise.any((kw) => lower.startsWith(kw) || lower == kw)) continue;

      // Strip leading SKU code.
      raw = raw.replaceFirst(_skuPrefixRegex, '');

      // qty x unit → total
      final qtyMatch = _qtyItemRegex.firstMatch(raw);
      if (qtyMatch != null) {
        final name = qtyMatch.group(1)!.trim();
        if (_looksLikeItemName(name)) {
          final quantity = _parseAmount(qtyMatch.group(2)!) ?? 1;
          final unitPrice = _parseAmount(qtyMatch.group(3)!);
          final total = _parseAmount(qtyMatch.group(4)!);
          if (total != null && total.abs() > 0) {
            items.add(
              ReceiptItem(
                name: name,
                quantity: quantity,
                unitPrice: unitPrice,
                total: total,
              ),
            );
            continue;
          }
        }
      }

      // Simple "name … total" (greedy match)
      final simple = _simpleItemRegex.firstMatch(raw);
      if (simple != null) {
        final name = simple.group(1)!.trim();
        // Remove trailing noise like "A   " from the name.
        final cleanName = name.replaceAll(RegExp(r'\s{2,}.*$'), '').trim();
        final total = _parseAmount(simple.group(2)!);
        if (total != null && total.abs() > 0 && _looksLikeItemName(cleanName)) {
          items.add(ReceiptItem(name: cleanName, total: total));
        }
      }
    }
    return items;
  }

  static bool _looksLikeItemName(String name) {
    final trimmed = name.trim();
    if (trimmed.length < 2) return false;
    if (RegExp(r'^[\d\s.,\-:/]+$').hasMatch(trimmed)) return false;
    final lower = trimmed.toLowerCase();
    if (_labelNoise.any((kw) => lower.contains(kw))) return false;
    return true;
  }

  /// Parses a numeric token that may use `.` or `,` as thousands/decimal separators.
  static double? _parseAmount(String token) {
    var t = token.replaceAll(RegExp(r'[^\d.,\-]'), '');
    if (t.isEmpty) return null;

    final negative = t.startsWith('-');
    if (negative) t = t.substring(1);
    if (t.isEmpty) return null;

    final hasComma = t.contains(',');
    final hasDot = t.contains('.');

    if (hasComma && hasDot) {
      if (t.lastIndexOf(',') > t.lastIndexOf('.')) {
        t = t.replaceAll('.', '').replaceAll(',', '.');
      } else {
        t = t.replaceAll(',', '');
      }
    } else if (hasComma) {
      // If comma has 3+ digits after it (e.g. 12,500), treat comma as thousands separator.
      final afterComma = t.split(',').last;
      if (afterComma.length >= 3) {
        t = t.replaceAll(',', '');
      } else {
        t = t.replaceAll('.', '').replaceAll(',', '.');
      }
    } else if (hasDot) {
      final dots = '.'.allMatches(t).length;
      if (dots > 1 || RegExp(r'\.\d{3}(?!\d)').hasMatch(t)) {
        t = t.replaceAll('.', '');
      }
    }

    final parsed = double.tryParse(t);
    if (parsed == null) return null;
    return negative ? -parsed : parsed;
  }

  /// Extracts transaction data from a Gemini JSON response.
  static ReceiptData parseGeminiJson(String jsonString) {
    String cleanJson = jsonString.trim();
    if (cleanJson.startsWith('```json')) {
      cleanJson = cleanJson.substring(7);
    } else if (cleanJson.startsWith('```')) {
      cleanJson = cleanJson.substring(3);
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

      final rawItems = data['items'];
      final items = <ReceiptItem>[];
      if (rawItems is List) {
        for (final entry in rawItems) {
          if (entry is! Map) continue;
          final name = entry['name']?.toString().trim();
          if (name == null || name.isEmpty) continue;
          final quantity =
              double.tryParse(entry['quantity']?.toString() ?? '') ?? 1;
          final unitPrice = double.tryParse(entry['unitPrice']?.toString() ?? '');
          final total = double.tryParse(entry['total']?.toString() ?? '') ??
              (unitPrice != null ? unitPrice * quantity : null);
          if (total == null) continue;
          items.add(
            ReceiptItem(
              name: name,
              quantity: quantity,
              unitPrice: unitPrice,
              total: total,
            ),
          );
        }
      }

      return ReceiptData(
        merchant: data['merchant']?.toString(),
        date: parsedDate,
        amount: parsedAmount,
        items: items,
      );
    } catch (_) {
      return ReceiptData();
    }
  }
}
