#!/usr/bin/env python3
"""Builds the Korean web font the browser demo loads at startup.

The shipping iOS app does not bundle a font - it uses the system face, which
is the right typeface on the platform and costs nothing. The browser has no
such face to fall back on: CanvasKit resolves unknown glyphs by fetching Noto
subsets from fonts.gstatic.com at runtime, which a strict CSP blocks, and the
whole interface then renders as blank boxes. So the demo carries its own font,
and only the demo: these files land in web/, which `flutter build web` copies
and every other platform ignores.

Google's variable Noto Sans KR is 10 MB. Two passes cut it to roughly a tenth:
instancing pins the weight axis, so a static face per weight the design system
asks for, and subsetting drops everything the app cannot display anyway -
above all the 20,000 Han ideographs, which Korean UI text does not use.

Needs `pip install fonttools brotli`. Run from apps/ledger:

    tool/make_demo_fonts.py
"""

from __future__ import annotations

import subprocess
import sys
import tempfile
import urllib.request
from pathlib import Path

SOURCE = (
    'https://raw.githubusercontent.com/google/fonts/main/ofl/notosanskr/'
    'NotoSansKR%5Bwght%5D.ttf'
)
LICENSE = (
    'https://raw.githubusercontent.com/google/fonts/main/ofl/notosanskr/OFL.txt'
)

# Two weights, not the four the type scale names. The whole 11,172-syllable
# Hangul block costs about 2.9 MB per face, so four faces would weigh more
# than the rest of the bundle put together - and the cut that buys that back
# by keeping only the 2,350 syllables of KS X 1001 is the wrong one: a name
# typed with any syllable outside it renders as a box, and which names those
# are is not ours to decide. So every syllable stays, and the weights give.
# Skia matches an unbundled weight to the nearest bundled face, which puts
# the 300 and 500 styles on 400 - a flattening you can only see with both in
# front of you, where a missing glyph is a hole in the middle of a word.
WEIGHTS = (400, 600)

# What Korean and English interface text is actually made of. Hangul syllables
# are the bulk of it; the jamo blocks matter because a syllable typed on an IME
# arrives decomposed before it is composed, and dropping them makes text flicker
# into boxes as you type.
UNICODES = ','.join((
    'U+0020-007E',    # Basic Latin
    'U+00A0-00FF',    # Latin-1 Supplement: accents, middot, multiplication
    'U+0100-017F',    # Latin Extended-A, for European currency names
    'U+2000-206F',    # General Punctuation: dashes, curly quotes, ellipsis
    'U+20A0-20BF',    # Currency symbols: the won sign lives here
    'U+2190-21FF',    # Arrows
    'U+2200-22FF',    # Mathematical operators: the minus sign on a refund
    'U+2500-257F',    # Box drawing
    'U+25A0-25FF',    # Geometric shapes
    'U+2600-26FF',    # Miscellaneous symbols
    'U+1100-11FF',    # Hangul Jamo
    'U+3000-303F',    # CJK symbols and punctuation
    'U+3130-318F',    # Hangul Compatibility Jamo
    'U+A960-A97F',    # Hangul Jamo Extended-A
    'U+AC00-D7A3',    # Hangul Syllables - the 11,172 of them
    'U+D7B0-D7FF',    # Hangul Jamo Extended-B
    'U+FFFD',         # Replacement character
))


def main() -> int:
    out = Path(__file__).resolve().parent.parent / 'web' / 'fonts'
    out.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory() as tmp:
        variable = Path(tmp) / 'NotoSansKR-variable.ttf'
        print(f'fetching {SOURCE}')
        urllib.request.urlretrieve(SOURCE, variable)
        print(f'  {variable.stat().st_size / 1e6:.1f} MB')

        urllib.request.urlretrieve(LICENSE, out / 'OFL.txt')

        total = 0
        for weight in WEIGHTS:
            static = Path(tmp) / f'static-{weight}.ttf'
            run([
                sys.executable, '-m', 'fontTools.varLib.instancer',
                str(variable), f'wght={weight}',
                '--output', str(static),
            ])

            target = out / f'NotoSansKR-{weight}.ttf'
            run([
                sys.executable, '-m', 'fontTools.subset', str(static),
                f'--unicodes={UNICODES}',
                '--layout-features=*',
                '--name-IDs=*',
                '--notdef-outline',
                '--no-hinting',
                f'--output-file={target}',
            ])

            size = target.stat().st_size
            total += size
            print(f'  {target.name}: {size / 1e6:.2f} MB')

    print(f'total {total / 1e6:.2f} MB in {out}')
    return 0


def run(cmd: list[str]) -> None:
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL)


if __name__ == '__main__':
    raise SystemExit(main())
