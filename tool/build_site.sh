#!/usr/bin/env bash
# Assembles docs/, the static site GitHub Pages serves, from Grove's store
# assets. Run it after changing apps/grove/store/landing.html or the
# screenshots, and commit what it writes.
#
#   tool/build_site.sh
#
# Pages is configured once, by hand, at
# Settings -> Pages -> Source: Deploy from a branch -> main / docs.
# The site then lives at https://<owner>.github.io/tyttest/.
set -euo pipefail

cd "$(dirname "$0")/.."

SITE=docs
STORE=apps/grove/store
# Where the site will be served from. Open Graph needs absolute URLs, so a
# relative path is not enough for the card that appears when the link is
# pasted into a chat.
BASE="${SITE_BASE:-https://kuyjukim.github.io/tyttest}"

rm -rf "$SITE"
mkdir -p "$SITE/shots"

cp "$STORE/icon-512.png"               "$SITE/icon.png"
cp "$STORE/screenshots/ko-1-focus.png" "$SITE/shots/focus.png"
cp "$STORE/screenshots/ko-2-garden.png" "$SITE/shots/garden.png"
cp "$STORE/screenshots/ko-3-stats.png" "$SITE/shots/stats.png"
cp "$STORE/screenshots/ko-5-dark.png"  "$SITE/shots/dark.png"

# landing.html is written as an artifact body: no doctype, no <head>, because
# the artifact host wraps it in one. A real web server does not, so the
# wrapper is reproduced here - including the small reset the host applies, or
# the page renders in quirks mode with browser defaults.
DESC='타이머를 맞추면 나무가 자랍니다. 끝까지 하면 정원에 남고, 중간에 그만두면 시듭니다. 구독 없이 한 번만 결제하는 집중 타이머.'

{
  cat <<HEAD
<!doctype html>
<html lang="ko">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="description" content="$DESC">
<meta name="color-scheme" content="light dark">
<link rel="icon" href="icon.png">
<link rel="apple-touch-icon" href="icon.png">
<meta property="og:type" content="website">
<meta property="og:site_name" content="그로브">
<meta property="og:title" content="그로브 — 끝낸 세션만 나무로 남습니다">
<meta property="og:description" content="$DESC">
<meta property="og:image" content="$BASE/icon.png">
<meta property="og:url" content="$BASE/">
<meta property="og:locale" content="ko_KR">
<meta name="twitter:card" content="summary">
<style>
  :root {
    color-scheme: light;
    padding-top: env(safe-area-inset-top, 0px);
    padding-bottom: env(safe-area-inset-bottom, 0px);
  }
  body { margin: 0; font: 14px system-ui, sans-serif; background: #fafaf9; }
  img { max-width: 100%; }
  [hidden] { display: none !important; }
</style>
</head>
<body>
HEAD
  cat "$STORE/landing.html"
  printf '</body>\n</html>\n'
} > "$SITE/index.html"

# A second build of the same page as one file, with every image inlined.
# This is the copy to hand someone directly - open it from a USB stick, drop
# it on Netlify, attach it to a mail - because it has no folder next to it to
# lose. The screenshots are halved first: they ship at 1320x2868 for the App
# Store and render about 240 wide here, so full resolution would triple the
# file for nothing. Web fonts still come over the network; without one it
# falls back to the system face and is perfectly readable.
python3 - "$SITE" "$STORE" <<'PYTHON'
import base64, pathlib, subprocess, sys, tempfile

site, store = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
page = (site / 'index.html').read_text()

def data_uri(path):
    return 'data:image/png;base64,' + base64.b64encode(path.read_bytes()).decode()

with tempfile.TemporaryDirectory() as tmp:
    swaps = {'icon.png': data_uri(site / 'icon.png')}
    for name in ('focus', 'garden', 'stats', 'dark'):
        small = pathlib.Path(tmp) / f'{name}.png'
        subprocess.run(['tool/shrink_png.py', str(site / 'shots' / f'{name}.png'),
                        str(small), '2'], check=True, stdout=subprocess.DEVNULL)
        swaps[f'shots/{name}.png'] = data_uri(small)

for ref, uri in swaps.items():
    before = page
    page = page.replace(f'"{ref}"', f'"{uri}"')
    assert page != before, f'nothing referenced {ref}'

out = site / 'grove.html'
out.write_text(page)
print(f'wrote {out} ({out.stat().st_size // 1024} KB, self-contained)')
PYTHON

printf '%s\n' "wrote $SITE/ ($(du -sh "$SITE" | cut -f1))"
printf '%s\n' "serve locally with:  python3 -m http.server -d $SITE 8000"
