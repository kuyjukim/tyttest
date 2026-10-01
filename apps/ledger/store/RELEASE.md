# Ledger — release checklist

What is done in this repository, and what is not. Nothing in the "needs a
Mac" or "needs an Android SDK" lists has been verified here: this container
has no Xcode, no Android SDK and no device of either kind.

## Done, and checked in

- **Icons.** Regenerate with `tool/make_app_icons.sh ledger` from the repo
  root. Every iOS and Android size is produced from one renderer, and the
  1024 marketing icon is written without an alpha channel - App Store
  Connect rejects one that has it, and the rejection arrives after upload.
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
4. **Privacy policy URL.** Play requires one for every app, including one
   that collects nothing, and will not accept "we collect nothing" as a
   substitute. It has to be a page you host.
5. **Data safety form.** Declare no collection and no sharing. It is
   answered in the console, not in the repository, and a wrong answer here
   is treated as a policy violation rather than a mistake.
6. **Content rating questionnaire**, and the target audience declaration.
7. **Screenshots.** Play takes the same PNGs as the App Store set, which are
   within its size limits - but they carry the same caveat: rendered by the
   test harness with a substitute font, not by a device.

## Pricing

The paid Finance chart's incumbents sit at $2.99–$5.99, and Korean
budgeting apps sell lifetime unlocks at ₩25,000–29,000 as in-app purchases
after a free trial. Paid-upfront carries far more friction than an unlock
someone buys after using the app, so the first list is the better guide:
around **₩8,000 / $5.99**, not ₩1,100.
