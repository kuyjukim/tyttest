import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper/paper.dart';

class Counter extends ChangeNotifier {
  int value = 0;
  void bump() {
    value++;
    notifyListeners();
  }
}

class Other extends ChangeNotifier {}

void main() {
  group('Scope', () {
    testWidgets('watch rebuilds the dependant when the notifier fires',
        (tester) async {
      final counter = Counter();
      addTearDown(counter.dispose);
      var builds = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scope<Counter>(
            value: counter,
            child: Builder(
              builder: (context) {
                builds++;
                return Text('${Scope.watch<Counter>(context).value}');
              },
            ),
          ),
        ),
      );
      expect(find.text('0'), findsOneWidget);
      expect(builds, 1);

      counter.bump();
      await tester.pump();

      expect(find.text('1'), findsOneWidget);
      expect(builds, 2);
    });

    testWidgets('read does not create a dependency', (tester) async {
      final counter = Counter();
      addTearDown(counter.dispose);
      var builds = 0;
      late Counter captured;

      await tester.pumpWidget(
        MaterialApp(
          home: Scope<Counter>(
            value: counter,
            child: Builder(
              builder: (context) {
                builds++;
                captured = Scope.read<Counter>(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(captured, same(counter));

      counter.bump();
      await tester.pump();

      expect(
        builds,
        1,
        reason: 'read is for callbacks; it must not subscribe the caller',
      );
    });

    testWidgets('scopes of different types nest without colliding',
        (tester) async {
      final counter = Counter();
      final other = Other();
      addTearDown(counter.dispose);
      addTearDown(other.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scope<Other>(
            value: other,
            child: Scope<Counter>(
              value: counter,
              child: Builder(
                builder: (context) => Text(
                  '${Scope.watch<Counter>(context).value}'
                  '/${Scope.read<Other>(context).runtimeType}',
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('0/Other'), findsOneWidget);
    });

    testWidgets('maybeRead returns null instead of asserting', (tester) async {
      Counter? found = Counter();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              found = Scope.maybeRead<Counter>(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(found, isNull);
    });

    testWidgets('ScopeBuilder scopes the rebuild to its own subtree',
        (tester) async {
      final counter = Counter();
      addTearDown(counter.dispose);
      var outerBuilds = 0;
      var innerBuilds = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scope<Counter>(
            value: counter,
            child: Builder(
              builder: (context) {
                outerBuilds++;
                return ScopeBuilder<Counter>(
                  builder: (context, value) {
                    innerBuilds++;
                    return Text('${value.value}');
                  },
                );
              },
            ),
          ),
        ),
      );
      expect((outerBuilds, innerBuilds), (1, 1));

      counter.bump();
      await tester.pump();

      expect(
        (outerBuilds, innerBuilds),
        (1, 2),
        reason: 'only the builder subtree should rebuild',
      );
      expect(find.text('1'), findsOneWidget);
    });
  });
}
