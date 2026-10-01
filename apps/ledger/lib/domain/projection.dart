import 'package:paper/paper.dart';

import 'budget.dart';
import 'envelope.dart';
import 'money.dart';
import 'month.dart';

/// One envelope's position in one month.
class EnvelopeStatus {
  const EnvelopeStatus({
    required this.envelope,
    required this.allocated,
    required this.rolloverIn,
    required this.spent,
  });

  final Envelope envelope;

  /// Budgeted this month.
  final Money allocated;

  /// Carried in from last month. Negative when last month was overspent.
  final Money rolloverIn;

  /// Money that left the envelope. Negative if refunds exceeded spending,
  /// which is unusual but real and is shown as it is rather than clamped.
  final Money spent;

  Money get available => allocated + rolloverIn;
  Money get remaining => available - spent;

  /// What carries into next month: nothing unless the envelope rolls over.
  Money get rolloverOut =>
      envelope.rollover ? remaining : Money.zeroIn(allocated.currency);

  bool get overspent => remaining.isNegative;

  /// Fraction of what was available that has been spent, for a bar.
  ///
  /// Clamped at the top so an overspent envelope's bar fills rather than
  /// overflowing its track; [overspent] is what the UI colours on.
  double get usedFraction {
    if (available.isZero) return spent.isPositive ? 1 : 0;
    return spent.fractionOf(available).clamp(0.0, 1.0);
  }

  /// True when nothing at all happened here this month.
  bool get isIdle => allocated.isZero && rolloverIn.isZero && spent.isZero;
}

/// A whole month, totalled.
class MonthReport {
  const MonthReport({
    required this.month,
    required this.currency,
    required this.income,
    required this.envelopes,
  });

  final Month month;
  final Currency currency;

  /// What the user said came in this month.
  final Money income;

  final List<EnvelopeStatus> envelopes;

  Money get allocatedTotal =>
      Money.sum(envelopes.map((e) => e.allocated), currency);

  /// Income not yet given a job. Negative means over-committed.
  Money get unallocated => income - allocatedTotal;

  Money get spentTotal => Money.sum(envelopes.map((e) => e.spent), currency);

  Money get remainingTotal =>
      Money.sum(envelopes.map((e) => e.remaining), currency);

  List<EnvelopeStatus> get overspentEnvelopes =>
      <EnvelopeStatus>[for (final e in envelopes) if (e.overspent) e];

  /// What is left, divided by the days left in the month including today.
  ///
  /// Rounded *down* on purpose - toward zero for a surplus, away from zero
  /// for a deficit - so the number is never a figure the user cannot actually
  /// afford to spend every remaining day. Null once the month is over, where
  /// a daily rate would be meaningless.
  Money? safeToSpendPerDay(Day today) {
    final days = month.daysRemainingFrom(today);
    if (days <= 0) return null;
    final total = remainingTotal.minor;
    final perDay = (total / days).floor();
    return Money(perDay, currency);
  }
}

/// Turns a [Budget] into month reports.
///
/// All of it is pure and derived: nothing here is persisted, so no stored
/// total can drift from the transactions it was meant to summarise. The cost
/// is that a month with rollover has to be computed by walking forward from
/// the first month with any history, which is why [maxMonthsWalked] exists.
abstract final class Projection {
  /// Ceiling on the rollover walk.
  ///
  /// Fifty years of months. A budget cannot legitimately need more, and a
  /// date typo of `0226` instead of `2026` should cost a wrong-looking screen
  /// rather than a frozen app.
  static const int maxMonthsWalked = 600;

  static MonthReport forMonth(Budget budget, Month month) =>
      series(budget, month, month).last;

