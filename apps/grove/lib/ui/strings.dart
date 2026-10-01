import 'package:flutter/widgets.dart';
import 'package:paper/paper.dart';

import '../domain/species.dart';
import '../state/session_controller.dart';

/// Grove's user-facing copy.
///
/// One implementation per language, so a missing translation is a compile
/// error. See `HandwrittenStrings` in `paper` for why this is not ARB.
abstract class S {
  static const HandwrittenStrings<S> delegate = HandwrittenStrings<S>({
    'en': En.new,
    'ko': Ko.new,
  });

  static S of(BuildContext context) => Localizations.of<S>(context, S) ?? En();

  String get appName;

  String get tabFocus;
  String get tabGarden;
  String get tabStats;
  String get tabSettings;

  String get focusTitle;
  String get tagHint;
  String get start;
  String get giveUp;
  String get giveUpConfirmTitle;
  String get giveUpConfirmBody;
  String get giveUpConfirmAction;
  String get strictOnNotice;
  String get strictOffNotice;
  String get plantedTitle;
  String get plantedBody;
  String get witheredTitle;
  String witheredBody(FailureReason reason);
  String get done;
  String get pickSpecies;
  String lockedUntil(String span);
  String get goalMet;
  String goalRemaining(String span);

  String get gardenTitle;
  String get gardenEmptyTitle;
  String get gardenEmptyBody;
  String get gardenEmptyAction;
  String plantedCount(int count);
  String witheredCount(int count);
  String get sessionCompleted;
  String get sessionAbandoned;
  String sessionReached(String percent);
  String get today;
  String get yesterday;

  String get statsTitle;
  String get statTodayLabel;
  String get statStreakLabel;
  String get statLifetimeLabel;
  String get streakUnitDays;
  String get rangeWeek;
  String get rangeMonth;
  String get bestDay;
  String get byTag;
  String get noStatsYet;

  String get settingsTitle;
  String get appearance;
  String get sessionSection;
  String get themeSystem;
  String get themeLight;
  String get themeDark;
  String get strictMode;
  String get strictModeBody;
  String get dailyGoal;
  String get haptics;
  String get hapticsBody;
  String get collection;
  String get dangerZone;
  String get clearGarden;
  String get clearGardenConfirmTitle;
  String get clearGardenConfirmBody;
  String get clearGardenConfirmAction;
  String get clearedToast;
  String get about;
  String get aboutBody;

  String speciesName(Species species);

  /// `2h 30m`, localised.
  String span(Duration duration);
}

class En implements S {
  @override
  String get appName => 'Grove';

  @override
  String get tabFocus => 'Focus';
  @override
  String get tabGarden => 'Garden';
  @override
  String get tabStats => 'Stats';
  @override
  String get tabSettings => 'Settings';

  @override
  String get focusTitle => 'Plant a tree';
  @override
  String get tagHint => 'What are you working on?';
  @override
  String get start => 'Start';
  @override
  String get giveUp => 'Give up';
  @override
  String get giveUpConfirmTitle => 'Let this tree die?';
  @override
  String get giveUpConfirmBody =>
      'The session will be recorded as abandoned, and the tree will stay in '
      'your garden as a stump.';
  @override
  String get giveUpConfirmAction => 'Give up';
  @override
  String get strictOnNotice => 'Leaving the app will kill the tree.';
  @override
  String get strictOffNotice => 'You can leave the app; the timer keeps going.';
  @override
  String get plantedTitle => 'Planted';
  @override
  String get plantedBody => 'Your tree is in the garden for good.';
  @override
  String get witheredTitle => 'It withered';
  @override
  String witheredBody(FailureReason reason) => switch (reason) {
    FailureReason.gaveUp => 'You ended the session early.',
    FailureReason.leftApp => 'You left the app while strict mode was on.',
    FailureReason.appClosed => 'The app stopped running before the timer ended.',
  };
  @override
  String get done => 'Done';
  @override
  String get pickSpecies => 'Species';
  @override
  String lockedUntil(String span) => 'Unlocks at $span of focus';
  @override
  String get goalMet => 'Daily goal met';
  @override
  String goalRemaining(String span) => '$span left today';

