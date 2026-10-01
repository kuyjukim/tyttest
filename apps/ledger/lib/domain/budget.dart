import 'package:flutter/material.dart' show ThemeMode;

import 'envelope.dart';
import 'money.dart';
import 'month.dart';
import 'txn.dart';

/// Preferences that are not part of the budget itself.
class LedgerSettings {
  const LedgerSettings({this.themeMode = ThemeMode.system});

  factory LedgerSettings.fromJson(Map<String, Object?> json) => LedgerSettings(
    themeMode: switch (json['themeMode']) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    },
  );

  final ThemeMode themeMode;

  LedgerSettings copyWith({ThemeMode? themeMode}) =>
      LedgerSettings(themeMode: themeMode ?? this.themeMode);

  Map<String, Object?> toJson() => <String, Object?>{
    'themeMode': themeMode.name,
  };
}

/// Everything Ledger stores.
class Budget {
  const Budget({
    this.currency = Currency.krw,
    this.envelopes = const <Envelope>[],
    this.transactions = const <Txn>[],
    this.plans = const <String, MonthPlan>{},
    this.settings = const LedgerSettings(),
  });

  static const Budget empty = Budget();

  /// One currency for the whole budget.
  ///
  /// Multi-currency budgeting needs exchange rates, which need a network and
  /// a rate source with a date - the opposite of what this app is. A single
  /// currency is a smaller product that is actually correct.
  final Currency currency;

  final List<Envelope> envelopes;
  final List<Txn> transactions;

  /// Month key (`YYYY-MM`) to what the user decided for it.
  final Map<String, MonthPlan> plans;

  final LedgerSettings settings;

  List<Envelope> get activeEnvelopes =>
      <Envelope>[for (final e in envelopes) if (!e.archived) e];

  Envelope? envelopeById(String id) {
    for (final envelope in envelopes) {
      if (envelope.id == id) return envelope;
    }
    return null;
  }

  MonthPlan planFor(Month month) => plans[month.toString()] ?? MonthPlan.empty;

  /// Transactions in [month], newest first.
  List<Txn> transactionsIn(Month month) {
    final result = <Txn>[
      for (final txn in transactions)
        if (month.contains(txn.date)) txn,
    ];
    result.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      return byDate != 0 ? byDate : b.id.compareTo(a.id);
    });
    return result;
  }

  /// The earliest month holding a transaction or a plan, or null when the
  /// budget has no history at all.
  Month? get earliestMonth {
    Month? earliest;
    void consider(Month candidate) {
      if (earliest == null || candidate.compareTo(earliest!) < 0) {
        earliest = candidate;
      }
    }

    for (final txn in transactions) {
      consider(Month.fromDay(txn.date));
    }
    for (final key in plans.keys) {
      try {
        consider(Month.parse(key));
      } on FormatException {
        continue;
      }
    }
    return earliest;
  }

  Budget copyWith({
    Currency? currency,
    List<Envelope>? envelopes,
    List<Txn>? transactions,
    Map<String, MonthPlan>? plans,
    LedgerSettings? settings,
  }) => Budget(
    currency: currency ?? this.currency,
    envelopes: envelopes ?? this.envelopes,
    transactions: transactions ?? this.transactions,
    plans: plans ?? this.plans,
    settings: settings ?? this.settings,
  );
}
