import 'package:flutter/material.dart';
import 'package:paper/paper.dart';

import '../../domain/entry.dart';
import '../../state/vault_store.dart';
import '../strings.dart';
import '../widgets/mood_dot.dart';

/// Write or edit one entry.
///
/// Saving is explicit rather than autosaving on every keystroke. Each save
/// re-seals the whole vault, and sealing on every character would be both
/// wasteful and a way to leave the file mid-write far more often.
class EditorScreen extends StatefulWidget {
  const EditorScreen({required this.entryId, super.key});

  /// Null composes a new entry.
  final String? entryId;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  final TextEditingController _tag = TextEditingController();

  Mood? _mood;
  late List<String> _tags;
  bool _dirty = false;
  bool _saving = false;

  Entry? get _existing {
    final id = widget.entryId;
    if (id == null) return null;
    return Scope.read<VaultStore>(context).journal?.byId(id);
  }

  @override
  void initState() {
    super.initState();
    // Read through the element rather than the widget's context extension,
    // because initState cannot create a dependency.
    final id = widget.entryId;
    final existing = id == null
        ? null
        : Scope.read<VaultStore>(context).journal?.byId(id);
    _title = TextEditingController(text: existing?.title ?? '');
    _body = TextEditingController(text: existing?.body ?? '');
    _mood = existing?.mood;
    _tags = <String>[...?existing?.tags];
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _tag.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = S.of(context);
    final existing = _existing;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // Captured before the await: resolving the Navigator afterwards
        // would be reaching through a context that may be gone.
        final navigator = Navigator.of(context);
        if (await _confirmDiscard(strings)) navigator.pop();
      },
      child: PaperScaffold(
        title: existing == null ? strings.newEntry : strings.save,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () async {
            final navigator = Navigator.of(context);
            if (!_dirty || await _confirmDiscard(strings)) navigator.pop();
          },
        ),
        actions: [
          if (existing != null)
            PaperIconButton(
              icon: Icons.delete_outline_rounded,
              tooltip: strings.delete,
              onPressed: () => _delete(existing, strings),
            ),
        ],
        body: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  TextField(
                    controller: _title,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => _markDirty(),
                    style: context.type.heading,
                    decoration: InputDecoration(
                      hintText: strings.titleHint,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const Hairline(),
                  const SizedBox(height: Gap.md),
                  TextField(
                    controller: _body,
                    autofocus: existing == null,
                    maxLines: null,
                    minLines: 10,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => _markDirty(),
                    style: context.type.body.copyWith(height: 1.6),
                    decoration: InputDecoration(
                      hintText: strings.bodyHint,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  SectionHeader(title: strings.moodLabel),
                  MoodPicker(
                    value: _mood,
                    label: strings.moodName,
                    onChanged: (mood) {
                      setState(() => _mood = mood);
                      _markDirty();
                    },
                  ),
                  SectionHeader(title: strings.tagsLabel),
                  _TagEditor(
                    tags: _tags,
                    controller: _tag,
                    hint: strings.addTagHint,
                    onAdd: _addTag,
                    onRemove: (tag) {
                      setState(() => _tags.remove(tag));
                      _markDirty();
                    },
                  ),
                  const SizedBox(height: Gap.x3l),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.lg, top: Gap.sm),
              child: Row(
                children: [
                  Text(
                    strings.wordCount(_wordCount),
                    style: context.type.caption,
                  ),
                  const Spacer(),
                  PaperButton(
                    label: strings.save,
                    busy: _saving,
                    onPressed: _canSave ? () => _save(strings) : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  int get _wordCount {
    final text = _body.text.trim();
    if (text.isEmpty) return 0;
    return text.split(RegExp(r'\s+')).length;
  }

  /// An entry with no title and no body is not worth sealing the vault for.
  bool get _canSave =>
      !_saving &&
      (_title.text.trim().isNotEmpty || _body.text.trim().isNotEmpty);

  void _markDirty() {
    if (_dirty) {
      // Still rebuild: the save button's enabled state tracks the text.
      setState(() {});
      return;
    }
    setState(() => _dirty = true);
  }

  void _addTag() {
    final value = _tag.text.trim();
    if (value.isEmpty) return;
    if (_tags.any((t) => t.toLowerCase() == value.toLowerCase())) {
      _tag.clear();
      return;
    }
    setState(() {
      _tags.add(value);
      _tag.clear();
    });
    _markDirty();
  }

  Future<bool> _confirmDiscard(S strings) async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.surfaceRaised,
        title: Text(strings.discardTitle, style: context.type.heading),
        content: Text(strings.discardBody, style: context.type.body),
        actions: [
          PaperButton(
            label: strings.keepEditing,
            kind: PaperButtonKind.ghost,
            size: PaperButtonSize.small,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          PaperButton(
            label: strings.discardAction,
            kind: PaperButtonKind.danger,
            size: PaperButtonSize.small,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  Future<void> _save(S strings) async {
    setState(() => _saving = true);
    final store = Scope.read<VaultStore>(context);
    await store.saveEntry(
      id: widget.entryId,
      title: _title.text,
      body: _body.text,
      mood: _mood,
      clearMood: _mood == null,
      tags: _tags,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _dirty = false;
    });
    Navigator.of(context).pop();
  }

  Future<void> _delete(Entry entry, S strings) async {
    final confirmed = await confirmDestructive(
      context,
      title: strings.deleteConfirmTitle,
      message: strings.deleteConfirmBody,
      confirmLabel: strings.deleteConfirmAction,
    );
    if (!confirmed || !mounted) return;
    await Scope.read<VaultStore>(context).deleteEntry(entry.id);
    if (mounted) Navigator.of(context).pop();
  }
}

class _TagEditor extends StatelessWidget {
  const _TagEditor({
    required this.tags,
    required this.controller,
    required this.hint,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> tags;
  final TextEditingController controller;
  final String hint;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tags.isNotEmpty)
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              for (final tag in tags)
                InputChip(
                  label: Text(tag),
                  onDeleted: () => onRemove(tag),
                  backgroundColor: colors.surfaceSunken,
                  side: BorderSide(color: colors.hairline),
                  labelStyle: context.type.caption.copyWith(color: colors.ink),
                ),
            ],
          ),
        const SizedBox(height: Gap.sm),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => onAdd(),
                decoration: InputDecoration(hintText: hint, isDense: true),
              ),
            ),
            const SizedBox(width: Gap.sm),
            PaperIconButton(
              icon: Icons.add_rounded,
              tooltip: hint,
              onPressed: onAdd,
            ),
          ],
        ),
      ],
    );
  }
}
