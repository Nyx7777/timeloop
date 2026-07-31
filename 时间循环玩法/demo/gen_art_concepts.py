"""
生成战棋美术概念图 — 调用 GPT Image 接口
输出到 art_concepts/ 文件夹
"""
import json
import base64
import requests
from pathlib import Path

GATEWAY_URL = "https://ai-gateway.testing.hetao101.com/v1/images/generations"
GATEWAY_TOKEN = "sk-YUzzgANfKgt_hdJxvELK5g"
GATEWAY_MODEL = "azure.public.gpt-image-2"

HEADERS = {
    "Authorization": f"Bearer {GATEWAY_TOKEN}",
    "Content-Type": "application/json",
}

output_dir = Path(__file__).parent / "art_concepts"
output_dir.mkdir(exist_ok=True)

GAME_CONTEXT = """This is concept art for an indie tactical strategy game called "Time Loop Tactics" (时间循环战术).
Core visual direction:
- Pixel art style with high information density
- Core imagery: shattered mirror / time fragments — time is like a broken mirror, each shard shows a different moment
- CRT/glitch aesthetic: scanlines, color aberration, pixel displacement
- Dark background with glitch effects, old TV display error feel
- Color palette: dark navy/indigo base, teal/cyan for player, purple for time ghosts, red/orange for enemies
- The world is experiencing temporal collapse — cracks, afterimages, temporal residue everywhere
"""

