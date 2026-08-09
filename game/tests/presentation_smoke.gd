extends SceneTree

const EnemyIntentPresentationScript := preload("res://presentation/battle/enemy_intent_presentation.gd")

var _failures: PackedStringArray = []
var _checks := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_pixel_art_render_settings()
	_test_high_density_battle_assets()
	_test_enemy_intent_presentation_snapshots()
	await _test_state_sync_clears_preview_cache()
	await _test_touch_input_maps_to_grid()
	await _test_event_driven_animation_states()
	await _test_playback_speeds_keep_identical_results()

	var packed_scene := load("res://presentation/battle/battle_screen.tscn") as PackedScene
	_expect(packed_scene != null, "battle screen scene loads")
	if packed_scene == null:
		_finish()
		return

	var screen := packed_scene.instantiate() as BattleScreen
	root.add_child(screen)
	await process_frame
	_expect(screen != null, "battle screen instantiates")
	if screen == null:
		_finish()
		return
	_test_mobile_layout(screen)

	screen.select_level_for_test(0)
	screen.set_instant_playback_for_test()
	var state := _state_from_screen(screen)
	_expect_equal(state.phase, BattlePhase.PLAYER_INPUT, "screen starts in player input")
	_expect(not bool(screen.get_ui_snapshot_for_test().end_turn_disabled), "initial controls are enabled")
	_expect_equal(screen.get_ui_snapshot_for_test().fixed_text, "固定 0", "unknown time shows no fixed enemies in the command rail")
	_expect_equal(screen.get_ui_snapshot_for_test().awake_text, "清醒 0", "unknown time shows no awake enemies in the command rail")
	_expect_equal(screen.get_ui_snapshot_for_test().sequence_portrait_modes.get("本体"), "upper_body", "command rail uses an upper-body player portrait")
	_expect_equal(screen.get_ui_snapshot_for_test().sequence_portrait_modes.get("E1"), "upper_body", "command rail uses upper-body enemy portraits")
	_expect_equal(screen.get_ui_snapshot_for_test().tutorial_focus_target, "move", "first battle opens with a non-blocking move focus")
	_expect(bool(screen.get_ui_snapshot_for_test().tutorial_other_actions_dimmed), "tutorial focus dims secondary actions")
	_expect_equal(screen.get_ui_snapshot_for_test().action_icons.move, "res://assets/ui/m50a/icon_move.png", "move control uses a standalone icon asset")
	_expect_equal(screen.get_ui_snapshot_for_test().action_icons.attack, "res://assets/ui/m50a/icon_attack.png", "attack control uses a standalone icon asset")
	_expect_equal(screen.get_ui_snapshot_for_test().action_icons.crystallize, "res://assets/ui/m50a/icon_lock.png", "locked crystallize control uses a standalone lock icon")
	_expect_equal(screen.get_ui_snapshot_for_test().action_icons.end_turn, "res://assets/ui/m50a/icon_end_turn.png", "end-turn control uses a standalone icon asset")
	_expect_equal(screen.get_ui_snapshot_for_test().action_plates.move.normal, "res://assets/ui/m50a/button_plate_move.png", "move control uses one coherent normal plate")
	_expect_equal(screen.get_ui_snapshot_for_test().action_plates.move.selected, "res://assets/ui/m50a/button_plate_selected_move.png", "move control uses a matching selected plate")
	_expect_equal(screen.get_ui_snapshot_for_test().action_plates.attack.normal, "res://assets/ui/m50a/button_plate_attack.png", "attack control uses one coherent normal plate")
	_expect_equal(screen.get_ui_snapshot_for_test().action_plates.attack.selected, "res://assets/ui/m50a/button_plate_selected_attack.png", "attack control uses a matching selected plate")
	_expect(not bool(screen.get_ui_snapshot_for_test().action_legacy_frame_visible), "action controls remove the obsolete outer-line frame layer")
	_expect_equal(screen.get_ui_snapshot_for_test().action_inner_glows.move, "res://assets/ui/m50a/button_inner_glow_move.png", "move control uses the restrained inner glow asset")
	_expect_equal(screen.get_ui_snapshot_for_test().action_inner_glows.attack, "res://assets/ui/m50a/button_inner_glow_attack.png", "attack control uses the restrained inner glow asset")
	_expect_equal(screen.get_ui_snapshot_for_test().action_inner_glows.crystallize, "res://assets/ui/m50a/button_inner_glow_crystallize.png", "crystallize control uses the restrained inner glow asset")
	_expect_equal(screen.get_ui_snapshot_for_test().action_inner_glows.end_turn, "res://assets/ui/m50a/button_inner_glow_end_turn.png", "end-turn control uses the restrained inner glow asset")
	_expect_equal(screen.get_ui_snapshot_for_test().crystallize_caption, "固化", "locked crystallize control keeps a single-line caption")
	screen.open_debug_overlay_for_test()
	_expect(bool(screen.get_ui_snapshot_for_test().debug_overlay_visible), "playtest menu exposes the review entry")
	_expect_equal(screen.get_ui_snapshot_for_test().boss_review_button_text, "进入 M5.0A · Boss + Build 评审态", "playtest menu names the non-level review state explicitly")
	screen.close_debug_overlay_for_test()
	screen.enter_boss_build_review_for_test()
	_expect(bool(screen.get_ui_snapshot_for_test().boss_build_review_visible), "maximum-information review exposes the boss and build rail")
	_expect(bool(screen.get_ui_snapshot_for_test().boss_build_review_mode), "maximum-information review is a dedicated read-only mode")
	_expect_equal(_state_from_screen(screen).timeline_index, 3, "review menu enters the T3 maximum-information fixture")
	_expect_equal(screen.get_ui_snapshot_for_test().boss_review_button_text, "退出评审态并返回原关卡", "review menu exposes an explicit exit")
	screen.exit_boss_build_review_for_test()
	_expect(not bool(screen.get_ui_snapshot_for_test().boss_build_review_mode), "exiting review restores normal battle mode")
	await _test_m50c_readability_review(screen)
	screen.set_action_mode_for_test(&"move")
	_expect(bool(screen.get_ui_snapshot_for_test().move_selected), "move control exposes the persistent selected state")
	_expect(not bool(screen.get_ui_snapshot_for_test().attack_selected), "selecting move leaves attack unselected")
	screen.set_action_mode_for_test(&"smart")

	await screen.submit_command_for_test(BattleCommand.move(&"player", Vector2i(1, 6)))
	_expect_equal(screen.get_ui_snapshot_for_test().tutorial_focus_target, "", "tutorial focus clears after the first move")
	await screen.submit_command_for_test(BattleCommand.attack(&"player", Vector2i(1, 5)))
	state = _state_from_screen(screen)
	_expect_equal(state.get_unit(&"guard_01").hp, 2, "presentation submits movement and attack")

	await screen.submit_command_for_test(BattleCommand.end_turn(&"player"))
	state = _state_from_screen(screen)
	_expect_equal(state.phase, BattlePhase.TIMELINE_TRANSITION, "death shows timeline transition")
	_expect(bool(screen.get_ui_snapshot_for_test().next_timeline_visible), "next timeline control becomes visible")

	await screen.submit_command_for_test(BattleCommand.start_next_timeline())
	state = _state_from_screen(screen)
	_expect_equal(state.timeline_index, 2, "screen starts the second timeline")
	_expect_equal(state.ghost_positions.get(&"ghost_t1"), Vector2i(1, 6), "ghost playback updates the board model")
	_expect_equal(screen.get_ui_snapshot_for_test().fixed_text, "固定 1", "known time counts the fixed enemy in the command rail")
	_expect_equal(screen.get_ui_snapshot_for_test().awake_text, "清醒 0", "known time keeps the awake count at zero")
	_expect_equal(screen.get_ui_snapshot_for_test().sequence_temporal_states.get("E1"), "定", "fixed enemy sequence card carries the fixed-history tag")
	_expect_equal(screen.get_ui_snapshot_for_test().sequence_portrait_modes.get("G1"), "upper_body", "command rail uses upper-body ghost portraits")

	var known_state := BattleState.from_dict(state.to_dict())
	var known_preview := screen.get_board_preview_snapshot_for_test()
	_expect_equal(known_preview.enemy_intent_count, 1, "known time exposes one fixed enemy intent")
	_expect_equal(known_preview.enemy_intents[0].label, "E1", "board intent identity matches the action sequence")
	_expect(bool(known_preview.enemy_intents[0].show_locked_intent), "known enemy exposes its locked intent")
	_expect_equal(known_preview.enemy_intents[0].attack_origin, known_preview.enemy_intents[0].destination, "enemy attack originates after its locked movement")
	screen.focus_enemy_for_test(&"guard_01")
	_expect_equal(screen.get_ui_snapshot_for_test().focused_enemy_id, &"guard_01", "clickable sequence focus stores the authoritative enemy id")
	_expect(bool(screen.get_ui_snapshot_for_test().sequence_focus_states.get("E1", false)), "focused enemy card exposes its selected state")
	_expect_equal(screen.get_board_preview_snapshot_for_test().focused_enemy_id, &"", "single-enemy focus does not pretend another intent was dimmed")
	screen.focus_enemy_for_test(&"guard_01")
	var pending_state := BattleState.from_dict(state.to_dict())
	pending_state.get_unit(&"guard_01").statuses["disturbed"] = true
	pending_state.get_unit(&"guard_01").statuses["awake_from_turn"] = pending_state.turn_index + 1
	screen.set_state_for_test(pending_state)
	_expect_equal(screen.get_ui_snapshot_for_test().sequence_temporal_states.get("E1"), "待醒", "disturbed enemy card shows the pending transition")
	_expect_equal(screen.get_board_preview_snapshot_for_test().enemy_intent_count, 1, "pending enemy keeps the current locked intent visible")
	_expect("本回合仍锁定" in String(screen.get_ui_snapshot_for_test().instruction), "pending feedback explains that the current intent remains locked")
	var mixed_state := BattleState.from_dict(state.to_dict())
	mixed_state.get_unit(&"guard_01").statuses["disturbed"] = true
	mixed_state.get_unit(&"guard_01").statuses["awake_from_turn"] = mixed_state.turn_index
	mixed_state.locked_enemy_intents[0]["reactive"] = true
	mixed_state.time_state = &"disturbed"
	screen.set_state_for_test(mixed_state)
	_expect_equal(screen.get_ui_snapshot_for_test().fixed_text, "固定 0", "awake enemy leaves the fixed count")
	_expect_equal(screen.get_ui_snapshot_for_test().awake_text, "清醒 1", "mixed command rail counts the awake enemy")
	_expect_equal(screen.get_ui_snapshot_for_test().sequence_temporal_states.get("E1"), "醒", "awake enemy sequence card carries the awake tag")
	_expect_equal(screen.get_board_preview_snapshot_for_test().enemy_intent_count, 0, "awake enemy hides all locked intent geometry")
	_expect_equal(screen.get_board_preview_snapshot_for_test().awake_question_count, 1, "awake enemy uses a question marker")
	_expect(not screen.get_board_preview_snapshot_for_test().enemy_intents[0].has("path"), "awake presentation snapshot does not leak a reactive path")
	_expect(not screen.get_board_preview_snapshot_for_test().enemy_intents[0].has("attack_target"), "awake presentation snapshot does not leak a reactive target")
	screen.set_state_for_test(known_state)

	await screen.submit_command_for_test(BattleCommand.move(&"player", Vector2i(0, 5)))
	await screen.submit_command_for_test(BattleCommand.attack(&"player", Vector2i(1, 5)))
	state = _state_from_screen(screen)
	_expect_equal(state.battle_outcome, &"victory", "visible battle loop reaches victory")
	_expect_equal(screen.get_ui_snapshot_for_test().instruction, "战斗胜利！", "victory message is shown")
	_expect(bool(screen.get_ui_snapshot_for_test().end_turn_disabled), "battle controls lock after victory")

	await _test_all_level_selection(screen)
	await _test_collision_course_screen(screen)

	screen.queue_free()
	await process_frame
	_finish()


