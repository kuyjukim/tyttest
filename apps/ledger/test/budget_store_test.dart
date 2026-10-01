import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/data/budget_repository.dart';

import 'package:ledger/domain/money.dart';
import 'package:ledger/domain/month.dart';
import 'package:ledger/state/budget_store.dart';
import 'package:paper/paper.dart';

const _key = 'ledger.budget.v1';
const krw = Currency.krw;

Money won(int amount) => Money(amount, krw);

class FakeClock {
  DateTime now = DateTime(2026, 10, 15, 9);
  void advance(Duration by) => now = now.add(by);
}

({BudgetStore store, FakeClock clock, MemoryStore raw}) build({
  Map<String, String>? seed,
}) {
  final clock = FakeClock();
  final raw = MemoryStore(seed);
  var id = 0;
  return (
    store: BudgetStore(
      repository: BudgetRepository(raw),
      clock: () => clock.now,
      idFactory: () => 'id-${(id++).toString().padLeft(3, '0')}',
    ),
    clock: clock,
    raw: raw,
  );
}

void main() {
  group('initialize', () {
    test('starts empty on the current month', () async {
      final (store: store, clock: _, raw: _) = build();
      await store.initialize();

      expect(store.ready, isTrue);
      expect(store.month, const Month(2026, 10));
      expect(store.isViewingCurrentMonth, isTrue);
      expect(store.budget.envelopes, isEmpty);
      expect(store.report.remainingTotal, won(0));
    });

    test('opens anyway when the stored file is corrupt', () async {
      final (store: store, clock: _, raw: _) = build(
        seed: {_key: 'not json at all'},
      );
      await store.initialize();
      expect(store.ready, isTrue);
      expect(store.budget.envelopes, isEmpty);
    });

    test('keeps the readable records when one transaction is damaged',
        () async {
      final payload = jsonEncode(<String, Object?>{
        'version': 1,
        'currency': 'KRW',
        'envelopes': <Object?>[
          <String, Object?>{
            'id': 'e1',
            'name': 'Groceries',
            'slot': 0,
            'allocationMinor': 100000,
          },
          'not a map',
        ],
        'transactions': <Object?>[
          <String, Object?>{
            'id': 't1',
            'envelopeId': 'e1',
            'date': '2026-10-02',
            'amountMinor': -5000,
          },
          <String, Object?>{'id': 'broken'},
        ],
        'plans': <String, Object?>{
          '2026-10': <String, Object?>{'incomeMinor': 1000},
          'not-a-month': 'junk',
        },
      });
      final (store: store, clock: _, raw: _) = build(seed: {_key: payload});
      await store.initialize();

      expect(store.budget.envelopes.map((e) => e.id), <String>['e1']);
      expect(store.budget.transactions.map((t) => t.id), <String>['t1']);
      expect(store.budget.planFor(const Month(2026, 10)).incomeMinor, 1000);
    });

    test('an out-of-range stored colour slot is clamped, not trusted',
        () async {
      final payload = jsonEncode(<String, Object?>{
        'version': 1,
        'envelopes': <Object?>[
          <String, Object?>{
            'id': 'e1',
            'name': 'X',
            'slot': 999,
            'allocationMinor': 0,
          },
        ],
      });
      final (store: store, clock: _, raw: _) = build(seed: {_key: payload});
      await store.initialize();
      expect(store.budget.envelopes.single.slot, lessThan(Viz.slots));
    });
  });

  group('envelopes', () {
    test('are created with the next free colour slot in order', () async {
      final (store: store, clock: _, raw: _) = build();
      await store.initialize();

      for (var i = 0; i < 3; i++) {
        await store.addEnvelope(name: 'Envelope $i', allocation: won(1000));
      }
      expect(store.budget.envelopes.map((e) => e.slot), <int>[0, 1, 2]);
    });

    test('a deleted slot is reused before the palette is exhausted',
        () async {
      final (store: store, clock: _, raw: _) = build();
      await store.initialize();
      final a = await store.addEnvelope(name: 'A', allocation: won(0));
      await store.addEnvelope(name: 'B', allocation: won(0));
      await store.deleteEnvelope(a.id);

      final c = await store.addEnvelope(name: 'C', allocation: won(0));
      expect(c.slot, 0, reason: 'slot 0 is free again');
    });

    test('names are trimmed', () async {
      final (store: store, clock: _, raw: _) = build();
      await store.initialize();
      final envelope = await store.addEnvelope(
        name: '  Groceries  ',
        allocation: won(0),
      );
      expect(envelope.name, 'Groceries');
    });

    test('archiving keeps history, deleting takes the transactions too',
        () async {
      final (store: store, clock: _, raw: _) = build();
      await store.initialize();
      final envelope = await store.addEnvelope(
        name: 'Dining',
        allocation: won(100000),
      );
      await store.addSpend(
        envelopeId: envelope.id,
        amount: won(30000),
        date: const Day(2026, 10, 3),
      );

      await store.archiveEnvelope(envelope.id);
      expect(store.budget.transactions, hasLength(1));
      expect(store.report.spentTotal, won(30000));

      await store.deleteEnvelope(envelope.id);
      expect(store.budget.transactions, isEmpty);
      expect(store.budget.envelopes, isEmpty);
    });

    test('archiving and unarchiving an unknown id is a no-op', () async {
      final (store: store, clock: _, raw: _) = build();
      await store.initialize();
      await store.archiveEnvelope('nope');
      await store.unarchiveEnvelope('nope');
      expect(store.budget.envelopes, isEmpty);
    });
  });

  group('transactions', () {
    test('a spend is stored negative and a refund positive', () async {
      final (store: store, clock: _, raw: _) = build();
      await store.initialize();
      final envelope = await store.addEnvelope(
        name: 'Groceries',
        allocation: won(400000),
      );

      final spend = await store.addSpend(
        envelopeId: envelope.id,
        amount: won(50000),
        date: const Day(2026, 10, 4),
        note: '  market  ',
      );
      final refund = await store.addRefund(
        envelopeId: envelope.id,
        amount: won(10000),
        date: const Day(2026, 10, 6),
      );

      expect(spend.amountMinor, -50000);
      expect(spend.note, 'market', reason: 'notes are trimmed');
      expect(refund.amountMinor, 10000);
      expect(store.report.spentTotal, won(40000));
      expect(store.report.remainingTotal, won(360000));
    });

    test('a negative amount handed to addSpend is still a spend', () async {
      final (store: store, clock: _, raw: _) = build();
      await store.initialize();
      final envelope = await store.addEnvelope(name: 'X', allocation: won(0));

      final txn = await store.addSpend(
        envelopeId: envelope.id,
        amount: won(-5000),
        date: const Day(2026, 10, 4),
      );
      expect(
        txn.amountMinor,
        -5000,
        reason: 'the sign is the method\'s business, not the caller\'s',
      );
    });

    test('are edited and deleted in place, and persist', () async {
      final (store: store, clock: _, raw: raw) = build();
      await store.initialize();
      final envelope = await store.addEnvelope(name: 'X', allocation: won(0));
      final txn = await store.addSpend(
        envelopeId: envelope.id,
        amount: won(5000),
        date: const Day(2026, 10, 4),
      );

      await store.updateTxn(txn.copyWith(amountMinor: -7000, note: 'fixed'));
      expect(store.budget.transactions.single.amountMinor, -7000);

      final reloaded = await BudgetRepository(raw).load();
      expect(reloaded.transactions.single.note, 'fixed');

      await store.deleteTxn(txn.id);
      expect(store.budget.transactions, isEmpty);
    });

    test('are listed for the month on screen only', () async {
      final (store: store, clock: _, raw: _) = build();
      await store.initialize();
      final envelope = await store.addEnvelope(name: 'X', allocation: won(0));
      await store.addSpend(
        envelopeId: envelope.id,
        amount: won(1000),
        date: const Day(2026, 10, 4),
      );
      await store.addSpend(
        envelopeId: envelope.id,
        amount: won(2000),
        date: const Day(2026, 11, 4),
      );

      expect(store.monthTransactions, hasLength(1));
      store.showNextMonth();
      expect(store.monthTransactions, hasLength(1));
      expect(store.monthTransactions.single.amountMinor, -2000);
    });
  });

  group('month navigation', () {
    test('moves back and forward and returns to today', () async {
      final (store: store, clock: _, raw: _) = build();
      await store.initialize();

      store.showPreviousMonth();
      expect(store.month, const Month(2026, 9));
      expect(store.isViewingCurrentMonth, isFalse);

      store.showNextMonth();
      store.showNextMonth();
      expect(store.month, const Month(2026, 11));

      store.showCurrentMonth();
      expect(store.month, const Month(2026, 10));
      expect(store.isViewingCurrentMonth, isTrue);
    });

    test('crosses a year boundary', () async {
      final (store: store, clock: clock, raw: _) = build();
      clock.now = DateTime(2026, 1, 10);
      await store.initialize();
      store.showPreviousMonth();
      expect(store.month, const Month(2025, 12));
    });

    test('notifies only when the month actually changes', () async {
      final (store: store, clock: _, raw: _) = build();
      await store.initialize();
      var notifications = 0;
      store.addListener(() => notifications++);

      store.showMonth(store.month);
      expect(notifications, 0);

      store.showNextMonth();
      expect(notifications, 1);
    });

    test('plan edits apply to the month on screen, not to today', () async {
      final (store: store, clock: _, raw: _) = build();
      await store.initialize();
      final envelope = await store.addEnvelope(name: 'X', allocation: won(100));

      store.showNextMonth();
      await store.setAllocation(envelope.id, won(900));
      await store.setIncome(won(5000));

      expect(store.report.envelopes.single.allocated, won(900));
      expect(store.report.income, won(5000));

      store.showPreviousMonth();
      expect(store.report.envelopes.single.allocated, won(100));
      expect(store.report.income, won(0));
    });
  });

  group('moveAllocation', () {
    test('takes from one envelope and gives to another, total unchanged',
        () async {
      final (store: store, clock: _, raw: _) = build();
      await store.initialize();
      final groceries = await store.addEnvelope(
        name: 'Groceries',
        allocation: won(300000),
      );
      final dining = await store.addEnvelope(
        name: 'Dining',
        allocation: won(100000),
      );
      final totalBefore = store.report.allocatedTotal;

      await store.moveAllocation(
        fromEnvelopeId: dining.id,
        toEnvelopeId: groceries.id,
        amount: won(40000),
      );

      final report = store.report;
      expect(
        report.envelopes.firstWhere((e) => e.envelope.id == groceries.id)
            .allocated,
        won(340000),
      );
      expect(
        report.envelopes.firstWhere((e) => e.envelope.id == dining.id)
            .allocated,
        won(60000),
      );
      expect(report.allocatedTotal, totalBefore);
    });

    test('only touches the month on screen', () async {
      final (store: store, clock: _, raw: _) = build();
      await store.initialize();
      final a = await store.addEnvelope(name: 'A', allocation: won(1000));
      final b = await store.addEnvelope(name: 'B', allocation: won(1000));

      await store.moveAllocation(
        fromEnvelopeId: a.id,
        toEnvelopeId: b.id,
        amount: won(400),
      );
      store.showNextMonth();

      expect(
        store.report.envelopes.map((e) => e.allocated),
        <Money>[won(1000), won(1000)],
        reason: 'next month still has the defaults',
      );
    });

    test('a move to the same envelope or of nothing is ignored', () async {
      final (store: store, clock: _, raw: _) = build();
      await store.initialize();
      final a = await store.addEnvelope(name: 'A', allocation: won(1000));
      final b = await store.addEnvelope(name: 'B', allocation: won(1000));

      await store.moveAllocation(
        fromEnvelopeId: a.id,
        toEnvelopeId: a.id,
        amount: won(100),
      );
      await store.moveAllocation(
        fromEnvelopeId: a.id,
        toEnvelopeId: b.id,
        amount: won(0),
      );

      expect(store.budget.plans, isEmpty, reason: 'no plan was written');
    });

    test('moving more than an envelope has leaves it negative, visibly',
        () async {
      final (store: store, clock: _, raw: _) = build();
      await store.initialize();
      final a = await store.addEnvelope(name: 'A', allocation: won(1000));
      final b = await store.addEnvelope(name: 'B', allocation: won(0));

      await store.moveAllocation(
        fromEnvelopeId: a.id,
        toEnvelopeId: b.id,
        amount: won(1500),
      );

      final report = store.report;
      expect(
        report.envelopes.firstWhere((e) => e.envelope.id == a.id).allocated,
        won(-500),
        reason: 'the app shows the hole rather than refusing the move',
      );
      expect(report.allocatedTotal, won(1000));
    });
  });

  group('safe to spend', () {
    test('reflects the day of the month', () async {
      final (store: store, clock: clock, raw: _) = build();
      await store.initialize();
      await store.addEnvelope(name: 'Everything', allocation: won(310000));

      // The 15th of a 31-day month: 17 days left including today.
      expect(store.safeToSpendPerDay, won(310000 ~/ 17));

      clock.now = DateTime(2026, 10, 31, 9);
      store.showCurrentMonth();
      expect(store.safeToSpendPerDay, won(310000));
    });

    test('is null for a month that has passed', () async {
      final (store: store, clock: _, raw: _) = build();
      await store.initialize();
      await store.addEnvelope(name: 'Everything', allocation: won(310000));

      store.showPreviousMonth();
      expect(store.safeToSpendPerDay, isNull);
    });
  });

  group('currency', () {
    test('changing it leaves the stored minor units alone', () async {
      final (store: store, clock: _, raw: _) = build();
      await store.initialize();
      final envelope = await store.addEnvelope(
        name: 'X',
        allocation: won(150000),
      );
      await store.addSpend(
        envelopeId: envelope.id,
        amount: won(50000),
        date: const Day(2026, 10, 2),
      );

      await store.setCurrency(Currency.usd);

      // 150000 minor units are now $1,500.00 rather than ₩150,000. There is
      // no rate to convert with offline, so the numbers are left as they are
      // and the UI warns before this happens.
      expect(store.currency, Currency.usd);
      expect(
        store.report.envelopes.single.allocated,
        const Money(150000, Currency.usd),
      );
      expect(store.report.spentTotal, const Money(50000, Currency.usd));
    });

    test('setting the same currency does not rewrite the file', () async {
      final (store: store, clock: _, raw: raw) = build();
      await store.initialize();
      await store.setCurrency(krw);
      expect(raw.snapshot[_key], isNull, reason: 'nothing was written');
    });
  });

  group('persistence', () {
    test('survives a cold start', () async {
      final (store: first, clock: _, raw: raw) = build();
      await first.initialize();
      final envelope = await first.addEnvelope(
        name: 'Groceries',
        allocation: won(400000),
        rollover: true,
      );
      await first.addSpend(
        envelopeId: envelope.id,
        amount: won(125000),
        date: const Day(2026, 10, 3),
      );
      await first.setIncome(won(3000000));

      final (store: second, clock: _, raw: _) = build(seed: raw.snapshot);
      await second.initialize();

      expect(second.budget.envelopes.single.name, 'Groceries');
      expect(second.budget.envelopes.single.rollover, isTrue);
      expect(second.report.spentTotal, won(125000));
      expect(second.report.income, won(3000000));
      expect(second.report.remainingTotal, won(275000));
    });

    test('clearEverything keeps the currency and the theme', () async {
      final (store: store, clock: _, raw: _) = build();
      await store.initialize();
      await store.setCurrency(Currency.usd);
      await store.addEnvelope(
        name: 'X',
        allocation: const Money(1000, Currency.usd),
      );

      await store.clearEverything();

      expect(store.budget.envelopes, isEmpty);
      expect(store.budget.transactions, isEmpty);
      expect(store.currency, Currency.usd);
    });
  });
}