PROMPTS = [
    {
        "id": "01_battle_ui",
        "prompt": f"""{GAME_CONTEXT}

Create a FULL GAME BATTLE SCREEN UI mockup for this pixel art tactical game:
- 8x8 grid battlefield taking up the center of the screen
- Dark indigo floor tiles with subtle glowing grid lines
- CRT scanline overlay across entire screen
- Top bar: timeline indicator, lives counter, turn number, HP bar
- Bottom: action buttons (Move, Attack, Overwatch, Solidify, End Turn) in pixel art style
- Left side: timeline track showing ghost actions per turn
- A player character (teal glow, pixel art, 32x32 style) standing on the grid
- 2 purple translucent time ghosts (afterimage effect, multiple offset frames) on other tiles
- 3 red-orange enemies with glitch/displacement effect on their sprites
- Some wall tiles with cracked/shattered texture
- Dark vignette around edges
- The overall feel should be: a broken CRT monitor showing a tactical game from a fractured timeline
- Style: pixel art UI, 16-bit era aesthetics mixed with modern glitch art
- Resolution should look like a complete game screenshot ready for a Steam store page""",
        "size": "1536x1024",
    },
    {
        "id": "02_characters",
        "prompt": f"""{GAME_CONTEXT}

Create a CHARACTER DESIGN SHEET (sprite sheet style) showing:
1. PLAYER CHARACTER — pixel art, facing 4 directions (down/up/left/right), teal-cyan glow outline, wearing a lab coat that's becoming torn/glitched, 32x32 pixel style but rendered at high res
2. TIME GHOST (分身) — same character but translucent purple, with 2-3 offset afterimage frames trailing behind, edges dissolving into mirror-shard particles
3. NORMAL ENEMY (时间错位体) — humanoid figure trapped in time, red-orange tint, body split into multiple time frames (head from one moment, limbs from another), pixel glitch tearing across the sprite
4. ELITE ENEMY — larger, multiple overlapping temporal states stacked, unstable form shifting, more intense glitch distortion
5. BOSS — a figure with full temporal awareness, eyes glowing, mirror shards orbiting around them, commanding presence

Layout: arrange all characters on a dark background with labels, sprite sheet style
Each character should be clearly distinct in silhouette and color
Pixel art style, but detailed enough to read the design intent""",
        "size": "1536x1024",
    },
    {
        "id": "03_atmosphere_lab",
        "prompt": f"""{GAME_CONTEXT}

Create an ATMOSPHERE CONCEPT for the LABORATORY TUTORIAL LEVEL:
- 8x8 grid battlefield in a clean, bright laboratory setting
- White/light gray floor tiles with subtle blue grid lines
- Fluorescent lighting, everything clean and orderly
- Lab equipment on some tiles (consoles, containment chambers)
- The player character just starting out — clean, unglitched
- Sterile, safe, controlled scientific environment
- But subtle hints of something wrong: a single cracked tile, a flickering monitor in the corner, one scanline visible
- Color palette: mostly white, light gray, clinical blue, with tiny hints of the chaos to come
- Pixel art style tactical game screenshot
- This is the BEFORE — calm before the storm""",
        "size": "1024x1024",
    },
    {
        "id": "04_atmosphere_accident",
        "prompt": f"""{GAME_CONTEXT}

Create an ATMOSPHERE CONCEPT for the ACCIDENT / TRANSITION MOMENT:
- The same laboratory from the tutorial level, but now BREAKING APART
- Heavy CRT scanlines tearing across the screen
- Chromatic aberration — red/blue color split on everything
- Pixel displacement — parts of the image shifted/offset
- The grid tiles cracking, some floating, reality fragmenting
- Mirror-shard particles exploding outward from center
- The player character caught in the blast, body splitting into multiple temporal frames
- Colors: harsh transition from clean white to chaotic glitch colors (magenta, cyan noise, static)
- The feeling of a CRT monitor having a catastrophic failure
- VHS tracking error lines
- This is THE MOMENT everything breaks""",
        "size": "1024x1024",
    },
    {
        "id": "05_atmosphere_world",
        "prompt": f"""{GAME_CONTEXT}

Create an ATMOSPHERE CONCEPT for the MAIN GAME WORLD (outside the laboratory):
- 8x8 grid battlefield in a dark, temporally fractured environment
- Dark indigo/navy base with glitch effects everywhere
- Floor tiles cracked and displaced, some floating at different time-states
- CRT scanlines as a permanent overlay
- Multiple time ghosts (purple afterimages) moving across the field
- Enemies with temporal distortion (red-orange glitch sprites)
- Mirror shards floating in the air, each reflecting a different moment
- Broken clock/time imagery integrated into the environment
- The sky/background showing temporal collapse — like looking at a shattered screen
- Vignette darkness pressing in from edges
- Color: dark navy base, teal player, purple ghosts, red enemies, occasional harsh glitch white
- This is the MAIN GAME FEEL — oppressive, fractured, but tactically readable
- Pixel art style, must still be clear enough to play as a tactics game""",
        "size": "1024x1024",
    },
    {
        "id": "06_ui_elements",
        "prompt": f"""{GAME_CONTEXT}

Create a UI ELEMENTS DESIGN SHEET showing individual game interface components:
1. HP BAR — pixel art style, with subtle glitch flicker, teal for player / red for enemy
2. TIMELINE TRACK — horizontal track showing turn markers, ghost action icons, current turn indicator with glow
3. ACTION BUTTONS — pixel art bordered buttons: "Move" "Attack" "Overwatch" "Solidify" "End Turn", dark background with teal accent
4. TURN INDICATOR — "Turn 3 / Timeline 2" display with CRT styling
5. LIVES COUNTER — showing 3 lives as temporal fragments/mirror shards
6. DAMAGE NUMBERS — pixel font damage popups with red flash
7. GRID TILE STATES — normal tile, highlighted (move range, green tint), danger zone (red glow), ghost occupied (purple border)
8. DEATH EFFECT — mirror shard explosion particle burst
9. SOLIDIFY EFFECT — bright energy burst dissolving into light particles (lighter/happier than death)

Layout: dark background, each element clearly separated and labeled
Pixel art style with CRT/glitch accent effects""",
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
        headers=HEADERS,
        timeout=180,
    )
    resp.raise_for_status()
    return base64.b64decode(resp.json()["data"][0]["b64_json"])


if __name__ == "__main__":
    for item in PROMPTS:
        out_path = output_dir / f"{item['id']}.png"
        if out_path.exists():
            print(f"[{item['id']}] skip (already exists)")
            continue

        print(f"[{item['id']}] generating...")
        try:
            img_bytes = generate(item)
            out_path.write_bytes(img_bytes)
            print(f"  saved: {out_path} ({len(img_bytes) // 1024}KB)")
        except Exception as e:
            print(f"  FAILED: {e}")

    print("\nDone! Check art_concepts/ folder.")
