import 'dart:async';

import 'package:flutter/material.dart';
import 'package:paper/paper.dart';

import '../../crypto/vault_cipher.dart';
import '../../domain/passphrase.dart';
import '../../state/vault_store.dart';
import '../strings.dart';

/// The only way in: create a vault, or open the one that exists.
///
/// Both states live in one screen because they are the same conversation
/// about one passphrase, and because a user who has deleted their journal
/// should land on "choose a passphrase" without a navigation animation that
/// implies they went somewhere.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final TextEditingController _passphrase = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  bool _busy = false;
  bool _reveal = false;
  String? _error;

  /// Re-renders the lockout countdown once a second while it is running.
  Timer? _countdown;

  @override
  void dispose() {
    _countdown?.cancel();
    _passphrase.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _syncCountdown(VaultStore store) {
    final needed = store.isLockedOut;
    if (needed && _countdown == null) {
      _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {});
        if (!Scope.read<VaultStore>(context).isLockedOut) {
          _countdown?.cancel();
          _countdown = null;
        }
      });
    } else if (!needed && _countdown != null) {
      _countdown!.cancel();
      _countdown = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = Scope.watch<VaultStore>(context);
    final strings = S.of(context);
    final creating = store.status == VaultStatus.absent;
    _syncCountdown(store);

    final strength = Passphrase.rate(_passphrase.text);
    final lockout = store.lockoutRemaining;

    return Scaffold(
      backgroundColor: context.colors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Gap.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    creating ? Icons.edit_note_rounded : Icons.lock_outline_rounded,
                    size: 36,
                    color: context.colors.accent,
                  ),
                  const SizedBox(height: Gap.xl),
                  Text(
                    creating ? strings.createTitle : strings.unlockTitle,
                    style: context.type.title,
                  ),
                  if (creating) ...[
                    const SizedBox(height: Gap.md),
                    Text(
                      strings.createBody,
                      style: context.type.body.copyWith(
                        color: context.colors.inkMuted,
                      ),
                    ),
                    const SizedBox(height: Gap.lg),
                    _Warning(text: strings.noRecoveryWarning),
                  ],
                  const SizedBox(height: Gap.xxl),
                  TextField(
                    controller: _passphrase,
                    obscureText: !_reveal,
                    autofocus: true,
                    enabled: !_busy && lockout == Duration.zero,
                    textInputAction: creating
                        ? TextInputAction.next
                        : TextInputAction.go,
                    onChanged: (_) => setState(() => _error = null),
                    onSubmitted: creating ? null : (_) => _submit(store, strings),
                    decoration: InputDecoration(
                      labelText: strings.passphraseLabel,
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _reveal = !_reveal),
                        icon: Icon(
                          _reveal
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                        ),
                        tooltip: strings.passphraseLabel,
                      ),
                    ),
                  ),
                  if (creating) ...[
                    const SizedBox(height: Gap.md),
                    _StrengthMeter(
                      value: Passphrase.meter(_passphrase.text),
                      label: strings.strengthLabel(strength),
                      weak: strength == PassphraseStrength.tooShort ||
                          strength == PassphraseStrength.weak,
                    ),
                    const SizedBox(height: Gap.lg),
                    TextField(
                      controller: _confirm,
                      obscureText: !_reveal,
                      enabled: !_busy,
                      textInputAction: TextInputAction.go,
                      onChanged: (_) => setState(() => _error = null),
                      onSubmitted: (_) => _submit(store, strings),
                      decoration: InputDecoration(
                        labelText: strings.confirmLabel,
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: Gap.lg),
                    Text(
                      _error!,
                      style: context.type.body.copyWith(
                        color: context.colors.danger,
                      ),
                    ),
                  ],
                  if (lockout > Duration.zero) ...[
                    const SizedBox(height: Gap.lg),
                    Text(
                      strings.lockedOutFor(strings.span(lockout)),
                      style: context.type.body.copyWith(
                        color: context.colors.caution,
                      ),
                    ),
                  ] else if (!creating && store.failedAttempts > 0) ...[
                    const SizedBox(height: Gap.sm),
                    Text(
                      strings.attemptsSoFar(store.failedAttempts),
                      style: context.type.caption,
                    ),
                  ],
                  const SizedBox(height: Gap.xxl),
                  PaperButton(
                    label: creating ? strings.createAction : strings.unlockAction,
                    size: PaperButtonSize.large,
                    expand: true,
                    busy: _busy,
                    onPressed: lockout > Duration.zero
                        ? null
                        : () => _submit(store, strings),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit(VaultStore store, S strings) async {
    if (_busy) return;
    final creating = store.status == VaultStatus.absent;
    final passphrase = _passphrase.text;

    if (creating) {
      if (!Passphrase.rate(passphrase).isAcceptable) {
        setState(() => _error = strings.tooShort);
        return;
      }
      if (passphrase != _confirm.text) {
        setState(() => _error = strings.passphrasesDiffer);
        return;
      }
    } else if (passphrase.isEmpty) {
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    String? failure;
    try {
      if (creating) {
        await store.create(passphrase);
      } else {
        await store.unlock(passphrase);
      }
    } on WrongPassphrase {
      failure = strings.wrongPassphrase;
    } on VaultTooNew {
      failure = strings.vaultTooNew;
    } on VaultCorrupt {
      failure = strings.vaultCorrupt;
    } on StateError {
      // Locked out between the tap and the call.
      failure = strings.lockedOutFor(strings.span(store.lockoutRemaining));
    }

    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = failure;
      if (failure == null) {
        _passphrase.clear();
        _confirm.clear();
      }
    });
  }
}

class _Warning extends StatelessWidget {
  const _Warning({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: Radii.allSm,
        border: Border(left: BorderSide(color: colors.caution, width: 3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: colors.caution),
          const SizedBox(width: Gap.sm),
          Expanded(child: Text(text, style: context.type.caption)),
        ],
      ),
    );
  }
}

class _StrengthMeter extends StatelessWidget {
  const _StrengthMeter({
    required this.value,
    required this.label,
    required this.weak,
  });

  final double value;
  final String label;
  final bool weak;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: Radii.allPill,
            child: Container(
              height: 4,
              color: colors.surfaceSunken,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: value.clamp(0.0, 1.0),
                child: AnimatedContainer(
                  duration: Motion.time(context, Tempo.base),
                  color: weak ? colors.caution : colors.positive,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: Gap.md),
        Text(
          label,
          style: context.type.caption.copyWith(
            color: weak ? colors.caution : colors.inkMuted,
          ),
        ),
      ],
    );
  }
}
