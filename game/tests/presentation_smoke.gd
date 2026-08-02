extends SceneTree

var _failures: PackedStringArray = []
var _checks := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_state_sync_clears_preview_cache()

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

	screen.select_level_for_test(0)
	screen.set_instant_playback_for_test()
	var state := _state_from_screen(screen)
	_expect_equal(state.phase, BattlePhase.PLAYER_INPUT, "screen starts in player input")
	_expect(not bool(screen.get_ui_snapshot_for_test().end_turn_disabled), "initial controls are enabled")

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

	await screen.submit_command_for_test(BattleCommand.move(&"player", Vector2i(0, 5)))
	await screen.submit_command_for_test(BattleCommand.attack(&"player", Vector2i(1, 5)))
	state = _state_from_screen(screen)
	_expect_equal(state.battle_outcome, &"victory", "visible battle loop reaches victory")
	_expect_equal(screen.get_ui_snapshot_for_test().instruction, "战斗胜利！", "victory message is shown")
	_expect(bool(screen.get_ui_snapshot_for_test().end_turn_disabled), "battle controls lock after victory")

	await _test_collision_course_screen(screen)

	screen.queue_free()
	await process_frame
	_finish()


func _test_collision_course_screen(screen: BattleScreen) -> void:
	screen.select_level_for_test(1)
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
	var level := load("res://content/levels/first_echo.tres") as LevelDefinition
	board.sync_from_state(BattleStateFactory.create_from_level(level, 99))
	_expect_equal(board.get_preview_snapshot_for_test().ghost_fire_count, 0, "state sync clears previous ghost markers")
	_expect_equal(board.get_preview_snapshot_for_test().enemy_attack_count, 0, "state sync clears previous enemy markers")
	board.queue_free()
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
