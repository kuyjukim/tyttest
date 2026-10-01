#!/usr/bin/env bash
# Builds the demo entrypoint for the web and stages it as a self-contained
# bundle that can be served from a subdirectory of some other page.
#
# Three things make the default `flutter build web` output unsuitable for that,
# and each is undone here rather than worked around at serve time:
#
#   1. CanvasKit is fetched from gstatic unless --no-web-resources-cdn is
#      passed. This container has no route to gstatic, and neither does a
#      viewer behind a strict CSP.
#   2. The bootstrap registers a service worker. A service worker needs its own
#      scope at the origin root; from a subdirectory it either fails or caches
#      the wrong thing, so the registration is removed outright.
#   3. <base href="/"> assumes the origin root.
#
# Everything the web build never requests is dropped: the skwasm renderer (the
# build above is canvaskit), symbol maps, and AssetManifest.bin (web reads the
# .json twin).
#
# Usage: tool/stage_web_demo.sh <output-directory>
set -euo pipefail

out=${1:?usage: stage_web_demo.sh <output-directory>}
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$here"

export PATH="/opt/fl/flutter/bin:$PATH"

# The Korean face the demo loads at startup. Generated rather than committed,
# so a fresh checkout builds it once here.
if [[ ! -f web/fonts/NotoSansKR-400.ttf ]]; then
  tool/make_demo_fonts.py
fi

flutter build web --release --no-web-resources-cdn -t lib/demo_main.dart

rm -rf -- "$out"
mkdir -p -- "$(dirname -- "$out")"
cp -r build/web "$out"

cd -- "$out"
rm -f canvaskit/skwasm*
find . -name '*.symbols' -delete
rm -f flutter_service_worker.js .last_build_id
rm -f assets/AssetManifest.bin
rm -rf assets/shaders   # InkRipple means no ink_sparkle.frag is ever fetched
rmdir assets/shaders 2>/dev/null || true

# Drop the service-worker registration and the source map hint, keeping the
# rest of the generated bootstrap byte for byte.
python3 - flutter_bootstrap.js <<'PY'
import re, sys
p = sys.argv[1]
src = open(p, encoding='utf-8').read()
src = src.replace('//# sourceMappingURL=flutter.js.map\n', '')
src, n = re.subn(
    r'_flutter\.loader\.load\(\{.*?\}\);',
    '_flutter.loader.load();',
    src,
    flags=re.S,
)
if n != 1:
    raise SystemExit(f'expected one _flutter.loader.load call, patched {n}')
open(p, 'w', encoding='utf-8').write(src)
PY

cat > index.html <<'HTML'
<!DOCTYPE html>
<html lang="ko">
<head>
  <!-- Relative: the bundle is served from a subdirectory, not the origin root. -->
  <base href="./">
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  <meta name="description" content="봉투 예산 가계부 웹 데모">
  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="default">
  <meta name="apple-mobile-web-app-title" content="봉투가계부">
  <link rel="apple-touch-icon" href="icons/Icon-192.png">
  <link rel="icon" type="image/png" href="favicon.png">
  <title>봉투가계부</title>
  <link rel="manifest" href="manifest.json">
</head>
<!-- The paper ground, so the gap before first paint is not a white flash. -->
<body style="margin:0;background:#FBF8F3">
  <script src="flutter_bootstrap.js" async></script>
</body>
</html>
HTML

python3 - manifest.json <<'PY'
import json, sys
p = sys.argv[1]
m = json.load(open(p, encoding='utf-8'))
m['name'] = '봉투가계부'
m['short_name'] = '봉투가계부'
m['description'] = '봉투 예산 가계부 웹 데모'
m['background_color'] = '#FBF8F3'
m['theme_color'] = '#C46C31'
json.dump(m, open(p, 'w', encoding='utf-8'), ensure_ascii=False, indent=4)
PY

echo "staged $(du -sh . | cut -f1) in $out"
