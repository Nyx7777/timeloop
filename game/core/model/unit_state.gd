class_name UnitState
extends RefCounted

var unit_id: StringName
var definition_id: StringName
var team: StringName
var position: Vector2i
var hp: int
var max_hp: int
var move_range: int
var attack_damage: int
var active := true
var has_moved := false
var has_acted := false
var statuses: Dictionary = {}


func to_dict() -> Dictionary:
	return {
		"unit_id": String(unit_id),
		"definition_id": String(definition_id),
		"team": String(team),
		"position": VariantCodec.encode(position),
		"hp": hp,
		"max_hp": max_hp,
		"move_range": move_range,
		"attack_damage": attack_damage,
		"active": active,
		"has_moved": has_moved,
		"has_acted": has_acted,
		"statuses": VariantCodec.encode(statuses),
	}


static func from_dict(data: Dictionary) -> UnitState:
	var unit := UnitState.new()
	unit.unit_id = StringName(data.get("unit_id", ""))
	unit.definition_id = StringName(data.get("definition_id", ""))
	unit.team = StringName(data.get("team", ""))
	unit.position = VariantCodec.decode(data.get("position", {}))
	unit.hp = int(data.get("hp", 0))
	unit.max_hp = int(data.get("max_hp", unit.hp))
	unit.move_range = int(data.get("move_range", 0))
	unit.attack_damage = int(data.get("attack_damage", 0))
	unit.active = bool(data.get("active", true))
	unit.has_moved = bool(data.get("has_moved", false))
	unit.has_acted = bool(data.get("has_acted", false))
	unit.statuses = VariantCodec.decode(data.get("statuses", VariantCodec.encode({})))
	return unit
