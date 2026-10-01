/// A currency, with the number of decimal places it is actually written in.
///
/// The digit count is the whole reason this type exists. Most budget apps
/// hard-code two decimal places, which is wrong for a great many currencies -
/// won, yen and franc CFA have none, and a dinar has three. Getting it wrong
/// means either showing `₩1,500.00`, which no Korean user has ever written,
/// or storing won as hundredths and rounding real money away.
class Currency implements Comparable<Currency> {
  const Currency({
    required this.code,
    required this.symbol,
    required this.digits,
    this.symbolLeads = true,
  });

  static const Currency krw = Currency(code: 'KRW', symbol: '₩', digits: 0);
  static const Currency jpy = Currency(code: 'JPY', symbol: '¥', digits: 0);
  static const Currency usd = Currency(code: 'USD', symbol: r'$', digits: 2);
  static const Currency eur = Currency(code: 'EUR', symbol: '€', digits: 2);
  static const Currency gbp = Currency(code: 'GBP', symbol: '£', digits: 2);
  static const Currency bhd = Currency(code: 'BHD', symbol: '.د.ب', digits: 3);

  /// The currencies the picker offers. Not an exhaustive list of money.
  static const List<Currency> known = <Currency>[krw, jpy, usd, eur, gbp, bhd];

  final String code;
  final String symbol;

  /// Decimal places: 0 for won, 2 for dollars, 3 for dinars.
  final int digits;

  final bool symbolLeads;

  /// Minor units in one major unit: 1, 100, or 1000.
  int get scale {
    var value = 1;
    for (var i = 0; i < digits; i++) {
      value *= 10;
    }
    return value;
  }

  static Currency byCode(String? code) {
    for (final currency in known) {
      if (currency.code == code) return currency;
    }
    return krw;
  }

  @override
  int compareTo(Currency other) => code.compareTo(other.code);

  @override
  bool operator ==(Object other) => other is Currency && other.code == code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => code;
}

/// Thrown when two amounts in different currencies are combined.
class CurrencyMismatch implements Exception {
  const CurrencyMismatch(this.left, this.right);

  final Currency left;
  final Currency right;

  @override
  String toString() =>
      'CurrencyMismatch: cannot combine $left with $right';
}

/// An amount of money, held as a whole number of minor units.
///
/// Never a double. `0.1 + 0.2` is not `0.3` in binary floating point, and a
/// budget app's entire job is adding up small numbers and comparing the total
/// to another number. Every operation here is integer arithmetic, and the
/// only place a fraction appears is [fractionOf], which returns a ratio for
/// drawing a bar and is never fed back into an amount.
class Money implements Comparable<Money> {
  const Money(this.minor, this.currency);

  /// Builds an amount from major units, e.g. `Money.major(12, 50, usd)` for
  /// $12.50. `minor` is in minor units and may exceed one major unit.
  factory Money.major(int major, int minor, Currency currency) =>
      Money(major * currency.scale + minor, currency);

  /// Parses what a user typed: `1234`, `1,234`, `12.50`, `₩3 000`.
  ///
  /// Returns null rather than throwing, because this runs on every keystroke
  /// of a text field. A value with more decimals than the currency has is
  /// rejected rather than rounded: silently turning `12.567` into `12.57`
  /// hides a typo in exactly the place it matters.
  static Money? tryParse(String input, Currency currency) {
    var text = input.trim();
    if (text.isEmpty) return null;

    var negative = false;
    if (text.startsWith('-')) {
      negative = true;
      text = text.substring(1).trim();
    }

    // Strip grouping separators, spaces and any currency symbol.
    text = text.replaceAll(RegExp(r'[\s,_]'), '');
    if (text.startsWith(currency.symbol)) {
      text = text.substring(currency.symbol.length);
    }
    if (text.isEmpty) return null;

    final parts = text.split('.');
    if (parts.length > 2) return null;
    if (!RegExp(r'^\d+$').hasMatch(parts[0])) return null;

    final major = int.tryParse(parts[0]);
    if (major == null) return null;

    var minorPart = 0;
    if (parts.length == 2) {
      final fraction = parts[1];
      if (currency.digits == 0) return null;
      if (fraction.isEmpty || !RegExp(r'^\d+$').hasMatch(fraction)) return null;
      if (fraction.length > currency.digits) return null;
      // `12.5` in a two-digit currency is 12.50, not 12.05.
      final padded = fraction.padRight(currency.digits, '0');
      minorPart = int.parse(padded);
    }

    final total = major * currency.scale + minorPart;
    return Money(negative ? -total : total, currency);
  }

  static Money zeroIn(Currency currency) => Money(0, currency);

