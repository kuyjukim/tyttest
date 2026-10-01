import 'package:paper/paper.dart';

/// A spending category with a monthly amount.
class Envelope {
  const Envelope({
    required this.id,
    required this.name,
    required this.slot,
    required this.allocationMinor,
    this.rollover = false,
    this.archived = false,
  });

  factory Envelope.fromJson(Map<String, Object?> json) => Envelope(
    id: json['id']! as String,
    name: json['name'] as String? ?? '',
    // Clamped into range so a file written by a build with more colours, or
    // edited by hand, cannot index past the palette.
    slot: switch (json['slot']) {
      final int value => value.abs() % Viz.slots,
      _ => 0,
    },
    allocationMinor: switch (json['allocationMinor']) {
      final int value => value < 0 ? 0 : value,
      _ => 0,
    },
    rollover: json['rollover'] as bool? ?? false,
    archived: json['archived'] as bool? ?? false,
  );

  final String id;
  final String name;

  /// Index into the validated chart palette.
  ///
  /// Stored on the envelope rather than derived from its position, so that
  /// archiving one or re-sorting the list never repaints the others. Colour
  /// follows the entity, not its rank.
  final int slot;

  /// Default amount budgeted each month, in minor units.
  final int allocationMinor;

  /// Whether what is left at month end carries into the next month.
  ///
  /// Carries overspending too, not just surplus. An envelope that forgives
  /// going over at midnight on the 31st is not a budget, it is a tally.
  final bool rollover;

  /// Hidden from new months, but kept so past months still add up.
  final bool archived;

  Envelope copyWith({
    String? name,
    int? slot,
    int? allocationMinor,
    bool? rollover,
    bool? archived,
  }) => Envelope(
    id: id,
    name: name ?? this.name,
    slot: slot ?? this.slot,
    allocationMinor: allocationMinor ?? this.allocationMinor,
    rollover: rollover ?? this.rollover,
    archived: archived ?? this.archived,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'slot': slot,
    'allocationMinor': allocationMinor,
    'rollover': rollover,
    'archived': archived,
  };

  @override
  bool operator ==(Object other) => other is Envelope && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Envelope($id, $name)';
}
