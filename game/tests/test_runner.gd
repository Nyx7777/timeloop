extends SceneTree

var _failures: PackedStringArray = []
var _checks := 0


func _init() -> void:
	_test_first_echo_resource()
	_test_command_serialization()
	_test_checkpoint_json_round_trip()
	_test_atomic_move_and_undo()
	_test_invalid_command_does_not_create_checkpoint()
	_test_reactive_enemy_movement()
	_test_first_echo_full_timeline_loop()
	_test_last_life_defeat_does_not_create_ghost()

	if _failures.is_empty():
		print("TIMELOOP TESTS PASSED (%d checks)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("TIMELOOP TESTS FAILED (%d failures, %d checks)" % [_failures.size(), _checks])
		quit(1)


func _test_first_echo_resource() -> void:
	var level := load("res://content/levels/first_echo.tres") as LevelDefinition
	_expect(level != null, "first_echo resource loads")
	if level == null:
		return
	var errors := LevelValidator.validate(level)
	_expect_equal(errors.size(), 0, "first_echo passes validation")
	var state := BattleStateFactory.create_from_level(level, 777)
	_expect(state != null, "factory creates first_echo state")
	if state != null:
		_expect_equal(state.get_unit(&"player").position, Vector2i(0, 7), "H5 row/col converts to Godot x/y")
		_expect_equal(state.rng_seed, 777, "battle seed is stored")


func _test_command_serialization() -> void:
	var command := BattleCommand.move(&"player", Vector2i(1, 7))
	command.payload = {"preview_path": [Vector2i(0, 7), Vector2i(1, 7)]}
	var restored := BattleCommand.from_dict(command.to_dict())
	_expect_equal(restored.command_type, BattleCommand.MOVE, "command type round-trips")
	_expect_equal(restored.target_cell, Vector2i(1, 7), "command target round-trips")
	_expect_equal(restored.payload.preview_path[1], Vector2i(1, 7), "command payload round-trips")


func _test_checkpoint_json_round_trip() -> void:
	var session := _create_session()
	if session == null:
		return
	var command := BattleCommand.move(&"player", Vector2i(1, 7))
	var checkpoint := BattleCheckpoint.capture(session.state, command)
	var json_text := JSON.stringify(checkpoint.to_dict())
	var parsed: Variant = JSON.parse_string(json_text)
	_expect(parsed is Dictionary, "checkpoint serializes to JSON")
	if not parsed is Dictionary:
		return
	var restored := BattleCheckpoint.from_dict(parsed)
	_expect_equal(restored.restore_state().get_unit(&"player").position, Vector2i(0, 7), "JSON checkpoint restores state")
	_expect_equal(restored.restore_command().target_cell, Vector2i(1, 7), "JSON checkpoint restores command")


func _test_atomic_move_and_undo() -> void:
	var session := _create_session()
	if session == null:
		return
	var initial_rng_state := session.state.rng_state
	var result := session.submit(BattleCommand.move(&"player", Vector2i(1, 7)))
	_expect(result.accepted, "valid move is accepted")
	_expect_equal(session.state.get_unit(&"player").position, Vector2i(1, 7), "move changes authoritative state")
	_expect_equal(session.state.current_recording.size(), 1, "move creates one recorded action")
	_expect_equal(result.events.size(), 1, "move creates one presentation event")
	_expect_equal(result.events[0].event_type, &"unit_moved", "move event has stable type")
	_expect_equal(session.get_undo_count(), 1, "accepted command creates checkpoint")

	var undo_result := session.undo_last_command()
	_expect(undo_result.accepted, "undo restores checkpoint")
	_expect_equal(session.state.get_unit(&"player").position, Vector2i(0, 7), "undo restores unit position")
	_expect_equal(session.state.current_recording.size(), 0, "undo restores recording length")
	_expect_equal(session.state.command_index, 0, "undo restores command index")
	_expect_equal(session.state.rng_state, initial_rng_state, "undo restores random source state")
	_expect_equal(undo_result.events[0].event_type, &"state_restored", "undo requests full presentation resync")


func _test_invalid_command_does_not_create_checkpoint() -> void:
	var session := _create_session()
	if session == null:
		return
	var result := session.submit(BattleCommand.move(&"player", Vector2i(2, 6)))
	_expect(not result.accepted, "move into wall is rejected")
	_expect_equal(result.reason, &"destination_unreachable", "invalid move reports stable reason")
	_expect_equal(session.get_undo_count(), 0, "rejected command creates no checkpoint")
	_expect_equal(session.state.get_unit(&"player").position, Vector2i(0, 7), "rejected command leaves state untouched")


func _test_reactive_enemy_movement() -> void:
	var session := _create_session()
	if session == null:
		return
	var result := session.submit(BattleCommand.end_turn(&"player"))
	_expect(result.accepted, "ending an untouched turn is accepted")
	_expect_equal(session.state.get_unit(&"guard_01").position, Vector2i(0, 5), "unknown-time enemy reacts with deterministic movement")
	_expect_equal(session.state.turn_index, 2, "surviving enemy phase advances the turn")
	_expect(session.state.current_enemy_history.has(1), "unknown-time intent is recorded in current history")
	_expect(_has_event(result, &"enemy_intents_locked"), "enemy phase publishes locked intents")


func _test_first_echo_full_timeline_loop() -> void:
	var session := _create_session()
	if session == null:
		return

	_expect(session.submit(BattleCommand.move(&"player", Vector2i(1, 6))).accepted, "T1 player reaches guard")
	var first_attack := session.submit(BattleCommand.attack(&"player", Vector2i(1, 5)))
	_expect(first_attack.accepted, "T1 attack is accepted")
	_expect_equal(session.state.get_unit(&"guard_01").hp, 2, "T1 attack records fixed damage")
	_expect_equal(session.state.current_recording.size(), 2, "T1 movement and attack are recorded")

	var death_turn := session.submit(BattleCommand.end_turn(&"player"))
	_expect(death_turn.accepted, "T1 enemy phase resolves")
	_expect_equal(session.state.phase, BattlePhase.TIMELINE_TRANSITION, "player death enters timeline transition")
	_expect_equal(session.state.lives_left, 1, "player death consumes one life")
	_expect_equal(session.state.timeline_recordings.size(), 1, "dead timeline becomes a ghost recording")
	_expect(session.state.enemy_history.has(1), "T1 enemy behavior becomes fixed history")
	_expect(_has_event(death_turn, &"timeline_ended"), "death publishes timeline-ended event")

	var next_timeline := session.submit(BattleCommand.start_next_timeline())
	_expect(next_timeline.accepted, "T2 starts from transition")
	_expect_equal(session.state.timeline_index, 2, "timeline counter advances")
	_expect_equal(session.state.phase, BattlePhase.PLAYER_INPUT, "ghost playback hands control to current player")
	_expect_equal(session.state.time_state, &"known", "T2 turn one exposes fixed enemy history")
	_expect_equal(session.state.get_unit(&"guard_01").hp, 2, "T1 ghost replays fixed attack into reset world")
	_expect_equal(session.state.ghost_positions.get(&"ghost_t1"), Vector2i(1, 6), "ghost replays absolute movement")
	_expect_equal(session.get_undo_count(), 0, "starting a committed timeline clears undo history")
	_expect(_has_event(next_timeline, &"timeline_started"), "T2 publishes timeline-start event")
	_expect(_has_event(next_timeline, &"attack_performed"), "ghost attack publishes presentation event")

	_expect(session.submit(BattleCommand.move(&"player", Vector2i(0, 5))).accepted, "T2 player avoids ghost end cell")
	var winning_attack := session.submit(BattleCommand.attack(&"player", Vector2i(1, 5)))
	_expect(winning_attack.accepted, "T2 current player completes combined attack")
	_expect_equal(session.state.battle_outcome, &"victory", "combined timelines win first_echo")
	_expect_equal(session.state.phase, BattlePhase.BATTLE_OVER, "victory ends battle immediately")
	_expect(not session.state.get_unit(&"guard_01").active, "guard is defeated")
	_expect_equal(session.state.timeline_recordings.size(), 2, "winning timeline is committed for combined replay")
	_expect_equal(session.state.timeline_recordings[1].end_reason, &"victory", "winning recording keeps its end reason")
	_expect(_has_event(winning_attack, &"battle_won"), "victory publishes battle-won event")


func _test_last_life_defeat_does_not_create_ghost() -> void:
	var session := _create_session()
	if session == null:
		return
	session.state.lives_left = 1
	_expect(session.submit(BattleCommand.move(&"player", Vector2i(1, 6))).accepted, "last-life player reaches guard")
	_expect(session.submit(BattleCommand.attack(&"player", Vector2i(1, 5))).accepted, "last-life player attacks")
	var defeat := session.submit(BattleCommand.end_turn(&"player"))
	_expect_equal(session.state.battle_outcome, &"defeat", "last-life death loses battle")
	_expect_equal(session.state.phase, BattlePhase.BATTLE_OVER, "defeat ends battle")
	_expect_equal(session.state.timeline_recordings.size(), 0, "last-life death creates no unusable ghost")
	_expect(_has_event(defeat, &"battle_lost"), "defeat publishes battle-lost event")


func _has_event(result: CommandResult, event_type: StringName) -> bool:
	for event in result.events:
		if event.event_type == event_type:
			return true
	return false


func _create_session() -> BattleSession:
	var level := load("res://content/levels/first_echo.tres") as LevelDefinition
	var state := BattleStateFactory.create_from_level(level, 12345)
	_expect(state != null, "test session state can be created")
	if state == null:
		return null
	return BattleSession.new(state)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _expect_equal(actual: Variant, expected: Variant, message: String) -> void:
	_checks += 1
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, expected, actual])
