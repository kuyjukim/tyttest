import 'package:paper/paper.dart';

/// One movement of money against an envelope.
///
/// The amount is signed, with negative meaning money left the envelope. The
/// UI enters a spend as a positive number and negates it, which keeps the
/// arithmetic everywhere else a plain sum: an envelope's balance is its
/// allocation plus everything that happened to it, and a refund needs no
/// special case.
class Txn {
  const Txn({
    required this.id,
    required this.envelopeId,
    required this.date,
    required this.amountMinor,
    this.note = '',
  });

  factory Txn.fromJson(Map<String, Object?> json) => Txn(
    id: json['id']! as String,
    envelopeId: json['envelopeId']! as String,
    date: Day.parse(json['date']! as String),
    amountMinor: json['amountMinor']! as int,
    note: json['note'] as String? ?? '',
  );

  final String id;
  final String envelopeId;
  final Day date;

  /// Negative for an expense, positive for a refund or correction.
  final int amountMinor;

  final String note;

  bool get isExpense => amountMinor < 0;

  Txn copyWith({
    String? envelopeId,
    Day? date,
    int? amountMinor,
    String? note,
  }) => Txn(
    id: id,
    envelopeId: envelopeId ?? this.envelopeId,
    date: date ?? this.date,
    amountMinor: amountMinor ?? this.amountMinor,
    note: note ?? this.note,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'envelopeId': envelopeId,
    'date': date.toString(),
    'amountMinor': amountMinor,
    if (note.isNotEmpty) 'note': note,
  };

  @override
  bool operator ==(Object other) => other is Txn && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Txn($id, $envelopeId, $amountMinor, $date)';
}

/// What the user decided for one month: how much came in, and how much each
/// envelope gets.
///
/// Absent entries fall back to the envelope's default allocation, so a month
/// the user never touched still budgets sensibly, and changing a default does
/// not rewrite the months they already adjusted by hand.
class MonthPlan {
  const MonthPlan({
    this.incomeMinor = 0,
    this.allocations = const <String, int>{},
  });

  factory MonthPlan.fromJson(Map<String, Object?> json) {
    final raw = json['allocations'];
    final allocations = <String, int>{};
    if (raw is Map<String, Object?>) {
      for (final entry in raw.entries) {
        final value = entry.value;
        if (value is int) allocations[entry.key] = value;
      }
    }
    return MonthPlan(
      incomeMinor: switch (json['incomeMinor']) {
        final int value => value,
        _ => 0,
      },
      allocations: allocations,
    );
  }

  static const MonthPlan empty = MonthPlan();

  final int incomeMinor;

  /// Envelope id to this month's allocation, overriding the default.
  final Map<String, int> allocations;

  MonthPlan copyWith({int? incomeMinor, Map<String, int>? allocations}) =>
      MonthPlan(
        incomeMinor: incomeMinor ?? this.incomeMinor,
        allocations: allocations ?? this.allocations,
      );

  /// This plan with [envelopeId] budgeted at [minor].
  MonthPlan withAllocation(String envelopeId, int minor) => copyWith(
    allocations: <String, int>{...allocations, envelopeId: minor},
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'incomeMinor': incomeMinor,
    'allocations': allocations,
  };
}
