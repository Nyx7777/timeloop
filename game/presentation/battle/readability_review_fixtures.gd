class_name ReadabilityReviewFixtures
extends RefCounted


const SCENARIOS := [
	{
		"id": &"t1_unknown",
		"label": "1 · T1 未知｜第 1 关",
		"level_index": 0,
		"prompt": "2—3 秒读图：现在能否预知敌人行动？",
		"answer": "不能。T1 是未知时间，固定 0、清醒 0，棋盘不显示敌人路径或目标。",
	},
	{
		"id": &"t2_fixed",
		"label": "2 · T2 全固定｜第 2 关",
		"level_index": 1,
		"prompt": "2—3 秒读图：两名敌人分别移动/攻击哪里？",
		"answer": "E1 沿橙线移动后攻击本体；E2 原地攻击 G1。顶部应显示固定 2、清醒 0。",
	},
	{
		"id": &"crossed_paths",
		"label": "3 · 交叉路径｜第 3 关",
		"level_index": 2,
		"prompt": "2—3 秒读图：交叉意图能否按 E1—E4 分辨？",
		"answer": "四名敌人均固定；点击顶部 E 卡可只强化对应完整路径和攻击线。",
	},
	{
		"id": &"waiting",
		"label": "4 · 攻击 + 等待｜第 4 关",
		"level_index": 3,
		"prompt": "2—3 秒读图：谁会攻击，谁会等待？",
		"answer": "E1 原地攻击本体并显示 2伤；E2 固定等待并显示“等待”。",
	},
	{
		"id": &"mixed_awake",
		"label": "5 · 固定/待醒/清醒｜第 5 关",
		"level_index": 4,
		"prompt": "2—3 秒读图：谁固定、谁待醒、谁已清醒？",
		"answer": "E1 固定；E2 本回合仍锁定、下回合清醒；E3 已清醒，只显示 ?。",
	},
	{
		"id": &"boss_limit",
		"label": "6 · Boss 信息上限｜第 6 关",
		"level_index": 5,
		"prompt": "2—3 秒读图：最大信息量下还能否定位固定与清醒敌人？",
		"answer": "T3、两名分身、四名敌人、Boss/Build 只读信息同屏；前三名固定，E4 清醒。",
		"show_boss_rail": true,
	},
]

const LEVEL_PATHS := [
	"res://content/levels/first_echo.tres",
	"res://content/levels/crossed_paths.tres",
	"res://content/levels/purple_crossfire.tres",
	"res://content/levels/push_calibration.tres",
	"res://content/levels/collision_course.tres",
	"res://content/levels/falling_timeline.tres",
]


static func count() -> int:
	return SCENARIOS.size()


static func describe(index: int) -> Dictionary:
	return (SCENARIOS[index] as Dictionary).duplicate(true)


