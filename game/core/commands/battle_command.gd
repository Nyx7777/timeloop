class_name BattleCommand
extends RefCounted

const SCHEMA_VERSION := 1
const MOVE: StringName = &"move"
const USE_ABILITY: StringName = &"use_ability"
const END_TURN: StringName = &"end_turn"
const CRYSTALLIZE: StringName = &"crystallize"

var command_type: StringName
var actor_id: StringName
var target_cell := Vector2i(-1, -1)
var ability_id: StringName
var payload: Dictionary = {}


static func move(actor: StringName, destination: Vector2i) -> BattleCommand:
	var command := BattleCommand.new()
	command.command_type = MOVE
	command.actor_id = actor
	command.target_cell = destination
	return command


static func use_ability(actor: StringName, ability: StringName, target: Vector2i) -> BattleCommand:
	var command := BattleCommand.new()
	command.command_type = USE_ABILITY
	command.actor_id = actor
	command.ability_id = ability
	command.target_cell = target
	return command


static func end_turn(actor: StringName) -> BattleCommand:
	var command := BattleCommand.new()
	command.command_type = END_TURN
	command.actor_id = actor
	return command


func to_dict() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"command_type": String(command_type),
		"actor_id": String(actor_id),
		"target_cell": VariantCodec.encode(target_cell),
		"ability_id": String(ability_id),
		"payload": VariantCodec.encode(payload),
	}


static func from_dict(data: Dictionary) -> BattleCommand:
	var command := BattleCommand.new()
	command.command_type = StringName(data.get("command_type", ""))
	command.actor_id = StringName(data.get("actor_id", ""))
	command.target_cell = VariantCodec.decode(data.get("target_cell", {}))
	command.ability_id = StringName(data.get("ability_id", ""))
	command.payload = VariantCodec.decode(data.get("payload", VariantCodec.encode({})))
	return command
