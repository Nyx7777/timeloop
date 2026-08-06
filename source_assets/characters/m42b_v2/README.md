# M4.2B v2 character sources

## Locked direction

- Player: escaped laboratory test subject, cyan hair, white institutional gown, unarmed.
- Ghost: the same silhouette and subject number in a violet time-projection palette.
- Current common enemy: time-distorted researcher with red-orange temporal cracks.
- Future enemy candidate: failed test subject; exported for evaluation but not used by the current single-enemy ruleset.

The `*_v2b_alpha.png` files are the selected compact/chibi sources. Despite the historical `_alpha` suffix, the generated files contain an opaque green chroma-key background. Runtime transparency is produced locally rather than assumed.

## Runtime export

1. Remove the green background with the installed imagegen `remove_chroma_key.py` helper using border auto-key, soft matte, and despill.
2. Run `tools/export_m42_runtime_assets.py --alpha-dir <rgba-dir> --environment-dir source_assets/environment/m42a --output-root game/assets`. Characters export to a 192×256 high-density canvas with nearest-neighbor sampling to preserve the source pixel clusters.
3. Validate that runtime drawing preserves the 3:4 source aspect ratio, snaps the sprite rectangle to integer pixels, and remains readable in 360×800, 390×844, 430×932, and the user's actual window sizes.

The generation script reads `TIMELOOP_IMAGE_GATEWAY_TOKEN` from the environment. Never store the token in this directory or in a local `.env` tracked by Git.
