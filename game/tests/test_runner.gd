extends SceneTree

var _failures: PackedStringArray = []
var _checks := 0


func _init() -> void:
	_test_first_echo_resource()
	_test_collision_course_resource()
	_test_migrated_level_resources()
	_test_command_serialization()
	_test_checkpoint_json_round_trip()
	_test_atomic_move_and_undo()
	_test_invalid_command_does_not_create_checkpoint()
	_test_reactive_enemy_movement()
	_test_first_echo_full_timeline_loop()
	_test_last_life_defeat_does_not_create_ghost()
	_test_attack_knockback_and_time_hole()
	_test_knockback_collision_damages_both_units()
	_test_collision_can_defeat_both_enemies()
	_test_ghost_replays_fixed_knockback_direction()
	_test_ghost_replays_collision_against_current_unit()
	_test_matching_ghost_displacement_preserves_fixed_history()
	_test_multiple_ghost_displacements_preserve_fixed_history()
	_test_divergent_ghost_replay_disturbs_enemy()
	_test_fixed_history_collision_pushes_player()
	_test_fixed_history_collision_into_hole_ends_timeline()
	_test_disturbance_wakes_enemy_next_turn()
	_test_awake_state_resets_on_next_timeline()
	_test_crystallize_commits_without_enemy_phase()

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


func _test_collision_course_resource() -> void:
	var level := load("res://content/levels/collision_course.tres") as LevelDefinition
	_expect(level != null, "collision_course resource loads")
	if level == null:
		return
	_expect_equal(LevelValidator.validate(level).size(), 0, "collision_course passes validation")
	var state := BattleStateFactory.create_from_level(level, 778)
	_expect_equal(state.lives_left, 3, "collision_course keeps three timelines")
	_expect_equal(state.holes, [Vector2i(3, 6), Vector2i(3, 3), Vector2i(6, 1)], "collision_course converts H5 hole coordinates")
	_expect_equal(state.get_unit(&"guard_01").position, Vector2i(2, 5), "collision_course converts enemy coordinates")
	_expect(bool(state.rules.get("push_enabled", false)), "collision_course enables knockback")


func _test_migrated_level_resources() -> void:
	var cases := [
		{
			"path": "res://content/levels/crossed_paths.tres",
			"id": &"crossed_paths",
			"lives": 2,
			"player": Vector2i(3, 7),
			"enemies": [Vector2i(1, 4), Vector2i(5, 4)],
			"walls": [Vector2i(2, 3), Vector2i(3, 3), Vector2i(4, 3), Vector2i(1, 5), Vector2i(5, 5), Vector2i(1, 6), Vector2i(5, 6)],
			"holes": [],
			"push": false,
		},
		{
			"path": "res://content/levels/purple_crossfire.tres",
			"id": &"purple_crossfire",
			"lives": 3,
			"player": Vector2i(0, 7),
			"enemies": [Vector2i(6, 1), Vector2i(2, 5), Vector2i(6, 6), Vector2i(1, 3)],
			"walls": [Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 3), Vector2i(1, 6)],
			"holes": [],
			"push": false,
		},
		{
			"path": "res://content/levels/push_calibration.tres",
			"id": &"push_calibration",
			"lives": 2,
			"player": Vector2i(1, 7),
			"enemies": [Vector2i(1, 6), Vector2i(5, 4)],
			"walls": [Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4), Vector2i(4, 2), Vector2i(5, 2), Vector2i(6, 2)],
			"holes": [Vector2i(1, 5), Vector2i(5, 3)],
			"push": true,
		},
		{
			"path": "res://content/levels/falling_timeline.tres",
			"id": &"falling_timeline",
			"lives": 3,
			"player": Vector2i(0, 7),
			"enemies": [Vector2i(1, 5), Vector2i(3, 4), Vector2i(5, 2), Vector2i(7, 5)],
			"walls": [Vector2i(3, 1), Vector2i(3, 2), Vector2i(3, 5), Vector2i(3, 6), Vector2i(1, 3), Vector2i(6, 4)],
			"holes": [Vector2i(1, 6), Vector2i(2, 4), Vector2i(5, 3), Vector2i(6, 1)],
			"push": true,
		},
	]
	for case in cases:
		var level := load(case.path) as LevelDefinition
		_expect(level != null, "%s resource loads" % case.id)
		if level == null:
			continue
		_expect_equal(LevelValidator.validate(level).size(), 0, "%s passes validation" % case.id)
		var state := BattleStateFactory.create_from_level(level, 779)
		_expect(state != null, "%s creates battle state" % case.id)
		if state == null:
			continue
		_expect_equal(state.level_id, case.id, "%s keeps its level id" % case.id)
		_expect_equal(state.lives_left, case.lives, "%s keeps timeline count" % case.id)
		_expect_equal(state.get_unit(&"player").position, case.player, "%s converts player row/col to x/y" % case.id)
		var enemy_positions: Array[Vector2i] = []
		for unit_id in state.unit_order:
			var unit := state.get_unit(unit_id)
			if unit.team == &"enemy":
				enemy_positions.append(unit.position)
		_expect_equal(enemy_positions, case.enemies, "%s converts every enemy row/col to x/y" % case.id)
		_expect_equal(state.walls, case.walls, "%s converts every wall row/col to x/y" % case.id)
		_expect_equal(state.holes, case.holes, "%s converts every hole row/col to x/y" % case.id)
		_expect_equal(bool(state.rules.get("push_enabled", false)), case.push, "%s keeps knockback rule" % case.id)
		_expect(bool(state.rules.get("crystallize_enabled", false)), "%s unlocks crystallize" % case.id)


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
	_expect_equal(restored.restore_state().rules.get("push_enabled"), false, "JSON checkpoint restores level rule switches")
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
	_expect_equal(result.events[0].payload.path, [Vector2i(0, 7), Vector2i(1, 7)], "move event preserves the traversed path")
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
	var intent_event := _find_event(result, &"enemy_intents_locked")
	_expect_equal(intent_event.payload.intents[0].path, [Vector2i(1, 5), Vector2i(0, 5)], "enemy intent preserves each movement step")


