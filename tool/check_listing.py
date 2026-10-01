#!/usr/bin/env python3
"""Checks store listing copy against App Store Connect's field limits.

Worth automating because the failure mode is slow: App Store Connect accepts
a too-long field by truncating it, or rejects the upload after the binary has
already gone up. Both are found minutes later rather than now.

Apple counts characters, not bytes, so Korean counts the same as English.

Usage:  tool/check_listing.py apps/ledger/store
"""
from __future__ import annotations

import pathlib
import re
import sys

LIMITS: dict[str, int] = {
    'name': 30,
    'subtitle': 30,
    'keywords': 100,
    'promotional text': 170,
    'description': 4000,
}

# The headings used in each locale's file, lowercased and matched loosely so
# the copy can be edited without breaking the check.
ALIASES: dict[str, str] = {
    '이름': 'name',
    '부제': 'subtitle',
    '키워드': 'keywords',
    '프로모션 텍스트': 'promotional text',
    '설명': 'description',
    'name': 'name',
    'subtitle': 'subtitle',
    'keywords': 'keywords',
    'promotional text': 'promotional text',
    'description': 'description',
}


def sections(text: str) -> dict[str, str]:
    found: dict[str, str] = {}
    for match in re.finditer(r'^## (.+?)$\n(.*?)(?=^## |\Z)', text, re.S | re.M):
        heading = match.group(1).strip().lower()
        body = '\n'.join(
            line for line in match.group(2).strip().split('\n')
            if not line.startswith('>')
        ).strip()
        for alias, field in ALIASES.items():
            if heading.startswith(alias):
                found[field] = body
                break
    return found


def check(path: pathlib.Path) -> bool:
    found = sections(path.read_text())
    print(f'\n{path}')
    ok = True
    for field, limit in LIMITS.items():
        body = found.get(field)
        if body is None:
            print(f'  [MISSING] {field}')
            ok = False
            continue
        count = len(body)
        over = count > limit
        ok = ok and not over
        print(f'  [{"OVER" if over else "OK  "}] {field:18} {count:5} / {limit}')
        if field == 'keywords':
            if ' ' in body:
                print('    note: spaces in the keyword field waste characters')
                ok = False
            unused = limit - count
            if unused > 15:
                print(f'    note: {unused} characters unused - that is '
                      'free search coverage left on the table')
    return ok


def main() -> int:
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else '.')
    files = sorted(root.glob('listing-*.md'))
    if not files:
        print(f'No listing-*.md under {root}', file=sys.stderr)
        return 2
    # Every file is checked before deciding: a generator inside `all()`
    # short-circuits, so one bad file used to hide the next one entirely.
    results = [check(f) for f in files]
    if all(results):
        print('\nall fields within limits')
        return 0
    print('\nfix the fields marked above')
    return 1


if __name__ == '__main__':
    raise SystemExit(main())
