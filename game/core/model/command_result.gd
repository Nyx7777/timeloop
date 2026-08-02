class_name CommandResult
extends RefCounted

var accepted: bool
var reason: StringName
var events: Array[BattleEvent] = []
var recorded_actions: Array[RecordedAction] = []


static func reject(rejection_reason: StringName) -> CommandResult:
	var result := CommandResult.new()
	result.accepted = false
	result.reason = rejection_reason
	return result


static func accept(result_events: Array[BattleEvent] = [], actions: Array[RecordedAction] = []) -> CommandResult:
	var result := CommandResult.new()
	result.accepted = true
	result.reason = &"ok"
	result.events = result_events
	result.recorded_actions = actions
	return result
