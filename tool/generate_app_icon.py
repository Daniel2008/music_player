from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
CANVAS = 1024
CORNER = 224
INDIGO = (79, 70, 229)
VIOLET = (124, 58, 237)
TEAL = (45, 212, 191)
CORAL = (251, 113, 91)
WHITE = (255, 255, 255)


def _mix(first: tuple[int, int, int], second: tuple[int, int, int], t: float):
    return tuple(round(a + (b - a) * t) for a, b in zip(first, second))


def _gradient(size: int, first: tuple[int, int, int], second: tuple[int, int, int]):
    image = Image.new("RGB", (size, size))
    pixels = image.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * (size - 1))
            pixels[x, y] = _mix(first, second, t)
    return image


def _rounded_mask(size: int, radius: int):
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, size - 1, size - 1),
        radius=radius,
        fill=255,
    )
    return mask


def _bezier(points, steps=24):
    output = []
    for index in range(steps + 1):
        t = index / steps
        one = 1 - t
        x = (
            one**3 * points[0][0]
            + 3 * one**2 * t * points[1][0]
            + 3 * one * t**2 * points[2][0]
            + t**3 * points[3][0]
        )
        y = (
            one**3 * points[0][1]
            + 3 * one**2 * t * points[1][1]
            + 3 * one * t**2 * points[2][1]
            + t**3 * points[3][1]
        )
        output.append((x, y))
    return output


def _draw_brand_mark(canvas: Image.Image):
    draw = ImageDraw.Draw(canvas, "RGBA")

    glow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow, "RGBA")
    glow_draw.ellipse((520, 70, 1010, 560), fill=(*CORAL, 112))
    glow_draw.ellipse((10, 520, 430, 1010), fill=(*TEAL, 96))
    glow_draw.ellipse((320, 210, 810, 760), fill=(*WHITE, 24))
    glow = glow.filter(ImageFilter.GaussianBlur(74))
    canvas.alpha_composite(glow)

    waveform = [(650, 665, 760, 980), (738, 520, 848, 980), (826, 350, 936, 980)]
    waveform_colors = [
        (*TEAL, 235),
        (*WHITE, 224),
        (*CORAL, 238),
    ]
    for (x0, y0, x1, y1), color in zip(waveform, waveform_colors):
        draw.rounded_rectangle((x0, y0, x1, y1), radius=52, fill=color)

    stem = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    stem_draw = ImageDraw.Draw(stem, "RGBA")
    stem_draw.rounded_rectangle((422, 294, 480, 704), radius=29, fill=(*WHITE, 248))
    for point in _bezier(((450, 320), (590, 280), (670, 382), (472, 500))):
        radius = 31
        stem_draw.ellipse(
            (point[0] - radius, point[1] - radius, point[0] + radius, point[1] + radius),
            fill=(*WHITE, 248),
        )
    canvas.alpha_composite(stem)

    head = Image.new("RGBA", (250, 170), (0, 0, 0, 0))
    head_draw = ImageDraw.Draw(head, "RGBA")
    head_draw.ellipse((10, 14, 215, 152), fill=(*WHITE, 252))
    head_draw.ellipse((62, 36, 128, 96), fill=(*INDIGO, 58))
    head = head.rotate(-18, resample=Image.Resampling.BICUBIC, expand=True)
    canvas.alpha_composite(head, (250, 584))

    inner = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    inner_draw = ImageDraw.Draw(inner, "RGBA")
    inner_draw.rounded_rectangle(
        (38, 38, CANVAS - 39, CANVAS - 39),
        radius=CORNER,
        outline=(255, 255, 255, 56),
        width=3,
    )
    inner_draw.ellipse((110, 104, 172, 166), fill=(255, 255, 255, 88))
    canvas.alpha_composite(inner)


def render_icon(size: int, maskable: bool = False) -> Image.Image:
    base = _gradient(size, INDIGO, VIOLET).convert("RGBA")

    tile = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    tile.alpha_composite(base, (0, 0))
    _draw_brand_mark(tile)

    mask = _rounded_mask(CANVAS, CORNER)
    tile.putalpha(Image.composite(tile.getchannel("A"), Image.new("L", tile.size, 0), mask))

    if maskable:
        background = _gradient(size, (27, 32, 58), (60, 37, 108)).convert("RGBA")
        background_draw = ImageDraw.Draw(background, "RGBA")
        background_draw.ellipse(
            (size * 0.55, -size * 0.08, size * 1.12, size * 0.48),
            fill=(*CORAL, 82),
        )
        background_draw.ellipse(
            (-size * 0.12, size * 0.52, size * 0.47, size * 1.1),
            fill=(*TEAL, 76),
        )
        content_size = round(size * 0.82)
        content = tile.resize(
            (content_size, content_size),
            Image.Resampling.LANCZOS,
        )
        offset = round((size - content_size) / 2)
        background.alpha_composite(content, (offset, offset))
        return background

    if size != CANVAS:
        tile = tile.resize((size, size), Image.Resampling.LANCZOS)
    return tile


def _save_png(image: Image.Image, path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, "PNG", optimize=True)


def main():
    source = render_icon(CANVAS)
    maskable = render_icon(CANVAS, maskable=True)
    _save_png(source, ROOT / "assets" / "branding" / "app_icon.png")
    _save_png(maskable, ROOT / "assets" / "branding" / "app_icon_maskable.png")

    ico_path = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
    source.save(
        ico_path,
        format="ICO",
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )

    macos = ROOT / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    for size in (16, 32, 64, 128, 256, 512, 1024):
        _save_png(render_icon(size), macos / f"app_icon_{size}.png")

    web = ROOT / "web" / "icons"
    _save_png(render_icon(192), web / "Icon-192.png")
    _save_png(render_icon(512), web / "Icon-512.png")
    _save_png(render_icon(192, maskable=True), web / "Icon-maskable-192.png")
    _save_png(render_icon(512, maskable=True), web / "Icon-maskable-512.png")
    _save_png(render_icon(64), ROOT / "web" / "favicon.png")


if __name__ == "__main__":
    main()