func _test_first_echo_full_timeline_loop() -> void:
	var session := _create_session()
	if session == null:
		return

	var opening_move := session.submit(BattleCommand.move(&"player", Vector2i(1, 6)))
	_expect(opening_move.accepted, "T1 player reaches guard")
	_expect_equal(opening_move.events[0].payload.path, [Vector2i(0, 7), Vector2i(1, 7), Vector2i(1, 6)], "multi-cell move exposes every traversed cell")
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
	var turn_started := _find_event(next_timeline, &"turn_started")
	_expect_equal(turn_started.payload.ghost_actions.size(), 2, "turn preview exposes the ghost move and attack")
	_expect_equal(turn_started.payload.enemy_intents.size(), 1, "known-time turn preview exposes enemy intent")

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


func _test_attack_knockback_and_time_hole() -> void:
	var moved_session := BattleSession.new(_create_micro_state(Vector2i(1, 3), Vector2i(1, 2)))
	var pushed := moved_session.submit(BattleCommand.attack(&"player", Vector2i(1, 2)))
	_expect(pushed.accepted, "push-enabled attack is accepted")
	_expect_equal(moved_session.state.get_unit(&"guard").position, Vector2i(1, 1), "surviving enemy is pushed one cell")
	_expect(_has_event(pushed, &"unit_pushed"), "successful knockback publishes displacement event")
	_expect_equal(moved_session.state.current_recording[0].result.push_direction, Vector2i(0, -1), "recorded attack stores fixed push direction")

	var hole_session := BattleSession.new(_create_micro_state(Vector2i(1, 3), Vector2i(1, 2), [Vector2i(1, 1)]))
	var fallen := hole_session.submit(BattleCommand.attack(&"player", Vector2i(1, 2)))
	_expect_equal(hole_session.state.battle_outcome, &"victory", "pushing the last enemy into a hole wins immediately")
	_expect(not hole_session.state.get_unit(&"guard").active, "enemy pushed into a time hole dies")
	_expect(_has_event(fallen, &"unit_died"), "time-hole fall publishes death event")


