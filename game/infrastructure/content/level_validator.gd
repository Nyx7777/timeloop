class_name LevelValidator
extends RefCounted


static func validate(level: LevelDefinition) -> PackedStringArray:
	var errors := PackedStringArray()
	if level == null:
		errors.append("level is null")
		return errors
	if level.level_id.is_empty():
		errors.append("level_id is required")
	if level.board_size.x <= 0 or level.board_size.y <= 0:
		errors.append("board_size must be positive")
	if level.lives <= 0:
		errors.append("lives must be positive")

	var terrain_cells: Dictionary = {}
	for wall in level.walls:
		_validate_cell(level, wall, "wall", errors)
		terrain_cells[wall] = "wall"
	for hole in level.holes:
		_validate_cell(level, hole, "hole", errors)
		if terrain_cells.has(hole):
			errors.append("hole overlaps terrain at %s" % hole)
		terrain_cells[hole] = "hole"

	var unit_ids: Dictionary = {}
	var spawn_cells: Dictionary = {}
	var player_count := 0
	for spawn_resource in level.spawns:
		var spawn := spawn_resource as UnitSpawnDefinition
		if spawn == null:
			errors.append("spawn has invalid resource type")
			continue
		if spawn.unit_id.is_empty():
			errors.append("spawn unit_id is required")
		elif unit_ids.has(spawn.unit_id):
			errors.append("duplicate unit_id: %s" % spawn.unit_id)
		unit_ids[spawn.unit_id] = true
		_validate_cell(level, spawn.position, "spawn", errors)
		if terrain_cells.has(spawn.position):
			errors.append("spawn overlaps terrain at %s" % spawn.position)
		if spawn_cells.has(spawn.position):
			errors.append("multiple spawns at %s" % spawn.position)
		spawn_cells[spawn.position] = true
		if spawn.team == &"player":
			player_count += 1
	if player_count != 1:
		errors.append("level must contain exactly one player spawn")
	return errors


static func _validate_cell(level: LevelDefinition, cell: Vector2i, label: String, errors: PackedStringArray) -> void:
	if cell.x < 0 or cell.y < 0 or cell.x >= level.board_size.x or cell.y >= level.board_size.y:
		errors.append("%s out of bounds at %s" % [label, cell])
