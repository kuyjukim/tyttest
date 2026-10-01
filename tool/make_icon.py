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

    def arc(self, cx: float, cy: float, radius: float, start: float,
            end: float, width: float,
            colour: tuple[int, int, int] | None) -> None:
        """A rounded arc, with angles in radians clockwise from straight up.

        Stepped discs rather than a stroked path: there is no path machinery
        here, and at 4x supersample the seam between two discs a third of a
        pixel apart is finer than the downsample can see. Stepping by a third
        of the stroke width would still band on the outer edge, so the step is
        taken in arc length.
        """
        if radius <= 0 or width <= 0:
            return
        step = max(1, int(abs(end - start) * radius / 1.5))
        for i in range(step + 1):
            angle = start + (end - start) * i / step
            self.disc(
                cx + math.sin(angle) * radius,
                cy - math.cos(angle) * radius,
                width / 2,
                colour,
            )

    def disc(self, cx: float, cy: float, r: float,
             colour: tuple[int, int, int] | None) -> None:
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


def _adaptive_scale(extent: float) -> float:
    """How far a mark shrinks to clear an adaptive icon's mask.

    The safe zone is a circle, so what has to fit inside it is the diameter
    of the mark's bounding circle - for a rectangle that is its diagonal, not
    its width, which would leave the corners to be shaved off by a round mask.
    """
    return SAFE_ZONE * SIZE / extent


# The diagonal of Ledger's card, and the diameter of Grove's dial.
LEDGER_EXTENT = math.hypot(CARD[2] - CARD[0], CARD[3] - CARD[1])


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
    _draw_mark(canvas, _adaptive_scale(LEDGER_EXTENT), card=CREAM, track=FAINT, fill=INK)
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
        _adaptive_scale(LEDGER_EXTENT),
        card=(0, 0, 0),
        erase=frozenset({'fill'}),
    )
    return canvas


# ---------------------------------------------------------------- Grove

# Deep pine, because the whole screen is a forest floor and because it has to
# be nothing like Ledger's terracotta on the same home screen.
PINE_TOP = (0x2F, 0x6B, 0x4A)
PINE_BOTTOM = (0x1B, 0x43, 0x30)

BARK = (0xF3, 0xF7, 0xEA)        # the tree, drawn light so it reads on pine
DIAL_TRACK = (0x44, 0x89, 0x63)  # the unfilled arc: pine, one step lighter
DIAL_FILL = (0xA8, 0xD9, 0x8A)   # leaf green, the app's own accent

# The dial, in the master's 1024-unit space. The app draws a 270° arc with the
# gap at the bottom, and the icon draws the same one: a session in progress is
# what the app looks like, so it is what the icon should be.
DIAL_RADIUS = 332
DIAL_STROKE = 58
DIAL_SWEEP = math.pi * 1.5
DIAL_START = -DIAL_SWEEP / 2
DIAL_FRACTION = 0.68

GROVE_EXTENT = (DIAL_RADIUS + DIAL_STROKE / 2) * 2

# The tree. Three levels of branching, which is what the app's own painter
# does; a lollipop canopy would read as any tree app, and this reads as this
# one.
# The tree sits inside the ring with air around it, so the two read as one
# composition rather than as a collision. The spread is kept near the app's
# own species parameters (0.34-0.52 rad); wider than that and the outer tips
# cross the arc. The taper is deliberately gentle - at a 60-pixel home screen
# icon, three levels of 0.64 taper puts the last twigs under a pixel wide.
TRUNK_BASE = 722          # where the trunk meets the gap in the dial
TRUNK_LENGTH = 190
TRUNK_WIDTH = 46
BRANCH_SPREAD = 0.44      # radians off the parent, each way
BRANCH_SHORTEN = 0.70
BRANCH_THIN = 0.74
BRANCH_DEPTH = 3

# Drawn bare, which was a decision rather than an omission. Discs at the tips
# were tried as foliage and read as pins on a board - eight dots on eight
# twigs is a ball-and-stick diagram, and enlarging them until they merge into
# a canopy buries the branching that makes this mark not every other focus
# app's tree. Bare, upright, symmetrical and cream inside a growing green dial
# does not read as the withered tree; that one is grey and drooping.


