#!/usr/bin/env python3
"""Renders an app icon master PNG with no third-party dependencies.

Why by hand rather than with a design tool: the icon has to be regenerable
from source in CI and reviewable as a diff. Everything here is zlib (for the
PNG container) and integer span fills, so it runs anywhere Python does.

Anti-aliasing comes from rendering at 4x and letting the downsample do the
averaging, which is both simpler and better than trying to compute edge
coverage analytically.

Three layers come out of here. The master is the whole icon, flattened, for
iOS and for the two Android releases below API 26 that minSdk 24 admits. The
other two are the halves an Android adaptive icon is made of: a foreground
drawn on transparency and sized to the safe zone, and a monochrome
silhouette for Android 13's themed icons. The background half is not here
at all - it is a flat gradient, which an
Android shape drawable expresses exactly and at any size.
"""
from __future__ import annotations

import math
import struct
import sys
import zlib

SUPERSAMPLE = 4
SIZE = 1024
W = H = SIZE * SUPERSAMPLE

# An adaptive icon is a 108dp canvas of which only the central 66dp circle is
# guaranteed to survive the launcher's mask. The card is a rectangle, so what
# has to fit is its diagonal, not its width.
SAFE_ZONE = 66 / 108


class Canvas:
    def __init__(self, width: int, height: int, *, alpha: bool = False) -> None:
        self.w = width
        self.h = height
        self.stride = width * 3
        self.buf = bytearray(self.stride * height)
        # Transparent everywhere until something is drawn. Only the layers
        # that need to be composited carry this; the flattened master does
        # not, and an icon with an alpha channel is one of the things App
        # Store Connect rejects after upload.
        self.alpha = bytearray(width * height) if alpha else None

    def vertical_gradient(self, top: tuple[int, int, int],
                          bottom: tuple[int, int, int]) -> None:
        for y in range(self.h):
            t = y / (self.h - 1)
            row = bytes(
                round(top[i] + (bottom[i] - top[i]) * t) for i in range(3)
            ) * self.w
            self.buf[y * self.stride:(y + 1) * self.stride] = row

    def _span(self, y: int, x_from: float, x_to: float,
              colour: tuple[int, int, int] | None) -> None:
        if y < 0 or y >= self.h:
            return
        a = max(0, int(round(x_from)))
        b = min(self.w, int(round(x_to)))
        if b <= a:
            return
        # A null colour erases: how the bars are knocked out of the
        # monochrome silhouette, which is tinted wherever it is opaque.
        if colour is not None:
            base = y * self.stride
            self.buf[base + a * 3:base + b * 3] = bytes(colour) * (b - a)
        if self.alpha is not None:
            row = y * self.w
            self.alpha[row + a:row + b] = bytes(
                [0 if colour is None else 255]
            ) * (b - a)

    def rounded_rect(self, x0: float, y0: float, x1: float, y1: float,
                     radius: float, colour: tuple[int, int, int]) -> None:
        r = min(radius, (x1 - x0) / 2, (y1 - y0) / 2)
        for y in range(int(math.floor(y0)), int(math.ceil(y1))):
            cy = y + 0.5
            if cy < y0 or cy > y1:
                continue
            if cy < y0 + r:
                dy = (y0 + r) - cy
            elif cy > y1 - r:
                dy = cy - (y1 - r)
            else:
                dy = 0.0
            if dy <= 0:
                self._span(y, x0, x1, colour)
                continue
            if dy >= r:
                continue
            dx = math.sqrt(max(r * r - dy * dy, 0.0))
            self._span(y, x0 + r - dx, x1 - r + dx, colour)

    def polygon(self, points: list[tuple[float, float]],
                colour: tuple[int, int, int]) -> None:
        """Scanline fill, even-odd rule."""
        if len(points) < 3:
            return
        top = max(0, int(math.floor(min(p[1] for p in points))))
        bottom = min(self.h, int(math.ceil(max(p[1] for p in points))))
        for y in range(top, bottom):
            cy = y + 0.5
            crossings: list[float] = []
            for i in range(len(points)):
                ax, ay = points[i]
                bx, by = points[(i + 1) % len(points)]
                if ay == by:
                    continue
                if (ay <= cy < by) or (by <= cy < ay):
                    crossings.append(ax + (cy - ay) * (bx - ax) / (by - ay))
            crossings.sort()
            for i in range(0, len(crossings) - 1, 2):
                self._span(y, crossings[i], crossings[i + 1], colour)

    def thick_line(self, a: tuple[float, float], b: tuple[float, float],
                   width: float, colour: tuple[int, int, int]) -> None:
        """A segment with square ends, as a quad."""
        dx, dy = b[0] - a[0], b[1] - a[1]
        length = math.hypot(dx, dy)
        if length == 0:
            return
        nx, ny = -dy / length * width / 2, dx / length * width / 2
        self.polygon(
            [
                (a[0] + nx, a[1] + ny),
                (b[0] + nx, b[1] + ny),
                (b[0] - nx, b[1] - ny),
                (a[0] - nx, a[1] - ny),
            ],
            colour,
        )

    def disc(self, cx: float, cy: float, r: float,
             colour: tuple[int, int, int]) -> None:
        for y in range(int(cy - r), int(cy + r) + 1):
            dy = (y + 0.5) - cy
            if abs(dy) > r:
                continue
            dx = math.sqrt(r * r - dy * dy)
            self._span(y, cx - dx, cx + dx, colour)

    def write_png(self, path: str) -> None:
        raw = bytearray()
        for y in range(self.h):
            raw.append(0)  # filter type 0, no prediction
            if self.alpha is None:
                raw += self.buf[y * self.stride:(y + 1) * self.stride]
                continue
            row = self.buf[y * self.stride:(y + 1) * self.stride]
            band = self.alpha[y * self.w:(y + 1) * self.w]
            for x in range(self.w):
                raw += row[x * 3:x * 3 + 3]
                raw.append(band[x])

        def chunk(tag: bytes, payload: bytes) -> bytes:
            return (
                struct.pack('>I', len(payload))
                + tag
                + payload
                + struct.pack('>I', zlib.crc32(tag + payload) & 0xFFFFFFFF)
            )

        colour_type = 2 if self.alpha is None else 6
        header = struct.pack(
            '>IIBBBBB', self.w, self.h, 8, colour_type, 0, 0, 0
        )
        with open(path, 'wb') as handle:
            handle.write(b'\x89PNG\r\n\x1a\n')
            handle.write(chunk(b'IHDR', header))
            handle.write(chunk(b'IDAT', zlib.compress(bytes(raw), 9)))
            handle.write(chunk(b'IEND', b''))


