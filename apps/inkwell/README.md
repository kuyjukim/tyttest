# Inkwell

An encrypted journal. Entries are sealed with AES-256-GCM under a key derived from your passphrase with Argon2id.

Entirely offline: no account, no sync, and no network code in the app at all.

From this directory:

```sh
flutter run      # run it
flutter test     # this app's suite
```

Or, from the repository root, `tool/check.sh inkwell` to analyze and test it the
way CI does.

The decisions behind this app - and what it deliberately does not do - are
written up in the [repository README](../../README.md), next to the other
three.
