import 'package:flutter/foundation.dart';
import 'package:paper/paper.dart';

import '../data/budget_repository.dart';
import '../domain/budget.dart';
import '../domain/envelope.dart';
import '../domain/money.dart';
import '../domain/month.dart';
import '../domain/projection.dart';
import '../domain/txn.dart';

/// Application state for Ledger.
///
/// Holds the budget and the month being looked at; every figure on screen
/// comes from [Projection], so nothing can be stored and then drift.
class BudgetStore extends ChangeNotifier {
  BudgetStore({
    required BudgetRepository repository,
    required DateTime Function() clock,
    required String Function() idFactory,
  }) : _repository = repository,
       _clock = clock,
       _idFactory = idFactory {
    // A sensible value before `initialize` runs, so `month` is never late-
    // init; `initialize` re-reads the clock, because construction can happen
    // well before the first frame.
    _month = Month.fromDay(today);
  }

  final BudgetRepository _repository;
  final DateTime Function() _clock;
  final String Function() _idFactory;

  Budget _budget = Budget.empty;
  late Month _month;
  bool _ready = false;

  bool get ready => _ready;
  Budget get budget => _budget;
  Currency get currency => _budget.currency;
  Day get today => Day.fromDateTime(_clock());

  /// The month on screen.
  Month get month => _month;

  bool get isViewingCurrentMonth => _month == Month.fromDay(today);

  MonthReport get report => Projection.forMonth(_budget, _month);

  List<Txn> get monthTransactions => _budget.transactionsIn(_month);

  Money? get safeToSpendPerDay => report.safeToSpendPerDay(today);

  Future<void> initialize() async {
    _budget = await _repository.load();
    _month = Month.fromDay(today);
    _ready = true;
    notifyListeners();
  }

  void showMonth(Month month) {
    if (month == _month) return;
    _month = month;
    notifyListeners();
  }

  void showPreviousMonth() => showMonth(_month.previous);
  void showNextMonth() => showMonth(_month.next);
  void showCurrentMonth() => showMonth(Month.fromDay(today));

  Future<Envelope> addEnvelope({
    required String name,
    required Money allocation,
    bool rollover = false,
    int? slot,
  }) async {
    final envelope = Envelope(
      id: _idFactory(),
      name: name.trim(),
      // Hand out the next unused slot in order, never a random one, so the
      // first envelopes get the leading colours and nothing collides until
      // the palette is exhausted.
      slot: slot ?? _nextFreeSlot(),
      allocationMinor: allocation.minor,
      rollover: rollover,
    );
    await _write(
      _budget.copyWith(envelopes: <Envelope>[..._budget.envelopes, envelope]),
    );
    return envelope;
  }

  Future<void> updateEnvelope(Envelope updated) async {
    await _write(
      _budget.copyWith(
        envelopes: <Envelope>[
          for (final envelope in _budget.envelopes)
            if (envelope.id == updated.id) updated else envelope,
        ],
      ),
    );
  }

  /// Hides an envelope from future months, keeping its history intact.
  Future<void> archiveEnvelope(String id) async {
    final envelope = _budget.envelopeById(id);
    if (envelope == null) return;
    await updateEnvelope(envelope.copyWith(archived: true));
  }

  Future<void> unarchiveEnvelope(String id) async {
    final envelope = _budget.envelopeById(id);
    if (envelope == null) return;
    await updateEnvelope(envelope.copyWith(archived: false));
  }

  /// Deletes an envelope and every transaction filed against it.
  ///
  /// Archiving is the gentle option and the one the UI offers first; this
  /// exists for an envelope created by mistake, and it says what it does.
  Future<void> deleteEnvelope(String id) async {
    await _write(
      _budget.copyWith(
        envelopes: <Envelope>[
          for (final e in _budget.envelopes)
            if (e.id != id) e,
        ],
        transactions: <Txn>[
          for (final t in _budget.transactions)
            if (t.envelopeId != id) t,
        ],
      ),
    );
  }