# The terracotta the background half is filled with, and the ink inside the
# card. Shared with tool/make_app_icons.sh, which writes the same two values
# into the Android gradient drawable.
TERRACOTTA_TOP = (0xC4, 0x6C, 0x31)
TERRACOTTA_BOTTOM = (0x8C, 0x43, 0x1E)

CREAM = (0xF9, 0xF1, 0xE2)
INK = (0xB4, 0x5E, 0x2A)
FAINT = (0xE8, 0xD8, 0xC2)

# The card and its three bars, in the master's 1024-unit coordinates.
CARD = (196, 236, 828, 788)
CARD_RADIUS = 92
BAR_LEFT, BAR_RIGHT = 272, 752
BAR_HEIGHT = 76
BAR_TOPS = (348, 474, 600)
BAR_FILL = (0.92, 0.58, 0.31)


def _draw_mark(canvas: Canvas, scale: float, *,
               card: tuple[int, int, int] | None = None,
               track: tuple[int, int, int] | None = None,
               fill: tuple[int, int, int] | None = None,
               erase: frozenset[str] = frozenset()) -> None:
    """Draws the mark, scaled about the centre of a square canvas.

    Each of the three elements can be painted a colour, left out by passing
    nothing, or named in `erase` to cut a hole in whatever is under it. The
    monochrome layer is made entirely of holes, since the system tints the
    layer wherever it is opaque and a painted colour would be thrown away.
    """
    unit = canvas.w / SIZE
    centre = SIZE / 2

    def at(v: float) -> float:
        return (centre + (v - centre) * scale) * unit

    if card is not None or 'card' in erase:
        canvas.rounded_rect(
            at(CARD[0]), at(CARD[1]), at(CARD[2]), at(CARD[3]),
            CARD_RADIUS * scale * unit,
            None if 'card' in erase else card,
        )

    radius = BAR_HEIGHT / 2
    for top, fraction in zip(BAR_TOPS, BAR_FILL):
        if track is not None or 'track' in erase:
            canvas.rounded_rect(
                at(BAR_LEFT), at(top), at(BAR_RIGHT), at(top + BAR_HEIGHT),
                radius * scale * unit,
                None if 'track' in erase else track,
            )
        if fill is not None or 'fill' in erase:
            filled = BAR_LEFT + (BAR_RIGHT - BAR_LEFT) * fraction
            canvas.rounded_rect(
                at(BAR_LEFT), at(top), at(filled), at(top + BAR_HEIGHT),
                radius * scale * unit,
                None if 'fill' in erase else fill,
            )