func _test_pixel_art_render_settings() -> void:
	_expect_equal(
		ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter"),
		0,
		"canvas textures use nearest-neighbor filtering"
	)
	_expect(
		bool(ProjectSettings.get_setting("rendering/2d/snap/snap_2d_transforms_to_pixel")),
		"2D transforms snap to whole pixels"
	)
	_expect(
		bool(ProjectSettings.get_setting("rendering/2d/snap/snap_2d_vertices_to_pixel")),
		"2D vertices snap to whole pixels"
	)


func _test_enemy_intent_presentation_snapshots() -> void:
	var level := load("res://content/levels/falling_timeline.tres") as LevelDefinition
	var state := BattleStateFactory.create_from_level(level, 20260809)
	state.timeline_index = 2
	state.turn_index = 1
	state.time_state = &"disturbed"
	state.locked_enemy_intents = [
		{
			"enemy_id": &"guard_01",
			"from": Vector2i(1, 5),
			"to": Vector2i(1, 4),
			"path": [Vector2i(1, 5), Vector2i(1, 4)],
			"target": Vector2i(0, 4),
			"damage": 2,
			"intent_type": &"move_attack",
			"reactive": false,
		},
		{
			"enemy_id": &"guard_02",
			"from": Vector2i(3, 4),
			"to": Vector2i(3, 4),
			"path": [Vector2i(3, 4)],
			"target": Vector2i(0, 7),
			"damage": 2,
			"intent_type": &"wait",
			"reactive": false,
		},
		{
			"enemy_id": &"guard_03",
			"from": Vector2i(5, 2),
			"to": Vector2i(5, 3),
			"path": [Vector2i(5, 2), Vector2i(5, 3)],
			"target": Vector2i(4, 3),
			"damage": 2,
			"intent_type": &"move_attack",
			"reactive": false,
		},
		{
			"enemy_id": &"guard_04",
			"from": Vector2i(7, 5),
			"to": Vector2i(7, 4),
			"path": [Vector2i(7, 5), Vector2i(7, 4)],
			"target": Vector2i(6, 4),
			"damage": 2,
			"intent_type": &"move_attack",
			"reactive": true,
		},
	]
	state.get_unit(&"guard_03").statuses["disturbed"] = true
	state.get_unit(&"guard_03").statuses["awake_from_turn"] = 2
	state.get_unit(&"guard_04").statuses["disturbed"] = true
	state.get_unit(&"guard_04").statuses["awake_from_turn"] = 1

	var snapshots := EnemyIntentPresentationScript.build(state, &"guard_02")
	_expect_equal(snapshots.size(), 4, "intent presenter maps every active enemy")
	_expect_equal(snapshots[0].label, "E1", "first enemy receives a stable E1 label")
	_expect_equal(snapshots[1].label, "E2", "second enemy receives a stable E2 label")
	_expect_equal(snapshots[0].path, [Vector2i(1, 5), Vector2i(1, 4)], "fixed intent preserves the complete movement path")
	_expect_equal(snapshots[0].attack_origin, Vector2i(1, 4), "attack telegraph starts from the post-move endpoint")
	_expect_equal(snapshots[0].attack_target, Vector2i(0, 4), "attack telegraph keeps the locked danger cell")
	_expect_equal(snapshots[0].damage, 2, "attack telegraph exposes locked damage")
	_expect(bool(snapshots[1].waiting), "wait intent is explicit presentation data")
	_expect_equal(snapshots[0].opacity, 0.20, "focusing E2 dims other fixed intents")
	_expect_equal(snapshots[1].opacity, 1.0, "focused intent keeps full opacity")
	_expect_equal(snapshots[2].temporal_status, &"pending_awake", "disturbed enemy remains pending during the locked turn")
	_expect(bool(snapshots[2].show_locked_intent), "pending enemy keeps its current locked intent visible")
	_expect_equal(snapshots[3].temporal_status, &"awake", "wake turn promotes the enemy to awake")
	_expect(bool(snapshots[3].show_question), "awake enemy exposes only the question marker")
	_expect(not snapshots[3].has("path"), "awake snapshot strips reactive movement truth")
	_expect(not snapshots[3].has("attack_target"), "awake snapshot strips reactive target truth")

	state.get_unit(&"guard_01").active = false
	var after_death := EnemyIntentPresentationScript.build(state)
	_expect_equal(after_death[0].label, "E2", "surviving enemy keeps its original label after E1 dies")


