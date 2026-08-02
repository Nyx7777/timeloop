class_name DisplacementQuery
extends RefCounted


static func evaluate_knockback(state: BattleState, target: UnitState, direction: Vector2i) -> Dictionary:
	var destination := target.position + direction
	var result := {
		"direction": direction,
		"from": target.position,
		"to": destination,
		"outcome": &"moved",
		"blocked_reason": &"",
	}
	if state.holes.has(destination):
		result.outcome = &"time_hole"
		return result
	if not GridQuery.is_in_bounds(state, destination):
		result.outcome = &"blocked"
		result.blocked_reason = &"out_of_bounds"
		return result
	if state.walls.has(destination):
		result.outcome = &"blocked"
		result.blocked_reason = &"wall"
		return result
	for unit_id in state.unit_order:
		var unit := state.get_unit(unit_id)
		if unit != null and unit.active and unit.unit_id != target.unit_id and unit.position == destination:
			result.outcome = &"blocked"
			result.blocked_reason = &"occupied"
			return result
	return result
