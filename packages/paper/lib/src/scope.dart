import 'package:flutter/widgets.dart';

/// A one-file substitute for a state-management dependency.
///
/// Every app in this suite is a local-first app whose state is a handful of
/// [ChangeNotifier]s. Pulling in a container/provider package to move those
/// down the tree would add a dependency, a build_runner step or a codegen
/// story for no behaviour we do not already get from [InheritedNotifier].
///
/// ```dart
/// Scope<SessionStore>(
///   value: store,
///   child: Builder(
///     builder: (context) => Text('${Scope.watch<SessionStore>(context).count}'),
///   ),
/// )
/// ```
class Scope<T extends Listenable> extends InheritedNotifier<T> {
  const Scope({required T value, required super.child, super.key})
    : super(notifier: value);

  /// Returns the nearest [T] and rebuilds the caller whenever it notifies.
  static T watch<T extends Listenable>(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<Scope<T>>();
    assert(scope != null, 'No Scope<$T> found above this widget.');
    return scope!.notifier!;
  }

  /// Returns the nearest [T] without subscribing.
  ///
  /// Use this in callbacks (`onPressed`) and in [State.initState], where
  /// creating a dependency is either pointless or illegal.
  static T read<T extends Listenable>(BuildContext context) {
    final element = context.getElementForInheritedWidgetOfExactType<Scope<T>>();
    assert(element != null, 'No Scope<$T> found above this widget.');
    return (element!.widget as Scope<T>).notifier!;
  }

  /// Like [read], but returns null instead of asserting.
  static T? maybeRead<T extends Listenable>(BuildContext context) {
    final element = context.getElementForInheritedWidgetOfExactType<Scope<T>>();
    return element == null ? null : (element.widget as Scope<T>).notifier;
  }
}

/// Rebuilds [builder] whenever the nearest [T] notifies.
///
/// Slightly cheaper than calling [Scope.watch] in a big `build`, because the
/// rebuild is scoped to the subtree this widget wraps.
class ScopeBuilder<T extends Listenable> extends StatelessWidget {
  const ScopeBuilder({required this.builder, super.key});

  final Widget Function(BuildContext context, T value) builder;

  @override
  Widget build(BuildContext context) =>
      builder(context, Scope.watch<T>(context));
}
