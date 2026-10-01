import 'dart:io';

import 'package:flutter/material.dart';
import 'package:paper/paper.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'data/sketch_repository.dart';
import 'state/studio_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final store = StudioStore(
    repository: SketchRepository(await _openStore()),
    clock: DateTime.now,
    idFactory: _newId,
  );

  runApp(StrokeApp(store: store));
  await store.initialize();
}

Future<KeyValueStore> _openStore() async {
  final support = await getApplicationSupportDirectory();
  return FileStore(Directory('${support.path}/stroke'));
}

var _counter = 0;

/// Fixed-width, time-ordered ids, so string comparison matches chronological
/// order wherever one is used as a sort tiebreaker.
String _newId() {
  final stamp = DateTime.now()
      .microsecondsSinceEpoch
      .toRadixString(36)
      .padLeft(11, '0');
  final suffix = (_counter++ % 46656).toRadixString(36).padLeft(3, '0');
  return '$stamp$suffix';
}
