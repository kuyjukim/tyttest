// Entry point used only to render store screenshots.
//
// Store screenshots have to be deterministic - the same numbers, the same
// month, the same day of the month - or every regeneration produces a set
// that no longer matches the captions written for it. This entry point pins
// the clock, seeds a realistic household budget in memory and never touches
// the disk, so it can also run in a browser where `path_provider` cannot.
//
// It is deliberately a separate `-t` target rather than a debug flag in
// `main.dart`: demo data must not be reachable from the shipped binary.
import 'package:flutter/material.dart';
import 'package:paper/paper.dart';

import 'app.dart';
import 'data/budget_repository.dart';
import 'domain/envelope.dart';
import 'domain/money.dart';
import 'state/budget_store.dart';

/// The day every screenshot is taken on: far enough into the month that the
/// envelopes have real spending in them, with enough left that "safe to
/// spend per day" is a number worth showing.
final DateTime _screenshotDay = DateTime(2026, 10, 18, 10, 30);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final store = BudgetStore(
    repository: BudgetRepository(MemoryStore()),
    clock: () => _screenshotDay,
    idFactory: _sequentialId,
  );
  await store.initialize();
  await _seed(store);

  // `?lang=en` renders the English set from the same build.
  final language = Uri.base.queryParameters['lang'] == 'en' ? 'en' : 'ko';

  runApp(LedgerApp(store: store, locale: Locale(language)));
}

var _counter = 0;
String _sequentialId() => 'demo-${(_counter++).toString().padLeft(4, '0')}';

/// A month in the life of a two-person household in Seoul.
Future<void> _seed(BudgetStore store) async {
  const krw = Currency.krw;
  Money won(int amount) => Money(amount, krw);

  final envelopes = <(String ko, String en, int budget, bool rollover)>[
    ('식비', 'Groceries', 600000, false),
    ('주거·관리비', 'Housing', 850000, false),
    ('교통', 'Transport', 120000, false),
    ('문화생활', 'Going out', 150000, false),
    ('의료', 'Health', 100000, false),
    ('모임', 'Friends', 180000, false),
    ('저축', 'Savings', 800000, true),
  ];

  final created = <String, Envelope>{};
  for (final (ko, _, budget, rollover) in envelopes) {
    created[ko] = await store.addEnvelope(
      name: ko,
      allocation: won(budget),
      rollover: rollover,
    );
  }

  await store.setIncome(won(3200000));

  // Spending that tells a story: housing is fully spent because it is a
  // fixed bill, going out has gone over, and savings is untouched.
  final spending = <(String envelope, int amount, int day, String note)>[
    ('주거·관리비', 850000, 1, '월세·관리비'),
    ('식비', 96000, 2, '장보기'),
    ('교통', 24000, 3, '교통카드 충전'),
    ('문화생활', 68000, 4, '공연'),
    ('식비', 42000, 6, '마트'),
    ('모임', 56000, 7, '저녁 모임'),
    ('식비', 18000, 8, '점심'),
    ('교통', 24000, 9, '교통카드 충전'),
    ('의료', 24000, 10, '약국'),
    ('식비', 104000, 11, '장보기'),
    ('문화생활', 97000, 12, '영화·저녁'),
    ('모임', 40000, 14, '커피'),
    ('식비', 62000, 15, '마트'),
    ('교통', 20000, 16, '택시'),
    ('식비', 90000, 17, '장보기'),
    ('식비', 32000, 18, '점심'),
  ];

  for (final (envelope, amount, day, note) in spending) {
    await store.addSpend(
      envelopeId: created[envelope]!.id,
      amount: won(amount),
      date: Day(2026, 10, day),
      note: note,
    );
  }

  // One refund, so the transaction list shows both signs.
  await store.addRefund(
    envelopeId: created['문화생활']!.id,
    amount: won(12000),
    date: const Day(2026, 10, 13),
    note: '예매 취소 환불',
  );
}
