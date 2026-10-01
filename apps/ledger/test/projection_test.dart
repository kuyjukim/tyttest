import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/domain/budget.dart';
import 'package:ledger/domain/envelope.dart';
import 'package:ledger/domain/money.dart';
import 'package:ledger/domain/month.dart';
import 'package:ledger/domain/projection.dart';
import 'package:ledger/domain/txn.dart';
import 'package:paper/paper.dart';

const krw = Currency.krw;

Envelope env(
  String id, {
  int allocation = 0,
  bool rollover = false,
  bool archived = false,
  int slot = 0,
}) => Envelope(
  id: id,
  name: id,
  slot: slot,
  allocationMinor: allocation,
  rollover: rollover,
  archived: archived,
);

Txn spend(String id, String envelopeId, int amount, Day date) => Txn(
  id: id,
  envelopeId: envelopeId,
  date: date,
  // The UI enters a spend as a positive number and negates it; the stored
  // value is signed.
  amountMinor: -amount,
);

Txn refund(String id, String envelopeId, int amount, Day date) =>
    Txn(id: id, envelopeId: envelopeId, date: date, amountMinor: amount);

Money won(int amount) => Money(amount, krw);

void main() {
  const october = Month(2026, 10);
  const november = Month(2026, 11);
  const december = Month(2026, 12);

  group('Month', () {
    test('knows its length, including February in a leap year', () {
      expect(const Month(2026, 1).dayCount, 31);
      expect(const Month(2026, 2).dayCount, 28);
      expect(const Month(2028, 2).dayCount, 29);
      expect(const Month(2026, 4).dayCount, 30);
    });

    test('steps across year boundaries', () {
      expect(const Month(2026, 12).next, const Month(2027, 1));
      expect(const Month(2026, 1).previous, const Month(2025, 12));
      expect(const Month(2026, 6).addMonths(-18), const Month(2024, 12));
      expect(const Month(2026, 6).addMonths(0), const Month(2026, 6));
    });

    test('monthsUntil is signed', () {
      expect(const Month(2026, 1).monthsUntil(const Month(2027, 1)), 12);
      expect(const Month(2027, 1).monthsUntil(const Month(2026, 1)), -12);
      expect(october.monthsUntil(october), 0);
    });

    test('first and last day bracket the month', () {
      expect(const Month(2026, 2).firstDay, const Day(2026, 2, 1));
      expect(const Month(2026, 2).lastDay, const Day(2026, 2, 28));
      expect(const Month(2028, 2).lastDay, const Day(2028, 2, 29));
      expect(const Month(2026, 12).lastDay, const Day(2026, 12, 31));
    });

    test('contains only its own days', () {
      expect(october.contains(const Day(2026, 10, 1)), isTrue);
      expect(october.contains(const Day(2026, 10, 31)), isTrue);
      expect(october.contains(const Day(2026, 9, 30)), isFalse);
      expect(october.contains(const Day(2026, 11, 1)), isFalse);
    });

    test('daysRemainingFrom counts today and stops at zero', () {
      expect(october.daysRemainingFrom(const Day(2026, 10, 1)), 31);
      expect(october.daysRemainingFrom(const Day(2026, 10, 31)), 1);
      expect(october.daysRemainingFrom(const Day(2026, 9, 15)), 31);
      expect(october.daysRemainingFrom(const Day(2026, 11, 1)), 0);
    });

    test('round-trips through its string form', () {
      expect(october.toString(), '2026-10');
      expect(Month.parse('2026-10'), october);
      expect(Month.parse('2026-01'), const Month(2026, 1));
    });

    test('rejects malformed month strings', () {
      for (final bad in <String>['', '2026', '2026-13', '2026-00', 'x-01']) {
        expect(() => Month.parse(bad), throwsFormatException, reason: bad);
      }
    });

    test('through is inclusive and empty when inverted', () {
      expect(october.through(december).length, 3);
      expect(december.through(october), isEmpty);
      expect(october.through(october).length, 1);
    });
  });

  group('a single month', () {
    test('allocation minus spending is what is left', () {
      final budget = Budget(
        envelopes: <Envelope>[
          env('groceries', allocation: 400000),
          env('transport', allocation: 100000),
        ],
        transactions: <Txn>[
          spend('t1', 'groceries', 125000, const Day(2026, 10, 3)),
          spend('t2', 'groceries', 75000, const Day(2026, 10, 14)),
          spend('t3', 'transport', 55000, const Day(2026, 10, 9)),
        ],
        plans: <String, MonthPlan>{
          '2026-10': const MonthPlan(incomeMinor: 3000000),
        },
      );

      final report = Projection.forMonth(budget, october);
      final groceries = report.envelopes.firstWhere(
        (e) => e.envelope.id == 'groceries',
      );

      expect(groceries.allocated, won(400000));
      expect(groceries.spent, won(200000));
      expect(groceries.remaining, won(200000));
      expect(groceries.overspent, isFalse);
      expect(groceries.usedFraction, 0.5);

      expect(report.spentTotal, won(255000));
      expect(report.allocatedTotal, won(500000));
      expect(report.remainingTotal, won(245000));
      expect(report.income, won(3000000));
      expect(report.unallocated, won(2500000));
    });

    test('a month-specific allocation overrides the envelope default', () {
      final budget = Budget(
        envelopes: <Envelope>[env('groceries', allocation: 400000)],
        plans: <String, MonthPlan>{
          '2026-10': const MonthPlan(
            allocations: <String, int>{'groceries': 250000},
          ),
        },
      );

      expect(
        Projection.forMonth(budget, october).envelopes.single.allocated,
        won(250000),
      );
      // November was never touched, so it falls back to the default.
      expect(
        Projection.forMonth(budget, november).envelopes.single.allocated,
        won(400000),
      );
    });

    test('an override of zero is respected, not treated as absent', () {
      final budget = Budget(
        envelopes: <Envelope>[env('holiday', allocation: 300000)],
        plans: <String, MonthPlan>{
          '2026-10': const MonthPlan(
            allocations: <String, int>{'holiday': 0},
          ),
        },
      );
      expect(
        Projection.forMonth(budget, october).envelopes.single.allocated,
        won(0),
        reason: 'skipping a category this month is a real decision',
      );
    });

    test('overspending is reported, not hidden', () {
      final budget = Budget(
        envelopes: <Envelope>[env('dining', allocation: 100000)],
        transactions: <Txn>[
          spend('t1', 'dining', 150000, const Day(2026, 10, 20)),
        ],
      );
      final status = Projection.forMonth(budget, october).envelopes.single;

      expect(status.remaining, won(-50000));
      expect(status.overspent, isTrue);
      expect(
        status.usedFraction,
        1.0,
        reason: 'the bar fills rather than overflowing its track',
      );
      expect(
        Projection.forMonth(budget, october).overspentEnvelopes.length,
        1,
      );
    });

    test('a refund puts money back', () {
      final budget = Budget(
        envelopes: <Envelope>[env('clothes', allocation: 100000)],
        transactions: <Txn>[
          spend('t1', 'clothes', 80000, const Day(2026, 10, 5)),
          refund('t2', 'clothes', 30000, const Day(2026, 10, 12)),
        ],
      );
      final status = Projection.forMonth(budget, october).envelopes.single;
      expect(status.spent, won(50000));
      expect(status.remaining, won(50000));
    });

    test('refunds beyond spending show as negative spend rather than clamped',
        () {
      final budget = Budget(
        envelopes: <Envelope>[env('clothes', allocation: 100000)],
        transactions: <Txn>[
          spend('t1', 'clothes', 20000, const Day(2026, 10, 5)),
          refund('t2', 'clothes', 50000, const Day(2026, 10, 12)),
        ],
      );
      final status = Projection.forMonth(budget, october).envelopes.single;
      expect(status.spent, won(-30000));
      expect(status.remaining, won(130000));
    });

    test('transactions outside the month are ignored', () {
      final budget = Budget(
        envelopes: <Envelope>[env('groceries', allocation: 400000)],
        transactions: <Txn>[
          spend('t1', 'groceries', 10000, const Day(2026, 9, 30)),
          spend('t2', 'groceries', 20000, const Day(2026, 10, 1)),
          spend('t3', 'groceries', 30000, const Day(2026, 11, 1)),
        ],
      );
      expect(
        Projection.forMonth(budget, october).envelopes.single.spent,
        won(20000),
      );
    });

    test('a transaction against a deleted envelope does not crash a report',
        () {
      final budget = Budget(
        envelopes: <Envelope>[env('groceries', allocation: 100000)],
        transactions: <Txn>[
          spend('orphan', 'gone', 50000, const Day(2026, 10, 5)),
        ],
      );
      final report = Projection.forMonth(budget, october);
      expect(report.envelopes.single.envelope.id, 'groceries');
      expect(report.spentTotal, won(0));
    });

    test('an empty budget totals to zero in its own currency', () {
      final report = Projection.forMonth(
        const Budget(currency: Currency.usd),
        october,
      );
      expect(report.envelopes, isEmpty);
      expect(report.spentTotal, const Money(0, Currency.usd));
      expect(report.remainingTotal, const Money(0, Currency.usd));
      expect(report.unallocated, const Money(0, Currency.usd));
    });
  });

  group('rollover', () {
    Budget budgetWith({required bool rollover}) => Budget(
      envelopes: <Envelope>[
        env('savings', allocation: 100000, rollover: rollover),
      ],
      transactions: <Txn>[
        spend('t1', 'savings', 30000, const Day(2026, 10, 10)),
      ],
    );

    test('carries a surplus forward when enabled', () {
      final report = Projection.forMonth(budgetWith(rollover: true), november);
      final status = report.envelopes.single;
      expect(status.rolloverIn, won(70000));
      expect(status.available, won(170000));
      expect(status.remaining, won(170000));
    });

    test('drops the surplus when disabled', () {
      final report = Projection.forMonth(budgetWith(rollover: false), november);
      expect(report.envelopes.single.rolloverIn, won(0));
      expect(report.envelopes.single.remaining, won(100000));
    });

    test('carries overspending forward as a debt', () {
      // An envelope that forgives going over at midnight on the 31st is a
      // tally, not a budget.
      final budget = Budget(
        envelopes: <Envelope>[
          env('dining', allocation: 100000, rollover: true),
        ],
        transactions: <Txn>[
          spend('t1', 'dining', 160000, const Day(2026, 10, 20)),
        ],
      );
      final status = Projection.forMonth(budget, november).envelopes.single;
      expect(status.rolloverIn, won(-60000));
      expect(status.remaining, won(40000));
    });

    test('accumulates across several months', () {
      final budget = Budget(
        envelopes: <Envelope>[
          env('savings', allocation: 100000, rollover: true),
        ],
      );
      expect(
        Projection.forMonth(budget, october).envelopes.single.rolloverIn,
        won(0),
        reason: 'nothing before the first month with any history',
      );
      expect(
        Projection.forMonth(
          budget.copyWith(
            plans: <String, MonthPlan>{'2026-10': const MonthPlan()},
          ),
          december,
        ).envelopes.single.rolloverIn,
        won(200000),
        reason: 'October and November each left 100000 behind',
      );
    });

    test('a long gap between months still accumulates correctly', () {
      final budget = Budget(
        envelopes: <Envelope>[
          env('savings', allocation: 50000, rollover: true),
        ],
        transactions: <Txn>[
          spend('t1', 'savings', 10000, const Day(2025, 1, 15)),
        ],
      );
      // Jan 2025 left 40000; Feb 2025 through Dec 2025 added 50000 each.
      final status = Projection.forMonth(
        budget,
        const Month(2026, 1),
      ).envelopes.single;
      expect(status.rolloverIn, won(40000 + 50000 * 11));
    });

    test('the walk is bounded so an absurd date cannot freeze the app', () {
      final budget = Budget(
        envelopes: <Envelope>[env('x', allocation: 1000, rollover: true)],
        transactions: <Txn>[
          // A plausible typo for 2026.
          spend('t1', 'x', 500, const Day(226, 10, 5)),
        ],
      );
      final stopwatch = Stopwatch()..start();
      final report = Projection.forMonth(budget, october);
      stopwatch.stop();

      expect(report.envelopes, hasLength(1));
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));
      expect(
        report.envelopes.single.rolloverIn,
        won(Projection.maxMonthsWalked * 1000),
        reason: 'exactly the capped number of months were walked',
      );
    });

    test('a series is consistent with computing each month on its own', () {
      final budget = Budget(
        envelopes: <Envelope>[
          env('a', allocation: 70000, rollover: true),
          env('b', allocation: 30000),
        ],
        transactions: <Txn>[
          spend('t1', 'a', 20000, const Day(2026, 10, 4)),
          spend('t2', 'b', 40000, const Day(2026, 11, 4)),
          spend('t3', 'a', 10000, const Day(2026, 12, 4)),
        ],
      );
      final series = Projection.series(budget, october, december);
      expect(series.map((r) => r.month), <Month>[october, november, december]);

      for (final report in series) {
        final alone = Projection.forMonth(budget, report.month);
        expect(report.remainingTotal, alone.remainingTotal,
            reason: '${report.month}');
        for (var i = 0; i < report.envelopes.length; i++) {
          expect(
            report.envelopes[i].rolloverIn,
            alone.envelopes[i].rolloverIn,
            reason: '${report.month} ${report.envelopes[i].envelope.id}',
          );
        }
      }
    });

    test('an inverted range yields nothing', () {
      expect(Projection.series(const Budget(), december, october), isEmpty);
    });
  });

  group('archived envelopes', () {
    test('disappear from months where nothing happened to them', () {
      final budget = Budget(
        envelopes: <Envelope>[
          env('old', allocation: 50000, archived: true),
          env('current', allocation: 100000),
        ],
        transactions: <Txn>[
          spend('t1', 'old', 20000, const Day(2026, 10, 7)),
        ],
      );

      final october2026 = Projection.forMonth(budget, october);
      expect(
        october2026.envelopes.map((e) => e.envelope.id),
        containsAll(<String>['old', 'current']),
        reason: 'October has a transaction against the archived envelope',
      );

      final nov = Projection.forMonth(budget, november);
      expect(
        nov.envelopes.map((e) => e.envelope.id),
        <String>['current'],
        reason: 'archiving tidies future months without rewriting old ones',
      );
    });

    test('still carry their rollover while they have one', () {
      final budget = Budget(
        envelopes: <Envelope>[
          env('old', allocation: 0, rollover: true, archived: true),
        ],
        transactions: <Txn>[
          refund('t1', 'old', 25000, const Day(2026, 10, 7)),
        ],
      );
      final nov = Projection.forMonth(budget, november);
      expect(nov.envelopes.single.rolloverIn, won(25000));
    });
  });

  group('safe to spend per day', () {
    MonthReport reportWith(int remaining) => MonthReport(
      month: october,
      currency: krw,
      income: won(0),
      envelopes: <EnvelopeStatus>[
        EnvelopeStatus(
          envelope: env('x', allocation: remaining),
          allocated: won(remaining),
          rolloverIn: won(0),
          spent: won(0),
        ),
      ],
    );

    test('divides what is left by the days that are left', () {
      // 310000 left with 31 days in October, viewed on the 1st.
      expect(
        reportWith(310000).safeToSpendPerDay(const Day(2026, 10, 1)),
        won(10000),
      );
      // Same money, viewed on the 21st: 11 days left.
      expect(
        reportWith(310000).safeToSpendPerDay(const Day(2026, 10, 21)),
        won(28181),
      );
    });

    test('rounds down so the figure is always affordable', () {
      expect(
        reportWith(100).safeToSpendPerDay(const Day(2026, 10, 1)),
        won(3),
        reason: '100/31 is 3.2; spending 4 a day would run out',
      );
    });

    test('rounds a deficit away from zero', () {
      expect(
        reportWith(-100).safeToSpendPerDay(const Day(2026, 10, 1)),
        won(-4),
        reason: 'understating a shortfall is the wrong direction to err',
      );
    });

    test('is the whole month when looking ahead', () {
      expect(
        reportWith(310000).safeToSpendPerDay(const Day(2026, 9, 15)),
        won(10000),
      );
    });

    test('is null once the month is over', () {
      expect(
        reportWith(310000).safeToSpendPerDay(const Day(2026, 11, 1)),
        isNull,
      );
    });
  });

  group('reporting helpers', () {
    final budget = Budget(
      envelopes: <Envelope>[
        env('groceries', allocation: 400000, slot: 0),
        env('transport', allocation: 100000, slot: 1),
      ],
      transactions: <Txn>[
        spend('t1', 'groceries', 100000, const Day(2026, 10, 3)),
        spend('t2', 'groceries', 50000, const Day(2026, 11, 3)),
        spend('t3', 'transport', 30000, const Day(2026, 10, 9)),
        refund('t4', 'groceries', 10000, const Day(2026, 10, 20)),
      ],
    );

    test('spentByEnvelope totals over a range', () {
      final october2026 = Projection.spentByEnvelope(
        budget,
        from: october,
        to: october,
      );
      expect(october2026['groceries'], won(90000));
      expect(october2026['transport'], won(30000));

      final both = Projection.spentByEnvelope(
        budget,
        from: october,
        to: november,
      );
      expect(both['groceries'], won(140000));
    });

    test('dailySpend covers every day of the month, zeroes included', () {
      final daily = Projection.dailySpend(budget, october);
      expect(daily.length, 31);
      expect(daily.first.$1, const Day(2026, 10, 1));
      expect(daily.last.$1, const Day(2026, 10, 31));
      expect(
        daily.firstWhere((e) => e.$1 == const Day(2026, 10, 3)).$2,
        won(100000),
      );
      expect(
        daily.firstWhere((e) => e.$1 == const Day(2026, 10, 20)).$2,
        won(-10000),
        reason: 'a refund day shows negative spend',
      );
      expect(daily.where((e) => e.$2.isZero).length, 28);
    });

    test('transactionsIn is newest first and deterministic', () {
      final listed = budget.transactionsIn(october);
      expect(listed.map((t) => t.id), <String>['t4', 't3', 't1']);
    });
  });
}
