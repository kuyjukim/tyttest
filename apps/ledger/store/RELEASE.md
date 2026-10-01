# Ledger — release checklist

What is done in this repository, and what still needs a Mac. Everything in
the second list is unverified here, because this container has no Xcode and
no device.

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
- **Portrait only.** Supporting an orientation the layouts were never
  designed for is how a reviewer finds a broken screen.
- **Localised launcher name**, English and Korean, for both platforms.
- **Screenshots.** `flutter test tool/screenshots.dart --update-goldens`
  writes the 6.9" set to `store/screenshots/`.

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

## Pricing

The paid Finance chart's incumbents sit at $2.99–$5.99, and Korean
budgeting apps sell lifetime unlocks at ₩25,000–29,000 as in-app purchases
after a free trial. Paid-upfront carries far more friction than an unlock
someone buys after using the app, so the first list is the better guide:
around **₩8,000 / $5.99**, not ₩1,100.
