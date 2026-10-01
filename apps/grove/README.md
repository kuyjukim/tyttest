# Grove

A focus timer that grows a tree while you work. Finish the session and the tree is planted for good; walk away and it withers.

Entirely offline: no account, no sync, and no network code in the app at all.

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