func _test_high_density_battle_assets() -> void:
	var expected_sizes := {
		"res://assets/characters/player_idle.png": Vector2(192.0, 256.0),
		"res://assets/characters/ghost_idle.png": Vector2(192.0, 256.0),
		"res://assets/characters/guard_idle.png": Vector2(192.0, 256.0),
		"res://assets/environment/lab_floor_tile.png": Vector2(256.0, 256.0),
		"res://assets/environment/time_void_tile.png": Vector2(256.0, 256.0),
		"res://assets/environment/lab_obstacle_server.png": Vector2(256.0, 320.0),
		"res://assets/environment/lab_obstacle_pillar.png": Vector2(256.0, 320.0),
		"res://assets/ui/m50a/icon_move.png": Vector2(128.0, 128.0),
		"res://assets/ui/m50a/icon_attack.png": Vector2(128.0, 128.0),
		"res://assets/ui/m50a/icon_crystallize.png": Vector2(128.0, 128.0),
		"res://assets/ui/m50a/icon_end_turn.png": Vector2(128.0, 128.0),
		"res://assets/ui/m50a/icon_fixed.png": Vector2(128.0, 128.0),
		"res://assets/ui/m50a/icon_awake.png": Vector2(128.0, 128.0),
		"res://assets/ui/m50a/icon_lock.png": Vector2(128.0, 128.0),
		"res://assets/ui/m50a/button_frame_glow_move.png": Vector2(128.0, 160.0),
		"res://assets/ui/m50a/button_frame_glow_attack.png": Vector2(128.0, 160.0),
		"res://assets/ui/m50a/button_frame_glow_crystallize.png": Vector2(128.0, 160.0),
		"res://assets/ui/m50a/button_frame_glow_end_turn.png": Vector2(128.0, 160.0),
		"res://assets/ui/m50a/button_inner_glow_move.png": Vector2(128.0, 160.0),
		"res://assets/ui/m50a/button_inner_glow_attack.png": Vector2(128.0, 160.0),
		"res://assets/ui/m50a/button_inner_glow_crystallize.png": Vector2(128.0, 160.0),
		"res://assets/ui/m50a/button_inner_glow_end_turn.png": Vector2(128.0, 160.0),
		"res://assets/ui/m50a/button_plate_move.png": Vector2(128.0, 160.0),
		"res://assets/ui/m50a/button_plate_attack.png": Vector2(128.0, 160.0),
		"res://assets/ui/m50a/button_plate_crystallize.png": Vector2(128.0, 160.0),
		"res://assets/ui/m50a/button_plate_end_turn.png": Vector2(128.0, 160.0),
		"res://assets/ui/m50a/button_plate_selected_move.png": Vector2(128.0, 160.0),
		"res://assets/ui/m50a/button_plate_selected_attack.png": Vector2(128.0, 160.0),
		"res://assets/ui/m50a/button_plate_selected_crystallize.png": Vector2(128.0, 160.0),
		"res://assets/ui/m50a/button_plate_selected_end_turn.png": Vector2(128.0, 160.0),
	}
	for path in expected_sizes:
		var texture := load(path) as Texture2D
		_expect(texture != null, "%s loads as a battle texture" % path)
		if texture != null:
			_expect_equal(texture.get_size(), expected_sizes[path], "%s keeps its high-density export size" % path)


