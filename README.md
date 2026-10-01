# tyttest — four paid-app candidates on one design system

Four complete, offline-first Flutter apps, built on a shared design system in
one repository.

| App | What it is | Tests |
|---|---|---|
| [`apps/grove`](apps/grove) | A focus timer that grows a procedural tree while you work | 84 |
| [`apps/inkwell`](apps/inkwell) | An encrypted journal (AES-256-GCM, Argon2id) | 123 |
| [`apps/ledger`](apps/ledger) | Offline envelope budgeting with integer money | 121 |
| [`apps/stroke`](apps/stroke) | A vector sketchbook with layers and deep undo | 130 |
| [`packages/paper`](packages/paper) | The shared design system they all run on | 67 |

525 tests, analyzer clean under a strict lint set, and every app compiles for
web as an end-to-end build check. About 16,700 lines of implementation and
8,700 of tests.

```sh
tool/check.sh                    # everything CI runs, in the same order
tool/check.sh grove              # one package
cd apps/grove && flutter run     # run an app
```

Requires Flutter 3.35.5 (the version CI pins). There is no melos and no
workspace file: each package resolves on its own and the apps depend on
`paper` by path, which keeps `flutter test` working in a fresh checkout with
no bootstrap step.

## What these four have in common

They are all built to be bought once rather than subscribed to, and that
decision shapes the code more than any style guide:

- **No network code.** Not "no telemetry by policy" - there is no HTTP client
  in any of the four. Nothing can stop working because a server does, which
  is the one promise a paid app can make that a subscription cannot.
- **No accounts, no sync.** Everything is a file on the device.
- **Three third-party dependencies in total**: `intl` for dates and number
  formats, `path_provider` to find the app-support directory, and
  `pointycastle` for Inkwell's crypto. Everything else is Flutter or this
  repo. A paid app's dependencies are its liabilities.
- **Local-first storage with atomic writes.** Saves go to a temp file and are
  renamed, so a crash mid-save can lose the new value but can never leave a
  half-written one - the difference between "lost today's entry" and "lost
  the journal".
- **English and Korean**, with the SDK's own localisation delegates bundled so
  stock Material affordances translate too.
- **Reduced motion is honoured.** Three of the four lean on animation to
  justify their price, which makes the OS setting a correctness concern.

## The shared design system

[`packages/paper`](packages/paper) carries the tokens, the two themes, the
motion rules, the primitive widgets, a pluggable key-value store, a validated
chart palette, calendar arithmetic and a one-file substitute for a
state-management dependency.

Two things in it are worth singling out.

**The chart palette is validated, not eyeballed.** The categorical slots were
run through a colour-vision validator against this suite's own surfaces: on
the adjacent pairlist that bars and stacks use, the worst adjacent pair is
ΔE 9.1 in light mode and 8.4 in dark (OKLab ×100, against a target of 8), and
worst-case normal-vision separation is 19.6 and 19.3 against a floor of 15.
Three light-mode slots fall below 3:1 contrast on the warm page, so every
chart that uses them ships visible direct labels. Colour follows the entity,
never its rank, so filtering or re-sorting never repaints the survivors.

**Calendar arithmetic never goes through `Duration`.** `subtract(const
Duration(days: 1))` is 23 or 25 hours across a DST boundary, which is how
streak bugs and off-by-one month totals happen. `Day` and `Month` step through
`DateTime`'s own field normalisation instead, and the date-sensitive suites run
in UTC, a DST zone and a half-hour-offset zone in CI.

## Grove — focus timer

Start a session, a tree grows while you work, finishing plants it permanently,
and leaving or giving up leaves a stump.

- **Elapsed time is read from the wall clock, never counted in ticks.** A
  tick-counting timer drifts, stops when the OS throttles timers, and gets
  starved by a busy frame, so a 25-minute session quietly becomes 27. A tick
  here only repaints the countdown.
- **There is no pause**, because pausing is the feature that makes a
  commitment device pointless. A test asserts the state machine has no state
  between running and ended, so adding one has to be deliberate.
- **Force-quitting is not an escape hatch.** The in-flight session is
  persisted the moment it starts and resolved on next launch.
- **Abandoned sessions stay in the garden.** A garden that only shows
  successes is a flattering lie, and the stumps are what give the planted
  trees their weight.
- **Trees are procedural**, so the timer animates continuously at any growth
  fraction instead of snapping between stage images, and a new species is a
  row of parameters rather than an asset set.

## Inkwell — encrypted journal

Entries are sealed with AES-256-GCM under a key derived from the user's
passphrase with Argon2id.

- **Argon2id at m=19 MiB, t=2, p=1** — OWASP's lower recommended set rather
  than the 64 MiB one. pointycastle is pure Dart, where 64 MiB with t=3
  measures 1.4 s on a desktop and several seconds on a phone; a five-second
  unlock trains its owner to pick a shorter passphrase, which costs more
  entropy than the memory buys.
