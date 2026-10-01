import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Delegate for a hand-written localisation class.
///
/// These apps use hand-written `abstract class` string tables with one
/// implementation per language rather than ARB files and `gen_l10n`. The
/// trade is deliberate:
///
/// * a missing translation becomes a *compile* error rather than a key that
///   silently falls back at runtime, which is the failure mode that actually
///   ships; and
/// * there is no codegen step, so `flutter test` on a clean checkout needs no
///   build_runner pass.
///
/// What is given up is the translator-facing tooling around ARB. For a suite
/// of two languages maintained by the people writing the UI, that is a trade
/// worth making; past a handful of locales it is not, and this delegate is
/// small enough to replace when that day comes.
///
/// ```dart
/// static const delegate = HandwrittenStrings<AppStrings>({
///   'en': EnglishStrings.new,
///   'ko': KoreanStrings.new,
/// });
/// ```
class HandwrittenStrings<T> extends LocalizationsDelegate<T> {
  const HandwrittenStrings(this.builders);

  /// Language code to a factory for that language's table.
  final Map<String, T Function()> builders;

  /// Pass to `MaterialApp.supportedLocales`.
  List<Locale> get supportedLocales =>
      builders.keys.map(Locale.new).toList(growable: false);

  @override
  bool isSupported(Locale locale) => builders.containsKey(locale.languageCode);

  @override
  Future<T> load(Locale locale) {
    final build = builders[locale.languageCode];
    if (build == null) {
      throw FlutterError(
        'HandwrittenStrings was asked for "${locale.languageCode}", which it '
        'does not support. Keep MaterialApp.supportedLocales in sync with '
        'this delegate by passing `delegate.supportedLocales`.',
      );
    }
    // Synchronous so the first frame already has the right language; an async
    // load would flash the fallback locale.
    return SynchronousFuture<T>(build());
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<T> old) => false;
}

/// The app's own string table plus the three SDK delegates.
///
/// Forgetting the SDK delegates is the standard localisation bug: the app's
/// own copy translates, while every stock Material affordance - the text
/// selection menu, date pickers, scrollbar semantics - stays in English, and
/// in debug builds Flutter only warns.
List<LocalizationsDelegate<Object?>> localizationDelegates(
  LocalizationsDelegate<Object?> table,
) => <LocalizationsDelegate<Object?>>[
  table,
  GlobalMaterialLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
];
