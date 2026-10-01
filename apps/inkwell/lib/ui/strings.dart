import 'package:flutter/widgets.dart';
import 'package:paper/paper.dart';

import '../domain/entry.dart';
import '../domain/passphrase.dart';

/// Inkwell's user-facing copy, English and Korean.
abstract class S {
  static const HandwrittenStrings<S> delegate = HandwrittenStrings<S>({
    'en': En.new,
    'ko': Ko.new,
  });

  static S of(BuildContext context) => Localizations.of<S>(context, S) ?? En();

  String get appName;
  String get tabJournal;
  String get tabInsights;
  String get tabSettings;

  String get createTitle;
  String get createBody;
  String get noRecoveryWarning;
  String get passphraseLabel;
  String get confirmLabel;
  String get createAction;
  String get passphrasesDiffer;
  String get tooShort;
  String strengthLabel(PassphraseStrength strength);

  String get unlockTitle;
  String get unlockAction;
  String get wrongPassphrase;
  String lockedOutFor(String span);
  String attemptsSoFar(int count);
  String get vaultCorrupt;
  String get vaultTooNew;
  String get lockNow;

  String get searchHint;
  String get journalEmptyTitle;
  String get journalEmptyBody;
  String get journalEmptyAction;
  String get newEntry;
  String get onThisDay;
  String yearsAgo(int years);
  String get untitled;
  String get today;
  String get yesterday;

  String get titleHint;
  String get bodyHint;
  String get moodLabel;
  String moodName(Mood mood);
  String get tagsLabel;
  String get addTagHint;
  String get save;
  String get delete;
  String get deleteConfirmTitle;
  String get deleteConfirmBody;
  String get deleteConfirmAction;
  String get discardTitle;
  String get discardBody;
  String get discardAction;
  String get keepEditing;
  String wordCount(int words);

  String get streakLabel;
  String get entriesLabel;
  String get wordsLabel;
  String get moodMix;
  String get writingActivity;
  String get insightsEmpty;
  String get days;

  String get appearance;
  String get themeSystem;
  String get themeLight;
  String get themeDark;
  String get security;
  String get autoLock;
  String get autoLockImmediately;
  String get autoLockNever;
  String get changePassphrase;
  String get currentPassphrase;
  String get newPassphrase;
  String get changeAction;
  String get passphraseChanged;
  String get export;
  String get exportBody;
  String get exportWarning;
  String get exportAction;
  String get exportedToast;
  String get about;
  String get aboutBody;
  String get biometricsNote;
  String get dangerZone;
  String get destroyVault;
  String get destroyConfirmTitle;
  String get destroyConfirmBody;
  String get destroyConfirmAction;

  /// `3 days`, `2 hours`, localised. Used for the auto-lock and lockout copy.
  String span(Duration duration);
}

class En implements S {
  @override
  String get appName => 'Inkwell';
  @override
  String get tabJournal => 'Journal';
  @override
  String get tabInsights => 'Insights';
  @override
  String get tabSettings => 'Settings';

  @override
  String get createTitle => 'Choose a passphrase';
  @override
  String get createBody =>
      'Everything you write is encrypted with a key derived from this '
      'passphrase. Length matters far more than symbols - a few uncommon '
      'words you will remember beats a short tangle you will not.';
  @override
  String get noRecoveryWarning =>
      'There is no reset and no recovery. If you forget this passphrase, the '
      'entries are gone - not withheld, gone.';
  @override
  String get passphraseLabel => 'Passphrase';
  @override
  String get confirmLabel => 'Type it again';
  @override
  String get createAction => 'Create journal';
  @override
  String get passphrasesDiffer => 'The two entries do not match.';
  @override
  String get tooShort => 'At least ${Passphrase.minimumLength} characters.';
  @override
  String strengthLabel(PassphraseStrength strength) => switch (strength) {
    PassphraseStrength.tooShort => 'Too short',
    PassphraseStrength.weak => 'Weak',
    PassphraseStrength.fair => 'Fair',
    PassphraseStrength.good => 'Good',
    PassphraseStrength.strong => 'Strong',
  };

