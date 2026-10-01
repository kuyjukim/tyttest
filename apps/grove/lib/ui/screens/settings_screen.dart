import 'package:flutter/material.dart';
import 'package:paper/paper.dart';

import '../../domain/species.dart';
import '../../domain/stats.dart';
import '../../state/garden_store.dart';
import '../strings.dart';
import '../widgets/tree_figure.dart';
import '../widgets/tree_view.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = Scope.watch<GardenStore>(context);
    final strings = S.of(context);
    final settings = store.settings;

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

        SectionHeader(title: strings.sessionSection),
        SettingSwitch(
          title: strings.strictMode,
          subtitle: strings.strictModeBody,
          value: settings.strict,
          onChanged: (value) =>
              store.updateSettings(settings.copyWith(strict: value)),
        ),
        const Hairline(),
        SettingRow(
          title: strings.dailyGoal,
          value: strings.span(settings.dailyGoal),
          onTap: () => _editGoal(context, store, strings),
        ),
        const Hairline(),
        SettingSwitch(
          title: strings.haptics,
          subtitle: strings.hapticsBody,
          value: settings.haptics,
          onChanged: (value) =>
              store.updateSettings(settings.copyWith(haptics: value)),
        ),

        SectionHeader(title: strings.collection),
        _Collection(store: store, strings: strings),

        SectionHeader(title: strings.about),
        Text(
          strings.aboutBody,
          style: context.type.body.copyWith(color: context.colors.inkMuted),
        ),

        SectionHeader(title: strings.dangerZone),
        SettingRow(
          title: strings.clearGarden,
          destructive: true,
          onTap: () => _clear(context, store, strings),
        ),
        const SizedBox(height: Gap.xl),
      ],
    );
  }

  Future<void> _editGoal(
    BuildContext context,
    GardenStore store,
    S strings,
  ) async {
    // Goals are offered as a short list rather than a free number field: the
    // interesting choice is "how much do I want to commit to", not "how many
    // minutes exactly".
    const options = <Duration>[
      Duration(minutes: 30),
      Duration(minutes: 60),
      Duration(minutes: 90),
      Duration(minutes: 120),
      Duration(minutes: 180),
      Duration(minutes: 240),
    ];
    final picked = await showPaperSheet<Duration>(
      context: context,
      title: strings.dailyGoal,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in options) ...[
            SettingRow(
              title: strings.span(option),
              value: option == store.settings.dailyGoal ? '✓' : null,
              onTap: () => Navigator.of(context).pop(option),
            ),
            if (option != options.last) const Hairline(),
          ],
        ],
      ),
    );
    if (picked == null) return;
    await store.updateSettings(store.settings.copyWith(dailyGoal: picked));
  }

  Future<void> _clear(
    BuildContext context,
    GardenStore store,
    S strings,
  ) async {
    final confirmed = await confirmDestructive(
      context,
      title: strings.clearGardenConfirmTitle,
      message: strings.clearGardenConfirmBody,
      confirmLabel: strings.clearGardenConfirmAction,
    );
    if (!confirmed || !context.mounted) return;
    await store.clearGarden();
    if (!context.mounted) return;
    showPaperToast(context, strings.clearedToast);
  }
}

/// The species ladder: what is unlocked, how many of each is planted, and
/// what the next threshold is.
class _Collection extends StatelessWidget {
  const _Collection({required this.store, required this.strings});

  final GardenStore store;
  final S strings;

  @override
  Widget build(BuildContext context) {
    final counts = Stats.plantedBySpecies(store.sessions);
    final unlockedMinutes = store.totalFocusedMinutes;

    return PaperCard(
      padding: const EdgeInsets.symmetric(vertical: Gap.sm),
      child: Column(
        children: [
          for (final species in Species.values) ...[
            if (species != Species.values.first) const Hairline(indent: Gap.lg),
            _SpeciesRow(
              species: species,
              label: strings.speciesName(species),
              planted: counts[species.name] ?? 0,
              unlocked: species.unlockMinutes <= unlockedMinutes,
              requirement: strings.lockedUntil(
                strings.span(Duration(minutes: species.unlockMinutes)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SpeciesRow extends StatelessWidget {
  const _SpeciesRow({
    required this.species,
    required this.label,
    required this.planted,
    required this.unlocked,
    required this.requirement,
  });

  final Species species;
  final String label;
  final int planted;
  final bool unlocked;
  final String requirement;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.sm),
      child: Row(
        children: [
          SizedBox(
            height: 44,
            width: 36,
            child: unlocked
                ? TreeView(
                    figure: TreeFigure(
                      species: species,
                      seed: species.index * 7717,
                      growth: 1,
                    ),
                    depthLimit: 3,
                    showGround: false,
                  )
                : Center(
                    child: Icon(
                      Icons.lock_outline_rounded,
                      size: 16,
                      color: colors.inkFaint,
                    ),
                  ),
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: context.type.body.copyWith(
                    color: unlocked ? colors.ink : colors.inkMuted,
                  ),
                ),
                if (!unlocked) Text(requirement, style: context.type.caption),
              ],
            ),
          ),
          if (unlocked && planted > 0)
            Text('$planted', style: context.type.numeric),
        ],
      ),
    );
  }
}
