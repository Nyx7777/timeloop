class_name BattleSimulator
extends RefCounted

const ENEMY_DIRECTIONS := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]


func apply_command(state: BattleState, command: BattleCommand) -> CommandResult:
	match command.command_type:
		BattleCommand.MOVE:
			return _apply_move(state, command)
		BattleCommand.ATTACK:
			return _apply_attack(state, command)
		BattleCommand.END_TURN:
			return _apply_end_turn(state, command)
		BattleCommand.START_NEXT_TIMELINE:
			return _apply_start_next_timeline(state)
		_:
			return CommandResult.reject(&"unsupported_command")


func _apply_move(state: BattleState, command: BattleCommand) -> CommandResult:
	var common_rejection := _validate_player_command(state, command)
	if not common_rejection.is_empty():
		return CommandResult.reject(common_rejection)

	var unit := state.get_unit(command.actor_id)
	if unit.has_moved:
		return CommandResult.reject(&"move_already_used")

	var path := GridQuery.find_path(state, unit.position, command.target_cell, unit.move_range, unit.unit_id)
	if path.is_empty():
		return CommandResult.reject(&"destination_unreachable")

	var origin := unit.position
	unit.position = command.target_cell
	unit.has_moved = true

	var action := _new_recorded_action(state, unit.unit_id, BattleCommand.MOVE, origin, command.target_cell)
	action.result = {"path": path}
	state.current_recording.append(action)

	var event := BattleEvent.create(&"unit_moved", unit.unit_id, {
		"from": origin,
		"to": command.target_cell,
		"path": path,
		"is_ghost": false,
	})
	var events: Array[BattleEvent] = [event]
	var actions: Array[RecordedAction] = [action]
	return CommandResult.accept(events, actions)


func _apply_attack(state: BattleState, command: BattleCommand) -> CommandResult:
	var common_rejection := _validate_player_command(state, command)
	if not common_rejection.is_empty():
		return CommandResult.reject(common_rejection)

	var attacker := state.get_unit(command.actor_id)
	if attacker.has_acted:
		return CommandResult.reject(&"action_already_used")
	if _manhattan(attacker.position, command.target_cell) != 1:
		return CommandResult.reject(&"target_out_of_range")

	var target := _find_active_unit_at(state, command.target_cell, &"enemy")
	if target == null:
		return CommandResult.reject(&"no_legal_target")

	attacker.has_acted = true
	var action := _new_recorded_action(state, attacker.unit_id, BattleCommand.ATTACK, attacker.position, command.target_cell)
	action.result = {
		"hit": true,
		"damage": attacker.attack_damage,
	}
	state.current_recording.append(action)

	var events: Array[BattleEvent] = []
	events.append(BattleEvent.create(&"attack_performed", attacker.unit_id, {
		"target_cell": command.target_cell,
		"is_ghost": false,
	}))
	_apply_damage(state, target, attacker.attack_damage, attacker.unit_id, events)

	var won := _all_enemies_defeated(state)
	if won:
		_mark_victory(state, events)
	var actions: Array[RecordedAction] = [action]
	return CommandResult.accept(events, actions, won)


func _apply_end_turn(state: BattleState, command: BattleCommand) -> CommandResult:
	var common_rejection := _validate_player_command(state, command)
	if not common_rejection.is_empty():
		return CommandResult.reject(common_rejection)

	var events: Array[BattleEvent] = []
	state.phase = BattlePhase.ENEMY_EXECUTION
	events.append(_phase_event(state.phase))

	var intents: Array = []
	var fixed_history := state.enemy_history.has(state.turn_index)
	if fixed_history:
		intents = VariantCodec.deep_copy(state.enemy_history[state.turn_index])
		state.time_state = &"known"
	else:
		intents = _compute_reactive_intents(state)
		state.current_enemy_history[state.turn_index] = VariantCodec.deep_copy(intents)
		state.time_state = &"unknown"
	state.locked_enemy_intents = VariantCodec.deep_copy(intents)
	events.append(BattleEvent.create(&"enemy_intents_locked", &"", {
		"time_state": state.time_state,
		"intents": intents,
	}))

	_execute_enemy_intents(state, intents, fixed_history, events)
	if state.phase == BattlePhase.TIMELINE_TRANSITION:
		return CommandResult.accept(events)
	if state.phase == BattlePhase.BATTLE_OVER:
		return CommandResult.accept(events, [], true)

	state.turn_index += 1
	_begin_turn(state, events)
	return CommandResult.accept(events)


