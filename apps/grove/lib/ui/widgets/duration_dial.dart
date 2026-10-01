import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:paper/paper.dart';

import '../format.dart';

/// A circular control for picking a session length, which becomes the
/// progress ring once the session is running.
///
/// The track is a 270° arc with the gap at the bottom rather than a full
/// circle. A full circle has no unambiguous start or end, so a drag past the
/// top wraps from 120 minutes to 5 - which is exactly the accident a user
/// makes once and then distrusts the control forever.
class DurationDial extends StatefulWidget {
  const DurationDial({
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
    this.progress,
    this.haptics = true,
    this.child,
    super.key,
  });

  final Duration value;
  final Duration min;
  final Duration max;
  final Duration step;

  /// Null makes the dial read-only, which is how it behaves while a session
  /// runs: the ring then shows [progress] and taps do nothing.
  final ValueChanged<Duration>? onChanged;

  /// 0..1. When non-null the ring fills to this instead of to [value].
  final double? progress;

  final bool haptics;

  /// Drawn in the middle of the ring - the countdown, or the tree.
  final Widget? child;

  @override
  State<DurationDial> createState() => _DurationDialState();
}

class _DurationDialState extends State<DurationDial> {
  /// Where the arc starts and how far it runs, in radians, clockwise from
  /// straight up.
  static const double _sweep = math.pi * 1.5;
  static const double _startAngle = -_sweep / 2;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final interactive = widget.onChanged != null;
    final fraction = widget.progress ?? _fractionFor(widget.value);

    return Semantics(
      slider: true,
      enabled: interactive,
      value: Fmt.minutes(widget.value),
      increasedValue: Fmt.minutes(_clamp(widget.value + widget.step)),
      decreasedValue: Fmt.minutes(_clamp(widget.value - widget.step)),
      onIncrease: interactive
          ? () => _emit(_clamp(widget.value + widget.step))
          : null,
      onDecrease: interactive
          ? () => _emit(_clamp(widget.value - widget.step))
          : null,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = math.min(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(
            onPanStart: interactive
                ? (details) => _handleDrag(details.localPosition, side)
                : null,
            onPanUpdate: interactive
                ? (details) => _handleDrag(details.localPosition, side)
                : null,
            child: SizedBox(
              height: side,
              width: side,
              child: CustomPaint(
                painter: _DialPainter(
                  fraction: fraction,
                  trackColor: colors.surfaceSunken,
                  fillColor: colors.accent,
                  tickColor: colors.hairline,
                  knobColor: colors.accent,
                  showKnob: interactive,
                  startAngle: _startAngle,
                  sweep: _sweep,
                  tickCount: _tickCount,
                ),
                child: Center(child: widget.child),
              ),
            ),
          );
        },
      ),
    );
  }

  int get _tickCount {
    final steps = (widget.max - widget.min).inSeconds ~/ widget.step.inSeconds;
    return steps < 1 ? 1 : steps;
  }

  double _fractionFor(Duration value) {
    final range = (widget.max - widget.min).inSeconds;
    if (range <= 0) return 0;
    return ((value - widget.min).inSeconds / range).clamp(0.0, 1.0);
  }

  Duration _clamp(Duration value) {
    if (value < widget.min) return widget.min;
    if (value > widget.max) return widget.max;
    return value;
  }

  void _handleDrag(Offset local, double side) {
    final centre = Offset(side / 2, side / 2);
    final vector = local - centre;
    // Ignore a drag that starts in the dead zone at the middle, where the
    // angle is noise and the user is probably trying to tap the child.
    if (vector.distance < side * 0.18) return;

    // atan2 measured clockwise from straight up, so it lines up with the arc.
    var angle = math.atan2(vector.dx, -vector.dy);
    if (angle < _startAngle) {
      // Below the gap: snap to whichever end the finger is nearer.
      angle = angle < -math.pi + _startAngle.abs()
          ? _startAngle + _sweep
          : _startAngle;
    } else if (angle > _startAngle + _sweep) {
      angle = _startAngle + _sweep;
    }

    final fraction = ((angle - _startAngle) / _sweep).clamp(0.0, 1.0);
    final range = (widget.max - widget.min).inSeconds;
    final rawSeconds = widget.min.inSeconds + fraction * range;
    final stepSeconds = widget.step.inSeconds;
    final snapped = Duration(
      seconds: (rawSeconds / stepSeconds).round() * stepSeconds,
    );
    _emit(_clamp(snapped));
  }

  void _emit(Duration next) {
    if (next == widget.value) return;
    // One tick per step crossed is the whole point of a dial: it lets the
    // user set a duration without looking at the number.
    Buzz.select(enabled: widget.haptics);
    widget.onChanged?.call(next);
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({
    required this.fraction,
    required this.trackColor,
    required this.fillColor,
    required this.tickColor,
    required this.knobColor,
    required this.showKnob,
    required this.startAngle,
    required this.sweep,
    required this.tickCount,
  });

  final double fraction;
  final Color trackColor;
  final Color fillColor;
  final Color tickColor;
  final Color knobColor;
  final bool showKnob;
  final double startAngle;
  final double sweep;
  final int tickCount;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final stroke = size.shortestSide * 0.045;
    final radius = size.shortestSide / 2 - stroke;
    // Canvas angles run from the positive x-axis; the dial's run from
    // straight up, which is a quarter turn earlier.
    final canvasStart = startAngle - math.pi / 2;
    final rect = Rect.fromCircle(center: centre, radius: radius);

    final track = Paint()
      ..color = trackColor
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawArc(rect, canvasStart, sweep, false, track);

    if (fraction > 0) {
      final fill = Paint()
        ..color = fillColor
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawArc(rect, canvasStart, sweep * fraction, false, fill);
    }

    // Ticks sit just inside the track. Drawn only when they are far enough
    // apart to read as marks rather than as a grey band.
    final tickSpacing = sweep / tickCount * radius;
    if (tickSpacing > 6) {
      final tick = Paint()
        ..color = tickColor
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round;
      final inner = radius - stroke * 1.6;
      for (var i = 0; i <= tickCount; i++) {
        final angle = canvasStart + sweep * (i / tickCount);
        final direction = Offset(math.cos(angle), math.sin(angle));
        // Every fourth tick is longer, which on a five-minute step makes the
        // long marks land on the hours and quarters.
        final length = i % 4 == 0 ? stroke * 0.9 : stroke * 0.5;
        canvas.drawLine(
          centre + direction * (inner - length),
          centre + direction * inner,
          tick,
        );
      }
    }

    if (showKnob) {
      final angle = canvasStart + sweep * fraction;
      final position =
          centre + Offset(math.cos(angle), math.sin(angle)) * radius;
      canvas
        ..drawCircle(position, stroke * 0.95, Paint()..color = knobColor)
        ..drawCircle(
          position,
          stroke * 0.42,
          Paint()..color = const Color(0xFFFFFFFF),
        );
    }
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.fraction != fraction ||
      old.trackColor != trackColor ||
      old.fillColor != fillColor ||
      old.tickColor != tickColor ||
      old.knobColor != knobColor ||
      old.showKnob != showKnob ||
      old.tickCount != tickCount;
}
