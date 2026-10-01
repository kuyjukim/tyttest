/// Shared design system for the tyttest app suite.
///
/// Four separate paid apps are built on this package. It carries the tokens,
/// the themes, the motion rules, a small set of primitive widgets, a
/// validated chart palette, a pluggable key-value store and a one-file
/// substitute for a state-management dependency.
///
/// It intentionally depends on nothing but Flutter, so every part of it can be
/// exercised by `flutter test` on any platform.
library;

export 'src/colors.dart';
export 'src/haptics.dart';
export 'src/motion.dart';
export 'src/scope.dart';
export 'src/store.dart';
export 'src/strings.dart';
export 'src/theme.dart';
export 'src/tokens.dart';
export 'src/typography.dart';
export 'src/viz.dart';
export 'src/widgets/buttons.dart';
export 'src/widgets/charts.dart';
export 'src/widgets/controls.dart';
export 'src/widgets/feedback.dart';
export 'src/widgets/surfaces.dart';
