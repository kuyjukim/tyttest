import 'package:flutter/material.dart';
import 'package:paper/paper.dart';

import '../../domain/entry.dart';
import '../mood_scale.dart';

/// A small filled circle for a mood, with a surface ring so it stays legible
/// where it overlaps text or another mark.
class MoodDot extends StatelessWidget {
  const MoodDot({required this.mood, this.size = 10, super.key});

  final Mood mood;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: MoodScale.of(mood, dark: colors.isDark),
        shape: BoxShape.circle,
        border: Border.all(color: colors.surface, width: 2),
      ),
    );
  }
}

/// The five-point mood picker.
///
/// Every option carries its name, not just its colour: the scale is the one
/// place in the app where colour encodes meaning, and it must not be the only
/// thing that does.
class MoodPicker extends StatelessWidget {
  const MoodPicker({
    required this.value,
    required this.onChanged,
    required this.label,
    super.key,
  });

  final Mood? value;

  /// Passing the current value again clears the selection, so a mis-tap is
  /// undone with a second tap rather than needing a separate "none" chip.
  final ValueChanged<Mood?> onChanged;

  final String Function(Mood mood) label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        for (final mood in Mood.values)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: Gap.xs),
              child: Semantics(
                selected: mood == value,
                button: true,
                label: label(mood),
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => onChanged(mood == value ? null : mood),
                  child: AnimatedContainer(
                    duration: Motion.time(context, Tempo.quick),
                    padding: const EdgeInsets.symmetric(vertical: Gap.sm),
                    decoration: BoxDecoration(
                      color: mood == value
                          ? colors.surfaceSunken
                          : Colors.transparent,
                      borderRadius: Radii.allSm,
                      border: Border.all(
                        color: mood == value
                            ? colors.hairline
                            : Colors.transparent,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          height: 14,
                          width: 14,
                          decoration: BoxDecoration(
                            color: MoodScale.of(mood, dark: colors.isDark),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(height: Gap.xs),
                        Text(
                          label(mood),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: context.type.caption.copyWith(
                            color: mood == value ? colors.ink : colors.inkMuted,
                            fontWeight: mood == value ? FontWeight.w600 : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