def _draw_grove(canvas: Canvas, scale: float, *,
                track: tuple[int, int, int] | None = None,
                fill: tuple[int, int, int] | None = None,
                tree: tuple[int, int, int] | None = None,
                erase: frozenset[str] = frozenset()) -> None:
    """Draws the dial and the tree, scaled about the centre of the canvas."""
    unit = canvas.w / SIZE
    centre = SIZE / 2

    def at(v: float) -> float:
        return (centre + (v - centre) * scale) * unit

    def length(v: float) -> float:
        return v * scale * unit

    if track is not None or 'track' in erase:
        canvas.arc(
            at(centre), at(centre), length(DIAL_RADIUS),
            DIAL_START, DIAL_START + DIAL_SWEEP, length(DIAL_STROKE),
            None if 'track' in erase else track,
        )
    if fill is not None or 'fill' in erase:
        canvas.arc(
            at(centre), at(centre), length(DIAL_RADIUS),
            DIAL_START, DIAL_START + DIAL_SWEEP * DIAL_FRACTION,
            length(DIAL_STROKE),
            None if 'fill' in erase else fill,
        )

    if tree is None and 'tree' not in erase:
        return
    colour = None if 'tree' in erase else tree

    def branch(x: float, y: float, angle: float, long: float,
               wide: float, depth: int) -> None:
        tip = (x + math.sin(angle) * long, y - math.cos(angle) * long)
        canvas.thick_line((x, y), tip, wide, colour)
        # A disc at each joint, or the corner between two branches is a notch.
        canvas.disc(tip[0], tip[1], wide / 2, colour)
        if depth == 0:
            return
        for side in (-BRANCH_SPREAD, BRANCH_SPREAD):
            branch(tip[0], tip[1], angle + side, long * BRANCH_SHORTEN,
                   wide * BRANCH_THIN, depth - 1)

    branch(
        at(centre), at(TRUNK_BASE), 0.0,
        length(TRUNK_LENGTH), length(TRUNK_WIDTH), BRANCH_DEPTH,
    )


def grove_icon() -> Canvas:
    """A tree growing inside the focus dial.

    The running screen of the app is literally this: a 270° dial with the
    session's tree in the middle of it. An icon of a tree alone would be every
    other focus app, and one of a timer alone would be a clock - the pair is
    what makes it this app, and it is also the first screenshot.
    """
    canvas = Canvas(W, H)
    canvas.vertical_gradient(PINE_TOP, PINE_BOTTOM)
    _draw_grove(canvas, 1.0, track=DIAL_TRACK, fill=DIAL_FILL, tree=BARK)
    return canvas


def grove_foreground() -> Canvas:
    canvas = Canvas(W, H, alpha=True)
    _draw_grove(canvas, _adaptive_scale(GROVE_EXTENT),
                track=DIAL_TRACK, fill=DIAL_FILL, tree=BARK)
    return canvas


def grove_monochrome() -> Canvas:
    """The silhouette Android 13 tints.

    Only the tree. The dial is a ring of even weight, and tinted flat it
    becomes a plain circle around a shape - which is what a hundred other
    monochrome icons already are. The branching alone is the distinctive part.
    """
    canvas = Canvas(W, H, alpha=True)
    _draw_grove(canvas, _adaptive_scale(GROVE_EXTENT), tree=(0, 0, 0))
    return canvas


# Each app's three layers, plus the two colours its Android background
# gradient is filled with. make_app_icons.sh reads the colours from here
# rather than carrying its own copy of them.
APPS = {
    'ledger': {
        'master': ledger_icon,
        'foreground': ledger_foreground,
        'monochrome': ledger_monochrome,
        'background': (TERRACOTTA_TOP, TERRACOTTA_BOTTOM),
    },
    'grove': {
        'master': grove_icon,
        'foreground': grove_foreground,
        'monochrome': grove_monochrome,
        'background': (PINE_TOP, PINE_BOTTOM),
    },
}

LAYERS = ('master', 'foreground', 'monochrome')


def main(argv: list[str]) -> int:
    # `--background <app>` prints the two gradient colours for the Android
    # background drawable, so that the shell script does not keep a second
    # copy of them to drift out of step with these.
    if len(argv) > 2 and argv[1] == '--background':
        app = APPS.get(argv[2])
        if app is None:
            print(f'unknown app {argv[2]!r}', file=sys.stderr)
            return 2
        print(' '.join('#%02X%02X%02X' % c for c in app['background']))
        return 0

    out = argv[1] if len(argv) > 1 else 'icon-master.png'
    layer = argv[2] if len(argv) > 2 else 'master'
    name = argv[3] if len(argv) > 3 else 'ledger'

    if layer not in LAYERS:
        print(f'unknown layer {layer!r}; expected one of '
              + ', '.join(LAYERS), file=sys.stderr)
        return 2
    app = APPS.get(name)
    if app is None:
        print(f'no icon is drawn for {name!r}; known: '
              + ', '.join(sorted(APPS)), file=sys.stderr)
        return 2

    app[layer]().write_png(out)
    print(f'wrote {out} at {W}x{H} ({name} {layer})')
    return 0


if __name__ == '__main__':
    raise SystemExit(main(sys.argv))
