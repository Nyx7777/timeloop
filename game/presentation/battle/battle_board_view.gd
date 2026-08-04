class_name BattleBoardView
extends Control

signal cell_clicked(cell: Vector2i)

const BOARD_PADDING := 5.0

const COLOR_FLOOR_A := Color("#243249")
const COLOR_FLOOR_B := Color("#293852")
const COLOR_GRID := Color("#577091")
const COLOR_WALL_TOP := Color("#65758d")
const COLOR_WALL_SIDE := Color("#35445c")
const COLOR_MOVE := Color(0.20, 0.88, 0.64, 0.32)
const COLOR_ATTACK := Color(1.0, 0.26, 0.31, 0.42)
const COLOR_GHOST := Color("#ab78ff")
const COLOR_GHOST_PATH := Color(0.67, 0.47, 1.0, 0.20)
const COLOR_GHOST_FIRE := Color("#c69aff")
const COLOR_ENEMY_MOVE := Color("#f2b86b")
const COLOR_ENEMY_ATTACK := Color("#ff6670")
const COLOR_PUSH := Color("#ffd166")
const COLOR_PLAYER := Color("#54e6ff")
const COLOR_ENEMY := Color("#ff5f68")

var _board_size := Vector2i(8, 8)
var _walls: Array[Vector2i] = []
var _holes: Array[Vector2i] = []
var _display_units: Dictionary = {}
var _animated_positions: Dictionary = {}
var _reachable: Array[Vector2i] = []
var _attackable: Array[Vector2i] = []
var _ghost_path_cells: Array[Vector2i] = []
var _ghost_fire_cells: Array[Vector2i] = []
var _enemy_move_cells: Array[Vector2i] = []
var _enemy_attack_cells: Array[Vector2i] = []
var _push_previews: Array = []
var _hovered_cell := Vector2i(-1, -1)
var _pulse_cell := Vector2i(-1, -1)
var _interaction_enabled := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func sync_from_state(state: BattleState) -> void:
	_board_size = state.board_size
	_walls.assign(state.walls)
	_holes.assign(state.holes)
	_display_units.clear()
	_animated_positions.clear()
	_clear_all_previews()
	_pulse_cell = Vector2i(-1, -1)
	_hovered_cell = Vector2i(-1, -1)
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
				"disturbed": bool(unit.statuses.get("disturbed", false)),
			}
	for ghost_id in state.ghost_positions.keys():
		_display_units[ghost_id] = _ghost_entry(state.ghost_positions[ghost_id])
	queue_redraw()


func get_preview_snapshot_for_test() -> Dictionary:
	return {
		"ghost_path_count": _ghost_path_cells.size(),
		"ghost_fire_count": _ghost_fire_cells.size(),
		"enemy_move_count": _enemy_move_cells.size(),
		"enemy_attack_count": _enemy_attack_cells.size(),
		"push_preview_count": _push_previews.size(),
		"push_collision_count": _push_previews.filter(func(preview: Dictionary) -> bool: return preview.get("outcome", &"") == &"collision").size(),
	}


func get_layout_snapshot_for_test() -> Dictionary:
	return {
		"cell_size": _cell_size(),
		"board_rect": _board_rect(),
	}


func get_cell_at_local_for_test(point: Vector2) -> Vector2i:
	return _cell_from_local(point)


func handle_input_for_test(event: InputEvent) -> void:
	_gui_input(event)


func set_interaction(reachable: Array[Vector2i], attackable: Array[Vector2i], enabled: bool, push_previews: Array = []) -> void:
	_reachable.assign(reachable)
	_attackable.assign(attackable)
	_push_previews = VariantCodec.deep_copy(push_previews)
	_interaction_enabled = enabled
	queue_redraw()


func play_event(event: BattleEvent, speed: float) -> void:
	match event.event_type:
		&"timeline_started":
			_apply_timeline_reset(event.payload)
		&"turn_started":
			_apply_turn_preview(event.payload)
			await _wait(0.48, speed)
		&"phase_changed":
			_apply_phase_change(event.payload.get("phase", &""))
		&"unit_moved":
			await _play_move(event, speed)
		&"unit_pushed":
			await _play_move(event, speed)
		&"push_blocked":
			await _play_cell_pulse(event.payload.get("cell", Vector2i(-1, -1)), 0.12, speed)
		&"units_collided":
			await _play_cell_pulse(event.payload.get("second_cell", Vector2i(-1, -1)), 0.12, speed)
			await _play_cell_pulse(event.payload.get("first_cell", Vector2i(-1, -1)), 0.08, speed)
		&"enemy_disturbed":
			_apply_disturbed(event.actor_id)
			await _wait(0.08, speed)
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
	elif event is InputEventScreenTouch and event.pressed:
		var cell := _cell_from_local(event.position)
		if _interaction_enabled and _is_in_bounds(cell):
			cell_clicked.emit(cell)
			accept_event()


