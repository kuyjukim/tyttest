import 'package:flutter/material.dart';
import 'package:paper/paper.dart';

import '../../domain/money.dart';
import '../../domain/projection.dart';
import '../../state/budget_store.dart';
import '../money_format.dart';
import '../strings.dart';

/// How many months back the report covers.
enum _Range {
  one(1),
  three(3),
  six(6);

  const _Range(this.months);
  final int months;
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  _Range _range = _Range.one;

  @override
  Widget build(BuildContext context) {
    final store = Scope.watch<BudgetStore>(context);
    final strings = S.of(context);
    final money = MoneyFormat(
      locale: Localizations.localeOf(context).toLanguageTag(),
      currency: store.currency,
    );

    if (store.budget.transactions.isEmpty) {
      return EmptyState(
        icon: Icons.bar_chart_outlined,
        title: strings.tabReports,
        message: strings.reportsEmpty,
      );
    }

    final to = store.month;
    final from = to.addMonths(-(_range.months - 1));
    final spent = Projection.spentByEnvelope(store.budget, from: from, to: to);
    final daily = Projection.dailySpend(store.budget, to);

    return ListView(
      padding: const EdgeInsets.only(bottom: Gap.x3l),
      children: [
        const SizedBox(height: Gap.lg),
        SegmentedToggle<_Range>(
          segments: [
            (_Range.one, strings.range1m),
            (_Range.three, strings.range3m),
            (_Range.six, strings.range6m),
          ],
          value: _range,
          onChanged: (value) => setState(() => _range = value),
        ),
        SectionHeader(title: strings.spendByEnvelope),
        // Ranked horizontal bars rather than a donut: the categories' values
        // are often close and their names are long, and every row carrying
        // its own name and number is what licenses the lighter palette slots.
        RankedBarList(
          bars: <RankedBar>[
            for (final envelope in store.budget.envelopes)
              if ((spent[envelope.id] ?? Money.zeroIn(store.currency))
                  .isPositive)
                RankedBar(
                  label: envelope.name,
                  value: spent[envelope.id]!.minor.toDouble(),
                  display: money.format(spent[envelope.id]!),
                  slot: envelope.slot,
                ),
          ],
        ),
        SectionHeader(title: strings.dailySpend),
        BarChart(
          bars: <Bar>[
            for (final (day, amount) in daily)
              Bar(
                label: '${day.dayOfMonth}',
                value: amount.minor.toDouble(),
                highlight: day == store.today,
              ),
          ],
          height: 120,
          formatValue: (value) =>
              money.compact(Money(value.round(), store.currency)),
        ),
      ],
    );
  }
}
