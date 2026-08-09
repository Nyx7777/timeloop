class_name EnemyIntentPresentation
extends RefCounted


static func build(state: BattleState, focused_enemy_id: StringName = &"") -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	var labels := enemy_labels(state)
	for unit_id in state.unit_order:
		var unit := state.get_unit(unit_id)
		if unit == null or not unit.active or unit.team != &"enemy":
			continue
		var status := temporal_status(state, unit)
		var intent := _find_locked_intent(state.locked_enemy_intents, unit.unit_id)
		var focused := focused_enemy_id == &"" or focused_enemy_id == unit.unit_id
		var snapshot: Dictionary = {
			"enemy_id": unit.unit_id,
			"label": String(labels.get(unit.unit_id, "?")),
			"position": unit.position,
			"temporal_status": status,
			"wake_turn": int(unit.statuses.get("awake_from_turn", 0)),
			"focused": focused,
			"opacity": 1.0 if focused else 0.20,
			"show_question": status == &"awake",
			"show_locked_intent": (status == &"fixed" or status == &"pending_awake") and not intent.is_empty(),
		}
		if bool(snapshot.show_locked_intent):
			var origin: Vector2i = intent.get("from", unit.position)
			var destination: Vector2i = intent.get("to", origin)
			var intent_type: StringName = intent.get("intent_type", &"wait")
			snapshot.merge({
				"intent_type": intent_type,
				"path": _normalized_path(intent.get("path", []), origin, destination),
				"origin": origin,
				"destination": destination,
				"attack_origin": destination,
				"attack_target": intent.get("target", Vector2i(-1, -1)),
				"damage": int(intent.get("damage", unit.attack_damage)),
				"waiting": intent_type == &"wait",
			})
		snapshots.append(snapshot)
	return snapshots


static func enemy_labels(state: BattleState) -> Dictionary:
	var labels := {}
	var enemy_index := 0
	# Include inactive enemies so surviving enemies never change identity mid-battle.
	for unit_id in state.unit_order:
		var unit := state.get_unit(unit_id)
		if unit == null or unit.team != &"enemy":
			continue
		enemy_index += 1
		labels[unit.unit_id] = "E%d" % enemy_index
	return labels


static func temporal_status(state: BattleState, unit: UnitState) -> StringName:
	var awake_from := int(unit.statuses.get("awake_from_turn", 0))
	if awake_from > 0 and state.turn_index >= awake_from:
		return &"awake"
	if awake_from > state.turn_index and bool(unit.statuses.get("disturbed", false)):
		return &"pending_awake"
	var intent := _find_locked_intent(state.locked_enemy_intents, unit.unit_id)
	if not intent.is_empty():
		return &"awake" if bool(intent.get("reactive", false)) else &"fixed"
	return &"unknown"


static func _find_locked_intent(intents: Array, enemy_id: StringName) -> Dictionary:
	for intent_data in intents:
		var intent: Dictionary = intent_data
		if StringName(intent.get("enemy_id", &"")) == enemy_id:
			return intent
	return {}


static func _normalized_path(raw_path: Variant, origin: Vector2i, destination: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if raw_path is Array:
		for cell_variant in raw_path:
			if cell_variant is Vector2i:
				path.append(cell_variant)
	if path.is_empty() or path[0] != origin:
		path.push_front(origin)
	if path[path.size() - 1] != destination:
		path.append(destination)
	return path
