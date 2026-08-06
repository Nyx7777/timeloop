# Runtime assets

Only Godot runtime-ready art, UI, audio, and font exports belong here. Editable source files stay in the repository-level `source_assets` directory once that pipeline is needed.

## Environment

- `environment/lab_floor_tile.png`：M4.2A 明亮实验室单格地砖，64×64。
- `environment/lab_obstacle_server.png`：M4.2A 单格服务器机柜，64×80 战术压缩版画布、底部锚定。
- `environment/lab_obstacle_pillar.png`：M4.2A 单格实验室立柱，64×80 战术压缩版画布、底部锚定。
- `environment/time_void_tile.png`：M4.2B 时间空洞单格素材，64×64，不越界；紫色旋涡完整限制在逻辑格内。
- 对应透明源图、候选规格和 ImageGen 提示词位于 `source_assets/environment/m42a/`。

## Characters

- `characters/player_idle.png`：M4.2B v2 本体静态战斗基准；青发、白色实验对象囚服、无武装，48×64、底部居中锚定。
- `characters/ghost_idle.png`：M4.2B v2 分身静态战斗基准，沿用本体轮廓并使用紫色时间投影语言，48×64。
- `characters/guard_idle.png`：当前六关普通敌人的运行时显示；采用红橙裂隙的时间错位研究员，48×64。
- `characters/enemy_subject_idle.png`：失败实验体候选，48×64；保留给未来独立敌人类型，当前六关不加载。
- 三类角色在棋盘内按约 1.18 格画布高绘制，实际可见轮廓约 1.05 格高；所属格由脚底圆环和底部 HP 条辅助辨认。
- 第一版候选位于 `source_assets/characters/m42b/`；当前 v2 绿幕源图和提示词位于 `source_assets/characters/m42b_v2/`。

## UI

- `ui/m42c/button_*_9patch.png`：移动、攻击、固化和结束回合四种 64×40 九宫格按钮底图。
- `ui/m42c/hud_panel_top.png`：顶部状态 HUD 九宫格底图，128×32。
- `ui/m42c/hint_bar_bg.png`：情境提示条九宫格底图，128×20。
- `ui/m42c/sequence_frame_active.png` / `sequence_frame_inactive.png`：行动序列当前项与普通项边框，48×48。
- `ui/m42c/hp_bar_player.png` / `hp_bar_enemy.png`：本体与敌人血条底图，64×12；运行时仍按权威 HP 比例遮罩。
- `ui/m42c/board_frame_border.png`：只包围真实 8×8 棋盘矩形的碎裂时间边框，96×96 九宫格源。

## Export pipeline

- 绿幕源图先使用已安装 imagegen 技能的 `remove_chroma_key.py` 转为 RGBA，再运行 `tools/export_m42_runtime_assets.py` 统一裁切、缩放、底部锚定并验证透明通道。
- 生成脚本只从环境变量 `TIMELOOP_IMAGE_GATEWAY_TOKEN` 读取图片网关凭据；不得把密钥写回仓库。