func _test_collision_course_screen(screen: BattleScreen) -> void:
	screen.select_level_for_test(4)
	screen.set_instant_playback_for_test()
	var state := _state_from_screen(screen)
	_expect_equal(state.level_id, &"collision_course", "level selector loads collision_course")
	_expect_equal(state.holes.size(), 3, "collision_course screen receives time holes")
	_expect(bool(screen.get_ui_snapshot_for_test().crystallize_visible), "collision_course exposes crystallize control")
	_expect_equal(screen.get_ui_snapshot_for_test().action_icons.crystallize, "res://assets/ui/m50a/icon_crystallize.png", "enabled crystallize control restores the temporal crystal icon")
	_expect_equal(screen.get_ui_snapshot_for_test().crystallize_caption, "固化", "enabled crystallize control keeps the same single-line caption")
	await screen.submit_command_for_test(BattleCommand.move(&"player", Vector2i(1, 5)))
	_expect_equal(screen.get_board_preview_snapshot_for_test().push_preview_count, 1, "attack selection shows knockback landing preview")
	await screen.submit_command_for_test(BattleCommand.attack(&"player", Vector2i(2, 5)))
	state = _state_from_screen(screen)
	_expect_equal(state.get_unit(&"guard_01").position, Vector2i(3, 5), "visible attack applies knockback")
	await screen.submit_command_for_test(BattleCommand.end_turn(&"player"))
	state = _state_from_screen(screen)
	_expect_equal(state.turn_index, 2, "collision_course visible loop advances through enemy phase")
	await screen.submit_command_for_test(BattleCommand.crystallize(&"player"))
	state = _state_from_screen(screen)
	_expect_equal(state.phase, BattlePhase.TIMELINE_TRANSITION, "visible crystallize opens timeline transition")
	_expect(bool(screen.get_ui_snapshot_for_test().next_timeline_visible), "crystallize uses timeline modal")


