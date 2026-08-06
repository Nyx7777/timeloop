# Runtime assets

Only Godot runtime-ready art, UI, audio, and font exports belong here. Editable source files stay in the repository-level `source_assets` directory once that pipeline is needed.

详细密度、同角色变体、导入缓存和验收规则见 `时间循环玩法/战场美术素材规范.md`。

## Environment

- `environment/lab_floor_tile.png`：M4.2A 明亮实验室单格地砖，256×256 高清密度。
- `environment/lab_obstacle_server.png`：M4.2A 单格服务器机柜，256×320 高清密度战术压缩版画布、底部锚定。
- `environment/lab_obstacle_pillar.png`：M4.2A 单格实验室立柱，256×320 高清密度战术压缩版画布、底部锚定。
- `environment/time_void_tile.png`：M4.2B 时间空洞单格素材，256×256，不越界；紫色旋涡完整限制在逻辑格内。
- 对应透明源图、候选规格和 ImageGen 提示词位于 `source_assets/environment/m42a/`。

## Characters

- `characters/player_idle.png`：M4.2B v2 本体静态战斗基准；青发、白色实验对象囚服、无武装，192×256、底部居中锚定。
- `characters/ghost_idle.png`：从本体透明母版逐像素派生的紫色时间投影，192×256；禁止使用独立人物图重新生成。
- `characters/guard_idle.png`：当前六关普通敌人的运行时显示；采用红橙裂隙的时间错位研究员，192×256。
- `characters/enemy_subject_idle.png`：失败实验体候选，192×256；保留给未来独立敌人类型，当前六关不加载。
- 三类角色在棋盘内按约 1.18 格画布高绘制，始终保持 3:4 原始宽高比，不允许用独立宽/高常量拉伸；所属格由格内扁椭圆脚底环和底部 HP 条辅助辨认。
- 角色从高分辨率像素源缩小时使用最近邻硬采样；UI 和环境仍可按各自用途使用平滑缩放。运行时继续使用最近邻过滤并将角色绘制矩形对齐到整数像素。
- 第一版候选位于 `source_assets/characters/m42b/`；当前 v2 绿幕源图和提示词位于 `source_assets/characters/m42b_v2/`。

## UI

- `ui/m42c/button_*_9patch.png`：移动、攻击、固化和结束回合四种 64×40 九宫格按钮底图。
- `ui/m42c/hud_panel_top.png`：顶部状态 HUD 九宫格底图，128×32。
- `ui/m42c/hint_bar_bg.png`：情境提示条九宫格底图，128×20。
- `ui/m42c/sequence_frame_active.png` / `sequence_frame_inactive.png`：行动序列当前项与普通项边框，48×48。
- `ui/m42c/hp_bar_player.png` / `hp_bar_enemy.png`：本体与敌人血条底图，64×12；运行时仍按权威 HP 比例遮罩。
- `ui/m42c/board_frame_border.png`：只包围真实 8×8 棋盘矩形的碎裂时间边框，96×96 九宫格源。

## Export pipeline

- 绿幕源图先使用已安装 imagegen 技能的 `remove_chroma_key.py` 转为 RGBA，再运行 `tools/export_m42_runtime_assets.py` 统一裁切、缩放、底部锚定并验证透明通道；角色导出固定使用最近邻硬采样，分身固定由本体透明图派生。
- 生成脚本只从环境变量 `TIMELOOP_IMAGE_GATEWAY_TOKEN` 读取图片网关凭据；不得把密钥写回仓库。
