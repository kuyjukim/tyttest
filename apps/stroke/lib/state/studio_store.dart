import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../data/sketch_repository.dart';
import '../domain/canvas_transform.dart';
import '../domain/commands.dart';
import '../domain/ink.dart';
import '../domain/sketch.dart';
import '../domain/stroke_math.dart';

/// What a pointer drag does.
enum Tool {
  draw,

  /// Removes whole strokes it touches.
  ///
  /// Stroke-level rather than pixel-level because this is a vector tool: a
  /// pixel eraser would force every stroke to be rasterised on first edit,
  /// which is the moment a vector drawing stops being resolution-independent.
  erase,

  /// Pans and zooms without drawing. Single-finger pan is also available
  /// through the two-finger gesture, but a mouse has only one pointer.
  pan,
}

/// The brush settings currently selected.
@immutable
class Brush {
  const Brush({
    required this.kind,
    required this.width,
    required this.colorValue,
    required this.opacity,
  });

  factory Brush.of(BrushKind kind, {int colorValue = 0xFF1C1A17}) => Brush(
    kind: kind,
    width: kind.defaultWidth,
    colorValue: colorValue,
    opacity: kind.defaultOpacity,
  );

  final BrushKind kind;
  final double width;
  final int colorValue;
  final double opacity;

  Brush copyWith({
    BrushKind? kind,
    double? width,
    int? colorValue,
    double? opacity,
  }) => Brush(
    kind: kind ?? this.kind,
    width: width ?? this.width,
    colorValue: colorValue ?? this.colorValue,
    opacity: opacity ?? this.opacity,
  );
}

/// Application state for Stroke.
class StudioStore extends ChangeNotifier {
  StudioStore({
    required SketchRepository repository,
    required DateTime Function() clock,
    required String Function() idFactory,
    this.autosaveDelay = const Duration(seconds: 2),
  }) : _repository = repository,
       _clock = clock,
       _idFactory = idFactory;

  /// How long after the last change the drawing is written.
  ///
  /// Saving on every stroke re-serialises the whole drawing, which gets
  /// slower the more the user draws; waiting for a pause writes once for a
  /// burst of strokes. Anything that could lose the buffer - closing the
  /// sketch, the app leaving the foreground - calls [flush] instead of
  /// waiting.
  ///
  /// [Duration.zero] means write immediately, with no timer at all. That is
  /// what widget tests use: a pending timer at the end of a test is a real
  /// failure the harness is right to report, and arming one for a save that
  /// is about to be asserted on is not worth the noise.
  final Duration autosaveDelay;

  final SketchRepository _repository;
  final DateTime Function() _clock;
  final String Function() _idFactory;

  List<SketchSummary> _gallery = const <SketchSummary>[];
  Sketch? _sketch;
  UndoStack _history = UndoStack();
  Brush _brush = Brush.of(BrushKind.pen);
  Tool _tool = Tool.draw;
  CanvasTransform _transform = const CanvasTransform();
  bool _ready = false;
  bool _dirty = false;
  Timer? _autosave;

  /// Points of the stroke being drawn right now, in canvas units.
  final List<InkPoint> _live = <InkPoint>[];

  /// Strokes removed by the eraser drag in progress.
  final List<(int index, Stroke stroke)> _erasing = <(int, Stroke)>[];

  bool get ready => _ready;
  List<SketchSummary> get gallery => _gallery;
  Sketch? get sketch => _sketch;
  UndoStack get history => _history;
  Brush get brush => _brush;
  Tool get tool => _tool;
  CanvasTransform get transform => _transform;
  bool get hasUnsavedChanges => _dirty;

  /// The live stroke, for the preview layer. Empty when not drawing.
  List<InkPoint> get liveStroke => List<InkPoint>.unmodifiable(_live);

  bool get isDrawing => _live.isNotEmpty;

  Future<void> initialize() async {
    _gallery = await _repository.listSketches();
    _ready = true;
    notifyListeners();
  }

  /// Creates a drawing and opens it.
  Future<Sketch> createSketch({String? name}) async {
    await flush();
    final now = _clock();
    final sketch = Sketch.blank(
      id: _idFactory(),
      layerId: _idFactory(),
      name: name ?? 'Untitled',
      now: now,
    );
    _sketch = sketch;
    _history = UndoStack();
    _transform = const CanvasTransform();
    _dirty = true;
    await flush();
    notifyListeners();
    return sketch;
  }

