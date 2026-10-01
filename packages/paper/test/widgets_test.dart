import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper/paper.dart';

Widget _host(Widget child, {bool reduceMotion = false, Brightness? brightness}) {
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

    testWidgets('a null callback blocks taps and reports as disabled',
        (tester) async {
      await tester.pumpWidget(
        _host(const PaperButton(label: 'Plant', onPressed: null)),
      );
      await tester.tap(find.text('Plant'));
      await tester.pump();

      final semantics = tester.getSemantics(find.text('Plant'));
      expect(semantics.flagsCollection.isEnabled, isFalse);
    });

    testWidgets('busy swaps the label for a spinner and ignores taps',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(PaperButton(label: 'Saving', busy: true, onPressed: () => taps++)),
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
        reason: 'an icon-only button is invisible to a screen reader without one',
      );
      final size = tester.getSize(find.byIcon(Icons.add).hitTestable());
      expect(size.width, greaterThanOrEqualTo(0));
    });
  });

  group('SegmentedToggle', () {
    testWidgets('reports the selection and emits the tapped value',
        (tester) async {
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

    testWidgets('a value outside the segments does not crash the thumb',
        (tester) async {
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

    testWidgets('renders an all-zero week without dividing by zero',
        (tester) async {
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

    testWidgets('tapping a column reveals its value, tapping again hides it',
        (tester) async {
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
    testWidgets('folds everything past six segments into one Other block',
        (tester) async {
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 300,
            child: ShareBar(
              segments: [for (var i = 0; i < 10; i++) (10.0, i)],
            ),
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
    testWidgets('collapses durations and travel when reduce-motion is on',
        (tester) async {
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

    testWidgets('passes values through when reduce-motion is off',
        (tester) async {
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

  group('feedback', () {
    testWidgets('confirmDestructive returns false when dismissed',
        (tester) async {
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
