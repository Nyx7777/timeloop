# M5.0A action-button plate design QA

- Source visual truth: `时间循环玩法/demo/art_concepts/14_m50a_temporal_command_rail_selected.png`
- Implementation screenshot: `C:/Users/User/AppData/Local/Temp/timeloop_m50a_button_plate_v2/m50a_boss_build_max.png`
- Focused comparison: `C:/Users/User/.codex/visualizations/2026/08/06/019fd7ba-9043-7612-a7e4-b8670c0a2732/button_compare_round3.png`
- Viewport: portrait mobile, Godot logical size 390×844
- Source pixels: 853×1844; normalized to the 390×844 implementation ratio for component comparison
- Implementation pixels: 390×844 at 1× capture density
- State: bottom action rail with Attack selected; normal, selected, disabled/locked and end-turn plates visible

## Full-view comparison evidence

The selected source and implementation use the same portrait aspect and four-slot action rail. The surrounding battle content differs by design fixture, so the QA target is the action-button component rather than the board or HUD content.

## Focused region comparison evidence

The focused comparison places the four source buttons above the four implementation buttons at a normalized component size. It is required here because the exterior rail, inner-rail spacing and clipped corners are too small to judge reliably from the full screen.

## Comparison history

### Pass 1 — blocked

Evidence: `C:/Users/User/.codex/visualizations/2026/08/06/019fd7ba-9043-7612-a7e4-b8670c0a2732/button_compare_round2.png`

- P1: the obsolete M4.2C button texture remained under the new frame, producing a second exterior outline.
- P1: the overlay frame was visibly inset and read as a rounded octagon instead of the reference's perimeter-hugging double rail.

Fixes applied:

- Removed the four legacy nine-patch button textures and the normal-state `FrameGlow` layer from runtime composition.
- Replaced them with one complete 128×160 plate per color and separate selected-state plates.
- Kept the lower interior glow and icon/caption as content layers above the single plate.

### Pass 2 — passed

Evidence: `C:/Users/User/.codex/visualizations/2026/08/06/019fd7ba-9043-7612-a7e4-b8670c0a2732/button_compare_round3.png`

- No duplicate line exists outside the button silhouette.
- The dark structural edge, colored outer rail, narrow inner rail and small clipped corners now occupy the same visual hierarchy as the source.
- The selected Attack plate uses the source's pale inner rail, red outer rail and dark red interior without adding a floating frame.

## Required fidelity surfaces

- Fonts and typography: existing approved icon/caption treatment is unchanged; the crystallize caption remains the single line “固化”.
- Spacing and layout rhythm: the replacement plate fills the existing touch target and keeps both rails close to the perimeter; no extra exterior frame consumes button spacing.
- Colors and visual tokens: cyan/red/purple/gold normal plates stay restrained; selected plates brighten the inner rail while preserving a dark interior.
- Image quality and asset fidelity: all visible plate geometry is raster pixel art derived from one ImageGen master, exported at 128×160 with transparent corners and nearest-neighbor runtime filtering.
- Copy and content: no button text changed in this pass.

## Follow-up polish

- P3: the current Godot touch target is slightly taller than the source concept's button proportion; retained because the geometry and touch baseline were already validated and the user feedback was specifically about frame layering and inner-rail fidelity.

final result: passed