func _draw() -> void:
	_draw_board()
	_draw_overlays()
	_draw_units()


func _draw_board() -> void:
	var board_rect := _board_rect()
	draw_rect(board_rect.grow(3.0), Color("#080d17"), true)
	draw_rect(board_rect.grow(3.0), Color("#7550a1"), false, 2.0)
	for y in range(_board_size.y):
		for x in range(_board_size.x):
			var cell := Vector2i(x, y)
			var cell_rect := _cell_rect(cell)
			var floor_color := COLOR_FLOOR_A if (x + y) % 2 == 0 else COLOR_FLOOR_B
			draw_rect(cell_rect, floor_color, true)
			draw_rect(cell_rect, COLOR_GRID, false, 1.1)
			if _holes.has(cell):
				draw_rect(cell_rect.grow(-1.0), Color("#160f2b"), true)
				var radius := _cell_size() * 0.30
				draw_circle(grid_to_local(cell), radius, Color("#7e4cba"), false, maxf(2.0, _cell_size() * 0.07), true)
				draw_circle(grid_to_local(cell), radius * 0.58, Color("#05030c"), true)
	for wall in _walls:
		_draw_wall(wall)


func _draw_wall(cell: Vector2i) -> void:
	var cell_rect := _cell_rect(cell).grow(-1.0)
	var lift := _cell_size() * 0.12
	var top_rect := Rect2(cell_rect.position - Vector2(0.0, lift), Vector2(cell_rect.size.x, cell_rect.size.y * 0.76))
	var side_rect := Rect2(top_rect.position + Vector2(0.0, top_rect.size.y), Vector2(top_rect.size.x, lift + cell_rect.size.y * 0.24))
	draw_rect(side_rect, COLOR_WALL_SIDE, true)
	draw_rect(top_rect, COLOR_WALL_TOP, true)
	draw_rect(top_rect, COLOR_GRID.lightened(0.15), false, 1.2)


func _draw_overlays() -> void:
	for cell in _ghost_path_cells:
		draw_rect(_cell_rect(cell).grow(-1.0), COLOR_GHOST_PATH, true)
	for cell in _enemy_attack_cells:
		draw_rect(_cell_rect(cell).grow(-1.0), Color(COLOR_ENEMY_ATTACK, 0.24), true)
	for cell in _enemy_move_cells:
		_draw_cell_outline(cell, COLOR_ENEMY_MOVE, 2.5)
	for cell in _ghost_fire_cells:
		_draw_cell_outline(cell, COLOR_GHOST_FIRE, 3.2)
	for cell in _reachable:
		draw_rect(_cell_rect(cell).grow(-1.0), COLOR_MOVE, true)
	for cell in _attackable:
		draw_rect(_cell_rect(cell).grow(-1.0), COLOR_ATTACK, true)
	for preview_data in _push_previews:
		var preview: Dictionary = preview_data
		var cell: Vector2i = preview.get("display_cell", Vector2i(-1, -1))
		if not _is_in_bounds(cell):
			continue
		var outcome: StringName = preview.get("outcome", &"moved")
		var color := Color("#ff9e64") if outcome == &"collision" else (Color("#8b98aa") if outcome == &"blocked" else (Color("#c69aff") if outcome == &"time_hole" else COLOR_PUSH))
		var marker := "↯" if outcome == &"collision" else ("×" if outcome == &"blocked" else ("↓" if outcome == &"time_hole" else "→"))
		_draw_cell_outline(cell, color, 2.8)
		_draw_centered_text(grid_to_local(cell) + Vector2(0.0, 5.0), marker, 17, color)
	for cell in _ghost_fire_cells:
		_draw_centered_text(grid_to_local(cell) + Vector2(0.0, 5.0), "G!", 13, COLOR_GHOST_FIRE)
	for cell in _enemy_attack_cells:
		_draw_centered_text(grid_to_local(cell) + Vector2(0.0, 5.0), "!", 16, COLOR_ENEMY_ATTACK)
	if _is_in_bounds(_hovered_cell):
		var hover_color := Color(1.0, 1.0, 1.0, 0.65) if _interaction_enabled else Color(0.7, 0.7, 0.7, 0.25)
		draw_rect(_cell_rect(_hovered_cell).grow(-1.0), hover_color, false, 2.5)
	if _is_in_bounds(_pulse_cell):
		draw_rect(_cell_rect(_pulse_cell).grow(-1.0), Color(1.0, 0.88, 0.45, 0.55), true)


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
		var radius := clampf(_cell_size() * 0.30, 10.0, 19.0)
		var body_center := screen_position - Vector2(0.0, radius * 0.18)
		draw_circle(screen_position + Vector2(0.0, radius * 0.36), radius, Color(0.0, 0.0, 0.0, 0.34))
		draw_circle(body_center, radius, color)
		draw_circle(body_center, radius, color.lightened(0.25), false, 2.0, true)
		var marker := "G" if is_ghost else ("P" if team == &"player" else "E")
		_draw_centered_text(body_center + Vector2(0.0, 4.0), marker, maxi(12, int(radius * 0.82)), Color("#101828"))
		if bool(entry.get("disturbed", false)):
			draw_circle(body_center, radius + 4.0, Color("#ff8fc7"), false, 3.0, true)
			_draw_centered_text(body_center + Vector2(radius, -radius * 0.7), "~", 14, Color("#ff8fc7"))
		if not is_ghost:
			_draw_hp_bar(screen_position + Vector2(-_cell_size() * 0.34, radius * 0.78), int(entry.get("hp", 0)), int(entry.get("max_hp", 1)), color)


