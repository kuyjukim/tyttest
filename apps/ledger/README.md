# Ledger

Envelope budgeting that works offline. Give every category an amount, spend against it, and see what is actually left.

Entirely offline: no account, no sync, and no network code in the app at all.

From this directory:

```sh
flutter run      # run it
flutter test     # this app's suite
```

Or, from the repository root, `tool/check.sh ledger` to analyze and test it the
way CI does.

The decisions behind this app - and what it deliberately does not do - are
written up in the [repository README](../../README.md), next to the other
three.

## Store assets

`store/` holds everything App Store Connect asks for: the listing copy in both
languages, the 1024px icon, and the screenshots. Regenerate the screenshots
after any change that moves pixels - they are golden files, rendered at device
size rather than captured from a simulator, so they are reproducible on any
machine:

```sh
flutter test --update-goldens tool/screenshots.dart
```

## Browser demo

`lib/demo_main.dart` is the same app over a pinned clock and a month of seeded
data, kept apart from `lib/main.dart` so none of it can reach the shipped
binary. It is also what the screenshots and the browser demo are built from.

```sh
tool/stage_web_demo.sh <output-directory>
```

That builds for the web and makes the result servable from a subdirectory:
CanvasKit local rather than fetched from a CDN, no service worker, a relative
`<base href>`. It also builds the Korean web font the demo loads at startup
(`tool/make_demo_fonts.py`, about 5 MB, generated rather than committed) -
the browser has no Korean system face to lend the app, and CanvasKit's own
answer of fetching Noto subsets from fonts.gstatic.com fails behind a strict
content security policy and leaves the interface blank.

The demo is the web build, so it differs from the real app in the ways the
web differs: no haptics, no native keyboard, and the system font is whatever
the browser has rather than the one iOS would use.