- **The vault header is bound as GCM associated data.** The header has to be
  plaintext because it holds the salt and cost needed to derive the key, so an
  attacker can read it - and could otherwise rewrite `iterations` to 1 and
  make a strong passphrase brute-forceable. There is a test for that exact
  attack.
- **A fresh nonce on every seal**, with no API that accepts one from outside a
  test: nonce reuse under one key breaks GCM completely.
- **Failed attempts back off and persist**, so quitting is not a reset. This
  protects against someone holding an unlocked phone; an attacker with the
  file brute-forces offline, where only the Argon2 cost reaches them.
- **No Face ID**, because unlocking with a face means storing the key where a
  face can fetch it. The app says so in Settings rather than quietly omitting
  the feature.
- **Preferences are plaintext and outside the vault**, so the lock screen is
  the right colour before a passphrase is typed. Nothing about the entries,
  not even the count, is outside the sealed blob.

## Ledger — envelope budgeting

Give each category an amount for the month, record what you spend, see what is
actually left.

- **Money is integer minor units, never a double.** The app's whole job is
  adding up small numbers and comparing the total to another number, which is
  what binary floating point is worst at.
- **Decimal places come from the currency.** Won and yen have none; a dinar
  has three. Hard-coding two either shows a Korean user `₩1,500.00` or stores
  won as hundredths and rounds real money away.
- **Splitting an amount loses nothing.** The remainder goes out one minor unit
  at a time, largest fractional part first, so 100 split three ways is
  34/33/33. A sweep over 200 amounts and five ratio shapes asserts it.
- **Parsing refuses what it cannot represent** rather than rounding it:
  `12.567` in dollars and `1500.5` in won are both rejected, because silently
  rounding a typo hides it exactly where it matters.
- **Rollover carries overspending as well as surplus.** An envelope that
  forgives going over at midnight on the 31st is a tally, not a budget.
- **Moving money edits the plan, not the history.** When groceries runs short
  you take the money from somewhere; what should change is the plan, not the
  record of what was bought.
- **Changing currency does not convert amounts**, because there is no rate
  offline. The app says so in a dialog first.

## Stroke — vector sketchbook

Pressure-aware strokes, layers, deep undo, and files that are plain JSON.

- **Points, not pixels**, so a sketch stays sharp at any zoom. That is also
  why the eraser is stroke-level: a pixel eraser would force the drawing to be
  rasterised on first edit.
- **Catmull-Rom smoothing**, because it passes *through* its control points; a
  spline that only approximates them makes the ink lag behind the finger.
- **The outline is generated and filled, not stroked**, because a stroked path
  cannot vary its width. The taper is measured in arc length, so a line drawn
  slowly tapers like the same line drawn fast.
- **Undo is commands, not snapshots.** Erase records each stroke's index,
  because order decides what covers what.
- **Pointer events are handled directly, not through gesture recognisers.**
  The canvas has to tell one finger from two on the first move, and the
  gesture arena resolves that by waiting - which shows up as the first few
  millimetres of every stroke going missing.
- **One key per sketch**, with the gallery index reconciled against the keys
  actually present, so a crash between two writes cannot hide a drawing or
  leave a row that opens nothing.

## What is deliberately not here

Being straight about the gap between "four finished apps" and "an app on sale":

- **No App Store submission.** No developer account, no code signing, no App
  Store Connect metadata or screenshots, and no `PrivacyInfo.xcprivacy`
  privacy manifest (required since 2024, even for an app that collects
  nothing). Bundle ids are the `com.tyttest.*` placeholders from
  `flutter create`, and the icons and launch screens are the Flutter defaults.
- **Never run on a physical device.** The container has no simulator, so
  pressure sensitivity, haptics and iOS system fonts are written to the
  documented behaviour and verified by test, not by hand on hardware. That is
  the first thing to do with these.
- **No PNG or PDF export in Stroke**, and no image import in any app. Both
  need platform plugins that cannot be exercised here.
- **No biometric unlock in Inkwell**, for the reason given above rather than
  for want of time.
- **No bank connection in Ledger**, which is what the top paid budget apps
  have; that is a server, a regulator and a subscription, i.e. a different
  product.
- **Hand-written localisation rather than ARB files.** A missing translation
  is a compile error and a clean checkout needs no codegen, but the
  translator-facing tooling around ARB is given up. Worth it at two languages;
  not worth it past a handful.
- **Ranking is not an engineering output.** Nothing in a repository decides
  whether an app reaches the top of a paid chart - pricing, store listing,
  screenshots, reviews and timing do. What code can do is be worth paying for
  once and not break, and that is what these four are built to be.
