extends SceneTree

var _failures: PackedStringArray = []
var _checks := 0


func _init() -> void:
	_test_first_echo_resource()
	_test_command_serialization()
	_test_checkpoint_json_round_trip()
	_test_atomic_move_and_undo()
	_test_invalid_command_does_not_create_checkpoint()

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
