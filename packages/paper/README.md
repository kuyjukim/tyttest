# paper

The design system the four apps in this repository share: tokens, the light
and dark themes, motion rules, primitive widgets, a validated chart palette,
calendar types, a pluggable key-value store, and a one-file substitute for a
state-management dependency.

It depends on nothing but the Flutter SDK (`flutter`, `flutter_localizations`
and `cupertino_icons`), so every part of it can be exercised by `flutter test`
on any platform.

## What is in here, and why

- **`colors.dart` / `typography.dart`** — semantic roles as `ThemeExtension`s,
  so call sites read `context.colors.inkMuted` rather than a Material role
  name. Dark accents are lifted into a legible lightness band, because brand
  colours picked for white backgrounds are reliably too dark on near-black.
  Tests assert WCAG contrast for every app's accent in both modes.
- **`viz.dart`** — the categorical chart palette, validated with a
  colour-vision validator against this suite's own surfaces rather than
  eyeballed. Slots are handed out in fixed order and never cycled, and colour
  follows the entity rather than its rank.
- **`day.dart`** — calendar arithmetic that never goes through `Duration`,
  because a day is 23 or 25 hours across a DST boundary.
- **`motion.dart`** — reduced-motion helpers. Three of the four apps lean on
  animation to justify their price, which makes the OS setting a correctness
  concern rather than a nicety.
- **`haptics.dart`** — fire-and-forget haptics. The platform channel throws
  wherever it is unimplemented, so a haptic must never be awaited before the
  work it accompanies.
- **`store.dart`** — `KeyValueStore` with in-memory and file-backed
  implementations. The file one takes a `Directory` instead of reaching for
  `path_provider` itself, which is what keeps this package plugin-free; writes
  go through a temp file and a rename.
- **`scope.dart`** — `InheritedNotifier` wrapper standing in for a
  state-management package these apps do not need.
- **`strings.dart`** — a delegate for hand-written localisation tables, so a
  missing translation is a compile error rather than a silent runtime
  fallback.

Run `flutter test` here, or `tool/check.sh paper` from the repository root.
