import 'package:flutter/widgets.dart';
import 'package:paper/paper.dart';

/// Ledger's user-facing copy, English and Korean.
abstract class S {
  static const HandwrittenStrings<S> delegate = HandwrittenStrings<S>({
    'en': En.new,
    'ko': Ko.new,
  });

  static S of(BuildContext context) => Localizations.of<S>(context, S) ?? En();

  String get appName;
  String get tabBudget;
  String get tabTransactions;
  String get tabReports;
  String get tabSettings;

  String get thisMonth;
  String get previousMonth;
  String get nextMonth;

  String get income;
  String get setIncome;
  String get leftToBudget;
  String get overCommitted;
  String get safeToSpend;
  String get perDay;
  String get monthIsOver;
  String get budgeted;
  String get spent;
  String get remaining;
  String get available;
  String get carriedIn;
  String get overspentBy;

  String get envelopes;
  String get newEnvelope;
  String get editEnvelope;
  String get envelopeName;
  String get monthlyAmount;
  String get thisMonthsAmount;
  String get rollover;
  String get rolloverBody;
  String get moveMoney;
  String get moveFrom;
  String get moveTo;
  String get amount;
  String get move;
  String get archive;
  String get unarchive;
  String get archived;
  String get deleteEnvelope;
  String get deleteEnvelopeConfirmTitle;
  String deleteEnvelopeConfirmBody(int transactions);
  String get deleteEnvelopeConfirmAction;
  String get budgetEmptyTitle;
  String get budgetEmptyBody;
  String get budgetEmptyAction;

  String get addSpend;
  String get addRefund;
  String get note;
  String get date;
  String get today;
  String get yesterday;
  String get transactionsEmptyTitle;
  String get transactionsEmptyBody;
  String get deleteTransaction;
  String get deleteTransactionConfirmTitle;
  String get deleteTransactionConfirmBody;
  String get save;
  String get cancel;

  String get spendByEnvelope;
  String get dailySpend;
  String get range1m;
  String get range3m;
  String get range6m;
  String get reportsEmpty;

  String get appearance;
  String get themeSystem;
  String get themeLight;
  String get themeDark;
  String get currency;
  String get currencyWarningTitle;
  String currencyWarningBody(String from, String to);
  String get currencyWarningAction;
  String get manageEnvelopes;
  String get about;
  String get aboutBody;
  String get dangerZone;
  String get clearAll;
  String get clearAllConfirmTitle;
  String get clearAllConfirmBody;
  String get clearAllConfirmAction;
  String get clearedToast;

  String get invalidAmount;
  String get nameRequired;
  String get noEnvelopeYet;
}

class En implements S {
  @override
  String get appName => 'Ledger';
  @override
  String get tabBudget => 'Budget';
  @override
  String get tabTransactions => 'Spending';
  @override
  String get tabReports => 'Reports';
  @override
  String get tabSettings => 'Settings';

  @override
  String get thisMonth => 'This month';
  @override
  String get previousMonth => 'Previous month';
  @override
  String get nextMonth => 'Next month';

  @override
  String get income => 'Income';
  @override
  String get setIncome => 'Set income';
  @override
  String get leftToBudget => 'Left to budget';
  @override
  String get overCommitted => 'Budgeted beyond income';
  @override
  String get safeToSpend => 'Safe to spend';
  @override
  String get perDay => 'per day';
  @override
  String get monthIsOver => 'This month has ended';
  @override
  String get budgeted => 'Budgeted';
  @override
  String get spent => 'Spent';
  @override
  String get remaining => 'Left';
  @override
  String get available => 'Available';
  @override
  String get carriedIn => 'Carried in';
  @override
  String get overspentBy => 'Over by';

  @override
  String get envelopes => 'Envelopes';
  @override
  String get newEnvelope => 'New envelope';
  @override
  String get editEnvelope => 'Edit envelope';
  @override
  String get envelopeName => 'Name';
  @override
  String get monthlyAmount => 'Amount each month';
  @override
  String get thisMonthsAmount => "This month's amount";
  @override
  String get rollover => 'Carry the balance over';
  @override
  String get rolloverBody =>
      'What is left at month end moves into next month - and so does an '
      'overspend. Useful for saving up; leave it off for things like '
      'groceries that start fresh.';
  @override
  String get moveMoney => 'Move money';
  @override
  String get moveFrom => 'From';
  @override
  String get moveTo => 'To';
  @override
  String get amount => 'Amount';
  @override
  String get move => 'Move';
  @override
  String get archive => 'Archive';
  @override
  String get unarchive => 'Bring back';
  @override
  String get archived => 'Archived';
  @override
  String get deleteEnvelope => 'Delete envelope';
  @override
  String get deleteEnvelopeConfirmTitle => 'Delete this envelope?';
  @override
  String deleteEnvelopeConfirmBody(int transactions) => transactions == 0
      ? 'It has no spending recorded against it.'
      : 'Its $transactions recorded transactions will be deleted too, and '
            'past months will no longer add up the same way. Archiving keeps '
            'the history.';
  @override
  String get deleteEnvelopeConfirmAction => 'Delete';
  @override
  String get budgetEmptyTitle => 'No envelopes yet';
  @override
  String get budgetEmptyBody =>
      'Give each thing you spend on an amount for the month. What is left is '
      'then a fact rather than a guess.';
  @override
  String get budgetEmptyAction => 'Add an envelope';