func _apply_start_next_timeline(state: BattleState) -> CommandResult:
	if state.phase != BattlePhase.TIMELINE_TRANSITION:
		return CommandResult.reject(&"not_timeline_transition")
	if state.lives_left <= 0:
		return CommandResult.reject(&"no_lives_remaining")

	state.timeline_index += 1
	state.turn_index = 1
	state.current_recording.clear()
	state.current_enemy_history.clear()
	state.locked_enemy_intents.clear()
	state.battle_outcome = &""
	_restore_initial_units(state)
	_reset_ghost_positions(state)

	var events: Array[BattleEvent] = []
	events.append(BattleEvent.create(&"timeline_started", state.player_id, {
		"timeline_index": state.timeline_index,
		"lives_left": state.lives_left,
	}))
	_begin_turn(state, events)
	return CommandResult.accept(events, [], true)


func _begin_turn(state: BattleState, events: Array[BattleEvent]) -> void:
	var player := state.get_unit(state.player_id)
	if player != null:
		player.has_moved = false
		player.has_acted = false

	_update_active_ghosts(state)
	if state.enemy_history.has(state.turn_index):
		state.time_state = &"known"
		state.locked_enemy_intents = VariantCodec.deep_copy(state.enemy_history[state.turn_index])
	else:
		state.time_state = &"unknown"
		state.locked_enemy_intents.clear()

	events.append(BattleEvent.create(&"turn_started", &"", {
		"turn_index": state.turn_index,
		"timeline_index": state.timeline_index,
		"time_state": state.time_state,
		"enemy_intents": state.locked_enemy_intents,
	}))
	state.phase = BattlePhase.GHOST_PLAYBACK
	events.append(_phase_event(state.phase))
	_execute_ghost_actions(state, events)
	if state.phase == BattlePhase.BATTLE_OVER or state.phase == BattlePhase.TIMELINE_TRANSITION:
		return
	state.phase = BattlePhase.PLAYER_INPUT
	events.append(_phase_event(state.phase))


func _execute_ghost_actions(state: BattleState, events: Array[BattleEvent]) -> void:
	for timeline_data in state.timeline_recordings:
		var record: Dictionary = timeline_data
		var timeline_number := int(record.get("timeline_index", 0))
		if state.turn_index > int(record.get("end_turn", 0)):
			continue
		var ghost_id := StringName("ghost_t%d" % timeline_number)
		for action_data in record.get("actions", []):
			var action := RecordedAction.from_dict(action_data)
			if action.turn_index != state.turn_index:
				continue
			if action.action_type == BattleCommand.MOVE:
				state.ghost_positions[ghost_id] = action.target
				events.append(BattleEvent.create(&"unit_moved", ghost_id, {
					"from": action.origin,
					"to": action.target,
					"path": action.result.get("path", [action.origin, action.target]),
					"is_ghost": true,
					"source_timeline": timeline_number,
				}))
			elif action.action_type == BattleCommand.ATTACK:
				_execute_ghost_attack(state, ghost_id, timeline_number, action, events)
				if state.phase == BattlePhase.BATTLE_OVER or state.phase == BattlePhase.TIMELINE_TRANSITION:
					return


func _execute_ghost_attack(state: BattleState, ghost_id: StringName, timeline_number: int, action: RecordedAction, events: Array[BattleEvent]) -> void:
	events.append(BattleEvent.create(&"attack_performed", ghost_id, {
		"target_cell": action.target,
		"is_ghost": true,
		"source_timeline": timeline_number,
	}))
	var target := _find_active_unit_at(state, action.target, &"enemy")
	if target == null:
		var player := state.get_unit(state.player_id)
		if player != null and player.active and player.position == action.target:
			target = player
	if target == null:
		events.append(BattleEvent.create(&"action_invalidated", ghost_id, {
			"action_type": BattleCommand.ATTACK,
			"target_cell": action.target,
			"reason": &"empty_target_cell",
		}))
		return

	var damage := int(action.result.get("damage", 0))
	_apply_damage(state, target, damage, ghost_id, events)
	if target.team == &"enemy" and _all_enemies_defeated(state):
		_mark_victory(state, events)
	elif target.unit_id == state.player_id and not target.active:
		_handle_player_death(state, &"ghost_attack", events)


func _compute_reactive_intents(state: BattleState) -> Array:
	var intents: Array = []
	for unit_id in state.unit_order:
		var enemy := state.get_unit(unit_id)
		if enemy == null or not enemy.active or enemy.team != &"enemy":
			continue
		intents.append(_compute_reactive_intent(state, enemy))
	return intents


