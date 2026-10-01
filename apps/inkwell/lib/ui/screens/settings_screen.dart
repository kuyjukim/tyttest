import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:paper/paper.dart';

import '../../crypto/vault_cipher.dart';
import '../../domain/passphrase.dart';
import '../../domain/prefs.dart';
import '../../state/vault_store.dart';
import '../strings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = Scope.watch<VaultStore>(context);
    final strings = S.of(context);
    final prefs = store.prefs;

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
          value: prefs.themeMode,
          onChanged: (mode) =>
              store.updatePrefs(prefs.copyWith(themeMode: mode)),
        ),

        SectionHeader(title: strings.security),
        SettingRow(
          title: strings.autoLock,
          value: _autoLockLabel(prefs.autoLock, strings),
          onTap: () => _pickAutoLock(context, store, strings),
        ),
        const Hairline(),
        SettingRow(
          title: strings.changePassphrase,
          onTap: () => _changePassphrase(context, store, strings),
        ),
        const Hairline(),
        SettingRow(title: strings.lockNow, onTap: store.lock),
        const SizedBox(height: Gap.lg),
        Text(strings.biometricsNote, style: context.type.caption),

        SectionHeader(title: strings.export),
        Text(
          strings.exportBody,
          style: context.type.body.copyWith(color: context.colors.inkMuted),
        ),
        const SizedBox(height: Gap.md),
        PaperButton(
          label: strings.export,
          kind: PaperButtonKind.ghost,
          onPressed: () => _export(context, store, strings),
        ),

        SectionHeader(title: strings.about),
        Text(
          strings.aboutBody,
          style: context.type.body.copyWith(color: context.colors.inkMuted),
        ),

        SectionHeader(title: strings.dangerZone),
        SettingRow(
          title: strings.destroyVault,
          destructive: true,
          onTap: () => _destroy(context, store, strings),
        ),
        const SizedBox(height: Gap.xl),
      ],
    );
  }

  static String _autoLockLabel(Duration value, S strings) {
    if (value == Duration.zero) return strings.autoLockImmediately;
    if (value >= Prefs.never) return strings.autoLockNever;
    return strings.span(value);
  }

  Future<void> _pickAutoLock(
    BuildContext context,
    VaultStore store,
    S strings,
  ) async {
    final picked = await showPaperSheet<Duration>(
      context: context,
      title: strings.autoLock,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in Prefs.autoLockChoices) ...[
            SettingRow(
              title: _autoLockLabel(option, strings),
              value: option == store.prefs.autoLock ? '✓' : null,
              onTap: () => Navigator.of(context).pop(option),
            ),
            if (option != Prefs.autoLockChoices.last) const Hairline(),
          ],
        ],
      ),
    );
    if (picked == null) return;
    await store.updatePrefs(store.prefs.copyWith(autoLock: picked));
  }

  Future<void> _changePassphrase(
    BuildContext context,
    VaultStore store,
    S strings,
  ) async {
    final changed = await showPaperSheet<bool>(
      context: context,
      title: strings.changePassphrase,
      builder: (context) => _ChangePassphraseForm(store: store, strings: strings),
    );
    if (changed != true || !context.mounted) return;
    showPaperToast(context, strings.passphraseChanged);
  }

  Future<void> _export(
    BuildContext context,
    VaultStore store,
    S strings,
  ) async {
    final confirmed = await confirmDestructive(
      context,
      title: strings.export,
      message: strings.exportWarning,
      confirmLabel: strings.exportAction,
    );
    if (!confirmed) return;

    final markdown = store.exportMarkdown();
    // The clipboard rather than a share sheet: sharing needs a plugin, and
    // handing plaintext to an arbitrary share target is exactly the step the
    // warning above is about. The user pastes it where they meant to.
    await Clipboard.setData(ClipboardData(text: markdown));
    if (!context.mounted) return;
    showPaperToast(context, strings.exportedToast);
  }

  Future<void> _destroy(
    BuildContext context,
    VaultStore store,
    S strings,
  ) async {
    final confirmed = await confirmDestructive(
      context,
      title: strings.destroyConfirmTitle,
      message: strings.destroyConfirmBody,
      confirmLabel: strings.destroyConfirmAction,
    );
    if (!confirmed) return;
    await store.destroyVault();
  }
}

class _ChangePassphraseForm extends StatefulWidget {
  const _ChangePassphraseForm({required this.store, required this.strings});

  final VaultStore store;
  final S strings;

  @override
  State<_ChangePassphraseForm> createState() => _ChangePassphraseFormState();
}

class _ChangePassphraseFormState extends State<_ChangePassphraseForm> {
  final TextEditingController _current = TextEditingController();
  final TextEditingController _next = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    final strength = Passphrase.rate(_next.text);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _current,
          obscureText: true,
          autofocus: true,
          enabled: !_busy,
          onChanged: (_) => setState(() => _error = null),
          decoration: InputDecoration(labelText: strings.currentPassphrase),
        ),
        const SizedBox(height: Gap.lg),
        TextField(
          controller: _next,
          obscureText: true,
          enabled: !_busy,
          onChanged: (_) => setState(() => _error = null),
          decoration: InputDecoration(
            labelText: strings.newPassphrase,
            helperText: strings.strengthLabel(strength),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: Gap.md),
          Text(
            _error!,
            style: context.type.caption.copyWith(color: context.colors.danger),
          ),
        ],
        const SizedBox(height: Gap.xl),
        PaperButton(
          label: strings.changeAction,
          expand: true,
          busy: _busy,
          onPressed: strength.isAcceptable ? _submit : null,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    String? failure;
    try {
      await widget.store.changePassphrase(
        current: _current.text,
        next: _next.text,
      );
    } on WrongPassphrase {
      failure = widget.strings.wrongPassphrase;
    }

    if (!mounted) return;
    if (failure == null) {
      navigator.pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _error = failure;
    });
  }
}
