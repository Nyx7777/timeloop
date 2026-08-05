# Runtime assets

Only Godot runtime-ready art, UI, audio, and font exports belong here. Editable source files stay in the repository-level `source_assets` directory once that pipeline is needed.

## Environment

- `environment/lab_floor_tile.png`：M4.2A 明亮实验室单格地砖，64×64。
- `environment/lab_obstacle_server.png`：M4.2A 单格服务器机柜，64×80 战术压缩版画布、底部锚定。
- `environment/lab_obstacle_pillar.png`：M4.2A 单格实验室立柱，64×80 战术压缩版画布、底部锚定。
- 对应透明源图、候选规格和 ImageGen 提示词位于 `source_assets/environment/m42a/`。

## Characters

- `characters/player_idle.png`：M4.2B 本体静态战斗基准，48×64、底部居中锚定。
- `characters/ghost_idle.png`：M4.2B 分身静态战斗基准，沿用本体轮廓并使用紫色时间投影语言，48×64。
- `characters/guard_idle.png`：M4.2B 普通守卫静态战斗基准，红橙装甲与深色制服，48×64。
- 三类角色在棋盘内按约 1.18 格画布高绘制，实际可见轮廓约 1.05 格高；所属格由脚底圆环和底部 HP 条辅助辨认。
- 对应透明源图、候选规格和 ImageGen 提示词位于 `source_assets/characters/m42b/`。