func _compute_reactive_intent(state: BattleState, enemy: UnitState) -> Dictionary:
	var player := state.get_unit(state.player_id)
	var current := enemy.position
	var last_direction := Vector2i.ZERO

	if _manhattan(current, player.position) > 1:
		for step in range(enemy.move_range):
			var best_direction := Vector2i.ZERO
			var best_distance := _manhattan(current, player.position)
			for direction in ENEMY_DIRECTIONS:
				var next: Vector2i = current + direction
				if not _is_enemy_step_valid(state, enemy.unit_id, next):
					continue
				var distance := _manhattan(next, player.position)
				if distance < best_distance:
					best_distance = distance
					best_direction = direction
			if best_direction == Vector2i.ZERO:
				break
			current += best_direction
			last_direction = best_direction
			if _manhattan(current, player.position) <= 1:
				break

	var did_move := current != enemy.position
	var adjacent := _manhattan(current, player.position) <= 1
	var intent := {
		"enemy_id": enemy.unit_id,
		"from": enemy.position,
		"to": current,
		"last_direction": last_direction,
		"target": player.position,
		"damage": enemy.attack_damage,
		"intent_type": &"wait",
	}
	if did_move and adjacent:
		intent.intent_type = &"move_attack"
	elif did_move:
		intent.intent_type = &"move"
	elif adjacent:
		intent.intent_type = &"attack"
	return intent


func _execute_enemy_intents(state: BattleState, intents: Array, fixed_history: bool, events: Array[BattleEvent]) -> void:
	for intent_data in intents:
		var intent: Dictionary = intent_data
		var enemy_id: StringName = intent.get("enemy_id", &"")
		var enemy := state.get_unit(enemy_id)
		if enemy == null or not enemy.active:
			continue
		var origin: Vector2i = intent.get("from", enemy.position)
		if fixed_history and enemy.position != origin:
			events.append(BattleEvent.create(&"action_invalidated", enemy.unit_id, {
				"action_type": intent.get("intent_type", &"wait"),
				"reason": &"history_origin_changed",
			}))
			continue

		var intent_type: StringName = intent.get("intent_type", &"wait")
		if intent_type == &"move" or intent_type == &"move_attack":
			var destination: Vector2i = intent.get("to", enemy.position)
			if _is_enemy_destination_open(state, enemy.unit_id, destination):
				var move_origin := enemy.position
				enemy.position = destination
				events.append(BattleEvent.create(&"unit_moved", enemy.unit_id, {
					"from": move_origin,
					"to": destination,
					"is_ghost": false,
				}))
			else:
				events.append(BattleEvent.create(&"action_invalidated", enemy.unit_id, {
					"action_type": &"move",
					"reason": &"destination_blocked",
				}))
				continue

		if intent_type == &"attack" or intent_type == &"move_attack":
			var target_cell: Vector2i = intent.get("target", Vector2i(-1, -1))
			events.append(BattleEvent.create(&"attack_performed", enemy.unit_id, {
				"target_cell": target_cell,
				"is_ghost": false,
			}))
			var player := state.get_unit(state.player_id)
			if player != null and player.active and player.position == target_cell:
				_apply_damage(state, player, int(intent.get("damage", enemy.attack_damage)), enemy.unit_id, events)
				if not player.active:
					_handle_player_death(state, &"enemy_attack", events)
					return
			else:
				events.append(BattleEvent.create(&"action_invalidated", enemy.unit_id, {
					"action_type": &"attack",
					"target_cell": target_cell,
					"reason": &"target_left_cell",
				}))


func _handle_player_death(state: BattleState, cause: StringName, events: Array[BattleEvent]) -> void:
	state.lives_left -= 1
	if state.lives_left <= 0:
		state.phase = BattlePhase.BATTLE_OVER
		state.battle_outcome = &"defeat"
		events.append(BattleEvent.create(&"battle_lost", state.player_id, {
			"cause": cause,
			"timeline_index": state.timeline_index,
		}))
		return

	_commit_current_timeline(state, &"death")
	state.phase = BattlePhase.TIMELINE_TRANSITION
	events.append(BattleEvent.create(&"timeline_ended", state.player_id, {
		"end_reason": &"death",
		"cause": cause,
		"timeline_index": state.timeline_index,
		"lives_left": state.lives_left,
	}))


func _commit_current_timeline(state: BattleState, end_reason: StringName) -> void:
	var action_data: Array = []
	for action in state.current_recording:
		action_data.append(action.to_dict())
	state.timeline_recordings.append({
		"timeline_index": state.timeline_index,
		"end_turn": state.turn_index,
		"end_reason": end_reason,
		"actions": action_data,
	})
	for turn_key in state.current_enemy_history.keys():
		state.enemy_history[turn_key] = VariantCodec.deep_copy(state.current_enemy_history[turn_key])


