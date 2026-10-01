import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:paper/paper.dart';

import '../../domain/money.dart';
import '../../domain/txn.dart';
import '../../state/budget_store.dart';
import '../money_format.dart';
import '../strings.dart';
import '../widgets/month_bar.dart';
import 'envelope_sheets.dart';

/// What was actually spent this month, newest first.
class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = Scope.watch<BudgetStore>(context);
    final strings = S.of(context);
    final money = MoneyFormat(
      locale: Localizations.localeOf(context).toLanguageTag(),
      currency: store.currency,
    );
    final transactions = store.monthTransactions;

    return Column(
      children: [
        MonthBar(
          month: store.month,
          isCurrent: store.isViewingCurrentMonth,
          onPrevious: store.showPreviousMonth,
          onNext: store.showNextMonth,
          onToday: store.showCurrentMonth,
        ),
        Expanded(
          child: transactions.isEmpty
              ? EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: strings.transactionsEmptyTitle,
                  message: strings.transactionsEmptyBody,
                  actionLabel: store.budget.activeEnvelopes.isEmpty
                      ? null
                      : strings.addSpend,
                  onAction: store.budget.activeEnvelopes.isEmpty
                      ? null
                      : () => showTransactionSheet(context, store: store),
                )
              : _TransactionList(
                  store: store,
                  transactions: transactions,
                  money: money,
                  strings: strings,
                  localeTag: context.localeTag,
                ),
        ),
        if (transactions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.lg, top: Gap.sm),
            child: PaperButton(
              label: strings.addSpend,
              icon: Icons.add_rounded,
              size: PaperButtonSize.large,
              expand: true,
              onPressed: store.budget.activeEnvelopes.isEmpty
                  ? null
                  : () => showTransactionSheet(context, store: store),
            ),
          ),
      ],
    );
  }
}

class _TransactionList extends StatelessWidget {
  const _TransactionList({
    required this.store,
    required this.transactions,
    required this.money,
    required this.strings,
    required this.localeTag,
  });

  final BudgetStore store;
  final List<Txn> transactions;
  final MoneyFormat money;
  final S strings;
  final String localeTag;

  String _dayLabel(Day day) {
    if (day == store.today) return strings.today;
    if (day == store.today.previous) return strings.yesterday;
    return DateFormat.MMMEd(localeTag).format(day.startOfDay);
  }

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    Day? lastDay;
    for (final txn in transactions) {
      if (txn.date != lastDay) {
        lastDay = txn.date;
        final dayTotal = Money.sum(
          <Money>[
            for (final t in transactions)
              if (t.date == txn.date) Money(-t.amountMinor, store.currency),
          ],
          store.currency,
        );
        rows.add(
          SectionHeader(
            title: _dayLabel(txn.date),
            trailing: Text(
              money.format(dayTotal),
              style: context.type.numeric.copyWith(
                color: context.colors.inkMuted,
              ),
            ),
          ),
        );
      }
      rows.add(
        _TxnRow(store: store, txn: txn, money: money, strings: strings),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: Gap.lg),
      itemCount: rows.length,
      itemBuilder: (context, index) => rows[index],
    );
  }
}

class _TxnRow extends StatelessWidget {
  const _TxnRow({
    required this.store,
    required this.txn,
    required this.money,
    required this.strings,
  });

  final BudgetStore store;
  final Txn txn;
  final MoneyFormat money;
  final S strings;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final envelope = store.budget.envelopeById(txn.envelopeId);
    final amount = Money(txn.amountMinor, store.currency);
    // Stored signed with negative meaning money out; shown signed too, so a
    // refund and a purchase never look the same at a glance.
    final label = money.signed(amount);

    return Semantics(
      button: true,
      label: '${envelope?.name ?? ''} $label ${txn.note}'.trim(),
      excludeSemantics: true,
      child: InkWell(
        onTap: () => _edit(context),
        onLongPress: () => _delete(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Gap.md),
          child: Row(
            children: [
              Container(
                height: 8,
                width: 8,
                decoration: BoxDecoration(
                  color: envelope == null
                      ? Viz.other(dark: colors.isDark)
                      : Viz.slot(envelope.slot, dark: colors.isDark),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      envelope?.name ?? '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.type.body,
                    ),
                    if (txn.note.isNotEmpty) ...[
                      const SizedBox(height: Gap.xxs),
                      Text(
                        txn.note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.type.caption,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: Gap.sm),
              Text(
                label,
                style: context.type.numeric.copyWith(
                  color: txn.isExpense ? colors.ink : colors.positive,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _edit(BuildContext context) => showTransactionSheet(
    context,
    store: store,
    txnId: txn.id,
  );

  Future<void> _delete(BuildContext context) async {
    final confirmed = await confirmDestructive(
      context,
      title: strings.deleteTransactionConfirmTitle,
      message: strings.deleteTransactionConfirmBody,
      confirmLabel: strings.deleteTransaction,
    );
    if (!confirmed) return;
    await store.deleteTxn(txn.id);
  }
}