  Future<void> openSketch(String id) async {
    await flush();
    final loaded = await _repository.load(id);
    if (loaded == null) {
      // The row pointed at nothing; refresh the gallery so it stops showing.
      _gallery = await _repository.listSketches();
      notifyListeners();
      return;
    }
    _sketch = loaded;
    _history = UndoStack();
    _transform = const CanvasTransform();
    _dirty = false;
    notifyListeners();
  }

  /// Saves and leaves the editor.
  Future<void> closeSketch() async {
    await flush();
    _sketch = null;
    _history = UndoStack();
    _live.clear();
    _erasing.clear();
    _gallery = await _repository.listSketches();
    notifyListeners();
  }

  Future<void> deleteSketch(String id) async {
    if (_sketch?.id == id) {
      _autosave?.cancel();
      _autosave = null;
      _dirty = false;
      _sketch = null;
      _history = UndoStack();
    }
    await _repository.delete(id);
    _gallery = await _repository.listSketches();
    notifyListeners();
  }

  Future<void> renameSketch(String name) async {
    final sketch = _sketch;
    if (sketch == null) return;
    sketch.name = name.trim().isEmpty ? 'Untitled' : name.trim();
    _markDirty();
    await flush();
  }

  void selectTool(Tool tool) {
    if (_tool == tool) return;
    _tool = tool;
    notifyListeners();
  }

  void selectBrush(BrushKind kind) {
    if (_brush.kind == kind) {
      _tool = Tool.draw;
      notifyListeners();
      return;
    }
    _brush = Brush.of(kind, colorValue: _brush.colorValue);
    _tool = Tool.draw;
    notifyListeners();
  }

  void setBrushWidth(double width) {
    _brush = _brush.copyWith(width: width.clamp(0.5, 120.0));
    notifyListeners();
  }

  void setBrushColor(int colorValue) {
    _brush = _brush.copyWith(colorValue: colorValue);
    notifyListeners();
  }

  void setTransform(CanvasTransform transform) {
    _transform = transform;
    notifyListeners();
  }

  void selectLayer(int index) {
    final sketch = _sketch;
    if (sketch == null) return;
    sketch.activeLayerIndex = index.clamp(0, sketch.layers.length - 1);
    notifyListeners();
  }

  // --- drawing -------------------------------------------------------------

  /// Starts a stroke at a canvas-space point.
  void beginStroke(Offset canvasPoint, double pressure) {
    if (_sketch == null || _tool != Tool.draw) return;
    _live
      ..clear()
      ..add(InkPoint(canvasPoint, pressure.clamp(0.0, 1.0)));
    notifyListeners();
  }

  void extendStroke(Offset canvasPoint, double pressure) {
    if (_live.isEmpty) return;
    _live.add(InkPoint(canvasPoint, pressure.clamp(0.0, 1.0)));
    notifyListeners();
  }

  /// Commits the live stroke. A tap with a single point becomes a dot.
  void endStroke() {
    final sketch = _sketch;
    if (sketch == null || _live.isEmpty) return;

    final thinned = StrokeMath.thin(_live);
    _live.clear();

    final stroke = Stroke(
      id: _idFactory(),
      kind: _brush.kind,
      colorValue: _brush.colorValue,
      width: _brush.width,
      opacity: _brush.opacity,
      points: thinned,
    );
    _history.run(
      AddStroke(layerId: sketch.activeLayer.id, stroke: stroke),
      sketch,
    );
    _markDirty();
    notifyListeners();
  }

  /// Throws away the stroke in progress, e.g. when a second finger lands and
  /// the gesture turns out to be a pinch.
  void cancelStroke() {
    if (_live.isEmpty) return;
    _live.clear();
    notifyListeners();
  }

  /// Marks strokes under the eraser for removal.
  ///
  /// They are collected across the whole drag and removed as one command, so
  /// a single swipe is a single undo rather than thirty.
  void eraseAt(Offset canvasPoint, double canvasRadius) {
    final sketch = _sketch;
    if (sketch == null || _tool != Tool.erase) return;
    final layer = sketch.activeLayer;

    var changed = false;
    for (var i = layer.strokes.length - 1; i >= 0; i--) {
      final stroke = layer.strokes[i];
      if (!StrokeMath.hits(stroke, canvasPoint, canvasRadius)) continue;
      _erasing.add((i, stroke));
      layer.strokes.removeAt(i);
      changed = true;
    }
    if (changed) notifyListeners();
  }

