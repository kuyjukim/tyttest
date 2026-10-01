// Renders store screenshots at device resolution.
//
// Run with:
//   flutter test tool/screenshots.dart --update-goldens
//
// This is a test file rather than a normal entry point because the test
// harness is the only way to rasterise the real widget tree to a PNG without
// a device: it gives an exact logical size, an exact device pixel ratio, and
// a deterministic frame. The web build was the first attempt and was the
// wrong tool - CanvasKit fetches its fonts from Google's CDN, so on a network
// that does not allow that out, every screenshot came back with the layout
// drawn and every glyph missing.
//
// Fonts are loaded from the host rather than bundled, so the shipped app
// keeps using the platform face.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ledger/app.dart';
import 'package:ledger/data/budget_repository.dart';
import 'package:ledger/domain/envelope.dart';
import 'package:ledger/domain/money.dart';
import 'package:ledger/state/budget_store.dart';
import 'package:paper/paper.dart';

/// 6.9" iPhone, the size App Store Connect asks for.
const Size kDevicePixels = Size(1320, 2868);
const double kDevicePixelRatio = 3;

/// The text face: one font that covers both scripts, and only one.
///
/// Mixing a Latin-only face into the same family does not work the way it
/// looks like it should. With Roboto also registered as `Roboto`, the
/// regular weight matched Roboto and stopped there, so every w400 Korean
/// label rendered as empty boxes while the w500 ones - which matched nothing
/// exactly and fell through - were fine. One face with full coverage has no
/// weight at which it can fail.
const List<String> _textFonts = <String>[
  '/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc',
];

/// Material's icon font, which the test harness does not load by default -
/// without it every icon in the screenshots is an empty box.
const List<String> _iconFonts = <String>[
  '/opt/fl/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
];

Future<int> _loadFamily(String family, List<String> paths) async {
  final loader = FontLoader(family);
  var loaded = 0;
  for (final path in paths) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final bytes = await file.readAsBytes();
    loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
    loaded++;
  }
  if (loaded > 0) await loader.load();
  return loaded;
}

Future<void> _loadFonts() async {
  // Date symbols, or a DateFormat built for 'ko' throws before it can render.
  await initializeDateFormatting();

  final text = await _loadFamily('Roboto', _textFonts);
  final icons = await _loadFamily('MaterialIcons', _iconFonts);
  if (text == 0 || icons == 0) {
    throw StateError(
      'Missing fonts (text: $text, icons: $icons). Screenshots would render '
      'with boxes instead of glyphs, which is worse than failing outright.',
    );
  }
}

/// The day every screenshot is taken on, so regenerating gives the same set.
final DateTime _day = DateTime(2026, 10, 18, 10, 30);

Future<BudgetStore> _seededStore() async {
  var id = 0;
  final store = BudgetStore(
    repository: BudgetRepository(MemoryStore()),
    clock: () => _day,
    idFactory: () => 'demo-${(id++).toString().padLeft(4, '0')}',
  );
  await store.initialize();

  const krw = Currency.krw;
  Money won(int amount) => Money(amount, krw);

  final envelopes = <String, Envelope>{};
  for (final (name, budget, rollover) in <(String, int, bool)>[
    ('식비', 600000, false),
    ('주거·관리비', 850000, false),
    ('교통', 120000, false),
    ('문화생활', 150000, false),
    ('의료', 100000, false),
    ('모임', 180000, false),
    ('저축', 800000, true),
  ]) {
    envelopes[name] = await store.addEnvelope(
      name: name,
      allocation: won(budget),
      rollover: rollover,
    );
  }
  await store.setIncome(won(3200000));

  // Spending that tells a story: housing is a fixed bill and fully spent,
  // going out has gone over, savings is untouched.
  for (final (envelope, amount, day, note) in <(String, int, int, String)>[
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
  ]) {
    await store.addSpend(
      envelopeId: envelopes[envelope]!.id,
      amount: won(amount),
      date: Day(2026, 10, day),
      note: note,
    );
  }
  // One refund, so the list shows both signs.
  await store.addRefund(
    envelopeId: envelopes['문화생활']!.id,
    amount: won(12000),
    date: const Day(2026, 10, 13),
    note: '예매 취소 환불',
  );

  return store;
}

void main() {
  setUpAll(_loadFonts);

  Future<void> shoot(
    WidgetTester tester,
    String name, {
    required Locale locale,
    Brightness brightness = Brightness.light,
    Future<void> Function(WidgetTester tester)? after,
  }) async {
    tester.view
      ..physicalSize = kDevicePixels
      ..devicePixelRatio = kDevicePixelRatio;
    tester.platformDispatcher.platformBrightnessTestValue = brightness;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    final store = await _seededStore();
    addTearDown(store.dispose);

    await tester.pumpWidget(
      LedgerApp(store: store, locale: locale, fontFamily: 'Roboto'),
    );
    await tester.pumpAndSettle();
    if (after != null) {
      await after(tester);
      await tester.pumpAndSettle();
    }

    await expectLater(
      find.byType(LedgerApp),
      matchesGoldenFile('../store/screenshots/$name.png'),
    );
  }

  /// Switches tab by its localised label, which is also a check that the
  /// label is where the screenshot says it is.
  Future<void> Function(WidgetTester) tab(String label) =>
      (tester) async => tester.tap(find.text(label).last);

  group('Korean', () {
    const ko = Locale('ko');
    testWidgets('budget', (t) => shoot(t, 'ko-1-budget', locale: ko));
    testWidgets('spending',
        (t) => shoot(t, 'ko-2-spending', locale: ko, after: tab('지출')));
    testWidgets('reports',
        (t) => shoot(t, 'ko-3-reports', locale: ko, after: tab('리포트')));
    testWidgets('settings',
        (t) => shoot(t, 'ko-4-settings', locale: ko, after: tab('설정')));
    testWidgets('dark', (t) => shoot(
          t,
          'ko-5-dark',
          locale: ko,
          brightness: Brightness.dark,
        ));
  });

  group('English', () {
    const en = Locale('en');
    testWidgets('budget', (t) => shoot(t, 'en-1-budget', locale: en));
    testWidgets('spending',
        (t) => shoot(t, 'en-2-spending', locale: en, after: tab('Spending')));
    testWidgets('reports',
        (t) => shoot(t, 'en-3-reports', locale: en, after: tab('Reports')));
  });
}
