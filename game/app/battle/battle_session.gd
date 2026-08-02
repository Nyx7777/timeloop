class_name BattleSession
extends RefCounted

var state: BattleState
var simulator: BattleSimulator
var checkpoint_limit := 64

var _undo_stack: Array[BattleCheckpoint] = []
var _command_in_progress := false


func _init(initial_state: BattleState = null, battle_simulator: BattleSimulator = null) -> void:
	state = initial_state
	simulator = battle_simulator if battle_simulator != null else BattleSimulator.new()


func submit(command: BattleCommand) -> CommandResult:
	if state == null:
		return CommandResult.reject(&"session_not_initialized")
	if _command_in_progress:
		return CommandResult.reject(&"command_in_progress")

	_command_in_progress = true
	var checkpoint := BattleCheckpoint.capture(state, command)
	var candidate := state.duplicate_state()
	var result := simulator.apply_command(candidate, command)

	if result.accepted:
		candidate.command_index += 1
		candidate.revision += 1
		for event in result.events:
			candidate.event_sequence += 1
			event.sequence = candidate.event_sequence
		state = candidate
		if result.commit_undo_barrier:
			_undo_stack.clear()
		else:
			_undo_stack.append(checkpoint)
			_trim_checkpoints()

	_command_in_progress = false
	return result


func can_undo() -> bool:
	return not _command_in_progress and not _undo_stack.is_empty()


func undo_last_command() -> CommandResult:
	if _command_in_progress:
		return CommandResult.reject(&"command_in_progress")
	if _undo_stack.is_empty():
		return CommandResult.reject(&"nothing_to_undo")

	var checkpoint: BattleCheckpoint = _undo_stack.pop_back()
	state = checkpoint.restore_state()
	state.revision += 1
	state.event_sequence += 1
	var event := BattleEvent.create(&"state_restored", &"", {
		"reason": &"undo",
		"undone_command": checkpoint.restore_command().to_dict(),
		"state": state.to_dict(),
	})
	event.sequence = state.event_sequence
	var events: Array[BattleEvent] = [event]
	return CommandResult.accept(events)


func commit_undo_barrier() -> void:
	_undo_stack.clear()


func get_undo_count() -> int:
	return _undo_stack.size()


func _trim_checkpoints() -> void:
	while _undo_stack.size() > checkpoint_limit:
		_undo_stack.pop_front()
