# Android build

Everything here is the Flutter template except for four things, each of which
the template leaves to you and none of which the build will complain about if
you forget.

**The icon is adaptive.** `tool/make_app_icons.sh` writes the two layers and
the `mipmap-anydpi-v26/ic_launcher.xml` that pairs them, alongside the flat
`ic_launcher.png` that Android 7.0 and 7.1 still use. Regenerate rather than
edit: the layers are derived from `tool/make_icon.py`.

**The activity is locked to portrait**, like the iPhone build. Android 16
lifts the lock above 600dp on its own, which leaves a tablet the latitude the
iPad build already has.

**`locales_config.xml` lists the languages**, so Android 13 and above offer
the app under per-app language settings. It has to agree with
`CFBundleLocalizations` on iOS and with the delegates in `lib/ui/strings.dart`.

**Release builds need an upload key**, and without one they are signed with
the debug key - fine for `flutter run --release`, rejected by the Play
Console. Gradle says which of the two it used on every configure.

## Signing a build for Play

Make a key once, outside the repository:

```sh
keytool -genkey -v -keystore ~/ledger-upload.jks \
    -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Then write `android/key.properties`, which is git-ignored and must stay that
way - anyone with this file and the keystore can publish an update as you:

```properties
storeFile=/absolute/path/to/ledger-upload.jks
storePassword=...
keyAlias=upload
keyPassword=...
```

`storeFile` is resolved relative to this directory, so an absolute path is
the honest thing to put there.

```sh
flutter build appbundle --release    # what Play takes
flutter build apk --release          # for sideloading and for testing
```

Keep the keystore backed up somewhere you will still have it in five years.
Play ties the app listing to the key; losing it means losing the ability to
update the app, and the only way back is Play App Signing's key reset, which
is a support request rather than a setting.
