import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:paper/paper.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'data/garden_repository.dart';
import 'state/garden_store.dart';
import 'state/session_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Loads the date symbols for every locale the app supports. Without
  // it, a DateFormat constructed for 'ko' throws at runtime.
  await initializeDateFormatting();

  final store = GardenStore(
    repository: GardenRepository(await _openStore()),
    controller: SessionController(
      clock: DateTime.now,
      idFactory: _newId,
    ),
    clock: DateTime.now,
  );

  runApp(GroveApp(store: store));
  // Loading after the first frame means the app paints its chrome
  // immediately rather than holding a blank window while the disk is read.
  await store.initialize();
}

/// Where the garden lives on disk.
///
/// Application *support*, not documents: this is app state the user never
/// browses, and on iOS the documents directory is what shows up in Files.
Future<KeyValueStore> _openStore() async {
  final support = await getApplicationSupportDirectory();
  return FileStore(Directory('${support.path}/grove'));
}

var _counter = 0;

/// Session ids only have to be unique within one device's garden, so the
/// timestamp plus a counter is enough and needs no uuid dependency.
String _newId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${_counter++}';
