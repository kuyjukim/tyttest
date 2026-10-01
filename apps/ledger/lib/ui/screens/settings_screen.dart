import 'package:flutter/material.dart';
import 'package:paper/paper.dart';

import '../../domain/money.dart';
import '../../state/budget_store.dart';
import '../money_format.dart';
import '../strings.dart';
import 'envelope_sheets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = Scope.watch<BudgetStore>(context);
    final strings = S.of(context);
    final settings = store.budget.settings;

    return ListView(
      padding: const EdgeInsets.only(bottom: Gap.x3l),
      children: [
        SectionHeader(title: strings.appearance),
        SegmentedToggle<ThemeMode>(
          segments: [
            (ThemeMode.system, strings.themeSystem),
            (ThemeMode.light, strings.themeLight),
            (ThemeMode.dark, strings.themeDark),
          ],
          value: settings.themeMode,
          onChanged: (mode) =>
              store.updateSettings(settings.copyWith(themeMode: mode)),
        ),

        SectionHeader(title: strings.currency),
        SettingRow(
          title: strings.currency,
          value: '${store.currency.symbol} ${store.currency.code}',
          onTap: () => _pickCurrency(context, store, strings),
        ),

        SectionHeader(title: strings.manageEnvelopes),
        _EnvelopeManager(store: store, strings: strings),

        SectionHeader(title: strings.about),
        Text(
          strings.aboutBody,
          style: context.type.body.copyWith(color: context.colors.inkMuted),
        ),

        SectionHeader(title: strings.dangerZone),
        SettingRow(
          title: strings.clearAll,
          destructive: true,
          onTap: () => _clear(context, store, strings),
        ),
        const SizedBox(height: Gap.xl),
      ],
    );
  }

  Future<void> _pickCurrency(
    BuildContext context,
    BudgetStore store,
    S strings,
  ) async {
    final picked = await showPaperSheet<Currency>(
      context: context,
      title: strings.currency,
      builder: (context) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final currency in Currency.known) ...[
              SettingRow(
                title: '${currency.symbol}  ${currency.code}',
                value: currency == store.currency ? '✓' : null,
                onTap: () => Navigator.of(context).pop(currency),
              ),
              if (currency != Currency.known.last) const Hairline(),
            ],
          ],
        ),
      ),
    );
    if (picked == null || picked == store.currency || !context.mounted) return;

    // Amounts are not converted, and that is worth a dialog rather than a
    // footnote: ₩150,000 becoming $150,000.00 is a surprise if nobody said so.
    final confirmed = await confirmDestructive(
      context,
      title: strings.currencyWarningTitle,
      message: strings.currencyWarningBody(
        store.currency.symbol,
        picked.symbol,
      ),
      confirmLabel: strings.currencyWarningAction,
    );
    if (!confirmed) return;
    await store.setCurrency(picked);
  }

  Future<void> _clear(
    BuildContext context,
    BudgetStore store,
    S strings,
  ) async {
    final confirmed = await confirmDestructive(
      context,
      title: strings.clearAllConfirmTitle,
      message: strings.clearAllConfirmBody,
      confirmLabel: strings.clearAllConfirmAction,
    );
    if (!confirmed || !context.mounted) return;
    await store.clearEverything();
    if (!context.mounted) return;
    showPaperToast(context, strings.clearedToast);
  }
}

class _EnvelopeManager extends StatelessWidget {
  const _EnvelopeManager({required this.store, required this.strings});

  final BudgetStore store;
  final S strings;

  @override
  Widget build(BuildContext context) {
    final money = MoneyFormat(
      locale: Localizations.localeOf(context).toLanguageTag(),
      currency: store.currency,
    );
    final envelopes = store.budget.envelopes;

    if (envelopes.isEmpty) {
      return PaperButton(
        label: strings.newEnvelope,
        kind: PaperButtonKind.tonal,
        expand: true,
        onPressed: () => showEnvelopeEditor(context, store: store),
      );
    }

    return Column(
      children: [
        for (final envelope in envelopes) ...[
          InkWell(
            onTap: () =>
                showEnvelopeEditor(context, store: store, envelope: envelope),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Gap.md),
              child: Row(
                children: [
                  Container(
                    height: 8,
                    width: 8,
                    decoration: BoxDecoration(
                      color: Viz.slot(
                        envelope.slot,
                        dark: context.colors.isDark,
                      ),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: Text(
                      envelope.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.type.body.copyWith(
                        color: envelope.archived
                            ? context.colors.inkMuted
                            : context.colors.ink,
                      ),
                    ),
                  ),
                  if (envelope.archived)
                    Padding(
                      padding: const EdgeInsets.only(right: Gap.sm),
                      child: Text(
                        strings.archived,
                        style: context.type.caption,
                      ),
                    ),
                  Text(
                    money.format(
                      Money(envelope.allocationMinor, store.currency),
                    ),
                    style: context.type.numeric.copyWith(
                      color: context.colors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Hairline(),
        ],
        const SizedBox(height: Gap.md),
        PaperButton(
          label: strings.newEnvelope,
          kind: PaperButtonKind.tonal,
          expand: true,
          onPressed: () => showEnvelopeEditor(context, store: store),
        ),
      ],
    );
  }
}
