class_name BattleBoardView
extends Control

signal cell_clicked(cell: Vector2i)

const CELL_WIDTH := 96.0
const CELL_HEIGHT := 48.0
const HALF_WIDTH := CELL_WIDTH * 0.5
const HALF_HEIGHT := CELL_HEIGHT * 0.5

const COLOR_FLOOR_A := Color("#243249")
const COLOR_FLOOR_B := Color("#293852")
const COLOR_GRID := Color("#577091")
const COLOR_WALL_TOP := Color("#65758d")
const COLOR_WALL_SIDE := Color("#35445c")
const COLOR_MOVE := Color(0.20, 0.88, 0.64, 0.32)
const COLOR_ATTACK := Color(1.0, 0.26, 0.31, 0.42)
const COLOR_GHOST := Color("#ab78ff")
const COLOR_PLAYER := Color("#54e6ff")
const COLOR_ENEMY := Color("#ff5f68")

var _board_size := Vector2i(8, 8)
var _walls: Array[Vector2i] = []
var _holes: Array[Vector2i] = []
var _display_units: Dictionary = {}
var _animated_positions: Dictionary = {}
var _reachable: Array[Vector2i] = []
var _attackable: Array[Vector2i] = []
var _hovered_cell := Vector2i(-1, -1)
var _pulse_cell := Vector2i(-1, -1)
var _interaction_enabled := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	queue_redraw()


func sync_from_state(state: BattleState) -> void:
	_board_size = state.board_size
	_walls.assign(state.walls)
	_holes.assign(state.holes)
	_display_units.clear()
	_animated_positions.clear()
	for unit_id in state.unit_order:
		var unit := state.get_unit(unit_id)
		if unit != null:
			_display_units[unit.unit_id] = {
				"position": unit.position,
				"hp": unit.hp,
				"max_hp": unit.max_hp,
				"team": unit.team,
				"active": unit.active,
				"is_ghost": false,
			}
	for ghost_id in state.ghost_positions.keys():
		_display_units[ghost_id] = _ghost_entry(state.ghost_positions[ghost_id])
	queue_redraw()


func set_interaction(reachable: Array[Vector2i], attackable: Array[Vector2i], enabled: bool) -> void:
	_reachable.assign(reachable)
	_attackable.assign(attackable)
	_interaction_enabled = enabled
	queue_redraw()


func play_event(event: BattleEvent, speed: float) -> void:
	match event.event_type:
		&"timeline_started":
			_apply_timeline_reset(event.payload)
		&"unit_moved":
			await _play_move(event, speed)
		&"attack_performed":
			await _play_cell_pulse(event.payload.get("target_cell", Vector2i(-1, -1)), 0.16, speed)
		&"damage_applied":
			_apply_damage_event(event.payload)
			await _wait(0.10, speed)
		&"unit_died":
			await _play_death(event, speed)
		&"state_restored":
			var restored := BattleState.from_dict(event.payload.get("state", {}))
			sync_from_state(restored)
		_:
			await _wait(0.025, speed)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hovered_cell = _cell_from_local(event.position)
		queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var cell := _cell_from_local(event.position)
		if _interaction_enabled and _is_in_bounds(cell):
			cell_clicked.emit(cell)
			accept_event()


func _draw() -> void:
	_draw_board()
	_draw_overlays()
	_draw_units()


func _draw_board() -> void:
	for y in range(_board_size.y):
		for x in range(_board_size.x):
			var cell := Vector2i(x, y)
			var center := grid_to_local(cell)
			var diamond := _diamond(center)
			var floor_color := COLOR_FLOOR_A if (x + y) % 2 == 0 else COLOR_FLOOR_B
			draw_colored_polygon(diamond, floor_color)
			draw_polyline(_closed_polygon(diamond), COLOR_GRID, 1.2, true)
			if _holes.has(cell):
				draw_colored_polygon(diamond, Color("#160f2b"))
				draw_circle(center, 12.0, Color("#7e4cba"), false, 3.0, true)
	for wall in _walls:
		_draw_wall(wall)