def _adaptive_scale() -> float:
    """How far the mark shrinks to clear an adaptive icon's mask.

    The safe zone is a circle, so the card's diagonal is what has to fit
    inside it - not its width, which would leave the corners to be shaved
    off by a round mask.
    """
    width = CARD[2] - CARD[0]
    height = CARD[3] - CARD[1]
    diagonal = math.hypot(width, height)
    return SAFE_ZONE * SIZE / diagonal


def ledger_icon() -> Canvas:
    """Three budget bars on a card, on terracotta.

    The first attempt was an envelope, which is the right *concept* for
    envelope budgeting and the wrong *glyph*: an envelope reads as mail to
    everyone, and an icon that is mistaken for a mail client in a search
    result is worse than a plain one.

    This is what the app's own budget screen looks like - a stack of
    partially filled bars - which means the icon and the first screenshot
    agree with each other. Monochrome inside the card on purpose: three
    palette colours would be busier than a 60-pixel home-screen icon can
    carry.
    """
    canvas = Canvas(W, H)
    canvas.vertical_gradient(TERRACOTTA_TOP, TERRACOTTA_BOTTOM)
    _draw_mark(canvas, 1.0, card=CREAM, track=FAINT, fill=INK)
    return canvas


def ledger_foreground() -> Canvas:
    """The card alone, on transparency, sized to the adaptive safe zone.

    It is drawn smaller than the master's card looks, and that is correct:
    the launcher mask crops the 108dp canvas down to something near 72dp, so
    a mark that filled this canvas the way it fills the master would have its
    edges cut off on exactly the devices the layer exists for.
    """
    canvas = Canvas(W, H, alpha=True)
    _draw_mark(canvas, _adaptive_scale(), card=CREAM, track=FAINT, fill=INK)
    return canvas


def ledger_monochrome() -> Canvas:
    """The silhouette Android 13 tints for a themed home screen.

    The system paints one colour wherever this layer is opaque, so the mark
    has to be made of holes rather than of colours: a solid card with the
    *filled* part of each bar cut out of it. Cutting the whole track instead
    would leave three holes of equal length, which is a list icon and not
    this one.
    """
    canvas = Canvas(W, H, alpha=True)
    _draw_mark(
        canvas,
        _adaptive_scale(),
        card=(0, 0, 0),
        erase=frozenset({'fill'}),
    )
    return canvas


LAYERS = {
    'master': ledger_icon,
    'foreground': ledger_foreground,
    'monochrome': ledger_monochrome,
}


def main(argv: list[str]) -> int:
    out = argv[1] if len(argv) > 1 else 'icon-master.png'
    layer = argv[2] if len(argv) > 2 else 'master'
    if layer not in LAYERS:
        print(
            f'unknown layer {layer!r}; expected one of '
            + ', '.join(sorted(LAYERS)),
            file=sys.stderr,
        )
        return 2
    LAYERS[layer]().write_png(out)
    print(f'wrote {out} at {W}x{H} ({layer})')
    return 0


if __name__ == '__main__':
    raise SystemExit(main(sys.argv))