  /// Whole number of minor units: 1500 for ₩1,500, 1250 for $12.50.
  final int minor;

  final Currency currency;

  bool get isZero => minor == 0;
  bool get isNegative => minor < 0;
  bool get isPositive => minor > 0;

  Money get abs => minor < 0 ? Money(-minor, currency) : this;
  Money operator -() => Money(-minor, currency);

  Money operator +(Money other) {
    _requireSame(other);
    return Money(minor + other.minor, currency);
  }

  Money operator -(Money other) {
    _requireSame(other);
    return Money(minor - other.minor, currency);
  }

  /// Whole multiples only. Scaling by a rate belongs in [allocate], which
  /// cannot lose or invent a minor unit.
  Money operator *(int factor) => Money(minor * factor, currency);

  bool operator <(Money other) => compareTo(other) < 0;
  bool operator <=(Money other) => compareTo(other) <= 0;
  bool operator >(Money other) => compareTo(other) > 0;
  bool operator >=(Money other) => compareTo(other) >= 0;

  /// This amount as a fraction of [whole], for drawing a progress bar.
  ///
  /// Zero when [whole] is zero, so a bar for an unfunded envelope renders
  /// empty instead of dividing by zero.
  double fractionOf(Money whole) {
    _requireSame(whole);
    if (whole.minor == 0) return 0;
    return minor / whole.minor;
  }

  /// Splits this amount into parts in the given [ratios], losing nothing.
  ///
  /// The remainder after integer division is handed out one minor unit at a
  /// time, largest fractional part first, so the parts always sum back to the
  /// original to the last won. Rounding each part independently - the obvious
  /// implementation - leaves the user looking at a split that is a unit or
  /// two off from the total, which reads as a bug in the app's arithmetic
  /// because it is one.
  List<Money> allocate(List<int> ratios) {
    if (ratios.isEmpty) return const <Money>[];
    if (ratios.any((r) => r < 0)) {
      throw ArgumentError.value(ratios, 'ratios', 'must not be negative');
    }
    final total = ratios.fold<int>(0, (sum, r) => sum + r);
    if (total == 0) {
      // Nothing to weight by: split as evenly as possible instead of
      // throwing, since "share this between these envelopes" is still a
      // sensible request when none of them has an allocation yet.
      return allocate(List<int>.filled(ratios.length, 1));
    }

    // Work on the magnitude so that a negative amount distributes its
    // remainder the same way a positive one does.
    final sign = minor < 0 ? -1 : 1;
    final amount = minor.abs();

    final base = <int>[];
    final remainders = <(int index, int remainder)>[];
    var handedOut = 0;
    for (var i = 0; i < ratios.length; i++) {
      final exact = amount * ratios[i];
      final share = exact ~/ total;
      base.add(share);
      handedOut += share;
      remainders.add((i, exact % total));
    }

    var left = amount - handedOut;
    // Largest remainder first; ties go to the earlier envelope so the result
    // is deterministic rather than dependent on sort stability.
    remainders.sort((a, b) {
      final byRemainder = b.$2.compareTo(a.$2);
      return byRemainder != 0 ? byRemainder : a.$1.compareTo(b.$1);
    });
    for (final entry in remainders) {
      if (left <= 0) break;
      base[entry.$1] += 1;
      left--;
    }

    return <Money>[for (final part in base) Money(sign * part, currency)];
  }

  /// Sums [amounts], which must all be in [currency].
  static Money sum(Iterable<Money> amounts, Currency currency) {
    var total = 0;
    for (final amount in amounts) {
      if (amount.currency != currency) {
        throw CurrencyMismatch(currency, amount.currency);
      }
      total += amount.minor;
    }
    return Money(total, currency);
  }

  void _requireSame(Money other) {
    if (other.currency != currency) {
      throw CurrencyMismatch(currency, other.currency);
    }
  }

  @override
  int compareTo(Money other) {
    _requireSame(other);
    return minor.compareTo(other.minor);
  }

  @override
  bool operator ==(Object other) =>
      other is Money && other.minor == minor && other.currency == currency;

  @override
  int get hashCode => Object.hash(minor, currency);

  /// Plain, locale-independent form, for logs and tests. The UI formats
  /// through `intl` instead.
  @override
  String toString() {
    if (currency.digits == 0) return '${currency.symbol}$minor';
    final sign = minor < 0 ? '-' : '';
    final magnitude = minor.abs();
    final major = magnitude ~/ currency.scale;
    final fraction = (magnitude % currency.scale)
        .toString()
        .padLeft(currency.digits, '0');
    return '$sign${currency.symbol}$major.$fraction';
  }
}
