# Ledger — release checklist

What is done in this repository, and what is not. Nothing in the "needs a
Mac" or "needs an Android SDK" lists has been verified here: this container
has no Xcode, no Android SDK and no device of either kind.

## Done, and checked in

- **Icons.** Regenerate with `tool/make_app_icons.sh ledger` from the repo
  root. Every iOS and Android size is produced from one renderer, and the
  1024 marketing icon is written without an alpha channel - App Store
  Connect rejects one that has it, and the rejection arrives after upload.
- **Privacy policy**, both languages, in `store/privacy-policy.md`. It
  discloses the one thing the listing copy used to get wrong: the app sends
  nothing anywhere, but the *operating system's* backup includes this app's
  file like any other app's, on both platforms. That is left switched on - a
  budget history that does not survive a phone change is worth less than the
  claim it would buy - and said plainly instead.
- **Export compliance.** `ITSAppUsesNonExemptEncryption = false` in
  `Info.plist`. True for this app: it contains no encryption. **Inkwell must
  not copy this** - it uses AES and Argon2 and has to answer the question
  properly.
- **Privacy manifest.** `ios/Runner/PrivacyInfo.xcprivacy`, declaring no
  tracking, no collected data and no required-reason API use.
- **Portrait only**, on both platforms. Supporting an orientation the
  layouts were never designed for is how a reviewer finds a broken screen.
  Android 16 lifts the lock above 600dp by itself, which leaves a tablet the
  same latitude the iPad build has.
- **Localised launcher name**, English and Korean, for both platforms, plus
  `locales_config.xml` so Android 13 and above list the app under per-app
  language settings.
- **Adaptive launcher icon** for Android, with a monochrome layer for
  Android 13's themed icons. Without it every phone since Android 8.0 shows
  the flat icon shrunk onto a white backplate.
- **An upload-key slot** for Android. `android/key.properties` is read if it
  is there and ignored by git; without it a release build is signed with the
  debug key, and Gradle says so on every configure. See
  `android/README.md`.
- **Screenshots.** `flutter test tool/screenshots.dart --update-goldens`
  writes the 6.9" set to `store/screenshots/`.
- **Listing copy** for both stores, English and Korean:
  `store/listing-*.md` for the App Store, `store/play-*.md` for Play, and
  the rest of the App Store Connect form in `store/metadata.md`. Check the
  field limits with `tool/check_listing.py apps/ledger/store` from the repo
  root - a console silently truncates an over-long field, or rejects the
  upload after the binary has already gone up. The Play files also list the
  search terms they mean to rank for, and the same script checks each one
  actually appears in the description: Play has no keyword field and indexes
  the description itself.
- **Play's feature graphic**, 1024×500 in both languages, written to
  `store/feature-graphic-*.png` by the same golden run as the screenshots.
  Play will not let you publish without one.

## Needs a Mac, and is not verified here

1. **Bundle identifier.** Currently `com.tyttest.ledger` in
   `ios/Runner.xcodeproj` and `android/app/build.gradle.kts`. Change it
   before the first upload if you own a domain - it cannot be changed after.
2. **Add two files to the Xcode target.** `PrivacyInfo.xcprivacy` and the
   `en.lproj` / `ko.lproj` `InfoPlist.strings` exist on disk but are not
   referenced by `project.pbxproj`. Drag them into the Runner target in
   Xcode (the strings files into Copy Bundle Resources). They were not added
   by hand here because editing `project.pbxproj` blind, with no way to open
   the project and check, risks corrupting it.
3. **Signing**: team, provisioning profile, and a matching App Store Connect
   record.
4. **Run it on a real device.** Nothing in this app has ever executed on
   iOS hardware. The first run is where keyboard behaviour, safe areas on a
   notched device and the system font show up.
5. **Store screenshots.** The set in `store/screenshots/` is rendered from
   the real widget tree at 1320×2868, which is the right size and the right
   pixels - but it is rendered by the test harness with a substitute font,
   not by iOS with the system face. Re-shoot on a device or simulator before
   uploading.

## Needs an Android SDK, and is not verified here

The Android side has never been compiled. This container's network policy
denies `dl.google.com`, so the SDK cannot be installed and neither
`flutter build apk` nor `flutter build appbundle` has ever run. Everything
below the Flutter layer - the Gradle script, the manifest, the resources -
is correct by inspection only.

1. **Build it once.** `flutter build appbundle --release`. The first build
   is where a Gradle mistake surfaces, and there are three new things here
   for it to surface in: the signing block, `locales_config.xml` and the
   adaptive icon.
2. **Make an upload key** and write `android/key.properties`, per
   `android/README.md`. Back the keystore up somewhere you will still have
   it in five years; losing it means losing the ability to update the app.
3. **Run it on a real phone.** Nothing here has executed on Android either.
   The back gesture, the IME over the amount field, and the system font are
   all first seen there.

What *is* checked here is the half that does not need a compiler:
`tool/check_android_res.py` resolves every `@type/name` in the manifest and
in res/ against the resources that exist, and checks the adaptive icon has
all its layers at every density with a flat icon behind it. A mistyped
`@mipmap/ic_launcher_foreground` is normally caught in the first ten seconds
of the first build; without that build it would otherwise be caught by a user
whose home screen is blank. `tool/check.sh` runs it.
4. **Privacy policy URL.** Both stores require one, Play even for an app
   that collects nothing, and neither accepts "we collect nothing" as a
   substitute for a page. The text is written, in both languages, in
   `store/privacy-policy.md`. Two fields have to be filled in before it goes
   anywhere - the developer name and a contact address - and then it needs
   hosting at a public URL.
5. **Data safety form, content rating, target audience.** Answered in the
   console rather than in the repository, and a wrong answer is treated as a
   policy violation rather than a mistake. The answers, with the reasoning
   for each, are in `store/play-console.md`.
6. **Screenshots.** Play takes the same PNGs as the App Store set, which are
   within its size limits - but they carry the same caveat: rendered by the
   test harness with a substitute font, not by a device.
7. **Closed testing, if the Play account is a new personal one.** Twelve
   testers for fourteen continuous days before production access can even be
   applied for. Organisation accounts are exempt. Check the current rule in
   the console: this one moves, and it is weeks of calendar time either way.

## Before any of this: who else is already there

`store/competition.md`. The assumption this app was built on - that no
established Korean app does prospective, envelope-style budgeting - has
three named counterexamples and has never been verified from here, because
every store host is blocked by this environment's network policy. That file
records what is believed, how strongly, and the five checks that settle it.
Two of them decide what the listing should lead with, so they are worth
doing before the copy is final rather than after.

## Pricing

The paid Finance chart's incumbents sit at $2.99–$5.99, and Korean
budgeting apps sell lifetime unlocks at ₩25,000–29,000 as in-app purchases
after a free trial. Paid-upfront carries far more friction than an unlock
someone buys after using the app, so the first list is the better guide:
around **₩8,000 / $5.99**, not ₩1,100.
