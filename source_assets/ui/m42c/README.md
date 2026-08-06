# M4.2C UI source assets

These 1024×1024 files are generated chroma-key sources for the first formal mobile battle skin. They are not Godot-ready nine-patches as committed: the green background must be removed and each visible element cropped and downscaled first.

Runtime mappings and sizes are documented in `game/assets/README.md`. The deterministic crop/downscale step lives in `tools/export_m42_runtime_assets.py`; source prompts remain represented by the committed image set and the locked `13_full_hud_max_complexity.png` visual baseline.
