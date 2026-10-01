import 'package:paper/paper.dart';

import '../domain/budget.dart';
import '../domain/envelope.dart';
import '../domain/money.dart';
import '../domain/txn.dart';

/// Reads and writes the whole budget as one JSON document.
class BudgetRepository {
  BudgetRepository(KeyValueStore store)
    : _document = JsonDocument<Budget>(
        store: store,
        key: 'ledger.budget.v1',
        empty: () => Budget.empty,
        decode: _decode,
        encode: _encode,
      );

  final JsonDocument<Budget> _document;

  Future<Budget> load({void Function(Object error)? onCorrupt}) =>
      _document.load(onCorrupt: onCorrupt);

  Future<void> save(Budget budget) => _document.save(budget);

  static Budget _decode(Map<String, Object?> json) {
    final envelopes = <Envelope>[];
    final rawEnvelopes = json['envelopes'];
    if (rawEnvelopes is List) {
      for (final raw in rawEnvelopes) {
        if (raw is! Map<String, Object?>) continue;
        try {
          envelopes.add(Envelope.fromJson(raw));
        } on Object {
          continue;
        }
      }
    }

    // Transactions are dropped individually on failure. A budget is worth
    // more than its worst record: losing one line beats refusing to open.
    final transactions = <Txn>[];
    final rawTransactions = json['transactions'];
    if (rawTransactions is List) {
      for (final raw in rawTransactions) {
        if (raw is! Map<String, Object?>) continue;
        try {
          transactions.add(Txn.fromJson(raw));
        } on Object {
          continue;
        }
      }
    }

    final plans = <String, MonthPlan>{};
    final rawPlans = json['plans'];
    if (rawPlans is Map<String, Object?>) {
      for (final entry in rawPlans.entries) {
        final value = entry.value;
        if (value is! Map<String, Object?>) continue;
        try {
          plans[entry.key] = MonthPlan.fromJson(value);
        } on Object {
          continue;
        }
      }
    }

    final rawSettings = json['settings'];
    return Budget(
      currency: Currency.byCode(json['currency'] as String?),
      envelopes: envelopes,
      transactions: transactions,
      plans: plans,
      settings: rawSettings is Map<String, Object?>
          ? LedgerSettings.fromJson(rawSettings)
          : const LedgerSettings(),
    );
  }

  static Map<String, Object?> _encode(Budget budget) => <String, Object?>{
    'version': 1,
    'currency': budget.currency.code,
    'envelopes': <Object?>[for (final e in budget.envelopes) e.toJson()],
    'transactions': <Object?>[for (final t in budget.transactions) t.toJson()],
    'plans': <String, Object?>{
      for (final entry in budget.plans.entries) entry.key: entry.value.toJson(),
    },
    'settings': budget.settings.toJson(),
  };
}