func _draw_wall(cell: Vector2i) -> void:
	var center := grid_to_local(cell)
	var top_center := center - Vector2(0.0, 24.0)
	var top := _diamond(top_center)
	var left_side := PackedVector2Array([
		top[3], top[2], top[2] + Vector2(0.0, 24.0), top[3] + Vector2(0.0, 24.0),
	])
	var right_side := PackedVector2Array([
		top[1], top[2], top[2] + Vector2(0.0, 24.0), top[1] + Vector2(0.0, 24.0),
	])
	draw_colored_polygon(left_side, COLOR_WALL_SIDE.darkened(0.12))
	draw_colored_polygon(right_side, COLOR_WALL_SIDE)
	draw_colored_polygon(top, COLOR_WALL_TOP)
	draw_polyline(_closed_polygon(top), COLOR_GRID.lightened(0.15), 1.2, true)


func _draw_overlays() -> void:
	for cell in _reachable:
		draw_colored_polygon(_diamond(grid_to_local(cell)), COLOR_MOVE)
	for cell in _attackable:
		draw_colored_polygon(_diamond(grid_to_local(cell)), COLOR_ATTACK)
	if _is_in_bounds(_hovered_cell):
		var hover_color := Color(1.0, 1.0, 1.0, 0.65) if _interaction_enabled else Color(0.7, 0.7, 0.7, 0.25)
		draw_polyline(_closed_polygon(_diamond(grid_to_local(_hovered_cell))), hover_color, 2.5, true)
	if _is_in_bounds(_pulse_cell):
		draw_colored_polygon(_diamond(grid_to_local(_pulse_cell)), Color(1.0, 0.88, 0.45, 0.55))


func _draw_units() -> void:
	var ids: Array = _display_units.keys()
	ids.sort_custom(_sort_unit_ids)
	for unit_id_variant in ids:
		var unit_id: StringName = unit_id_variant
		var entry: Dictionary = _display_units[unit_id]
		if not bool(entry.get("active", true)):
			continue
		var screen_position: Vector2 = _animated_positions.get(unit_id, grid_to_local(entry.get("position", Vector2i.ZERO)))
		var is_ghost := bool(entry.get("is_ghost", false))
		var team: StringName = entry.get("team", &"")
		var color := COLOR_GHOST if is_ghost else (COLOR_PLAYER if team == &"player" else COLOR_ENEMY)
		draw_circle(screen_position + Vector2(0.0, 7.0), 19.0, Color(0.0, 0.0, 0.0, 0.34))
		draw_circle(screen_position - Vector2(0.0, 8.0), 18.0, color)
		draw_circle(screen_position - Vector2(0.0, 8.0), 18.0, color.lightened(0.25), false, 2.0, true)
		var marker := "G" if is_ghost else ("P" if team == &"player" else "E")
		_draw_centered_text(screen_position - Vector2(0.0, 2.0), marker, 16, Color("#101828"))
		if not is_ghost:
			_draw_hp_bar(screen_position + Vector2(-22.0, 18.0), int(entry.get("hp", 0)), int(entry.get("max_hp", 1)), color)


func _draw_hp_bar(position: Vector2, hp: int, max_hp: int, color: Color) -> void:
	var width := 44.0
	draw_rect(Rect2(position, Vector2(width, 5.0)), Color("#111725"), true)
	var ratio := clampf(float(hp) / float(maxi(max_hp, 1)), 0.0, 1.0)
	draw_rect(Rect2(position + Vector2(1.0, 1.0), Vector2((width - 2.0) * ratio, 3.0)), color, true)


