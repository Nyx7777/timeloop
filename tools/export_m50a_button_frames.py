"""Derive consistent M5.0A button-frame and inner-glow variants."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageOps


EXPORTS = {
    "move": ("#062c39", "#43cce2", "#a9edf6"),
    "attack": ("#391014", "#df4650", "#f6a4a7"),
    "crystallize": ("#29143c", "#9c5dcc", "#d5acee"),
    "end_turn": ("#382b12", "#c99b4c", "#e7cc94"),
}

PLATE_EXPORTS = {
    "move": ("#030912", "#0b3d47", "#79d4dc"),
    "attack": ("#09070c", "#421018", "#ff8588"),
    "crystallize": ("#08070f", "#2a1737", "#a978c7"),
    "end_turn": ("#09090c", "#35280f", "#c89a52"),
}

PLATE_SELECTED_EXPORTS = {
    "move": ("#04101a", "#145866", "#dcfbff"),
    "attack": ("#13070b", "#76141d", "#fff1ee"),
    "crystallize": ("#100818", "#48255e", "#f1ddff"),
    "end_turn": ("#120f08", "#5b4318", "#fff0bc"),
}

RUNTIME_SIZE = (128, 160)
CONTENT_SIZE = (116, 148)
PLATE_CONTENT_SIZE = (124, 156)


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


def export_inner_glow(source: Image.Image, destination: Path, palette: tuple[str, str, str]) -> None:
    """Keep the generated glow's low placement while scaling it into the runtime slot."""
    fitted = ImageOps.contain(source, CONTENT_SIZE, Image.Resampling.LANCZOS)
    alpha = fitted.getchannel("A")
    grayscale = ImageOps.grayscale(fitted.convert("RGB"))
    recolored = ImageOps.colorize(
        grayscale,
        black=palette[0],
        mid=palette[1],
        white=palette[2],
    ).convert("RGBA")
    recolored.putalpha(alpha)

    canvas = Image.new("RGBA", RUNTIME_SIZE, (0, 0, 0, 0))
    canvas.alpha_composite(
        recolored,
        ((canvas.width - recolored.width) // 2, (canvas.height - recolored.height) // 2),
    )
    destination.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(destination, format="PNG", optimize=True)
    checked = Image.open(destination).convert("RGBA")
    if checked.size != RUNTIME_SIZE or checked.getpixel((0, 0))[3] != 0:
        raise ValueError(f"invalid exported inner glow: {destination}")


def export_plate(
    source: Image.Image,
    destination: Path,
    palette: tuple[str, str, str],
    selected: bool = False,
) -> None:
    """Export one coherent plate close to the runtime slot perimeter."""
    alpha = source.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        raise ValueError("button plate master has no visible pixels")

    plate = source.crop(bbox)
    plate_alpha = plate.getchannel("A")
    grayscale = ImageOps.grayscale(plate.convert("RGB"))
    colorize_options = {
        "black": palette[0],
        "mid": palette[1],
        "white": palette[2],
    }
    if selected:
        colorize_options.update({"midpoint": 65, "whitepoint": 170})
    recolored = ImageOps.colorize(grayscale, **colorize_options).convert("RGBA")
    recolored.putalpha(plate_alpha)
    fitted = ImageOps.contain(recolored, PLATE_CONTENT_SIZE, Image.Resampling.LANCZOS)

    canvas = Image.new("RGBA", RUNTIME_SIZE, (0, 0, 0, 0))
    canvas.alpha_composite(
        fitted,
        ((canvas.width - fitted.width) // 2, (canvas.height - fitted.height) // 2),
    )
    destination.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(destination, format="PNG", optimize=True)
    checked = Image.open(destination).convert("RGBA")
    if checked.size != RUNTIME_SIZE or checked.getpixel((0, 0))[3] != 0:
        raise ValueError(f"invalid exported plate: {destination}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("frame_source", type=Path)
    parser.add_argument("glow_source", type=Path)
    parser.add_argument("plate_source", type=Path)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()

    frame_source = Image.open(args.frame_source).convert("RGBA")
    glow_source = Image.open(args.glow_source).convert("RGBA")
    plate_source = Image.open(args.plate_source).convert("RGBA")
    for name, palette in EXPORTS.items():
        frame_destination = args.destination / f"button_frame_glow_{name}.png"
        export_variant(frame_source, frame_destination, palette)
        print(f"Wrote {frame_destination}")
        glow_destination = args.destination / f"button_inner_glow_{name}.png"
        export_inner_glow(glow_source, glow_destination, palette)
        print(f"Wrote {glow_destination}")
        plate_destination = args.destination / f"button_plate_{name}.png"
        export_plate(plate_source, plate_destination, PLATE_EXPORTS[name])
        print(f"Wrote {plate_destination}")
        selected_plate_destination = args.destination / f"button_plate_selected_{name}.png"
        export_plate(plate_source, selected_plate_destination, PLATE_SELECTED_EXPORTS[name], selected=True)
        print(f"Wrote {selected_plate_destination}")


if __name__ == "__main__":
    main()