static func build_state(index: int) -> BattleState:
	var scenario := describe(index)
	var state := _base_state(int(scenario.level_index))
	match StringName(scenario.id):
		&"t1_unknown":
			return state
		&"t2_fixed":
			state.timeline_index = 2
			state.lives_left = 1
			state.turn_index = 2
			state.time_state = &"known"
			state.ghost_positions = {&"ghost_t1": Vector2i(4, 4)}
			state.get_unit(state.player_id).position = Vector2i(3, 5)
			state.locked_enemy_intents = [
				_intent(&"guard_01", Vector2i(1, 4), [Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4)], Vector2i(3, 5)),
				_intent(&"guard_02", Vector2i(5, 4), [Vector2i(5, 4)], Vector2i(4, 4), &"attack"),
			]
		&"crossed_paths":
			state.timeline_index = 3
			state.lives_left = 1
			state.turn_index = 3
			state.time_state = &"known"
			state.ghost_positions = {&"ghost_t1": Vector2i(3, 5), &"ghost_t2": Vector2i(4, 3)}
			state.locked_enemy_intents = [
				_intent(&"guard_01", Vector2i(6, 1), [Vector2i(6, 1), Vector2i(5, 1), Vector2i(5, 2), Vector2i(4, 2)], Vector2i(4, 3)),
				_intent(&"guard_02", Vector2i(2, 5), [Vector2i(2, 5), Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4)], Vector2i(4, 3)),
				_intent(&"guard_03", Vector2i(6, 6), [Vector2i(6, 6), Vector2i(5, 6), Vector2i(4, 6), Vector2i(3, 6)], Vector2i(3, 5)),
				_intent(&"guard_04", Vector2i(1, 3), [Vector2i(1, 3), Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4)], Vector2i(3, 5)),
			]
		&"waiting":
			state.timeline_index = 2
			state.lives_left = 1
			state.turn_index = 2
			state.time_state = &"known"
			state.ghost_positions = {&"ghost_t1": Vector2i(5, 5)}
			state.locked_enemy_intents = [
				_intent(&"guard_01", Vector2i(1, 6), [Vector2i(1, 6)], Vector2i(1, 7), &"attack"),
				_intent(&"guard_02", Vector2i(5, 4), [Vector2i(5, 4)], Vector2i(-1, -1), &"wait"),
			]
		&"mixed_awake":
			state.timeline_index = 3
			state.lives_left = 1
			state.turn_index = 3
			state.time_state = &"disturbed"
			state.ghost_positions = {&"ghost_t1": Vector2i(4, 4), &"ghost_t2": Vector2i(4, 3)}
			state.locked_enemy_intents = [
				_intent(&"guard_01", Vector2i(2, 5), [Vector2i(2, 5), Vector2i(3, 5), Vector2i(3, 4)], Vector2i(4, 4)),
				_intent(&"guard_02", Vector2i(5, 2), [Vector2i(5, 2), Vector2i(4, 2), Vector2i(4, 3)], Vector2i(4, 4)),
				_intent(&"guard_03", Vector2i(7, 5), [Vector2i(7, 5)], Vector2i(6, 5), &"attack", true),
			]
			state.get_unit(&"guard_02").statuses = {"disturbed": true, "awake_from_turn": 4}
			state.get_unit(&"guard_03").statuses = {"disturbed": true, "awake_from_turn": 3}
		&"boss_limit":
			state.timeline_index = 3
			state.lives_left = 1
			state.turn_index = 6
			state.time_state = &"disturbed"
			state.ghost_positions = {&"ghost_t1": Vector2i(0, 6), &"ghost_t2": Vector2i(2, 6)}
			state.get_unit(state.player_id).position = Vector2i(0, 5)
			state.locked_enemy_intents = [
				_intent(&"guard_01", Vector2i(1, 5), [Vector2i(1, 5), Vector2i(1, 4), Vector2i(0, 4)], Vector2i(0, 5)),
				_intent(&"guard_02", Vector2i(3, 4), [Vector2i(3, 4), Vector2i(4, 4), Vector2i(4, 5)], Vector2i(4, 6)),
				_intent(&"guard_03", Vector2i(5, 2), [Vector2i(5, 2)], Vector2i(-1, -1), &"wait"),
				_intent(&"guard_04", Vector2i(7, 5), [Vector2i(7, 5)], Vector2i(6, 5), &"attack", true),
			]
			state.get_unit(&"guard_04").statuses = {"disturbed": true, "awake_from_turn": 6}
	return state


static func _base_state(level_index: int) -> BattleState:
	var level := load(LEVEL_PATHS[level_index]) as LevelDefinition
	return BattleStateFactory.create_from_level(level, 20260809)


static func _intent(
	enemy_id: StringName,
	origin: Vector2i,
	path: Array[Vector2i],
	target: Vector2i,
	intent_type: StringName = &"move_attack",
	reactive := false
) -> Dictionary:
	return {
		"enemy_id": enemy_id,
		"from": origin,
		"to": path[path.size() - 1],
		"path": path,
		"last_direction": Vector2i.ZERO if path.size() <= 1 else path[path.size() - 1] - path[path.size() - 2],
		"target": target,
		"damage": 2,
		"intent_type": intent_type,
		"reactive": reactive,
	}
