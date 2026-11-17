import 'dart:ui' show PlatformDispatcher;

import 'package:intl/intl.dart';

/// Amounts of money as the reader's currency writes them.
///
/// Prices are stored as plain numbers: the app keeps one currency for every
/// book, chosen in Settings, and never converts between them.
class Money {
  Money._();

  /// The currencies offered in Settings, by ISO code, most used first.
  static const codes = [
    'USD', 'EUR', 'GBP', 'CAD', 'AUD', 'JPY', 'INR', 'BRL', 'MXN', 'CHF',
    'SEK', 'NOK', 'DKK', 'PLN', 'CZK', 'HUF', 'TRY', 'NZD', 'ZAR', 'KRW',
    'CNY', 'SGD', 'HKD', 'PHP', 'IDR', 'ARS',
  ];

  /// The currency of the device's region, if it is one of [codes] — the
  /// starting point before the reader has picked one.
  static String deviceDefault() {
    try {
      final locale = PlatformDispatcher.instance.locale.toString();
      final code = NumberFormat.simpleCurrency(locale: locale).currencyName;
      if (code != null && codes.contains(code)) return code;
    } catch (_) {
      // An unusual locale intl has no data for; fall through.
    }
    return 'USD';
  }

  /// "$", "€", "£" — what stands in front of an amount field.
  static String symbol(String code) =>
      NumberFormat.simpleCurrency(name: code).currencySymbol;

  /// "$12.99". With [whole], rounded to the unit — "$1,240" — for totals,
  /// where the cents are noise.
  static String format(num amount, String code, {bool whole = false}) {
    final format = NumberFormat.simpleCurrency(
      name: code,
      decimalDigits: whole ? 0 : null,
    );
    return format.format(amount);
  }

  /// What the reader typed in an amount field, or null if it is empty or not
  /// a number. A comma is taken as the decimal mark, as much of the world
  /// writes it.
  static double? parse(String text) {
    final cleaned = text.trim().replaceAll(',', '.');
    if (cleaned.isEmpty) return null;
    final value = double.tryParse(cleaned);
    return value == null || value < 0 ? null : value;
  }

  /// An amount as it goes back into a field: no trailing ".0", two places
  /// when there are cents.
  static String forField(num? amount) {
    if (amount == null) return '';
    return amount == amount.roundToDouble()
        ? amount.toStringAsFixed(0)
        : amount.toStringAsFixed(2);
  }
}