func _restore_initial_units(state: BattleState) -> void:
	state.units.clear()
	for unit_id in state.unit_order:
		var key := String(unit_id)
		if state.initial_units.has(key):
			var restored_from_string := UnitState.from_dict(state.initial_units[key])
			state.units[restored_from_string.unit_id] = restored_from_string
		elif state.initial_units.has(unit_id):
			var restored_from_name := UnitState.from_dict(state.initial_units[unit_id])
			state.units[restored_from_name.unit_id] = restored_from_name


func _reset_ghost_positions(state: BattleState) -> void:
	state.ghost_positions.clear()
	for timeline_data in state.timeline_recordings:
		var record: Dictionary = timeline_data
		var ghost_id := StringName("ghost_t%d" % int(record.get("timeline_index", 0)))
		state.ghost_positions[ghost_id] = state.player_start


func _update_active_ghosts(state: BattleState) -> void:
	var active_ids: Dictionary = {}
	for timeline_data in state.timeline_recordings:
		var record: Dictionary = timeline_data
		if state.turn_index <= int(record.get("end_turn", 0)):
			var ghost_id := StringName("ghost_t%d" % int(record.get("timeline_index", 0)))
			active_ids[ghost_id] = true
			if not state.ghost_positions.has(ghost_id):
				state.ghost_positions[ghost_id] = state.player_start
	for ghost_id in state.ghost_positions.keys():
		if not active_ids.has(ghost_id):
			state.ghost_positions.erase(ghost_id)


func _validate_player_command(state: BattleState, command: BattleCommand) -> StringName:
	if state.phase != BattlePhase.PLAYER_INPUT:
		return &"not_player_input_phase"
	if command.actor_id != state.player_id:
		return &"actor_not_controlled"
	var unit := state.get_unit(command.actor_id)
	if unit == null or not unit.active:
		return &"actor_unavailable"
	return &""


func _new_recorded_action(state: BattleState, actor_id: StringName, action_type: StringName, origin: Vector2i, target: Vector2i) -> RecordedAction:
	var action := RecordedAction.new()
	action.action_id = StringName("t%d_turn%d_cmd%d" % [state.timeline_index, state.turn_index, state.command_index + 1])
	action.actor_id = actor_id
	action.action_type = action_type
	action.turn_index = state.turn_index
	action.phase = state.phase
	action.origin = origin
	action.target = target
	return action


func _apply_damage(state: BattleState, target: UnitState, damage: int, source_id: StringName, events: Array[BattleEvent]) -> void:
	target.hp = maxi(0, target.hp - damage)
	events.append(BattleEvent.create(&"damage_applied", source_id, {
		"target_id": target.unit_id,
		"damage": damage,
		"remaining_hp": target.hp,
	}))
	if target.hp <= 0:
		target.active = false
		events.append(BattleEvent.create(&"unit_died", target.unit_id, {
			"source_id": source_id,
			"cell": target.position,
		}))


func _mark_victory(state: BattleState, events: Array[BattleEvent]) -> void:
	_commit_current_timeline(state, &"victory")
	state.phase = BattlePhase.BATTLE_OVER
	state.battle_outcome = &"victory"
	events.append(BattleEvent.create(&"battle_won", state.player_id, {
		"timeline_index": state.timeline_index,
		"turn_index": state.turn_index,
	}))


func _all_enemies_defeated(state: BattleState) -> bool:
	for unit_id in state.unit_order:
		var unit := state.get_unit(unit_id)
		if unit != null and unit.team == &"enemy" and unit.active:
			return false
	return true


func _find_active_unit_at(state: BattleState, cell: Vector2i, required_team: StringName = &"") -> UnitState:
	for unit_id in state.unit_order:
		var unit := state.get_unit(unit_id)
		if unit == null or not unit.active or unit.position != cell:
			continue
		if required_team.is_empty() or unit.team == required_team:
			return unit
	return null


func _is_enemy_step_valid(state: BattleState, moving_enemy: StringName, cell: Vector2i) -> bool:
	if not GridQuery.is_in_bounds(state, cell) or state.walls.has(cell) or state.holes.has(cell):
		return false
	for unit_id in state.unit_order:
		var unit := state.get_unit(unit_id)
		if unit != null and unit.active and unit.team == &"enemy" and unit.unit_id != moving_enemy and unit.position == cell:
			return false
	return true


func _is_enemy_destination_open(state: BattleState, moving_enemy: StringName, cell: Vector2i) -> bool:
	if not _is_enemy_step_valid(state, moving_enemy, cell):
		return false
	var player := state.get_unit(state.player_id)
	return player == null or not player.active or player.position != cell


func _phase_event(phase: StringName) -> BattleEvent:
	return BattleEvent.create(&"phase_changed", &"", {"phase": phase})


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