func _test_all_level_selection(screen: BattleScreen) -> void:
	var expected := [
		{"id": &"first_echo", "holes": 0, "crystallize_enabled": false, "enemies": 1},
		{"id": &"crossed_paths", "holes": 0, "crystallize_enabled": true, "enemies": 2},
		{"id": &"purple_crossfire", "holes": 0, "crystallize_enabled": true, "enemies": 4},
		{"id": &"push_calibration", "holes": 2, "crystallize_enabled": true, "enemies": 2},
		{"id": &"collision_course", "holes": 3, "crystallize_enabled": true, "enemies": 3},
		{"id": &"falling_timeline", "holes": 4, "crystallize_enabled": true, "enemies": 4},
	]
	for viewport_size in [Vector2i(360, 800), Vector2i(390, 844), Vector2i(430, 932)]:
		root.size = viewport_size
		await process_frame
		for index in range(expected.size()):
			screen.select_level_for_test(index)
			await process_frame
			var state := _state_from_screen(screen)
			var suffix := "level %d at %dx%d" % [index + 1, viewport_size.x, viewport_size.y]
			_expect_equal(state.level_id, expected[index].id, "%s loads in order" % suffix)
			_expect_equal(state.holes.size(), expected[index].holes, "%s exposes expected holes" % suffix)
			_expect(bool(screen.get_ui_snapshot_for_test().crystallize_visible), "%s keeps the fixed crystallize slot visible" % suffix)
			_expect_equal(screen.get_ui_snapshot_for_test().crystallize_disabled, not expected[index].crystallize_enabled, "%s applies the crystallize rule" % suffix)
			var layout := screen.get_layout_snapshot_for_test()
			_expect(float(layout.board_cell_size) >= 36.0, "%s keeps touch-safe board cells" % suffix)
			_expect_equal(layout.sequence_count, int(expected[index].enemies) + 1, "%s keeps every enemy action card visible" % suffix)
	root.size = Vector2i(390, 844)
	await process_frame


