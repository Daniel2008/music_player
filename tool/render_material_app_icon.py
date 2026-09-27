from __future__ import annotations

import os
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
CANVAS = 1024
TILE_INSET = 44
TILE_RADIUS = 214
BORDER_WIDTH = 5

BACKGROUND = (234, 235, 242, 255)
BORDER = (201, 203, 221, 255)
NOTE = (81, 91, 146, 255)
SHADOW = (38, 44, 72, 44)
MUSIC_NOTE_GLYPH = "\uf8ed"
NOTE_FONT_SIZE = 630


def _material_icon_font() -> ImageFont.FreeTypeFont:
    flutter_root = os.environ.get("FLUTTER_ROOT")
    flutter_command = shutil.which("flutter") or shutil.which("flutter.bat")
    candidates = []
    if flutter_root:
        candidates.append(Path(flutter_root))
    if flutter_command:
        candidates.append(Path(flutter_command).resolve().parent.parent)
    candidates.append(Path("D:/worksoft/flutter"))

    for root in candidates:
        font_path = (
            root
            / "bin"
            / "cache"
            / "artifacts"
            / "material_fonts"
            / "materialicons-regular.otf"
        )
        if font_path.is_file():
            return ImageFont.truetype(str(font_path), NOTE_FONT_SIZE)
    raise FileNotFoundError(
        "MaterialIcons-Regular.otf was not found; set FLUTTER_ROOT or add flutter to PATH."
    )


def _draw_note(canvas: Image.Image) -> None:
    note = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(note, "RGBA")
    draw.text(
        (CANVAS // 2, CANVAS // 2 + 4),
        MUSIC_NOTE_GLYPH,
        font=_material_icon_font(),
        fill=NOTE,
        anchor="mm",
    )
    canvas.alpha_composite(note)


def render_icon(size: int, maskable: bool = False) -> Image.Image:
    tile_size = CANVAS - TILE_INSET * 2
    tile = Image.new("RGBA", (tile_size, tile_size), (0, 0, 0, 0))

    draw = ImageDraw.Draw(tile, "RGBA")
    draw.rounded_rectangle(
        (0, 0, tile_size - 1, tile_size - 1),
        radius=TILE_RADIUS - TILE_INSET,
        fill=BACKGROUND,
        outline=BORDER,
        width=BORDER_WIDTH,
    )

    note_layer = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    _draw_note(note_layer)
    tile.alpha_composite(note_layer, (-TILE_INSET, -TILE_INSET))

    if maskable:
        background = Image.new("RGBA", (CANVAS, CANVAS), BACKGROUND)
        content_size = round(CANVAS * 0.78)
        content = tile.resize(
            (content_size, content_size),
            Image.Resampling.LANCZOS,
        )
        offset = (CANVAS - content_size) // 2
        background.alpha_composite(content, (offset, offset))
        return background.resize((size, size), Image.Resampling.LANCZOS)

    result = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    shadow = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow, "RGBA")
    shadow_draw.rounded_rectangle(
        (
            TILE_INSET + 2,
            TILE_INSET + 12,
            CANVAS - TILE_INSET + 2,
            CANVAS - TILE_INSET + 12,
        ),
        radius=TILE_RADIUS - TILE_INSET,
        fill=SHADOW,
    )
    result.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(18)))
    result.alpha_composite(tile, (TILE_INSET, TILE_INSET))

    if size != CANVAS:
        result = result.resize((size, size), Image.Resampling.LANCZOS)
    return result


def _save_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, "PNG", optimize=True)


def main() -> None:
    source = render_icon(CANVAS)
    maskable = render_icon(CANVAS, maskable=True)

    _save_png(source, ROOT / "assets" / "branding" / "app_icon.png")
    _save_png(maskable, ROOT / "assets" / "branding" / "app_icon_maskable.png")

    ico_path = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
    source.save(
        ico_path,
        format="ICO",
        sizes=[
            (16, 16),
            (24, 24),
            (32, 32),
            (48, 48),
            (64, 64),
            (128, 128),
            (256, 256),
        ],
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