func _test_knockback_collision_damages_both_units() -> void:
	var state := _create_collision_state()
	var session := BattleSession.new(state)
	var result := session.submit(BattleCommand.attack(&"player", Vector2i(1, 2)))
	var pushed := session.state.get_unit(&"guard")
	var blocker := session.state.get_unit(&"guard_02")
	_expect(result.accepted, "attack into an occupied knockback cell is accepted")
	_expect_equal(pushed.position, Vector2i(1, 2), "colliding pushed enemy stays in its original cell")
	_expect_equal(blocker.position, Vector2i(1, 1), "collision target stays in its original cell")
	_expect_equal(pushed.hp, 1, "pushed enemy takes attack damage plus one collision damage")
	_expect_equal(blocker.hp, 2, "collision target takes one collision damage")
	_expect(_has_event(result, &"units_collided"), "enemy collision publishes a dedicated event")
	_expect(not _has_event(result, &"unit_pushed"), "enemy collision does not publish a movement event")
	_expect_equal(session.state.current_recording[0].result.push_result.outcome, &"collision", "recorded attack stores the collision outcome")
	_expect_equal(session.state.current_recording[0].result.push_result.collision_target_id, &"guard_02", "collision result identifies the second unit")
	_expect_equal(_count_damage_events(result, &"collision"), 2, "collision emits one damage event for each unit")


func _test_collision_can_defeat_both_enemies() -> void:
	var state := _create_collision_state()
	state.get_unit(&"guard").hp = 2
	state.get_unit(&"guard_02").hp = 1
	var session := BattleSession.new(state)
	var result := session.submit(BattleCommand.attack(&"player", Vector2i(1, 2)))
	_expect(not session.state.get_unit(&"guard").active, "attack plus collision can defeat the pushed enemy")
	_expect(not session.state.get_unit(&"guard_02").active, "collision damage can defeat the second enemy")
	_expect_equal(session.state.battle_outcome, &"victory", "simultaneous collision deaths can complete the battle")
	_expect(_has_event(result, &"battle_won"), "collision victory publishes the battle-won event")


func _test_ghost_replays_fixed_knockback_direction() -> void:
	var state := _create_micro_state(Vector2i(1, 3), Vector2i(1, 2), [Vector2i(1, 1)])
	state.phase = BattlePhase.TIMELINE_TRANSITION
	state.timeline_recordings = [{
		"timeline_index": 1,
		"end_turn": 1,
		"end_reason": &"death",
		"actions": [_recorded_attack(Vector2i(1, 3), Vector2i(1, 2), Vector2i(0, -1))],
	}]
	var session := BattleSession.new(state)
	var result := session.submit(BattleCommand.start_next_timeline())
	_expect(result.accepted, "timeline with recorded push starts")
	_expect_equal(session.state.battle_outcome, &"victory", "ghost fixed push can drop current enemy into a hole")
	_expect(_has_event(result, &"unit_pushed"), "ghost knockback publishes displacement event")


func _test_ghost_replays_collision_against_current_unit() -> void:
	var state := _create_collision_state()
	state.phase = BattlePhase.TIMELINE_TRANSITION
	state.timeline_recordings = [{
		"timeline_index": 1,
		"end_turn": 1,
		"end_reason": &"death",
		"actions": [_recorded_attack(Vector2i(1, 3), Vector2i(1, 2), Vector2i(0, -1))],
	}]
	var session := BattleSession.new(state)
	var result := session.submit(BattleCommand.start_next_timeline())
	_expect(result.accepted, "timeline with a recorded collision starts")
	_expect(_has_event(result, &"units_collided"), "ghost knockback resolves collision against the current board")
	_expect_equal(session.state.get_unit(&"guard").hp, 1, "ghost target takes recorded attack and collision damage")
	_expect_equal(session.state.get_unit(&"guard_02").hp, 2, "current collision target takes ghost collision damage")
	_expect_equal(session.state.get_unit(&"guard").position, Vector2i(1, 2), "ghost collision keeps the pushed enemy in place")


func _test_matching_ghost_displacement_preserves_fixed_history() -> void:
	var state := _create_micro_state(Vector2i(1, 3), Vector2i(1, 2))
	state.phase = BattlePhase.TIMELINE_TRANSITION
	state.enemy_history[1] = [_fixed_move_intent(Vector2i(1, 1), Vector2i(2, 1))]
	state.timeline_recordings = [{
		"timeline_index": 1,
		"end_turn": 1,
		"end_reason": &"death",
		"actions": [_recorded_attack(Vector2i(1, 3), Vector2i(1, 2), Vector2i.UP)],
	}]
	var session := BattleSession.new(state)
	var result := session.submit(BattleCommand.start_next_timeline())

	_expect(result.accepted, "T2 starts with a matching recorded displacement")
	_expect_equal(session.state.get_unit(&"guard").position, Vector2i(1, 1), "T1 ghost reconstructs the fixed enemy starting position")
	_expect(not _has_event(result, &"enemy_disturbed"), "matching T1 displacement does not disturb the enemy in T2")
	_expect_equal(int(session.state.get_unit(&"guard").statuses.get("awake_from_turn", 0)), 0, "matching historical replay keeps the enemy fixed")
	_expect(not bool(session.state.locked_enemy_intents[0].reactive), "matching historical replay preserves the locked intent")


