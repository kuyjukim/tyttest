import 'dart:math' as math;

/// How strong a candidate passphrase looks.
enum PassphraseStrength {
  tooShort,
  weak,
  fair,
  good,
  strong;

  /// Whether a vault may be created with this.
  ///
  /// Only the shortest band is refused. Beyond that the user is informed and
  /// then trusted: a journal locked behind a passphrase its owner cannot
  /// remember is worse than one behind a mediocre passphrase, because there
  /// is no reset link and no support queue to recover it.
  bool get isAcceptable => this != PassphraseStrength.tooShort;
}

/// A rough estimate of how hard a passphrase would be to guess.
///
/// Deliberately not a character-class checklist ("must contain a digit"):
/// those rules push people toward `Password1!`, which is weaker than
/// `four random uncommon words` and far harder to remember. Length
/// dominates here, as it does in reality, and the penalties target the
/// specific shapes that make a long string much weaker than its length
/// suggests.
abstract final class Passphrase {
  /// Shortest passphrase the app will accept.
  static const int minimumLength = 10;

  /// An estimate of guessing entropy, in bits.
  ///
  /// This is an approximation, not a measurement - a real estimator needs a
  /// dictionary, which would mean shipping one and still being wrong about
  /// Korean. It is good enough to tell a user that `aaaaaaaaaaaa` is not
  /// twelve characters of strength.
  static double bits(String passphrase) {
    if (passphrase.isEmpty) return 0;

    final runes = passphrase.runes.toList();
    var classes = 0;
    var hasLower = false;
    var hasUpper = false;
    var hasDigit = false;
    var hasSymbol = false;
    var hasNonLatin = false;

    for (final rune in runes) {
      if (rune >= 0x61 && rune <= 0x7A) {
        hasLower = true;
      } else if (rune >= 0x41 && rune <= 0x5A) {
        hasUpper = true;
      } else if (rune >= 0x30 && rune <= 0x39) {
        hasDigit = true;
      } else if (rune < 0x80) {
        hasSymbol = true;
      } else {
        hasNonLatin = true;
      }
    }
    if (hasLower) classes += 26;
    if (hasUpper) classes += 26;
    if (hasDigit) classes += 10;
    if (hasSymbol) classes += 32;
    // Hangul, kana and CJK draw from a far larger set per character, which is
    // why a short Korean phrase is not as weak as its length looks.
    if (hasNonLatin) classes += 2000;

    final alphabet = classes < 2 ? 2 : classes;
    final raw = runes.length * (math.log(alphabet) / math.ln2);

    // Distinct runes, as a fraction. `aaaaaaaaaa` scores a tenth of its
    // nominal entropy; a phrase with ordinary repetition is barely touched.
    final distinct = runes.toSet().length / runes.length;
    final repetition = 0.35 + 0.65 * distinct;

    // A single repeated block ("abcabcabc") is weaker still.
    final patterned = _hasShortCycle(runes) ? 0.5 : 1.0;

    return raw * repetition * patterned;
  }

  static PassphraseStrength rate(String passphrase) {
    if (passphrase.runes.length < minimumLength) {
      return PassphraseStrength.tooShort;
    }
    final entropy = bits(passphrase);
    if (entropy < 45) return PassphraseStrength.weak;
    if (entropy < 70) return PassphraseStrength.fair;
    if (entropy < 100) return PassphraseStrength.good;
    return PassphraseStrength.strong;
  }

  /// 0..1, for the strength meter.
  static double meter(String passphrase) =>
      (bits(passphrase) / 120).clamp(0.0, 1.0);

  /// True when the whole string is one short block repeated.
  static bool _hasShortCycle(List<int> runes) {
    for (var period = 1; period <= runes.length ~/ 3; period++) {
      if (runes.length % period != 0) continue;
      var cyclic = true;
      for (var i = period; i < runes.length && cyclic; i++) {
        if (runes[i] != runes[i - period]) cyclic = false;
      }
      if (cyclic) return true;
    }
    return false;
  }
}