  @override
  String get unlockTitle => 'Unlock your journal';
  @override
  String get unlockAction => 'Unlock';
  @override
  String get wrongPassphrase =>
      'That did not open the journal. If you are sure the passphrase is '
      'right, the file may have been modified.';
  @override
  String lockedOutFor(String span) => 'Too many attempts. Try again in $span.';
  @override
  String attemptsSoFar(int count) =>
      count == 1 ? '1 failed attempt' : '$count failed attempts';
  @override
  String get vaultCorrupt => 'This file is not a readable Inkwell journal.';
  @override
  String get vaultTooNew =>
      'This journal was written by a newer version of Inkwell. Update the app '
      'to open it.';
  @override
  String get lockNow => 'Lock now';

  @override
  String get searchHint => 'Search entries';
  @override
  String get journalEmptyTitle => 'Nothing written yet';
  @override
  String get journalEmptyBody =>
      'Your first entry is encrypted the moment you save it.';
  @override
  String get journalEmptyAction => 'Write something';
  @override
  String get newEntry => 'New entry';
  @override
  String get onThisDay => 'On this day';
  @override
  String yearsAgo(int years) => years == 1 ? 'A year ago' : '$years years ago';
  @override
  String get untitled => 'Untitled';
  @override
  String get today => 'Today';
  @override
  String get yesterday => 'Yesterday';

  @override
  String get titleHint => 'Title (optional)';
  @override
  String get bodyHint => 'What happened?';
  @override
  String get moodLabel => 'Mood';
  @override
  String moodName(Mood mood) => switch (mood) {
    Mood.awful => 'Awful',
    Mood.low => 'Low',
    Mood.neutral => 'Neutral',
    Mood.good => 'Good',
    Mood.great => 'Great',
  };
  @override
  String get tagsLabel => 'Tags';
  @override
  String get addTagHint => 'Add a tag';
  @override
  String get save => 'Save';
  @override
  String get delete => 'Delete';
  @override
  String get deleteConfirmTitle => 'Delete this entry?';
  @override
  String get deleteConfirmBody => 'It cannot be recovered.';
  @override
  String get deleteConfirmAction => 'Delete';
  @override
  String get discardTitle => 'Discard changes?';
  @override
  String get discardBody => 'What you have typed will not be saved.';
  @override
  String get discardAction => 'Discard';
  @override
  String get keepEditing => 'Keep editing';
  @override
  String wordCount(int words) => words == 1 ? '1 word' : '$words words';

  @override
  String get streakLabel => 'Streak';
  @override
  String get entriesLabel => 'Entries';
  @override
  String get wordsLabel => 'Words';
  @override
  String get moodMix => 'How you have felt';
  @override
  String get writingActivity => 'Entries per day';
  @override
  String get insightsEmpty =>
      'Write a few entries and your patterns show up here.';
  @override
  String get days => 'days';

  @override
  String get appearance => 'Appearance';
  @override
  String get themeSystem => 'System';
  @override
  String get themeLight => 'Light';
  @override
  String get themeDark => 'Dark';
  @override
  String get security => 'Security';
  @override
  String get autoLock => 'Auto-lock';
  @override
  String get autoLockImmediately => 'When I leave the app';
  @override
  String get autoLockNever => 'Never';
  @override
  String get changePassphrase => 'Change passphrase';
  @override
  String get currentPassphrase => 'Current passphrase';
  @override
  String get newPassphrase => 'New passphrase';
  @override
  String get changeAction => 'Change';
  @override
  String get passphraseChanged => 'Passphrase changed';
  @override
  String get export => 'Export as plain text';
  @override
  String get exportBody =>
      'A journal that only this app can read is a journal held hostage, so '
      'the door is here.';
  @override
  String get exportWarning =>
      'The export is NOT encrypted. Anything you do with it - share sheet, '
      'cloud drive, email - is readable by whoever receives it.';
  @override
  String get exportAction => 'Export anyway';
  @override
  String get exportedToast => 'Exported';
  @override
  String get about => 'About';
  @override
  String get aboutBody =>
      'Entries are sealed with AES-256-GCM under a key derived from your '
      'passphrase with Argon2id. The app contains no networking code at all, '
      'so there is nowhere for your journal to go.';
  @override
  String get biometricsNote =>
      'There is deliberately no Face ID unlock. Unlocking with a face means '
      'storing the key where a face can fetch it, and the honest version of '
      'that is a second, weaker lock on the same door.';
  @override
  String get dangerZone => 'Danger zone';
  @override
  String get destroyVault => 'Delete the journal';
  @override
  String get destroyConfirmTitle => 'Delete everything?';
  @override
  String get destroyConfirmBody =>
      'Every entry is erased from this device. There is no backup and no '
      'recovery.';
  @override
  String get destroyConfirmAction => 'Delete everything';