  @override
  String get gardenTitle => 'Garden';
  @override
  String get gardenEmptyTitle => 'Nothing planted yet';
  @override
  String get gardenEmptyBody =>
      'Finish a focus session and the tree you grew stays here.';
  @override
  String get gardenEmptyAction => 'Start focusing';
  @override
  String plantedCount(int count) => count == 1 ? '1 planted' : '$count planted';
  @override
  String witheredCount(int count) => '$count withered';
  @override
  String get sessionCompleted => 'Completed';
  @override
  String get sessionAbandoned => 'Abandoned';
  @override
  String sessionReached(String percent) => 'Got $percent of the way';
  @override
  String get today => 'Today';
  @override
  String get yesterday => 'Yesterday';

  @override
  String get statsTitle => 'Stats';
  @override
  String get statTodayLabel => 'Today';
  @override
  String get statStreakLabel => 'Streak';
  @override
  String get statLifetimeLabel => 'Lifetime';
  @override
  String get streakUnitDays => 'days';
  @override
  String get rangeWeek => '7 days';
  @override
  String get rangeMonth => '30 days';
  @override
  String get bestDay => 'Best day';
  @override
  String get byTag => 'What you focused on';
  @override
  String get noStatsYet => 'Finish a session to see your numbers here.';

  @override
  String get settingsTitle => 'Settings';
  @override
  String get appearance => 'Appearance';
  @override
  // Not just "Focus": that is also the tab's name, and two different things
  // with the same label in one app is one thing too many.
  String get sessionSection => 'Focus sessions';
  @override
  String get themeSystem => 'System';
  @override
  String get themeLight => 'Light';
  @override
  String get themeDark => 'Dark';
  @override
  String get strictMode => 'Strict mode';
  @override
  String get strictModeBody =>
      'Leaving the app during a session kills the tree. A glance of up to 20 '
      'seconds is forgiven, so a phone call will not cost you the session.';
  @override
  String get dailyGoal => 'Daily goal';
  @override
  String get haptics => 'Haptics';
  @override
  String get hapticsBody => 'Vibrate when the dial moves and when a tree is planted.';
  @override
  String get collection => 'Collection';
  @override
  String get dangerZone => 'Danger zone';
  @override
  String get clearGarden => 'Delete every tree';
  @override
  String get clearGardenConfirmTitle => 'Delete your whole garden?';
  @override
  String get clearGardenConfirmBody =>
      'Every session, planted and withered, will be erased. Your settings are '
      'kept. This cannot be undone.';
  @override
  String get clearGardenConfirmAction => 'Delete everything';
  @override
  String get clearedToast => 'Garden cleared';
  @override
  String get about => 'About';
  @override
  String get aboutBody =>
      'Grove keeps everything on this device. There is no account, no sync '
      'and no network access - which is also why there is nothing to lose if '
      'you go offline.';

  @override
  String speciesName(Species species) => switch (species) {
    Species.sprout => 'Sprout',
    Species.pine => 'Pine',
    Species.maple => 'Maple',
    Species.ginkgo => 'Ginkgo',
    Species.willow => 'Willow',
    Species.cherry => 'Cherry',
    Species.baobab => 'Baobab',
  };

  @override
  String span(Duration duration) {
    final total = duration.isNegative ? Duration.zero : duration;
    final hours = total.inHours;
    final minutes = total.inMinutes % 60;
    if (hours == 0) return '${minutes}m';
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }
}

class Ko implements S {
  @override
  String get appName => '그로브';

  @override
  String get tabFocus => '집중';
  @override
  String get tabGarden => '정원';
  @override
  String get tabStats => '기록';
  @override
  String get tabSettings => '설정';

  @override
  String get focusTitle => '나무 심기';
  @override
  String get tagHint => '무엇에 집중하나요?';
  @override
  String get start => '시작';
  @override
  String get giveUp => '포기';
  @override
  String get giveUpConfirmTitle => '이 나무를 포기할까요?';
  @override
  String get giveUpConfirmBody => '중단으로 기록되고, 나무는 그루터기로 정원에 남습니다.';
  @override
  String get giveUpConfirmAction => '포기하기';
  @override
  String get strictOnNotice => '앱을 벗어나면 나무가 시듭니다.';
  @override
  String get strictOffNotice => '앱을 벗어나도 타이머는 계속됩니다.';
  @override
  String get plantedTitle => '심었습니다';
  @override
  String get plantedBody => '이 나무는 정원에 영구히 남습니다.';
  @override
  String get witheredTitle => '시들었습니다';
  @override
  String witheredBody(FailureReason reason) => switch (reason) {
    FailureReason.gaveUp => '세션을 일찍 끝냈습니다.',
    FailureReason.leftApp => '엄격 모드가 켜진 상태에서 앱을 벗어났습니다.',
    FailureReason.appClosed => '타이머가 끝나기 전에 앱이 종료되었습니다.',
  };
  @override
  String get done => '확인';
  @override
  String get pickSpecies => '수종';
  @override
  String lockedUntil(String span) => '누적 $span 집중 시 해금';
  @override
  String get goalMet => '오늘 목표 달성';
  @override
  String goalRemaining(String span) => '오늘 $span 남음';

