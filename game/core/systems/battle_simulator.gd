class_name BattleSimulator
extends RefCounted


func apply_command(state: BattleState, command: BattleCommand) -> CommandResult:
	match command.command_type:
		BattleCommand.MOVE:
			return _apply_move(state, command)
		_:
			return CommandResult.reject(&"unsupported_command")


func _apply_move(state: BattleState, command: BattleCommand) -> CommandResult:
	if state.phase != BattlePhase.PLAYER_INPUT:
		return CommandResult.reject(&"not_player_input_phase")
	if command.actor_id != state.player_id:
		return CommandResult.reject(&"actor_not_controlled")

	var unit := state.get_unit(command.actor_id)
	if unit == null or not unit.active:
		return CommandResult.reject(&"actor_unavailable")
	if unit.has_moved:
		return CommandResult.reject(&"move_already_used")

	var path := GridQuery.find_path(state, unit.position, command.target_cell, unit.move_range, unit.unit_id)
	if path.is_empty():
		return CommandResult.reject(&"destination_unreachable")

	var origin := unit.position
	unit.position = command.target_cell
	unit.has_moved = true

	var action := RecordedAction.new()
	action.action_id = StringName("t%d_turn%d_cmd%d" % [state.timeline_index, state.turn_index, state.command_index + 1])
	action.actor_id = unit.unit_id
	action.action_type = BattleCommand.MOVE
	action.turn_index = state.turn_index
	action.phase = state.phase
	action.origin = origin
	action.target = command.target_cell
	action.result = {"path": path}
	state.current_recording.append(action)

	var event := BattleEvent.create(&"unit_moved", unit.unit_id, {
		"from": origin,
		"to": command.target_cell,
		"path": path,
	})
	var events: Array[BattleEvent] = [event]
	var actions: Array[RecordedAction] = [action]
	return CommandResult.accept(events, actions)
