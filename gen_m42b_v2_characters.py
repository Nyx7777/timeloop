"""
M4.2B v2 角色重制 — 囚服本体 + 时间扭曲敌人
参考图：02_characters.png (角色身份) + 13_full_hud_max_complexity.png (战场风格)
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

output_dir = Path(__file__).parent / "source_assets" / "characters" / "m42b_v2"
output_dir.mkdir(parents=True, exist_ok=True)

ref_dir = Path(__file__).parent / "时间循环玩法" / "demo" / "art_concepts"
ref_02 = ref_dir / "02_characters.png"
ref_13 = ref_dir / "13_full_hud_max_complexity.png"

PROMPTS = [
    {
        "id": "player_v2",
        "prompt": """Use case: stylized-concept
Asset type: single runtime-ready pixel-art tactical game character sprite source
Input images: Image 1 is the established character-design reference (use the PLAYER CHARACTER row for identity and pixel style); Image 2 is the locked mobile battle visual and near-top-down scale reference. Generate a new isolated asset, do not edit the references.
Primary request: create exactly one full-body player character for a bright-laboratory time-loop tactics game — this is Chapter 1, where the protagonist is a captive test subject escaping the facility.
Subject: a young captive experiment subject who just broke free. Short tousled cyan/teal hair (same identity as reference). Wearing a plain white hospital gown / prisoner jumpsuit with a visible subject number patch, barefoot or simple facility slippers. NO weapons, NO armor, NO gadgets — completely unarmed, hands empty or in a defensive stance. Lean build, slightly vulnerable but determined expression. The clothing is simple, wrinkled, institutional — not combat gear.
Style/medium: crisp hand-authored 2D pixel art matching both references, limited palette, chunky pixel clusters, strong silhouette, designed to reduce cleanly to a 48×64 game sprite with nearest-neighbor scaling.
Composition/framing: exactly one centered full-body character, near-top-down camera only 10–15 degrees off vertical, three-quarter front view facing slightly toward screen right, both feet visible on one shared bottom baseline, bottom-center anchor, body no wider than about 0.85 of one square board cell and visual height about 1.25 cells, generous empty padding on all sides.
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background. One uniform color only, with no shadows, gradients, texture, floor plane, reflection, glow spill, or lighting variation.
Color palette: white/light gray hospital gown, pale skin, cyan/teal hair as the only bright accent. Institutional, clinical feel. Do not use #00ff00 anywhere in the character.
Constraints: exactly one character; fully opaque hard-edged pixel silhouette; no cast shadow; no contact shadow; no floating effects; no text; no UI; no floor tile; no extra props; no logo; no watermark.
Avoid: sprite sheet, multiple poses, portrait framing, chibi oversized head, realistic painting, 3D render, isometric 45-degree view, blurry antialiasing, neon aura, weapons, guns, armor, tactical gear.""",
        "size": "1024x1024",
    },
    {
        "id": "enemy_researcher_v2",
        "prompt": """Use case: stylized-concept
Asset type: single runtime-ready pixel-art tactical game character sprite source
Input images: Image 1 is the established character-design reference (use the NORMAL ENEMY row for visual language: time-displaced, pixel glitch tears, red-orange energy); Image 2 is the locked mobile battle visual and near-top-down scale reference. Generate a new isolated asset, do not edit the references.
Primary request: create exactly one full-body time-distorted researcher enemy for a bright-laboratory time-loop tactics game.
Subject: a laboratory researcher who has been warped by temporal collapse. Originally wore a white lab coat over a dark shirt, but now the coat is partially torn and flickering between time states. The body shows visible temporal distortion: one arm is slightly offset/displaced from the main body, the head has a faint afterimage echo shifted a few pixels to one side, and 2-3 horizontal pixel-tear lines cut across the torso. Glowing red-orange energy leaks from the distortion cracks. Eyes glow a dim red-orange. Still recognizably human in shape but clearly wrong/broken. Holding a clipboard or data tablet that is also partially glitched. Stance is jerky, unnatural, puppet-like.
Style/medium: crisp hand-authored 2D pixel art matching both references, limited palette, chunky pixel clusters, strong enemy silhouette with visible glitch distortion, designed to reduce cleanly to a 48×64 game sprite with nearest-neighbor scaling.
Composition/framing: exactly one centered full-body character, near-top-down camera only 10–15 degrees off vertical, three-quarter front view facing slightly toward screen left, both feet visible on one shared bottom baseline, bottom-center anchor, body no wider than about 0.9 of one square board cell and visual height about 1.25 cells, generous empty padding on all sides.
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background. One uniform color only, with no shadows, gradients, texture, floor plane, reflection, glow spill, or lighting variation.
Color palette: white lab coat (partially stained/torn), dark undershirt, red-orange temporal energy accents, dim red eyes. Warm distortion colors against cold institutional clothing. Do not use #00ff00 anywhere in the character.
Constraints: exactly one character; fully opaque hard-edged pixel silhouette; no cast shadow; no contact shadow; no text; no UI; no floor tile; no extra props beyond the clipboard; no logo; no watermark.
Avoid: sprite sheet, multiple poses, portrait framing, full armor, military gear, giant mech, chibi oversized head, realistic painting, 3D render, isometric 45-degree view, blurry antialiasing, excessive neon aura that obscures the body.""",
        "size": "1024x1024",
    },
    {
        "id": "enemy_subject_v2",
        "prompt": """Use case: stylized-concept
