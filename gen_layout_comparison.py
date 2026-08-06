"""
生成两版战斗布局概念图对比 — 休闲解谜 vs 重度战棋
"""
import base64
import os
import requests
from pathlib import Path

GATEWAY_URL = "https://ai-gateway.testing.hetao101.com/v1/images/generations"
GATEWAY_MODEL = "azure.public.gpt-image-2"


def gateway_headers():
    token = os.environ.get("TIMELOOP_IMAGE_GATEWAY_TOKEN")
    if not token:
        raise RuntimeError(
            "Set TIMELOOP_IMAGE_GATEWAY_TOKEN before running this generation script."
        )
    return {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }

output_dir = Path(__file__).parent / "layout_concepts"
output_dir.mkdir(exist_ok=True)

GAME_CONTEXT = """This is a UI concept for "Time Loop Tactics" — a tactical strategy game where the player dies and restarts from turn 1, with their previous self becoming an AI ghost that replays recorded actions. The player choreographs multiple timelines to solve combat encounters."""

PROMPTS = [
    {
        "id": "layout_A_casual_puzzle",
        "prompt": f"""{GAME_CONTEXT}

Design a CASUAL PUZZLE GAME battle screen — clean, minimal, mobile-friendly:

LAYOUT: Portrait/square orientation (like a mobile game). The 8x8 isometric grid takes up 80% of the screen.

STYLE:
- Clean, modern minimalist aesthetic (think Monument Valley meets Into the Breach)
- Soft pastel background with gentle gradients
- Crisp, readable tile outlines — no clutter
- Warm color palette: cream/white base, soft teal player, lavender ghosts, coral enemies
- Flat design with subtle shadows for depth
- No CRT/glitch effects — this is calm and cerebral

UI ELEMENTS (minimal):
- Top: just a small "Timeline 2 / Turn 3" badge and 3 small heart icons for lives
- Bottom: only 2-3 large friendly tap buttons (Move, Attack, End Turn) with rounded corners
- No side panels, no logs, no complex HUD
- Damage/status shown as small floating bubbles on units

ON THE BOARD:
- A cute teal player character (simple geometric shape, friendly)
- 1-2 lavender/purple translucent ghost allies with gentle trailing effect
- 2 coral/red enemies, simple shapes
- A few wall tiles, clean geometric
- Move range shown as soft green highlighted tiles
- Ghost path shown as dotted lavender line

FEEL: This looks like a puzzle game you'd play on your phone during commute. Calm, think-y, no stress. Like a chess puzzle app with beautiful minimal design. The time loop mechanic is a brain teaser, not an action challenge.

This should look like a polished indie puzzle game screenshot ready for App Store feature.""",
        "size": "1024x1536",
    },
    {
        "id": "layout_B_tactical_roguelike",
        "prompt": f"""{GAME_CONTEXT}

Design a HARDCORE TACTICAL ROGUELIKE battle screen — information-rich, PC-focused:

LAYOUT: Widescreen 16:9 landscape. Isometric 8x8 grid takes up the left 65%. Right side has a dense info panel. Bottom has action bar.

STYLE:
- Dark, atmospheric, pixel art with modern polish (think XCOM meets Slay the Spire UI density)
- Dark indigo/navy background
- CRT scanline subtle overlay
- Glowing grid lines on dark tiles
- Color palette: dark navy base, bright teal player, electric purple ghosts, aggressive red-orange enemies
- High contrast for readability in complex situations

UI ELEMENTS (dense but organized):
- TOP BAR: Turn counter, Timeline indicator (T2 of 3), lives as glowing shards, enemy count, a minimap or timeline scrubber
- RIGHT PANEL: 
  - Selected unit stats (HP bar, ATK, move range, status effects)
  - Turn order timeline showing all units (player, ghosts, enemies) in action sequence
  - Ghost replay schedule (what each ghost will do this turn)
  - Battle log (scrollable text of recent events)
- BOTTOM ACTION BAR: Move | Attack | Overwatch | Solidify | Use Item | End Turn — styled as tactical buttons with hotkey labels (Q/W/E/R/T/Y)
- Tooltip area for hovered tile info

ON THE BOARD:
- A detailed pixel art player character with teal energy glow
- 2 purple time ghosts with afterimage trail and projected fire lines (purple dashed arrows showing where they'll attack)
- 3-4 red-orange enemies with visible intent markers (red arrows showing planned movement, red target zones)
- Wall tiles, a time void (black hole tile), breakable cover
- Move range overlay (green tiles), attack range (red tiles), danger zone (orange warning tiles)
- Knockback preview arrows (yellow)
- Rich visual information density — player can read the full tactical situation at a glance

FEEL: This is a serious tactics game for PC players who love XCOM and Into the Breach. Dense information, lots of tools, complex decision-making. The time loop is a deep system you master over dozens of hours. Looks like a Steam Early Access tactical game with 50+ hours of content.

This should look like a polished indie tactics game screenshot ready for a Steam store page.""",
        "size": "1536x1024",
    },
]


def generate(prompt_data):
    resp = requests.post(
        GATEWAY_URL,
        json={
            "model": GATEWAY_MODEL,
            "prompt": prompt_data["prompt"],
            "n": 1,
            "size": prompt_data["size"],
            "quality": "high",
        },
        headers=gateway_headers(),
        timeout=300,
    )
    resp.raise_for_status()
    return base64.b64decode(resp.json()["data"][0]["b64_json"])


if __name__ == "__main__":
    for item in PROMPTS:
        out_path = output_dir / f"{item['id']}.png"
        print(f"[{item['id']}] generating...")
        try:
            img_bytes = generate(item)
            out_path.write_bytes(img_bytes)
            print(f"  saved: {out_path} ({len(img_bytes) // 1024}KB)")
        except Exception as e:
            print(f"  FAILED: {e}")

    print("\nDone! Check layout_concepts/ folder.")
