class_name BattleStateFactory
extends RefCounted


static func create_from_level(level: LevelDefinition, seed: int = 1) -> BattleState:
	var validation_errors := LevelValidator.validate(level)
	if not validation_errors.is_empty():
		push_error("Invalid level %s: %s" % [level.level_id, "; ".join(validation_errors)])
		return null

	var state := BattleState.new()
	state.battle_id = StringName("%s_%d" % [level.level_id, seed])
	state.level_id = level.level_id
	state.board_size = level.board_size
	state.walls.assign(level.walls)
	state.holes.assign(level.holes)
	state.lives_left = level.lives
	state.rng_seed = seed
	var random := RandomNumberGenerator.new()
	random.seed = seed
	state.rng_state = random.state

	for spawn_resource in level.spawns:
		var spawn := spawn_resource as UnitSpawnDefinition
		var unit := UnitState.new()
		unit.unit_id = spawn.unit_id
		unit.definition_id = spawn.definition_id
		unit.team = spawn.team
		unit.position = spawn.position
		unit.max_hp = spawn.max_hp
		unit.hp = spawn.max_hp
		unit.move_range = spawn.move_range
		unit.attack_damage = spawn.attack_damage
		state.units[unit.unit_id] = unit
		if unit.team == &"player":
			state.player_id = unit.unit_id
	return state
