import 'dart:async';

import 'package:flutter/material.dart';
import 'package:paper/paper.dart';

import 'state/garden_store.dart';
import 'state/session_controller.dart';
import 'ui/screens/focus_screen.dart';
import 'ui/screens/garden_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/stats_screen.dart';
import 'ui/strings.dart';

/// Grove's brand colour.
const Color groveAccent = Color(0xFF2F7D5B);

/// Root widget. Owns the theme, the locale and the single [GardenStore].
class GroveApp extends StatelessWidget {
  const GroveApp({
    required this.store,
    this.locale,
    this.fontFamily,
    super.key,
  });

  final GardenStore store;

  /// Forces a language, overriding the device setting. Null follows the
  /// device, which is what the shipped app does.
  final Locale? locale;

  /// Overrides the platform text face. Null in the shipped app; set by the
  /// screenshot run, which has no platform font to fall back to.
  final String? fontFamily;

  @override
  Widget build(BuildContext context) {
    return Scope<GardenStore>(
      value: store,
      child: ScopeBuilder<GardenStore>(
        builder: (context, store) => MaterialApp(
          onGenerateTitle: (context) => S.of(context).appName,
          debugShowCheckedModeBanner: false,
          theme: PaperTheme.light(accent: groveAccent, fontFamily: fontFamily),
          darkTheme: PaperTheme.dark(
            accent: groveAccent,
            fontFamily: fontFamily,
          ),
          themeMode: store.settings.themeMode,
          locale: locale,
          localizationsDelegates: localizationDelegates(S.delegate),
          supportedLocales: S.delegate.supportedLocales,
          home: store.ready ? const _Shell() : const _Splash(),
        ),
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.colors.surface,
    body: const Center(child: CircularProgressIndicator()),
  );
}

/// Tab shell. Also the one place that drives the clock and watches the app
/// lifecycle, because both are process-level concerns rather than screen ones.
class _Shell extends StatefulWidget {
  const _Shell();

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> with WidgetsBindingObserver {
  int _tab = 0;
  Timer? _ticker;
  SessionPhase? _lastPhase;

  GardenStore get _store => Scope.read<GardenStore>(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // A session recovered at launch leaves the controller in a result phase,
    // so make sure the user lands on the screen that explains it.
    _lastPhase = SessionPhase.idle;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncTicker();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final store = _store;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        store.onBackgrounded();
      case AppLifecycleState.resumed:
        unawaited(store.onForegrounded());
      case AppLifecycleState.inactive:
        // Transient - the app switcher, a system sheet sliding in. Treating
        // this as leaving would kill a session every time a notification
        // banner appeared.
        break;
    }
  }

  /// Runs the per-second tick only while a session is live.
  ///
  /// The tick exists to repaint the countdown; elapsed time is always read
  /// from the clock, so a missed tick costs a frame rather than a minute.
  void _syncTicker() {
    final running = _store.controller.isRunning;
    if (running && _ticker == null) {
      _ticker = Timer.periodic(
        const Duration(seconds: 1),
        (_) => unawaited(_store.tick()),
      );
    } else if (!running && _ticker != null) {
      _ticker!.cancel();
      _ticker = null;
    }
  }

  void _onPhaseChange(SessionPhase phase) {
    final store = _store;
    if (phase == SessionPhase.succeeded) {
      Buzz.success(enabled: store.settings.haptics);
    }
    if (phase != SessionPhase.idle && _tab != 0) {
      setState(() => _tab = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = Scope.watch<GardenStore>(context);
    final strings = S.of(context);

    final phase = store.controller.phase;
    if (phase != _lastPhase) {
      _lastPhase = phase;
      // Deferred: this runs during build, and both the ticker and the tab
      // index must not be mutated mid-frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _syncTicker();
        _onPhaseChange(phase);
      });
    }

    final titles = <String>[
      strings.focusTitle,
      strings.gardenTitle,
      strings.statsTitle,
      strings.settingsTitle,
    ];

    return PaperScaffold(
      title: titles[_tab],
      body: IndexedStack(
        index: _tab,
        children: [
          const FocusScreen(),
          GardenScreen(onStartFocusing: () => setState(() => _tab = 0)),
          const StatsScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomBar: NavigationBar(
        selectedIndex: _tab,
        backgroundColor: context.colors.surfaceRaised,
        indicatorColor: context.colors.accentSoft,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.hourglass_empty_rounded),
            selectedIcon: const Icon(Icons.hourglass_bottom_rounded),
            label: strings.tabFocus,
          ),
          NavigationDestination(
            icon: const Icon(Icons.park_outlined),
            selectedIcon: const Icon(Icons.park_rounded),
            label: strings.tabGarden,
          ),
          NavigationDestination(
            icon: const Icon(Icons.insights_outlined),
            selectedIcon: const Icon(Icons.insights_rounded),
            label: strings.tabStats,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings_rounded),
            label: strings.tabSettings,
          ),
        ],
      ),
    );
  }
}
