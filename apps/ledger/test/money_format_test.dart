import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/domain/money.dart';
import 'package:ledger/ui/money_format.dart';

void main() {
  final korean = MoneyFormat(locale: 'ko', currency: Currency.krw);
  final american = MoneyFormat(locale: 'en_US', currency: Currency.usd);

  group('format', () {
    test('writes won with no decimals and dollars with two', () {
      expect(korean.format(const Money(150000, Currency.krw)), '₩150,000');
      expect(american.format(const Money(150000, Currency.usd)), r'$1,500.00');
      expect(american.format(const Money(5, Currency.usd)), r'$0.05');
    });

    test('writes zero rather than an empty string', () {
      expect(korean.format(const Money(0, Currency.krw)), '₩0');
    });
  });

  group('signed', () {
    test('marks money in and money out differently', () {
      expect(korean.signed(const Money(-5000, Currency.krw)), '-₩5,000');
      expect(
        korean.signed(const Money(10000, Currency.krw)),
        '+₩10,000',
        reason: 'without the plus a refund reads as a purchase',
      );
      expect(korean.signed(const Money(0, Currency.krw)), '₩0');
    });
  });

  group('bare', () {
    test('drops the symbol so it can seed a text field', () {
      expect(korean.bare(const Money(150000, Currency.krw)), '150,000');
      expect(american.bare(const Money(1250, Currency.usd)), '12.50');
    });

    test('round-trips through tryParse', () {
      for (final amount in <Money>[
        const Money(0, Currency.krw),
        const Money(1500, Currency.krw),
        const Money(1234567, Currency.krw),
      ]) {
        expect(Money.tryParse(korean.bare(amount), Currency.krw), amount);
      }
      for (final amount in <Money>[
        const Money(5, Currency.usd),
        const Money(1250, Currency.usd),
        const Money(9999999, Currency.usd),
      ]) {
        expect(Money.tryParse(american.bare(amount), Currency.usd), amount);
      }
    });
  });

  group('compact', () {
    test('shortens amounts enough to fit under a bar', () {
      expect(korean.compact(const Money(150000, Currency.krw)), '₩150k');
      expect(korean.compact(const Money(1200000, Currency.krw)), '₩1.2M');
      expect(korean.compact(const Money(12000000, Currency.krw)), '₩12M');
      expect(korean.compact(const Money(900, Currency.krw)), '₩900');
      expect(korean.compact(const Money(-150000, Currency.krw)), '-₩150k');
      expect(korean.compact(const Money(0, Currency.krw)), '₩0');
    });

    test('drops a trailing .0', () {
      expect(korean.compact(const Money(2000000, Currency.krw)), '₩2M');
      expect(korean.compact(const Money(5000, Currency.krw)), '₩5k');
    });

    test('keeps decimals for a two-digit currency under a thousand', () {
      expect(american.compact(const Money(1250, Currency.usd)), r'$12.50');
    });
  });
}
