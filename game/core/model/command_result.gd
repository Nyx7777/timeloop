class_name CommandResult
extends RefCounted

var accepted: bool
var reason: StringName
var events: Array[BattleEvent] = []
var recorded_actions: Array[RecordedAction] = []
var commit_undo_barrier := false


static func reject(rejection_reason: StringName) -> CommandResult:
	var result := CommandResult.new()
	result.accepted = false
	result.reason = rejection_reason
	return result


static func accept(result_events: Array[BattleEvent] = [], actions: Array[RecordedAction] = [], commit_barrier := false) -> CommandResult:
	var result := CommandResult.new()
	result.accepted = true
	result.reason = &"ok"
	result.events = result_events
	result.recorded_actions = actions
	result.commit_undo_barrier = commit_barrier
	return result
