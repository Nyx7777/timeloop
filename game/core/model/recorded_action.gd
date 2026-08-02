class_name RecordedAction
extends RefCounted

const SCHEMA_VERSION := 1

var action_id: StringName
var actor_id: StringName
var action_type: StringName
var turn_index := 1
var phase: StringName = BattlePhase.PLAYER_INPUT
var actor_order: int
var step_index: int
var reaction_index: int
var origin := Vector2i(-1, -1)
var target := Vector2i(-1, -1)
var result: Dictionary = {}


func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"action_id": String(action_id),
		"actor_id": String(actor_id),
		"action_type": String(action_type),
		"turn_index": turn_index,
		"phase": String(phase),
		"actor_order": actor_order,
		"step_index": step_index,
		"reaction_index": reaction_index,
		"origin": VariantCodec.encode(origin),
		"target": VariantCodec.encode(target),
		"result": VariantCodec.encode(result),
	}


static func from_dict(data: Dictionary) -> RecordedAction:
	var action := RecordedAction.new()
	action.action_id = StringName(data.get("action_id", ""))
	action.actor_id = StringName(data.get("actor_id", ""))
	action.action_type = StringName(data.get("action_type", ""))
	action.turn_index = int(data.get("turn_index", 1))
	action.phase = StringName(data.get("phase", String(BattlePhase.PLAYER_INPUT)))
	action.actor_order = int(data.get("actor_order", 0))
	action.step_index = int(data.get("step_index", 0))
	action.reaction_index = int(data.get("reaction_index", 0))
	action.origin = VariantCodec.decode(data.get("origin", {}))
	action.target = VariantCodec.decode(data.get("target", {}))
	action.result = VariantCodec.decode(data.get("result", VariantCodec.encode({})))
	return action
