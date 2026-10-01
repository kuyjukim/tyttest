import 'dart:io';

import 'package:flutter/material.dart';
import 'package:paper/paper.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'data/vault_repository.dart';
import 'state/vault_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final store = VaultStore(
    repository: VaultRepository(await _openStore()),
    clock: DateTime.now,
    idFactory: _newId,
  );

  runApp(InkwellApp(store: store));
  await store.initialize();
}

/// Application support, not documents: the vault is app state, and on iOS
/// the documents directory is browsable in Files.
Future<KeyValueStore> _openStore() async {
  final support = await getApplicationSupportDirectory();
  return FileStore(Directory('${support.path}/inkwell'));
}

var _counter = 0;

/// Fixed-width, time-ordered ids.
///
/// Padded so that string comparison matches chronological order: the entry
/// list uses the id as its sort tiebreaker, and a variable-width id would
/// make `9` sort after `10`.
String _newId() {
  final stamp = DateTime.now()
      .microsecondsSinceEpoch
      .toRadixString(36)
      .padLeft(11, '0');
  final suffix = (_counter++ % 46656).toRadixString(36).padLeft(3, '0');
  return '$stamp$suffix';
}
