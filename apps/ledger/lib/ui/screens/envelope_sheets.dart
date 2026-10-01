import 'package:flutter/material.dart';
import 'package:paper/paper.dart';

import '../../domain/envelope.dart';
import '../../domain/money.dart';
import '../../domain/projection.dart';
import '../../state/budget_store.dart';
import '../money_format.dart';
import '../strings.dart';
import '../widgets/money_field.dart';

MoneyFormat _money(BuildContext context, BudgetStore store) => MoneyFormat(
  locale: Localizations.localeOf(context).toLanguageTag(),
  currency: store.currency,
);

/// Create or edit an envelope.
Future<void> showEnvelopeEditor(
  BuildContext context, {
  required BudgetStore store,
  Envelope? envelope,
}) {
  final strings = S.of(context);
  return showPaperSheet<void>(
    context: context,
    title: envelope == null ? strings.newEnvelope : strings.editEnvelope,
    builder: (context) => _EnvelopeForm(store: store, envelope: envelope),
  );
}

class _EnvelopeForm extends StatefulWidget {
  const _EnvelopeForm({required this.store, this.envelope});

  final BudgetStore store;
  final Envelope? envelope;

  @override
  State<_EnvelopeForm> createState() => _EnvelopeFormState();
}

class _EnvelopeFormState extends State<_EnvelopeForm> {
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late bool _rollover;
  bool _nameMissing = false;

  @override
  void initState() {
    super.initState();
    final envelope = widget.envelope;
    _name = TextEditingController(text: envelope?.name ?? '');
    _amount = TextEditingController(
      text: envelope == null
          ? ''
          : MoneyFormat(
              locale: 'en',
              currency: widget.store.currency,
            ).bare(Money(envelope.allocationMinor, widget.store.currency)),
    );
    _rollover = envelope?.rollover ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = S.of(context);
    final currency = widget.store.currency;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _name,
            autofocus: widget.envelope == null,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) {
              if (_nameMissing) setState(() => _nameMissing = false);
            },
            decoration: InputDecoration(
              labelText: strings.envelopeName,
              errorText: _nameMissing ? strings.nameRequired : null,
            ),
          ),
          const SizedBox(height: Gap.lg),
          MoneyField(
            controller: _amount,
            currency: currency,
            label: strings.monthlyAmount,
            errorText: strings.invalidAmount,
          ),
          const SizedBox(height: Gap.sm),
          SettingSwitch(
            title: strings.rollover,
            subtitle: strings.rolloverBody,
            value: _rollover,
            onChanged: (value) => setState(() => _rollover = value),
          ),
          const SizedBox(height: Gap.lg),
          PaperButton(label: strings.save, expand: true, onPressed: _save),
          if (widget.envelope != null) ...[
            const SizedBox(height: Gap.sm),
            PaperButton(
              label: widget.envelope!.archived
                  ? strings.unarchive
                  : strings.archive,
              kind: PaperButtonKind.ghost,
              expand: true,
              onPressed: _toggleArchive,
            ),
            const SizedBox(height: Gap.sm),
            PaperButton(
              label: strings.deleteEnvelope,
              kind: PaperButtonKind.danger,
              expand: true,
              onPressed: _delete,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameMissing = true);
      return;
    }
    final currency = widget.store.currency;
    // An empty amount means zero rather than an error: an envelope with no
    // money budgeted yet is a normal thing to create.
    final amount = _amount.text.trim().isEmpty
        ? Money.zeroIn(currency)
        : Money.tryParse(_amount.text, currency);
    if (amount == null) return;

    final navigator = Navigator.of(context);
    final existing = widget.envelope;
    if (existing == null) {
      await widget.store.addEnvelope(
        name: name,
        allocation: amount,
        rollover: _rollover,
      );
    } else {
      await widget.store.updateEnvelope(
        existing.copyWith(
          name: name,
          allocationMinor: amount.minor,
          rollover: _rollover,
        ),
      );
    }
    navigator.pop();
  }

  Future<void> _toggleArchive() async {
    final envelope = widget.envelope!;
    final navigator = Navigator.of(context);
    if (envelope.archived) {
      await widget.store.unarchiveEnvelope(envelope.id);
    } else {
      await widget.store.archiveEnvelope(envelope.id);
    }
    navigator.pop();
  }

  Future<void> _delete() async {
    final strings = S.of(context);
    final envelope = widget.envelope!;
    final affected = widget.store.budget.transactions
        .where((t) => t.envelopeId == envelope.id)
        .length;

    final navigator = Navigator.of(context);
    final confirmed = await confirmDestructive(
      context,
      title: strings.deleteEnvelopeConfirmTitle,
      message: strings.deleteEnvelopeConfirmBody(affected),
      confirmLabel: strings.deleteEnvelopeConfirmAction,
    );
    if (!confirmed) return;
    await widget.store.deleteEnvelope(envelope.id);
    navigator.pop();
  }
}