func _test_multiple_ghost_displacements_preserve_fixed_history() -> void:
	var state := _create_micro_state(Vector2i(1, 3), Vector2i(1, 2))
	state.timeline_index = 2
	state.phase = BattlePhase.TIMELINE_TRANSITION
	state.enemy_history[1] = [_fixed_move_intent(Vector2i(0, 1), Vector2i(0, 2))]
	state.timeline_recordings = [
		{
			"timeline_index": 1,
			"end_turn": 1,
			"end_reason": &"death",
			"actions": [_recorded_attack(Vector2i(1, 3), Vector2i(1, 2), Vector2i.UP)],
		},
		{
			"timeline_index": 2,
			"end_turn": 1,
			"end_reason": &"crystallized",
			"actions": [_recorded_attack(Vector2i(2, 1), Vector2i(1, 1), Vector2i.LEFT)],
		},
	]
	var session := BattleSession.new(state)
	var result := session.submit(BattleCommand.start_next_timeline())

	_expect(result.accepted, "T3 starts with two recorded displacements")
	_expect_equal(session.state.get_unit(&"guard").position, Vector2i(0, 1), "multiple ghosts collectively reconstruct the fixed starting position")
	_expect(not _has_event(result, &"enemy_disturbed"), "intermediate ghost positions do not cause false disturbance")
	_expect(not bool(session.state.locked_enemy_intents[0].reactive), "collective historical reconstruction keeps the enemy fixed")


func _test_divergent_ghost_replay_disturbs_enemy() -> void:
	var state := _create_micro_state(Vector2i(1, 3), Vector2i(1, 2))
	state.phase = BattlePhase.TIMELINE_TRANSITION
	state.enemy_history[1] = [_fixed_move_intent(Vector2i(2, 1), Vector2i(2, 2))]
	state.timeline_recordings = [{
		"timeline_index": 1,
		"end_turn": 1,
		"end_reason": &"death",
		"actions": [_recorded_attack(Vector2i(1, 3), Vector2i(1, 2), Vector2i.UP)],
	}]
	var session := BattleSession.new(state)
	var result := session.submit(BattleCommand.start_next_timeline())
	var disturbed := _find_event(result, &"enemy_disturbed")

	_expect(result.accepted, "T2 starts even when ghost replay diverges from fixed history")
	_expect(disturbed != null, "ghost replay that misses the fixed starting state marks disturbance")
	_expect_equal(disturbed.payload.get("reason", &""), &"history_diverged", "replay divergence reports a stable disturbance reason")
	_expect_equal(disturbed.payload.get("expected_position", Vector2i.ZERO), Vector2i(2, 1), "divergence reports the fixed starting position")
	_expect_equal(disturbed.payload.get("actual_position", Vector2i.ZERO), Vector2i(1, 1), "divergence reports the reconstructed actual position")
	_expect_equal(session.state.get_unit(&"guard").statuses.awake_from_turn, 2, "divergent ghost replay wakes the enemy next turn")
	_expect(not bool(session.state.locked_enemy_intents[0].reactive), "divergence does not rewrite the current locked intent")


func _test_fixed_history_collision_pushes_player() -> void:
	var state := _create_micro_state(Vector2i(1, 2), Vector2i(1, 1))
	state.timeline_index = 2
	state.enemy_history[1] = [_fixed_move_intent(Vector2i(1, 1), Vector2i(1, 2))]
	var session := BattleSession.new(state)
	var result := session.submit(BattleCommand.end_turn(&"player"))
	_expect(result.accepted, "fixed-history collision turn resolves")
	_expect_equal(session.state.get_unit(&"player").position, Vector2i(1, 3), "historical enemy endpoint pushes player forward")
	_expect_equal(session.state.get_unit(&"guard").position, Vector2i(1, 2), "historical enemy keeps endpoint priority")
	_expect(_has_event(result, &"unit_pushed"), "history collision publishes player displacement")