  @override
  String span(Duration duration) {
    final total = duration.isNegative ? Duration.zero : duration;
    if (total.inDays >= 1) {
      return total.inDays == 1 ? '1 day' : '${total.inDays} days';
    }
    if (total.inHours >= 1) {
      return total.inHours == 1 ? '1 hour' : '${total.inHours} hours';
    }
    if (total.inMinutes >= 1) {
      return total.inMinutes == 1 ? '1 minute' : '${total.inMinutes} minutes';
    }
    return '${total.inSeconds} seconds';
  }
}

class Ko implements S {
  @override
  String get appName => '잉크웰';
  @override
  String get tabJournal => '일기';
  @override
  String get tabInsights => '통계';
  @override
  String get tabSettings => '설정';

  @override
  String get createTitle => '암호문구를 정하세요';
  @override
  String get createBody =>
      '작성한 모든 내용은 이 암호문구에서 파생한 키로 암호화됩니다. 특수문자보다 길이가 '
      '훨씬 중요합니다. 기억할 수 있는 흔하지 않은 단어 몇 개가 짧고 복잡한 조합보다 낫습니다.';
  @override
  String get noRecoveryWarning =>
      '재설정도 복구도 없습니다. 이 암호문구를 잊으면 기록은 접근이 막히는 것이 아니라 '
      '사라집니다.';
  @override
  String get passphraseLabel => '암호문구';
  @override
  String get confirmLabel => '한 번 더 입력';
  @override
  String get createAction => '일기 만들기';
  @override
  String get passphrasesDiffer => '두 입력이 일치하지 않습니다.';
  @override
  String get tooShort => '${Passphrase.minimumLength}자 이상이어야 합니다.';
  @override
  String strengthLabel(PassphraseStrength strength) => switch (strength) {
    PassphraseStrength.tooShort => '너무 짧음',
    PassphraseStrength.weak => '약함',
    PassphraseStrength.fair => '보통',
    PassphraseStrength.good => '좋음',
    PassphraseStrength.strong => '매우 강함',
  };

  @override
  String get unlockTitle => '일기 열기';
  @override
  String get unlockAction => '열기';
  @override
  String get wrongPassphrase => '일기를 열지 못했습니다. 암호문구가 확실하다면 파일이 수정되었을 수 있습니다.';
  @override
  String lockedOutFor(String span) => '시도가 너무 많습니다. $span 후에 다시 시도하세요.';
  @override
  String attemptsSoFar(int count) => '실패 $count회';
  @override
  String get vaultCorrupt => '읽을 수 있는 잉크웰 일기 파일이 아닙니다.';
  @override
  String get vaultTooNew => '더 새로운 버전에서 만든 일기입니다. 앱을 업데이트하세요.';
  @override
  String get lockNow => '지금 잠그기';

  @override
  String get searchHint => '기록 검색';
  @override
  String get journalEmptyTitle => '아직 쓴 글이 없습니다';
  @override
  String get journalEmptyBody => '첫 기록은 저장하는 즉시 암호화됩니다.';
  @override
  String get journalEmptyAction => '쓰기 시작';
  @override
  String get newEntry => '새 기록';
  @override
  String get onThisDay => '그날의 기록';
  @override
  String yearsAgo(int years) => '$years년 전';
  @override
  String get untitled => '제목 없음';
  @override
  String get today => '오늘';
  @override
  String get yesterday => '어제';

