class_name BattleCheckpoint
extends RefCounted

const SCHEMA_VERSION := 1

var state_data: Dictionary
var command_data: Dictionary
var reason: StringName


static func capture(state: BattleState, command: BattleCommand, checkpoint_reason: StringName = &"before_command") -> BattleCheckpoint:
	var checkpoint := BattleCheckpoint.new()
	checkpoint.state_data = state.to_dict()
	checkpoint.command_data = command.to_dict()
	checkpoint.reason = checkpoint_reason
	return checkpoint


func restore_state() -> BattleState:
	return BattleState.from_dict(state_data)


func restore_command() -> BattleCommand:
	return BattleCommand.from_dict(command_data)


func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"state": state_data.duplicate(true),
		"command": command_data.duplicate(true),
		"reason": String(reason),
	}


static func from_dict(data: Dictionary) -> BattleCheckpoint:
	var checkpoint := BattleCheckpoint.new()
	checkpoint.state_data = data.get("state", {}).duplicate(true)
	checkpoint.command_data = data.get("command", {}).duplicate(true)
	checkpoint.reason = StringName(data.get("reason", ""))
	return checkpoint