/// One envelope's month: the numbers, then the things you can do about them.
Future<void> showEnvelopeDetail(
  BuildContext context, {
  required BudgetStore store,
  required EnvelopeStatus status,
}) {
  final strings = S.of(context);
  final money = _money(context, store);

  return showPaperSheet<void>(
    context: context,
    title: status.envelope.name,
    builder: (context) => SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MoneyRow(
            label: strings.budgeted,
            amount: money.format(status.allocated),
          ),
          if (!status.rolloverIn.isZero)
            MoneyRow(
              label: strings.carriedIn,
              amount: money.signed(status.rolloverIn),
            ),
          MoneyRow(label: strings.spent, amount: money.format(status.spent)),
          const Hairline(),
          MoneyRow(
            label: status.overspent ? strings.overspentBy : strings.remaining,
            amount: money.format(
              status.overspent ? status.remaining.abs : status.remaining,
            ),
            strong: true,
            tone: status.overspent ? context.colors.danger : null,
          ),
          const SizedBox(height: Gap.xl),
          PaperButton(
            label: strings.addSpend,
            icon: Icons.remove_rounded,
            expand: true,
            onPressed: () {
              Navigator.of(context).pop();
              showTransactionSheet(
                context,
                store: store,
                envelopeId: status.envelope.id,
              );
            },
          ),
          const SizedBox(height: Gap.sm),
          PaperButton(
            label: strings.thisMonthsAmount,
            kind: PaperButtonKind.tonal,
            expand: true,
            onPressed: () {
              Navigator.of(context).pop();
              showAllocationSheet(context, store: store, status: status);
            },
          ),
          const SizedBox(height: Gap.sm),
          PaperButton(
            label: strings.editEnvelope,
            kind: PaperButtonKind.ghost,
            expand: true,
            onPressed: () {
              Navigator.of(context).pop();
              showEnvelopeEditor(
                context,
                store: store,
                envelope: status.envelope,
              );
            },
          ),
        ],
      ),
    ),
  );
}

/// Set this month's allocation for one envelope.
Future<void> showAllocationSheet(
  BuildContext context, {
  required BudgetStore store,
  required EnvelopeStatus status,
}) {
  final strings = S.of(context);
  return showPaperSheet<void>(
    context: context,
    title: strings.thisMonthsAmount,
    builder: (context) => _SingleAmountForm(
      initial: status.allocated,
      currency: store.currency,
      label: strings.thisMonthsAmount,
      action: strings.save,
      onSubmit: (amount) => store.setAllocation(status.envelope.id, amount),
    ),
  );
}

/// Set this month's income.
Future<void> showIncomeSheet(
  BuildContext context, {
  required BudgetStore store,
}) {
  final strings = S.of(context);
  return showPaperSheet<void>(
    context: context,
    title: strings.setIncome,
    builder: (context) => _SingleAmountForm(
      initial: store.report.income,
      currency: store.currency,
      label: strings.income,
      action: strings.save,
      onSubmit: store.setIncome,
    ),
  );
}

class _SingleAmountForm extends StatefulWidget {
  const _SingleAmountForm({
    required this.initial,
    required this.currency,
    required this.label,
    required this.action,
    required this.onSubmit,
  });

