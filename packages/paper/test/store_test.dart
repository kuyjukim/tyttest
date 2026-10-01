import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paper/paper.dart';

void main() {
  group('MemoryStore', () {
    test('round-trips, overwrites and deletes', () async {
      final store = MemoryStore();
      expect(await store.read('a'), isNull);

      await store.write('a', '1');
      expect(await store.read('a'), '1');

      await store.write('a', '2');
      expect(await store.read('a'), '2');

      await store.delete('a');
      expect(await store.read('a'), isNull);
      expect(await store.keys(), isEmpty);
    });

    test('seeds from a map without aliasing it', () async {
      final seed = <String, String>{'k': 'v'};
      final store = MemoryStore(seed);
      await store.write('k2', 'v2');
      expect(seed.keys, ['k'], reason: 'the caller\'s map must not be mutated');
      expect(await store.keys(), containsAll(<String>['k', 'k2']));
    });
  });

  group('FileStore', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('paper_store'));
    tearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test('creates its directory lazily on first write', () async {
      final nested = Directory('${dir.path}/does/not/exist/yet');
      final store = FileStore(nested);
      expect(nested.existsSync(), isFalse);
      expect(await store.read('x'), isNull, reason: 'reads must not throw');
      expect(await store.keys(), isEmpty);

      await store.write('x', 'hello');
      expect(await store.read('x'), 'hello');
    });

    test('survives keys containing path separators and colons', () async {
      final store = FileStore(dir);
      const awkward = 'vault/2026-10-01T09:30:00Z/entry';
      await store.write(awkward, 'payload');

      expect(await store.read(awkward), 'payload');
      expect(await store.keys(), [awkward]);
    });

    test('leaves no temp file behind after a write', () async {
      final store = FileStore(dir);
      await store.write('k', 'v');
      final leftovers = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.tmp'))
          .toList();
      expect(leftovers, isEmpty);
    });

    test('serialises concurrent writes to the same key', () async {
      final store = FileStore(dir);
      // Fire 20 writes without awaiting; the last one queued must win and the
      // file must never be observed half-written.
      final writes = <Future<void>>[
        for (var i = 0; i < 20; i++) store.write('k', 'value-$i'),
      ];
      await Future.wait(writes);
      expect(await store.read('k'), 'value-19');
      expect(await store.keys(), ['k']);
    });

    test('a failed write does not poison later writes', () async {
      final store = FileStore(dir);
      await store.write('ok', 'first');

      // Deleting the directory out from under an in-flight rename is the
      // cheapest way to make one write fail for real.
      final doomed = Future<void>.sync(() async {
        dir.deleteSync(recursive: true);
        await store.write('boom', 'x');
      });
      await doomed.then<void>((_) {}, onError: (Object _) {});

      await store.write('after', 'still works');
      expect(await store.read('after'), 'still works');
    });

    test('ignores foreign files when listing keys', () async {
      final store = FileStore(dir);
      await store.write('mine', 'v');
      File('${dir.path}/README.txt').writeAsStringSync('not ours');
      File('${dir.path}/!!!not-base64!!!.kv').writeAsStringSync('junk');

      expect(await store.keys(), ['mine']);
    });
  });

  group('JsonDocument', () {
    test('returns empty() when nothing is stored', () async {
      final doc = _counterDoc(MemoryStore());
      expect((await doc.load()).value, 0);
    });

    test('round-trips through the store', () async {
      final store = MemoryStore();
      final doc = _counterDoc(store);
      await doc.save(const _Counter(7));
      expect((await doc.load()).value, 7);
      expect(store.snapshot['counter'], jsonEncode({'value': 7}));
    });

    test('falls back to empty() and reports when the payload is corrupt',
        () async {
      final store = MemoryStore({'counter': '{not json'});
      final doc = _counterDoc(store);
      Object? reported;

      final loaded = await doc.load(onCorrupt: (error) => reported = error);

      expect(loaded.value, 0, reason: 'a corrupt file must still open the app');
      expect(reported, isNotNull);
    });

    test('treats a stored JSON array as corrupt rather than crashing',
        () async {
      final doc = _counterDoc(MemoryStore({'counter': '[1,2,3]'}));
      Object? reported;
      expect((await doc.load(onCorrupt: (e) => reported = e)).value, 0);
      expect(reported, isA<FormatException>());
    });
  });
}


class _Counter {
  const _Counter(this.value);
  final int value;
}

JsonDocument<_Counter> _counterDoc(KeyValueStore store) => JsonDocument<_Counter>(
  store: store,
  key: 'counter',
  empty: () => const _Counter(0),
  decode: (json) => _Counter(json['value']! as int),
  encode: (c) => <String, Object?>{'value': c.value},
);
