import 'dart:convert';

import 'package:paper/paper.dart';

import '../domain/sketch.dart';

/// What the gallery shows without loading a whole drawing.
class SketchSummary implements Comparable<SketchSummary> {
  const SketchSummary({
    required this.id,
    required this.name,
    required this.updatedAt,
    required this.strokeCount,
  });

  factory SketchSummary.of(Sketch sketch) => SketchSummary(
    id: sketch.id,
    name: sketch.name,
    updatedAt: sketch.updatedAt,
    strokeCount: sketch.strokeCount,
  );

  factory SketchSummary.fromJson(Map<String, Object?> json) => SketchSummary(
    id: json['id']! as String,
    name: json['name'] as String? ?? '',
    updatedAt:
        DateTime.tryParse(json['updatedAt'] as String? ?? '')?.toLocal() ??
        DateTime.fromMillisecondsSinceEpoch(0),
    strokeCount: switch (json['strokeCount']) {
      final int value => value,
      _ => 0,
    },
  );

  final String id;
  final String name;
  final DateTime updatedAt;
  final int strokeCount;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'updatedAt': updatedAt.toIso8601String(),
    'strokeCount': strokeCount,
  };

  /// Newest first.
  @override
  int compareTo(SketchSummary other) {
    final byTime = other.updatedAt.compareTo(updatedAt);
    return byTime != 0 ? byTime : id.compareTo(other.id);
  }
}

/// Stores each drawing under its own key, with an index for the gallery.
///
/// One key per sketch rather than one big document: a drawing is the largest
/// thing this suite persists, and rewriting every sketch to save a stroke in
/// one of them would get slower the more the user draws.
class SketchRepository {
  SketchRepository(this._store);

  final KeyValueStore _store;

  static const String indexKey = 'stroke.index.v1';
  static const String sketchPrefix = 'stroke.sketch.';

  static String keyFor(String id) => '$sketchPrefix$id';

  /// The gallery, newest first.
  ///
  /// The index is reconciled against the keys actually present: an entry
  /// whose document is gone is dropped, and a document missing from the
  /// index is read and added. Without that, a crash between writing a sketch
  /// and writing the index would either hide a drawing forever or leave a
  /// row that opens nothing - and both are worse than one extra read.
  Future<List<SketchSummary>> listSketches() async {
    final indexed = <String, SketchSummary>{};
    final raw = await _store.read(indexKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final entry in decoded) {
            if (entry is! Map<String, Object?>) continue;
            try {
              final summary = SketchSummary.fromJson(entry);
              indexed[summary.id] = summary;
            } on Object {
              continue;
            }
          }
        }
      } on FormatException {
        // A corrupt index is recoverable: everything below rebuilds it.
      }
    }

    final present = <String>{
      for (final key in await _store.keys())
        if (key.startsWith(sketchPrefix)) key.substring(sketchPrefix.length),
    };

    var changed = false;
    final result = <SketchSummary>[];

    for (final id in present) {
      final known = indexed[id];
      if (known != null) {
        result.add(known);
        continue;
      }
      // Present on disk but not in the index: read it to find out what it is.
      final sketch = await load(id);
      if (sketch == null) continue;
      result.add(SketchSummary.of(sketch));
      changed = true;
    }
    // Index entries with no document behind them.
    if (indexed.keys.any((id) => !present.contains(id))) changed = true;

    result.sort();
    if (changed) await _writeIndex(result);
    return result;
  }

  Future<Sketch?> load(String id) async {
    final raw = await _store.read(keyFor(id));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) return null;
      return Sketch.fromJson(decoded);
    } on Object {
      return null;
    }
  }

  /// Writes the sketch, then updates the index.
  ///
  /// In this order deliberately: if the process dies between the two, the
  /// drawing exists and [listSketches] will find it, which is the failure
  /// that loses nothing.
  Future<void> save(Sketch sketch) async {
    await _store.write(keyFor(sketch.id), jsonEncode(sketch.toJson()));
    final summaries = await listSketches();
    final updated = <SketchSummary>[
      SketchSummary.of(sketch),
      for (final summary in summaries)
        if (summary.id != sketch.id) summary,
    ]..sort();
    await _writeIndex(updated);
  }

  Future<void> delete(String id) async {
    await _store.delete(keyFor(id));
    final remaining = <SketchSummary>[
      for (final summary in await listSketches())
        if (summary.id != id) summary,
    ];
    await _writeIndex(remaining);
  }

  Future<void> _writeIndex(List<SketchSummary> summaries) => _store.write(
    indexKey,
    jsonEncode(<Object?>[for (final summary in summaries) summary.toJson()]),
  );
}
