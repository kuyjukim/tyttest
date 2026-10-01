import 'package:flutter_test/flutter_test.dart';
import 'package:inkwell/domain/entry.dart';
import 'package:inkwell/domain/journal.dart';
import 'package:paper/paper.dart';

Entry entry({
  required String id,
  required DateTime createdAt,
  String title = '',
  String body = '',
  Mood? mood,
  List<String> tags = const <String>[],
}) => Entry(
  id: id,
  createdAt: createdAt,
  updatedAt: createdAt,
  title: title,
  body: body,
  mood: mood,
  tags: tags,
);

void main() {
  group('Entry', () {
    test('preview takes the first line and truncates politely', () {
      expect(
        entry(
          id: 'a',
          createdAt: DateTime(2026),
          body: 'first line\nsecond line',
        ).preview,
        'first line',
      );
      expect(entry(id: 'a', createdAt: DateTime(2026), body: '   ').preview, '');

      final long = entry(id: 'a', createdAt: DateTime(2026), body: 'x' * 300);
      expect(long.preview.length, 140);
      expect(long.preview, endsWith('…'));
    });

    test('titleOr falls back for a blank or whitespace title', () {
      expect(
        entry(id: 'a', createdAt: DateTime(2026), title: '  ').titleOr('Untitled'),
        'Untitled',
      );
      expect(
        entry(id: 'a', createdAt: DateTime(2026), title: ' Monday ')
            .titleOr('Untitled'),
        'Monday',
      );
    });

    test('wordCount handles empty, single and multi-line bodies', () {
      expect(entry(id: 'a', createdAt: DateTime(2026), body: '').wordCount, 0);
      expect(entry(id: 'a', createdAt: DateTime(2026), body: '  ').wordCount, 0);
      expect(entry(id: 'a', createdAt: DateTime(2026), body: 'one').wordCount, 1);
      expect(
        entry(
          id: 'a',
          createdAt: DateTime(2026),
          body: 'one two\nthree\tfour  five',
        ).wordCount,
        5,
      );
    });

    test('isEmpty only when both title and body are blank', () {
      expect(entry(id: 'a', createdAt: DateTime(2026)).isEmpty, isTrue);
      expect(
        entry(id: 'a', createdAt: DateTime(2026), title: 'x').isEmpty,
        isFalse,
      );
      expect(
        entry(id: 'a', createdAt: DateTime(2026), body: 'x').isEmpty,
        isFalse,
      );
    });

    test('search is case-insensitive across title, body and tags', () {
      final e = entry(
        id: 'a',
        createdAt: DateTime(2026),
        title: 'Rainy Monday',
        body: 'I walked to the Station',
        tags: <String>['Weather'],
      );
      expect(e.matches('rainy'), isTrue);
      expect(e.matches('STATION'), isTrue);
      expect(e.matches('weather'), isTrue);
      expect(e.matches(''), isTrue);
      expect(e.matches('   '), isTrue);
      expect(e.matches('sunny'), isFalse);
    });

    test('search matches inside a Korean run with no spaces', () {
      // Substring rather than token matching, because a space-splitting
      // tokeniser would simply never match here.
      final e = entry(
        id: 'a',
        createdAt: DateTime(2026),
        body: '오늘은비가왔고기분이좋았다',
      );
      expect(e.matches('기분'), isTrue);
      expect(e.matches('눈'), isFalse);
    });

    test('round-trips through JSON, including a missing updatedAt', () {
      final original = entry(
        id: 'a',
        createdAt: DateTime(2026, 5, 4, 12, 30),
        title: 'Title',
        body: 'Body\nwith lines',
        mood: Mood.good,
        tags: <String>['one', 'two'],
      );
      final restored = Entry.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.body, original.body);
      expect(restored.mood, Mood.good);
      expect(restored.tags, <String>['one', 'two']);
      expect(restored.createdAt, original.createdAt);

      // An entry written before updatedAt existed.
      final legacy = original.toJson()..remove('updatedAt');
      expect(Entry.fromJson(legacy).updatedAt, original.createdAt);
    });

    test('an unknown mood decodes as none instead of throwing', () {
      final json = entry(id: 'a', createdAt: DateTime(2026)).toJson()
        ..['mood'] = 'ecstatic';
      expect(Entry.fromJson(json).mood, isNull);
    });

    test('blank and non-string tags are dropped on decode', () {
      final json = entry(id: 'a', createdAt: DateTime(2026)).toJson()
        ..['tags'] = <Object?>['  keep  ', '', '   ', 42, null];
      expect(Entry.fromJson(json).tags, <String>['keep']);
    });
  });

  group('Journal', () {
    Journal sample() => Journal(
      entries: <Entry>[
        entry(
          id: 'e1',
          createdAt: DateTime(2026, 10, 1, 9),
          title: 'Today',
          tags: <String>['work'],
        ),
        entry(
          id: 'e2',
          createdAt: DateTime(2026, 9, 30, 20),
          title: 'Yesterday',
          tags: <String>['rest'],
        ),
        entry(
          id: 'e3',
          createdAt: DateTime(2026, 9, 1, 8),
          title: 'Earlier in September',
        ),
        entry(
          id: 'e4',
          createdAt: DateTime(2025, 10, 1, 8),
          title: 'A year ago today',
        ),
      ],
    )..sort();

    test('upsert adds then replaces, keeping one copy', () {
      final journal = Journal.empty();
      final first = entry(id: 'x', createdAt: DateTime(2026), title: 'One');
      journal
        ..upsert(first)
        ..upsert(entry(id: 'x', createdAt: DateTime(2026), title: 'Two'));

      expect(journal.entries, hasLength(1));
      expect(journal.entries.single.title, 'Two');
    });

    test('remove reports whether it removed anything', () {
      final journal = sample();
      expect(journal.remove('nope'), isFalse);
      expect(journal.remove('e1'), isTrue);
      expect(journal.entries, hasLength(3));
    });

    test('byMonth groups newest month first', () {
      final months = sample().byMonth();
      expect(months.keys.toList(), <Day>[
        const Day(2026, 10, 1),
        const Day(2026, 9, 1),
        const Day(2025, 10, 1),
      ]);
      expect(months[const Day(2026, 9, 1)], hasLength(2));
    });

    test('onThisDay finds earlier years only, never today', () {
      final resurfaced = sample().onThisDay(const Day(2026, 10, 1));
      expect(resurfaced.map((e) => e.id), <String>['e4']);
      expect(sample().onThisDay(const Day(2026, 10, 2)), isEmpty);
    });

    test('allTags is the sorted set in use', () {
      expect(sample().allTags(), <String>['rest', 'work']);
      expect(Journal.empty().allTags(), isEmpty);
    });

    test('writingStreak counts consecutive days with the morning grace', () {
      const today = Day(2026, 10, 1);
      Journal daysBack(Iterable<int> offsets) => Journal(
        entries: <Entry>[
          for (final offset in offsets)
            entry(
              id: 'd$offset',
              createdAt: today.addDays(-offset).startOfDay.add(
                const Duration(hours: 10),
              ),
            ),
        ],
      );

      expect(daysBack(const <int>[]).writingStreak(today), 0);
      expect(daysBack(const <int>[0, 1, 2]).writingStreak(today), 3);
      // Nothing yet today, but yesterday and before: the streak holds.
      expect(daysBack(const <int>[1, 2, 3]).writingStreak(today), 3);
      // A whole day missed: broken.
      expect(daysBack(const <int>[2, 3, 4]).writingStreak(today), 0);
      // Two entries in one day count once.
      expect(daysBack(const <int>[0, 0, 1]).writingStreak(today), 2);
    });

    test('search filters and an empty query returns everything', () {
      expect(sample().search('year').map((e) => e.id), <String>['e4']);
      expect(sample().search('').length, 4);
      expect(sample().search('nothing matches this'), isEmpty);
    });

    group('encode and decode', () {
      test('round-trips', () {
        final original = sample();
        final restored = Journal.decode(original.encode());
        expect(restored.entries.map((e) => e.id), original.entries.map((e) => e.id));
      });

      test('an empty or blank body decodes to an empty journal', () {
        expect(Journal.decode('').entries, isEmpty);
        expect(Journal.decode('   ').entries, isEmpty);
        expect(Journal.decode('{}').entries, isEmpty);
      });

      test('a non-object body is a format error', () {
        expect(() => Journal.decode('[1,2,3]'), throwsFormatException);
      });

      test('one damaged entry is skipped, the rest survive', () {
        // The key was right - the body decrypted - so refusing to open the
        // journal over one bad record would be the wrong trade.
        const payload = '{"version":1,"entries":['
            '{"id":"ok","createdAt":"2026-10-01T09:00:00.000","title":"Fine"},'
            '{"id":"broken"},'
            '"not even an object",'
            '{"id":"ok2","createdAt":"2026-09-01T09:00:00.000","title":"Also fine"}'
            ']}';
        final journal = Journal.decode(payload);
        expect(journal.entries.map((e) => e.id), <String>['ok', 'ok2']);
      });
    });

    test('markdown export carries the content, the date and the metadata', () {
      final markdown = Journal(
        entries: <Entry>[
          entry(
            id: 'e',
            createdAt: DateTime(2026, 10, 1, 9),
            title: 'Monday',
            body: 'it rained',
            mood: Mood.low,
            tags: <String>['weather', 'commute'],
          ),
        ],
      ).toMarkdown();

      expect(markdown, contains('## Monday'));
      expect(markdown, contains('it rained'));
      expect(markdown, contains('Mood: low'));
      expect(markdown, contains('weather, commute'));
      expect(markdown, contains('2026-10-01'));
    });

    test('markdown uses the date as a heading for an untitled entry', () {
      final markdown = Journal(
        entries: <Entry>[
          entry(id: 'e', createdAt: DateTime(2026, 10, 1), body: 'no title'),
        ],
      ).toMarkdown();
      expect(markdown, contains('## 2026-10-01'));
    });
  });

  group('Mood', () {
    test('scores are ordered and centred on neutral', () {
      expect(Mood.neutral.score, 0);
      for (var i = 1; i < Mood.values.length; i++) {
        expect(
          Mood.values[i].score,
          greaterThan(Mood.values[i - 1].score),
          reason: 'the scale must be monotonic to average meaningfully',
        );
      }
    });

    test('byName is total over the enum and null for anything else', () {
      for (final mood in Mood.values) {
        expect(Mood.byName(mood.name), mood);
      }
      expect(Mood.byName(null), isNull);
      expect(Mood.byName('indifferent'), isNull);
    });
  });
}