func _draw_hp_bar(position: Vector2, hp: int, max_hp: int, color: Color) -> void:
	var width := clampf(_cell_size() * 0.68, 24.0, 44.0)
	draw_rect(Rect2(position, Vector2(width, 5.0)), Color("#111725"), true)
	var ratio := clampf(float(hp) / float(maxi(max_hp, 1)), 0.0, 1.0)
	draw_rect(Rect2(position + Vector2(1.0, 1.0), Vector2((width - 2.0) * ratio, 3.0)), color, true)


func _draw_centered_text(center: Vector2, text: String, font_size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, center - Vector2(text_size.x * 0.5, -text_size.y * 0.28), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func grid_to_local(cell: Vector2i) -> Vector2:
	var rect := _board_rect()
	var cell_size := _cell_size()
	return rect.position + Vector2((float(cell.x) + 0.5) * cell_size, (float(cell.y) + 0.5) * cell_size)


func _cell_from_local(point: Vector2) -> Vector2i:
	var rect := _board_rect()
	if not rect.has_point(point):
		return Vector2i(-1, -1)
	var cell_size := _cell_size()
	var local_point := point - rect.position
	var candidate := Vector2i(floori(local_point.x / cell_size), floori(local_point.y / cell_size))
	return candidate if _is_in_bounds(candidate) else Vector2i(-1, -1)


func _play_move(event: BattleEvent, speed: float) -> void:
	var actor_id := event.actor_id
	var origin: Vector2i = event.payload.get("from", Vector2i.ZERO)
	var target: Vector2i = event.payload.get("to", origin)
	var path := _normalized_path(event.payload.get("path", []), origin, target)
	var is_ghost := bool(event.payload.get("is_ghost", false))
	if not _display_units.has(actor_id):
		_display_units[actor_id] = _ghost_entry(origin) if is_ghost else {
			"position": origin,
			"hp": 1,
			"max_hp": 1,
			"team": &"enemy",
			"active": true,
			"is_ghost": false,
			"disturbed": false,
		}
	for step_index in range(1, path.size()):
		var step_origin: Vector2i = path[step_index - 1]
		var step_target: Vector2i = path[step_index]
		var duration := _scaled_duration(0.16, speed)
		if duration > 0.0:
			var tween := create_tween()
			tween.tween_method(_set_move_progress.bind(actor_id, grid_to_local(step_origin), grid_to_local(step_target)), 0.0, 1.0, duration)
			await tween.finished
		else:
			_animated_positions[actor_id] = grid_to_local(step_target)
			queue_redraw()
			await get_tree().process_frame
		var step_entry: Dictionary = _display_units[actor_id]
		step_entry.position = step_target
		_display_units[actor_id] = step_entry
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


func _apply_disturbed(enemy_id: StringName) -> void:
	if not _display_units.has(enemy_id):
		return
	var entry: Dictionary = _display_units[enemy_id]
	entry.disturbed = true
	_display_units[enemy_id] = entry
	queue_redraw()


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
	_clear_all_previews()
	var units: Dictionary = payload.get("units", {})
	for unit_id in units.keys():
		var entry: Dictionary = VariantCodec.deep_copy(units[unit_id])
		entry.is_ghost = false
		_display_units[unit_id] = entry
	var ghosts: Dictionary = payload.get("ghost_positions", {})
	for ghost_id in ghosts.keys():
		_display_units[ghost_id] = _ghost_entry(ghosts[ghost_id])
	queue_redraw()


func _apply_turn_preview(payload: Dictionary) -> void:
	_ghost_path_cells.clear()
	_ghost_fire_cells.clear()
	_enemy_move_cells.clear()
	_enemy_attack_cells.clear()
	for action_data in payload.get("ghost_actions", []):
		var action: Dictionary = action_data
		var action_type: StringName = action.get("action_type", &"")
		if action_type == BattleCommand.MOVE:
			for cell_variant in action.get("path", []):
				_append_unique(_ghost_path_cells, cell_variant)
		elif action_type == BattleCommand.ATTACK:
			_append_unique(_ghost_fire_cells, action.get("target", Vector2i(-1, -1)))
	if StringName(payload.get("time_state", &"unknown")) == &"known":
		for intent_data in payload.get("enemy_intents", []):
			var intent: Dictionary = intent_data
			if bool(intent.get("reactive", false)):
				continue
			var intent_type: StringName = intent.get("intent_type", &"wait")
			if intent_type == &"move" or intent_type == &"move_attack":
				_append_unique(_enemy_move_cells, intent.get("to", Vector2i(-1, -1)))
			if intent_type == &"attack" or intent_type == &"move_attack":
				_append_unique(_enemy_attack_cells, intent.get("target", Vector2i(-1, -1)))
	queue_redraw()


func _apply_phase_change(phase: StringName) -> void:
	if phase == BattlePhase.PLAYER_INPUT:
		_ghost_path_cells.clear()
		_ghost_fire_cells.clear()
	elif phase == BattlePhase.ENEMY_EXECUTION:
		_enemy_move_cells.clear()
		_enemy_attack_cells.clear()
	elif phase == BattlePhase.TIMELINE_TRANSITION or phase == BattlePhase.BATTLE_OVER:
		_clear_all_previews()
	queue_redraw()


func _clear_all_previews() -> void:
	_ghost_path_cells.clear()
	_ghost_fire_cells.clear()
	_enemy_move_cells.clear()
	_enemy_attack_cells.clear()
	_push_previews.clear()


func _append_unique(cells: Array[Vector2i], cell: Vector2i) -> void:
	if _is_in_bounds(cell) and not cells.has(cell):
		cells.append(cell)


func _normalized_path(raw_path: Variant, origin: Vector2i, target: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if raw_path is Array:
		for cell_variant in raw_path:
			if cell_variant is Vector2i:
				path.append(cell_variant)
	if path.is_empty() or path[0] != origin:
		path.push_front(origin)
	if path[path.size() - 1] != target:
		path.append(target)
	return path


func _draw_cell_outline(cell: Vector2i, color: Color, width: float) -> void:
	draw_rect(_cell_rect(cell).grow(-1.0), color, false, width)


func _ghost_entry(position: Vector2i) -> Dictionary:
	return {
		"position": position,
		"hp": 1,
		"max_hp": 1,
		"team": &"ghost",
		"active": true,
		"is_ghost": true,
		"disturbed": false,
	}


func _sort_unit_ids(a: Variant, b: Variant) -> bool:
	var a_entry: Dictionary = _display_units[a]
	var b_entry: Dictionary = _display_units[b]
	var a_cell: Vector2i = a_entry.get("position", Vector2i.ZERO)
	var b_cell: Vector2i = b_entry.get("position", Vector2i.ZERO)
	return (a_cell.x + a_cell.y) < (b_cell.x + b_cell.y)


func _cell_size() -> float:
	var available_width := maxf(0.0, size.x - BOARD_PADDING * 2.0)
	var available_height := maxf(0.0, size.y - BOARD_PADDING * 2.0)
	return maxf(1.0, floorf(minf(available_width / float(_board_size.x), available_height / float(_board_size.y))))


func _board_rect() -> Rect2:
	var cell_size := _cell_size()
	var board_pixels := Vector2(float(_board_size.x) * cell_size, float(_board_size.y) * cell_size)
	return Rect2((size - board_pixels) * 0.5, board_pixels)


func _cell_rect(cell: Vector2i) -> Rect2:
	var rect := _board_rect()
	var cell_size := _cell_size()
	return Rect2(rect.position + Vector2(float(cell.x) * cell_size, float(cell.y) * cell_size), Vector2(cell_size, cell_size))


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
