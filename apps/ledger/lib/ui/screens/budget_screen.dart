import 'package:flutter/material.dart';
import 'package:paper/paper.dart';

import '../../domain/projection.dart';
import '../../state/budget_store.dart';
import '../money_format.dart';
import '../strings.dart';
import '../widgets/money_field.dart';
import '../widgets/month_bar.dart';
import 'envelope_sheets.dart';

/// The month at a glance: what came in, what is still unbudgeted, what each
/// envelope has left.
class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = Scope.watch<BudgetStore>(context);
    final strings = S.of(context);
    final money = MoneyFormat(
      locale: Localizations.localeOf(context).toLanguageTag(),
      currency: store.currency,
    );
    final report = store.report;

    return Column(
      children: [
        MonthBar(
          month: store.month,
          isCurrent: store.isViewingCurrentMonth,
          onPrevious: store.showPreviousMonth,
          onNext: store.showNextMonth,
          onToday: store.showCurrentMonth,
        ),
        if (report.envelopes.isEmpty && store.budget.envelopes.isEmpty)
          Expanded(
            child: EmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: strings.budgetEmptyTitle,
              message: strings.budgetEmptyBody,
              actionLabel: strings.budgetEmptyAction,
              onAction: () => showEnvelopeEditor(context, store: store),
            ),
          )
        else
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: Gap.x3l),
              children: [
                _Headline(store: store, report: report, money: money),
                const SizedBox(height: Gap.lg),
                _IncomeCard(store: store, report: report, money: money),
                SectionHeader(
                  title: strings.envelopes,
                  trailing: PaperButton(
                    label: strings.newEnvelope,
                    kind: PaperButtonKind.ghost,
                    size: PaperButtonSize.small,
                    onPressed: () => showEnvelopeEditor(context, store: store),
                  ),
                ),
                // Part-to-whole at a glance, capped at six segments plus a
                // neutral tail; the rows below carry the names and numbers.
                ShareBar(
                  segments: <(double, int)>[
                    for (final status in report.envelopes)
                      if (status.allocated.isPositive)
                        (status.allocated.minor.toDouble(), status.envelope.slot),
                  ],
                ),
                const SizedBox(height: Gap.lg),
                for (final status in report.envelopes)
                  _EnvelopeRow(
                    status: status,
                    money: money,
                    strings: strings,
                    onTap: () => showEnvelopeDetail(
                      context,
                      store: store,
                      status: status,
                    ),
                  ),
                if (store.budget.activeEnvelopes.length > 1) ...[
                  const SizedBox(height: Gap.sm),
                  PaperButton(
                    label: strings.moveMoney,
                    icon: Icons.swap_horiz_rounded,
                    kind: PaperButtonKind.tonal,
                    expand: true,
                    onPressed: () => showMoveMoneySheet(context, store: store),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// The one number the screen exists to show.
class _Headline extends StatelessWidget {
  const _Headline({
    required this.store,
    required this.report,
    required this.money,
  });

  final BudgetStore store;
  final MonthReport report;
  final MoneyFormat money;

  @override
  Widget build(BuildContext context) {
    final strings = S.of(context);
    final colors = context.colors;
    final perDay = store.safeToSpendPerDay;
    final overspent = report.remainingTotal.isNegative;

    return PaperCard(
      accent: !overspent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            perDay == null ? strings.remaining : strings.safeToSpend,
            style: context.type.label,
          ),
          const SizedBox(height: Gap.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  money.format(perDay ?? report.remainingTotal),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.numericLarge.copyWith(
                    fontSize: 38,
                    color: overspent ? colors.danger : colors.ink,
                  ),
                ),
              ),
              if (perDay != null) ...[
                const SizedBox(width: Gap.sm),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(strings.perDay, style: context.type.caption),
                ),
              ],
            ],
          ),
          const SizedBox(height: Gap.sm),
          Text(
            perDay == null
                ? strings.monthIsOver
                : '${strings.remaining} ${money.format(report.remainingTotal)}'
                      ' · ${strings.spent} ${money.format(report.spentTotal)}',
            style: context.type.caption,
          ),
        ],
      ),
    );
  }
}

class _IncomeCard extends StatelessWidget {
  const _IncomeCard({
    required this.store,
    required this.report,
    required this.money,
  });

  final BudgetStore store;
  final MonthReport report;
  final MoneyFormat money;

  @override
  Widget build(BuildContext context) {
    final strings = S.of(context);
    final colors = context.colors;
    final over = report.unallocated.isNegative;

    return PaperCard(
      onTap: () => showIncomeSheet(context, store: store),
      child: Column(
        children: [
          MoneyRow(
            label: strings.income,
            amount: money.format(report.income),
          ),
          MoneyRow(
            label: strings.budgeted,
            amount: money.format(report.allocatedTotal),
          ),
          const Hairline(),
          MoneyRow(
            label: over ? strings.overCommitted : strings.leftToBudget,
            amount: money.format(report.unallocated),
            strong: true,
            tone: over ? colors.danger : colors.positive,
          ),
        ],
      ),
    );
  }
}

class _EnvelopeRow extends StatelessWidget {
  const _EnvelopeRow({
    required this.status,
    required this.money,
    required this.strings,
    required this.onTap,
  });

  final EnvelopeStatus status;
  final MoneyFormat money;
  final S strings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final colour = Viz.slot(status.envelope.slot, dark: colors.isDark);
    final remaining = status.remaining;

    return Semantics(
      button: true,
      label:
          '${status.envelope.name}, '
          '${strings.remaining} ${money.format(remaining)}, '
          '${strings.spent} ${money.format(status.spent)}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Gap.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 8,
                    width: 8,
                    decoration: BoxDecoration(
                      color: colour,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: Text(
                      status.envelope.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.type.body,
                    ),
                  ),
                  Text(
                    money.format(remaining),
                    style: context.type.numeric.copyWith(
                      color: status.overspent ? colors.danger : colors.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.sm),
              ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(4)),
                child: Container(
                  height: 6,
                  color: colors.surfaceSunken,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: status.usedFraction,
                    child: ColoredBox(
                      color: status.overspent ? colors.danger : colour,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Gap.xs),
              Text(
                <String>[
                  '${strings.spent} ${money.compact(status.spent)}',
                  '${strings.available} ${money.compact(status.available)}',
                  if (!status.rolloverIn.isZero)
                    '${strings.carriedIn} ${money.signed(status.rolloverIn)}',
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.type.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
