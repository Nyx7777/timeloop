# M4.2B v2 character sources

## Locked direction

- Player: escaped laboratory test subject, cyan hair, white institutional gown, unarmed.
- Ghost: a deterministic violet projection derived from the player master, with the exact same silhouette, pose, face, clothing, and subject number.
- Current common enemy: time-distorted researcher with red-orange temporal cracks.
- Future enemy candidate: failed test subject; exported for evaluation but not used by the current single-enemy ruleset.

The `*_v2b_alpha.png` files are the selected compact/chibi sources. Despite the historical `_alpha` suffix, the generated files contain an opaque green chroma-key background. Runtime transparency is produced locally rather than assumed.

## Runtime export

1. Remove the green background with the installed imagegen `remove_chroma_key.py` helper using border auto-key, soft matte, and despill.
2. Run `tools/export_m42_runtime_assets.py --alpha-dir <rgba-dir> --environment-dir source_assets/environment/m42a --derived-source-dir source_assets/characters/m42b_v2 --output-root game/assets`. Characters export to a 192×256 high-density canvas with nearest-neighbor sampling. `ghost_idle.png` and `ghost_v2c_alpha.png` are derived from the player master; the old independently generated `ghost_v2b_alpha.png` is historical input only.
3. Validate that runtime drawing preserves the 3:4 source aspect ratio, snaps the sprite rectangle to integer pixels, and remains readable in 360×800, 390×844, 430×932, and the user's actual window sizes.

The generation script reads `TIMELOOP_IMAGE_GATEWAY_TOKEN` from the environment. Never store the token in this directory or in a local `.env` tracked by Git.

## Ghost v2c identity lock

- Built-in image editing was used to establish the violet/lilac projection palette with an identity-preserve prompt: keep the exact face, hair spikes, body proportions, gown, `07`, pose, direction, framing, and pixel clusters; change only palette, emissive outline, and minimal temporal fragments on a flat `#00ff00` background.
- The selected production asset does not use a separately redrawn body. `tools/export_m42_runtime_assets.py` derives both `ghost_v2c_alpha.png` and `ghost_idle.png` from the chroma-removed player master, guaranteeing identical geometry for this frame.
- Future animation ghosts must be derived from each matching player frame after that player frame is approved.