func _test_fixed_history_collision_into_hole_ends_timeline() -> void:
	var state := _create_micro_state(Vector2i(1, 2), Vector2i(1, 1), [Vector2i(1, 3)])
	state.timeline_index = 2
	state.enemy_history[1] = [_fixed_move_intent(Vector2i(1, 1), Vector2i(1, 2))]
	var session := BattleSession.new(state)
	var result := session.submit(BattleCommand.end_turn(&"player"))
	_expect_equal(session.state.phase, BattlePhase.TIMELINE_TRANSITION, "collision into time hole ends current timeline")
	_expect_equal(session.state.lives_left, 1, "history collision death consumes one life")
	_expect(_has_event(result, &"timeline_ended"), "history collision publishes timeline transition")


func _test_disturbance_wakes_enemy_next_turn() -> void:
	var state := _create_micro_state(Vector2i(1, 3), Vector2i(1, 2))
	state.timeline_index = 2
	state.enemy_history[1] = [_fixed_move_intent(Vector2i(1, 2), Vector2i(1, 3))]
	state.enemy_history[2] = [_fixed_move_intent(Vector2i(1, 2), Vector2i(2, 2))]
	var session := BattleSession.new(state)
	var attack := session.submit(BattleCommand.attack(&"player", Vector2i(1, 2)))
	_expect(_has_event(attack, &"enemy_disturbed"), "pushing fixed enemy marks disturbance")
	_expect_equal(_find_event(attack, &"enemy_disturbed").payload.get("reason", &""), &"direct_interference", "current player displacement reports direct interference")
	_expect_equal(session.state.get_unit(&"guard").statuses.awake_from_turn, 2, "disturbance starts on next turn")
	var first_end := session.submit(BattleCommand.end_turn(&"player"))
	_expect(_has_event(first_end, &"action_invalidated"), "current locked action fails after enemy leaves historical origin")
	_expect_equal(session.state.turn_index, 2, "disturbed enemy reaches next turn")
	_expect_equal(session.state.time_state, &"disturbed", "next known turn is marked disturbed")
	_expect(bool(session.state.locked_enemy_intents[0].reactive), "awake enemy preview hides a reactive intent")
	var second_end := session.submit(BattleCommand.end_turn(&"player"))
	var resolved := _find_event(second_end, &"enemy_intents_locked")
	_expect(bool(resolved.payload.intents[0].reactive), "awake enemy recomputes its action at execution time")


func _test_awake_state_resets_on_next_timeline() -> void:
	var state := _create_micro_state(Vector2i(1, 3), Vector2i(1, 2))
	state.timeline_index = 2
	state.rules["crystallize_enabled"] = true
	state.enemy_history[1] = [_fixed_move_intent(Vector2i(1, 2), Vector2i(1, 3))]
	state.enemy_history[2] = [_fixed_move_intent(Vector2i(1, 2), Vector2i(2, 2))]
	var session := BattleSession.new(state)

	session.submit(BattleCommand.attack(&"player", Vector2i(1, 2)))
	session.submit(BattleCommand.end_turn(&"player"))
	_expect_equal(session.state.turn_index, 2, "disturbed T2 enemy reaches its awake turn")
	_expect(bool(session.state.locked_enemy_intents[0].reactive), "enemy is awake only inside the disturbed timeline")
	session.submit(BattleCommand.end_turn(&"player"))
	# Isolate timeline-state inheritance from a fresh displacement replayed by the
	# new ghost. If the attack recording remained, T3 reconstruction would end
	# away from the rewritten fixed starting position and correctly disturb again.
	session.state.current_recording.clear()
	_expect(session.submit(BattleCommand.crystallize(&"player")).accepted, "disturbed timeline can be committed after recording awake behavior")
	_expect(session.submit(BattleCommand.start_next_timeline()).accepted, "next timeline starts after disturbed history is committed")

	_expect_equal(session.state.timeline_index, 3, "successor is the third timeline")
	_expect_equal(int(session.state.get_unit(&"guard").statuses.get("awake_from_turn", 0)), 0, "awake marker does not carry from T2 into T3")
	_expect(not bool(session.state.locked_enemy_intents[0].reactive), "T3 begins by treating rewritten T2 history as fixed")
	session.submit(BattleCommand.end_turn(&"player"))
	_expect_equal(session.state.turn_index, 2, "T3 reaches the turn whose behavior was rewritten in T2")
	_expect(not bool(session.state.locked_enemy_intents[0].reactive), "recorded awake behavior becomes fixed history in T3 until disturbed again")


