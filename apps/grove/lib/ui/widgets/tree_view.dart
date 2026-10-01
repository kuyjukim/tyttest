import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:paper/paper.dart';

import 'tree_figure.dart';

/// Draws a [TreeFigure], optionally with an idle breeze.
///
/// The breeze is the only continuously animating thing in the app, and it is
/// the reason a 25-minute screen does not feel like a static countdown. It is
/// also the first thing to go: under reduced motion the tree is drawn
/// perfectly still, and the growth staging alone carries the progress.
class TreeView extends StatefulWidget {
  const TreeView({
    required this.figure,
    this.breeze = false,
    this.depthLimit,
    this.showGround = true,
    super.key,
  });

  final TreeFigure figure;

  /// Sway the branches. Left off for the garden, where dozens of trees are on
  /// screen at once and the animation would cost more than it adds.
  final bool breeze;

  final int? depthLimit;
  final bool showGround;

  @override
  State<TreeView> createState() => _TreeViewState();
}

class _TreeViewState extends State<TreeView>
    with SingleTickerProviderStateMixin {
  /// Created eagerly in [initState], never lazily.
  ///
  /// A `late final` initialiser here is a crash: a tree drawn without the
  /// breeze - every thumbnail in the garden - would never touch the field
  /// while it was alive, so `dispose` would be the first access and would
  /// construct an AnimationController during unmount, where `vsync` has to
  /// look up an ancestor that is already deactivated.
  late final AnimationController _breeze;

  @override
  void initState() {
    super.initState();
    _breeze = AnimationController(
      // Slow on purpose. A fast sway reads as a cartoon; this is meant to be
      // watchable for the length of a work session.
      duration: const Duration(seconds: 9),
      vsync: this,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion is a MediaQuery dependency, so the decision belongs
    // here rather than in initState: it has to be re-made when the user
    // flips the system setting while the app is open.
    _syncBreeze();
  }

  @override
  void didUpdateWidget(TreeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncBreeze();
  }

  /// Runs the ticker only when the sway will actually be drawn.
  ///
  /// Leaving the controller repeating under reduced motion would schedule a
  /// frame forever for an animation nothing reads - invisible to the user,
  /// but real battery and a test that can never reach quiescence.
  void _syncBreeze() {
    final wanted = widget.breeze && !Motion.reduced(context);
    if (wanted && !_breeze.isAnimating) {
      _breeze.repeat();
    } else if (!wanted && _breeze.isAnimating) {
      _breeze
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _breeze.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ground = context.colors.isDark
        ? context.colors.hairline
        : const Color(0xFFDCD2C2);
    final still = !_breeze.isAnimating;

    // Isolated so the breeze repaints the tree and nothing else - not the
    // countdown text beside it, and not the garden row behind it.
    return RepaintBoundary(
      child: still
          ? CustomPaint(
              painter: TreePainter(
                figure: widget.figure,
                groundColor: ground,
                showGround: widget.showGround,
                depthLimit: widget.depthLimit,
              ),
              size: Size.infinite,
            )
          : AnimatedBuilder(
              animation: _breeze,
              builder: (context, _) => CustomPaint(
                painter: TreePainter(
                  figure: widget.figure,
                  groundColor: ground,
                  sway: _breeze.value * 2 * math.pi,
                  showGround: widget.showGround,
                  depthLimit: widget.depthLimit,
                ),
                size: Size.infinite,
              ),
            ),
    );
  }
}
