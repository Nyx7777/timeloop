# M4.2A 实验室环境基准

> 状态：2026-08-05 已接入候选版，等待用户在 390×844 实际战场中确认。

## 运行时导出

- `lab_floor_tile_alpha.png`：地砖透明源图；裁切透明边界后缩放为 `game/assets/environment/lab_floor_tile.png`（64×64）。
- `lab_wall_block_alpha.png`：墙体透明源图；裁切透明边界后等比缩放、底部对齐至 `game/assets/environment/lab_wall_block.png`（64×64 画布）。
- 运行时由 `BattleBoardView` 使用最近邻过滤绘制，点击判定、格子坐标和战术叠加层不依赖贴图尺寸。

## 当前候选规格

- 镜头：近俯视微倾斜，约 10—15° 偏离正上方；格子保持正方形，不使用 45° 菱形等距视角。
- 地砖：浅冷灰实验室面板，低对比磨损，细钢蓝接缝，青色指示像素仅作微弱点缀。
- 墙体：单格方形占位，顶部宽面 + 约 20—25% 正面厚度，底部锚定格子，避免灰盒阶段的堆叠方块感。
- 信息层级：环境保持低饱和、低噪声，红橙敌人、紫色分身与青色移动范围必须优先可读。

## ImageGen 提示词

使用内置 ImageGen，以 `时间循环玩法/demo/art_concepts/13_full_hud_max_complexity.png` 作为风格与配色参考；生成图使用纯色 `#00ff00` 背景，再通过本地色键移除生成透明源图。

### 地砖（最终迭代）

```text
Use case: precise-object-edit
Asset type: single runtime-ready pixel-art game floor tile source
Input images: Image 1 is the edit target.
Primary request: remove only the vertical and horizontal seams crossing the center so the image contains one single continuous square laboratory floor panel, not four sub-tiles.
Constraints: keep the outer border, pale cool-gray lab material, tiny cyan indicator pixels, restrained scratches, exact centered square footprint, crisp pixel-art style, scale, lighting, palette, and flat #00ff00 chroma-key background unchanged. The single panel interior must have no dividing grid lines or large internal seams. Background remains perfectly uniform #00ff00 with no shadows or gradients. No text, characters, props, wall, UI, logo, or watermark.
```

### 墙体

```text
Use case: stylized-concept
Asset type: single runtime-ready pixel-art game wall block source
Input images: Image 1 is the overall bright laboratory battlefield style reference; Image 2 is the approved floor-tile material and palette reference. Generate a new wall asset, do not edit either image.
Primary request: create exactly one low laboratory wall/solid obstacle occupying one square grid footprint, matching the pale cool-gray floor tile but clearly raised.
Subject: a clean modular sci-fi lab barrier seen from a near-top-down camera only 10–15 degrees off vertical; broad square top surface with beveled metal rim; a short visible front face about 20–25% of the total object height; two tiny restrained cyan status lights on the front face; subtle panel seams and minor wear. It must read instantly as blocking terrain, not as stacked crates.
Style/medium: crisp hand-authored 2D pixel art, limited palette, chunky pixel clusters, suitable to reduce to roughly 64×76 pixels with nearest-neighbor scaling.
Composition/framing: one centered wall block, fully isolated, front edge horizontal, exact square footprint, all corners and the short front face visible, generous uniform padding. No isometric diamond and no 45-degree view.
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background for local removal. Background must be one uniform color with no shadows, gradients, texture, floor plane, reflection, or lighting variation.
Color palette: pale cool gray top, darker steel blue-gray front face and seams, tiny cyan indicators. Do not use #00ff00 anywhere in the object.
Constraints: exactly one wall block; no cast shadow; no contact shadow; no text; no characters; no extra props; no floor tile beneath it; no UI; no logo; no watermark; crisp silhouette and generous padding.
Avoid: stacked boxes, crate, tall pillar, dark navy object, photorealism, 3D render, multiple wall pieces, wall sheet, diagonal diamond footprint.
```

