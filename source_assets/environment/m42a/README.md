# M4.2A 实验室环境基准

> 状态：2026-08-05 普通地砖已获用户认可；低墙候选被否决，已按参考图 11/12 改为服务器与实验室立柱，等待第二轮实战确认。

## 运行时导出

- `lab_floor_tile_alpha.png`：地砖透明源图；裁切透明边界后缩放为 `game/assets/environment/lab_floor_tile.png`（64×64）。
- `lab_server_alpha.png`：服务器透明源图；裁切透明边界后缩放、底部对齐至 `game/assets/environment/lab_obstacle_server.png`（64×96 画布）。
- `lab_pillar_alpha.png`：立柱透明源图；裁切透明边界后缩放、底部对齐至 `game/assets/environment/lab_obstacle_pillar.png`（64×96 画布）。
- 运行时由 `BattleBoardView` 使用最近邻过滤绘制，点击判定、格子坐标和战术叠加层不依赖贴图尺寸。

## 当前候选规格

- 镜头：近俯视微倾斜，约 10—15° 偏离正上方；格子保持正方形，不使用 45° 菱形等距视角。
- 地砖：浅冷灰实验室面板，低对比磨损，细钢蓝接缝，青色指示像素仅作微弱点缀。
- 不可通行格：不使用抽象低墙；由服务器机柜、实验室立柱等实体设备承担阻挡语义。设备底部只占一个逻辑格，精灵向上延伸约半格，并按行从后向前绘制。
- 设备变体：当前按格子坐标稳定交错服务器与立柱，只改变表现，不增加第二套关卡碰撞数据。
- 信息层级：环境保持低饱和、低噪声，红橙敌人、紫色分身与青色移动范围必须优先可读。

## ImageGen 提示词

使用内置 ImageGen；地砖以 `13_full_hud_max_complexity.png` 为风格参考，障碍物以 `11_ui_max_complexity_frame.png`、`12_ui_near_topdown_max_complexity.png` 和已确认地砖为参考。生成图使用纯色 `#00ff00` 背景，再通过本地色键移除生成透明源图。

### 地砖（最终迭代）

```text
Use case: precise-object-edit
Asset type: single runtime-ready pixel-art game floor tile source
Input images: Image 1 is the edit target.
Primary request: remove only the vertical and horizontal seams crossing the center so the image contains one single continuous square laboratory floor panel, not four sub-tiles.
Constraints: keep the outer border, pale cool-gray lab material, tiny cyan indicator pixels, restrained scratches, exact centered square footprint, crisp pixel-art style, scale, lighting, palette, and flat #00ff00 chroma-key background unchanged. The single panel interior must have no dividing grid lines or large internal seams. Background remains perfectly uniform #00ff00 with no shadows or gradients. No text, characters, props, wall, UI, logo, or watermark.
```

### 服务器机柜

```text
Use case: stylized-concept
Asset type: single runtime-ready pixel-art laboratory obstacle sprite
Input images: Image 1 and Image 2 are composition and equipment-style references; Image 3 is the approved floor material and palette reference. Generate a new isolated asset, do not edit the references.
Primary request: create exactly one tall single-cell laboratory server cabinet that replaces an abstract wall tile as blocking terrain.
Subject: a compact rectangular server rack / scientific data cabinet, pale cool-gray metal frame, dark steel-blue recessed front panel, several crisp horizontal equipment bays, tiny cyan status lights and one small cyan display. It must read immediately as laboratory machinery and solid impassable cover, not as a wall, crate, vending machine, or computer desk.
Style/medium: crisp hand-authored 2D pixel art matching the references, limited palette, chunky pixel clusters, suitable to reduce to a 64×80 game sprite with nearest-neighbor scaling.
Composition/framing: one centered full object, near-top-down camera only 10–15 degrees off vertical, front face visible, front edge horizontal, narrow square floor footprint, object taller than its footprint, bottom-center anchor, generous padding above and beside it. No isometric diamond and no 45-degree view.
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background. One uniform color only: no shadows, gradients, texture, floor plane, reflection, or lighting variation.
Color palette: pale cool gray housing, medium and dark blue-gray equipment panels, restrained cyan indicator lights, tiny orange warning pixel at most. Do not use #00ff00 anywhere in the object.
Constraints: exactly one server cabinet; no cast shadow; no contact shadow; no cables leaving the footprint; no text; no characters; no extra props; no floor tile; no UI; no logo; no watermark; crisp isolated silhouette.
Avoid: wall block, low box, stacked crate, wide console table, cylindrical tank, photorealism, 3D render, multiple objects, sprite sheet.
```

### 实验室立柱

```text
Use case: stylized-concept
Asset type: single runtime-ready pixel-art laboratory obstacle sprite
Input images: Image 1 and Image 2 are composition and equipment-style references; Image 3 is the approved floor material and palette reference. Generate a new isolated asset, do not edit the references.
Primary request: create exactly one tall single-cell laboratory structural utility pillar that replaces an abstract wall tile as blocking terrain.
Subject: a sturdy rectangular lab support column / powered utility pillar with a square floor footprint, pale cool-gray armored casing, darker blue-gray recessed side panels, one narrow vertical cyan light strip, a small maintenance hatch, subtle seams and corner braces. It must read immediately as a permanent laboratory column and solid impassable cover, distinct from the server cabinet.
Style/medium: crisp hand-authored 2D pixel art matching the references, limited palette, chunky pixel clusters, suitable to reduce to a 64×80 game sprite with nearest-neighbor scaling.
Composition/framing: one centered full object, near-top-down camera only 10–15 degrees off vertical, top cap and front face both visible, front edge horizontal, compact square footprint, object taller than its footprint, bottom-center anchor, generous padding above and beside it. No isometric diamond and no 45-degree view.
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background. One uniform color only: no shadows, gradients, texture, floor plane, reflection, or lighting variation.
Color palette: pale cool gray armor, medium and dark steel blue-gray inset panels, restrained cyan light strip. Do not use #00ff00 anywhere in the object.
Constraints: exactly one structural pillar; no cast shadow; no contact shadow; no cables; no screen full of rack bays; no text; no characters; no extra props; no floor tile; no UI; no logo; no watermark; crisp isolated silhouette.
Avoid: wall block, low box, stacked crate, server rack, computer desk, cylindrical tank, glass tube, photorealism, 3D render, multiple objects, sprite sheet.
```
