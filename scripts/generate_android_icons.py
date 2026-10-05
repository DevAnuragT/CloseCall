#!/usr/bin/env python3
"""Render CloseCall's Android launcher icons from android/assets/Icon.png.

The supplied artwork contains a few almost-transparent pixels outside the
visible rounded-square artwork.  Those pixels are removed from generated
copies only; the source image is never modified.

Requires Pillow, which is already used by the repository's local image tooling.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "android/assets/Icon.png"
LEGACY_SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}
ALPHA_CUTOFF = 16
ADAPTIVE_CANVAS = 108
ADAPTIVE_FOREGROUND_SIZE = 72


def cleaned_artwork() -> Image.Image:
    """Return a square, cleaned copy of the source artwork."""
    source = Image.open(SOURCE).convert("RGBA")
    alpha = source.getchannel("A").point(
        lambda value: 0 if value < ALPHA_CUTOFF else value
    )
    source.putalpha(alpha)
    bbox = alpha.getbbox()
    if bbox is None:
        raise ValueError(f"{SOURCE} has no visible artwork")

    # The visible artwork is only a few pixels taller/shorter than wide.  A
    # square crop keeps the proportions intact while retaining all of it.
    left, top, right, bottom = bbox
    width, height = right - left, bottom - top
    side = max(width, height)
    center_x = (left + right) // 2
    center_y = (top + bottom) // 2
    crop_left = max(0, center_x - side // 2)
    crop_top = max(0, center_y - side // 2)
    crop_right = min(source.width, crop_left + side)
    crop_bottom = min(source.height, crop_top + side)
    # Shift the crop back inside the source if it touched an edge.
    crop_left = crop_right - side
    crop_top = crop_bottom - side
    return source.crop((crop_left, crop_top, crop_right, crop_bottom))


def resized(image: Image.Image, size: int) -> Image.Image:
    result = image.resize((size, size), Image.Resampling.LANCZOS)
    # Avoid reintroducing barely visible fringe pixels during downsampling.
    alpha = result.getchannel("A").point(
        lambda value: 0 if value < 8 else value
    )
    result.putalpha(alpha)
    return result


def render_legacy(artwork: Image.Image, size: int) -> Image.Image:
    # Leave a small transparent safety border.  This prevents launcher masks
    # from clipping the source's rounded corners or the heart illustration.
    art = resized(artwork, round(size * 0.90))
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.alpha_composite(art, ((size - art.width) // 2, (size - art.height) // 2))
    return canvas


def render_adaptive_foreground(artwork: Image.Image) -> Image.Image:
    # Android adaptive icons use a 108dp layer; keeping the complete source in
    # 72px leaves the illustration inside the approximately 66px safe zone.
    art = resized(artwork, ADAPTIVE_FOREGROUND_SIZE)
    canvas = Image.new("RGBA", (ADAPTIVE_CANVAS, ADAPTIVE_CANVAS), (0, 0, 0, 0))
    canvas.alpha_composite(
        art,
        ((ADAPTIVE_CANVAS - art.width) // 2, (ADAPTIVE_CANVAS - art.height) // 2),
    )
    return canvas


def write_pngs() -> None:
    artwork = cleaned_artwork()
    for directory, size in LEGACY_SIZES.items():
        destination = ROOT / "android/app/src/main/res" / directory / "ic_launcher.png"
        destination.parent.mkdir(parents=True, exist_ok=True)
        rendered = render_legacy(artwork, size)
        rendered.save(destination, "PNG", optimize=True)
        # Keep the roundIcon reference valid on pre-26 configurations too.
        rendered.save(destination.with_name("ic_launcher_round.png"), "PNG", optimize=True)

    foreground = ROOT / "android/app/src/main/res/drawable-nodpi/ic_launcher_foreground.png"
    foreground.parent.mkdir(parents=True, exist_ok=True)
    render_adaptive_foreground(artwork).save(foreground, "PNG", optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.parse_args()
    write_pngs()


if __name__ == "__main__":
    main()