  @override
  String get addSpend => 'Add spending';
  @override
  String get addRefund => 'Add a refund';
  @override
  String get note => 'Note';
  @override
  String get date => 'Date';
  @override
  String get today => 'Today';
  @override
  String get yesterday => 'Yesterday';
  @override
  String get transactionsEmptyTitle => 'Nothing recorded this month';
  @override
  String get transactionsEmptyBody =>
      'Add what you spend as you spend it; the envelopes update as you go.';
  @override
  String get deleteTransaction => 'Delete';
  @override
  String get deleteTransactionConfirmTitle => 'Delete this entry?';
  @override
  String get deleteTransactionConfirmBody => 'The envelope will be adjusted.';
  @override
  String get save => 'Save';
  @override
  String get cancel => 'Cancel';

  @override
  String get spendByEnvelope => 'Where the money went';
  @override
  String get dailySpend => 'Spending by day';
  @override
  String get range1m => '1 month';
  @override
  String get range3m => '3 months';
  @override
  String get range6m => '6 months';
  @override
  String get reportsEmpty => 'Record some spending and the picture shows up here.';

  @override
  String get appearance => 'Appearance';
  @override
  String get themeSystem => 'System';
  @override
  String get themeLight => 'Light';
  @override
  String get themeDark => 'Dark';
  @override
  String get currency => 'Currency';
  @override
  String get currencyWarningTitle => 'Change the currency?';
  @override
  String currencyWarningBody(String from, String to) =>
      'Your amounts are not converted - there is no exchange rate offline, '
      'and inventing one would be worse than leaving the numbers alone. '
      '$from 150,000 becomes $to 150,000.';
  @override
  String get currencyWarningAction => 'Change it';
  @override
  String get manageEnvelopes => 'Manage envelopes';
  @override
  String get about => 'About';
  @override
  String get aboutBody =>
      'Everything is stored on this device. There is no bank connection, no '
      'account and no subscription - which is also why nothing here can stop '
      'working when a server does.';
  @override
  String get dangerZone => 'Danger zone';
  @override
  String get clearAll => 'Delete everything';
  @override
  String get clearAllConfirmTitle => 'Delete the whole budget?';
  @override
  String get clearAllConfirmBody =>
      'Every envelope and every recorded transaction will be erased. Your '
      'currency and theme are kept. This cannot be undone.';
  @override
  String get clearAllConfirmAction => 'Delete everything';
  @override
  String get clearedToast => 'Budget cleared';

  @override
  String get invalidAmount => 'That is not an amount.';
  @override
  String get nameRequired => 'Give it a name.';
  @override
  String get noEnvelopeYet => 'Add an envelope first.';
}

class Ko implements S {
  @override
  String get appName => '레저';
  @override
  String get tabBudget => '예산';
  @override
  String get tabTransactions => '지출';
  @override
  String get tabReports => '리포트';
  @override
  String get tabSettings => '설정';

  @override
  String get thisMonth => '이번 달';
  @override
  String get previousMonth => '지난달';
  @override
  String get nextMonth => '다음 달';

  @override
  String get income => '수입';
  @override
  String get setIncome => '수입 입력';
  @override
  String get leftToBudget => '배정 남은 금액';
  @override
  String get overCommitted => '수입보다 많이 배정됨';
  @override
  String get safeToSpend => '안심 지출 한도';
  @override
  String get perDay => '하루';
  @override
  String get monthIsOver => '지난 달입니다';
  @override
  String get budgeted => '배정';
  @override
  String get spent => '지출';
  @override
  String get remaining => '남음';
  @override
  String get available => '사용 가능';
  @override
  String get carriedIn => '이월';
  @override
  String get overspentBy => '초과';

