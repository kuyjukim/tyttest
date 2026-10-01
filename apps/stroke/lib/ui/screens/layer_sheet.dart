import 'package:flutter/material.dart';
import 'package:paper/paper.dart';

import '../../state/studio_store.dart';
import '../strings.dart';

/// The layer stack, topmost first.
///
/// Reversed on purpose: the list reads the way the drawing looks, with the
/// layer nearest the viewer at the top. A list in storage order puts the
/// background first, which is the opposite of what anyone points at.
Future<void> showLayerSheet(
  BuildContext context, {
  required StudioStore store,
}) {
  final strings = S.of(context);
  return showPaperSheet<void>(
    context: context,
    title: strings.layers,
    builder: (context) => _LayerList(store: store, strings: strings),
  );
}

class _LayerList extends StatefulWidget {
  const _LayerList({required this.store, required this.strings});

  final StudioStore store;
  final S strings;

  @override
  State<_LayerList> createState() => _LayerListState();
}

class _LayerListState extends State<_LayerList> {
  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final strings = widget.strings;
    final sketch = store.sketch;
    if (sketch == null) return const SizedBox.shrink();

    final indices = <int>[
      for (var i = sketch.layers.length - 1; i >= 0; i--) i,
    ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final index in indices) ...[
            _LayerRow(
              store: store,
              strings: strings,
              index: index,
              onChanged: () => setState(() {}),
            ),
            if (index != 0) const Hairline(),
          ],
          const SizedBox(height: Gap.lg),
          PaperButton(
            label: store.canAddLayer
                ? strings.addLayer
                : strings.layerLimitReached,
            icon: store.canAddLayer ? Icons.add_rounded : null,
            kind: PaperButtonKind.tonal,
            expand: true,
            onPressed: store.canAddLayer
                ? () {
                    store.addLayer();
                    setState(() {});
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

class _LayerRow extends StatefulWidget {
  const _LayerRow({
    required this.store,
    required this.strings,
    required this.index,
    required this.onChanged,
  });

  final StudioStore store;
  final S strings;
  final int index;
  final VoidCallback onChanged;

  @override
  State<_LayerRow> createState() => _LayerRowState();
}

class _LayerRowState extends State<_LayerRow> {
  /// The opacity before the slider was touched.
  ///
  /// Needed because the drag writes straight to the layer for live feedback;
  /// without remembering where it started, the command pushed on release
  /// would record the *dragged* value as the one to undo to, and undo would
  /// jump the layer to wherever the finger happened to pass through.
  double? _opacityBeforeDrag;

  StudioStore get store => widget.store;
  S get strings => widget.strings;
  int get index => widget.index;
  void onChanged() => widget.onChanged();

  @override
  Widget build(BuildContext context) {
    final sketch = store.sketch!;
    final layer = sketch.layers[index];
    final selected = sketch.activeLayerIndex == index;
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: Gap.sm),
      decoration: BoxDecoration(
        color: selected ? colors.accentSoft : Colors.transparent,
        borderRadius: Radii.allSm,
      ),
      child: Column(
        children: [
          Row(
            children: [
              PaperIconButton(
                icon: layer.visible
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                tooltip: layer.visible ? strings.hideLayer : strings.showLayer,
                onPressed: () {
                  store.setLayerProperties(index, visible: !layer.visible);
                  onChanged();
                },
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    store.selectLayer(index);
                    onChanged();
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        layer.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.type.body.copyWith(
                          color: layer.visible ? colors.ink : colors.inkMuted,
                          fontWeight: selected ? FontWeight.w600 : null,
                        ),
                      ),
                      Text(
                        strings.strokeCount(layer.strokes.length),
                        style: context.type.caption,
                      ),
                    ],
                  ),
                ),
              ),
              PaperIconButton(
                icon: Icons.keyboard_arrow_up_rounded,
                tooltip: strings.moveUp,
                onPressed: index == sketch.layers.length - 1
                    ? null
                    : () {
                        store.reorderLayer(index, index + 1);
                        onChanged();
                      },
              ),
              PaperIconButton(
                icon: Icons.keyboard_arrow_down_rounded,
                tooltip: strings.moveDown,
                onPressed: index == 0
                    ? null
                    : () {
                        store.reorderLayer(index, index - 1);
                        onChanged();
                      },
              ),
            ],
          ),
          Row(
            children: [
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Slider(
                  value: layer.opacity,
                  // Written straight to the layer while dragging so the
                  // canvas follows the finger, then pushed through the
                  // command stack once on release - a command per frame would
                  // bury the undo history under one gesture.
                  onChangeStart: (_) => _opacityBeforeDrag = layer.opacity,
                  onChanged: (value) {
                    layer.opacity = value;
                    onChanged();
                  },
                  onChangeEnd: (value) {
                    layer.opacity = _opacityBeforeDrag ?? layer.opacity;
                    _opacityBeforeDrag = null;
                    store.setLayerProperties(index, opacity: value);
                    onChanged();
                  },
                ),
              ),
              PaperIconButton(
                icon: Icons.layers_clear_rounded,
                tooltip: strings.clearLayer,
                onPressed: layer.strokes.isEmpty
                    ? null
                    : () {
                        store.clearLayer(index);
                        onChanged();
                      },
              ),
              PaperIconButton(
                icon: Icons.delete_outline_rounded,
                tooltip: strings.deleteLayer,
                color: colors.danger,
                onPressed: () {
                  store.removeLayer(index);
                  onChanged();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