func _test_mobile_layout(screen: BattleScreen) -> void:
	var layout := screen.get_layout_snapshot_for_test()
	_expect_equal(layout.logical_size, Vector2(390.0, 844.0), "M4 uses the 390x844 logical portrait baseline")
	_expect_equal(layout.action_button_count, 4, "M4 keeps four fixed action slots")
	_expect(float(layout.action_button_height) >= 72.0, "action buttons keep a touch-safe height")
	_expect(float(layout.board_cell_size) >= 36.0, "each 8x8 board cell keeps a touch-safe center")
	_expect(float(layout.board_rect.size.x) <= float(layout.board_size.x) + 0.1, "board fits inside its horizontal presentation region")
	_expect(float(layout.board_rect.size.y) <= float(layout.board_size.y) + 0.1, "board fits inside its vertical presentation region")
	_expect(int(layout.sequence_count) >= 2, "action sequence includes the player and active enemies")


func _test_m50c_readability_review(screen: BattleScreen) -> void:
	var initial_ui := screen.get_ui_snapshot_for_test()
	_expect_equal(initial_ui.readability_review_button_text, "进入 M5.0C · 只读读图评审", "playtest menu exposes the M5.0C timed readability entry")
	_expect("对照：" not in String(initial_ui.readability_review_details), "readability entry does not leak the answer before exposure")
	var expected_visible := [0, 2, 4, 2, 2, 3]
	var expected_awake := [0, 0, 0, 0, 1, 1]
	var expected_sequence := [2, 4, 7, 4, 6, 7]
	for scenario_index in range(6):
		screen.enter_readability_review_for_test(scenario_index)
		await process_frame
		var ui := screen.get_ui_snapshot_for_test()
		var preview := screen.get_board_preview_snapshot_for_test()
		_expect(bool(ui.readability_review_mode), "M5.0C scenario %d enters a dedicated read-only mode" % (scenario_index + 1))
		_expect_equal(int(ui.readability_scenario_index), scenario_index, "M5.0C scenario %d keeps stable identity" % (scenario_index + 1))
		_expect(bool(ui.end_turn_disabled) and bool(ui.move_disabled) and bool(ui.attack_disabled), "M5.0C scenario %d blocks battle mutation during timed reading" % (scenario_index + 1))
		_expect_equal(int(preview.enemy_intent_count), expected_visible[scenario_index], "M5.0C scenario %d exposes the intended locked geometry count" % (scenario_index + 1))
		_expect_equal(int(preview.awake_question_count), expected_awake[scenario_index], "M5.0C scenario %d exposes the intended awake marker count" % (scenario_index + 1))
		if scenario_index == 2:
			screen.focus_enemy_for_test(&"guard_02")
			preview = screen.get_board_preview_snapshot_for_test()
			var dimmed_count := 0
			for intent_data in preview.enemy_intents:
				if float((intent_data as Dictionary).get("opacity", 1.0)) < 0.3:
					dimmed_count += 1
			_expect_equal(preview.focused_enemy_id, &"guard_02", "crossed-path scenario keeps action-card focus available")
			_expect_equal(dimmed_count, 3, "crossed-path focus dims the other three enemy intents")
		if scenario_index == 3:
			var waiting_count := 0
			for intent_data in preview.enemy_intents:
				if bool((intent_data as Dictionary).get("waiting", false)):
					waiting_count += 1
			_expect_equal(waiting_count, 1, "attack-and-wait scenario keeps one explicit waiting badge")
		if scenario_index == 4:
			_expect("本回合仍锁定" in String(ui.instruction), "mixed scenario explains the pending enemy without opening logs")
		if scenario_index == 5:
			_expect(bool(ui.boss_build_review_visible), "information-limit scenario includes the existing Boss and Build rail")
		screen.finish_readability_exposure_for_test()
		ui = screen.get_ui_snapshot_for_test()
		_expect(bool(ui.readability_cover_visible), "M5.0C scenario %d automatically covers the board after exposure" % (scenario_index + 1))
		_expect(not bool(ui.readability_answer_visible), "M5.0C scenario %d asks before revealing the answer" % (scenario_index + 1))
		_expect(not String(ui.readability_prompt_text).is_empty(), "M5.0C scenario %d provides a post-exposure question" % (scenario_index + 1))
		screen.reveal_readability_answer_for_test()
		_expect(bool(screen.get_ui_snapshot_for_test().readability_answer_visible), "M5.0C scenario %d reveals its answer only on request" % (scenario_index + 1))
		screen.exit_readability_review_for_test()

	for viewport_size in [Vector2i(360, 800), Vector2i(390, 844), Vector2i(430, 932)]:
		root.size = viewport_size
		await process_frame
		for scenario_index in range(6):
			screen.enter_readability_review_for_test(scenario_index)
			await process_frame
			var layout := screen.get_layout_snapshot_for_test()
			var suffix := "M5.0C scenario %d at %dx%d" % [scenario_index + 1, viewport_size.x, viewport_size.y]
			_expect(float(layout.board_cell_size) >= 36.0, "%s keeps touch-safe board cells" % suffix)
			_expect_equal(int(layout.sequence_count), expected_sequence[scenario_index], "%s keeps every action card visible" % suffix)
			_expect(float(layout.action_button_height) >= 72.0, "%s keeps touch-safe action controls" % suffix)
			screen.exit_readability_review_for_test()
	root.size = Vector2i(390, 844)
	await process_frame


