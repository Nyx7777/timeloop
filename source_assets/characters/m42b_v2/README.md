# M4.2B v2 character sources

## Locked direction

- Player: escaped laboratory test subject, cyan hair, white institutional gown, unarmed.
- Ghost: the same silhouette and subject number in a violet time-projection palette.
- Current common enemy: time-distorted researcher with red-orange temporal cracks.
- Future enemy candidate: failed test subject; exported for evaluation but not used by the current single-enemy ruleset.

The `*_v2b_alpha.png` files are the selected compact/chibi sources. Despite the historical `_alpha` suffix, the generated files contain an opaque green chroma-key background. Runtime transparency is produced locally rather than assumed.

## Runtime export

1. Remove the green background with the installed imagegen `remove_chroma_key.py` helper using border auto-key, soft matte, and despill.
2. Run `tools/export_m42_runtime_assets.py --alpha-dir <rgba-dir> --output-root game/assets`.
3. Validate the 48×64 outputs at nearest-neighbor scale in 360×800, 390×844, and 430×932 battle captures.

The generation script reads `TIMELOOP_IMAGE_GATEWAY_TOKEN` from the environment. Never store the token in this directory or in a local `.env` tracked by Git.