  final Money initial;
  final Currency currency;
  final String label;
  final String action;
  final Future<void> Function(Money amount) onSubmit;

  @override
  State<_SingleAmountForm> createState() => _SingleAmountFormState();
}

class _SingleAmountFormState extends State<_SingleAmountForm> {
  late final TextEditingController _amount = TextEditingController(
    text: widget.initial.isZero
        ? ''
        : MoneyFormat(locale: 'en', currency: widget.currency)
              .bare(widget.initial),
  );

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        MoneyField(
          controller: _amount,
          currency: widget.currency,
          label: widget.label,
          errorText: strings.invalidAmount,
          autofocus: true,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: Gap.xl),
        PaperButton(label: widget.action, expand: true, onPressed: _submit),
      ],
    );
  }

  Future<void> _submit() async {
    final amount = _amount.text.trim().isEmpty
        ? Money.zeroIn(widget.currency)
        : Money.tryParse(_amount.text, widget.currency);
    if (amount == null) return;
    final navigator = Navigator.of(context);
    await widget.onSubmit(amount);
    navigator.pop();
  }
}

/// Move budgeted money between two envelopes.
Future<void> showMoveMoneySheet(
  BuildContext context, {
  required BudgetStore store,
}) {
  final strings = S.of(context);
  return showPaperSheet<void>(
    context: context,
    title: strings.moveMoney,
    builder: (context) => _MoveMoneyForm(store: store),
  );
}

class _MoveMoneyForm extends StatefulWidget {
  const _MoveMoneyForm({required this.store});

  final BudgetStore store;

  @override
  State<_MoveMoneyForm> createState() => _MoveMoneyFormState();
}

class _MoveMoneyFormState extends State<_MoveMoneyForm> {
  final TextEditingController _amount = TextEditingController();
  String? _from;
  String? _to;

