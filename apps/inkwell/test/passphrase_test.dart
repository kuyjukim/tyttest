import 'package:flutter_test/flutter_test.dart';
import 'package:inkwell/domain/passphrase.dart';

void main() {
  group('Passphrase.rate', () {
    test('refuses anything under the minimum length', () {
      for (final short in <String>['', 'a', 'abc', 'x' * 9]) {
        expect(Passphrase.rate(short), PassphraseStrength.tooShort);
        expect(Passphrase.rate(short).isAcceptable, isFalse);
      }
      expect(
        Passphrase.rate('x' * Passphrase.minimumLength),
        isNot(PassphraseStrength.tooShort),
      );
    });

    test('a long passphrase of random words rates well', () {
      expect(
        Passphrase.rate('correct horse battery staple'),
        anyOf(PassphraseStrength.good, PassphraseStrength.strong),
      );
    });

    test('a long run of one character is not treated as long', () {
      expect(Passphrase.rate('aaaaaaaaaaaaaaaaaaaa'), PassphraseStrength.weak);
      expect(
        Passphrase.bits('aaaaaaaaaaaaaaaaaaaa'),
        lessThan(Passphrase.bits('tuesday afternoon rain')),
      );
    });

    test('a repeated block is weaker than it looks', () {
      expect(
        Passphrase.bits('abcabcabcabcabcabc'),
        lessThan(Passphrase.bits('abcdefghijklmnopqr')),
      );
    });

    test('a short Korean phrase is not under-rated', () {
      // Hangul draws from a much larger alphabet per character, so a phrase
      // this length is stronger than the same number of Latin letters.
      expect(
        Passphrase.bits('열려라참깨보물창고'),
        greaterThan(Passphrase.bits('opensesame')),
      );
    });

    test('character-class tricks do not beat length', () {
      // The point of not using a checklist: this is the password every
      // "must contain a symbol" rule produces, and it is not good.
      expect(
        Passphrase.bits('Password1!'),
        lessThan(Passphrase.bits('the slow green kettle')),
      );
    });

    test('bits grows with length for the same alphabet', () {
      var previous = 0.0;
      for (final length in <int>[10, 14, 20, 26]) {
        final value = Passphrase.bits(
          'abcdefghijklmnopqrstuvwxyz'.substring(0, length),
        );
        expect(value, greaterThan(previous));
        previous = value;
      }
    });

    test('meter stays inside 0..1 for anything', () {
      for (final input in <String>['', 'short', 'a' * 500, '🔐' * 40]) {
        final value = Passphrase.meter(input);
        expect(value, inInclusiveRange(0, 1));
      }
    });

    test('bits is zero only for the empty string', () {
      expect(Passphrase.bits(''), 0);
      expect(Passphrase.bits(' '), greaterThan(0));
    });
  });
}
