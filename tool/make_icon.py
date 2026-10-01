#!/usr/bin/env python3
"""Renders an app icon master PNG with no third-party dependencies.

Why by hand rather than with a design tool: the icon has to be regenerable
from source in CI and reviewable as a diff. Everything here is zlib (for the
PNG container) and integer span fills, so it runs anywhere Python does.

Anti-aliasing comes from rendering at 4x and letting the downsample do the
averaging, which is both simpler and better than trying to compute edge
coverage analytically.
"""
from __future__ import annotations

import math
import struct
import sys
import zlib

SUPERSAMPLE = 4
SIZE = 1024
W = H = SIZE * SUPERSAMPLE


class Canvas:
    def __init__(self, width: int, height: int) -> None:
        self.w = width
        self.h = height
        self.stride = width * 3
        self.buf = bytearray(self.stride * height)

    def vertical_gradient(self, top: tuple[int, int, int],
                          bottom: tuple[int, int, int]) -> None:
        for y in range(self.h):
            t = y / (self.h - 1)
            row = bytes(
                round(top[i] + (bottom[i] - top[i]) * t) for i in range(3)
            ) * self.w
            self.buf[y * self.stride:(y + 1) * self.stride] = row

    def _span(self, y: int, x_from: float, x_to: float,
              colour: tuple[int, int, int]) -> None:
        if y < 0 or y >= self.h:
            return
        a = max(0, int(round(x_from)))
        b = min(self.w, int(round(x_to)))
        if b <= a:
            return
        base = y * self.stride
        self.buf[base + a * 3:base + b * 3] = bytes(colour) * (b - a)

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
            raw += self.buf[y * self.stride:(y + 1) * self.stride]

        def chunk(tag: bytes, payload: bytes) -> bytes:
            return (
                struct.pack('>I', len(payload))
                + tag
                + payload
                + struct.pack('>I', zlib.crc32(tag + payload) & 0xFFFFFFFF)
            )

        header = struct.pack('>IIBBBBB', self.w, self.h, 8, 2, 0, 0, 0)
        with open(path, 'wb') as handle:
            handle.write(b'\x89PNG\r\n\x1a\n')
            handle.write(chunk(b'IHDR', header))
            handle.write(chunk(b'IDAT', zlib.compress(bytes(raw), 9)))
            handle.write(chunk(b'IEND', b''))


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
    s = SUPERSAMPLE
    canvas = Canvas(W, H)
    canvas.vertical_gradient((0xC4, 0x6C, 0x31), (0x8C, 0x43, 0x1E))

    cream = (0xF9, 0xF1, 0xE2)
    ink = (0xB4, 0x5E, 0x2A)
    faint = (0xE8, 0xD8, 0xC2)

    # The card.
    canvas.rounded_rect(196 * s, 236 * s, 828 * s, 788 * s, 92 * s, cream)

    # Three bars, each on its own track, filling less each time: the shape of
    # a month going on.
    left = 272
    right = 752
    track = right - left
    bar_height = 76
    radius = bar_height / 2
    tops = (348, 474, 600)
    fractions = (0.92, 0.58, 0.31)

    for top, fraction in zip(tops, fractions):
        canvas.rounded_rect(
            left * s, top * s, right * s, (top + bar_height) * s,
            radius * s, faint,
        )
        filled = left + track * fraction
        canvas.rounded_rect(
            left * s, top * s, filled * s, (top + bar_height) * s,
            radius * s, ink,
        )

    return canvas


if __name__ == '__main__':
    out = sys.argv[1] if len(sys.argv) > 1 else 'icon-master.png'
    icon = ledger_icon()
    icon.write_png(out)
    print(f'wrote {out} at {W}x{H}')
