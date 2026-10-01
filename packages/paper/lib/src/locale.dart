import 'package:flutter/widgets.dart';

/// The locale a widget should format dates and numbers for.
///
/// Exists because the mistake it prevents is invisible until someone runs the
/// app in another language: `DateFormat.yMMMM()` with no argument formats for
/// `Intl.defaultLocale`, which is not the app's locale and is usually
/// `en_US`. The result is a fully translated screen with its dates in
/// English, which reads as a half-finished app.
///
/// Every `DateFormat` and `NumberFormat` in this suite takes its locale from
/// here.
extension PaperLocale on BuildContext {
  /// BCP 47 tag of the nearest [Localizations], e.g. `ko` or `en`.
  String get localeTag => Localizations.localeOf(this).toLanguageTag();
}
