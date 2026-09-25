"""Build the three tintable 32px Civ V unit-flag symbols from supplied PNGs."""

from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / "Art" / "Sources" / "Flags"
OUTPUT = ROOT / "Art" / "Icons" / "AzulUnitFlags32.dds"
NAMES = ("Fighter", "Destroyer", "Testudon")
CELL_SIZE = 32
# Civ V clips the center of a unit flag to a circle roughly 22px across.
SYMBOL_SIZE = 22


def symbol(path: Path) -> Image.Image:
    source = Image.open(path).convert("RGBA")
    alpha = source.getchannel("A")
    bounds = alpha.point(lambda value: 255 if value >= 16 else 0).getbbox()
    if bounds is None:
        raise ValueError(f"empty unit flag artwork: {path}")
    alpha = alpha.crop(bounds)
    alpha.thumbnail((SYMBOL_SIZE, SYMBOL_SIZE), Image.Resampling.LANCZOS)
    tile = Image.new("RGBA", (CELL_SIZE, CELL_SIZE), (255, 255, 255, 0))
    glyph = Image.new("RGBA", alpha.size, (255, 255, 255, 0))
    glyph.putalpha(alpha)
    tile.alpha_composite(glyph, ((CELL_SIZE - glyph.width) // 2, (CELL_SIZE - glyph.height) // 2))
    return tile


def main() -> None:
    atlas = Image.new("RGBA", (CELL_SIZE * len(NAMES), CELL_SIZE), (255, 255, 255, 0))
    for index, name in enumerate(NAMES):
        atlas.alpha_composite(symbol(SOURCES / f"{name}.png"), (index * CELL_SIZE, 0))
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    # Match the project's reliable uncompressed A8R8G8B8 DDS icon format.
    atlas.save(OUTPUT)
    print(f"built {OUTPUT.relative_to(ROOT)} ({atlas.width}x{atlas.height})")


if __name__ == "__main__":
    main()
