import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A tiny async key-value store.
///
/// This package deliberately depends on no plugins, so the file-backed
/// implementation takes a [Directory] rather than resolving one itself; apps
/// pass a directory from `path_provider` at startup. That keeps every store
/// consumer testable with [MemoryStore] and keeps `paper` buildable for web
/// and for plain `dart test`.
abstract interface class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<List<String>> keys();
}

/// In-memory store for tests, previews and the web demo build.
class MemoryStore implements KeyValueStore {
  MemoryStore([Map<String, String>? seed])
    : _data = <String, String>{...?seed};

  final Map<String, String> _data;

  /// Direct view of the backing map, for assertions in tests.
  Map<String, String> get snapshot => Map<String, String>.unmodifiable(_data);

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);

  @override
  Future<List<String>> keys() async => _data.keys.toList(growable: false);
}

/// One file per key, inside [directory].
///
/// Writes go to a sibling temp file and are then renamed. On every platform we
/// ship to, rename within a directory is atomic, which means a crash or a
/// force-quit mid-save can lose the new value but can never leave a
/// half-written file behind - the difference between "lost today's entry" and
/// "lost the journal".
class FileStore implements KeyValueStore {
  FileStore(this.directory);

  final Directory directory;

  /// Serialises writes so two concurrent saves to the same key cannot
  /// interleave their temp-file rename.
  Future<void> _tail = Future<void>.value();

  static const String _extension = '.kv';

  /// Keys are base64url-encoded so that any string - including one with a
  /// slash or a colon - is a legal filename on every platform.
  File _fileFor(String key) {
    final name = base64Url.encode(utf8.encode(key));
    return File('${directory.path}${Platform.pathSeparator}$name$_extension');
  }

  String _keyFor(String filename) {
    final encoded = filename.substring(0, filename.length - _extension.length);
    return utf8.decode(base64Url.decode(encoded));
  }

  @override
  Future<String?> read(String key) async {
    final file = _fileFor(key);
    if (!file.existsSync()) return null;
    return file.readAsString();
  }

  @override
  Future<void> write(String key, String value) {
    return _serialise(() async {
      await directory.create(recursive: true);
      final target = _fileFor(key);
      final temp = File('${target.path}.tmp');
      await temp.writeAsString(value, flush: true);
      await temp.rename(target.path);
    });
  }

  @override
  Future<void> delete(String key) {
    return _serialise(() async {
      final file = _fileFor(key);
      if (file.existsSync()) await file.delete();
    });
  }

  @override
  Future<List<String>> keys() async {
    if (!directory.existsSync()) return const <String>[];
    final result = <String>[];
    await for (final entity in directory.list()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (!name.endsWith(_extension)) continue;
      try {
        result.add(_keyFor(name));
      } on FormatException {
        // A file we did not write. Leave it alone rather than guessing.
        continue;
      }
    }
    return result;
  }

  Future<void> _serialise(Future<void> Function() action) {
    final next = _tail.then((_) => action());
    // Keep the chain alive even if one write fails, otherwise a single error
    // would poison every later write to this store.
    _tail = next.catchError((Object _) {});
    return next;
  }
}

/// Reads and writes a single JSON document under [key].
///
/// Every app in the suite persists exactly one aggregate (the garden, the
/// vault, the budget, the sketch index), so this is the only shape of
/// persistence any of them needs.
class JsonDocument<T extends Object> {
  JsonDocument({
    required this.store,
    required this.key,
    required this.decode,
    required this.encode,
    required this.empty,
  });

  final KeyValueStore store;
  final String key;
  final T Function(Map<String, Object?> json) decode;
  final Map<String, Object?> Function(T value) encode;
  final T Function() empty;

  /// Returns the stored value, or [empty] when nothing is stored yet.
  ///
  /// A stored document that cannot be parsed also yields [empty]: a user with
  /// a corrupt file is better served by an app that opens than by one that
  /// refuses to launch. [onCorrupt] lets the caller report it.
  Future<T> load({void Function(Object error)? onCorrupt}) async {
    final raw = await store.read(key);
    if (raw == null || raw.isEmpty) return empty();
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, Object?>) {
        throw const FormatException('Stored document is not a JSON object');
      }
      return decode(json);
    } on Object catch (error) {
      onCorrupt?.call(error);
      return empty();
    }
  }

  Future<void> save(T value) => store.write(key, jsonEncode(encode(value)));
}
