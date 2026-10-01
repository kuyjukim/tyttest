import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/app.dart';
import 'package:ledger/data/budget_repository.dart';
import 'package:ledger/domain/money.dart';
import 'package:ledger/state/budget_store.dart';
import 'package:paper/paper.dart';

class FakeClock {
  DateTime now = DateTime(2026, 10, 15, 9);
}

class Harness {
  Harness({Map<String, String>? seed})
    : clock = FakeClock(),
      raw = MemoryStore(seed) {
    var id = 0;
    store = BudgetStore(
      repository: BudgetRepository(raw),
      clock: () => clock.now,
      idFactory: () => 'id-${(id++).toString().padLeft(3, '0')}',
    );
  }

  final FakeClock clock;
  final MemoryStore raw;
  late final BudgetStore store;
}

Future<Harness> pumpApp(
  WidgetTester tester, {
  Map<String, String>? seed,
  Locale locale = const Locale('en'),
}) async {
  tester.view
    ..physicalSize = const Size(393, 852)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final harness = Harness(seed: seed);
  await harness.store.initialize();
  await tester.pumpWidget(LedgerApp(store: harness.store, locale: locale));
  await tester.pumpAndSettle();
  return harness;
}

/// Adds an envelope through the UI.
Future<void> addEnvelope(
  WidgetTester tester, {
  required String name,
  required String amount,
  bool rollover = false,
}) async {
  final opener = find.text('Add an envelope').evaluate().isNotEmpty
      ? find.text('Add an envelope')
      : find.text('New envelope').first;
  await tester.tap(opener);
  await tester.pumpAndSettle();

  await tester.enterText(find.widgetWithText(TextField, 'Name'), name);
  await tester.enterText(
    find.widgetWithText(TextField, 'Amount each month'),
    amount,
  );
  if (rollover) {
    await tester.tap(find.text('Carry the balance over'));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.widgetWithText(PaperButton, 'Save'));
  await tester.pumpAndSettle();
}