  @override
  void initState() {
    super.initState();
    final envelopes = widget.store.budget.activeEnvelopes;
    if (envelopes.length >= 2) {
      _from = envelopes.first.id;
      _to = envelopes[1].id;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = S.of(context);
    final envelopes = widget.store.budget.activeEnvelopes;
    final currency = widget.store.currency;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EnvelopePicker(
          label: strings.moveFrom,
          envelopes: envelopes,
          value: _from,
          onChanged: (value) => setState(() => _from = value),
        ),
        const SizedBox(height: Gap.lg),
        _EnvelopePicker(
          label: strings.moveTo,
          envelopes: envelopes,
          value: _to,
          onChanged: (value) => setState(() => _to = value),
        ),
        const SizedBox(height: Gap.lg),
        MoneyField(
          controller: _amount,
          currency: currency,
          label: strings.amount,
          errorText: strings.invalidAmount,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: Gap.xl),
        PaperButton(
          label: strings.move,
          expand: true,
          onPressed: _from == null || _to == null || _from == _to
              ? null
              : _submit,
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final amount = Money.tryParse(_amount.text, widget.store.currency);
    if (amount == null || amount.isZero) return;
    final navigator = Navigator.of(context);
    await widget.store.moveAllocation(
      fromEnvelopeId: _from!,
      toEnvelopeId: _to!,
      amount: amount,
    );
    navigator.pop();
  }
}

class _EnvelopePicker extends StatelessWidget {
  const _EnvelopePicker({
    required this.label,
    required this.envelopes,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final List<Envelope> envelopes;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: <DropdownMenuItem<String>>[
        for (final envelope in envelopes)
          DropdownMenuItem<String>(
            value: envelope.id,
            child: Row(
              children: [
                Container(
                  height: 8,
                  width: 8,
                  decoration: BoxDecoration(
                    color: Viz.slot(
                      envelope.slot,
                      dark: context.colors.isDark,
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Text(envelope.name, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

/// Record a spend or a refund.
Future<void> showTransactionSheet(
  BuildContext context, {
  required BudgetStore store,
  String? envelopeId,
  String? txnId,
}) {
  final strings = S.of(context);
  return showPaperSheet<void>(
    context: context,
    title: txnId == null ? strings.addSpend : strings.save,
    builder: (context) => _TransactionForm(
      store: store,
      envelopeId: envelopeId,
      txnId: txnId,
    ),
  );
}

class _TransactionForm extends StatefulWidget {
  const _TransactionForm({required this.store, this.envelopeId, this.txnId});

  final BudgetStore store;
  final String? envelopeId;
  final String? txnId;

  @override
  State<_TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<_TransactionForm> {
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _note = TextEditingController();
  String? _envelopeId;
  late Day _date;
  bool _isRefund = false;

  @override
  void initState() {
    super.initState();
    final store = widget.store;
    final existing = widget.txnId == null
        ? null
        : store.budget.transactions.firstWhere((t) => t.id == widget.txnId);

    _envelopeId =
        existing?.envelopeId ??
        widget.envelopeId ??
        (store.budget.activeEnvelopes.isEmpty
            ? null
            : store.budget.activeEnvelopes.first.id);
    _date = existing?.date ?? _defaultDate(store);
    _isRefund = existing != null && !existing.isExpense;
    if (existing != null) {
      _amount.text = MoneyFormat(locale: 'en', currency: store.currency)
          .bare(Money(existing.amountMinor.abs(), store.currency));
      _note.text = existing.note;
    }
  }

  /// Today when the month on screen is the current one, otherwise the first
  /// of that month - so recording into a past month does not silently file
  /// the entry under today and move it out of view.
  static Day _defaultDate(BudgetStore store) =>
      store.isViewingCurrentMonth ? store.today : store.month.firstDay;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = S.of(context);
    final store = widget.store;
    final envelopes = store.budget.activeEnvelopes;

    if (envelopes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.xl),
        child: Text(strings.noEnvelopeYet, style: context.type.body),
      );
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedToggle<bool>(
            segments: [(false, strings.addSpend), (true, strings.addRefund)],
            value: _isRefund,
            onChanged: (value) => setState(() => _isRefund = value),
          ),
          const SizedBox(height: Gap.lg),
          MoneyField(
            controller: _amount,
            currency: store.currency,
            label: strings.amount,
            errorText: strings.invalidAmount,
            autofocus: true,
          ),
          const SizedBox(height: Gap.lg),
          _EnvelopePicker(
            label: strings.envelopes,
            envelopes: envelopes,
            value: _envelopeId,
            onChanged: (value) => setState(() => _envelopeId = value),
          ),
          const SizedBox(height: Gap.lg),
          SettingRow(
            title: strings.date,
            value: _date.toString(),
            onTap: _pickDate,
          ),
          const SizedBox(height: Gap.lg),
          TextField(
            controller: _note,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: strings.note),
          ),
          const SizedBox(height: Gap.xl),
          PaperButton(label: strings.save, expand: true, onPressed: _submit),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.startOfDay,
      // A decade either way: wide enough for a backdated receipt, narrow
      // enough that a mis-scroll cannot land in 1823.
      firstDate: DateTime(_date.year - 10),
      lastDate: DateTime(_date.year + 10, 12, 31),
    );
    if (picked == null) return;
    setState(() => _date = Day.fromDateTime(picked));
  }

  Future<void> _submit() async {
    final store = widget.store;
    final amount = Money.tryParse(_amount.text, store.currency);
    if (amount == null || amount.isZero || _envelopeId == null) return;

    final navigator = Navigator.of(context);
    final existing = widget.txnId;
    if (existing == null) {
      if (_isRefund) {
        await store.addRefund(
          envelopeId: _envelopeId!,
          amount: amount,
          date: _date,
          note: _note.text,
        );
      } else {
        await store.addSpend(
          envelopeId: _envelopeId!,
          amount: amount,
          date: _date,
          note: _note.text,
        );
      }
    } else {
      final signed = _isRefund ? amount.abs.minor : -amount.abs.minor;
      await store.updateTxn(
        store.budget.transactions
            .firstWhere((t) => t.id == existing)
            .copyWith(
              envelopeId: _envelopeId,
              amountMinor: signed,
              date: _date,
              note: _note.text,
            ),
      );
    }
    navigator.pop();
  }
}
