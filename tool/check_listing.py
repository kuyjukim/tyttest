#!/usr/bin/env python3
"""Checks store listing copy against the two stores' field limits.

Worth automating because the failure mode is slow: a console accepts a
too-long field by truncating it, or rejects the upload after the binary has
already gone up. Both are found minutes later rather than now.

Both stores count characters rather than bytes, so Korean counts the same as
English.

The stores differ in a way that matters more than the limits. Apple gives you
a hidden keyword field; Google gives you none, and indexes the description
itself. So a Play file carries the search terms it means to rank for, and
this checks that each one actually appears in the text a shopper reads -
which is the only place Play can find it.

Usage:  tool/check_listing.py apps/ledger/store
"""
from __future__ import annotations

import pathlib
import re
import sys


# A listing file is one locale of one store: `play-ko.md`, `listing-en.md`,
# and room for the regional forms (`play-pt-BR.md`) if the app ever ships to
# a market that needs one. Matching `play-*.md` instead would sweep up notes
# that live beside the copy - which it did, the first time.
LISTING_FILE = re.compile(r'^(?P<prefix>\w+)-(?P<locale>[a-z]{2}(?:-[A-Za-z]{2,4})?)\.md$')


class Store:
    def __init__(self, name: str, prefix: str, limits: dict[str, int],
                 aliases: dict[str, str], searchable: tuple[str, ...] = ()):
        self.name = name
        self.prefix = prefix
        self.limits = limits
        self.aliases = aliases
        # Fields a shopper reads, and therefore the only text Play's search
        # can index. Empty for a store with a keyword field.
        self.searchable = searchable


APP_STORE = Store(
    'App Store',
    'listing',
    {
        'name': 30,
        'subtitle': 30,
        'keywords': 100,
        'promotional text': 170,
        'description': 4000,
    },
    {
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
    },
)

PLAY = Store(
    'Google Play',
    'play',
    {
        'name': 30,
        'short description': 80,
        'full description': 4000,
    },
    {
        '앱 이름': 'name',
        '간단한 설명': 'short description',
        '자세한 설명': 'full description',
        '검색어': 'search terms',
        'app name': 'name',
        'short description': 'short description',
        'full description': 'full description',
        'search terms': 'search terms',
    },
    searchable=('name', 'short description', 'full description'),
)

STORES = (APP_STORE, PLAY)


def sections(text: str, aliases: dict[str, str]) -> dict[str, str]:
    found: dict[str, str] = {}
    for match in re.finditer(r'^## (.+?)$\n(.*?)(?=^## |\Z)', text, re.S | re.M):
        heading = match.group(1).strip().lower()
        body = '\n'.join(
            line for line in match.group(2).strip().split('\n')
            if not line.startswith('>')
        ).strip()
        for alias, field in aliases.items():
            if heading.startswith(alias):
                found[field] = body
                break
    return found


def check(path: pathlib.Path, store: Store) -> bool:
    found = sections(path.read_text(), store.aliases)
    print(f'\n{path}  ({store.name})')
    ok = True
    for field, limit in store.limits.items():
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
    if store.searchable:
        ok = check_search_terms(found, store) and ok
    return ok


def check_search_terms(found: dict[str, str], store: Store) -> bool:
    terms = found.get('search terms')
    if terms is None:
        print('  [MISSING] search terms')
        return False
    # Case-insensitively, because store search is: a term that opens a
    # sentence is still the term, and failing it would only teach whoever
    # writes the copy to distrust this check.
    haystack = ' '.join(found.get(f, '') for f in store.searchable).lower()
    wanted = [t.strip() for t in re.split(r'[,\n]', terms) if t.strip()]
    missing = [t for t in wanted if t.lower() not in haystack]
    print(f'  [{"MISS" if missing else "OK  "}] {"search terms":18} '
          f'{len(wanted) - len(missing):5} / {len(wanted)} present in the copy')
    for term in missing:
        print(f'    missing: {term}')
    return not missing


def main() -> int:
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else '.')
    results: list[bool] = []
    for store in STORES:
        files = sorted(
            path for path in root.glob(f'{store.prefix}-*.md')
            if (match := LISTING_FILE.match(path.name))
            and match['prefix'] == store.prefix
        )
        if not files:
            print(f'No {store.prefix}-*.md under {root} - '
                  f'nothing to check for {store.name}', file=sys.stderr)
            continue
        # Every file is checked before deciding: a generator inside `all()`
        # short-circuits, so one bad file used to hide the next one entirely.
        results.extend(check(f, store) for f in files)

    if not results:
        print(f'No listing files at all under {root}', file=sys.stderr)
        return 2
    if all(results):
        print('\nall fields within limits')
        return 0
    print('\nfix the fields marked above')
    return 1


if __name__ == '__main__':
    raise SystemExit(main())
