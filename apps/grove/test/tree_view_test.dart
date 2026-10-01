import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grove/domain/species.dart';
import 'package:grove/ui/widgets/tree_figure.dart';
import 'package:grove/ui/widgets/tree_view.dart';

Widget host(Widget child, {double side = 200}) => MaterialApp(
  home: Scaffold(
    body: Center(child: SizedBox(height: side, width: side, child: child)),
  ),
);

void main() {
  const figure = TreeFigure(
    species: Species.sprout,
    growth: 0.5,
    seed: 12345,
  );

  group('TreeView lifecycle', () {
    testWidgets('a still tree can be disposed without ever animating',
        (tester) async {
      // Regression: with a lazily-initialised AnimationController, `dispose`
      // was the first access and built the controller during unmount, where
      // vsync looks up an already-deactivated ancestor. Every garden
      // thumbnail hit this on scroll.
      await tester.pumpWidget(host(const TreeView(figure: figure)));
      await tester.pumpWidget(host(const SizedBox.shrink()));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a breezing tree can be disposed mid-animation',
        (tester) async {
      await tester.pumpWidget(
        host(const TreeView(figure: figure, breeze: true)),
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpWidget(host(const SizedBox.shrink()));
      expect(tester.takeException(), isNull);
    });

    testWidgets('turning the breeze on and off starts and stops the ticker',
        (tester) async {
      await tester.pumpWidget(host(const TreeView(figure: figure)));
      expect(tester.hasRunningAnimations, isFalse);

      await tester.pumpWidget(
        host(const TreeView(figure: figure, breeze: true)),
      );
      await tester.pump();
      expect(tester.hasRunningAnimations, isTrue);

      await tester.pumpWidget(host(const TreeView(figure: figure)));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('TreePainter', () {
    testWidgets('draws every species at every growth stage without throwing',
        (tester) async {
      for (final species in Species.values) {
        for (final growth in <double>[0, 0.01, 0.33, 0.66, 1]) {
          for (final withered in <bool>[false, true]) {
            await tester.pumpWidget(
              host(
                TreeView(
                  figure: TreeFigure(
                    species: species,
                    seed: species.index * 31 + 7,
                    growth: growth,
                    withered: withered,
                  ),
                ),
              ),
            );
            expect(
              tester.takeException(),
              isNull,
              reason: '${species.name} at $growth (withered: $withered)',
            );
          }
        }
      }
    });

    testWidgets('survives a degenerate box and an out-of-range growth',
        (tester) async {
      await tester.pumpWidget(
        host(const TreeView(figure: figure), side: 0),
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        host(
          const TreeView(
            figure: TreeFigure(
              species: Species.baobab,
              seed: 1,
              growth: 4.2,
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    test('repaints only when something visible changed', () {
      TreePainter painter(TreeFigure f, {double sway = 0, int? depth}) =>
          TreePainter(
            figure: f,
            groundColor: const Color(0xFF000000),
            sway: sway,
            depthLimit: depth,
          );

      expect(painter(figure).shouldRepaint(painter(figure)), isFalse);
      expect(
        painter(figure).shouldRepaint(painter(figure, sway: 0.4)),
        isTrue,
      );
      expect(
        painter(figure).shouldRepaint(painter(figure, depth: 3)),
        isTrue,
      );
      expect(
        painter(
          figure,
        ).shouldRepaint(painter(const TreeFigure(
          species: Species.sprout,
          growth: 0.51,
          seed: 12345,
        ))),
        isTrue,
      );
    });

    test('figures compare by value so identical trees do not repaint', () {
      expect(
        const TreeFigure(species: Species.pine, growth: 1, seed: 9),
        const TreeFigure(species: Species.pine, growth: 1, seed: 9),
      );
      expect(
        const TreeFigure(species: Species.pine, growth: 1, seed: 9),
        isNot(const TreeFigure(species: Species.pine, growth: 1, seed: 10)),
      );
    });
  });
}
