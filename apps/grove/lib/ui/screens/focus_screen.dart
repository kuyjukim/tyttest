import 'package:flutter/material.dart';
import 'package:paper/paper.dart';

import '../../domain/session.dart';
import '../../domain/settings.dart';
import '../../domain/species.dart';
import '../../state/garden_store.dart';
import '../../state/session_controller.dart';
import '../format.dart';
import '../strings.dart';
import '../widgets/duration_dial.dart';
import '../widgets/tree_figure.dart';
import '../widgets/tree_view.dart';

/// The timer. One screen with three states: pick a length, watch it grow,
/// see what happened.
class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  final TextEditingController _tag = TextEditingController();
  Duration? _pending;

  @override
  void dispose() {
    _tag.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = Scope.watch<GardenStore>(context);
    final strings = S.of(context);

    return switch (store.controller.phase) {
      SessionPhase.idle => _Idle(
        store: store,
        strings: strings,
        tagController: _tag,
        duration: _pending ?? store.settings.defaultDuration,
        onDuration: (value) => setState(() => _pending = value),
        onStart: () => _start(store),
      ),
      SessionPhase.running => _Running(
        store: store,
        strings: strings,
        onGiveUp: () => _giveUp(store),
      ),
      SessionPhase.succeeded || SessionPhase.failed => _Outcome(
        store: store,
        strings: strings,
        onDone: () {
          _tag.clear();
          store.acknowledge();
        },
      ),
    };
  }

  Future<void> _start(GardenStore store) async {
    final duration = _pending ?? store.settings.defaultDuration;
    // The haptic is fired, not awaited. Awaiting it meant that on any
    // platform without the channel - web, desktop, a widget test - the throw
    // happened before the session started, so Start did nothing at all.
    Buzz.tap(enabled: store.settings.haptics);
    await store.startSession(
      species: store.settings.preferredSpecies,
      planned: duration,
      tag: _tag.text,
    );
  }

  Future<void> _giveUp(GardenStore store) async {
    final strings = S.of(context);
    final confirmed = await confirmDestructive(
      context,
      title: strings.giveUpConfirmTitle,
      message: strings.giveUpConfirmBody,
      confirmLabel: strings.giveUpConfirmAction,
    );
    if (!confirmed) return;
    await store.giveUp();
  }
}

class _Idle extends StatelessWidget {
  const _Idle({
    required this.store,
    required this.strings,
    required this.tagController,
    required this.duration,
    required this.onDuration,
    required this.onStart,
  });

  final GardenStore store;
  final S strings;
  final TextEditingController tagController;
  final Duration duration;
  final ValueChanged<Duration> onDuration;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final species = store.settings.preferredSpecies;

    return ListView(
      padding: const EdgeInsets.only(top: Gap.sm, bottom: Gap.x3l),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: AspectRatio(
              aspectRatio: 1,
              child: DurationDial(
                value: duration,
                min: GroveSettings.minDuration,
                max: GroveSettings.maxDuration,
                step: GroveSettings.durationStep,
                haptics: store.settings.haptics,
                onChanged: onDuration,
                child: Padding(
                  padding: const EdgeInsets.all(Gap.x4l),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        strings.span(duration),
                        style: context.type.numericLarge.copyWith(fontSize: 44),
                      ),
                      const SizedBox(height: Gap.xs),
                      Text(
                        strings.speciesName(species),
                        style: context.type.label,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: Gap.xl),
        TextField(
          controller: tagController,
          textInputAction: TextInputAction.done,
          maxLength: 60,
          decoration: InputDecoration(
            hintText: strings.tagHint,
            counterText: '',
          ),
        ),
        const SizedBox(height: Gap.lg),
        _SpeciesStrip(store: store, strings: strings),
        const SizedBox(height: Gap.xl),
        PaperButton(
          label: strings.start,
          size: PaperButtonSize.large,
          expand: true,
          onPressed: onStart,
        ),
        const SizedBox(height: Gap.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              store.settings.strict
                  ? Icons.lock_outline_rounded
                  : Icons.lock_open_rounded,
              size: 14,
              color: colors.inkFaint,
            ),
            const SizedBox(width: Gap.xs),
            // Flexible, not a bare Text: this sentence is longer in Korean
            // and longer again at a large text scale, and an unbounded Text
            // in a Row overflows rather than wrapping.
            Flexible(
              child: Text(
                store.settings.strict
                    ? strings.strictOnNotice
                    : strings.strictOffNotice,
                textAlign: TextAlign.center,
                style: context.type.caption,
              ),
            ),
          ],
        ),
        if (store.todayTotal.focused > Duration.zero) ...[
          const SizedBox(height: Gap.xl),
          _GoalLine(store: store, strings: strings),
        ],
      ],
    );
  }
}

