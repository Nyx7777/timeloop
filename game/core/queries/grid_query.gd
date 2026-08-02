class_name GridQuery
extends RefCounted

const DIRECTIONS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]


static func is_in_bounds(state: BattleState, cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < state.board_size.x and cell.y < state.board_size.y


static func is_occupied(state: BattleState, cell: Vector2i, ignored_unit: StringName = &"") -> bool:
	for unit_id in state.units.keys():
		var unit := state.units[unit_id] as UnitState
		if unit.active and unit.unit_id != ignored_unit and unit.position == cell:
			return true
	return false


static func is_walkable(state: BattleState, cell: Vector2i, ignored_unit: StringName = &"") -> bool:
	return is_in_bounds(state, cell) \
		and not state.walls.has(cell) \
		and not state.holes.has(cell) \
		and not is_occupied(state, cell, ignored_unit)


static func find_path(state: BattleState, start: Vector2i, target: Vector2i, max_steps: int, moving_unit: StringName) -> Array[Vector2i]:
	var empty_path: Array[Vector2i] = []
	if start == target or max_steps <= 0 or not is_walkable(state, target, moving_unit):
		return empty_path

	var frontier: Array[Vector2i] = [start]
	var distance := {start: 0}
	var parent: Dictionary = {}
	var cursor := 0

	while cursor < frontier.size():
		var current := frontier[cursor]
		cursor += 1
		if distance[current] >= max_steps:
			continue
		for direction in DIRECTIONS:
			var next: Vector2i = current + direction
			if distance.has(next) or not is_walkable(state, next, moving_unit):
				continue
			distance[next] = distance[current] + 1
			parent[next] = current
			frontier.append(next)
			if next == target:
				return _reconstruct_path(parent, start, target)

	return empty_path


static func _reconstruct_path(parent: Dictionary, start: Vector2i, target: Vector2i) -> Array[Vector2i]:
	var reversed_path: Array[Vector2i] = [target]
	var current := target
	while current != start:
		current = parent[current]
		reversed_path.append(current)
	reversed_path.reverse()
	return reversed_path