  /// Records a spend. [amount] is given positive and stored negative.
  Future<Txn> addSpend({
    required String envelopeId,
    required Money amount,
    required Day date,
    String note = '',
  }) => _addTxn(
    envelopeId: envelopeId,
    amountMinor: -amount.abs.minor,
    date: date,
    note: note,
  );

  /// Records money coming back into an envelope.
  Future<Txn> addRefund({
    required String envelopeId,
    required Money amount,
    required Day date,
    String note = '',
  }) => _addTxn(
    envelopeId: envelopeId,
    amountMinor: amount.abs.minor,
    date: date,
    note: note,
  );

  Future<void> updateTxn(Txn updated) async {
    await _write(
      _budget.copyWith(
        transactions: <Txn>[
          for (final txn in _budget.transactions)
            if (txn.id == updated.id) updated else txn,
        ],
      ),
    );
  }

  Future<void> deleteTxn(String id) async {
    await _write(
      _budget.copyWith(
        transactions: <Txn>[
          for (final txn in _budget.transactions)
            if (txn.id != id) txn,
        ],
      ),
    );
  }

  Future<void> setIncome(Money income) async {
    final plan = _budget.planFor(_month).copyWith(incomeMinor: income.minor);
    await _writePlan(plan);
  }

  Future<void> setAllocation(String envelopeId, Money amount) async {
    await _writePlan(
      _budget.planFor(_month).withAllocation(envelopeId, amount.minor),
    );
  }

  /// Moves budgeted money from one envelope to another within this month.
  ///
  /// This, not a transfer transaction, is the envelope-budgeting move: when
  /// groceries runs short you take the money from somewhere, and the record
  /// that should change is the plan, not the history of what was bought.
  Future<void> moveAllocation({
    required String fromEnvelopeId,
    required String toEnvelopeId,
    required Money amount,
  }) async {
    if (fromEnvelopeId == toEnvelopeId || amount.isZero) return;
    final current = report;
    Money allocationOf(String id) => current.envelopes
        .firstWhere((e) => e.envelope.id == id)
        .allocated;

    final moved = amount.abs;
    var plan = _budget.planFor(_month);
    plan = plan.withAllocation(
      fromEnvelopeId,
      (allocationOf(fromEnvelopeId) - moved).minor,
    );
    plan = plan.withAllocation(
      toEnvelopeId,
      (allocationOf(toEnvelopeId) + moved).minor,
    );
    await _writePlan(plan);
  }

  /// Changes the currency of the whole budget.
  ///
  /// The stored minor units are left exactly as they are: there is no rate to
  /// convert with, and inventing one would be worse than leaving the numbers
  /// alone and letting the user see what they are. The UI warns first.
  Future<void> setCurrency(Currency currency) async {
    if (currency == _budget.currency) return;
    await _write(_budget.copyWith(currency: currency));
  }

  Future<void> updateSettings(LedgerSettings settings) =>
      _write(_budget.copyWith(settings: settings));

  Future<void> clearEverything() =>
      _write(Budget(currency: currency, settings: _budget.settings));

  int _nextFreeSlot() {
    final used = <int>{for (final e in _budget.envelopes) e.slot};
    for (var slot = 0; slot < Viz.slots; slot++) {
      if (!used.contains(slot)) return slot;
    }
    // Past the palette, reuse in order rather than inventing a hue.
    return _budget.envelopes.length % Viz.slots;
  }

  Future<Txn> _addTxn({
    required String envelopeId,
    required int amountMinor,
    required Day date,
    required String note,
  }) async {
    final txn = Txn(
      id: _idFactory(),
      envelopeId: envelopeId,
      date: date,
      amountMinor: amountMinor,
      note: note.trim(),
    );
    await _write(
      _budget.copyWith(
        transactions: <Txn>[txn, ..._budget.transactions],
      ),
    );
    return txn;
  }

  Future<void> _writePlan(MonthPlan plan) => _write(
    _budget.copyWith(
      plans: <String, MonthPlan>{..._budget.plans, _month.toString(): plan},
    ),
  );

  Future<void> _write(Budget next) async {
    _budget = next;
    await _repository.save(next);
    notifyListeners();
  }
}
