import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paper/paper.dart';

abstract class Demo {
  String get hello;
}

class DemoEn implements Demo {
  @override
  String get hello => 'Hello';
}

class DemoKo implements Demo {
  @override
  String get hello => '안녕하세요';
}

void main() {
  const delegate = HandwrittenStrings<Demo>({'en': DemoEn.new, 'ko': DemoKo.new});

  test('advertises exactly the locales it can build', () {
    expect(delegate.supportedLocales, [const Locale('en'), const Locale('ko')]);
    expect(delegate.isSupported(const Locale('ko', 'KR')), isTrue);
    expect(delegate.isSupported(const Locale('ja')), isFalse);
  });

  test('loads synchronously so the first frame is already translated', () {
    final future = delegate.load(const Locale('ko'));
    Demo? resolved;
    // ignore: discarded_futures
    future.then((value) => resolved = value);
    expect(resolved, isNotNull, reason: 'an async load would flash English');
    expect(resolved!.hello, '안녕하세요');
  });

  test('an unsupported locale fails loudly rather than falling back', () {
    expect(() => delegate.load(const Locale('ja')), throwsFlutterError);
  });

  test('bundles the SDK delegates so stock Material widgets translate too', () {
    final delegates = localizationDelegates(delegate);
    expect(delegates.first, same(delegate));
    expect(delegates.length, 4);
  });

  testWidgets('resolves through Localizations for a regional locale',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko', 'KR'),
        localizationsDelegates: localizationDelegates(delegate),
        supportedLocales: delegate.supportedLocales,
        home: Builder(
          builder: (context) =>
              Text(Localizations.of<Demo>(context, Demo)!.hello),
        ),
      ),
    );
    expect(find.text('안녕하세요'), findsOneWidget);
  });
}
