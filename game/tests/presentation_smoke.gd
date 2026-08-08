extends SceneTree

var _failures: PackedStringArray = []
var _checks := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_pixel_art_render_settings()
	_test_high_density_battle_assets()
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
	screen.set_action_mode_for_test(&"move")
	_expect(bool(screen.get_ui_snapshot_for_test().move_selected), "move control exposes the persistent selected state")
	_expect(not bool(screen.get_ui_snapshot_for_test().attack_selected), "selecting move leaves attack unselected")
	screen.set_action_mode_for_test(&"smart")

	await screen.submit_command_for_test(BattleCommand.move(&"player", Vector2i(1, 6)))
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

	var known_state := BattleState.from_dict(state.to_dict())
	var mixed_state := BattleState.from_dict(state.to_dict())
	mixed_state.get_unit(&"guard_01").statuses["disturbed"] = true
	mixed_state.get_unit(&"guard_01").statuses["awake_from_turn"] = mixed_state.turn_index
	mixed_state.locked_enemy_intents[0]["reactive"] = true
	mixed_state.time_state = &"disturbed"
	screen.set_state_for_test(mixed_state)
	_expect_equal(screen.get_ui_snapshot_for_test().fixed_text, "固定 0", "awake enemy leaves the fixed count")
	_expect_equal(screen.get_ui_snapshot_for_test().awake_text, "清醒 1", "mixed command rail counts the awake enemy")
	_expect_equal(screen.get_ui_snapshot_for_test().sequence_temporal_states.get("E1"), "醒", "awake enemy sequence card carries the awake tag")
	screen.set_state_for_test(known_state)

	await screen.submit_command_for_test(BattleCommand.move(&"player", Vector2i(0, 5)))
	await screen.submit_command_for_test(BattleCommand.attack(&"player", Vector2i(1, 5)))
	state = _state_from_screen(screen)
	_expect_equal(state.battle_outcome, &"victory", "visible battle loop reaches victory")
	_expect_equal(screen.get_ui_snapshot_for_test().instruction, "战斗胜利！", "victory message is shown")
	_expect(bool(screen.get_ui_snapshot_for_test().end_turn_disabled), "battle controls lock after victory")

	_test_all_level_selection(screen)
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


func _test_high_density_battle_assets() -> void:
	var expected_sizes := {
		"res://assets/characters/player_idle.png": Vector2(192.0, 256.0),
		"res://assets/characters/ghost_idle.png": Vector2(192.0, 256.0),
		"res://assets/characters/guard_idle.png": Vector2(192.0, 256.0),
		"res://assets/environment/lab_floor_tile.png": Vector2(256.0, 256.0),
		"res://assets/environment/time_void_tile.png": Vector2(256.0, 256.0),
		"res://assets/environment/lab_obstacle_server.png": Vector2(256.0, 320.0),
		"res://assets/environment/lab_obstacle_pillar.png": Vector2(256.0, 320.0),
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
		{"id": &"first_echo", "holes": 0, "crystallize_enabled": false},
		{"id": &"crossed_paths", "holes": 0, "crystallize_enabled": true},
		{"id": &"purple_crossfire", "holes": 0, "crystallize_enabled": true},
		{"id": &"push_calibration", "holes": 2, "crystallize_enabled": true},
		{"id": &"collision_course", "holes": 3, "crystallize_enabled": true},
		{"id": &"falling_timeline", "holes": 4, "crystallize_enabled": true},
	]
	for index in range(expected.size()):
		screen.select_level_for_test(index)
		var state := _state_from_screen(screen)
		_expect_equal(state.level_id, expected[index].id, "selector loads level %d in order" % (index + 1))
		_expect_equal(state.holes.size(), expected[index].holes, "level %d exposes expected holes" % (index + 1))
		_expect(bool(screen.get_ui_snapshot_for_test().crystallize_visible), "level %d keeps the fixed crystallize slot visible" % (index + 1))
		_expect_equal(screen.get_ui_snapshot_for_test().crystallize_disabled, not expected[index].crystallize_enabled, "level %d applies the crystallize rule by disabled state" % (index + 1))


func _test_mobile_layout(screen: BattleScreen) -> void:
	var layout := screen.get_layout_snapshot_for_test()
	_expect_equal(layout.logical_size, Vector2(390.0, 844.0), "M4 uses the 390x844 logical portrait baseline")
	_expect_equal(layout.action_button_count, 4, "M4 keeps four fixed action slots")
	_expect(float(layout.action_button_height) >= 72.0, "action buttons keep a touch-safe height")
	_expect(float(layout.board_cell_size) >= 36.0, "each 8x8 board cell keeps a touch-safe center")
	_expect(float(layout.board_rect.size.x) <= float(layout.board_size.x) + 0.1, "board fits inside its horizontal presentation region")
	_expect(float(layout.board_rect.size.y) <= float(layout.board_size.y) + 0.1, "board fits inside its vertical presentation region")
	_expect(int(layout.sequence_count) >= 2, "action sequence includes the player and active enemies")


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
