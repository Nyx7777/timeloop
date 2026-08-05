# M4.2B 角色美术基准

> 状态：2026-08-05 第一轮实机候选；等待用户评审本体、分身和普通守卫的轮廓、尺寸及阵营辨识度。

## 运行时导出

- `player_alpha.png`、`ghost_alpha.png`、`guard_alpha.png`：移除色键后的完整透明源图。
- 运行时统一裁切透明边界，以最近邻缩放到底部对齐的 48×64 PNG：`game/assets/characters/*_idle.png`。
- 可见主体目标高度 58 像素，脚底基线位于画布 y=61；运行时由 `BattleBoardView` 按约 1.18 格画布高、1.10 格画布宽绘制。
- 角色实际可见轮廓约 1.05 格高，向上越界约 30%；脚底圆环和底部 HP 条留在所属格内，遵守 D-026。
- 当前只建立静态战斗姿态和角色身份，不提前生成四方向、移动、攻击、受击、死亡或固化动画。

## 视觉分工

- 本体：青色短发、浅色实验室外套、深蓝行动服和时间装置，青色脚底环。
- 分身：与本体保持同一轮廓和姿态，改为紫色投影、亮紫描边和少量短距离像素错位；源图保持实色，运行时仅轻微降低透明度。
- 守卫：红橙头盔与装甲、黑灰制服和封闭式横向面罩，红色脚底环。
- 三类角色都保持武器贴近身体，不让枪械或拖尾跨入相邻格形成错误占位暗示。

## ImageGen 提示词

使用内置 ImageGen；`02_characters.png` 作为角色身份参考，`13_full_hud_max_complexity.png` 作为锁定的近俯视战场风格和尺度参考。生成图使用纯色 `#00ff00` 背景，再通过本地色键移除生成透明源图；纯绿色中间图不纳入项目版本库。

### 本体

```text
Use case: stylized-concept
Asset type: single runtime-ready pixel-art tactical game character sprite source
Input images: Image 1 is the established character-design reference; Image 2 is the locked mobile battle visual and near-top-down scale reference. Generate a new isolated asset, do not edit the references.
Primary request: create exactly one full-body player character for a bright-laboratory time-loop tactics game.
Subject: the same visual identity as the established chrono analyst: compact young field researcher, short tousled cyan/teal hair, dark navy tactical undersuit, short pale laboratory jacket with cyan trim, compact temporal sidearm held close across the body, small cyan time-device at the belt. Alert neutral combat-ready stance, readable heroic silhouette, no exaggerated cape or loose accessories.
Style/medium: crisp hand-authored 2D pixel art matching both references, limited palette, chunky pixel clusters, strong silhouette, designed to reduce cleanly to a 48×64 game sprite with nearest-neighbor scaling.
Composition/framing: exactly one centered full-body character, near-top-down camera only 10–15 degrees off vertical, three-quarter front view facing slightly toward screen right, both feet visible on one shared bottom baseline, bottom-center anchor, body no wider than about 0.85 of one square board cell and visual height about 1.25 cells, generous empty padding on all sides.
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background. One uniform color only, with no shadows, gradients, texture, floor plane, reflection, glow spill, or lighting variation.
Color palette: dark navy and cool gray clothing, pale jacket, restrained bright cyan hair and time-energy accents. Do not use #00ff00 anywhere in the character.
Constraints: exactly one character; fully opaque hard-edged pixel silhouette; no cast shadow; no contact shadow; no floating effects; no text; no UI; no floor tile; no extra props; no logo; no watermark.
Avoid: sprite sheet, multiple poses, portrait framing, chibi oversized head, realistic painting, 3D render, isometric 45-degree view, blurry antialiasing, neon aura.
```

### 普通守卫

```text
Use case: stylized-concept
Asset type: single runtime-ready pixel-art tactical game character sprite source
Input images: Image 1 is the established character-design reference; Image 2 is the locked mobile battle visual and near-top-down scale reference. Generate a new isolated asset, do not edit the references.
Primary request: create exactly one full-body normal laboratory security guard enemy for a bright-laboratory time-loop tactics game.
Subject: compact human security trooper in red-orange armored helmet with a single dark horizontal visor, dark charcoal padded tactical uniform, red-orange chest and shoulder plates, heavy boots, compact security carbine held close across the body. Ordinary rank-and-file guard, sturdy and threatening but clearly smaller and simpler than an elite or boss.
Style/medium: crisp hand-authored 2D pixel art matching both references, limited palette, chunky pixel clusters, strong enemy silhouette, designed to reduce cleanly to a 48×64 game sprite with nearest-neighbor scaling.
Composition/framing: exactly one centered full-body character, near-top-down camera only 10–15 degrees off vertical, three-quarter front view facing slightly toward screen left, both feet visible on one shared bottom baseline, bottom-center anchor, body no wider than about 0.9 of one square board cell and visual height about 1.25 cells, generous empty padding on all sides.
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background. One uniform color only, with no shadows, gradients, texture, floor plane, reflection, glow spill, or lighting variation.
Color palette: dark charcoal and muted black uniform, red-orange armor, tiny restrained red indicator pixels. Do not use #00ff00 anywhere in the character.
Constraints: exactly one character; fully opaque hard-edged pixel silhouette; no cast shadow; no contact shadow; no floating effects; no text; no UI; no floor tile; no extra props; no logo; no watermark.
Avoid: sprite sheet, multiple poses, portrait framing, giant mech, elite armor, cape, chibi oversized head, realistic painting, 3D render, isometric 45-degree view, blurry antialiasing, neon aura.
```

### 分身

```text
Use case: precise-object-edit
Asset type: single runtime-ready pixel-art tactical game time-ghost sprite source
Input images: Image 1 is the edit target and exact player-character identity, pose, framing, scale, and pixel-style anchor.
Primary request: transform only the character into their time-ghost replay state.
Changes: recolor the character into a high-contrast violet and lavender temporal projection; keep the darkest navy pixels as deep purple; make the face less natural and slightly shadowed; add a crisp lavender outer rim and a few short horizontal pixel-displacement cuts inside the silhouette. Add only 3–5 tiny square glitch fragments immediately behind the character toward screen left, extending no farther than roughly 10% of the character width.
Invariants: preserve the exact same body proportions, hairstyle silhouette, clothing shapes, weapon, pose, near-top-down camera, full-body framing, foot positions, bottom baseline, scale, centered placement, hard-edged pixel clusters, and generous padding from Image 1. Keep the background perfectly flat uniform solid #00ff00 with no shadows, gradients, texture, floor plane, reflection, glow spill, or lighting variation. Do not use #00ff00 in the subject.
Constraints: one fully opaque character only; no translucency baked into the source; no aura; no cast or contact shadow; no long motion trail; no text; no UI; no floor; no extra props; no logo; no watermark.
```
