import 'package:flutter/material.dart';
import 'package:paper/paper.dart';

import 'state/vault_store.dart';
import 'ui/screens/insights_screen.dart';
import 'ui/screens/lock_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/timeline_screen.dart';
import 'ui/strings.dart';

/// Inkwell's brand colour.
const Color inkwellAccent = Color(0xFF5B5BD6);

class InkwellApp extends StatelessWidget {
  const InkwellApp({required this.store, this.locale, super.key});

  final VaultStore store;

  /// Forces a language, overriding the device setting.
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    return Scope<VaultStore>(
      value: store,
      child: ScopeBuilder<VaultStore>(
        builder: (context, store) => MaterialApp(
          onGenerateTitle: (context) => S.of(context).appName,
          debugShowCheckedModeBanner: false,
          theme: PaperTheme.light(accent: inkwellAccent),
          darkTheme: PaperTheme.dark(accent: inkwellAccent),
          // Read from the plaintext preferences, which is the reason they are
          // not inside the vault: the lock screen has to be the right colour
          // before any passphrase is typed.
          themeMode: store.prefs.themeMode,
          locale: locale,
          localizationsDelegates: localizationDelegates(S.delegate),
          supportedLocales: S.delegate.supportedLocales,
          home: switch (store.status) {
            VaultStatus.checking => const _Splash(),
            VaultStatus.absent || VaultStatus.locked => const LockScreen(),
            VaultStatus.unlocked => const _Shell(),
          },
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

/// The unlocked app. Also the one place watching the lifecycle, so that
/// auto-lock is a property of the process rather than of whichever screen
/// happens to be on top.
class _Shell extends StatefulWidget {
  const _Shell();

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> with WidgetsBindingObserver {
  int _tab = 0;

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
    final store = Scope.read<VaultStore>(context);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        store.onBackgrounded();
      case AppLifecycleState.resumed:
        store.onForegrounded();
      case AppLifecycleState.inactive:
        // The app switcher, a permission sheet. Locking here would lock on
        // every notification banner.
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = S.of(context);
    final titles = <String>[
      strings.tabJournal,
      strings.tabInsights,
      strings.tabSettings,
    ];

    return PaperScaffold(
      title: titles[_tab],
      actions: [
        PaperIconButton(
          icon: Icons.lock_outline_rounded,
          tooltip: strings.lockNow,
          onPressed: Scope.read<VaultStore>(context).lock,
        ),
      ],
      body: IndexedStack(
        index: _tab,
        children: const [
          TimelineScreen(),
          InsightsScreen(),
          SettingsScreen(),
        ],
      ),
      bottomBar: NavigationBar(
        selectedIndex: _tab,
        backgroundColor: context.colors.surfaceRaised,
        indicatorColor: context.colors.accentSoft,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.menu_book_outlined),
            selectedIcon: const Icon(Icons.menu_book_rounded),
            label: strings.tabJournal,
          ),
          NavigationDestination(
            icon: const Icon(Icons.insights_outlined),
            selectedIcon: const Icon(Icons.insights_rounded),
            label: strings.tabInsights,
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