  @override
  String get titleHint => '제목 (선택)';
  @override
  String get bodyHint => '무슨 일이 있었나요?';
  @override
  String get moodLabel => '기분';
  @override
  String moodName(Mood mood) => switch (mood) {
    Mood.awful => '최악',
    Mood.low => '나쁨',
    Mood.neutral => '보통',
    Mood.good => '좋음',
    Mood.great => '최고',
  };
  @override
  String get tagsLabel => '태그';
  @override
  String get addTagHint => '태그 추가';
  @override
  String get save => '저장';
  @override
  String get delete => '삭제';
  @override
  String get deleteConfirmTitle => '이 기록을 삭제할까요?';
  @override
  String get deleteConfirmBody => '복구할 수 없습니다.';
  @override
  String get deleteConfirmAction => '삭제';
  @override
  String get discardTitle => '변경을 버릴까요?';
  @override
  String get discardBody => '입력한 내용이 저장되지 않습니다.';
  @override
  String get discardAction => '버리기';
  @override
  String get keepEditing => '계속 쓰기';
  @override
  String wordCount(int words) => '$words단어';

  @override
  String get streakLabel => '연속';
  @override
  String get entriesLabel => '기록';
  @override
  String get wordsLabel => '단어';
  @override
  String get moodMix => '기분 분포';
  @override
  String get writingActivity => '하루 기록 수';
  @override
  String get insightsEmpty => '기록이 몇 개 쌓이면 여기에 패턴이 보입니다.';
  @override
  String get days => '일';

  @override
  String get appearance => '화면';
  @override
  String get themeSystem => '시스템';
  @override
  String get themeLight => '밝게';
  @override
  String get themeDark => '어둡게';
  @override
  String get security => '보안';
  @override
  String get autoLock => '자동 잠금';
  @override
  String get autoLockImmediately => '앱을 벗어나면 바로';
  @override
  String get autoLockNever => '안 함';
  @override
  String get changePassphrase => '암호문구 변경';
  @override
  String get currentPassphrase => '현재 암호문구';
  @override
  String get newPassphrase => '새 암호문구';
  @override
  String get changeAction => '변경';
  @override
  String get passphraseChanged => '암호문구를 변경했습니다';
  @override
  String get export => '평문으로 내보내기';
  @override
  String get exportBody => '이 앱만 읽을 수 있는 일기는 인질입니다. 그래서 출구를 둡니다.';
  @override
  String get exportWarning =>
      '내보낸 파일은 암호화되지 않습니다. 공유, 클라우드, 메일 등 어디로 보내든 받는 사람이 '
      '그대로 읽을 수 있습니다.';
  @override
  String get exportAction => '그래도 내보내기';
  @override
  String get exportedToast => '내보냈습니다';
  @override
  String get about => '정보';
  @override
  String get aboutBody =>
      '기록은 Argon2id로 암호문구에서 파생한 키를 사용해 AES-256-GCM으로 봉인됩니다. '
      '앱에는 네트워크 코드가 전혀 없으므로 일기가 나갈 곳이 없습니다.';
  @override
  String get biometricsNote =>
      'Face ID 잠금 해제는 의도적으로 넣지 않았습니다. 얼굴로 열려면 얼굴이 꺼낼 수 있는 '
      '곳에 키를 두어야 하고, 그것은 같은 문에 더 약한 자물쇠를 하나 더 다는 일입니다.';
  @override
  String get dangerZone => '위험 구역';
  @override
  String get destroyVault => '일기 삭제';
  @override
  String get destroyConfirmTitle => '전부 삭제할까요?';
  @override
  String get destroyConfirmBody => '이 기기에서 모든 기록이 지워집니다. 백업도 복구도 없습니다.';
  @override
  String get destroyConfirmAction => '전부 삭제';

  @override
  String span(Duration duration) {
    final total = duration.isNegative ? Duration.zero : duration;
    if (total.inDays >= 1) return '${total.inDays}일';
    if (total.inHours >= 1) return '${total.inHours}시간';
    if (total.inMinutes >= 1) return '${total.inMinutes}분';
    return '${total.inSeconds}초';
  }
}
