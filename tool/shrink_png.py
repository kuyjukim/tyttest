#!/usr/bin/env python3
"""Halves (or quarters, …) a PNG by box-averaging, with no dependencies.

The repository already decodes and writes PNGs by hand in make_icon.py, for
the same reason: this machine has no Pillow, and a build step that needs one
is a build step that stops working on somebody else's machine.

    tool/shrink_png.py in.png out.png 2

The output is RGB with no alpha, which is what the screenshots need: they are
opaque, and dropping the alpha channel is a quarter of the bytes for free.
"""
import struct
import sys
import zlib


def _decode(path):
    raw = open(path, 'rb').read()
    pos, idat, width, height, colour = 8, b'', None, None, None
    while pos < len(raw):
        length = struct.unpack('>I', raw[pos:pos + 4])[0]
        kind = raw[pos + 4:pos + 8]
        data = raw[pos + 8:pos + 8 + length]
        if kind == b'IHDR':
            width, height, depth, colour = struct.unpack('>IIBB', data[:10])
            if depth != 8:
                raise SystemExit(f'{path}: only 8-bit channels are supported')
        elif kind == b'IDAT':
            idat += data
        pos += 12 + length

    channels = {0: 1, 2: 3, 4: 2, 6: 4}.get(colour)
    if channels is None:
        raise SystemExit(f'{path}: palette PNGs are not supported')

    stream = zlib.decompress(idat)
    stride = width * channels
    rows, previous, offset = [], bytes(stride), 0
    for _ in range(height):
        filter_type = stream[offset]
        offset += 1
        line = bytearray(stream[offset:offset + stride])
        offset += stride
        if filter_type == 1:
            for x in range(channels, stride):
                line[x] = (line[x] + line[x - channels]) & 255
        elif filter_type == 2:
            for x in range(stride):
                line[x] = (line[x] + previous[x]) & 255
        elif filter_type == 3:
            for x in range(stride):
                left = line[x - channels] if x >= channels else 0
                line[x] = (line[x] + ((left + previous[x]) >> 1)) & 255
        elif filter_type == 4:
            for x in range(stride):
                a = line[x - channels] if x >= channels else 0
                b = previous[x]
                c = previous[x - channels] if x >= channels else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                nearest = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[x] = (line[x] + nearest) & 255
        rows.append(bytes(line))
        previous = line
    return width, height, channels, rows


def _encode(path, width, height, rows):
    def chunk(kind, data):
        return (struct.pack('>I', len(data)) + kind + data
                + struct.pack('>I', zlib.crc32(kind + data) & 0xFFFFFFFF))

    # Try both filters that are worth trying and keep whichever compresses
    # smaller. Which one wins is not predictable from the image: Up exploits
    # the long vertical runs of a UI screenshot, None leaves deflate a plainer
    # stream to work with, and on these screenshots None has won by 20%.
    flat = b''.join(b'\x00' + row for row in rows)

    up = bytearray()
    previous = bytes(width * 3)
    for row in rows:
        up.append(2)
        up += bytes((row[i] - previous[i]) & 255 for i in range(len(row)))
        previous = row

    best = min((zlib.compress(candidate, 9) for candidate in (flat, bytes(up))),
               key=len)
    open(path, 'wb').write(
        b'\x89PNG\r\n\x1a\n'
        + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0))
        + chunk(b'IDAT', best)
        + chunk(b'IEND', b''))


def shrink(src, dst, factor):
    width, height, channels, rows = _decode(src)
    out_w, out_h = width // factor, height // factor
    area = factor * factor
    out = []
    for y in range(out_h):
        block = rows[y * factor:(y + 1) * factor]
        line = bytearray()
        for x in range(out_w):
            r = g = b = 0
            for row in block:
                for dx in range(factor):
                    o = (x * factor + dx) * channels
                    if channels >= 3:
                        r += row[o]
                        g += row[o + 1]
                        b += row[o + 2]
                    else:
                        r += row[o]
                        g += row[o]
                        b += row[o]
            line += bytes((r // area, g // area, b // area))
        out.append(bytes(line))
    _encode(dst, out_w, out_h, out)
    return out_w, out_h


if __name__ == '__main__':
    if len(sys.argv) != 4:
        raise SystemExit(__doc__)
    w, h = shrink(sys.argv[1], sys.argv[2], int(sys.argv[3]))
    print(f'{sys.argv[2]} {w}x{h}')
