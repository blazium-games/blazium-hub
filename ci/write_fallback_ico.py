#!/usr/bin/env python3
"""Write a minimal valid .ico (solid tile) when ImageMagick SVG convert is unavailable."""

from __future__ import annotations

import struct
import sys
import zlib
from pathlib import Path


def _png_rgba(size: int, rgba: tuple[int, int, int, int]) -> bytes:
    w = h = size
    raw = b""
    row = bytes(rgba) * w
    for _ in range(h):
        raw += b"\x00" + row
    comp = zlib.compress(raw, 9)

    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", comp) + chunk(b"IEND", b"")


def write_ico(path: Path) -> None:
    # Blue Blazium-ish tile; sizes Inno accepts.
    sizes = (16, 32, 48, 256)
    images = [_png_rgba(s, (0x1E, 0x88, 0xE5, 0xFF)) for s in sizes]
    count = len(images)
    # ICONDIR + ICONDIRENTRY * count
    offset = 6 + 16 * count
    entries = b""
    data = b""
    for size, png in zip(sizes, images):
        w = 0 if size >= 256 else size
        h = 0 if size >= 256 else size
        entries += struct.pack("<BBBBHHII", w, h, 0, 0, 1, 32, len(png), offset + len(data))
        data += png
    path.write_bytes(struct.pack("<HHH", 0, 1, count) + entries + data)


def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {sys.argv[0]} <out.ico>", file=sys.stderr)
        return 2
    out = Path(sys.argv[1])
    out.parent.mkdir(parents=True, exist_ok=True)
    write_ico(out)
    print(f"wrote {out} ({out.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
