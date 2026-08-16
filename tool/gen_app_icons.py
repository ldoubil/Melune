"""Generate Melune launcher icons from the equalizer-bar mark."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
MASTER = ROOT / "assets" / "icon" / "app_icon.png"
SIZE = 1024
BG = (13, 8, 26, 255)
BAR = (183, 148, 246, 255)
HEIGHTS = (0.42, 0.70, 1.00, 0.70, 0.42)


def _draw_bars(im: Image.Image, *, color: tuple[int, int, int, int], pad: int, inflate: int = 0) -> None:
    draw = ImageDraw.Draw(im)
    content = SIZE - 2 * pad
    gap_factor = 0.42
    bar_w = content / (5 + 4 * gap_factor)
    gap = bar_w * gap_factor
    for i, height_ratio in enumerate(HEIGHTS):
        width = bar_w + inflate * 2
        height = max(width, content * height_ratio + inflate * 2)
        x = pad + i * (bar_w + gap) - inflate
        y = (SIZE - height) / 2
        draw.rounded_rectangle(
            (x, y, x + width, y + height),
            radius=width / 2,
            fill=color,
        )


def _write_master() -> Image.Image:
    glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    _draw_bars(glow, color=(183, 148, 246, 140), pad=196, inflate=18)
    glow = glow.filter(ImageFilter.GaussianBlur(28))

    fg = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    _draw_bars(fg, color=BAR, pad=214)

    canvas = Image.new("RGBA", (SIZE, SIZE), BG)
    canvas.alpha_composite(glow)
    canvas.alpha_composite(fg)
    MASTER.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(MASTER, "PNG", optimize=True)
    return canvas


def _open_master() -> Image.Image:
    return _write_master()


def _fit(src: Image.Image, size: int) -> Image.Image:
    return src.resize((size, size), Image.Resampling.LANCZOS)


def _save_png(im: Image.Image, path: Path, *, alpha: bool) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if alpha:
        im.convert("RGBA").save(path, "PNG", optimize=True)
    else:
        im.convert("RGB").save(path, "PNG", optimize=True)


def _save_circle(im: Image.Image, path: Path, size: int) -> None:
    square = _fit(im, size).convert("RGBA")
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, size - 1, size - 1), fill=255)
    square.putalpha(mask)
    _save_png(square, path, alpha=True)


def _save_ico(src: Image.Image, path: Path, sizes: tuple[int, ...]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    src.convert("RGBA").save(
        path,
        format="ICO",
        sizes=[(size, size) for size in sizes],
    )


def main() -> None:
    src = _open_master()

    _save_png(_fit(src, 256), ROOT / "assets" / "tray" / "app_icon.png", alpha=True)
    _save_ico(
        src,
        ROOT / "assets" / "tray" / "app_icon.ico",
        (16, 24, 32, 48, 64, 128, 256),
    )
    _save_ico(
        src,
        ROOT / "windows" / "runner" / "resources" / "app_icon.ico",
        (16, 20, 24, 32, 40, 48, 64, 128, 256),
    )

    android = ROOT / "android" / "app" / "src" / "main" / "res"
    for density, launcher, foreground in (
        ("mdpi", 48, 108),
        ("hdpi", 72, 162),
        ("xhdpi", 96, 216),
        ("xxhdpi", 144, 324),
        ("xxxhdpi", 192, 432),
    ):
        mipmap = android / f"mipmap-{density}"
        _save_png(_fit(src, launcher), mipmap / "ic_launcher.png", alpha=False)
        _save_circle(src, mipmap / "ic_launcher_round.png", launcher)
        _save_png(
            _fit(src, foreground),
            mipmap / "ic_launcher_foreground.png",
            alpha=False,
        )

    ios = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    for name, size in (
        ("Icon-App-20x20@1x.png", 20),
        ("Icon-App-20x20@2x.png", 40),
        ("Icon-App-20x20@3x.png", 60),
        ("Icon-App-29x29@1x.png", 29),
        ("Icon-App-29x29@2x.png", 58),
        ("Icon-App-29x29@3x.png", 87),
        ("Icon-App-40x40@1x.png", 40),
        ("Icon-App-40x40@2x.png", 80),
        ("Icon-App-40x40@3x.png", 120),
        ("Icon-App-60x60@2x.png", 120),
        ("Icon-App-60x60@3x.png", 180),
        ("Icon-App-76x76@1x.png", 76),
        ("Icon-App-76x76@2x.png", 152),
        ("Icon-App-83.5x83.5@2x.png", 167),
        ("Icon-App-1024x1024@1x.png", 1024),
    ):
        _save_png(_fit(src, size), ios / name, alpha=False)

    macos = ROOT / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    for size in (16, 32, 64, 128, 256, 512, 1024):
        _save_png(_fit(src, size), macos / f"app_icon_{size}.png", alpha=False)

    web = ROOT / "web"
    _save_png(_fit(src, 32), web / "favicon.png", alpha=True)
    _save_png(_fit(src, 192), web / "icons" / "Icon-192.png", alpha=False)
    _save_png(_fit(src, 512), web / "icons" / "Icon-512.png", alpha=False)
    _save_png(_fit(src, 192), web / "icons" / "Icon-maskable-192.png", alpha=False)
    _save_png(_fit(src, 512), web / "icons" / "Icon-maskable-512.png", alpha=False)

    _save_png(_fit(src, 256), ROOT / "linux" / "melune.png", alpha=True)

    launch = (
        ROOT
        / "ios"
        / "Runner"
        / "Assets.xcassets"
        / "LaunchImage.imageset"
    )
    _save_png(_fit(src, 168), launch / "LaunchImage.png", alpha=True)
    _save_png(_fit(src, 336), launch / "LaunchImage@2x.png", alpha=True)
    _save_png(_fit(src, 504), launch / "LaunchImage@3x.png", alpha=True)
    print("wrote launcher icons from", MASTER)


if __name__ == "__main__":
    main()
