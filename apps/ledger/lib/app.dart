import 'package:flutter/material.dart';
import 'package:paper/paper.dart';

import 'state/budget_store.dart';
import 'ui/screens/budget_screen.dart';
import 'ui/screens/reports_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/transactions_screen.dart';
import 'ui/strings.dart';

/// Ledger's brand colour.
const Color ledgerAccent = Color(0xFFA85A2B);

class LedgerApp extends StatelessWidget {
  const LedgerApp({
    required this.store,
    this.locale,
    this.fontFamily,
    super.key,
  });

  final BudgetStore store;

  /// Overrides the platform text face. Null in the shipped app; set by the
  /// screenshot run, which has no platform font to fall back to.
  final String? fontFamily;

  /// Forces a language, overriding the device setting.
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    return Scope<BudgetStore>(
      value: store,
      child: ScopeBuilder<BudgetStore>(
        builder: (context, store) => MaterialApp(
          onGenerateTitle: (context) => S.of(context).appName,
          debugShowCheckedModeBanner: false,
          theme: PaperTheme.light(
            accent: ledgerAccent,
            fontFamily: fontFamily,
          ),
          darkTheme: PaperTheme.dark(
            accent: ledgerAccent,
            fontFamily: fontFamily,
          ),
          themeMode: store.budget.settings.themeMode,
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

class _Shell extends StatefulWidget {
  const _Shell();

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final strings = S.of(context);
    final titles = <String>[
      strings.tabBudget,
      strings.tabTransactions,
      strings.tabReports,
      strings.tabSettings,
    ];

    return PaperScaffold(
      title: titles[_tab],
      body: IndexedStack(
        index: _tab,
        children: const [
          BudgetScreen(),
          TransactionsScreen(),
          ReportsScreen(),
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
            icon: const Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: const Icon(Icons.account_balance_wallet_rounded),
            label: strings.tabBudget,
          ),
          NavigationDestination(
            icon: const Icon(Icons.receipt_long_outlined),
            selectedIcon: const Icon(Icons.receipt_long_rounded),
            label: strings.tabTransactions,
          ),
          NavigationDestination(
            icon: const Icon(Icons.bar_chart_outlined),
            selectedIcon: const Icon(Icons.bar_chart_rounded),
            label: strings.tabReports,
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
