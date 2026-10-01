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
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  final fontFamily = await _loadFont();

  runApp(
    LedgerApp(store: store, locale: Locale(language), fontFamily: fontFamily),
  );
}

/// The browser has no Korean system face to lend the app, and CanvasKit's
/// own answer - fetching Noto subsets from fonts.gstatic.com as it meets
/// glyphs it cannot draw - fails behind any strict content security policy
/// and leaves the interface blank. So the demo carries its own face, built
/// by `tool/make_demo_fonts.py` into `web/fonts/`.
///
/// Returns null if the fonts cannot be fetched. That is not fatal: the app
/// then renders in whatever CanvasKit resolves, which is the behaviour we
/// would have had anyway, and a demo that is wrongly set beats one that
/// never starts.
Future<String?> _loadFont() async {
  const family = 'Noto Sans KR';
  try {
    final loader = FontLoader(family);
    // One file per weight. FontLoader registers them under a single family
    // and Skia matches on each face's own OS/2 weight, so the type scale
    // keeps working without naming the files.
    for (final weight in const [400, 600]) {
      loader.addFont(_fetchBytes('fonts/NotoSansKR-$weight.ttf'));
    }
    await loader.load();
    return family;
  } catch (error) {
    debugPrint('demo: falling back to the default font ($error)');
    return null;
  }
}

Future<ByteData> _fetchBytes(String url) async {
  final response = await _fetch(url).toDart;
  if (!response.ok) {
    throw StateError('GET $url -> ${response.status}');
  }
  final buffer = await response.arrayBuffer().toDart;
  return ByteData.view(buffer.toDart);
}

@JS('fetch')
external JSPromise<_Response> _fetch(String url);

extension type _Response._(JSObject _) implements JSObject {
  external bool get ok;
  external int get status;
  external JSPromise<JSArrayBuffer> arrayBuffer();
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
