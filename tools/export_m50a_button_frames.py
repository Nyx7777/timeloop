"""Derive consistent M5.0A button-frame variants from one generated master."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageOps


EXPORTS = {
    "move": ("#073744", "#53e7ff", "#ecfdff"),
    "attack": ("#421014", "#ff4e55", "#fff1f1"),
    "crystallize": ("#2f1745", "#b86cff", "#f8eaff"),
    "end_turn": ("#413113", "#e9b95f", "#fff6d8"),
}

RUNTIME_SIZE = (128, 160)
CONTENT_SIZE = (116, 148)


def export_variant(source: Image.Image, destination: Path, palette: tuple[str, str, str]) -> None:
    alpha = source.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        raise ValueError("button frame master has no visible pixels")

    frame = source.crop(bbox)
    frame_alpha = frame.getchannel("A")
    grayscale = ImageOps.grayscale(frame.convert("RGB"))
    recolored = ImageOps.colorize(
        grayscale,
        black=palette[0],
        mid=palette[1],
        white=palette[2],
    ).convert("RGBA")
    recolored.putalpha(frame_alpha)

    scale = min(CONTENT_SIZE[0] / recolored.width, CONTENT_SIZE[1] / recolored.height)
    resized = recolored.resize(
        (max(1, round(recolored.width * scale)), max(1, round(recolored.height * scale))),
        Image.Resampling.LANCZOS,
    )
    canvas = Image.new("RGBA", RUNTIME_SIZE, (0, 0, 0, 0))
    canvas.alpha_composite(
        resized,
        ((canvas.width - resized.width) // 2, (canvas.height - resized.height) // 2),
    )

    destination.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(destination, format="PNG", optimize=True)
    checked = Image.open(destination).convert("RGBA")
    if checked.size != RUNTIME_SIZE or checked.getpixel((0, 0))[3] != 0:
        raise ValueError(f"invalid exported frame: {destination}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()

    source = Image.open(args.source).convert("RGBA")
    for name, palette in EXPORTS.items():
        destination = args.destination / f"button_frame_glow_{name}.png"
        export_variant(source, destination, palette)
        print(f"Wrote {destination}")


if __name__ == "__main__":
    main()