  @override
  String get envelopes => '봉투';
  @override
  String get newEnvelope => '새 봉투';
  @override
  String get editEnvelope => '봉투 수정';
  @override
  String get envelopeName => '이름';
  @override
  String get monthlyAmount => '매달 금액';
  @override
  String get thisMonthsAmount => '이번 달 금액';
  @override
  String get rollover => '잔액 이월';
  @override
  String get rolloverBody =>
      '월말에 남은 금액이 다음 달로 넘어갑니다. 초과 지출도 같이 넘어갑니다. 목돈 모으기에 '
      '유용하고, 식비처럼 매달 새로 시작하는 항목은 끄는 편이 좋습니다.';
  @override
  String get moveMoney => '금액 이동';
  @override
  String get moveFrom => '보낼 봉투';
  @override
  String get moveTo => '받을 봉투';
  @override
  String get amount => '금액';
  @override
  String get move => '이동';
  @override
  String get archive => '보관';
  @override
  String get unarchive => '되살리기';
  @override
  String get archived => '보관됨';
  @override
  String get deleteEnvelope => '봉투 삭제';
  @override
  String get deleteEnvelopeConfirmTitle => '이 봉투를 삭제할까요?';
  @override
  String deleteEnvelopeConfirmBody(int transactions) => transactions == 0
      ? '기록된 지출이 없습니다.'
      : '기록된 지출 $transactions건도 함께 삭제되고, 지난 달 합계가 달라집니다. '
            '보관하면 기록은 그대로 남습니다.';
  @override
  String get deleteEnvelopeConfirmAction => '삭제';
  @override
  String get budgetEmptyTitle => '봉투가 없습니다';
  @override
  String get budgetEmptyBody =>
      '지출 항목마다 이번 달 금액을 정해두면, 남은 돈이 추측이 아니라 사실이 됩니다.';
  @override
  String get budgetEmptyAction => '봉투 추가';

  @override
  String get addSpend => '지출 입력';
  @override
  String get addRefund => '환불 입력';
  @override
  String get note => '메모';
  @override
  String get date => '날짜';
  @override
  String get today => '오늘';
  @override
  String get yesterday => '어제';
  @override
  String get transactionsEmptyTitle => '이번 달 기록이 없습니다';
  @override
  String get transactionsEmptyBody => '쓸 때마다 적어두면 봉투가 바로 갱신됩니다.';
  @override
  String get deleteTransaction => '삭제';
  @override
  String get deleteTransactionConfirmTitle => '이 기록을 삭제할까요?';
  @override
  String get deleteTransactionConfirmBody => '해당 봉투 금액이 조정됩니다.';
  @override
  String get save => '저장';
  @override
  String get cancel => '취소';

  @override
  String get spendByEnvelope => '어디에 썼나';
  @override
  String get dailySpend => '일별 지출';
  @override
  String get range1m => '1개월';
  @override
  String get range3m => '3개월';
  @override
  String get range6m => '6개월';
  @override
  String get reportsEmpty => '지출을 기록하면 여기에 그림이 나타납니다.';

  @override
  String get appearance => '화면';
  @override
  String get themeSystem => '시스템';
  @override
  String get themeLight => '밝게';
  @override
  String get themeDark => '어둡게';
  @override
  String get currency => '통화';
  @override
  String get currencyWarningTitle => '통화를 바꿀까요?';
  @override
  String currencyWarningBody(String from, String to) =>
      '금액은 환산되지 않습니다. 오프라인에는 환율이 없고, 임의의 환율을 쓰는 것이 숫자를 '
      '그대로 두는 것보다 나쁩니다. $from 150,000은 $to 150,000이 됩니다.';
  @override
  String get currencyWarningAction => '바꾸기';
  @override
  String get manageEnvelopes => '봉투 관리';
  @override
  String get about => '정보';
  @override
  String get aboutBody =>
      '모든 데이터는 이 기기에만 저장됩니다. 은행 연동도, 계정도, 구독도 없습니다. '
      '그래서 어떤 서버가 멈춰도 이 앱은 멈추지 않습니다.';
  @override
  String get dangerZone => '위험 구역';
  @override
  String get clearAll => '전부 삭제';
  @override
  String get clearAllConfirmTitle => '예산을 전부 삭제할까요?';
  @override
  String get clearAllConfirmBody =>
      '모든 봉투와 기록된 지출이 지워집니다. 통화와 테마는 유지됩니다. 되돌릴 수 없습니다.';
  @override
  String get clearAllConfirmAction => '전부 삭제';
  @override
  String get clearedToast => '예산을 비웠습니다';

  @override
  String get invalidAmount => '금액 형식이 아닙니다.';
  @override
  String get nameRequired => '이름을 입력하세요.';
  @override
  String get noEnvelopeYet => '먼저 봉투를 추가하세요.';
}
