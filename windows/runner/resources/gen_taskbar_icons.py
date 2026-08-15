"""Generate 16/32px taskbar toolbar ICO glyphs."""

from __future__ import annotations

import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def _blank(size: int) -> list[list[tuple[int, int, int, int]]]:
    return [[(0, 0, 0, 0) for _ in range(size)] for _ in range(size)]


def _plot(px, x: int, y: int, a: float = 1.0) -> None:
    size = len(px)
    if 0 <= x < size and 0 <= y < size and a > 0:
        src_a = int(255 * min(1.0, a))
        r, g, b, old = px[y][x]
        out_a = src_a + old * (255 - src_a) // 255
        px[y][x] = (255, 255, 255, out_a)


def _fill_triangle(px, ax, ay, bx, by, cx, cy) -> None:
    size = len(px)
    minx, maxx = int(min(ax, bx, cx)), int(max(ax, bx, cx))
    miny, maxy = int(min(ay, by, cy)), int(max(ay, by, cy))
    den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
    if abs(den) < 1e-6:
        return
    for y in range(miny, maxy + 1):
        for x in range(minx, maxx + 1):
            if not (0 <= x < size and 0 <= y < size):
                continue
            w1 = ((by - cy) * (x - cx) + (cx - bx) * (y - cy)) / den
            w2 = ((cy - ay) * (x - cx) + (ax - cx) * (y - cy)) / den
            w3 = 1 - w1 - w2
            if w1 >= -0.02 and w2 >= -0.02 and w3 >= -0.02:
                edge = min(w1, w2, w3)
                _plot(px, x, y, 1 if edge > 0.04 else 0.45)


def _fill_rect(px, x0, y0, x1, y1) -> None:
    for y in range(int(y0), int(y1) + 1):
        for x in range(int(x0), int(x1) + 1):
            _plot(px, x, y)


def _heart(px, filled: bool) -> None:
    size = len(px)
    for y in range(size):
        for x in range(size):
            nx = (x + 0.5) / size * 2 - 1
            ny = 1 - (y + 0.5) / size * 2
            nx *= 1.18
            ny = ny * 1.18 - 0.12
            value = (nx * nx + ny * ny - 0.42) ** 3 - nx * nx * (ny + 0.08) ** 3
            if filled:
                if value <= 0:
                    _plot(px, x, y)
            else:
                if -0.035 <= value <= 0:
                    _plot(px, x, y)


def _draw(kind: str, size: int) -> list[list[tuple[int, int, int, int]]]:
    px = _blank(size)
    s = size / 32
    if kind == "prev":
        _fill_rect(px, 6 * s, 8 * s, 9 * s, 23 * s)
        _fill_triangle(px, 22 * s, 7 * s, 22 * s, 24 * s, 10 * s, 15.5 * s)
    elif kind == "next":
        _fill_rect(px, 22 * s, 8 * s, 25 * s, 23 * s)
        _fill_triangle(px, 9 * s, 7 * s, 9 * s, 24 * s, 21 * s, 15.5 * s)
    elif kind == "play":
        _fill_triangle(px, 10 * s, 6 * s, 10 * s, 25 * s, 24 * s, 15.5 * s)
    elif kind == "pause":
        _fill_rect(px, 8 * s, 7 * s, 13 * s, 24 * s)
        _fill_rect(px, 18 * s, 7 * s, 23 * s, 24 * s)
    elif kind == "like":
        _heart(px, False)
    elif kind == "liked":
        _heart(px, True)
    return px


def _bmp(px) -> bytes:
    size = len(px)
    xor = bytearray()
    for y in range(size - 1, -1, -1):
        for x in range(size):
            r, g, b, a = px[y][x]
            xor += bytes((b, g, r, a))
    row = ((size + 31) // 32) * 4
    mask = bytearray(row * size)
    header = struct.pack(
        "<IiiHHIIiiII",
        40,
        size,
        size * 2,
        1,
        32,
        0,
        len(xor),
        0,
        0,
        0,
        0,
    )
    return header + xor + mask


def _ico(images: list[bytes], sizes: list[int]) -> bytes:
    count = len(images)
    header = struct.pack("<HHH", 0, 1, count)
    offset = 6 + 16 * count
    entries = b""
    payload = b""
    for data, size in zip(images, sizes):
        entries += struct.pack("<BBBBHHII", size, size, 0, 0, 1, 32, len(data), offset)
        payload += data
        offset += len(data)
    return header + entries + payload


def write(kind: str, name: str) -> None:
    images = []
    sizes = (16, 32)
    for size in sizes:
        images.append(_bmp(_draw(kind, size)))
    path = ROOT / name
    path.write_bytes(_ico(images, list(sizes)))
    print(path)


if __name__ == "__main__":
    write("prev", "tb_prev.ico")
    write("play", "tb_play.ico")
    write("pause", "tb_pause.ico")
    write("next", "tb_next.ico")
    write("like", "tb_like.ico")
    write("liked", "tb_liked.ico")
