import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper/paper.dart';

/// WCAG relative luminance.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  // The four app accents the suite ships with. A regression here means one of
  // the apps has an unreadable brand colour in one of the two modes.
  const accents = <String, Color>{
    'grove': Color(0xFF2F7D5B),
    'inkwell': Color(0xFF5B5BD6),
    'ledger': Color(0xFFA85A2B),
    'stroke': Color(0xFFC2255C),
  };

  group('PaperColors', () {
    test('body text clears AA against the page in both modes', () {
      for (final brightness in Brightness.values) {
        final c = brightness == Brightness.dark
            ? PaperColors.dark(accent: accents['grove']!)
            : PaperColors.light(accent: accents['grove']!);
        expect(
          _contrast(c.ink, c.surface),
          greaterThanOrEqualTo(4.5),
          reason: '$brightness primary ink must pass AA',
        );
        expect(
          _contrast(c.inkMuted, c.surface),
          greaterThanOrEqualTo(4.5),
          reason: '$brightness secondary ink is used for body copy, so it '
              'must pass AA too, not just large-text AA',
        );
      }
    });

    test('every app accent stays visible on its own dark surface', () {
      for (final entry in accents.entries) {
        final dark = PaperColors.dark(accent: entry.value);
        expect(
          _contrast(dark.accent, dark.surface),
          greaterThanOrEqualTo(3.0),
          reason: '${entry.key}: a brand colour chosen for white needs '
              'lifting before it works on near-black',
        );
      }
    });

    test('text on an accent fill is readable for every app accent', () {
      for (final entry in accents.entries) {
        for (final brightness in Brightness.values) {
          final c = brightness == Brightness.dark
              ? PaperColors.dark(accent: entry.value)
              : PaperColors.light(accent: entry.value);
          expect(
            _contrast(c.onAccent, c.accent),
            greaterThanOrEqualTo(3.0),
            reason: '${entry.key} $brightness: button labels sit on the accent',
          );
        }
      }
    });

    test('lifting is idempotent for an accent already in the dark band', () {
      final once = PaperColors.dark(accent: accents['stroke']!).accent;
      final twice = PaperColors.dark(accent: once).accent;
      expect(twice, once);
    });

    test('lerp walks between the two palettes without throwing', () {
      final light = PaperColors.light(accent: accents['ledger']!);
      final dark = PaperColors.dark(accent: accents['ledger']!);
      for (final t in <double>[0, 0.25, 0.5, 0.75, 1]) {
        expect(light.lerp(dark, t), isA<PaperColors>());
      }
      expect(light.lerp(dark, 0).surface, light.surface);
      expect(light.lerp(dark, 1).surface, dark.surface);
      expect(light.lerp(null, 0.5), light);
    });
  });

  group('PaperTheme', () {
    test('publishes both extensions so context accessors never fall back', () {
      for (final brightness in Brightness.values) {
        final theme = PaperTheme.of(
          accent: accents['inkwell']!,
          brightness: brightness,
        );
        expect(theme.extension<PaperColors>(), isNotNull);
        expect(theme.extension<PaperType>(), isNotNull);
        expect(theme.brightness, brightness);
        expect(theme.scaffoldBackgroundColor,
            theme.extension<PaperColors>()!.surface);
      }
    });

    testWidgets('context.colors and context.type read the theme', (tester) async {
      late PaperColors seen;
      late PaperType type;
      await tester.pumpWidget(
        MaterialApp(
          theme: PaperTheme.dark(accent: accents['ledger']!),
          home: Builder(
            builder: (context) {
              seen = context.colors;
              type = context.type;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(seen.isDark, isTrue);
      expect(type.numericLarge.fontFeatures, isNotEmpty);
    });
  });

  group('PaperType', () {
    test('numeric styles use tabular figures', () {
      final type = PaperType.standard(
        ink: const Color(0xFF000000),
        muted: const Color(0xFF666666),
      );
      for (final style in <TextStyle>[type.numeric, type.numericLarge]) {
        expect(
          style.fontFeatures?.map((f) => f.feature),
          contains('tnum'),
          reason: 'without tnum a running timer jitters on every tick',
        );
      }
    });

    test('lerp is total over the scale', () {
      final a = PaperType.standard(
        ink: const Color(0xFF000000),
        muted: const Color(0xFF666666),
      );
      final b = PaperType.standard(
        ink: const Color(0xFFFFFFFF),
        muted: const Color(0xFF999999),
      );
      final mid = a.lerp(b, 0.5);
      expect(mid.body.color, isNot(a.body.color));
      expect(a.lerp(null, 0.5), a);
    });
  });

  group('Viz', () {
    test('slot colours are stable and never cycle inside the range', () {
      final seen = <Color>{};
      for (var i = 0; i < Viz.slots; i++) {
        expect(seen.add(Viz.slot(i, dark: false)), isTrue,
            reason: 'slot $i duplicates an earlier hue');
      }
      expect(Viz.slots, Viz.names.length);
    });

    test('light and dark are selected per mode, not the same table', () {
      var differences = 0;
      for (var i = 0; i < Viz.slots; i++) {
        if (Viz.slot(i, dark: true) != Viz.slot(i, dark: false)) differences++;
      }
      expect(differences, greaterThan(Viz.slots ~/ 2));
    });

    test('a corrupt slot index folds back into range instead of throwing', () {
      expect(Viz.slot(Viz.slots + 2, dark: false), Viz.slot(2, dark: false));
      expect(Viz.slot(-1, dark: true), Viz.slot(1, dark: true));
    });

    test('dark slots clear 3:1 against the dark page', () {
      final surface = PaperColors.dark(accent: accents['ledger']!).surface;
      for (var i = 0; i < Viz.slots; i++) {
        expect(
          _contrast(Viz.slot(i, dark: true), surface),
          greaterThanOrEqualTo(3.0),
          reason: 'dark slot $i (${Viz.names[i]})',
        );
      }
    });
  });
}
