import 'package:intl/intl.dart';

/// Returns a currency formatter that uses compact notation (K/M/B/T) for
/// values of 1,000 and above, always with English suffixes regardless of the
/// selected currency symbol. Sub-1,000 values render in full.
///
/// Compact values use two significant figures (e.g. `$1.23K`, `$12.3K`), and
/// values just below 1,000 may round up to `$1K`.
NumberFormat moneyFormat(String symbol) {
  return NumberFormat.compactCurrency(locale: 'en_US', symbol: symbol);
}
