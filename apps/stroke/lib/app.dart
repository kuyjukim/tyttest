import 'dart:async';

import 'package:flutter/material.dart';
import 'package:paper/paper.dart';

import 'state/studio_store.dart';
import 'ui/screens/editor_screen.dart';
import 'ui/screens/gallery_screen.dart';
import 'ui/strings.dart';

/// Stroke's brand colour.
const Color strokeAccent = Color(0xFFC2255C);

class StrokeApp extends StatelessWidget {
  const StrokeApp({required this.store, this.locale, super.key});

  final StudioStore store;

  /// Forces a language, overriding the device setting.
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    return Scope<StudioStore>(
      value: store,
      child: ScopeBuilder<StudioStore>(
        builder: (context, store) => MaterialApp(
          onGenerateTitle: (context) => S.of(context).appName,
          debugShowCheckedModeBanner: false,
          theme: PaperTheme.light(accent: strokeAccent),
          darkTheme: PaperTheme.dark(accent: strokeAccent),
          locale: locale,
          localizationsDelegates: localizationDelegates(S.delegate),
          supportedLocales: S.delegate.supportedLocales,
          home: const _Root(),
        ),
      ),
    );
  }
}

/// Picks the gallery or the editor, and makes sure a drawing is written
/// before the app can be taken away.
class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        // Autosave is on a delay, and the OS can kill a backgrounded app at
        // any moment. Leaving the foreground is the last reliable chance to
        // write, so it is taken rather than waited out.
        unawaited(Scope.read<StudioStore>(context).flush());
      case AppLifecycleState.resumed:
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = Scope.watch<StudioStore>(context);
    if (!store.ready) {
      return Scaffold(
        backgroundColor: context.colors.surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return store.sketch == null
        ? const GalleryScreen()
        : const EditorScreen();
  }
}
