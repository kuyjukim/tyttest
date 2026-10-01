import 'package:flutter/material.dart';

import '../motion.dart';
import '../theme.dart';
import '../tokens.dart';

/// A sliding segmented control.
///
/// Material's `SegmentedButton` is close, but it animates each segment's fill
/// independently; a single travelling thumb reads as one control rather than
/// several, which matters for a control users hit dozens of times a day.
class SegmentedToggle<T extends Object> extends StatelessWidget {
  const SegmentedToggle({
    required this.segments,
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// Ordered value/label pairs. Two to four entries; beyond that use a list.
  final List<(T value, String label)> segments;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final selected = segments.indexWhere((s) => s.$1 == value);
    // A value outside `segments` would otherwise put the thumb at -1.
    final index = selected < 0 ? 0 : selected;

    return LayoutBuilder(
      builder: (context, constraints) {
        final slot = constraints.maxWidth / segments.length;
        return Container(
          height: 38,
          decoration: BoxDecoration(
            color: colors.surfaceSunken,
            borderRadius: Radii.allSm,
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: Motion.time(context, Tempo.base),
                curve: Ease.emphasized,
                left: slot * index,
                top: 3,
                bottom: 3,
                width: slot,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surfaceRaised,
                      borderRadius: Radii.allXs,
                      border: Border.all(color: colors.hairline),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final segment in segments)
                    Expanded(
                      child: Semantics(
                        selected: segment.$1 == value,
                        button: true,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onChanged(segment.$1),
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: Motion.time(context, Tempo.base),
                              style: context.type.label.copyWith(
                                color: segment.$1 == value
                                    ? colors.ink
                                    : colors.inkMuted,
                                fontWeight: segment.$1 == value
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                              child: Text(segment.$2),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A labelled row with a trailing switch, sized for a settings list.
class SettingSwitch extends StatelessWidget {
  const SettingSwitch({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Gap.md),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.type.body),
                    if (subtitle != null) ...[
                      const SizedBox(height: Gap.xxs),
                      Text(subtitle!, style: context.type.caption),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: Gap.lg),
              // The row itself is the tap target; the switch must not also
              // handle taps or a tap on the thumb toggles twice.
              IgnorePointer(
                child: Switch.adaptive(value: value, onChanged: onChanged),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A row that opens something else - a picker, a sub-page, a sheet.
class SettingRow extends StatelessWidget {
  const SettingRow({
    required this.title,
    required this.onTap,
    this.value,
    this.destructive = false,
    super.key,
  });

  final String title;
  final String? value;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.md),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: context.type.body.copyWith(
                  color: destructive ? colors.danger : colors.ink,
                ),
              ),
            ),
            if (value != null)
              Text(value!, style: context.type.body.copyWith(color: colors.inkMuted)),
            const SizedBox(width: Gap.xs),
            Icon(Icons.chevron_right_rounded, size: 20, color: colors.inkFaint),
          ],
        ),
      ),
    );
  }
}
