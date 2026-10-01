// Renders store screenshots at device resolution.
//
// Run with:
//   flutter test tool/screenshots.dart --update-goldens
//
// A test file rather than a normal entry point because the test harness is
// the only way to rasterise the real widget tree to a PNG without a device:
// it gives an exact logical size, an exact device pixel ratio, and a
// deterministic frame.
//
// Fonts are loaded from the host rather than bundled, so the shipped app
// keeps using the platform face.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grove/app.dart';
import 'package:grove/data/garden_repository.dart';
import 'package:grove/domain/session.dart';
import 'package:grove/domain/settings.dart';
import 'package:grove/domain/species.dart';
import 'package:grove/state/garden_store.dart';
import 'package:grove/state/session_controller.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:paper/paper.dart';

/// 6.9" iPhone, the size App Store Connect asks for.
const Size kDevicePixels = Size(1320, 2868);
const double kDevicePixelRatio = 3;

/// One face that covers both scripts, and only one.
///
/// Mixing a Latin-only face into the same family does not work the way it
/// looks like it should: with Roboto also registered as `Roboto`, the regular
/// weight matches Roboto and stops there, so every w400 Korean label renders
/// as empty boxes while the w500 ones - which match nothing exactly and fall
/// through - are fine. One face with full coverage has no weight at which it
/// can fail.
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

/// The moment every screenshot is taken at, so regenerating gives the same
/// set. Late morning, so "today" already has hours in it.
final DateTime _now = DateTime(2026, 10, 18, 11, 20);

/// Six weeks of a believable habit: mostly finished, occasionally not.
///
/// The abandoned ones are deliberate. A garden of unbroken successes is both
/// a lie and a worse screenshot - the stumps are what this app is *about*,
/// and leaving them out would sell a different product than the one that
/// ships.
GardenData _seed() {
  var id = 0;
  final sessions = <FocusSession>[];

  void session(
    int daysAgo,
    int hour,
    int minutes,
    Species species,
    String tag, {
    bool finished = true,
  }) {
    sessions.add(
      FocusSession(
        id: 'seed-${(id++).toString().padLeft(3, '0')}',
        species: species,
        planned: Duration(minutes: minutes),
        // Built from fields rather than by subtracting a Duration: a day is
        // not always 24 hours, and this set is regenerated in three zones.
        startedAt: DateTime(_now.year, _now.month, _now.day - daysAgo, hour),
        elapsed: Duration(minutes: finished ? minutes : minutes ~/ 3),
        outcome: finished ? SessionOutcome.completed : SessionOutcome.abandoned,
        tag: tag,
      ),
    );
  }

  // Today: past the daily goal, with the day still running.
  session(0, 9, 50, Species.cherry, '논문');
  session(0, 10, 25, Species.pine, '이메일');

  // The last fortnight, at a believable density.
  const recent = <(int, int, int, Species, String, bool)>[
    (1, 9, 50, Species.cherry, '논문', true),
    (1, 14, 50, Species.ginkgo, '논문', true),
    (1, 16, 25, Species.sprout, '정리', false),
    (2, 10, 50, Species.maple, '코드 리뷰', true),
    (2, 15, 50, Species.cherry, '논문', true),
    (3, 9, 25, Species.pine, '이메일', true),
    (3, 11, 50, Species.willow, '논문', true),
    (4, 13, 50, Species.ginkgo, '코드 리뷰', true),
    (4, 15, 50, Species.maple, '논문', false),
    (5, 10, 50, Species.cherry, '논문', true),
    (6, 9, 25, Species.sprout, '정리', true),
    (7, 10, 50, Species.baobab, '논문', true),
    (7, 14, 50, Species.willow, '코드 리뷰', true),
    (8, 11, 50, Species.ginkgo, '논문', true),
    (9, 9, 50, Species.cherry, '논문', true),
    (10, 16, 25, Species.pine, '이메일', false),
    (11, 10, 50, Species.maple, '논문', true),
    (12, 13, 50, Species.willow, '코드 리뷰', true),
    (13, 9, 50, Species.baobab, '논문', true),
    (14, 10, 25, Species.sprout, '정리', true),
  ];
  for (final (days, hour, minutes, species, tag, finished) in recent) {
    session(days, hour, minutes, species, tag, finished: finished);
  }

  // Further back, thinner, so the lifetime total and the species unlocks are
  // earned by the data rather than asserted by it.
  for (var week = 3; week <= 6; week++) {
    for (final day in const <int>[1, 3, 5]) {
      session(week * 7 + day, 10, 50, Species.cherry, '논문');
      session(week * 7 + day, 14, 25, Species.pine, '코드 리뷰');
    }
  }

  return GardenData(
    sessions: sessions,
    settings: const GroveSettings(dailyGoal: Duration(minutes: 90)),
  );
}

Future<GardenStore> _seededStore() async {
  var id = 0;
  final repository = GardenRepository(MemoryStore());
  await repository.save(_seed());

  final store = GardenStore(
    repository: repository,
    controller: SessionController(
      clock: () => _now,
      idFactory: () => 'shot-${(id++).toString().padLeft(3, '0')}',
    ),
    clock: () => _now,
  );
  await store.initialize();
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
      GroveApp(store: store, locale: locale, fontFamily: 'Roboto'),
    );
    await tester.pumpAndSettle();
    if (after != null) {
      await after(tester);
      await tester.pumpAndSettle();
    }

    await expectLater(
      find.byType(GroveApp),
      matchesGoldenFile('../store/screenshots/$name.png'),
    );
  }

  /// Switches tab by its localised label, which is also a check that the
  /// label is where the screenshot says it is.
  Future<void> Function(WidgetTester) tab(String label) =>
      (tester) async => tester.tap(find.text(label).last);

  group('Korean', () {
    const ko = Locale('ko');
    testWidgets('focus', (t) => shoot(t, 'ko-1-focus', locale: ko));
    testWidgets(
      'garden',
      (t) => shoot(t, 'ko-2-garden', locale: ko, after: tab('정원')),
    );
    testWidgets(
      'stats',
      (t) => shoot(t, 'ko-3-stats', locale: ko, after: tab('기록')),
    );
    testWidgets(
      'settings',
      (t) => shoot(t, 'ko-4-settings', locale: ko, after: tab('설정')),
    );
    testWidgets(
      'dark',
      (t) => shoot(
        t,
        'ko-5-dark',
        locale: ko,
        brightness: Brightness.dark,
        after: tab('정원'),
      ),
    );
  });

  group('English', () {
    const en = Locale('en');
    testWidgets('focus', (t) => shoot(t, 'en-1-focus', locale: en));
    testWidgets(
      'garden',
      (t) => shoot(t, 'en-2-garden', locale: en, after: tab('Garden')),
    );
    testWidgets(
      'stats',
      (t) => shoot(t, 'en-3-stats', locale: en, after: tab('Stats')),
    );
  });
}
