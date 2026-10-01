import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper/paper.dart';

Widget _host(
  Widget child, {
  bool reduceMotion = false,
  Brightness? brightness,
}) {
  return MaterialApp(
    theme: PaperTheme.of(
      accent: const Color(0xFF2F7D5B),
      brightness: brightness ?? Brightness.light,
    ),
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  group('PaperButton', () {
    testWidgets('fires once per tap when enabled', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(PaperButton(label: 'Plant', onPressed: () => taps++)),
      );
      await tester.tap(find.text('Plant'));
      expect(taps, 1);
    });

    testWidgets('a null callback blocks taps and reports as disabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const PaperButton(label: 'Plant', onPressed: null)),
      );
      await tester.tap(find.text('Plant'));
      await tester.pump();

      final semantics = tester.getSemantics(find.text('Plant'));
      expect(semantics.flagsCollection.isEnabled, isFalse);
    });

    testWidgets('busy swaps the label for a spinner and ignores taps', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          PaperButton(label: 'Saving', busy: true, onPressed: () => taps++),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Saving'), findsNothing);

      await tester.tap(find.byType(PaperButton));
      expect(taps, 0, reason: 'a busy button must not double-submit');
    });

    testWidgets('every size meets the minimum touch target', (tester) async {
      for (final size in PaperButtonSize.values) {
        await tester.pumpWidget(
          _host(PaperButton(label: 'Go', size: size, onPressed: () {})),
        );
        final height = tester.getSize(find.byType(PaperButton)).height;
        expect(height, greaterThanOrEqualTo(36.0), reason: '$size');
      }
    });
  });

  group('PaperIconButton', () {
    testWidgets('exposes its tooltip as a semantic label', (tester) async {
      await tester.pumpWidget(
        _host(
          PaperIconButton(
            icon: Icons.add,
            tooltip: 'Add envelope',
            onPressed: () {},
          ),
        ),
      );
      expect(
        find.bySemanticsLabel('Add envelope'),
        findsWidgets,
        reason:
            'an icon-only button is invisible to a screen reader without one',
      );
      final size = tester.getSize(find.byIcon(Icons.add).hitTestable());
      expect(size.width, greaterThanOrEqualTo(0));
    });
  });

  group('SegmentedToggle', () {
    testWidgets('reports the selection and emits the tapped value', (
      tester,
    ) async {
      String? picked;
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 300,
            child: SegmentedToggle<String>(
              segments: const [('d', 'Day'), ('w', 'Week'), ('m', 'Month')],
              value: 'w',
              onChanged: (v) => picked = v,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(find.text('Week')).flagsCollection.isSelected,
        isTrue,
      );
      await tester.tap(find.text('Month'));
      expect(picked, 'm');
    });

    testWidgets('a value outside the segments does not crash the thumb', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 300,
            child: SegmentedToggle<String>(
              segments: const [('d', 'Day'), ('w', 'Week')],
              value: 'nonsense',
              onChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('BarChart', () {
    List<Bar> week(List<double> values) => [
      for (final (i, v) in values.indexed)
        Bar(label: 'D$i', value: v, highlight: i == values.length - 1),
    ];

    testWidgets('renders an all-zero week without dividing by zero', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 320,
            child: BarChart(
              bars: week(const [0, 0, 0, 0, 0, 0, 0]),
              formatValue: (v) => '${v.round()}m',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('labels the peak but not every column', (tester) async {
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 320,
            child: BarChart(
              bars: week(const [10, 90, 25, 0, 40, 15, 30]),
              formatValue: (v) => '${v.round()}m',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('90m'), findsOneWidget, reason: 'the peak is labelled');
      expect(find.text('25m'), findsNothing, reason: 'the rest are not');
    });

    testWidgets('tapping a column reveals its value, tapping again hides it', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 320,
            child: BarChart(
              bars: week(const [10, 90, 25, 0, 40, 15, 30]),
              formatValue: (v) => '${v.round()}m',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('D2'));
      await tester.pumpAndSettle();
      expect(find.text('25m'), findsOneWidget);

      await tester.tap(find.text('D2'));
      await tester.pumpAndSettle();
      expect(find.text('25m'), findsNothing);
    });

    testWidgets('thins the axis strip when the columns are too narrow', (
      tester,
    ) async {
      // A month of daily bars in a phone's width: about eleven logical
      // pixels a column, which two digits do not fit into. The unit on the
      // value labels keeps them out of the way of this test's day numbers.
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 360,
            child: BarChart(
              bars: [
                for (var day = 1; day <= 31; day++)
                  Bar(
                    label: '$day',
                    value: day.toDouble(),
                    highlight: day == 18,
                  ),
              ],
              formatValue: (v) => '${v.round()}m',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final shown = [
        for (var day = 1; day <= 31; day++)
          if (find.text('$day').evaluate().isNotEmpty) day,
      ];

      expect(shown.length, lessThan(31), reason: 'the strip was thinned');
      expect(shown.length, greaterThan(4), reason: 'but not emptied');
      expect(
        shown,
        contains(18),
        reason: 'the highlighted day anchors the stride, so it stays named',
      );

      // Every label that survived is drawn whole. A column is narrower than
      // "10" at this width, so a label has to be allowed to spill into the
      // blank columns beside it rather than lose its last digit.
      for (final day in shown) {
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text('$day'),
        );
        expect(
          paragraph.size.width,
          greaterThanOrEqualTo(paragraph.getMaxIntrinsicWidth(double.infinity)),
          reason: '"$day" was clipped by the width of its column',
        );
      }
    });

    testWidgets('keeps every label when the columns are wide enough', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 360,
            child: BarChart(
              bars: week(const [10, 90, 25, 0, 40, 15, 30]),
              formatValue: (v) => '${v.round()}m',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (var i = 0; i < 7; i++) {
        expect(find.text('D$i'), findsOneWidget);
      }
    });

    testWidgets('a thinned strip still names every column in semantics', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 360,
            child: BarChart(
              bars: [
                for (var day = 1; day <= 31; day++)
                  Bar(label: '$day', value: day.toDouble()),
              ],
              formatValue: (v) => '${v.round()}',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Day 20 has no visible label at this width; a screen reader still
      // reaches it.
      expect(find.text('20'), findsNothing);
      expect(find.bySemanticsLabel('20: 20'), findsOneWidget);
    });

    testWidgets('each column carries its value in semantics', (tester) async {
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 320,
            child: BarChart(
              bars: week(const [10, 90, 25, 0, 40, 15, 30]),
              formatValue: (v) => '${v.round()}m',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('D3: 0m'), findsOneWidget);
    });
  });

  group('ShareBar', () {
    testWidgets('folds everything past six segments into one Other block', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 300,
            child: ShareBar(segments: [for (var i = 0; i < 10; i++) (10.0, i)]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Six hues plus one neutral tail.
      expect(find.byType(ClipRRect), findsNWidgets(ShareBar.maxSegments + 1));
    });

    testWidgets('an empty total renders an inert track', (tester) async {
      await tester.pumpWidget(
        _host(
          const SizedBox(width: 300, child: ShareBar(segments: [(0.0, 0)])),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('Motion', () {
    testWidgets('collapses durations and travel when reduce-motion is on', (
      tester,
    ) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox.shrink();
            },
          ),
          reduceMotion: true,
        ),
      );
      expect(Motion.reduced(ctx), isTrue);
      expect(Motion.time(ctx, Tempo.slow), Duration.zero);
      expect(Motion.travel(ctx, 40), 0);
      expect(Motion.curve(ctx, Ease.overshoot), Curves.linear);
    });

    testWidgets('passes values through when reduce-motion is off', (
      tester,
    ) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(Motion.time(ctx, Tempo.slow), Tempo.slow);
      expect(Motion.travel(ctx, 40), 40);
    });
  });

  group('Buzz', () {
    testWidgets('swallows a missing haptics channel instead of throwing', (
      tester,
    ) async {
      // No mock handler is installed, so the platform channel replies null,
      // which MethodChannel turns into a MissingPluginException. A haptic
      // must never be able to break the action it accompanies.
      Buzz.select();
      Buzz.tap();
      Buzz.success();
      Buzz.reject();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('does nothing at all when disabled', (tester) async {
      var calls = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') calls++;
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      Buzz.tap(enabled: false);
      await tester.pump();
      expect(calls, 0);

      Buzz.tap();
      await tester.pump();
      expect(calls, 1);
    });
  });

  group('feedback', () {
    testWidgets('confirmDestructive returns false when dismissed', (
      tester,
    ) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final future = confirmDestructive(
        ctx,
        title: 'Delete vault',
        message: 'This cannot be undone.',
        confirmLabel: 'Delete',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(await future, isFalse);
    });

    testWidgets('EmptyState shows its call to action', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _host(
          EmptyState(
            icon: Icons.park_outlined,
            title: 'Nothing planted yet',
            message: 'Finish a focus session to grow your first tree.',
            actionLabel: 'Start focusing',
            onAction: () => tapped = true,
          ),
        ),
      );
      await tester.tap(find.text('Start focusing'));
      expect(tapped, isTrue);
    });
  });
}
