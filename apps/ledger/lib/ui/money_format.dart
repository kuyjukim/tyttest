import 'package:intl/intl.dart';

import '../domain/money.dart';

/// Formats [Money] for display.
///
/// The minor-unit integer is only turned into a fraction here, at the very
/// edge, and never read back into an amount. Everything upstream stays
/// integer arithmetic.
class MoneyFormat {
  MoneyFormat({required this.locale, required this.currency})
    : _full = NumberFormat.currency(
        locale: locale,
        symbol: currency.symbol,
        decimalDigits: currency.digits,
      ),
      _plain = NumberFormat.decimalPattern(locale);

  final String locale;
  final Currency currency;

  final NumberFormat _full;
  final NumberFormat _plain;

  double _major(Money amount) => amount.minor / currency.scale;

  /// `₩150,000`, `$1,500.00`.
  String format(Money amount) => _full.format(_major(amount));

  /// The number without its symbol, for a text field's initial value.
  String bare(Money amount) => currency.digits == 0
      ? _plain.format(amount.minor)
      : _major(amount).toStringAsFixed(currency.digits);

  /// `+₩10,000` for money coming back, `-₩5,000` for money going out.
  ///
  /// An explicit plus matters in a transaction list: without it a refund and
  /// a purchase look the same at a glance, which is exactly the confusion a
  /// budget app must not create.
  String signed(Money amount) {
    final text = format(amount.abs);
    if (amount.isZero) return text;
    return amount.isNegative ? '-$text' : '+$text';
  }

  /// Short form for chart labels: `₩1.2M`, `₩150k`.
  ///
  /// Hand-rolled rather than `NumberFormat.compactCurrency`, which renders
  /// won as `₩15만` in Korean - correct, but it will not fit under a bar.
  String compact(Money amount) {
    final major = _major(amount).abs();
    final sign = amount.isNegative ? '-' : '';
    final String body;
    if (major >= 1000000) {
      body = '${_trim(major / 1000000)}M';
    } else if (major >= 1000) {
      body = '${_trim(major / 1000)}k';
    } else {
      body = currency.digits == 0
          ? major.round().toString()
          : major.toStringAsFixed(currency.digits);
    }
    return '$sign${currency.symbol}$body';
  }

  /// One decimal below ten, none above, and no trailing `.0`.
  static String _trim(double value) {
    if (value >= 10) return value.round().toString();
    final text = value.toStringAsFixed(1);
    return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  }
}