func _test_state_sync_clears_preview_cache() -> void:
	var board := BattleBoardView.new()
	root.add_child(board)
	await process_frame
	var preview_event := BattleEvent.create(&"turn_started", &"", {
		"time_state": &"known",
		"ghost_actions": [{"action_type": BattleCommand.ATTACK, "target": Vector2i(1, 5)}],
		"enemy_intents": [{"intent_type": &"attack", "target": Vector2i(0, 6)}],
	})
	await board.play_event(preview_event, 0.0)
	_expect_equal(board.get_preview_snapshot_for_test().ghost_fire_count, 1, "preview fixture exposes a ghost fire marker")
	_expect_equal(board.get_preview_snapshot_for_test().enemy_attack_count, 1, "preview fixture exposes an enemy warning marker")
	board.set_interaction([], [], true, [{"outcome": &"collision", "display_cell": Vector2i(1, 1)}])
	_expect_equal(board.get_preview_snapshot_for_test().push_collision_count, 1, "knockback preview exposes an occupied-cell collision marker")
	var level := load("res://content/levels/first_echo.tres") as LevelDefinition
	board.sync_from_state(BattleStateFactory.create_from_level(level, 99))
	_expect_equal(board.get_preview_snapshot_for_test().ghost_fire_count, 0, "state sync clears previous ghost markers")
	_expect_equal(board.get_preview_snapshot_for_test().enemy_attack_count, 0, "state sync clears previous enemy markers")
	_expect_equal(board.get_preview_snapshot_for_test().push_collision_count, 0, "state sync clears previous collision previews")
	board.queue_free()
	await process_frame


func _test_touch_input_maps_to_grid() -> void:
	var board := BattleBoardView.new()
	board.size = Vector2(360.0, 520.0)
	root.add_child(board)
	await process_frame
	var level := load("res://content/levels/first_echo.tres") as LevelDefinition
	board.sync_from_state(BattleStateFactory.create_from_level(level, 100))
	board.set_interaction([], [], true)
	var captured := {"cell": Vector2i(-1, -1)}
	board.cell_clicked.connect(func(cell: Vector2i) -> void: captured.cell = cell)
	var touch := InputEventScreenTouch.new()
	touch.position = board.grid_to_local(Vector2i(0, 7))
	touch.pressed = true
	board.handle_input_for_test(touch)
	_expect_equal(captured.cell, Vector2i(0, 7), "screen touch selects the intended logical grid cell")
	board.queue_free()
	await process_frame