Asset type: single runtime-ready pixel-art tactical game character sprite source
Input images: Image 1 is the established character-design reference (use the NORMAL ENEMY row for visual language: time-displaced, pixel glitch tears, red-orange energy); Image 2 is the locked mobile battle visual and near-top-down scale reference. Generate a new isolated asset, do not edit the references.
Primary request: create exactly one full-body time-distorted test subject enemy for a bright-laboratory time-loop tactics game.
Subject: another experiment subject (like the player) who failed to escape and was consumed by temporal collapse. Wears a tattered white hospital gown / prisoner jumpsuit similar to the player's but more damaged. The body is heavily warped: limbs stretched or compressed in places, torso has 3-4 horizontal pixel-displacement tears showing red-orange energy underneath, one arm is longer than the other due to time stretching. Face is obscured by temporal static — no clear features visible, just a smeared red-orange glow where the face should be. Barefoot, fingers elongated unnaturally. Stance is hunched, feral, reaching forward aggressively. This was once a person like the player — now a cautionary warning.
Style/medium: crisp hand-authored 2D pixel art matching both references, limited palette, chunky pixel clusters, strong threatening silhouette with heavy glitch distortion, designed to reduce cleanly to a 48×64 game sprite with nearest-neighbor scaling.
Composition/framing: exactly one centered full-body character, near-top-down camera only 10–15 degrees off vertical, three-quarter front view facing slightly toward screen left, both feet visible on one shared bottom baseline, bottom-center anchor, body no wider than about 0.9 of one square board cell and visual height about 1.25 cells, generous empty padding on all sides.
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background. One uniform color only, with no shadows, gradients, texture, floor plane, reflection, glow spill, or lighting variation.
Color palette: tattered white/gray hospital gown, exposed red-orange temporal energy through tears, face completely obscured by warm glitch static. More red-orange than the researcher variant — further gone into temporal collapse. Do not use #00ff00 anywhere in the character.
Constraints: exactly one character; fully opaque hard-edged pixel silhouette; no cast shadow; no contact shadow; no text; no UI; no floor tile; no extra props; no logo; no watermark.
Avoid: sprite sheet, multiple poses, portrait framing, full armor, military gear, weapons in hand, chibi oversized head, realistic painting, 3D render, isometric 45-degree view, blurry antialiasing, excessive neon aura that completely obscures the body shape.""",
        "size": "1024x1024",
    },
]


def generate_with_refs(prompt_text, size, ref_images):
    """Generate image with reference images using the edits endpoint."""
    import io

    # Use the generations endpoint with image references encoded in prompt
    # The gateway supports image input via the edits endpoint
    payload = {
        "model": GATEWAY_MODEL,
        "prompt": prompt_text,
        "n": 1,
        "size": size,
        "quality": "high",
    }

    # Try with image references if the endpoint supports it
    # Fall back to text-only if needed
    if ref_images:
        payload["image"] = []
        for ref_path in ref_images:
            with open(ref_path, "rb") as f:
                img_b64 = base64.b64encode(f.read()).decode()
            payload["image"].append({
                "type": "base64",
                "data": img_b64,
            })

    resp = requests.post(
        GATEWAY_URL,
        json=payload,
        headers=HEADERS,
        timeout=300,
    )
    if resp.status_code != 200:
        # Fallback: try without images
        print(f"  Image ref failed ({resp.status_code}), trying text-only...")
        payload.pop("image", None)
        resp = requests.post(
            GATEWAY_URL,
            json=payload,
            headers=HEADERS,
            timeout=300,
        )
    resp.raise_for_status()
    return base64.b64decode(resp.json()["data"][0]["b64_json"])


if __name__ == "__main__":
    refs = [str(ref_02), str(ref_13)]

    for item in PROMPTS:
        out_path = output_dir / f"{item['id']}_alpha.png"
        if out_path.exists():
            print(f"[{item['id']}] skip (already exists)")
            continue

        print(f"[{item['id']}] generating with refs...")
        try:
            img_bytes = generate_with_refs(item["prompt"], item["size"], refs)
            out_path.write_bytes(img_bytes)
            print(f"  saved: {out_path} ({len(img_bytes) // 1024}KB)")
        except Exception as e:
            print(f"  FAILED: {e}")

    print("\nDone! Check", output_dir)