  @override
  String get gardenTitle => '정원';
  @override
  String get gardenEmptyTitle => '아직 심은 나무가 없습니다';
  @override
  String get gardenEmptyBody => '집중 세션을 끝내면 그때 키운 나무가 이곳에 남습니다.';
  @override
  String get gardenEmptyAction => '집중 시작';
  @override
  String plantedCount(int count) => '$count그루 심음';
  @override
  String witheredCount(int count) => '$count그루 시듦';
  @override
  String get sessionCompleted => '완료';
  @override
  String get sessionAbandoned => '중단';
  @override
  String sessionReached(String percent) => '$percent 진행';
  @override
  String get today => '오늘';
  @override
  String get yesterday => '어제';

  @override
  String get statsTitle => '기록';
  @override
  String get statTodayLabel => '오늘';
  @override
  String get statStreakLabel => '연속';
  @override
  String get statLifetimeLabel => '누적';
  @override
  String get streakUnitDays => '일';
  @override
  String get rangeWeek => '7일';
  @override
  String get rangeMonth => '30일';
  @override
  String get bestDay => '최고 기록일';
  @override
  String get byTag => '집중한 일';
  @override
  String get noStatsYet => '세션을 한 번 끝내면 숫자가 쌓입니다.';

  @override
  String get settingsTitle => '설정';
  @override
  String get appearance => '화면';
  @override
  String get sessionSection => '집중 세션';
  @override
  String get themeSystem => '시스템';
  @override
  String get themeLight => '밝게';
  @override
  String get themeDark => '어둡게';
  @override
  String get strictMode => '엄격 모드';
  @override
  String get strictModeBody =>
      '세션 중 앱을 벗어나면 나무가 시듭니다. 20초 이내의 짧은 이탈은 허용되므로, '
      '전화 한 통으로 세션을 잃지는 않습니다.';
  @override
  String get dailyGoal => '하루 목표';
  @override
  String get haptics => '진동';
  @override
  String get hapticsBody => '다이얼을 돌릴 때와 나무를 심을 때 진동합니다.';
  @override
  String get collection => '수집';
  @override
  String get dangerZone => '위험 구역';
  @override
  String get clearGarden => '모든 나무 삭제';
  @override
  String get clearGardenConfirmTitle => '정원을 전부 삭제할까요?';
  @override
  String get clearGardenConfirmBody =>
      '심은 나무와 시든 나무 전부가 지워집니다. 설정은 유지됩니다. 되돌릴 수 없습니다.';
  @override
  String get clearGardenConfirmAction => '전부 삭제';
  @override
  String get clearedToast => '정원을 비웠습니다';
  @override
  String get about => '정보';
  @override
  String get aboutBody =>
      '그로브는 모든 데이터를 이 기기에만 저장합니다. 계정도, 동기화도, 네트워크 접근도 '
      '없습니다. 그래서 오프라인에서도 잃을 것이 없습니다.';

  @override
  String speciesName(Species species) => switch (species) {
    Species.sprout => '새싹',
    Species.pine => '소나무',
    Species.maple => '단풍나무',
    Species.ginkgo => '은행나무',
    Species.willow => '버드나무',
    Species.cherry => '벚나무',
    Species.baobab => '바오바브',
  };

  @override
  String span(Duration duration) {
    final total = duration.isNegative ? Duration.zero : duration;
    final hours = total.inHours;
    final minutes = total.inMinutes % 60;
    if (hours == 0) return '$minutes분';
    if (minutes == 0) return '$hours시간';
    return '$hours시간 $minutes분';
  }
}