  /// Reports for [from] through [to], inclusive and in order.
  ///
  /// Computed in one walk: each month's rollover depends on the month before
  /// it, so asking for a range separately would redo the same work for every
  /// month in it.
  static List<MonthReport> series(Budget budget, Month from, Month to) {
    if (from.compareTo(to) > 0) return const <MonthReport>[];

    final currency = budget.currency;
    final zero = Money.zeroIn(currency);

    // Start the walk at the first month that could contribute a rollover.
    final earliest = budget.earliestMonth;
    var start = earliest == null || earliest.compareTo(from) > 0
        ? from
        : earliest;
    final walk = start.monthsUntil(to);
    if (walk > maxMonthsWalked) {
      start = to.addMonths(-maxMonthsWalked);
    }

    // Transactions bucketed by month then envelope, so the walk is one pass
    // over the ledger rather than a scan per month per envelope.
    final spentByMonth = <String, Map<String, int>>{};
    for (final txn in budget.transactions) {
      final key = Month.fromDay(txn.date).toString();
      final byEnvelope = spentByMonth.putIfAbsent(key, () => <String, int>{});
      // Stored signed with negative meaning "left the envelope"; `spent` is
      // the positive view of the same number.
      byEnvelope.update(
        txn.envelopeId,
        (value) => value - txn.amountMinor,
        ifAbsent: () => -txn.amountMinor,
      );
    }

    final carried = <String, int>{};
    final reports = <MonthReport>[];

    for (final month in start.through(to)) {
      final plan = budget.planFor(month);
      final spentHere = spentByMonth[month.toString()] ?? const <String, int>{};

      final statuses = <EnvelopeStatus>[];
      final nextCarried = <String, int>{};

      for (final envelope in budget.envelopes) {
        // An archived envelope stops drawing its default allocation: that is
        // what archiving means. An explicit allocation for this month still
        // wins, so a category can be brought back for one month without
        // un-archiving it.
        final fallback = envelope.archived ? 0 : envelope.allocationMinor;
        final allocation = Money(
          plan.allocations[envelope.id] ?? fallback,
          currency,
        );
        final rolloverIn = Money(carried[envelope.id] ?? 0, currency);
        final spent = Money(spentHere[envelope.id] ?? 0, currency);

        final status = EnvelopeStatus(
          envelope: envelope,
          allocated: allocation,
          rolloverIn: rolloverIn,
          spent: spent,
        );
        if (status.rolloverOut != zero) {
          nextCarried[envelope.id] = status.rolloverOut.minor;
        }

        // An archived envelope only appears in a month where something
        // actually happened to it, so retiring a category tidies future
        // months without rewriting past ones.
        if (!envelope.archived || !status.isIdle) statuses.add(status);
      }

      carried
        ..clear()
        ..addAll(nextCarried);

      if (month.compareTo(from) >= 0) {
        reports.add(
          MonthReport(
            month: month,
            currency: currency,
            income: Money(plan.incomeMinor, currency),
            envelopes: statuses,
          ),
        );
      }
    }

    return reports;
  }

  /// Total spent per envelope across [from]..[to], for the reports screen.
  static Map<String, Money> spentByEnvelope(
    Budget budget, {
    required Month from,
    required Month to,
  }) {
    final totals = <String, int>{};
    for (final txn in budget.transactions) {
      final month = Month.fromDay(txn.date);
      if (month.compareTo(from) < 0 || month.compareTo(to) > 0) continue;
      totals.update(
        txn.envelopeId,
        (value) => value - txn.amountMinor,
        ifAbsent: () => -txn.amountMinor,
      );
    }
    return <String, Money>{
      for (final entry in totals.entries)
        entry.key: Money(entry.value, budget.currency),
    };
  }

  /// Spending per day in [month], for the activity chart.
  static List<(Day day, Money spent)> dailySpend(Budget budget, Month month) {
    final perDay = <String, int>{};
    for (final txn in budget.transactions) {
      if (!month.contains(txn.date)) continue;
      perDay.update(
        txn.date.toString(),
        (value) => value - txn.amountMinor,
        ifAbsent: () => -txn.amountMinor,
      );
    }
    return <(Day, Money)>[
      for (final day in month.firstDay.through(month.lastDay))
        (day, Money(perDay[day.toString()] ?? 0, budget.currency)),
    ];
  }
}