/// Horizontal picker of unlocked species, with the next locked one shown so
/// the ladder is visible rather than a surprise.
class _SpeciesStrip extends StatelessWidget {
  const _SpeciesStrip({required this.store, required this.strings});

  final GardenStore store;
  final S strings;

  @override
  Widget build(BuildContext context) {
    final unlocked = store.unlockedSpecies;
    final next = store.nextUnlock;
    final selected = store.settings.preferredSpecies;

    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: unlocked.length + (next == null ? 0 : 1),
        separatorBuilder: (_, _) => const SizedBox(width: Gap.sm),
        itemBuilder: (context, index) {
          if (index == unlocked.length) {
            return _LockedChip(species: next!, strings: strings);
          }
          final species = unlocked[index];
          return _SpeciesChip(
            species: species,
            label: strings.speciesName(species),
            selected: species == selected,
            onTap: () => store.updateSettings(
              store.settings.copyWith(preferredSpecies: species),
            ),
          );
        },
      ),
    );
  }
}

class _SpeciesChip extends StatelessWidget {
  const _SpeciesChip({
    required this.species,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Species species;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.time(context, Tempo.quick),
          width: 76,
          decoration: BoxDecoration(
            color: selected ? colors.accentSoft : colors.surfaceRaised,
            borderRadius: Radii.allMd,
            border: Border.all(
              color: selected ? colors.accent : colors.hairline,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Gap.sm, Gap.sm, Gap.sm, 0),
                  child: TreeView(
                    figure: TreeFigure(
                      species: species,
                      // A fixed seed per species, so the picker is a catalogue
                      // of shapes rather than a slot machine.
                      seed: species.index * 7717,
                      growth: 1,
                    ),
                    depthLimit: 3,
                    showGround: false,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.sm),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.caption.copyWith(
                    color: selected ? colors.accent : colors.inkMuted,
                    fontWeight: selected ? FontWeight.w600 : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LockedChip extends StatelessWidget {
  const _LockedChip({required this.species, required this.strings});

  final Species species;
  final S strings;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final threshold = strings.span(Duration(minutes: species.unlockMinutes));
    // The chip shows only the threshold. The full sentence wrapped onto three
    // lines at any text scale above the default and overflowed the strip, and
    // a screen reader gets it in full below regardless.
    return Semantics(
      label: strings.lockedUntil(threshold),
      excludeSemantics: true,
      child: Container(
        width: 76,
        padding: const EdgeInsets.all(Gap.sm),
        decoration: BoxDecoration(
          color: colors.surfaceSunken,
          borderRadius: Radii.allMd,
          border: Border.all(color: colors.hairline),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, size: 18, color: colors.inkFaint),
            const SizedBox(height: Gap.xs),
            Text(
              threshold,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.type.caption,
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalLine extends StatelessWidget {
  const _GoalLine({required this.store, required this.strings});

  final GardenStore store;
  final S strings;

  @override
  Widget build(BuildContext context) {
    final remaining = store.settings.dailyGoal - store.todayTotal.focused;
    final met = remaining <= Duration.zero;
    return PaperCard(
      accent: met,
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle_outline_rounded : Icons.timelapse_rounded,
            size: 18,
            color: met ? context.colors.accent : context.colors.inkMuted,
          ),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Text(
              met
                  ? strings.goalMet
                  : strings.goalRemaining(strings.span(remaining)),
              style: context.type.body,
            ),
          ),
          Text(
            strings.span(store.todayTotal.focused),
            style: context.type.numeric,
          ),
        ],
      ),
    );
  }
}

class _Running extends StatelessWidget {
  const _Running({
    required this.store,
    required this.strings,
    required this.onGiveUp,
  });

  final GardenStore store;
  final S strings;
  final VoidCallback onGiveUp;

  @override
  Widget build(BuildContext context) {
    final controller = store.controller;
    final active = controller.active!;

    return Column(
      children: [
        const SizedBox(height: Gap.sm),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: AspectRatio(
                aspectRatio: 1,
                child: DurationDial(
                  value: active.planned,
                  min: GroveSettings.minDuration,
                  max: GroveSettings.maxDuration,
                  step: GroveSettings.durationStep,
                  progress: controller.progress,
                  // Read-only while running: the commitment was made at start.
                  onChanged: null,
                  child: Padding(
                    padding: const EdgeInsets.all(Gap.x3l),
                    child: TreeView(
                      figure: TreeFigure(
                        species: active.species,
                        seed: active.id.hashCode & 0x7fffffff,
                        growth: controller.progress,
                      ),
                      breeze: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Text(
          Fmt.clock(controller.remaining),
          style: context.type.numericLarge,
        ),
        if (active.tag != null) ...[
          const SizedBox(height: Gap.xs),
          Text(active.tag!, style: context.type.label),
        ],
        const SizedBox(height: Gap.xl),
        PaperButton(
          label: strings.giveUp,
          kind: PaperButtonKind.ghost,
          onPressed: onGiveUp,
        ),
        const SizedBox(height: Gap.xxl),
      ],
    );
  }
}

class _Outcome extends StatelessWidget {
  const _Outcome({
    required this.store,
    required this.strings,
    required this.onDone,
  });

  final GardenStore store;
  final S strings;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final result = store.controller.result;
    if (result == null) {
      // Nothing to show: the result was acknowledged between frames.
      return const SizedBox.shrink();
    }
    final succeeded = result.outcome == SessionOutcome.completed;
    final percent = '${(result.completion * 100).round()}%';

    return Column(
      children: [
        const SizedBox(height: Gap.sm),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: AspectRatio(
                aspectRatio: 1,
                child: TreeView(
                  figure: TreeFigure(
                    species: result.species,
                    seed: result.seed,
                    // A withered tree is drawn at the growth it reached, so a
                    // session abandoned at 90% leaves a nearly-full stump and
                    // one abandoned instantly leaves a twig.
                    growth: succeeded ? 1 : result.completion,
                    withered: !succeeded,
                  ),
                ),
              ),
            ),
          ),
        ),
        Text(
          succeeded ? strings.plantedTitle : strings.witheredTitle,
          style: context.type.title,
        ),
        const SizedBox(height: Gap.sm),
        Text(
          succeeded
              ? strings.plantedBody
              : strings.witheredBody(
                  store.controller.failureReason ?? FailureReason.gaveUp,
                ),
          textAlign: TextAlign.center,
          style: context.type.body.copyWith(color: context.colors.inkMuted),
        ),
        const SizedBox(height: Gap.sm),
        Text(
          succeeded
              ? strings.span(result.elapsed)
              : '${strings.sessionReached(percent)} · '
                    '${strings.span(result.elapsed)}',
          style: context.type.label,
        ),
        const SizedBox(height: Gap.xxl),
        PaperButton(
          label: strings.done,
          size: PaperButtonSize.large,
          expand: true,
          onPressed: onDone,
        ),
        const SizedBox(height: Gap.xxl),
      ],
    );
  }
}
