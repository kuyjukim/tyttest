import 'ink.dart';
import 'sketch.dart';

/// A reversible change to a [Sketch].
///
/// Commands rather than document snapshots. A snapshot per stroke means
/// copying every point in the drawing on every stroke, which at a few
/// thousand strokes is megabytes of garbage per second; a command stores only
/// what changed, so undo depth costs almost nothing.
abstract interface class SketchCommand {
  /// Applies the change. Must be safe to call again after [revert].
  void apply(Sketch sketch);

  /// Puts the sketch back exactly as it was before [apply].
  void revert(Sketch sketch);

  /// Shown in the undo tooltip.
  String get label;
}

/// Adds one stroke to a layer.
class AddStroke implements SketchCommand {
  AddStroke({required this.layerId, required this.stroke});

  final String layerId;
  final Stroke stroke;

  @override
  String get label => 'Stroke';

  @override
  void apply(Sketch sketch) => sketch.layerById(layerId)?.strokes.add(stroke);

  @override
  void revert(Sketch sketch) =>
      sketch.layerById(layerId)?.strokes.removeWhere((s) => s.id == stroke.id);
}

/// Removes strokes from a layer, remembering where each one was.
///
/// The index matters: putting an erased stroke back on top would change what
/// covers what, so undo has to restore its place in the stack as well as its
/// existence.
class EraseStrokes implements SketchCommand {
  EraseStrokes({required this.layerId, required this.removed});

  final String layerId;

  /// Index and stroke, ascending by index.
  final List<(int index, Stroke stroke)> removed;

  @override
  String get label => 'Erase';

  @override
  void apply(Sketch sketch) {
    final layer = sketch.layerById(layerId);
    if (layer == null) return;
    final ids = <String>{for (final entry in removed) entry.$2.id};
    layer.strokes.removeWhere((stroke) => ids.contains(stroke.id));
  }

  @override
  void revert(Sketch sketch) {
    final layer = sketch.layerById(layerId);
    if (layer == null) return;
    // Ascending, so each insert lands at the index it originally held.
    for (final entry in removed) {
      final index = entry.$1.clamp(0, layer.strokes.length);
      layer.strokes.insert(index, entry.$2);
    }
  }
}

/// Empties a layer.
class ClearLayer implements SketchCommand {
  ClearLayer({required this.layerId, required this.previous});

  final String layerId;
  final List<Stroke> previous;

  @override
  String get label => 'Clear layer';

  @override
  void apply(Sketch sketch) => sketch.layerById(layerId)?.strokes.clear();

  @override
  void revert(Sketch sketch) {
    final layer = sketch.layerById(layerId);
    if (layer == null) return;
    layer.strokes
      ..clear()
      ..addAll(previous);
  }
}

/// Adds a layer above the current one.
class AddLayer implements SketchCommand {
  AddLayer({required this.layer, required this.atIndex});

  final Layer layer;
  final int atIndex;

  @override
  String get label => 'Add layer';

  @override
  void apply(Sketch sketch) {
    final index = atIndex.clamp(0, sketch.layers.length);
    sketch.layers.insert(index, layer);
    sketch.activeLayerIndex = index;
  }

  @override
  void revert(Sketch sketch) {
    sketch.layers.removeWhere((l) => l.id == layer.id);
    sketch.activeLayerIndex =
        sketch.activeLayerIndex.clamp(0, sketch.layers.length - 1);
  }
}

/// Deletes a layer and everything on it.
class RemoveLayer implements SketchCommand {
  RemoveLayer({
    required this.layer,
    required this.atIndex,
    required this.previousActive,
  });

  final Layer layer;
  final int atIndex;
  final int previousActive;

  @override
  String get label => 'Delete layer';

  @override
  void apply(Sketch sketch) {
    sketch.layers.removeWhere((l) => l.id == layer.id);
    sketch.activeLayerIndex =
        sketch.activeLayerIndex.clamp(0, sketch.layers.length - 1);
  }

