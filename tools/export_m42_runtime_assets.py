"""Export validated M4.2 source cutouts into Godot runtime PNG assets.

The input directory must contain chroma-key-removed RGBA files produced by the
installed imagegen ``remove_chroma_key.py`` helper. This script only performs
deterministic cropping, high-density resizing, anchoring, and final alpha
validation.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


CHARACTER_EXPORTS = {
    "player_v2b_alpha.png": "characters/player_idle.png",
    "ghost_v2b_alpha.png": "characters/ghost_idle.png",
    "enemy_researcher_v2b_alpha.png": "characters/guard_idle.png",
    "enemy_subject_v2b_alpha.png": "characters/enemy_subject_idle.png",
}

UI_EXPORTS = {
    "board_frame_border.png": ("ui/m42c/board_frame_border.png", (96, 96)),
    "button_attack_9patch.png": ("ui/m42c/button_attack_9patch.png", (64, 40)),
    "button_crystallize_9patch.png": ("ui/m42c/button_crystallize_9patch.png", (64, 40)),
    "button_endturn_9patch.png": ("ui/m42c/button_endturn_9patch.png", (64, 40)),
    "button_move_9patch.png": ("ui/m42c/button_move_9patch.png", (64, 40)),
    "hint_bar_bg.png": ("ui/m42c/hint_bar_bg.png", (128, 20)),
    "hp_bar_enemy.png": ("ui/m42c/hp_bar_enemy.png", (64, 12)),
    "hp_bar_player.png": ("ui/m42c/hp_bar_player.png", (64, 12)),
    "hud_panel_top.png": ("ui/m42c/hud_panel_top.png", (128, 32)),
    "sequence_frame_active.png": ("ui/m42c/sequence_frame_active.png", (48, 48)),
    "sequence_frame_inactive.png": ("ui/m42c/sequence_frame_inactive.png", (48, 48)),
}

CHARACTER_CANVAS = (192, 256)
CHARACTER_SUBJECT_BOUNDS = (168, 232)
CHARACTER_BASELINE_Y = 244
BOARD_TILE_SIZE = (256, 256)
OBSTACLE_CANVAS = (256, 320)


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    bbox = image.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("source has no visible pixels")
    return bbox


def save_rgba(
    image: Image.Image,
    destination: Path,
    *,
    require_transparent_corner: bool = True,
) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    image.save(destination, format="PNG", optimize=True)
    checked = Image.open(destination).convert("RGBA")
    if checked.getchannel("A").getextrema()[0] != 0:
        raise ValueError(f"{destination} has no transparent pixels")
    if require_transparent_corner and checked.getpixel((0, 0))[3] != 0:
        raise ValueError(f"{destination} does not have a transparent corner")


def export_character(source: Path, destination: Path) -> None:
    image = Image.open(source).convert("RGBA")
    subject = image.crop(alpha_bbox(image))
    scale = min(
        CHARACTER_SUBJECT_BOUNDS[0] / subject.width,
        CHARACTER_SUBJECT_BOUNDS[1] / subject.height,
    )
    size = (
        max(1, round(subject.width * scale)),
        max(1, round(subject.height * scale)),
    )
    # Keep four texture pixels for every former runtime pixel. The generated
    # sources already contain deliberate pixel clusters; nearest sampling
    # preserves those clusters without collapsing the character to 48x64.
    subject = subject.resize(size, Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", CHARACTER_CANVAS, (0, 0, 0, 0))
    x = (canvas.width - subject.width) // 2
    y = CHARACTER_BASELINE_Y - subject.height
    canvas.alpha_composite(subject, (x, y))
    save_rgba(canvas, destination)


def export_floor(source: Path, destination: Path) -> None:
    image = Image.open(source).convert("RGBA")
    subject = image.crop(alpha_bbox(image))
    resized = subject.resize(BOARD_TILE_SIZE, Image.Resampling.LANCZOS)
    save_rgba(resized, destination, require_transparent_corner=False)


def export_obstacle(source: Path, destination: Path) -> None:
    image = Image.open(source).convert("RGBA")
    subject = image.crop(alpha_bbox(image))
    inset = 8
    scale = min(
        (OBSTACLE_CANVAS[0] - inset * 2) / subject.width,
        (OBSTACLE_CANVAS[1] - inset) / subject.height,
    )
    resized = subject.resize(
        (max(1, round(subject.width * scale)), max(1, round(subject.height * scale))),
        Image.Resampling.LANCZOS,
    )
    canvas = Image.new("RGBA", OBSTACLE_CANVAS, (0, 0, 0, 0))
    canvas.alpha_composite(
        resized,
        ((canvas.width - resized.width) // 2, canvas.height - resized.height),
    )
    save_rgba(canvas, destination)


def export_contained(source: Path, destination: Path, size: tuple[int, int], inset: int = 2) -> None:
    image = Image.open(source).convert("RGBA")
    subject = image.crop(alpha_bbox(image))
    max_width = size[0] - inset * 2
    max_height = size[1] - inset * 2
    scale = min(max_width / subject.width, max_height / subject.height)
    resized = subject.resize(
        (max(1, round(subject.width * scale)), max(1, round(subject.height * scale))),
        Image.Resampling.LANCZOS,
    )
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    canvas.alpha_composite(
        resized,
        ((size[0] - resized.width) // 2, (size[1] - resized.height) // 2),
    )
    save_rgba(canvas, destination)


def export_stretched(source: Path, destination: Path, size: tuple[int, int]) -> None:
    image = Image.open(source).convert("RGBA")
    subject = image.crop(alpha_bbox(image))
    resized = subject.resize(size, Image.Resampling.LANCZOS)
    save_rgba(resized, destination, require_transparent_corner=False)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--alpha-dir", type=Path, required=True)
    parser.add_argument("--environment-dir", type=Path)
    parser.add_argument("--output-root", type=Path, required=True)
    args = parser.parse_args()

    for source_name, destination_name in CHARACTER_EXPORTS.items():
        destination = args.output_root / destination_name
        export_character(args.alpha_dir / source_name, destination)
        print(f"EXPORTED {destination}")

    void_destination = args.output_root / "environment/time_void_tile.png"
    export_contained(
        args.alpha_dir / "time_void_tile_alpha.png",
        void_destination,
        BOARD_TILE_SIZE,
        inset=4,
    )
    print(f"EXPORTED {void_destination}")

    if args.environment_dir is not None:
        environment_exports = {
            "lab_floor_tile_alpha.png": ("environment/lab_floor_tile.png", export_floor),
            "lab_server_alpha.png": ("environment/lab_obstacle_server.png", export_obstacle),
            "lab_pillar_alpha.png": ("environment/lab_obstacle_pillar.png", export_obstacle),
        }
        for source_name, (destination_name, exporter) in environment_exports.items():
            destination = args.output_root / destination_name
            exporter(args.environment_dir / source_name, destination)
            print(f"EXPORTED {destination}")

    for source_name, (destination_name, size) in UI_EXPORTS.items():
        destination = args.output_root / destination_name
        export_stretched(args.alpha_dir / source_name, destination, size)
        print(f"EXPORTED {destination}")


if __name__ == "__main__":
    main()
