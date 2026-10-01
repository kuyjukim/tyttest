#!/usr/bin/env python3
"""Resolves every Android resource reference against the resources that exist.

This exists because the Android build is the one build this repository cannot
run: the SDK platform comes from dl.google.com and nothing else serves it, so
a container without that host has no `android.jar` and therefore no
`flutter build apk`. A mistyped `@mipmap/ic_launcher_foreground` is normally
caught in the first ten seconds of the first build. Without that build, it is
caught by a user whose home screen shows a blank icon.

So: parse the manifest and every XML under res/, find each `@type/name`, and
check something defines it. Framework references (`@android:...`) and theme
attributes (`?attr/...`) are somebody else's to resolve and are skipped.

It is not aapt. It does not type-check, it does not evaluate qualifiers, and
it will not tell you that a drawable is malformed. It tells you that every
name you referred to is a name that exists, which is the error this repo is
actually exposed to.

Usage:  tool/check_android_res.py [apps/ledger ...]
"""
from __future__ import annotations

import pathlib
import re
import sys
import xml.etree.ElementTree as ET

# `@package:+type/name`, with the package and the plus both optional.
REFERENCE = re.compile(r'@(?:(\w+):)?(\+?)(\w+)/([\w.]+)')

# Elements under <resources> whose tag is not the resource type it defines.
VALUE_TAGS = {
    'string-array': 'array',
    'integer-array': 'array',
    'declare-styleable': 'styleable',
}


def defined(res: pathlib.Path) -> set[tuple[str, str]]:
    """Every (type, name) the resource directory defines."""
    found: set[tuple[str, str]] = set()
    if not res.is_dir():
        return found

    for directory in sorted(res.iterdir()):
        if not directory.is_dir():
            continue
        # "mipmap-anydpi-v26" defines mipmap; "values-ko" defines whatever is
        # written inside it.
        kind = directory.name.split('-', 1)[0]
        for path in sorted(directory.iterdir()):
            if not path.is_file():
                continue
            if kind == 'values':
                found |= values_in(path)
            else:
                # A nine-patch keeps the .9, an icon loses only its extension.
                stem = path.name.split('.')[0]
                found.add((kind, stem))
    return found


def values_in(path: pathlib.Path) -> set[tuple[str, str]]:
    if path.suffix != '.xml':
        return set()
    root = ET.parse(path).getroot()
    found: set[tuple[str, str]] = set()
    for element in root:
        name = element.get('name')
        if name is None:
            continue
        kind = element.get('type') if element.tag == 'item' else element.tag
        if kind is None:
            continue
        found.add((VALUE_TAGS.get(kind, kind), name))
    return found


def referenced(root: pathlib.Path) -> list[tuple[pathlib.Path, str, str]]:
    """Every (file, type, name) referred to, excluding framework and ids.

    Parsed rather than grepped. Flutter's own launch_background.xml carries a
    commented-out `@mipmap/launch_image` for you to uncomment, and a checker
    that reads the raw text reports it as missing in every app in the repo -
    which is how a check teaches people to ignore it.
    """
    out: list[tuple[pathlib.Path, str, str]] = []
    files = [root / 'AndroidManifest.xml']
    files += sorted((root / 'res').rglob('*.xml'))
    for path in files:
        if not path.is_file():
            continue
        for element in ET.parse(path).iter():
            # A reference can be an attribute value (`android:drawable=`) or
            # the element's own text (`<item>@color/ink</item>`).
            for text in (*element.attrib.values(), element.text or ''):
                for package, plus, kind, name in REFERENCE.findall(text):
                    # `@android:` is the framework's. `@+id/x` declares rather
                    # than refers, and an id needs no definition elsewhere.
                    if package == 'android' or plus or kind == 'id':
                        continue
                    out.append((path, kind, name))
    return out


def check(app: pathlib.Path) -> bool:
    main = app / 'android' / 'app' / 'src' / 'main'
    if not (main / 'AndroidManifest.xml').is_file():
        print(f'{app}: no Android manifest, skipping')
        return True

    have = defined(main / 'res')
    ok = True
    print(f'\n{app}')

    missing = [
        (path, kind, name)
        for path, kind, name in referenced(main)
        if (kind, name) not in have
    ]
    for path, kind, name in missing:
        ok = False
        print(f'  [MISSING] @{kind}/{name}'
              f'  referenced by {path.relative_to(app)}')
    if not missing:
        print(f'  [OK  ] every reference resolves '
              f'({len(have)} resources defined)')

    ok = adaptive_icon(main / 'res', have) and ok
    return ok


def adaptive_icon(res: pathlib.Path, have: set[tuple[str, str]]) -> bool:
    """An adaptive icon does not replace the flat one, it sits beside it."""
    if not (res / 'mipmap-anydpi-v26' / 'ic_launcher.xml').is_file():
        return True

    legacy = sorted(res.glob('mipmap-*dpi/ic_launcher.png'))
    if not legacy:
        print('  [MISSING] mipmap-*dpi/ic_launcher.png - the adaptive icon '
              'leaves Android 7 with no icon at all')
        return False

    # Each layer at every density the flat icon is drawn at: a layer that
    # stops at xhdpi is upscaled from there on the phones with the most
    # pixels, which is exactly backwards.
    densities = {path.parent.name for path in legacy}
    ok = True
    for layer in ('ic_launcher_foreground', 'ic_launcher_monochrome'):
        if ('mipmap', layer) not in have:
            continue
        for density in sorted(densities):
            if not (res / density / f'{layer}.png').is_file():
                print(f'  [MISSING] {density}/{layer}.png')
                ok = False
    if ok:
        print(f'  [OK  ] adaptive icon complete at {len(densities)} densities,'
              ' with a flat icon behind it')
    return ok


def main() -> int:
    root = pathlib.Path(__file__).resolve().parent.parent
    names = sys.argv[1:]
    apps = ([root / name for name in names] if names
            else sorted((root / 'apps').iterdir()))
    results = [check(app) for app in apps if app.is_dir()]
    if not results:
        print('No apps to check', file=sys.stderr)
        return 2
    if all(results):
        print('\nevery Android resource reference resolves')
        return 0
    print('\nfix the references marked above')
    return 1


if __name__ == '__main__':
    raise SystemExit(main())