  /// Turns the accumulated erasures into one undoable command.
  void endErase() {
    final sketch = _sketch;
    if (sketch == null || _erasing.isEmpty) return;

    // The strokes were already removed as the finger moved, so the command
    // is pushed in its applied state: ascending by index, which is the order
    // revert needs to put them back where they were.
    final removed = <(int, Stroke)>[..._erasing]
      ..sort((a, b) => a.$1.compareTo(b.$1));
    _erasing.clear();

    final command = EraseStrokes(
      layerId: sketch.activeLayer.id,
      removed: removed,
    );
    _history.run(command, sketch);
    _markDirty();
    notifyListeners();
  }

  void undo() {
    final sketch = _sketch;
    if (sketch == null) return;
    if (_history.undo(sketch) == null) return;
    _markDirty();
    notifyListeners();
  }

  void redo() {
    final sketch = _sketch;
    if (sketch == null) return;
    if (_history.redo(sketch) == null) return;
    _markDirty();
    notifyListeners();
  }

  // --- layers --------------------------------------------------------------

  bool get canAddLayer =>
      _sketch != null && _sketch!.layers.length < Sketch.maxLayers;

  void addLayer() {
    final sketch = _sketch;
    if (sketch == null || !canAddLayer) return;
    _history.run(
      AddLayer(
        layer: Layer(
          id: _idFactory(),
          name: 'Layer ${sketch.layers.length + 1}',
        ),
        atIndex: sketch.activeLayerIndex + 1,
      ),
      sketch,
    );
    _markDirty();
    notifyListeners();
  }

  /// Deletes a layer. The last remaining layer is cleared instead, so there
  /// is always somewhere to draw.
  void removeLayer(int index) {
    final sketch = _sketch;
    if (sketch == null || index < 0 || index >= sketch.layers.length) return;

    if (sketch.layers.length == 1) {
      clearLayer(index);
      return;
    }
    _history.run(
      RemoveLayer(
        layer: sketch.layers[index],
        atIndex: index,
        previousActive: sketch.activeLayerIndex,
      ),
      sketch,
    );
    _markDirty();
    notifyListeners();
  }

  void clearLayer(int index) {
    final sketch = _sketch;
    if (sketch == null || index < 0 || index >= sketch.layers.length) return;
    final layer = sketch.layers[index];
    if (layer.strokes.isEmpty) return;
    _history.run(
      ClearLayer(
        layerId: layer.id,
        previous: List<Stroke>.of(layer.strokes),
      ),
      sketch,
    );
    _markDirty();
    notifyListeners();
  }

  void reorderLayer(int from, int to) {
    final sketch = _sketch;
    if (sketch == null || from == to) return;
    _history.run(ReorderLayer(from: from, to: to), sketch);
    _markDirty();
    notifyListeners();
  }

  void setLayerProperties(
    int index, {
    bool? visible,
    double? opacity,
    String? name,
  }) {
    final sketch = _sketch;
    if (sketch == null || index < 0 || index >= sketch.layers.length) return;
    final layer = sketch.layers[index];
    _history.run(
      SetLayerProperties(
        layerId: layer.id,
        wasVisible: layer.visible,
        wasOpacity: layer.opacity,
        wasName: layer.name,
        visible: visible,
        opacity: opacity,
        name: name,
      ),
      sketch,
    );
    _markDirty();
    notifyListeners();
  }

  // --- persistence ---------------------------------------------------------

  void _markDirty() {
    _dirty = true;
    _autosave?.cancel();
    if (autosaveDelay == Duration.zero) {
      _autosave = null;
      unawaited(flush());
      return;
    }
    _autosave = Timer(autosaveDelay, () => unawaited(flush()));
  }

  /// Writes the open sketch now, if anything has changed.
  Future<void> flush() async {
    _autosave?.cancel();
    _autosave = null;
    final sketch = _sketch;
    if (sketch == null || !_dirty) return;
    sketch.updatedAt = _clock();
    await _repository.save(sketch);
    _dirty = false;
    _gallery = await _repository.listSketches();
    notifyListeners();
  }

  @override
  void dispose() {
    _autosave?.cancel();
    super.dispose();
  }
}
