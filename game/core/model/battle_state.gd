class_name BattleState
extends RefCounted

const SCHEMA_VERSION := 1

var battle_id: StringName
var level_id: StringName
var board_size := Vector2i(8, 8)
var walls: Array[Vector2i] = []
var holes: Array[Vector2i] = []
var rules: Dictionary = {}
var player_start := Vector2i.ZERO
var timeline_index := 1
var lives_left := 1
var turn_index := 1
var phase: StringName = BattlePhase.PLAYER_INPUT
var player_id: StringName
var units: Dictionary = {}
var unit_order: Array[StringName] = []
var initial_units: Dictionary = {}
var current_recording: Array[RecordedAction] = []
var timeline_recordings: Array = []
var ghost_positions: Dictionary = {}
var enemy_history: Dictionary = {}
var current_enemy_history: Dictionary = {}
var locked_enemy_intents: Array = []
var time_state: StringName = &"unknown"
var scene_objects: Dictionary = {}
var pending_loot: Dictionary = {}
var battle_outcome: StringName
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
		"rules": VariantCodec.encode(rules),
		"player_start": VariantCodec.encode(player_start),
		"timeline_index": timeline_index,
		"lives_left": lives_left,
		"turn_index": turn_index,
		"phase": String(phase),
		"player_id": String(player_id),
		"units": unit_data,
		"unit_order": VariantCodec.encode(unit_order),
		"initial_units": VariantCodec.encode(initial_units),
		"current_recording": recording_data,
		"timeline_recordings": VariantCodec.encode(timeline_recordings),
		"ghost_positions": VariantCodec.encode(ghost_positions),
		"enemy_history": VariantCodec.encode(enemy_history),
		"current_enemy_history": VariantCodec.encode(current_enemy_history),
		"locked_enemy_intents": VariantCodec.encode(locked_enemy_intents),
		"time_state": String(time_state),
		"scene_objects": VariantCodec.encode(scene_objects),
		"pending_loot": VariantCodec.encode(pending_loot),
		"battle_outcome": String(battle_outcome),
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
	state.rules = VariantCodec.decode(data.get("rules", VariantCodec.encode({})))
	state.player_start = VariantCodec.decode(data.get("player_start", VariantCodec.encode(Vector2i.ZERO)))
	state.timeline_index = int(data.get("timeline_index", 1))
	state.lives_left = int(data.get("lives_left", 1))
	state.turn_index = int(data.get("turn_index", 1))
	state.phase = StringName(data.get("phase", String(BattlePhase.PLAYER_INPUT)))
	state.player_id = StringName(data.get("player_id", ""))
	for unit_id in data.get("units", {}).keys():
		var unit := UnitState.from_dict(data["units"][unit_id])
		state.units[unit.unit_id] = unit
	state.unit_order.assign(VariantCodec.decode(data.get("unit_order", VariantCodec.encode([]))))
	state.initial_units = VariantCodec.decode(data.get("initial_units", VariantCodec.encode({})))
	for action_data in data.get("current_recording", []):
		state.current_recording.append(RecordedAction.from_dict(action_data))
	state.timeline_recordings = VariantCodec.decode(data.get("timeline_recordings", VariantCodec.encode([])))
	state.ghost_positions = VariantCodec.decode(data.get("ghost_positions", VariantCodec.encode({})))
	state.enemy_history = VariantCodec.decode(data.get("enemy_history", VariantCodec.encode({})))
	state.current_enemy_history = VariantCodec.decode(data.get("current_enemy_history", VariantCodec.encode({})))
	state.locked_enemy_intents = VariantCodec.decode(data.get("locked_enemy_intents", VariantCodec.encode([])))
	state.time_state = StringName(data.get("time_state", "unknown"))
	state.scene_objects = VariantCodec.decode(data.get("scene_objects", VariantCodec.encode({})))
	state.pending_loot = VariantCodec.decode(data.get("pending_loot", VariantCodec.encode({})))
	state.battle_outcome = StringName(data.get("battle_outcome", ""))
	state.rng_seed = int(data.get("rng_seed", 0))
	state.rng_state = int(data.get("rng_state", 0))
	state.command_index = int(data.get("command_index", 0))
	state.event_sequence = int(data.get("event_sequence", 0))
	state.revision = int(data.get("revision", 0))
	return state


func duplicate_state() -> BattleState:
	return BattleState.from_dict(to_dict())
