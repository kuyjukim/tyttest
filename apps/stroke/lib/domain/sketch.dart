import 'dart:ui';

import 'ink.dart';

/// A stack of strokes that can be hidden or faded as a unit.
///
/// Mutable, unlike most of the models in this suite. A drawing is tens of
/// thousands of points, and the undo system works by applying and reverting
/// commands against one live document; copying the whole sketch on every
/// stroke would allocate megabytes per second while the user is drawing.
class Layer {
  Layer({
    required this.id,
    required this.name,
    List<Stroke>? strokes,
    this.visible = true,
    this.opacity = 1,
  }) : strokes = strokes ?? <Stroke>[];

  factory Layer.fromJson(Map<String, Object?> json) {
    final rawStrokes = json['strokes'];
    final strokes = <Stroke>[];
    if (rawStrokes is List) {
      for (final raw in rawStrokes) {
        if (raw is! Map<String, Object?>) continue;
        try {
          strokes.add(Stroke.fromJson(raw));
        } on Object {
          // One unreadable stroke is not worth the rest of the drawing.
          continue;
        }
      }
    }
    return Layer(
      id: json['id']! as String,
      name: json['name'] as String? ?? '',
      strokes: strokes,
      visible: json['visible'] as bool? ?? true,
      opacity: switch (json['opacity']) {
        final num value => value.toDouble().clamp(0.0, 1.0),
        _ => 1.0,
      },
    );
  }

  final String id;
  String name;
  final List<Stroke> strokes;
  bool visible;
  double opacity;

  bool get isEmpty => strokes.isEmpty;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'visible': visible,
    'opacity': opacity,
    'strokes': <Object?>[for (final stroke in strokes) stroke.toJson()],
  };

  @override
  String toString() => 'Layer($id, "$name", ${strokes.length} strokes)';
}

/// One drawing.
class Sketch {
  Sketch({
    required this.id,
    required this.name,
    required this.size,
    required this.createdAt,
    required this.updatedAt,
    List<Layer>? layers,
    this.activeLayerIndex = 0,
  }) : layers = layers ?? <Layer>[];

  /// A new drawing with one empty layer.
  factory Sketch.blank({
    required String id,
    required String layerId,
    required String name,
    required DateTime now,
    Size size = defaultSize,
  }) => Sketch(
    id: id,
    name: name,
    size: size,
    createdAt: now,
    updatedAt: now,
    layers: <Layer>[Layer(id: layerId, name: 'Layer 1')],
  );

  factory Sketch.fromJson(Map<String, Object?> json) {
    final rawLayers = json['layers'];
    final layers = <Layer>[];
    if (rawLayers is List) {
      for (final raw in rawLayers) {
        if (raw is! Map<String, Object?>) continue;
        try {
          layers.add(Layer.fromJson(raw));
        } on Object {
          continue;
        }
      }
    }
    // A sketch with no readable layers still opens, with somewhere to draw.
    if (layers.isEmpty) {
      layers.add(Layer(id: '${json['id']}-l1', name: 'Layer 1'));
    }

    final created = DateTime.tryParse(json['createdAt'] as String? ?? '');
    final updated = DateTime.tryParse(json['updatedAt'] as String? ?? '');
    final width = switch (json['width']) {
      final num value => value.toDouble(),
      _ => defaultSize.width,
    };
    final height = switch (json['height']) {
      final num value => value.toDouble(),
      _ => defaultSize.height,
    };

    return Sketch(
      id: json['id']! as String,
      name: json['name'] as String? ?? '',
      size: Size(
        width.clamp(64.0, 8192.0),
        height.clamp(64.0, 8192.0),
      ),
      createdAt: (created ?? DateTime.now()).toLocal(),
      updatedAt: (updated ?? created ?? DateTime.now()).toLocal(),
      layers: layers,
      activeLayerIndex: switch (json['activeLayerIndex']) {
        final int value => value.clamp(0, layers.length - 1),
        _ => 0,
      },
    );
  }

  /// 1536 x 2048 canvas units: a 3:4 page that exports at a useful size
  /// without making every sketch a 50 MB image.
  static const Size defaultSize = Size(1536, 2048);

  /// Most layers a sketch may have.
  ///
  /// Not a technical limit - a cap that keeps the layer sheet usable and the
  /// per-frame compositing cost bounded.
  static const int maxLayers = 8;

  final String id;
  String name;
  final Size size;
  final DateTime createdAt;
  DateTime updatedAt;
  final List<Layer> layers;
  int activeLayerIndex;

  Layer get activeLayer => layers[activeLayerIndex.clamp(0, layers.length - 1)];

  int get strokeCount =>
      layers.fold<int>(0, (sum, layer) => sum + layer.strokes.length);

  bool get isEmpty => strokeCount == 0;

  Layer? layerById(String id) {
    for (final layer in layers) {
      if (layer.id == id) return layer;
    }
    return null;
  }

  int indexOfLayer(String id) {
    for (var i = 0; i < layers.length; i++) {
      if (layers[i].id == id) return i;
    }
    return -1;
  }

  Rect get contentBounds {
    Rect? bounds;
    for (final layer in layers) {
      for (final stroke in layer.strokes) {
        bounds = bounds == null ? stroke.bounds : bounds.expandToInclude(
          stroke.bounds,
        );
      }
    }
    return bounds ?? Rect.fromLTWH(0, 0, size.width, size.height);
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'width': size.width,
    'height': size.height,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'activeLayerIndex': activeLayerIndex,
    'layers': <Object?>[for (final layer in layers) layer.toJson()],
  };

  @override
  String toString() =>
      'Sketch($id, "$name", ${layers.length} layers, $strokeCount strokes)';
}