func _draw_centered_text(center: Vector2, text: String, font_size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, center - Vector2(text_size.x * 0.5, -text_size.y * 0.28), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func grid_to_local(cell: Vector2i) -> Vector2:
	var origin := Vector2(size.x * 0.5, 72.0)
	return origin + Vector2((cell.x - cell.y) * HALF_WIDTH, (cell.x + cell.y) * HALF_HEIGHT)


func _cell_from_local(point: Vector2) -> Vector2i:
	var origin := Vector2(size.x * 0.5, 72.0)
	var relative := point - origin
	var iso_x := relative.x / HALF_WIDTH
	var iso_y := relative.y / HALF_HEIGHT
	var candidate := Vector2i(roundi((iso_y + iso_x) * 0.5), roundi((iso_y - iso_x) * 0.5))
	if not _is_in_bounds(candidate):
		return Vector2i(-1, -1)
	var center := grid_to_local(candidate)
	var normalized := absf(point.x - center.x) / HALF_WIDTH + absf(point.y - center.y) / HALF_HEIGHT
	return candidate if normalized <= 1.0 else Vector2i(-1, -1)


func _play_move(event: BattleEvent, speed: float) -> void:
	var actor_id := event.actor_id
	var origin: Vector2i = event.payload.get("from", Vector2i.ZERO)
	var target: Vector2i = event.payload.get("to", origin)
	var is_ghost := bool(event.payload.get("is_ghost", false))
	if not _display_units.has(actor_id):
		_display_units[actor_id] = _ghost_entry(origin) if is_ghost else {
			"position": origin,
			"hp": 1,
			"max_hp": 1,
			"team": &"enemy",
			"active": true,
			"is_ghost": false,
		}
	var duration := _scaled_duration(0.22, speed)
	if duration > 0.0:
		var tween := create_tween()
		tween.tween_method(_set_move_progress.bind(actor_id, grid_to_local(origin), grid_to_local(target)), 0.0, 1.0, duration)
		await tween.finished
	var entry: Dictionary = _display_units[actor_id]
	entry.position = target
	_display_units[actor_id] = entry
	_animated_positions.erase(actor_id)
	queue_redraw()


func _set_move_progress(progress: float, actor_id: StringName, origin: Vector2, target: Vector2) -> void:
	_animated_positions[actor_id] = origin.lerp(target, progress)
	queue_redraw()


func _play_cell_pulse(cell: Vector2i, base_duration: float, speed: float) -> void:
	_pulse_cell = cell
	queue_redraw()
	await _wait(base_duration, speed)
	_pulse_cell = Vector2i(-1, -1)
	queue_redraw()


func _apply_damage_event(payload: Dictionary) -> void:
	var target_id: StringName = payload.get("target_id", &"")
	if not _display_units.has(target_id):
		return
	var entry: Dictionary = _display_units[target_id]
	entry.hp = int(payload.get("remaining_hp", entry.get("hp", 0)))
	_display_units[target_id] = entry


func _play_death(event: BattleEvent, speed: float) -> void:
	var cell: Vector2i = event.payload.get("cell", Vector2i(-1, -1))
	await _play_cell_pulse(cell, 0.18, speed)
	if _display_units.has(event.actor_id):
		var entry: Dictionary = _display_units[event.actor_id]
		entry.active = false
		_display_units[event.actor_id] = entry


func _apply_timeline_reset(payload: Dictionary) -> void:
	_display_units.clear()
	_animated_positions.clear()
	var units: Dictionary = payload.get("units", {})
	for unit_id in units.keys():
		var entry: Dictionary = VariantCodec.deep_copy(units[unit_id])
		entry.is_ghost = false
		_display_units[unit_id] = entry
	var ghosts: Dictionary = payload.get("ghost_positions", {})
	for ghost_id in ghosts.keys():
		_display_units[ghost_id] = _ghost_entry(ghosts[ghost_id])
	queue_redraw()


func _ghost_entry(position: Vector2i) -> Dictionary:
	return {
		"position": position,
		"hp": 1,
		"max_hp": 1,
		"team": &"ghost",
		"active": true,
		"is_ghost": true,
	}


func _sort_unit_ids(a: Variant, b: Variant) -> bool:
	var a_entry: Dictionary = _display_units[a]
	var b_entry: Dictionary = _display_units[b]
	var a_cell: Vector2i = a_entry.get("position", Vector2i.ZERO)
	var b_cell: Vector2i = b_entry.get("position", Vector2i.ZERO)
	return (a_cell.x + a_cell.y) < (b_cell.x + b_cell.y)


func _diamond(center: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(0.0, -HALF_HEIGHT),
		center + Vector2(HALF_WIDTH, 0.0),
		center + Vector2(0.0, HALF_HEIGHT),
		center + Vector2(-HALF_WIDTH, 0.0),
	])


func _closed_polygon(points: PackedVector2Array) -> PackedVector2Array:
	var closed := PackedVector2Array(points)
	closed.append(points[0])
	return closed


func _is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < _board_size.x and cell.y < _board_size.y


func _wait(base_duration: float, speed: float) -> void:
	var duration := _scaled_duration(base_duration, speed)
	if duration > 0.0:
		await get_tree().create_timer(duration).timeout
	else:
		await get_tree().process_frame


func _scaled_duration(base_duration: float, speed: float) -> float:
	return 0.0 if speed <= 0.0 else base_duration / speed