func _test_event_driven_animation_states() -> void:
	var board := BattleBoardView.new()
	board.size = Vector2(360.0, 520.0)
	root.add_child(board)
	await process_frame
	var level := load("res://content/levels/first_echo.tres") as LevelDefinition
	board.sync_from_state(BattleStateFactory.create_from_level(level, 101))

	await board.play_event(BattleEvent.create(&"unit_moved", &"player", {
		"from": Vector2i(0, 6),
		"to": Vector2i(1, 6),
		"path": [Vector2i(0, 6), Vector2i(1, 6)],
	}), 0.0)
	var animations: Dictionary = board.get_animation_snapshot_for_test().units
	_expect_equal(animations[&"player"].last_completed_state, UnitAnimationState.MOVE, "move event completes the movement animation state")
	_expect_equal(animations[&"player"].facing, Vector2i(1, 0), "movement stores the unit facing")

	await board.play_event(BattleEvent.create(&"attack_performed", &"player", {
		"target_cell": Vector2i(1, 5),
	}), 0.0)
	animations = board.get_animation_snapshot_for_test().units
	_expect_equal(animations[&"player"].last_completed_state, UnitAnimationState.ATTACK, "attack event completes the attack animation state")

	await board.play_event(BattleEvent.create(&"attack_performed", &"guard_01", {
		"target_cell": Vector2i(0, 5),
	}), 0.0)
	animations = board.get_animation_snapshot_for_test().units
	_expect_equal(animations[&"guard_01"].facing, Vector2i(-1, 0), "enemy attack stores a left-facing direction")
	_expect_equal(animations[&"guard_01"].draw_scale_x, 1.0, "left-facing enemy keeps the guard master's authored orientation")

	await board.play_event(BattleEvent.create(&"attack_performed", &"guard_01", {
		"target_cell": Vector2i(2, 5),
	}), 0.0)
	animations = board.get_animation_snapshot_for_test().units
	_expect_equal(animations[&"guard_01"].facing, Vector2i(1, 0), "enemy attack stores a right-facing direction")
	_expect_equal(animations[&"guard_01"].draw_scale_x, -1.0, "right-facing enemy mirrors the left-facing guard master")

	await board.play_event(BattleEvent.create(&"damage_applied", &"player", {
		"target_id": &"guard_01",
		"damage": 1,
		"remaining_hp": 2,
		"cause": &"attack",
	}), 0.0)
	animations = board.get_animation_snapshot_for_test().units
	_expect_equal(animations[&"guard_01"].last_completed_state, UnitAnimationState.HIT, "damage event completes the hit animation state")

	await board.play_event(BattleEvent.create(&"units_collided", &"guard_01", {
		"first_unit_id": &"guard_01",
		"second_unit_id": &"player",
		"first_cell": Vector2i(1, 5),
		"second_cell": Vector2i(1, 6),
		"damage": 1,
	}), 3.0)
	var snapshot := board.get_animation_snapshot_for_test()
	animations = snapshot.units
	_expect_equal(animations[&"guard_01"].last_completed_state, UnitAnimationState.COLLISION, "collision shakes the first unit")
	_expect_equal(animations[&"player"].last_completed_state, UnitAnimationState.COLLISION, "collision shakes the second unit")
	_expect_equal(snapshot.floating_number_count, 0, "collision damage numbers clean up after playback")
	_expect_equal(snapshot.impact_flash_count, 0, "collision flash cleans up after playback")

	await board.play_event(BattleEvent.create(&"enemy_disturbed", &"guard_01", {"wake_turn": 2}), 0.0)
	_expect_equal(board.get_preview_snapshot_for_test().last_disturbance_enemy, &"guard_01", "disturbance event drives the fracture-wave presentation")

	await board.play_event(BattleEvent.create(&"timeline_crystallized", &"player"), 0.0)
	animations = board.get_animation_snapshot_for_test().units
	_expect_equal(animations[&"player"].last_completed_state, UnitAnimationState.CRYSTALLIZE, "crystallize event completes the crystallize animation state")

	await board.play_event(BattleEvent.create(&"unit_died", &"guard_01", {
		"cell": Vector2i(1, 5),
		"cause": &"attack",
	}), 0.0)
	animations = board.get_animation_snapshot_for_test().units
	_expect_equal(animations[&"guard_01"].last_completed_state, UnitAnimationState.DEATH, "death event completes the death animation state")
	_expect_equal(animations[&"guard_01"].state, UnitAnimationState.DEATH, "dead unit remains in the terminal animation state")
	board.queue_free()
	await process_frame


func _test_playback_speeds_keep_identical_results() -> void:
	var packed_scene := load("res://presentation/battle/battle_screen.tscn") as PackedScene
	var reference_state: Dictionary = {}
	for speed in [0.0, 1.0, 3.0]:
		var screen := packed_scene.instantiate() as BattleScreen
		root.add_child(screen)
		await process_frame
		screen.select_level_for_test(0)
		screen.set_playback_speed_for_test(speed)
		await screen.submit_command_for_test(BattleCommand.move(&"player", Vector2i(1, 6)))
		await screen.submit_command_for_test(BattleCommand.attack(&"player", Vector2i(1, 5)))
		var state := screen.get_state_snapshot_for_test()
		if reference_state.is_empty():
			reference_state = state
		else:
			_expect_equal(state, reference_state, "playback speed %.0fx preserves the same authoritative state" % speed)
		screen.queue_free()
		await process_frame


func _state_from_screen(screen: BattleScreen) -> BattleState:
	return BattleState.from_dict(screen.get_state_snapshot_for_test())


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
	_expect(actual == expected, "%s (expected %s, got %s)" % [label, expected, actual])


func _finish() -> void:
	if _failures.is_empty():
		print("TIMELOOP PRESENTATION SMOKE PASSED (%d checks)" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("TIMELOOP PRESENTATION SMOKE FAILED (%d failures, %d checks)" % [_failures.size(), _checks])
	quit(1)
