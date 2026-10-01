import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:paper/paper.dart';

import '../../domain/month.dart';
import '../strings.dart';

/// Month stepper: back, the month's name, forward.
///
/// Forward is never disabled. Budgeting next month before it starts is the
/// normal use of an envelope system, not an edge case.
class MonthBar extends StatelessWidget {
  const MonthBar({
    required this.month,
    required this.isCurrent,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
    super.key,
  });

  final Month month;
  final bool isCurrent;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final strings = S.of(context);
    return Row(
      children: [
        PaperIconButton(
          icon: Icons.chevron_left_rounded,
          tooltip: strings.previousMonth,
          onPressed: onPrevious,
        ),
        Expanded(
          child: GestureDetector(
            onTap: isCurrent ? null : onToday,
            child: Column(
              children: [
                Text(
                  DateFormat.yMMMM(context.localeTag).format(month.firstDay.startOfDay),
                  textAlign: TextAlign.center,
                  style: context.type.bodyStrong,
                ),
                if (!isCurrent)
                  Text(
                    strings.thisMonth,
                    style: context.type.caption.copyWith(
                      color: context.colors.accent,
                    ),
                  ),
              ],
            ),
          ),
        ),
        PaperIconButton(
          icon: Icons.chevron_right_rounded,
          tooltip: strings.nextMonth,
          onPressed: onNext,
        ),
      ],
    );
  }
}
