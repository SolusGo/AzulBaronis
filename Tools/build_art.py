"""Build Civ V DDS atlases from the supplied Azul Baronis PNG artwork."""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps


ROOT = Path(__file__).resolve().parents[1]
ICON_DIR = ROOT / "Art" / "Icons"
LOADING_DIR = ROOT / "Art" / "Loading"
PREVIEW_DIR = ROOT / "Art" / "Preview"

SOURCES = {
    "cannon": "01_Main_Cannon_Big_Laser.png",
    "player": "02_Player_Controlled_UA.png",
    "afterburner": "03_Afterburner.png",
    "homing": "04_Destroyer_Homing_Bomb.png",
    "commander": "05_Fleet_Commander.png",
    "dawn": "06_Dawn_of_Man_Loading_Art.png",
    "turret": "07_Defensive_Turret.png",
    "civilization": "08_Civilization_Icon.png",
    "leader": "09_Leader_Icon.png",
    "testudon": "10_Tetsudon.png",
    "destroyer": "11_Destroyer.png",
    "fighter": "12_Fighter.png",
}

COLOR_SIZES = (256, 128, 80, 64, 45, 32)
ALPHA_SIZES = (128, 64, 48, 32, 24, 16)


def source_digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def circular_portrait(path: Path, size: int) -> Image.Image:
    """Resize a supplied medallion and remove its opaque black corners."""
    source = Image.open(path).convert("RGBA")
    portrait = ImageOps.fit(source, (size, size), Image.Resampling.LANCZOS)

    scale = 4
    mask = Image.new("L", (size * scale, size * scale), 0)
    draw = ImageDraw.Draw(mask)
    inset = max(1, scale)
    draw.ellipse((inset, inset, size * scale - inset - 1, size * scale - inset - 1), fill=255)
    mask = mask.resize((size, size), Image.Resampling.LANCZOS)
    if "A" in source.getbands():
        mask = ImageChops.multiply(mask, portrait.getchannel("A"))
    portrait.putalpha(mask)
    return portrait


def alpha_symbol(path: Path, size: int) -> Image.Image:
    """Derive Civ V's tintable alpha symbol from the luminous crest artwork."""
    source = circular_portrait(path, max(size * 4, 128))
    red, green, blue, circle = source.split()
    luminance = ImageChops.lighter(ImageChops.lighter(red, green), blue)
    luminance = luminance.point(lambda value: max(0, min(255, int((value - 18) * 1.65))))
    luminance = ImageChops.multiply(luminance, circle)
    luminance = luminance.filter(ImageFilter.GaussianBlur(max(0.35, source.width / 768)))
    luminance = luminance.resize((size, size), Image.Resampling.LANCZOS)
    result = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    result.putalpha(luminance)
    return result


def atlas(paths: list[Path], size: int, columns: int, rows: int) -> Image.Image:
    result = Image.new("RGBA", (columns * size, rows * size), (0, 0, 0, 0))
    for index, path in enumerate(paths):
        result.alpha_composite(circular_portrait(path, size), ((index % columns) * size, (index // columns) * size))
    return result


def save_dds(image: Image.Image, path: Path, *, compressed: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if compressed:
        image.save(path, pixel_format="DXT5")
    else:
        # Civ V's legacy UI reliably accepts NPOT 45px atlases as uncompressed
        # 32-bit RGBA. Block-compressed 45px sheets can silently render blank.
        image.save(path)


def build(source_dir: Path) -> None:
    paths = {key: source_dir / filename for key, filename in SOURCES.items()}
    missing = [str(path) for path in paths.values() if not path.is_file()]
    if missing:
        raise SystemExit(f"missing source artwork: {missing}")

    for size in COLOR_SIZES:
        save_dds(circular_portrait(paths["civilization"], size), ICON_DIR / f"AzulCivColor{size}.dds")
        save_dds(circular_portrait(paths["leader"], size), ICON_DIR / f"AzulLeader{size}.dds")
        save_dds(
            atlas(
                [paths["fighter"], paths["destroyer"], paths["testudon"], paths["turret"], paths["commander"]],
                size,
                4,
                2,
            ),
            ICON_DIR / f"AzulUnits{size}.dds",
        )
        save_dds(
            atlas([paths["cannon"], paths["player"], paths["afterburner"], paths["homing"]], size, 4, 1),
            ICON_DIR / f"AzulAbilities{size}.dds",
        )

    for size in ALPHA_SIZES:
        save_dds(alpha_symbol(paths["civilization"], size), ICON_DIR / f"AzulCivAlpha{size}.dds")

    dawn_source = Image.open(paths["dawn"]).convert("RGB")
    save_dds(
        ImageOps.fit(dawn_source, (1024, 768), Image.Resampling.LANCZOS, centering=(0.5, 0.52)).convert("RGBA"),
        LOADING_DIR / "AzulDawnOfMan.dds",
        compressed=True,
    )
    save_dds(
        ImageOps.fit(dawn_source, (512, 512), Image.Resampling.LANCZOS, centering=(0.5, 0.5)).convert("RGBA"),
        LOADING_DIR / "AzulMap512.dds",
        compressed=True,
    )
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    ImageOps.fit(dawn_source, (1200, 675), Image.Resampling.LANCZOS).save(
        PREVIEW_DIR / "AzulBanner.png", optimize=True
    )

    print(f"built 32 DDS textures and README banner from {source_dir}")
    for key in SOURCES:
        print(f"{SOURCES[key]}  {source_digest(paths[key])}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_dir", type=Path, help="directory containing the twelve numbered source PNG files")
    args = parser.parse_args()
    build(args.source_dir.resolve())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
