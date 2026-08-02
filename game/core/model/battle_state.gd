class_name BattleState
extends RefCounted

const SCHEMA_VERSION := 1

var battle_id: StringName
var level_id: StringName
var board_size := Vector2i(8, 8)
var walls: Array[Vector2i] = []
var holes: Array[Vector2i] = []
var timeline_index := 1
var lives_left := 1
var turn_index := 1
var phase: StringName = BattlePhase.PLAYER_INPUT
var player_id: StringName
var units: Dictionary = {}
var current_recording: Array[RecordedAction] = []
var timeline_recordings: Array = []
var enemy_history: Dictionary = {}
var scene_objects: Dictionary = {}
var pending_loot: Dictionary = {}
var rng_seed: int
var rng_state: int
var command_index: int
var event_sequence: int
var revision: int


func get_unit(unit_id: StringName) -> UnitState:
	return units.get(unit_id) as UnitState


func to_dict() -> Dictionary:
	var unit_data: Dictionary = {}
	for unit_id in units.keys():
		unit_data[String(unit_id)] = (units[unit_id] as UnitState).to_dict()

	var recording_data: Array = []
	for action in current_recording:
		recording_data.append(action.to_dict())

	return {
		"schema_version": SCHEMA_VERSION,
		"battle_id": String(battle_id),
		"level_id": String(level_id),
		"board_size": VariantCodec.encode(board_size),
		"walls": VariantCodec.encode(walls),
		"holes": VariantCodec.encode(holes),
		"timeline_index": timeline_index,
		"lives_left": lives_left,
		"turn_index": turn_index,
		"phase": String(phase),
		"player_id": String(player_id),
		"units": unit_data,
		"current_recording": recording_data,
		"timeline_recordings": VariantCodec.encode(timeline_recordings),
		"enemy_history": VariantCodec.encode(enemy_history),
		"scene_objects": VariantCodec.encode(scene_objects),
		"pending_loot": VariantCodec.encode(pending_loot),
		"rng_seed": rng_seed,
		"rng_state": rng_state,
		"command_index": command_index,
		"event_sequence": event_sequence,
		"revision": revision,
	}


static func from_dict(data: Dictionary) -> BattleState:
	var state := BattleState.new()
	state.battle_id = StringName(data.get("battle_id", ""))
	state.level_id = StringName(data.get("level_id", ""))
	state.board_size = VariantCodec.decode(data.get("board_size", {}))
	state.walls.assign(VariantCodec.decode(data.get("walls", VariantCodec.encode([]))))
	state.holes.assign(VariantCodec.decode(data.get("holes", VariantCodec.encode([]))))
	state.timeline_index = int(data.get("timeline_index", 1))
	state.lives_left = int(data.get("lives_left", 1))
	state.turn_index = int(data.get("turn_index", 1))
	state.phase = StringName(data.get("phase", String(BattlePhase.PLAYER_INPUT)))
	state.player_id = StringName(data.get("player_id", ""))
	for unit_id in data.get("units", {}).keys():
		var unit := UnitState.from_dict(data["units"][unit_id])
		state.units[unit.unit_id] = unit
	for action_data in data.get("current_recording", []):
		state.current_recording.append(RecordedAction.from_dict(action_data))
	state.timeline_recordings = VariantCodec.decode(data.get("timeline_recordings", VariantCodec.encode([])))
	state.enemy_history = VariantCodec.decode(data.get("enemy_history", VariantCodec.encode({})))
	state.scene_objects = VariantCodec.decode(data.get("scene_objects", VariantCodec.encode({})))
	state.pending_loot = VariantCodec.decode(data.get("pending_loot", VariantCodec.encode({})))
	state.rng_seed = int(data.get("rng_seed", 0))
	state.rng_state = int(data.get("rng_state", 0))
	state.command_index = int(data.get("command_index", 0))
	state.event_sequence = int(data.get("event_sequence", 0))
	state.revision = int(data.get("revision", 0))
	return state


func duplicate_state() -> BattleState:
	return BattleState.from_dict(to_dict())
