import 'dart:convert';
import 'dart:math' as math;

enum ReceiptItemStatus { purchased, cancelled }

class ReceiptItem {
  final String name;
  final double quantity;
  final double? unitPrice;
  final double? weight;
  final double total;
  final String? itemCode;
  final double? discountAmount;
  final ReceiptItemStatus? status;

  const ReceiptItem({
    required this.name,
    this.quantity = 1,
    this.unitPrice,
    this.weight,
    required this.total,
    this.itemCode,
    this.discountAmount,
    this.status,
  });
}

class ReceiptData {
  final String? merchant;
  final DateTime? date;
  final double? amount;
  final List<ReceiptItem> items;
  final String? storeAddress;
  final String? receiptId;
  final String? paymentMethod;
  final double? subtotal;
  final double? totalDiscount;
  final double? changeDue;
  final String? reconciliationWarning;

  ReceiptData({
    this.merchant,
    this.date,
    this.amount,
    this.items = const [],
    this.storeAddress,
    this.receiptId,
    this.paymentMethod,
    this.subtotal,
    this.totalDiscount,
    this.changeDue,
    this.reconciliationWarning,
  });
}

class ReceiptParser {
  /// Words that mark rows which are never line items. Used both to skip rows
  /// during item extraction and to reject candidate item names.
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
    'pajak',
    'materai',
    'diskon',
    'potongan',
    'potong',
    'promo',
    'discount',
    'disc',
    'kasir',
    'cashier',
    'npwp',
    'tel:',
    'telp',
    'tel',
    'telepon',
    'phone',
    'fax',
    'no',
    'nomor',
    'no.',
    'no:',
    'invoice',
    'struk',
    'faktur',
    'transaksi',
    'kode',
    'member',
    'pukul',
    'jam',
    'tgl',
    'tanggal',
    'qris',
    'gopay',
    'go-pay',
    'gocash',
    'debit',
    'kredit',
    'kartu',
    'transfer',
    'visa',
    'mastercard',
    'ovo',
    'dana',
    'mested',
    'sisa',
    'ongkir',
    'biaya',
    'fee',
    'pembulatan',
    'rounding',
    'voucher',
    'rp',
  ];

  /// Rows that belong to the receipt header/metadata block.
  static const List<String> _idKeywords = [
    'no',
    'nomor',
    'struk',
    'invoice',
    'faktur',
    'transaksi',
    'trx',
    'ord',
    'receipt',
    'bill',
    'kasir',
    'cashier',
    'npwp',
    'cabang',
    'cab',
    'kode',
    'member',
    'pukul',
    'jam',
    'tgl',
    'tanggal',
    'tel',
    'telp',
    'telepon',
    'phone',
    'fax',
  ];

  /// Like [_idKeywords] but without `no`/`nomor` (house numbers must not be
  /// dropped from addresses). Used when filtering address lines.
  static const List<String> _headerMetaKeywords = [
    'struk',
    'invoice',
    'faktur',
    'transaksi',
    'trx',
    'ord',
    'receipt',
    'bill',
    'kasir',
    'cashier',
    'npwp',
    'cabang',
    'cab',
    'kode',
    'member',
    'pukul',
    'jam',
    'tgl',
    'tanggal',
    'tel',
    'telp',
    'telepon',
    'phone',
    'fax',
  ];

  /// Words that signal an address line (street, city, district).
  static const List<String> _addressKeywords = [
    'jl',
    'jalan',
    'st',
    'street',
    'rd',
    'road',
    'ave',
    'avenue',
    'blvd',
    'boulevard',
    'dr',
    'drive',
    'lane',
    'place',
    'court',
    'plaza',
    'rt',
    'rw',
    'kel',
    'kec',
    'kota',
    'kab',
    'prop',
    'dusun',
    'gang',
    'blok',
    'km',
  ];

  /// Words used to detect item-table header rows (e.g. `ITEM QTY HARGA JUMLAH`).
  static const List<String> _itemHeaderKeywords = [
    'qty',
    'harga',
    'jumlah',
    'satuan',
    'barang',
    'produk',
    'item',
    'nama',
  ];

  static const List<String> _subtotalKeywords = [
    'subtotal',
    'sub total',
    'sub-total',
    'jual',
  ];

  static const List<String> _taxKeywords = [
    'ppn',
    'pb1',
    'tax',
    'vat',
    'service',
    'pajak',
    'materai',
    'pembulatan',
    'rounding',
  ];

  /// Words that mark a discount/promo row.
  static const List<String> _discountKeywords = [
    'disc',
    'discount',
    'diskon',
    'potongan',
    'potong',
    'promo',
    'voucher',
  ];

  static const List<String> _changeKeywords = [
    'kembali',
    'kembalian',
    'change',
    'sisa',
    'tukar',
  ];

  static const List<String> _paymentKeywords = [
    'qris',
    'gopay',
    'go-pay',
    'gocash',
    'ovo',
    'dana',
    'debit',
    'kredit',
    'kartu',
    'tunai',
    'cash',
    'transfer',
    'visa',
    'mastercard',
    'mested',
    'flo',
  ];

  static const List<String> _cancelKeywords = [
    'batal',
    'cancel',
    'cancelled',
    'void',
    'retur',
    'refund',
  ];

  static final RegExp _dateRegex = RegExp(
    r'(\d{1,2})[-/.](\d{1,2})[-/.](\d{4})|(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})',
  );

  /// Guarded `dd[-/.]mm[-/.]yy` (2-digit year). Only ever used as a fallback
  /// for the date field; day/month/year validity is enforced in [_matchDate].
  static final RegExp _date2yRegex = RegExp(
    r'(?<!\d)(\d{1,2})[-/.](\d{1,2})[-/.](\d{2})(?!\d)',
  );

  static final RegExp _timeRegex = RegExp(
    r'(?<!\d)(\d{1,2})[:.](\d{2})(?::(\d{2}))?(?!\d)',
  );

  static final RegExp _timeOnlyRegex = RegExp(
    r'^\d{1,2}[:.]\d{2}([:.]\d{2})?$',
  );

  /// Barcode / SKU-only line (12-14 digit EAN/UPC).
  static final RegExp _barcodeRegex = RegExp(r'^\d{12,14}$');

  /// Leading SKU code: 6+ digits followed by whitespace.
  static final RegExp _skuPrefixRegex = RegExp(r'^\d{6,}\s+');

  /// Decoration/separator rows.
  static final RegExp _separatorRegex = RegExp(r'^[\s\-=_*·•.|~]+$');

  /// A line that is a short store/city name + 5-digit postal code
  /// (e.g. `BANDUNG 40132`). Kept strict so `GULA PASIR 15000` is not caught.
  static final RegExp _cityZipRegex =
      RegExp(r'^[A-Za-z]{2,}(?: [A-Za-z]{2,})? \d{5}$');

  /// A US city/state/zip line (e.g. `Seattle, WA 98101`).
  static final RegExp _usCityStateZipRegex = RegExp(
    r"^[A-Za-z][A-Za-z .'\-]+, [A-Za-z]{2} \d{5}$",
  );

  static bool _isCityZip(String line) {
    return line.length <= 30 &&
        (_cityZipRegex.hasMatch(line) || _usCityStateZipRegex.hasMatch(line));
  }

  /// Numeric money token, not followed by a letter or more of the number
  /// (so `25GR`/`5kg` never yield a token, but backtracking to an empty
  /// `[\d.,]*` can't match a lone digit of `25GR`).
  static final RegExp _moneyTokenRegex =
      RegExp(r'-?[\d][\d.,]*(?![.,\dA-Za-z])');

  static final RegExp _receiptStrukRegex = RegExp(
    r'(struk|invoice|faktur|transaksi|trx|receipt|bill)'
    r'(?:\s*(?:no|nomor|no\.))?\s*[:=]?\s*([A-Za-z0-9][A-Za-z0-9\-/]*)',
    caseSensitive: false,
  );

  static final RegExp _receiptNoRegex = RegExp(
    r'\bno\s*[:.]?\s*(\d{4,})',
    caseSensitive: false,
  );

  /// Extracts transaction data from a list of OCR text lines.
  static ReceiptData parseLines(List<String> lines) {
    final clean = _cleanLines(lines);

    final header = _scanHeader(clean);

    final totals = _scanTotals(clean, header);

    final items = _extractItems(
      clean,
      fromIndex: header.headerEnd,
      toIndex: totals.totalIndex ?? clean.length,
    );

    final itemSum = items
        .where((i) => i.status != ReceiptItemStatus.cancelled || i.total < 0)
        .fold<double>(0, (s, i) => s + i.total);
    String? warning;
    if (totals.subtotal != null && !_approx(itemSum, totals.subtotal!)) {
      warning = 'Scanned items sum to ${_fmt(itemSum)} but the subtotal shows '
          '${_fmt(totals.subtotal!)}. Review the items before saving.';
    } else if (totals.amount != null &&
        totals.subtotal != null &&
        !_approx(totals.amount!, totals.expected)) {
      warning =
          'The total (${_fmt(totals.amount!)}) does not match the subtotal '
          'after discounts and taxes. Review before saving.';
    }

    return ReceiptData(
      merchant: header.merchant,
      date: header.date,
      amount: totals.amount,
      items: items,
      storeAddress: header.storeAddress,
      receiptId: header.receiptId,
      paymentMethod: header.paymentMethod,
      subtotal: totals.subtotal,
      totalDiscount: totals.totalDiscount,
      changeDue: totals.changeDue,
      reconciliationWarning: warning,
    );
  }

  // ---------------------------------------------------------------------------
  // Stage 0 — normalization
  // ---------------------------------------------------------------------------

  static List<String> _cleanLines(List<String> lines) {
    final out = <String>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (_separatorRegex.hasMatch(trimmed)) continue;
      out.add(trimmed);
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Stage 1 — header/metadata
  // ---------------------------------------------------------------------------

  static _HeaderScan _scanHeader(List<String> clean) {
    int? merchantIndex;
    String? merchant;

    for (int i = 0; i < clean.length; i++) {
      final line = clean[i];
      final lower = line.toLowerCase();
      if (_isHeaderMetadata(line, lower)) continue;
      if (_isMerchantLike(line, lower)) {
        merchant = line;
        merchantIndex = i;
        break;
      }
    }

    int headerEnd = (merchantIndex ?? -1) + 1;
    {
      var i = headerEnd;
      while (i < clean.length) {
        final line = clean[i];
        final lower = line.toLowerCase();
        if (_isHeaderMetadata(line, lower)) {
          i++;
          continue;
        }
        // Street/city lines belong to the header, not the item body.
        if (_isAddressish(line, lower)) {
          i++;
          continue;
        }
        // A short, digit-free line right after an address line is a trailing
        // part of the address (e.g. the city name).
        if (i > 0 &&
            _isShortNameNoDigits(line) &&
            _isAddressish(clean[i - 1], clean[i - 1].toLowerCase())) {
          i++;
          continue;
        }
        break;
      }
      headerEnd = i;
    }

    // Store address = header lines that are not id/date/tel metadata.
    final addressParts = <String>[];
    for (int i = (merchantIndex ?? 0) + 1; i < headerEnd; i++) {
      final line = clean[i];
      final lower = line.toLowerCase();
      if (_dateRegex.hasMatch(line)) continue;
      if (_timeOnlyRegex.hasMatch(line)) continue;
      if (_headerMetaKeywords.any((k) => _containsWord(lower, k))) continue;
      if (_isItemHeaderRow(line, lower)) continue;
      addressParts.add(line);
    }

    return _HeaderScan(
      merchant: merchant,
      storeAddress: addressParts.isEmpty ? null : addressParts.join(', '),
      date: _scanDate(clean),
      receiptId: _scanReceiptId(clean, headerEnd),
      paymentMethod: _scanPaymentMethod(clean),
      headerEnd: headerEnd,
    );
  }

  static DateTime? _scanDate(List<String> clean) {
    for (int i = 0; i < clean.length; i++) {
      final dm = _matchDate(clean[i]);
      if (dm == null) continue;

      int? hour;
      int? minute;
      int? second;
      final timeMatch = _timeRegex.firstMatch(
        dm.match.end < clean[i].length ? clean[i].substring(dm.match.end) : '',
      );
      if (timeMatch != null) {
        hour = int.tryParse(timeMatch.group(1)!);
        minute = int.tryParse(timeMatch.group(2)!);
        second = int.tryParse(timeMatch.group(3) ?? '');
      } else {
        for (int j = i + 1; j <= i + 2 && j < clean.length; j++) {
          if (clean[j].length > 25) continue;
          final t = _timeRegex.firstMatch(clean[j]);
          if (t == null) continue;
          final h = int.tryParse(t.group(1)!);
          final m = int.tryParse(t.group(2)!);
          if (h == null || m == null || h > 23 || m > 59) continue;
          hour = h;
          minute = m;
          second = int.tryParse(t.group(3) ?? '');
          break;
        }
      }
      if (hour != null && (hour > 23 || (minute ?? 0) > 59)) {
        hour = null;
        minute = null;
        second = null;
      }

      return DateTime(
        dm.year,
        dm.month,
        dm.day,
        hour ?? 0,
        minute ?? 0,
        second ?? 0,
      );
    }
    return null;
  }

  static String? _scanReceiptId(List<String> clean, int headerEnd) {
    final upper = math.min(headerEnd, clean.length);
    for (int i = 0; i < upper; i++) {
      final struk = _receiptStrukRegex.firstMatch(clean[i]);
      if (struk != null) {
        final code = struk.group(2)!.trim();
        if (code.isNotEmpty &&
            !RegExp(r'^[a-z]+$', caseSensitive: false).hasMatch(code)) {
          return code;
        }
      }
      final no = _receiptNoRegex.firstMatch(clean[i]);
      if (no != null) {
        return no.group(1)!;
      }
    }
    // Fallback: a bare `#NNN` reference (e.g. Alfamart `#281`).
    for (final line in clean) {
      if (line.toLowerCase().contains('member')) continue;
      final hash = RegExp(r'(?:^|\s)#(\d+)\b').firstMatch(line);
      if (hash != null) return hash.group(1)!;
    }
    return null;
  }

  static String? _scanPaymentMethod(List<String> clean) {
    for (final line in clean) {
      final lower = line.toLowerCase();
      String? label;
      if (_containsWord(lower, 'qris')) {
        label = 'QRIS';
      } else if (_containsWord(lower, 'gopay') ||
          _containsWord(lower, 'go-pay') ||
          _containsWord(lower, 'gocash')) {
        label = 'GoPay';
      } else if (_containsWord(lower, 'ovo')) {
        label = 'OVO';
      } else if (_containsWord(lower, 'dana')) {
        label = 'DANA';
      } else if (_containsWord(lower, 'tunai') ||
          _containsWord(lower, 'cash')) {
        label = 'Cash';
      } else if (_containsWord(lower, 'debit')) {
        label = 'Debit';
      } else if (_containsWord(lower, 'kredit') ||
          _containsWord(lower, 'kartu') ||
          _containsWord(lower, 'visa') ||
          _containsWord(lower, 'mastercard')) {
        label = 'Card';
      } else if (_containsWord(lower, 'transfer')) {
        label = 'Transfer';
      }
      if (label != null) return label;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Stage 2 — totals & reconciliation
  // ---------------------------------------------------------------------------

  static _TotalsScan _scanTotals(List<String> clean, _HeaderScan header) {
    double? subtotal;
    int? subtotalIndex;
    double totalDiscount = 0;
    double taxSum = 0;
    double? changeDue;
    final candidates = <({int index, double value})>[];

    for (int i = 0; i < clean.length; i++) {
      final line = clean[i];
      final lower = line.toLowerCase();
      final value = _lineMoney(line);

      final isSubtotal = _subtotalKeywords.any((k) => _containsWord(lower, k));
      if (isSubtotal && value != null && value > 0) {
        subtotal = value;
        subtotalIndex = i;
      }

      if (_discountKeywords.any((k) => _containsWord(lower, k)) &&
          !_isDiscountMirrorLine(line, lower)) {
        final d = _discountValue(line);
        if (d != null && d > 0) totalDiscount += d;
      }

      if (_taxKeywords.any((k) => _containsWord(lower, k))) {
        if (value != null && value > 0) taxSum += value;
      }

      if (_changeKeywords.any((k) => _containsWord(lower, k))) {
        if (value != null && value > 0) changeDue = value;
      }

      final isGrandTotal = !isSubtotal &&
          (_containsWord(lower, 'total') ||
              _containsWord(lower, 'jumlah') ||
              _containsWord(lower, 'belanja'));
      if (isGrandTotal && value != null && value > 0) {
        candidates.add((index: i, value: value));
      }
    }

    double? amount;
    int? totalIndex;
    if (candidates.isNotEmpty) {
      final expected =
          subtotal == null ? null : subtotal - totalDiscount + taxSum;
      var best = candidates.reduce((a, b) => a.value >= b.value ? a : b);
      if (expected != null) {
        final matching =
            candidates.where((c) => _approx(c.value, expected)).toList();
        if (matching.isNotEmpty) {
          best = matching.reduce((a, b) => a.value >= b.value ? a : b);
        }
      }
      amount = best.value;
      totalIndex = best.index;
    } else if (subtotal != null) {
      amount = subtotal - totalDiscount + taxSum;
      totalIndex = subtotalIndex;
    }

    return _TotalsScan(
      subtotal: subtotal,
      totalDiscount: totalDiscount == 0 ? null : totalDiscount,
      taxSum: taxSum,
      changeDue: changeDue,
      amount: amount,
      totalIndex: totalIndex,
    );
  }

  // ---------------------------------------------------------------------------
  // Stage 3 — line items
  // ---------------------------------------------------------------------------

  static List<ReceiptItem> _extractItems(
    List<String> clean, {
    required int fromIndex,
    required int toIndex,
  }) {
    final items = <ReceiptItem>[];
    final pending = <String>[];

    double? pendingQty;
    double? pendingUnit;
    String? pendingCode;

    void flushAll() {
      pending.clear();
      pendingQty = null;
      pendingUnit = null;
      pendingCode = null;
    }

    void flushNames() => pending.clear();

    void resetCarry() {
      pendingQty = null;
      pendingUnit = null;
      pendingCode = null;
    }

    void emitPending({
      double quantity = 1,
      double? unitPrice,
      double? weight,
      required double total,
      String? itemCode,
      ReceiptItemStatus? status,
    }) {
      if (pending.isEmpty) return;
      final name = pending.join(' ').trim();
      pending.clear();
      if (total.abs() == 0 || !_looksLikeItemName(name)) return;
      items.add(
        ReceiptItem(
          name: name,
          quantity: quantity,
          unitPrice: unitPrice,
          weight: weight,
          total: total,
          itemCode: itemCode,
          status: status,
        ),
      );
    }

    for (int i = fromIndex; i < toIndex && i < clean.length; i++) {
      var raw = clean[i];
      final isStarred = raw.startsWith('*');
      if (isStarred) {
        raw = raw.replaceFirst(RegExp(r'^\*\s*'), '').trim();
      }
      final lower = raw.toLowerCase();

      // Per-item discount mirror rows (`DISC 20% X 1.0 2.400-`) fold into the
      // preceding item instead of becoming items of their own.
      if (_isDiscountMirrorLine(raw, lower)) {
        if (items.isNotEmpty) {
          final amount = _discountValue(raw);
          if (amount != null) {
            final last = items.removeLast();
            items.add(
              ReceiptItem(
                name: last.name,
                quantity: last.quantity,
                unitPrice: last.unitPrice,
                weight: last.weight,
                total: last.total,
                itemCode: last.itemCode,
                discountAmount: (last.discountAmount ?? 0) + amount,
                status: last.status,
              ),
            );
          }
        }
        flushAll();
        continue;
      }

      // `ITEM # <code>` carries a code forward to the next item line.
      final carriedCode = _itemCodeLine(raw);
      if (carriedCode != null) {
        pendingCode = carriedCode;
        flushNames();
        continue;
      }

      if (_matchDate(raw) != null) {
        flushAll();
        continue;
      }
      if (_timeOnlyRegex.hasMatch(raw)) {
        flushAll();
        continue;
      }
      if (_isItemHeaderRow(raw, lower)) {
        flushAll();
        continue;
      }
      if (_isCityZip(raw)) {
        flushAll();
        continue;
      }
      if (raw.startsWith(',') || lower.startsWith('http')) {
        flushAll();
        continue;
      }
      if (_isAddressish(raw, lower)) {
        flushAll();
        continue;
      }
      if (_isNoiseLine(raw, lower)) {
        flushAll();
        continue;
      }
      if (_barcodeRegex.hasMatch(raw)) {
        flushAll();
        continue;
      }

      var status = ReceiptItemStatus.purchased;
      if (isStarred || _cancelKeywords.any((k) => _containsWord(lower, k))) {
        status = ReceiptItemStatus.cancelled;
      }

      String? itemCode;
      final sku = _skuPrefixRegex.firstMatch(raw);
      if (sku != null) {
        itemCode = sku.group(0)!.trim();
        raw = raw.replaceFirst(_skuPrefixRegex, '').trim();
      }

      final parsed = _parseItemLine(raw);
      if (parsed == null) {
        if (_looksLikeItemName(raw) && pending.length < 4) {
          pending.add(raw);
        } else {
          flushAll();
        }
        continue;
      }

      // `qty x unit` with no total — stash for the following name + total line.
      if (parsed.total == null && parsed.unitPrice != null) {
        pendingQty = parsed.quantity;
        pendingUnit = parsed.unitPrice;
        flushNames();
        continue;
      }

      if (parsed.name.isNotEmpty && parsed.total != null) {
        if (_looksLikeItemName(parsed.name)) {
          var quantity = parsed.quantity;
          var unitPrice = parsed.unitPrice;
          final carriedQty = pendingQty;
          if (quantity == 1 && unitPrice == null && carriedQty != null) {
            quantity = carriedQty;
            unitPrice = pendingUnit;
          }
          var name = parsed.name;
          var total = parsed.total!;
          if (status == ReceiptItemStatus.cancelled &&
              _isCancelOnlyName(parsed.name)) {
            if (items.isNotEmpty) name = items.last.name;
            total = -total.abs();
          }
          items.add(
            ReceiptItem(
              name: name,
              quantity: quantity,
              unitPrice: unitPrice,
              weight: parsed.weight,
              total: total,
              itemCode: pendingCode ?? itemCode,
              status: status,
            ),
          );
        }
        resetCarry();
        flushNames();
        continue;
      }

      if (parsed.total != null && pending.isNotEmpty) {
        emitPending(
          quantity: parsed.quantity,
          unitPrice: parsed.unitPrice,
          weight: parsed.weight,
          total: parsed.total!,
          itemCode: pendingCode ?? itemCode,
          status: status,
        );
        resetCarry();
        continue;
      }

      flushAll();
    }
    return items;
  }

  /// Parses a single body line into a candidate item. Returns null when the
  /// line carries no money information (a name-only line).
  static _ParsedLine? _parseItemLine(String raw) {
    final tokens = _moneyTokens(raw);
    if (tokens.isEmpty) return null;

    final first = _nameBoundaryToken(raw, tokens) ?? tokens.first;
    var name = raw.substring(0, first.start).trim();
    name = name.replaceAll(RegExp(r'\s{2,}'), ' ').trim();

    final values = [for (final t in tokens) t.value];
    final total = values.last; // name + qty x unit → total
    final qtyItem = RegExp(
      r'^(.+?)\s+(\d+(?:[.,]\d+)?)\s*[xX*]\s*([\d.,]+)\s+(-?[\d.,]+)$',
    ).firstMatch(raw);
    if (qtyItem != null) {
      final qName = qtyItem.group(1)!.trim();
      if (_looksLikeItemName(qName)) {
        final qty = _parseAmount(qtyItem.group(2)!) ?? 1;
        final unit = _parseAmount(qtyItem.group(3)!);
        final tot = _parseAmount(qtyItem.group(4)!);
        if (unit != null && tot != null && _approx(qty * unit, tot)) {
          return _ParsedLine(
            name: qName,
            quantity: qty,
            unitPrice: unit,
            total: tot,
          );
        }
      }
    }

    // name + qty @ unit [/kg] [=] total
    final atMatch = RegExp(
      r'^(.+?)\s+(\d+(?:[.,]\d+)?)\s*@\s*([\d.,]+)'
      r'(?:/(KG|GR|G|ML|L))?\s*(?:=)?\s*(-?[\d.,]+)?$',
      caseSensitive: false,
    ).firstMatch(raw);
    if (atMatch != null) {
      final aName = atMatch.group(1)!.trim();
      final qty = _parseAmount(atMatch.group(2)!) ?? 1;
      final unit = _parseAmount(atMatch.group(3)!);
      if (_looksLikeItemName(aName) && unit != null) {
        final explicit =
            atMatch.group(5) == null ? null : _parseAmount(atMatch.group(5)!);
        final computed = qty * unit;
        final tot = (explicit != null && _approx(explicit, computed))
            ? explicit
            : computed;
        return _ParsedLine(
          name: aName,
          quantity: qty,
          unitPrice: unit,
          weight: atMatch.group(4) != null ? qty : null,
          total: tot,
        );
      }
    }

    // name + x qty unit → total (restaurant-style `NASI PUTIH x 2 5.000 10.000`)
    final xQty = RegExp(
      r'^(.+?)\s+[xX]\s+(\d+(?:[.,]\d+)?)\s+([\d.,]+)\s+(-?[\d.,]+)$',
    ).firstMatch(raw);
    if (xQty != null) {
      final xName = xQty.group(1)!.trim();
      if (_looksLikeItemName(xName)) {
        final qty = _parseAmount(xQty.group(2)!) ?? 1;
        final unit = _parseAmount(xQty.group(3)!);
        final tot = _parseAmount(xQty.group(4)!);
        if (unit != null && tot != null && _approx(qty * unit, tot)) {
          return _ParsedLine(
            name: xName,
            quantity: qty,
            unitPrice: unit,
            total: tot,
          );
        }
      }
    }

    // Continuation without a name: `qty x unit [=] total`
    final keyless = RegExp(
      r'^(\d+(?:[.,]\d+)?)\s*[xX*]\s*([\d.,]+)\s*(?:=\s*|\s+)(-?[\d.,]+)$',
    ).firstMatch(raw);
    if (keyless != null) {
      final qty = _parseAmount(keyless.group(1)!) ?? 1;
      final unit = _parseAmount(keyless.group(2)!);
      final tot = _parseAmount(keyless.group(3)!);
      if (unit != null && tot != null) {
        final computed = qty * unit;
        return _ParsedLine(
          quantity: qty,
          unitPrice: unit,
          total: _approx(tot, computed) ? tot : computed,
        );
      }
    }

    // Continuation: `x<qty> @ unit`
    final xAt =
        RegExp(r'^[xX]\s*(\d+(?:[.,]\d+)?)\s*@\s*([\d.,]+)$').firstMatch(raw);
    if (xAt != null) {
      final qty = _parseAmount(xAt.group(1)!) ?? 1;
      final unit = _parseAmount(xAt.group(2)!);
      if (unit != null) {
        return _ParsedLine(quantity: qty, unitPrice: unit, total: qty * unit);
      }
    }

    // `qty x unit` with no total (e.g. YOGYA `2.0 X 12000`) — the total is
    // emitted on the following name line.
    final qtyOnly = RegExp(
      r'^(\d+(?:[.,]\d+)?)\s*[xX*]\s*(-?[\d.,]+)$',
    ).firstMatch(raw);
    if (qtyOnly != null) {
      final qty = _parseAmount(qtyOnly.group(1)!) ?? 1;
      final unit = _parseAmount(qtyOnly.group(2)!);
      if (unit != null) {
        return _ParsedLine(quantity: qty, unitPrice: unit);
      }
    }

    // Generic token layouts.
    if (values.length >= 3) {
      final q = values[values.length - 3];
      final u = values[values.length - 2];
      final t = values.last;
      if (q > 0 && u > 0 && _approx(q * u, t)) {
        return _ParsedLine(
          name: name,
          quantity: q,
          unitPrice: u,
          total: t,
        );
      }
    }

    if (values.length == 2) {
      final a = values[0];
      final b = values[1];
      if (_approx(a, b)) {
        return _ParsedLine(name: name, quantity: 1, unitPrice: a, total: b);
      }
      if (name.isEmpty) {
        return _ParsedLine(name: name, quantity: a, total: b);
      }
      return _ParsedLine(name: name, quantity: 1, total: b);
    }
    return _ParsedLine(name: name, total: total);
  }

  // ---------------------------------------------------------------------------
  // Classification helpers
  // ---------------------------------------------------------------------------

  static bool _isHeaderMetadata(String line, String lower) {
    if (_separatorRegex.hasMatch(line)) return true;
    if (_matchDate(line) != null) return true;
    if (_timeOnlyRegex.hasMatch(line)) return true;
    if (_isItemHeaderRow(line, lower)) return true;
    if (_idKeywords.any((k) => _containsWord(lower, k))) return true;
    if (_addressKeywords.any((k) => _containsWord(lower, k))) return true;
    if (_isCityZip(line)) return true;
    return false;
  }

  static bool _isMerchantLike(String line, String lower) {
    if (line.length < 3) return false;
    if (_isHeaderMetadata(line, lower)) return false;
    if (line.contains(RegExp(r'\d'))) return false;
    if (_moneyTokens(line).isNotEmpty) return false;
    return RegExp(r'[A-Za-z]{2,}').hasMatch(line);
  }

  static bool _isAddressish(String line, String lower) {
    if (_addressKeywords.any((k) => _containsWord(lower, k))) return true;
    if (_isCityZip(line)) return true;
    if (_containsWord(lower, 'no')) return true;
    return false;
  }

  static bool _isShortNameNoDigits(String line) {
    if (line.contains(RegExp(r'\d'))) return false;
    final words =
        line.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length > 2) return false;
    if (line.length > 16) return false;
    return RegExp(r'[A-Za-z]').hasMatch(line);
  }

  static bool _isItemHeaderRow(String line, String lower) {
    if (_moneyTokens(line).isNotEmpty) return false;
    final words =
        lower.split(RegExp(r'[^a-z0-9]+')).where((w) => w.isNotEmpty).toList();
    if (words.length > 6) return false;
    return _itemHeaderKeywords.any((k) => _containsWord(lower, k));
  }

  static bool _isNoiseLine(String line, String lower) {
    if (_labelNoise.any((k) => _containsWord(lower, k))) return true;
    if (_paymentKeywords.any((k) => _containsWord(lower, k))) return true;
    return false;
  }

  /// Checks whether [text] contains [word] as a whole word (not as substring).
  static bool _containsWord(String text, String word) {
    final escaped = word.replaceAllMapped(
      RegExp(r'[.*+?^${}()|[\]\\]'),
      (m) => '\\${m[0]}',
    );
    return RegExp('\\b$escaped\\b', caseSensitive: false).hasMatch(text);
  }

  static bool _looksLikeItemName(String name) {
    final trimmed = name.trim();
    if (trimmed.length < 2) return false;
    if (RegExp(r'^[\d\s.,\-:/]+$').hasMatch(trimmed)) return false;
    final lower = trimmed.toLowerCase();
    if (_labelNoise.any((kw) => _containsWord(lower, kw))) return false;
    return true;
  }

  /// Detects per-item discount mirror rows such as `DISC 20% X 1.0 2.400-`.
  /// These carry a `%` and a qty multiplier, unlike aggregated discount rows
  /// (`DISKON 5% -1.275`, `TOTAL DISCOUNT 4.600-`).
  static bool _isDiscountMirrorLine(String line, String lower) {
    if (!lower.contains('%')) return false;
    if (!RegExp(r'\bx\s*\d').hasMatch(lower)) return false;
    return _discountKeywords.any((k) => _containsWord(lower, k));
  }

  static final RegExp _itemCodeLineRegex = RegExp(
    r'^item\s*[#:]\s*([A-Za-z0-9][A-Za-z0-9\-/]*)',
    caseSensitive: false,
  );

  /// The code on an `ITEM # <code>` line, or null when the line is not one.
  static String? _itemCodeLine(String raw) {
    return _itemCodeLineRegex.firstMatch(raw)?.group(1)?.trim();
  }

  /// Picks the money token that ends the item-name prefix. Skips tokens glued
  /// to letters/dots (`T/A.25`, `2X137`) and leading pack-size integers
  /// (`FRSTEA TEH MADU 350 1 3950 3,950`) so full names are preserved.
  static ({double value, int start, int end})? _nameBoundaryToken(
    String raw,
    List<({double value, int start, int end})> tokens,
  ) {
    for (int k = 0; k < tokens.length; k++) {
      final t = tokens[k];
      final token = raw.substring(t.start, t.end);
      final formatted = RegExp(r'[.,]').hasMatch(token);
      final glued =
          t.start > 0 && RegExp(r'[A-Za-z.]').hasMatch(raw[t.start - 1]);
      final remaining = tokens.length - k;
      if (glued && !formatted) continue;
      if (!formatted && remaining > 3) continue;
      return t;
    }
    return tokens.isEmpty ? null : tokens.first;
  }

  /// Whether [name] is just a cancellation keyword (e.g. `CANCEL :`), meaning
  /// the row is a void mirror that should inherit the preceding item's name.
  static bool _isCancelOnlyName(String name) {
    var rest = name;
    for (final kw in [
      'batal',
      'cancel',
      'cancelled',
      'void',
      'retur',
      'refund',
    ]) {
      rest = rest.replaceAll(RegExp('\\b$kw\\b', caseSensitive: false), ' ');
    }
    rest = rest.replaceAll(RegExp(r'[\s:.,\-]+'), ' ').trim();
    return rest.isEmpty || !_looksLikeItemName(rest);
  }

  /// Matches a plausible calendar date anywhere in [line]. Enforces day/month
  /// validity (with US-style MM/DD swapping) and refuses money-shaped
  /// substrings like `24.000` (zero month/year) or 2-digit years before 2010.
  static _DateMatch? _matchDate(String line) {
    RegExpMatch? m = _dateRegex.firstMatch(line);
    var twoDigitYear = false;
    if (m == null) {
      m = _date2yRegex.firstMatch(line);
      twoDigitYear = m != null;
    }
    if (m == null) return null;

    int day, month, year;
    try {
      if (m.group(1) != null) {
        day = int.parse(m.group(1)!);
        month = int.parse(m.group(2)!);
        year = int.parse(m.group(3)!);
      } else {
        year = int.parse(m.group(4)!);
        month = int.parse(m.group(5)!);
        day = int.parse(m.group(6)!);
      }
    } catch (_) {
      return null;
    }

    if (twoDigitYear) {
      if (year < 10 || year > 99) return null;
      year += 2000;
    }
    if (year < 2000 || year > 2100) return null;

    if (month > 12 && day <= 12) {
      final t = month;
      month = day;
      day = t;
    }
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;

    return _DateMatch(m, day, month, year);
  }

  static bool _approx(double a, double b) {
    final diff = (a - b).abs();
    return diff <= math.max(2.0, (a.abs() + b.abs()) * 0.01);
  }

  static String _fmt(double value) {
    return value == value.truncateToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }

  // ---------------------------------------------------------------------------
  // Money parsing
  // ---------------------------------------------------------------------------

  static List<({double value, int start, int end})> _moneyTokens(String line) {
    final out = <({double value, int start, int end})>[];
    for (final match in _moneyTokenRegex.allMatches(line)) {
      final token = match.group(0)!;
      final end = match.end;
      if (end < line.length && line[end] == '%') continue;
      final value = _parseAmount(token);
      if (value == null) continue;
      if (!_isPlausibleMoney(token, value)) continue;
      out.add((value: value, start: match.start, end: end));
    }
    return out;
  }

  static double? _lineMoney(String line) {
    final tokens = _moneyTokens(line);
    if (tokens.isEmpty) return null;
    return tokens.last.value;
  }

  static bool _isPlausibleMoney(String token, double value) {
    final digits = token.replaceAll(RegExp(r'[^0-9]'), '').length;
    if (digits > 9 && !token.contains(RegExp(r'[.,]'))) return false;
    return value.abs() > 0 && value.abs() < 1e9;
  }

  /// Parses a numeric token that may use `.` or `,` as thousands/decimal
  /// separators, with optional `Rp`/`IDR`/currency symbols.
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
      final afterComma = t.split(',').last;
      if (afterComma.length >= 3) {
        t = t.replaceAll(',', '');
      } else {
        t = t.replaceAll('.', '').replaceAll(',', '.');
      }
    } else if (hasDot) {
      if (RegExp(r'^0\.\d+$').hasMatch(t)) {
        // Leading-zero decimal, e.g. 0.500 → 0.5.
      } else {
        final dots = '.'.allMatches(t).length;
        if (dots > 1 || RegExp(r'\.\d{3}(?!\d)').hasMatch(t)) {
          t = t.replaceAll('.', '');
        }
      }
    }

    final parsed = double.tryParse(t);
    if (parsed == null) return null;
    return negative ? -parsed : parsed;
  }

  /// Returns the discount amount implied by [line], or null if there is none.
  ///
  /// Picks the largest absolute numeric token in the line and skips
  /// percentages (e.g. `DISKON MEMBER 10%` yields nothing).
  static double? _discountValue(String line) {
    double? best;
    for (final match in RegExp(r'-?[\d.,]+%?').allMatches(line)) {
      final token = match.group(0)!;
      if (token.endsWith('%')) continue;
      final value = _parseAmount(token);
      if (value == null) continue;
      final abs = value.abs();
      if (best == null || abs > best) best = abs;
    }
    return best;
  }

  // ---------------------------------------------------------------------------
  // Gemini JSON
  // ---------------------------------------------------------------------------

  /// Extracts transaction data from a Gemini (or compatible) JSON response.
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
      final rawDate = data['transaction_datetime'] ??
          data['transactionDateTime'] ??
          data['datetime'] ??
          data['date'];
      if (rawDate != null) {
        try {
          parsedDate = DateTime.parse(rawDate.toString());
        } catch (_) {}
      }

      final parsedAmount = _toDouble(data['amount'] ?? data['final_total']);

      final items = <ReceiptItem>[];
      final rawItems = data['items'];
      if (rawItems is List) {
        for (final entry in rawItems) {
          if (entry is! Map) continue;
          final name =
              (entry['name'] ?? entry['description'])?.toString().trim();
          if (name == null || name.isEmpty) continue;
          final quantity = _toDouble(entry['quantity']) ?? 1;
          final unitPrice =
              _toDouble(entry['unitPrice'] ?? entry['unit_price']);
          final net =
              _toDouble(entry['net_line_total'] ?? entry['netLineTotal']);
          final total = net ??
              _toDouble(entry['total']) ??
              (unitPrice != null ? unitPrice * quantity : null);
          if (total == null) continue;

          final statusRaw = (entry['status'] ?? '').toString().toLowerCase();
          final status = statusRaw.isEmpty
              ? null
              : (['cancelled', 'cancel', 'void', 'batal', 'refund']
                      .contains(statusRaw)
                  ? ReceiptItemStatus.cancelled
                  : ReceiptItemStatus.purchased);

          items.add(
            ReceiptItem(
              name: name,
              quantity: quantity,
              unitPrice: unitPrice,
              total: total,
              itemCode: (entry['item_code'] ?? entry['itemCode'])?.toString(),
              discountAmount: _toDouble(
                entry['discount_amount'] ?? entry['discountAmount'],
              ),
              status: status,
            ),
          );
        }
      }

      return ReceiptData(
        merchant: (data['merchant'] ?? data['merchant_name'])?.toString(),
        date: parsedDate,
        amount: parsedAmount,
        items: items,
        storeAddress:
            (data['store_address'] ?? data['storeAddress'])?.toString(),
        receiptId: (data['receipt_id'] ??
                data['receiptId'] ??
                data['transaction_code'])
            ?.toString(),
        paymentMethod:
            (data['payment_method'] ?? data['paymentMethod'])?.toString(),
        subtotal: _toDouble(data['subtotal']),
        totalDiscount: _toDouble(
          data['total_discount'] ?? data['totalDiscount'],
        ),
        changeDue: _toDouble(data['change_due'] ?? data['changeDue']),
      );
    } catch (_) {
      return ReceiptData();
    }
  }

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value == null) return null;
    return double.tryParse(value.toString());
  }
}

class _HeaderScan {
  final String? merchant;
  final String? storeAddress;
  final DateTime? date;
  final String? receiptId;
  final String? paymentMethod;
  final int headerEnd;

  const _HeaderScan({
    this.merchant,
    this.storeAddress,
    this.date,
    this.receiptId,
    this.paymentMethod,
    required this.headerEnd,
  });
}

class _TotalsScan {
  final double? subtotal;
  final double? totalDiscount;
  final double taxSum;
  final double? changeDue;
  final double? amount;
  final int? totalIndex;

  double get expected => (subtotal ?? 0) - (totalDiscount ?? 0) + taxSum;

  const _TotalsScan({
    this.subtotal,
    this.totalDiscount,
    this.taxSum = 0,
    this.changeDue,
    this.amount,
    this.totalIndex,
  });
}

class _ParsedLine {
  final String name;
  final double quantity;
  final double? unitPrice;
  final double? weight;
  final double? total;

  const _ParsedLine({
    this.name = '',
    this.quantity = 1,
    this.unitPrice,
    this.weight,
    this.total,
  });
}

class _DateMatch {
  final RegExpMatch match;
  final int day;
  final int month;
  final int year;

  const _DateMatch(this.match, this.day, this.month, this.year);
}
