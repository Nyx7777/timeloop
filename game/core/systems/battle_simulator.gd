class_name BattleSimulator
extends RefCounted

const ENEMY_DIRECTIONS := [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
const DisplacementQueryScript := preload("res://core/queries/displacement_query.gd")
const COLLISION_DAMAGE := 1


func apply_command(state: BattleState, command: BattleCommand) -> CommandResult:
	match command.command_type:
		BattleCommand.MOVE:
			return _apply_move(state, command)
		BattleCommand.ATTACK:
			return _apply_attack(state, command)
		BattleCommand.END_TURN:
			return _apply_end_turn(state, command)
		BattleCommand.CRYSTALLIZE:
			return _apply_crystallize(state, command)
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
	var push_direction := command.target_cell - attacker.position
	action.result = {
		"hit": true,
		"damage": attacker.attack_damage,
		"push_direction": push_direction,
	}
	state.current_recording.append(action)

	var events: Array[BattleEvent] = []
	events.append(BattleEvent.create(&"attack_performed", attacker.unit_id, {
		"target_cell": command.target_cell,
		"is_ghost": false,
	}))
	_apply_damage(state, target, attacker.attack_damage, attacker.unit_id, events)
	if target.active and _is_push_enabled(state):
		action.result["push_result"] = _apply_knockback(state, target, push_direction, attacker.unit_id, events)

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
	var has_history := state.enemy_history.has(state.turn_index)
	if has_history:
		intents = _resolve_known_time_intents(state)
		state.time_state = &"disturbed" if _has_reactive_intent(intents) else &"known"
	else:
		intents = _compute_reactive_intents(state)
		state.time_state = &"unknown"
	state.current_enemy_history[state.turn_index] = VariantCodec.deep_copy(intents)
	state.locked_enemy_intents = VariantCodec.deep_copy(intents)
	events.append(BattleEvent.create(&"enemy_intents_locked", &"", {
		"time_state": state.time_state,
		"intents": intents,
	}))

	_execute_enemy_intents(state, intents, has_history, events)
	if state.phase == BattlePhase.TIMELINE_TRANSITION:
		return CommandResult.accept(events)
	if state.phase == BattlePhase.BATTLE_OVER:
		return CommandResult.accept(events, [], true)

	state.turn_index += 1
	_begin_turn(state, events)
	return CommandResult.accept(events)


func _apply_crystallize(state: BattleState, command: BattleCommand) -> CommandResult:
	var common_rejection := _validate_player_command(state, command)
	if not common_rejection.is_empty():
		return CommandResult.reject(common_rejection)
	if not bool(state.rules.get("crystallize_enabled", false)):
		return CommandResult.reject(&"crystallize_not_unlocked")
	if state.lives_left <= 1:
		return CommandResult.reject(&"last_life_cannot_crystallize")

	state.lives_left -= 1
	_commit_current_timeline(state, &"crystallized")
	state.phase = BattlePhase.TIMELINE_TRANSITION
	var events: Array[BattleEvent] = [
		BattleEvent.create(&"timeline_crystallized", state.player_id, {
			"timeline_index": state.timeline_index,
			"lives_left": state.lives_left,
		}),
		BattleEvent.create(&"timeline_ended", state.player_id, {
			"end_reason": &"crystallized",
			"cause": &"player_choice",
			"timeline_index": state.timeline_index,
			"lives_left": state.lives_left,
		}),
	]
	return CommandResult.accept(events, [], true)


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
		"units": _build_unit_view_data(state),
		"ghost_positions": state.ghost_positions,
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
		state.locked_enemy_intents = _build_known_time_preview(state)
		state.time_state = &"disturbed" if _has_reactive_intent(state.locked_enemy_intents) else &"known"
	else:
		state.time_state = &"unknown"
		state.locked_enemy_intents.clear()

	events.append(BattleEvent.create(&"turn_started", &"", {
		"turn_index": state.turn_index,
		"timeline_index": state.timeline_index,
		"time_state": state.time_state,
		"enemy_intents": state.locked_enemy_intents,
		"ghost_actions": _build_ghost_preview(state),
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
	if target.active and _is_push_enabled(state):
		var push_direction: Vector2i = action.result.get("push_direction", action.target - action.origin)
		_apply_knockback(state, target, push_direction, ghost_id, events)
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


func _build_known_time_preview(state: BattleState) -> Array:
	var previews: Array = VariantCodec.deep_copy(state.enemy_history.get(state.turn_index, []))
	for preview_data in previews:
		var preview: Dictionary = preview_data
		var enemy := state.get_unit(StringName(preview.get("enemy_id", &"")))
		preview["reactive"] = enemy != null and _is_enemy_awake(enemy, state.turn_index)
	return previews


func _resolve_known_time_intents(state: BattleState) -> Array:
	var history: Array = state.enemy_history.get(state.turn_index, [])
	var intents: Array = []
	for unit_id in state.unit_order:
		var enemy := state.get_unit(unit_id)
		if enemy == null or not enemy.active or enemy.team != &"enemy":
			continue
		if _is_enemy_awake(enemy, state.turn_index):
			var reactive := _compute_reactive_intent(state, enemy)
			reactive["reactive"] = true
			intents.append(reactive)
			continue
		var historical := _find_intent_for_enemy(history, enemy.unit_id)
		if not historical.is_empty():
			historical["reactive"] = false
			intents.append(historical)
	return intents


func _find_intent_for_enemy(intents: Array, enemy_id: StringName) -> Dictionary:
	for intent_data in intents:
		var intent: Dictionary = intent_data
		if StringName(intent.get("enemy_id", &"")) == enemy_id:
			return VariantCodec.deep_copy(intent)
	return {}


func _has_reactive_intent(intents: Array) -> bool:
	for intent_data in intents:
		if bool((intent_data as Dictionary).get("reactive", false)):
			return true
	return false


func _is_enemy_awake(enemy: UnitState, turn_index: int) -> bool:
	var awake_from := int(enemy.statuses.get("awake_from_turn", 0))
	return awake_from > 0 and turn_index >= awake_from


func _compute_reactive_intent(state: BattleState, enemy: UnitState) -> Dictionary:
	var player := state.get_unit(state.player_id)
	var current := enemy.position
	var last_direction := Vector2i.ZERO
	var path: Array[Vector2i] = [current]

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
			path.append(current)
			last_direction = best_direction
			if _manhattan(current, player.position) <= 1:
				break

	var did_move := current != enemy.position
	var adjacent := _manhattan(current, player.position) <= 1
	var intent := {
		"enemy_id": enemy.unit_id,
		"from": enemy.position,
		"to": current,
		"path": path,
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
		var fixed_intent := fixed_history and not bool(intent.get("reactive", false))
		var origin: Vector2i = intent.get("from", enemy.position)
		if fixed_intent and enemy.position != origin:
			events.append(BattleEvent.create(&"action_invalidated", enemy.unit_id, {
				"action_type": intent.get("intent_type", &"wait"),
				"reason": &"history_origin_changed",
			}))
			continue

		var intent_type: StringName = intent.get("intent_type", &"wait")
		if intent_type == &"move" or intent_type == &"move_attack":
			var destination: Vector2i = intent.get("to", enemy.position)
			var can_move := _is_enemy_step_valid(state, enemy.unit_id, destination) if fixed_intent else _is_enemy_destination_open(state, enemy.unit_id, destination)
			if can_move:
				var move_origin := enemy.position
				var player := state.get_unit(state.player_id)
				if fixed_intent and player != null and player.active and player.position == destination:
					_apply_history_collision(state, player, intent, enemy.unit_id, events)
				enemy.position = destination
				events.append(BattleEvent.create(&"unit_moved", enemy.unit_id, {
					"from": move_origin,
					"to": destination,
					"path": intent.get("path", [move_origin, destination]),
					"is_ghost": false,
				}))
				if player != null and not player.active:
					_handle_player_death(state, &"history_collision", events)
					return
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


func _apply_knockback(state: BattleState, target: UnitState, direction: Vector2i, source_id: StringName, events: Array[BattleEvent]) -> Dictionary:
	var result: Dictionary = DisplacementQueryScript.evaluate_knockback(state, target, direction)
	var origin: Vector2i = result.from
	var destination: Vector2i = result.to
	if result.outcome == &"time_hole":
		target.position = destination
		events.append(BattleEvent.create(&"unit_pushed", target.unit_id, {
			"from": origin,
			"to": destination,
			"path": [origin, destination],
			"source_id": source_id,
			"outcome": &"time_hole",
		}))
		_kill_unit(target, source_id, &"time_hole", events)
		return result

	if result.outcome == &"collision":
		var collision_target := state.get_unit(result.get("collision_target_id", &""))
		if collision_target == null or not collision_target.active:
			result.outcome = &"blocked"
			result.blocked_reason = &"collision_target_missing"
			events.append(BattleEvent.create(&"push_blocked", target.unit_id, {
				"cell": origin,
				"attempted_cell": destination,
				"source_id": source_id,
				"reason": result.blocked_reason,
			}))
			return result
		events.append(BattleEvent.create(&"units_collided", target.unit_id, {
			"first_unit_id": target.unit_id,
			"second_unit_id": collision_target.unit_id,
			"first_cell": origin,
			"second_cell": destination,
			"source_id": source_id,
			"damage": COLLISION_DAMAGE,
		}))
		_apply_damage(state, target, COLLISION_DAMAGE, source_id, events, &"collision")
		_apply_damage(state, collision_target, COLLISION_DAMAGE, source_id, events, &"collision")
		return result

	if result.outcome == &"blocked":
		events.append(BattleEvent.create(&"push_blocked", target.unit_id, {
			"cell": origin,
			"attempted_cell": destination,
			"source_id": source_id,
			"reason": result.blocked_reason,
		}))
		return result

	target.position = destination
	events.append(BattleEvent.create(&"unit_pushed", target.unit_id, {
		"from": origin,
		"to": destination,
		"path": [origin, destination],
		"source_id": source_id,
		"outcome": &"moved",
	}))
	if target.team == &"enemy":
		_mark_enemy_disturbed(state, target, events)
	return result


func _mark_enemy_disturbed(state: BattleState, enemy: UnitState, events: Array[BattleEvent]) -> void:
	if state.timeline_index <= 1 or not state.enemy_history.has(state.turn_index):
		return
	var wake_turn := state.turn_index + 1
	var existing := int(enemy.statuses.get("awake_from_turn", 0))
	if existing > 0:
		wake_turn = mini(wake_turn, existing)
	enemy.statuses["awake_from_turn"] = wake_turn
	enemy.statuses["disturbed"] = true
	events.append(BattleEvent.create(&"enemy_disturbed", enemy.unit_id, {
		"wake_turn": wake_turn,
	}))


func _apply_history_collision(state: BattleState, player: UnitState, intent: Dictionary, enemy_id: StringName, events: Array[BattleEvent]) -> void:
	var direction: Vector2i = intent.get("last_direction", Vector2i.ZERO)
	if direction == Vector2i.ZERO:
		direction = _cardinal_direction(intent.get("from", Vector2i.ZERO), intent.get("to", Vector2i.ZERO))
	var origin := player.position
	var destination := origin + direction
	if state.holes.has(destination):
		player.position = destination
		events.append(BattleEvent.create(&"unit_pushed", player.unit_id, {
			"from": origin,
			"to": destination,
			"path": [origin, destination],
			"source_id": enemy_id,
			"outcome": &"time_hole",
			"collision": true,
		}))
		_kill_unit(player, enemy_id, &"time_hole", events)
		return

	if not GridQuery.is_in_bounds(state, destination) or state.walls.has(destination) or _find_active_unit_at(state, destination) != null:
		_kill_unit(player, enemy_id, &"time_compression", events)
		return

	player.position = destination
	events.append(BattleEvent.create(&"unit_pushed", player.unit_id, {
		"from": origin,
		"to": destination,
		"path": [origin, destination],
		"source_id": enemy_id,
		"outcome": &"moved",
		"collision": true,
	}))


func _kill_unit(target: UnitState, source_id: StringName, cause: StringName, events: Array[BattleEvent]) -> void:
	target.hp = 0
	target.active = false
	events.append(BattleEvent.create(&"unit_died", target.unit_id, {
		"source_id": source_id,
		"cell": target.position,
		"cause": cause,
	}))


func _cardinal_direction(origin: Vector2i, target: Vector2i) -> Vector2i:
	var delta := target - origin
	if absi(delta.x) >= absi(delta.y) and delta.x != 0:
		return Vector2i(signi(delta.x), 0)
	if delta.y != 0:
		return Vector2i(0, signi(delta.y))
	return Vector2i.ZERO


func _is_push_enabled(state: BattleState) -> bool:
	return bool(state.rules.get("push_enabled", false))


func _apply_damage(state: BattleState, target: UnitState, damage: int, source_id: StringName, events: Array[BattleEvent], cause: StringName = &"attack") -> void:
	target.hp = maxi(0, target.hp - damage)
	events.append(BattleEvent.create(&"damage_applied", source_id, {
		"target_id": target.unit_id,
		"damage": damage,
		"remaining_hp": target.hp,
		"cause": cause,
	}))
	if target.hp <= 0:
		target.active = false
		events.append(BattleEvent.create(&"unit_died", target.unit_id, {
			"source_id": source_id,
			"cell": target.position,
			"cause": cause,
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


func _build_unit_view_data(state: BattleState) -> Dictionary:
	var view_data: Dictionary = {}
	for unit_id in state.unit_order:
		var unit := state.get_unit(unit_id)
		if unit != null:
			view_data[unit.unit_id] = {
				"position": unit.position,
				"hp": unit.hp,
				"max_hp": unit.max_hp,
				"team": unit.team,
				"active": unit.active,
				"disturbed": bool(unit.statuses.get("disturbed", false)),
			}
	return view_data


func _build_ghost_preview(state: BattleState) -> Array:
	var preview: Array = []
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
			preview.append({
				"ghost_id": ghost_id,
				"source_timeline": timeline_number,
				"action_type": action.action_type,
				"origin": action.origin,
				"target": action.target,
				"path": action.result.get("path", [action.origin, action.target]),
			})
	return preview


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
