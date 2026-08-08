import 'package:flutter_test/flutter_test.dart';

import 'package:uangku/core/utils/money_format.dart';

void main() {
  test('renders full format below 1000', () {
    final format = moneyFormat('\$');
    expect(format.format(0), '\$0.00');
    expect(format.format(1), '\$1.00');
    expect(format.format(99.9), '\$99.90');
    expect(format.format(999), '\$999');
  });

  test('compacts thousands with K', () {
    final format = moneyFormat('\$');
    expect(format.format(1000), '\$1K');
    expect(format.format(1234), '\$1.23K');
    expect(format.format(12345), '\$12.3K');
    expect(format.format(123456), '\$123K');
  });

  test('compacts millions and billions with M/B', () {
    final format = moneyFormat('\$');
    expect(format.format(1234567), '\$1.23M');
    expect(format.format(12345678), '\$12.3M');
    expect(format.format(1234567890), '\$1.23B');
  });

  test('uses English K/M suffixes for every currency symbol', () {
    expect(moneyFormat('Rp').format(1234), 'Rp1.23K');
    expect(moneyFormat('€').format(1234), '€1.23K');
    expect(moneyFormat('£').format(1234567), '£1.23M');
  });

  test('handles negative and over-budget values', () {
    final format = moneyFormat('\$');
    expect(format.format(-1234), '-\$1.23K');
    expect(format.format(-1000), '-\$1K');
  });
}