func _test_crystallize_commits_without_enemy_phase() -> void:
	var state := _create_micro_state(Vector2i(1, 3), Vector2i(1, 2))
	state.rules["crystallize_enabled"] = true
	var session := BattleSession.new(state)
	var result := session.submit(BattleCommand.crystallize(&"player"))
	_expect(result.accepted, "unlocked crystallize command is accepted")
	_expect_equal(session.state.phase, BattlePhase.TIMELINE_TRANSITION, "crystallize enters timeline transition immediately")
	_expect_equal(session.state.lives_left, 1, "crystallize consumes one life")
	_expect_equal(session.state.timeline_recordings.size(), 1, "crystallize commits current recording")
	_expect_equal(session.state.timeline_recordings[0].end_reason, &"crystallized", "crystallized recording keeps distinct end reason")
	_expect(not _has_event(result, &"enemy_intents_locked"), "crystallize skips enemy phase")
	_expect(_has_event(result, &"timeline_crystallized"), "crystallize publishes dedicated event")
	_expect(session.submit(BattleCommand.start_next_timeline()).accepted, "crystallized timeline can start its successor")
	var rejected := session.submit(BattleCommand.crystallize(&"player"))
	_expect(not rejected.accepted, "last life cannot crystallize")
	_expect_equal(rejected.reason, &"last_life_cannot_crystallize", "last-life crystallize returns stable reason")


func _has_event(result: CommandResult, event_type: StringName) -> bool:
	for event in result.events:
		if event.event_type == event_type:
			return true
	return false


func _count_damage_events(result: CommandResult, cause: StringName) -> int:
	var count := 0
	for event in result.events:
		if event.event_type == &"damage_applied" and event.payload.get("cause", &"") == cause:
			count += 1
	return count


func _find_event(result: CommandResult, event_type: StringName) -> BattleEvent:
	for event in result.events:
		if event.event_type == event_type:
			return event
	return null


func _create_micro_state(player_position: Vector2i, enemy_position: Vector2i, holes: Array[Vector2i] = []) -> BattleState:
	var state := BattleState.new()
	state.battle_id = &"micro"
	state.level_id = &"micro_push"
	state.board_size = Vector2i(5, 5)
	state.holes.assign(holes)
	state.rules = {"push_enabled": true}
	state.lives_left = 2
	state.player_id = &"player"
	state.player_start = player_position
	state.phase = BattlePhase.PLAYER_INPUT
	state.time_state = &"unknown"

	var player := _make_unit(&"player", &"player", player_position, 3, 3, 1)
	var enemy := _make_unit(&"guard", &"enemy", enemy_position, 3, 2, 1)
	for unit in [player, enemy]:
		state.units[unit.unit_id] = unit
		state.unit_order.append(unit.unit_id)
		state.initial_units[unit.unit_id] = unit.to_dict()
	return state


func _create_collision_state() -> BattleState:
	var state := _create_micro_state(Vector2i(1, 3), Vector2i(1, 2))
	var blocker := _make_unit(&"guard_02", &"enemy", Vector2i(1, 1), 3, 2, 1)
	state.units[blocker.unit_id] = blocker
	state.unit_order.append(blocker.unit_id)
	state.initial_units[blocker.unit_id] = blocker.to_dict()
	return state


func _make_unit(unit_id: StringName, team: StringName, position: Vector2i, hp: int, move_range: int, damage: int) -> UnitState:
	var unit := UnitState.new()
	unit.unit_id = unit_id
	unit.definition_id = StringName("%s_test" % unit_id)
	unit.team = team
	unit.position = position
	unit.hp = hp
	unit.max_hp = hp
	unit.move_range = move_range
	unit.attack_damage = damage
	return unit


func _recorded_attack(origin: Vector2i, target: Vector2i, push_direction: Vector2i) -> Dictionary:
	var action := RecordedAction.new()
	action.action_id = &"recorded_attack"
	action.actor_id = &"player"
	action.action_type = BattleCommand.ATTACK
	action.turn_index = 1
	action.phase = BattlePhase.PLAYER_INPUT
	action.origin = origin
	action.target = target
	action.result = {"hit": true, "damage": 1, "push_direction": push_direction}
	return action.to_dict()


func _fixed_move_intent(origin: Vector2i, target: Vector2i) -> Dictionary:
	return {
		"enemy_id": &"guard",
		"from": origin,
		"to": target,
		"path": [origin, target],
		"last_direction": target - origin,
		"target": Vector2i(-1, -1),
		"damage": 1,
		"intent_type": &"move",
	}


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
