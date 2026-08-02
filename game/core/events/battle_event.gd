class_name BattleEvent
extends RefCounted

const SCHEMA_VERSION := 1

var sequence: int
var event_type: StringName
var actor_id: StringName
var payload: Dictionary = {}


static func create(type: StringName, actor: StringName = &"", data: Dictionary = {}) -> BattleEvent:
	var event := BattleEvent.new()
	event.event_type = type
	event.actor_id = actor
	event.payload = VariantCodec.deep_copy(data)
	return event


func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"sequence": sequence,
		"event_type": String(event_type),
		"actor_id": String(actor_id),
		"payload": VariantCodec.encode(payload),
	}


static func from_dict(data: Dictionary) -> BattleEvent:
	var event := BattleEvent.new()
	event.sequence = int(data.get("sequence", 0))
	event.event_type = StringName(data.get("event_type", ""))
	event.actor_id = StringName(data.get("actor_id", ""))
	event.payload = VariantCodec.decode(data.get("payload", VariantCodec.encode({})))
	return event
