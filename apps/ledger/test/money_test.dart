import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/domain/money.dart';

void main() {
  const krw = Currency.krw;
  const usd = Currency.usd;
  const bhd = Currency.bhd;

  group('Currency', () {
    test('scale follows the digit count', () {
      expect(krw.scale, 1);
      expect(usd.scale, 100);
      expect(bhd.scale, 1000);
    });

    test('byCode falls back rather than throwing on a stored unknown', () {
      expect(Currency.byCode('USD'), usd);
      expect(Currency.byCode('XYZ'), krw);
      expect(Currency.byCode(null), krw);
    });
  });

  group('construction', () {
    test('major combines whole and minor units', () {
      expect(Money.major(12, 50, usd).minor, 1250);
      expect(Money.major(1500, 0, krw).minor, 1500);
      expect(Money.major(1, 250, bhd).minor, 1250);
    });

    test('toString writes the right number of decimals per currency', () {
      expect(const Money(1500, krw).toString(), '₩1500');
      expect(const Money(1250, usd).toString(), r'$12.50');
      expect(const Money(1205, usd).toString(), r'$12.05');
      expect(const Money(-1250, usd).toString(), r'-$12.50');
      expect(const Money(1, bhd).toString(), '.د.ب0.001');
    });
  });

  group('arithmetic', () {
    test('adds, subtracts and negates exactly', () {
      const a = Money(1050, usd);
      const b = Money(275, usd);
      expect((a + b).minor, 1325);
      expect((a - b).minor, 775);
      expect((b - a).minor, -775);
      expect((-a).minor, -1050);
      expect(a.abs.minor, 1050);
      expect((-a).abs.minor, 1050);
    });

    test('the classic floating-point trap stays exact', () {
      // 0.1 + 0.2 != 0.3 in binary floating point. Ten dimes are a dollar
      // here because none of this is floating point.
      var total = const Money(0, usd);
      for (var i = 0; i < 10; i++) {
        total += const Money(10, usd);
      }
      expect(total, const Money(100, usd));

      var pennies = const Money(0, usd);
      for (var i = 0; i < 300; i++) {
        pennies += const Money(1, usd);
      }
      expect(pennies, const Money(300, usd));
    });

    test('multiplies by whole factors', () {
      expect((const Money(1500, krw) * 3).minor, 4500);
      expect((const Money(1500, krw) * 0).minor, 0);
      expect((const Money(1500, krw) * -2).minor, -3000);
    });

    test('refuses to mix currencies', () {
      const won = Money(1000, krw);
      const dollars = Money(1000, usd);
      expect(() => won + dollars, throwsA(isA<CurrencyMismatch>()));
      expect(() => won - dollars, throwsA(isA<CurrencyMismatch>()));
      expect(() => won.compareTo(dollars), throwsA(isA<CurrencyMismatch>()));
      expect(
        () => won.fractionOf(dollars),
        throwsA(isA<CurrencyMismatch>()),
      );
      expect(
        () => Money.sum(<Money>[won, dollars], krw),
        throwsA(isA<CurrencyMismatch>()),
      );
    });

    test('compares and sorts', () {
      final amounts = <Money>[
        const Money(300, usd),
        const Money(-100, usd),
        const Money(0, usd),
        const Money(100, usd),
      ]..sort();
      expect(amounts.map((m) => m.minor), <int>[-100, 0, 100, 300]);

      expect(const Money(100, usd) < const Money(200, usd), isTrue);
      expect(const Money(200, usd) >= const Money(200, usd), isTrue);
      expect(const Money(200, usd) > const Money(200, usd), isFalse);
    });

    test('equality is by amount and currency together', () {
      expect(const Money(100, usd), const Money(100, usd));
      expect(const Money(100, usd), isNot(const Money(100, Currency.eur)));
      // Built from a list so the literal is not two identical constants,
      // which the analyzer rightly flags; the point is the hashing.
      final duplicates = <Money>[
        const Money(100, usd),
        const Money(50, usd) + const Money(50, usd),
      ];
      expect(duplicates.toSet().length, 1);
    });

    test('sum of nothing is zero in the asked-for currency', () {
      expect(Money.sum(const <Money>[], krw), const Money(0, krw));
    });
  });

  group('fractionOf', () {
    test('is a plain ratio and never divides by zero', () {
      expect(const Money(50, usd).fractionOf(const Money(200, usd)), 0.25);
      expect(const Money(300, usd).fractionOf(const Money(200, usd)), 1.5);
      expect(
        const Money(50, usd).fractionOf(const Money(0, usd)),
        0,
        reason: 'an unfunded envelope draws an empty bar, not a crash',
      );
    });
  });

  group('allocate', () {
    test('splits evenly when it divides', () {
      final parts = const Money(900, krw).allocate(<int>[1, 1, 1]);
      expect(parts.map((m) => m.minor), <int>[300, 300, 300]);
    });

    test('loses nothing when it does not divide', () {
      // The classic: 100 split three ways. Rounding each part independently
      // gives 33/33/33 and loses a unit.
      final parts = const Money(100, krw).allocate(<int>[1, 1, 1]);
      expect(parts.map((m) => m.minor), <int>[34, 33, 33]);
      expect(Money.sum(parts, krw), const Money(100, krw));
    });

    test('respects weights', () {
      final parts = const Money(1000, krw).allocate(<int>[7, 2, 1]);
      expect(parts.map((m) => m.minor), <int>[700, 200, 100]);
      expect(Money.sum(parts, krw), const Money(1000, krw));
    });

    test('hands the remainder to the largest fractional parts', () {
      // 10 by 3:3:1 over a total of 7 gives exact shares of 30/7, 30/7 and
      // 10/7, i.e. 4, 4 and 1 with remainders 2, 2 and 3. The spare unit goes
      // to the largest remainder, which is the *smallest* envelope - so the
      // answer is [4, 4, 2], not the [5, 4, 1] that weighting intuition
      // suggests.
      final parts = const Money(10, krw).allocate(<int>[3, 3, 1]);
      expect(Money.sum(parts, krw), const Money(10, krw));
      expect(parts.map((m) => m.minor), <int>[4, 4, 2]);
    });

    test('is deterministic when remainders tie', () {
      for (var i = 0; i < 20; i++) {
        expect(
          const Money(100, krw).allocate(<int>[1, 1, 1]).map((m) => m.minor),
          <int>[34, 33, 33],
        );
      }
    });

    test('never loses a unit, over a wide sweep', () {
      for (var amount = 0; amount < 200; amount++) {
        for (final ratios in <List<int>>[
          <int>[1, 1, 1],
          <int>[1, 2, 3, 4],
          <int>[5, 1],
          <int>[1, 1, 1, 1, 1, 1, 1],
          <int>[9, 0, 1],
        ]) {
          final parts = Money(amount, krw).allocate(ratios);
          expect(
            Money.sum(parts, krw),
            Money(amount, krw),
            reason: 'splitting $amount by $ratios',
          );
          expect(parts.length, ratios.length);
        }
      }
    });

    test('handles a negative amount without losing a unit', () {
      final parts = const Money(-100, krw).allocate(<int>[1, 1, 1]);
      expect(Money.sum(parts, krw), const Money(-100, krw));
      expect(parts.every((m) => m.minor <= 0), isTrue);
    });

    test('a zero ratio gets nothing, unless every ratio is zero', () {
      expect(
        const Money(100, krw).allocate(<int>[1, 0]).map((m) => m.minor),
        <int>[100, 0],
      );
      // All-zero means "no weights given", which is still a sensible ask.
      final even = const Money(100, krw).allocate(<int>[0, 0, 0]);
      expect(Money.sum(even, krw), const Money(100, krw));
      expect(even.map((m) => m.minor), <int>[34, 33, 33]);
    });

    test('an empty ratio list yields nothing', () {
      expect(const Money(100, krw).allocate(const <int>[]), isEmpty);
    });

    test('rejects a negative ratio', () {
      expect(
        () => const Money(100, krw).allocate(<int>[1, -1]),
        throwsArgumentError,
      );
    });
  });

  group('tryParse', () {
    test('reads plain and grouped digits', () {
      expect(Money.tryParse('1500', krw), const Money(1500, krw));
      expect(Money.tryParse('1,500', krw), const Money(1500, krw));
      expect(Money.tryParse('1 500', krw), const Money(1500, krw));
      expect(Money.tryParse('  1500  ', krw), const Money(1500, krw));
      expect(Money.tryParse('₩1500', krw), const Money(1500, krw));
    });

    test('reads decimals for a currency that has them', () {
      expect(Money.tryParse('12.50', usd), const Money(1250, usd));
      expect(Money.tryParse('12.5', usd), const Money(1250, usd));
      expect(Money.tryParse('0.05', usd), const Money(5, usd));
      expect(Money.tryParse('12', usd), const Money(1200, usd));
      expect(Money.tryParse('1.001', bhd), const Money(1001, bhd));
    });

    test('refuses a decimal point in a zero-digit currency', () {
      expect(
        Money.tryParse('1500.5', krw),
        isNull,
        reason: 'there is no such thing as half a won',
      );
    });

    test('refuses more decimals than the currency has', () {
      expect(
        Money.tryParse('12.567', usd),
        isNull,
        reason: 'rounding a typo away hides it exactly where it matters',
      );
      expect(Money.tryParse('1.0001', bhd), isNull);
    });

    test('reads a negative amount', () {
      expect(Money.tryParse('-1500', krw), const Money(-1500, krw));
      expect(Money.tryParse('- 12.50', usd), const Money(-1250, usd));
    });

    test('returns null for anything that is not an amount', () {
      for (final input in <String>[
        '',
        '   ',
        'abc',
        '12abc',
        '.',
        '.5',
        '1.2.3',
        '-',
        '--5',
        '+5',
        '1e5',
      ]) {
        expect(
          Money.tryParse(input, usd),
          isNull,
          reason: 'should reject "$input"',
        );
      }
    });

    test('round-trips what a user is likely to type', () {
      for (final amount in <Money>[
        const Money(0, usd),
        const Money(5, usd),
        const Money(1250, usd),
        const Money(-1250, usd),
        const Money(123456789, usd),
      ]) {
        final text = amount.toString().replaceAll(usd.symbol, '');
        expect(Money.tryParse(text, usd), amount, reason: text);
      }
    });
  });
}
