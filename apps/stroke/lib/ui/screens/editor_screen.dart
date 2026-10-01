import 'package:flutter/material.dart';
import 'package:paper/paper.dart';

import '../../domain/canvas_transform.dart';
import '../../domain/ink.dart';
import '../../state/studio_store.dart';
import '../palette.dart';
import '../strings.dart';
import '../widgets/sketch_canvas.dart';
import 'layer_sheet.dart';

/// The drawing screen: canvas, a tool strip, and nothing else competing for
/// the space.
class EditorScreen extends StatelessWidget {
  const EditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = Scope.watch<StudioStore>(context);
    final strings = S.of(context);
    final sketch = store.sketch;
    if (sketch == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: context.colors.surfaceSunken,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        leading: PaperIconButton(
          icon: Icons.arrow_back_rounded,
          tooltip: strings.done,
          onPressed: store.closeSketch,
        ),
        title: GestureDetector(
          onTap: () => _rename(context, store, strings),
          child: Text(sketch.name, style: context.type.heading),
        ),
        actions: [
          PaperIconButton(
            icon: Icons.undo_rounded,
            tooltip: strings.undo,
            onPressed: store.history.canUndo ? store.undo : null,
          ),
          PaperIconButton(
            icon: Icons.redo_rounded,
            tooltip: strings.redo,
            onPressed: store.history.canRedo ? store.redo : null,
          ),
          PaperIconButton(
            icon: Icons.layers_outlined,
            tooltip: strings.layers,
            onPressed: () => showLayerSheet(context, store: store),
          ),
          const SizedBox(width: Gap.xs),
        ],
      ),
      body: Column(
        children: [
          const Expanded(child: SketchCanvas()),
          _ToolStrip(store: store, strings: strings),
        ],
      ),
    );
  }

  Future<void> _rename(
    BuildContext context,
    StudioStore store,
    S strings,
  ) async {
    final name = await showPaperSheet<String>(
      context: context,
      title: strings.renameTitle,
      builder: (context) => const _RenameForm(),
    );
    if (name == null) return;
    await store.renameSketch(name);
  }
}

/// Owns its own controller.
///
/// Creating the controller in the caller and disposing it when the sheet's
/// future resolves looks right and is not: the sheet is still animating out
/// at that point, so its TextField rebuilds against a disposed controller and
/// throws. The widget that uses it has to be the widget that outlives it.
class _RenameForm extends StatefulWidget {
  const _RenameForm();

  @override
  State<_RenameForm> createState() => _RenameFormState();
}

class _RenameFormState extends State<_RenameForm> {
  late final TextEditingController _name = TextEditingController(
    text: Scope.read<StudioStore>(context).sketch?.name ?? '',
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = S.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _name,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.of(context).pop(value),
          decoration: InputDecoration(labelText: strings.nameLabel),
        ),
        const SizedBox(height: Gap.xl),
        PaperButton(
          label: strings.save,
          expand: true,
          onPressed: () => Navigator.of(context).pop(_name.text),
        ),
      ],
    );
  }
}

class _ToolStrip extends StatelessWidget {
  const _ToolStrip({required this.store, required this.strings});

  final StudioStore store;
  final S strings;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.md,
            vertical: Gap.sm,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  for (final kind in BrushKind.values)
                    _ToolButton(
                      icon: switch (kind) {
                        BrushKind.pen => Icons.edit_rounded,
                        BrushKind.marker => Icons.brush_rounded,
                        BrushKind.highlighter => Icons.format_color_fill_rounded,
                      },
                      label: strings.brushName(kind),
                      selected:
                          store.tool == Tool.draw && store.brush.kind == kind,
                      onTap: () => store.selectBrush(kind),
                    ),
                  const SizedBox(width: Gap.sm),
                  _ToolButton(
                    icon: Icons.cleaning_services_rounded,
                    label: strings.eraser,
                    selected: store.tool == Tool.erase,
                    onTap: () => store.selectTool(Tool.erase),
                  ),
                  _ToolButton(
                    icon: Icons.open_with_rounded,
                    label: strings.pan,
                    selected: store.tool == Tool.pan,
                    onTap: () => store.selectTool(Tool.pan),
                  ),
                  const Spacer(),
                  Text(
                    strings.zoomLabel((store.transform.scale * 100).round()),
                    style: context.type.caption,
                  ),
                  PaperIconButton(
                    icon: Icons.fit_screen_rounded,
                    tooltip: strings.fitToScreen,
                    onPressed: () => store.setTransform(
                      CanvasTransform.fit(
                        content: store.sketch!.size,
                        viewport: MediaQuery.sizeOf(context),
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  SizedBox(
                    width: 46,
                    child: Text(strings.size, style: context.type.caption),
                  ),
                  Expanded(
                    child: Slider(
                      value: store.brush.width.clamp(0.5, 60),
                      min: 0.5,
                      max: 60,
                      onChanged: store.setBrushWidth,
                    ),
                  ),
                  SizedBox(
                    width: 34,
                    child: Text(
                      store.brush.width.round().toString(),
                      textAlign: TextAlign.right,
                      style: context.type.numeric.copyWith(fontSize: 13),
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 36,
                child: Row(
                  children: [
                    SizedBox(
                      width: 46,
                      child: Text(strings.colour, style: context.type.caption),
                    ),
                    Expanded(
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: InkPalette.colours.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: Gap.sm),
                        itemBuilder: (context, index) {
                          final colour = InkPalette.colours[index];
                          final value = colour.toARGB32();
                          final selected = store.brush.colorValue == value;
                          return Semantics(
                            selected: selected,
                            button: true,
                            label: '${strings.colour} ${index + 1}',
                            child: GestureDetector(
                              onTap: () => store.setBrushColor(value),
                              child: Container(
                                width: 28,
                                margin: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: colour,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    // A ring in the surface colour, then the
                                    // accent: white ink on a white page needs
                                    // an outline to be visible at all.
                                    color: selected
                                        ? colors.accent
                                        : colors.hairline,
                                    width: selected ? 3 : 1,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
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
      child: Tooltip(
        message: label,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: Motion.time(context, Tempo.quick),
            height: kMinTouchTarget,
            width: kMinTouchTarget,
            margin: const EdgeInsets.only(right: Gap.xs),
            decoration: BoxDecoration(
              color: selected ? colors.accentSoft : Colors.transparent,
              borderRadius: Radii.allSm,
              border: Border.all(
                color: selected ? colors.accent : Colors.transparent,
              ),
            ),
            child: Center(
              child: Icon(
                icon,
                size: 20,
                color: selected ? colors.accent : colors.inkMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