void main() {
  group('first run', () {
    testWidgets('offers to add the first envelope', (tester) async {
      await pumpApp(tester);

      expect(find.text('No envelopes yet'), findsOneWidget);
      expect(find.text('Add an envelope'), findsOneWidget);
      expect(find.text('October 2026'), findsWidgets);
    });

    testWidgets('an envelope appears with its amount', (tester) async {
      final harness = await pumpApp(tester);
      await addEnvelope(tester, name: 'Groceries', amount: '400,000');

      expect(harness.store.budget.envelopes.single.name, 'Groceries');
      expect(harness.store.budget.envelopes.single.allocationMinor, 400000);
      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('₩400,000'), findsWidgets);
    });

    testWidgets('a nameless envelope is refused', (tester) async {
      final harness = await pumpApp(tester);
      await tester.tap(find.text('Add an envelope'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PaperButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Give it a name.'), findsOneWidget);
      expect(harness.store.budget.envelopes, isEmpty);
    });
  });

  group('budgeting', () {
    testWidgets('income drives what is left to budget', (tester) async {
      final harness = await pumpApp(tester);
      await addEnvelope(tester, name: 'Groceries', amount: '400,000');

      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Income'),
        '3,000,000',
      );
      await tester.tap(find.widgetWithText(PaperButton, 'Save'));
      await tester.pumpAndSettle();

      expect(harness.store.report.income, const Money(3000000, Currency.krw));
      expect(find.text('Left to budget'), findsOneWidget);
      expect(find.text('₩2,600,000'), findsOneWidget);
    });

    testWidgets('budgeting past income says so', (tester) async {
      final harness = await pumpApp(tester);
      await addEnvelope(tester, name: 'Rent', amount: '1,000,000');

      await tester.tap(find.text('Income'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Income'),
        '500,000',
      );
      await tester.tap(find.widgetWithText(PaperButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('Budgeted beyond income'), findsOneWidget);
      expect(harness.store.report.unallocated.isNegative, isTrue);
    });

    testWidgets('spending reduces what is left in the envelope',
        (tester) async {
      final harness = await pumpApp(tester);
      await addEnvelope(tester, name: 'Groceries', amount: '400,000');

      await tester.tap(find.text('Groceries'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PaperButton, 'Add spending'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Amount'),
        '125,000',
      );
      await tester.enterText(find.widgetWithText(TextField, 'Note'), 'market');
      await tester.tap(find.widgetWithText(PaperButton, 'Save'));
      await tester.pumpAndSettle();

      expect(harness.store.report.spentTotal, const Money(125000, Currency.krw));
      expect(find.text('₩275,000'), findsWidgets);
    });

    testWidgets('a refund puts money back', (tester) async {
      final harness = await pumpApp(tester);
      await addEnvelope(tester, name: 'Clothes', amount: '100,000');

      await tester.tap(find.text('Clothes'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PaperButton, 'Add spending'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add a refund'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Amount'),
        '30,000',
      );
      await tester.tap(find.widgetWithText(PaperButton, 'Save'));
      await tester.pumpAndSettle();

      expect(
        harness.store.budget.transactions.single.amountMinor,
        30000,
        reason: 'a refund is stored positive',
      );
      expect(harness.store.report.spentTotal, const Money(-30000, Currency.krw));
    });

    testWidgets('moving money leaves the total budgeted unchanged',
        (tester) async {
      final harness = await pumpApp(tester);
      await addEnvelope(tester, name: 'Groceries', amount: '300,000');
      await addEnvelope(tester, name: 'Dining', amount: '100,000');
      final before = harness.store.report.allocatedTotal;

      await tester.tap(find.text('Move money'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Amount'),
        '40,000',
      );
      await tester.tap(find.widgetWithText(PaperButton, 'Move'));
      await tester.pumpAndSettle();

      final report = harness.store.report;
      expect(report.allocatedTotal, before);
      expect(
        report.envelopes.firstWhere((e) => e.envelope.name == 'Groceries')
            .allocated,
        const Money(260000, Currency.krw),
      );
      expect(
        report.envelopes.firstWhere((e) => e.envelope.name == 'Dining')
            .allocated,
        const Money(140000, Currency.krw),
      );
    });

    testWidgets('the move button is unavailable with only one envelope',
        (tester) async {
      await pumpApp(tester);
      await addEnvelope(tester, name: 'Only one', amount: '1,000');
      expect(find.text('Move money'), findsNothing);
    });
  });

  group('month navigation', () {
    testWidgets('steps between months and offers a way back to today',
        (tester) async {
      final harness = await pumpApp(tester);
      await addEnvelope(tester, name: 'Groceries', amount: '400,000');

      await tester.tap(find.byIcon(Icons.chevron_left_rounded).first);
      await tester.pumpAndSettle();

      expect(find.text('September 2026'), findsWidgets);
      expect(find.text('This month'), findsWidgets);

      await tester.tap(find.text('This month').first);
      await tester.pumpAndSettle();
      expect(find.text('October 2026'), findsWidgets);
      expect(harness.store.isViewingCurrentMonth, isTrue);
    });

    testWidgets('an allocation set for one month does not leak into another',
        (tester) async {
      final harness = await pumpApp(tester);
      await addEnvelope(tester, name: 'Gifts', amount: '50,000');

      await tester.tap(find.byIcon(Icons.chevron_right_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gifts'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PaperButton, "This month's amount"));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, "This month's amount"),
        '200,000',
      );
      await tester.tap(find.widgetWithText(PaperButton, 'Save'));
      await tester.pumpAndSettle();

      expect(
        harness.store.report.envelopes.single.allocated,
        const Money(200000, Currency.krw),
      );

      await tester.tap(find.byIcon(Icons.chevron_left_rounded).first);
      await tester.pumpAndSettle();
      expect(
        harness.store.report.envelopes.single.allocated,
        const Money(50000, Currency.krw),
        reason: 'October keeps the default',
      );
    });
  });

  group('spending tab', () {
    testWidgets('lists the month and edits an entry', (tester) async {
      final harness = await pumpApp(tester);
      await addEnvelope(tester, name: 'Transport', amount: '100,000');

      await tester.tap(find.text('Spending'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing recorded this month'), findsOneWidget);

      await tester.tap(find.widgetWithText(PaperButton, 'Add spending'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Amount'),
        '12,000',
      );
      await tester.enterText(find.widgetWithText(TextField, 'Note'), 'bus');
      await tester.tap(find.widgetWithText(PaperButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('bus'), findsOneWidget);
      expect(find.text('-₩12,000'), findsWidgets);
      expect(find.text('Today'), findsWidgets);

      await tester.tap(find.text('bus'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Amount'),
        '15,000',
      );
      await tester.tap(find.widgetWithText(PaperButton, 'Save'));
      await tester.pumpAndSettle();

      expect(harness.store.budget.transactions.single.amountMinor, -15000);
    });

    testWidgets('a long press deletes after confirming', (tester) async {
      final harness = await pumpApp(tester);
      await addEnvelope(tester, name: 'Transport', amount: '100,000');
      await tester.tap(find.text('Spending'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PaperButton, 'Add spending'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Amount'),
        '12,000',
      );
      await tester.tap(find.widgetWithText(PaperButton, 'Save'));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Transport').last);
      await tester.pumpAndSettle();
      expect(find.text('Delete this entry?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(harness.store.budget.transactions, hasLength(1));

      await tester.longPress(find.text('Transport').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PaperButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(harness.store.budget.transactions, isEmpty);
    });
  });

  group('reports', () {
    testWidgets('are empty until something is recorded, then rank the '
        'envelopes', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Reports'));
      await tester.pumpAndSettle();
      expect(
        find.text('Record some spending and the picture shows up here.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Budget'));
      await tester.pumpAndSettle();
      await addEnvelope(tester, name: 'Groceries', amount: '400,000');
      await tester.tap(find.text('Groceries'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PaperButton, 'Add spending'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Amount'),
        '125,000',
      );
      await tester.tap(find.widgetWithText(PaperButton, 'Save'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reports'));
      await tester.pumpAndSettle();

      expect(find.text('Where the money went'), findsOneWidget);
      expect(find.text('Groceries'), findsWidgets);
      expect(find.text('₩125,000'), findsWidgets);

      await tester.tap(find.text('3 months'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('settings', () {
    testWidgets('changing the currency warns before it happens',
        (tester) async {
      final harness = await pumpApp(tester);
      await addEnvelope(tester, name: 'Groceries', amount: '400,000');
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Currency').last);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('USD'));
      await tester.pumpAndSettle();

      expect(find.text('Change the currency?'), findsOneWidget);
      expect(
        find.textContaining('not converted'),
        findsOneWidget,
        reason: 'a surprise this large deserves a dialog, not a footnote',
      );

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(harness.store.currency, Currency.krw);

      await tester.tap(find.text('Currency').last);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('USD'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Change it'));
      await tester.pumpAndSettle();

      expect(harness.store.currency, Currency.usd);
      expect(
        harness.store.budget.envelopes.single.allocationMinor,
        400000,
        reason: 'the stored minor units are left exactly as they were',
      );
    });

    testWidgets('an envelope can be archived and brought back', (tester) async {
      final harness = await pumpApp(tester);
      await addEnvelope(tester, name: 'Holiday', amount: '200,000');
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Holiday'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PaperButton, 'Archive'));
      await tester.pumpAndSettle();

      expect(harness.store.budget.envelopes.single.archived, isTrue);
      expect(find.text('Archived'), findsOneWidget);

      await tester.tap(find.text('Holiday'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PaperButton, 'Bring back'));
      await tester.pumpAndSettle();

      expect(harness.store.budget.envelopes.single.archived, isFalse);
    });

    testWidgets('deleting an envelope with history says what it will cost',
        (tester) async {
      final harness = await pumpApp(tester);
      await addEnvelope(tester, name: 'Dining', amount: '100,000');
      await tester.tap(find.text('Dining'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PaperButton, 'Add spending'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Amount'),
        '20,000',
      );
      await tester.tap(find.widgetWithText(PaperButton, 'Save'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dining'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PaperButton, 'Delete envelope'));
      await tester.pumpAndSettle();

      expect(find.textContaining('1 recorded transactions'), findsOneWidget);
      expect(find.textContaining('Archiving keeps'), findsOneWidget);

      await tester.tap(find.widgetWithText(PaperButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(harness.store.budget.envelopes, isEmpty);
      expect(harness.store.budget.transactions, isEmpty);
    });

    testWidgets('clearing everything keeps the currency', (tester) async {
      final harness = await pumpApp(tester);
      await addEnvelope(tester, name: 'Groceries', amount: '400,000');
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Delete everything'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Delete everything'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PaperButton, 'Delete everything'));
      await tester.pumpAndSettle();

      expect(harness.store.budget.envelopes, isEmpty);
      expect(harness.store.currency, Currency.krw);
      expect(find.text('Budget cleared'), findsOneWidget);
    });
  });

  group('currency behaviour in the UI', () {
    testWidgets('a won field refuses a decimal amount', (tester) async {
      final harness = await pumpApp(tester);
      await tester.tap(find.text('Add an envelope'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'X');
      await tester.enterText(
        find.widgetWithText(TextField, 'Amount each month'),
        '1500.5',
      );
      await tester.pumpAndSettle();

      expect(find.text('That is not an amount.'), findsOneWidget);
      await tester.tap(find.widgetWithText(PaperButton, 'Save'));
      await tester.pumpAndSettle();
      expect(
        harness.store.budget.envelopes,
        isEmpty,
        reason: 'there is no such thing as half a won',
      );
    });
  });

  group('persistence', () {
    testWidgets('a cold start restores the budget', (tester) async {
      final first = await pumpApp(tester);
      await addEnvelope(
        tester,
        name: 'Savings',
        amount: '200,000',
        rollover: true,
      );

      final second = Harness(seed: first.raw.snapshot);
      await second.store.initialize();
      expect(second.store.budget.envelopes.single.name, 'Savings');
      expect(second.store.budget.envelopes.single.rollover, isTrue);
    });
  });

  group('localisation', () {
    testWidgets('runs in Korean', (tester) async {
      await pumpApp(tester, locale: const Locale('ko'));

      expect(find.text('봉투가 없습니다'), findsOneWidget);
      expect(find.text('봉투 추가'), findsOneWidget);

      await tester.tap(find.text('봉투 추가'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, '이름'), '식비');
      await tester.enterText(
        find.widgetWithText(TextField, '매달 금액'),
        '400,000',
      );
      await tester.tap(find.widgetWithText(PaperButton, '저장'));
      await tester.pumpAndSettle();

      expect(find.text('식비'), findsOneWidget);
      expect(find.text('₩400,000'), findsWidgets);
    });
  });
}