  @override
  void revert(Sketch sketch) {
    sketch.layers.insert(atIndex.clamp(0, sketch.layers.length), layer);
    sketch.activeLayerIndex =
        previousActive.clamp(0, sketch.layers.length - 1);
  }
}

/// Moves a layer up or down the stack.
class ReorderLayer implements SketchCommand {
  ReorderLayer({required this.from, required this.to});

  final int from;
  final int to;

  @override
  String get label => 'Reorder layers';

  @override
  void apply(Sketch sketch) => _move(sketch, from, to);

  @override
  void revert(Sketch sketch) => _move(sketch, to, from);

  static void _move(Sketch sketch, int from, int to) {
    if (from < 0 || from >= sketch.layers.length) return;
    if (to < 0 || to >= sketch.layers.length) return;
    final layer = sketch.layers.removeAt(from);
    sketch.layers.insert(to, layer);
    sketch.activeLayerIndex = to;
  }
}

/// Changes a layer's visibility or opacity.
class SetLayerProperties implements SketchCommand {
  SetLayerProperties({
    required this.layerId,
    required this.wasVisible,
    required this.wasOpacity,
    required this.wasName,
    this.visible,
    this.opacity,
    this.name,
  });

  final String layerId;
  final bool wasVisible;
  final double wasOpacity;
  final String wasName;
  final bool? visible;
  final double? opacity;
  final String? name;

  @override
  String get label => 'Layer settings';

  @override
  void apply(Sketch sketch) {
    final layer = sketch.layerById(layerId);
    if (layer == null) return;
    if (visible != null) layer.visible = visible!;
    if (opacity != null) layer.opacity = opacity!.clamp(0.0, 1.0);
    if (name != null) layer.name = name!;
  }

  @override
  void revert(Sketch sketch) {
    final layer = sketch.layerById(layerId);
    if (layer == null) return;
    layer
      ..visible = wasVisible
      ..opacity = wasOpacity
      ..name = wasName;
  }
}

/// Applied commands, and the ones that have been undone.
class UndoStack {
  UndoStack({this.capacity = 300})
    : assert(capacity > 0, 'an undo stack of nothing is not an undo stack');

  /// How many commands are remembered.
  ///
  /// Past this the oldest is forgotten, which is a real limit the UI does not
  /// pretend away: "unlimited undo" that silently stops working is worse than
  /// a deep limit.
  final int capacity;

  final List<SketchCommand> _done = <SketchCommand>[];
  final List<SketchCommand> _undone = <SketchCommand>[];

  bool get canUndo => _done.isNotEmpty;
  bool get canRedo => _undone.isNotEmpty;
  int get depth => _done.length;
  int get redoDepth => _undone.length;

  String? get nextUndoLabel => _done.isEmpty ? null : _done.last.label;
  String? get nextRedoLabel => _undone.isEmpty ? null : _undone.last.label;

  /// Applies [command] and makes it the next thing undone.
  ///
  /// Doing anything new discards the redo chain: keeping it would let a redo
  /// re-apply a command against a document that has moved on underneath it.
  void run(SketchCommand command, Sketch sketch) {
    command.apply(sketch);
    _done.add(command);
    _undone.clear();
    while (_done.length > capacity) {
      _done.removeAt(0);
    }
  }

  /// Reverts the most recent command. Returns it, or null when there is none.
  SketchCommand? undo(Sketch sketch) {
    if (_done.isEmpty) return null;
    final command = _done.removeLast();
    command.revert(sketch);
    _undone.add(command);
    return command;
  }

  /// Re-applies the most recently undone command.
  SketchCommand? redo(Sketch sketch) {
    if (_undone.isEmpty) return null;
    final command = _undone.removeLast();
    command.apply(sketch);
    _done.add(command);
    return command;
  }

  void clear() {
    _done.clear();
    _undone.clear();
  }
}
