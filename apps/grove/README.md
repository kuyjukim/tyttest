# Grove

A focus timer that grows a tree while you work. Finish the session and the tree is planted for good; walk away and it withers.

Entirely offline: no account, no sync, and no network code in the app at all.
`timezone`, pulled in by the notification plugin, is the one dependency with a
`package:http` edge; it lives in `timezone/browser.dart`, which is the web
entry point and is not imported by anything Grove ships.

From this directory:

```sh
flutter run      # run it
flutter test     # this app's suite
```

Or, from the repository root, `tool/check.sh grove` to analyze and test it the
way CI does.

The decisions behind this app - and what it deliberately does not do - are
written up in the [repository README](../../README.md), next to the other
three. Why this is the one being submitted first is in
[PLAN.md](../../PLAN.md).

## Notifications

Grove posts exactly one notification: the end of a session it was not on
screen for. It is armed when the app leaves the foreground and dropped when it
comes back, so nothing is ever posted into an app the user is looking at - the
countdown and the finish haptic already say that - and on Android, where a
foreground notification cannot be suppressed, nothing has to be.

The copy is deliberately neutral ("시간이 끝났습니다" / "Time is up"). In strict
mode a session that ends while the app is away has usually already failed, so
neither "grown" nor "withered" can be promised from the alarm.

The split is `lib/platform/session_alarm.dart`, an interface with a no-op
default, and `lib/platform/notification_alarm.dart`, the plugin behind it.
Everything decidable in Dart - whether to arm, for which instant, when to drop
it - is decided in `GardenStore` and covered by `test/session_alarm_test.dart`.
What is left is delivery, and **that has not been run on a device**: this
repository can compile both platforms in CI but cannot launch either, so the
banner itself is unverified until someone installs it on a phone.

Two platform notes worth knowing before that run:

* **Android 14+** does not grant `SCHEDULE_EXACT_ALARM` on install, and
  `USE_EXACT_ALARM` - the one that is granted - is restricted by Google to
  alarm-clock and calendar apps and audited at review. Grove asks for the
  former and falls back to an inexact alarm when it is refused, which can fire
  a few minutes late on a dozing phone.
* **The alarm instant is named in UTC**, not in the device's zone, because it
  is a fixed point a few minutes away rather than a wall-clock time. That is
  also why no tzdata is loaded and no platform zone is looked up.

## The public page

`store/landing.html` is the marketing page, and it carries the privacy policy
the App Store submission needs a URL for. It is written as an artifact body -
no doctype, no `<head>` - so it cannot be served as-is. `tool/build_site.sh`
wraps it, copies the icon and four screenshots alongside, and writes `docs/`
at the repository root:

```sh
tool/build_site.sh                      # writes docs/
python3 -m http.server -d docs 8000     # look at it
```

GitHub Pages is pointed at `docs/` once, by hand, under
Settings -> Pages -> Source: Deploy from a branch. Re-run the script and
commit `docs/` after any change to the page or the screenshots; nothing
builds it automatically.

The trees on that page are the real ones: `lib/ui/widgets/tree_figure.dart`
ported to canvas, same staged growth and same species table. Only the random
source differs, so a seed draws a tree of the same character rather than the
same tree.

## Store assets

`store/` holds what App Store Connect asks for: the listing copy in both
languages, the icons, and the screenshots. Regenerate the screenshots after
any change that moves pixels - they are golden files rendered at device size
rather than captured from a simulator, so they are reproducible on any
machine:

```sh
flutter test tool/screenshots.dart --update-goldens
```

The icons come from the repository root, since one renderer draws all of
them:

```sh
tool/make_app_icons.sh grove      # every iOS and Android size
ruby tool/wire_ios_resources.rb grove   # puts the privacy manifest in the bundle
```
