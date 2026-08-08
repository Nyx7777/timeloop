class_name BattleBoardView
extends Control

signal cell_clicked(cell: Vector2i)

const UnitAnimationStateScript := preload("res://presentation/battle/unit_animation_state.gd")

const BOARD_PADDING := 5.0
const OBSTACLE_DRAW_WIDTH_CELLS := 1.45
const OBSTACLE_DRAW_HEIGHT_CELLS := 1.22
const FLOOR_TILE_TEXTURE := preload("res://assets/environment/lab_floor_tile.png")
const OBSTACLE_SERVER_TEXTURE := preload("res://assets/environment/lab_obstacle_server.png")
const OBSTACLE_PILLAR_TEXTURE := preload("res://assets/environment/lab_obstacle_pillar.png")
const TIME_VOID_TEXTURE := preload("res://assets/environment/time_void_tile.png")
const BOARD_FRAME_TEXTURE := preload("res://assets/ui/m42c/board_frame_border.png")
const PLAYER_IDLE_TEXTURE := preload("res://assets/characters/player_idle.png")
const GHOST_IDLE_TEXTURE := preload("res://assets/characters/ghost_idle.png")
const GUARD_IDLE_TEXTURE := preload("res://assets/characters/guard_idle.png")
const PLAYER_HP_TEXTURE := preload("res://assets/ui/m42c/hp_bar_player.png")
const ENEMY_HP_TEXTURE := preload("res://assets/ui/m42c/hp_bar_enemy.png")
const UNIT_DRAW_HEIGHT_CELLS := 1.18
const UNIT_SPRITE_FOOT_OFFSET_CELLS := 0.28
const UNIT_RING_OFFSET_CELLS := 0.18
const UNIT_RING_RADIUS_CELLS := 0.25
const UNIT_RING_Y_SCALE := 0.38

const COLOR_FLOOR_A := Color("#ffffff")
const COLOR_FLOOR_B := Color("#f4f7fb")
const COLOR_GRID := Color("#718096")
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
const COLOR_HIT := Color("#ff9b8f")
const COLOR_COLLISION := Color("#ffb35c")
const COLOR_CRYSTALLIZE := Color("#c58cff")

var _board_size := Vector2i(8, 8)
var _walls: Array[Vector2i] = []
var _holes: Array[Vector2i] = []
var _display_units: Dictionary = {}
var _animated_positions: Dictionary = {}
var _unit_animations: Dictionary = {}
var _floating_numbers: Array[Dictionary] = []
var _impact_flashes: Array[Dictionary] = []
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
var _board_frame_style: StyleBoxTexture


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = false
	_board_frame_style = StyleBoxTexture.new()
	_board_frame_style.texture = BOARD_FRAME_TEXTURE
	_board_frame_style.texture_margin_left = 18.0
	_board_frame_style.texture_margin_top = 18.0
	_board_frame_style.texture_margin_right = 18.0
	_board_frame_style.texture_margin_bottom = 18.0
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
	_unit_animations.clear()
	_floating_numbers.clear()
	_impact_flashes.clear()
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
			_ensure_animation(unit.unit_id)
	for ghost_id in state.ghost_positions.keys():
		_display_units[ghost_id] = _ghost_entry(state.ghost_positions[ghost_id])
		_ensure_animation(ghost_id)
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


func get_animation_snapshot_for_test() -> Dictionary:
	var units := {}
	for unit_id in _unit_animations:
		units[unit_id] = _unit_animations[unit_id].snapshot()
	return {
		"units": units,
		"floating_number_count": _floating_numbers.size(),
		"impact_flash_count": _impact_flashes.size(),
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
			await _play_push(event, speed)
		&"push_blocked":
			await _play_cell_pulse(event.payload.get("cell", Vector2i(-1, -1)), 0.12, speed)
		&"units_collided":
			await _play_collision(event, speed)
		&"enemy_disturbed":
			_apply_disturbed(event.actor_id)
			await _wait(0.08, speed)
		&"attack_performed":
			await _play_attack(event, speed)
		&"damage_applied":
			await _play_damage(event, speed)
		&"unit_died":
			await _play_death(event, speed)
		&"timeline_crystallized":
			await _play_crystallize(event, speed)
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
	_draw_effects()


func _draw_board() -> void:
	var board_rect := _board_rect()
	draw_style_box(_board_frame_style, board_rect.grow(7.0))
	draw_rect(board_rect.grow(2.0), Color("#080d17"), true)
	for y in range(_board_size.y):
		for x in range(_board_size.x):
			var cell := Vector2i(x, y)
			var cell_rect := _cell_rect(cell)
			var floor_color := COLOR_FLOOR_A if (x + y) % 2 == 0 else COLOR_FLOOR_B
			draw_texture_rect(FLOOR_TILE_TEXTURE, cell_rect, false, floor_color)
			draw_rect(cell_rect, COLOR_GRID, false, 1.1)
			if _holes.has(cell):
				draw_rect(cell_rect.grow(-1.0), Color("#110923"), true)
				draw_texture_rect(TIME_VOID_TEXTURE, cell_rect.grow(-1.0), false)
	for wall_row in range(_board_size.y):
		for wall in _walls:
			if wall.y == wall_row:
				_draw_wall(wall)


func _draw_wall(cell: Vector2i) -> void:
	var cell_rect := _cell_rect(cell)
	var texture := OBSTACLE_SERVER_TEXTURE if (cell.x + cell.y) % 2 == 0 else OBSTACLE_PILLAR_TEXTURE
	var sprite_size := Vector2(
		cell_rect.size.x * OBSTACLE_DRAW_WIDTH_CELLS,
		cell_rect.size.y * OBSTACLE_DRAW_HEIGHT_CELLS
	)
	var sprite_rect := Rect2(
		Vector2(cell_rect.get_center().x - sprite_size.x * 0.5, cell_rect.end.y - sprite_size.y),
		sprite_size
	)
	draw_texture_rect(texture, sprite_rect, false)


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
		var animation: UnitAnimationState = _ensure_animation(unit_id)
		var is_ghost := bool(entry.get("is_ghost", false))
		var team: StringName = entry.get("team", &"")
		var color := COLOR_GHOST if is_ghost else (COLOR_PLAYER if team == &"player" else COLOR_ENEMY)
		var cell_size := _cell_size()
		var sprite_foot := screen_position + Vector2(0.0, cell_size * UNIT_SPRITE_FOOT_OFFSET_CELLS)
		var ring_center := screen_position + Vector2(0.0, cell_size * UNIT_RING_OFFSET_CELLS)
		var ring_radius := cell_size * UNIT_RING_RADIUS_CELLS
		_draw_foot_ellipse(ring_center, ring_radius, color)
		var texture: Texture2D = GHOST_IDLE_TEXTURE if is_ghost else (PLAYER_IDLE_TEXTURE if team == &"player" else GUARD_IDLE_TEXTURE)
		var sprite_height := roundf(cell_size * UNIT_DRAW_HEIGHT_CELLS)
		var sprite_width := roundf(sprite_height * float(texture.get_width()) / float(texture.get_height()))
		var sprite_size := Vector2(sprite_width, sprite_height)
		var sprite_modulate := Color(1.0, 1.0, 1.0, 0.88) if is_ghost else Color.WHITE
		sprite_modulate *= animation.tint
		sprite_modulate.a *= animation.opacity
		var facing_scale_x := -1.0 if animation.facing.x < 0 else 1.0
		draw_set_transform(
			Vector2(roundf(sprite_foot.x + animation.offset.x), roundf(sprite_foot.y + animation.offset.y)),
			animation.rotation,
			Vector2(animation.scale.x * facing_scale_x, animation.scale.y)
		)
		var local_sprite_rect := Rect2(Vector2(roundf(-sprite_size.x * 0.5), roundf(-sprite_size.y)), sprite_size)
		draw_texture_rect(texture, local_sprite_rect, false, sprite_modulate)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if bool(entry.get("disturbed", false)):
			_draw_ellipse_outline(ring_center, ring_radius + 3.0, Color("#ff8fc7"), 3.0)
			_draw_centered_text(screen_position + Vector2(cell_size * 0.34, -cell_size * 0.42), "~", 14, Color("#ff8fc7"))
		if not is_ghost:
			_draw_hp_bar(
				screen_position + Vector2(-cell_size * 0.34, cell_size * 0.36),
				int(entry.get("hp", 0)),
				int(entry.get("max_hp", 1)),
				team
			)


func _draw_effects() -> void:
	var cell_size := _cell_size()
	for unit_id in _unit_animations:
		var animation: UnitAnimationState = _unit_animations[unit_id]
		if animation.state != UnitAnimationState.DEATH and animation.state != UnitAnimationState.CRYSTALLIZE:
			continue
		if not _display_units.has(unit_id):
			continue
		var entry: Dictionary = _display_units[unit_id]
		var center: Vector2 = _animated_positions.get(unit_id, grid_to_local(entry.get("position", Vector2i.ZERO)))
		_draw_temporal_shards(center, animation)
	for flash in _impact_flashes:
		var center: Vector2 = flash.get("position", Vector2.ZERO)
		var intensity := float(flash.get("intensity", 0.0))
		var color: Color = flash.get("color", COLOR_COLLISION)
		var radius := cell_size * lerpf(0.12, 0.48, intensity)
		draw_circle(center, radius, Color(color, 0.42 * intensity))
		var diamond_radius := cell_size * lerpf(0.05, 0.16, intensity)
		draw_colored_polygon(PackedVector2Array([
			center + Vector2(0.0, -diamond_radius),
			center + Vector2(diamond_radius, 0.0),
			center + Vector2(0.0, diamond_radius),
			center + Vector2(-diamond_radius, 0.0),
		]), Color(1.0, 0.96, 0.78, 0.82 * intensity))
		for ray_index in range(8):
			var angle := float(ray_index) * TAU / 8.0
			var inner := center + Vector2.from_angle(angle) * radius * 0.45
			var outer := center + Vector2.from_angle(angle) * radius
			draw_line(inner, outer, Color(color, 0.95 * intensity), maxf(1.5, cell_size * 0.06))
	for number in _floating_numbers:
		var position: Vector2 = number.get("position", Vector2.ZERO) + Vector2(0.0, float(number.get("rise", 0.0)))
		var alpha := float(number.get("alpha", 1.0))
		var color: Color = number.get("color", COLOR_HIT)
		var text := String(number.get("text", ""))
		var font_size := maxi(17, roundi(cell_size * 0.42))
		var badge_size := Vector2(float(font_size) * 1.55, float(font_size) * 1.12)
		draw_rect(Rect2(position - badge_size * 0.5 + Vector2(0.0, 1.0), badge_size), Color(0.03, 0.04, 0.08, alpha * 0.82), true)
		draw_rect(Rect2(position - badge_size * 0.5 + Vector2(0.0, 1.0), badge_size), Color(color, alpha * 0.92), false, 1.5)
		_draw_centered_text(position + Vector2(1.5, 2.0), text, font_size, Color(0.03, 0.04, 0.08, alpha * 0.92))
		_draw_centered_text(position, text, font_size, Color(Color.WHITE.lerp(color, 0.36), alpha))


func _draw_temporal_shards(center: Vector2, animation: UnitAnimationState) -> void:
	var progress := animation.progress
	var cell_size := _cell_size()
	var color := COLOR_CRYSTALLIZE if animation.state == UnitAnimationState.CRYSTALLIZE else COLOR_HIT
	var alpha := sin(progress * PI) * (0.85 if animation.state == UnitAnimationState.CRYSTALLIZE else 0.68)
	var base_distance := cell_size * (0.12 + progress * 0.42)
	for shard_index in range(8):
		var angle := float(shard_index) * TAU / 8.0 + (0.18 if shard_index % 2 == 0 else -0.08)
		var direction := Vector2.from_angle(angle)
		var shard_center := center + direction * base_distance
		var side := direction.rotated(PI * 0.5) * cell_size * 0.035
		var tip := direction * cell_size * 0.09
		draw_colored_polygon(PackedVector2Array([shard_center + tip, shard_center + side, shard_center - tip * 0.45, shard_center - side]), Color(color, alpha))
	if animation.state == UnitAnimationState.CRYSTALLIZE:
		draw_circle(center, cell_size * (0.24 + progress * 0.22), Color(color, alpha * 0.7), false, maxf(1.5, cell_size * 0.04), true)


func _draw_foot_ellipse(center: Vector2, radius: float, color: Color) -> void:
	draw_set_transform(center, 0.0, Vector2(1.0, UNIT_RING_Y_SCALE))
	draw_circle(Vector2.ZERO, radius, Color(0.0, 0.0, 0.0, 0.38))
	draw_circle(Vector2.ZERO, radius * 0.86, Color(color, 0.20))
	draw_circle(Vector2.ZERO, radius, color.lightened(0.18), false, maxf(1.5, radius * 0.17), true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_ellipse_outline(center: Vector2, radius: float, color: Color, width: float) -> void:
	draw_set_transform(center, 0.0, Vector2(1.0, UNIT_RING_Y_SCALE))
	draw_circle(Vector2.ZERO, radius, color, false, width, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_hp_bar(position: Vector2, hp: int, max_hp: int, team: StringName) -> void:
	var width := clampf(_cell_size() * 0.68, 24.0, 44.0)
	var height := 6.0
	var bar_rect := Rect2(position, Vector2(width, height))
	var texture: Texture2D = PLAYER_HP_TEXTURE if team == &"player" else ENEMY_HP_TEXTURE
	draw_texture_rect(texture, bar_rect, false)
	var ratio := clampf(float(hp) / float(maxi(max_hp, 1)), 0.0, 1.0)
	if ratio < 1.0:
		var missing_width := (width - 2.0) * (1.0 - ratio)
		draw_rect(
			Rect2(position + Vector2(1.0 + (width - 2.0) * ratio, 1.0), Vector2(missing_width, height - 2.0)),
			Color("#111725"),
			true
		)
	draw_rect(bar_rect, Color("#050914"), false, 1.0)


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
	await _play_path_motion(event, speed, UnitAnimationState.MOVE, 0.16)


func _play_push(event: BattleEvent, speed: float) -> void:
	await _play_path_motion(event, speed, UnitAnimationState.PUSHED, 0.11)


func _play_path_motion(event: BattleEvent, speed: float, animation_state: StringName, base_step_duration: float) -> void:
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
	var animation: UnitAnimationState = _ensure_animation(actor_id)
	animation.begin(animation_state, _cardinal_direction(origin, target))
	for step_index in range(1, path.size()):
		var step_origin: Vector2i = path[step_index - 1]
		var step_target: Vector2i = path[step_index]
		animation.facing = _cardinal_direction(step_origin, step_target)
		var duration := _scaled_duration(base_step_duration, speed)
		if duration > 0.0:
			var tween := create_tween()
			tween.set_trans(Tween.TRANS_SINE)
			tween.set_ease(Tween.EASE_IN_OUT)
			tween.tween_method(_set_move_progress.bind(actor_id, grid_to_local(step_origin), grid_to_local(step_target), animation_state), 0.0, 1.0, duration)
			await tween.finished
		else:
			_animated_positions[actor_id] = grid_to_local(step_target)
			animation.progress = 1.0
			queue_redraw()
			await get_tree().process_frame
		var step_entry: Dictionary = _display_units[actor_id]
		step_entry.position = step_target
		_display_units[actor_id] = step_entry
	var entry: Dictionary = _display_units[actor_id]
	entry.position = target
	_display_units[actor_id] = entry
	_animated_positions.erase(actor_id)
	animation.complete()
	queue_redraw()


func _set_move_progress(progress: float, actor_id: StringName, origin: Vector2, target: Vector2, animation_state: StringName) -> void:
	var animation: UnitAnimationState = _ensure_animation(actor_id)
	animation.progress = progress
	_animated_positions[actor_id] = origin.lerp(target, progress)
	var arc := sin(progress * PI)
	if animation_state == UnitAnimationState.PUSHED:
		animation.rotation = sin(progress * PI * 2.0) * 0.08
		animation.scale = Vector2(1.0 + arc * 0.10, 1.0 - arc * 0.12)
	else:
		animation.offset.y = -arc * _cell_size() * 0.08
		animation.scale = Vector2(1.0 + arc * 0.035, 1.0 - arc * 0.035)
	queue_redraw()


func _play_attack(event: BattleEvent, speed: float) -> void:
	var actor_id := event.actor_id
	var target_cell: Vector2i = event.payload.get("target_cell", Vector2i(-1, -1))
	if not _display_units.has(actor_id):
		await _wait(0.16, speed)
		return
	var entry: Dictionary = _display_units[actor_id]
	var origin_cell: Vector2i = entry.get("position", target_cell)
	var direction := _cardinal_direction(origin_cell, target_cell)
	var animation: UnitAnimationState = _ensure_animation(actor_id)
	animation.begin(UnitAnimationState.ATTACK, direction)
	var flash := _add_impact_flash(grid_to_local(target_cell), COLOR_HIT)
	var duration := _scaled_duration(0.24, speed)
	if duration > 0.0:
		var tween := create_tween()
		tween.tween_method(_set_attack_progress.bind(actor_id, direction, flash), 0.0, 1.0, duration)
		await tween.finished
	else:
		_set_attack_progress(1.0, actor_id, direction, flash)
		await get_tree().process_frame
	_impact_flashes.erase(flash)
	animation.complete()
	queue_redraw()


func _set_attack_progress(progress: float, actor_id: StringName, direction: Vector2i, flash: Dictionary) -> void:
	var animation: UnitAnimationState = _ensure_animation(actor_id)
	animation.progress = progress
	var cell_size := _cell_size()
	var direction_vector := Vector2(direction)
	if progress < 0.32:
		var anticipation := progress / 0.32
		animation.offset = -direction_vector * cell_size * 0.07 * anticipation
		animation.scale = Vector2(0.94, 1.06)
	elif progress < 0.62:
		var strike := (progress - 0.32) / 0.30
		animation.offset = direction_vector * cell_size * lerpf(-0.07, 0.28, strike)
		animation.scale = Vector2(1.10, 0.91)
	else:
		var recover := (progress - 0.62) / 0.38
		animation.offset = direction_vector * cell_size * 0.28 * (1.0 - recover)
		animation.scale = Vector2.ONE.lerp(Vector2(1.10, 0.91), 1.0 - recover)
	flash.intensity = clampf(sin(clampf((progress - 0.38) / 0.62, 0.0, 1.0) * PI), 0.0, 1.0)
	queue_redraw()


func _play_damage(event: BattleEvent, speed: float) -> void:
	var target_id: StringName = event.payload.get("target_id", &"")
	_apply_damage_event(event.payload)
	if not _display_units.has(target_id):
		await _wait(0.08, speed)
		return
	var cause: StringName = event.payload.get("cause", &"attack")
	var damage := int(event.payload.get("damage", 0))
	var animation: UnitAnimationState = _ensure_animation(target_id)
	var source_position := _unit_screen_position(event.actor_id)
	var target_position := _unit_screen_position(target_id)
	var hit_direction := _cardinal_direction_from_vector(target_position - source_position)
	animation.begin(UnitAnimationState.HIT, -hit_direction)
	var number: Dictionary = {}
	if cause != &"collision":
		number = _add_floating_number(target_position - Vector2(0.0, _cell_size() * 0.62), "-%d" % damage, COLOR_HIT)
	var duration := _scaled_duration(0.18 if cause != &"collision" else 0.10, speed)
	if duration > 0.0:
		var tween := create_tween().set_parallel(true)
		tween.tween_method(_set_hit_progress.bind(target_id, hit_direction), 0.0, 1.0, duration)
		if not number.is_empty():
			tween.tween_method(_set_number_progress.bind(number), 0.0, 1.0, duration)
		await tween.finished
	else:
		_set_hit_progress(1.0, target_id, hit_direction)
		if not number.is_empty():
			_set_number_progress(1.0, number)
		await get_tree().process_frame
	if not number.is_empty():
		_floating_numbers.erase(number)
	animation.complete()
	queue_redraw()


func _set_hit_progress(progress: float, target_id: StringName, direction: Vector2i) -> void:
	var animation: UnitAnimationState = _ensure_animation(target_id)
	animation.progress = progress
	var decay := 1.0 - progress
	var shake := sin(progress * PI * 6.0) * decay
	animation.offset = Vector2(direction) * _cell_size() * 0.10 * shake
	animation.scale = Vector2(1.0 + sin(progress * PI) * 0.08, 1.0 - sin(progress * PI) * 0.08)
	animation.tint = Color.WHITE.lerp(COLOR_HIT, sin(progress * PI) * 0.72)
	queue_redraw()


func _play_collision(event: BattleEvent, speed: float) -> void:
	var first_id: StringName = event.payload.get("first_unit_id", event.actor_id)
	var second_id: StringName = event.payload.get("second_unit_id", &"")
	var first_cell: Vector2i = event.payload.get("first_cell", Vector2i(-1, -1))
	var second_cell: Vector2i = event.payload.get("second_cell", Vector2i(-1, -1))
	var direction := _cardinal_direction(first_cell, second_cell)
	var first_animation: UnitAnimationState = _ensure_animation(first_id)
	var second_animation: UnitAnimationState = _ensure_animation(second_id)
	first_animation.begin(UnitAnimationState.COLLISION, direction)
	second_animation.begin(UnitAnimationState.COLLISION, -direction)
	var midpoint := (grid_to_local(first_cell) + grid_to_local(second_cell)) * 0.5
	var flash := _add_impact_flash(midpoint, COLOR_COLLISION)
	var damage := int(event.payload.get("damage", 1))
	var perpendicular := Vector2(-direction.y, direction.x)
	var first_number := _add_floating_number(grid_to_local(first_cell) + perpendicular * _cell_size() * 0.42 - Vector2(0.0, _cell_size() * 0.68), "-%d" % damage, COLOR_COLLISION)
	var second_number := _add_floating_number(grid_to_local(second_cell) - perpendicular * _cell_size() * 0.42 - Vector2(0.0, _cell_size() * 0.68), "-%d" % damage, COLOR_COLLISION)
	var duration := _scaled_duration(0.30, speed)
	if duration > 0.0:
		var tween := create_tween().set_parallel(true)
		tween.tween_method(_set_collision_progress.bind(first_id, second_id, direction, flash), 0.0, 1.0, duration)
		tween.tween_method(_set_number_progress.bind(first_number), 0.0, 1.0, duration)
		tween.tween_method(_set_number_progress.bind(second_number), 0.0, 1.0, duration)
		await tween.finished
	else:
		_set_collision_progress(1.0, first_id, second_id, direction, flash)
		_set_number_progress(1.0, first_number)
		_set_number_progress(1.0, second_number)
		await get_tree().process_frame
	_impact_flashes.erase(flash)
	_floating_numbers.erase(first_number)
	_floating_numbers.erase(second_number)
	first_animation.complete()
	second_animation.complete()
	queue_redraw()


func _set_collision_progress(progress: float, first_id: StringName, second_id: StringName, direction: Vector2i, flash: Dictionary) -> void:
	var first_animation: UnitAnimationState = _ensure_animation(first_id)
	var second_animation: UnitAnimationState = _ensure_animation(second_id)
	first_animation.progress = progress
	second_animation.progress = progress
	var impact := sin(progress * PI)
	var shake := sin(progress * PI * 8.0) * (1.0 - progress)
	var push := Vector2(direction) * _cell_size() * (0.10 * impact + 0.035 * shake)
	first_animation.offset = push
	second_animation.offset = -push
	first_animation.rotation = 0.08 * shake
	second_animation.rotation = -0.08 * shake
	first_animation.tint = Color.WHITE.lerp(COLOR_COLLISION, impact * 0.62)
	second_animation.tint = Color.WHITE.lerp(COLOR_COLLISION, impact * 0.62)
	flash.intensity = impact
	queue_redraw()


func _set_number_progress(progress: float, number: Dictionary) -> void:
	number.rise = -_cell_size() * 0.34 * progress
	number.alpha = 1.0 if progress < 0.58 else 1.0 - (progress - 0.58) / 0.42
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
	var actor_id := event.actor_id
	if not _display_units.has(actor_id):
		await _wait(0.18, speed)
		return
	var animation: UnitAnimationState = _ensure_animation(actor_id)
	animation.begin(UnitAnimationState.DEATH)
	var duration := _scaled_duration(0.36, speed)
	if duration > 0.0:
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(Tween.EASE_IN)
		tween.tween_method(_set_death_progress.bind(actor_id), 0.0, 1.0, duration)
		await tween.finished
	else:
		_set_death_progress(1.0, actor_id)
		await get_tree().process_frame
	var entry: Dictionary = _display_units[actor_id]
	entry.active = false
	_display_units[actor_id] = entry
	animation.complete(true)
	queue_redraw()


func _set_death_progress(progress: float, actor_id: StringName) -> void:
	var animation: UnitAnimationState = _ensure_animation(actor_id)
	animation.progress = progress
	animation.opacity = clampf(1.0 - progress * 1.08, 0.0, 1.0)
	animation.scale = Vector2(1.0 + progress * 0.34, 1.0 - progress * 0.72)
	animation.offset.y = _cell_size() * 0.18 * progress
	animation.rotation = sin(progress * PI) * 0.10
	animation.tint = Color.WHITE.lerp(COLOR_HIT, progress * 0.64)
	queue_redraw()


func _play_crystallize(event: BattleEvent, speed: float) -> void:
	var actor_id := event.actor_id
	if not _display_units.has(actor_id):
		await _wait(0.28, speed)
		return
	var animation: UnitAnimationState = _ensure_animation(actor_id)
	animation.begin(UnitAnimationState.CRYSTALLIZE)
	var flash := _add_impact_flash(_unit_screen_position(actor_id), COLOR_CRYSTALLIZE)
	var duration := _scaled_duration(0.48, speed)
	if duration > 0.0:
		var tween := create_tween()
		tween.tween_method(_set_crystallize_progress.bind(actor_id, flash), 0.0, 1.0, duration)
		await tween.finished
	else:
		_set_crystallize_progress(1.0, actor_id, flash)
		await get_tree().process_frame
	_impact_flashes.erase(flash)
	animation.complete()
	queue_redraw()


func _set_crystallize_progress(progress: float, actor_id: StringName, flash: Dictionary) -> void:
	var animation: UnitAnimationState = _ensure_animation(actor_id)
	animation.progress = progress
	var pulse := sin(progress * PI * 3.0) * (1.0 - progress * 0.45)
	animation.scale = Vector2(1.0 + pulse * 0.07, 1.0 - pulse * 0.04)
	animation.offset.y = -sin(progress * PI) * _cell_size() * 0.07
	animation.tint = Color.WHITE.lerp(COLOR_CRYSTALLIZE, sin(progress * PI) * 0.76)
	flash.intensity = sin(progress * PI)
	queue_redraw()


func _apply_timeline_reset(payload: Dictionary) -> void:
	_display_units.clear()
	_animated_positions.clear()
	_unit_animations.clear()
	_floating_numbers.clear()
	_impact_flashes.clear()
	_clear_all_previews()
	var units: Dictionary = payload.get("units", {})
	for unit_id in units.keys():
		var entry: Dictionary = VariantCodec.deep_copy(units[unit_id])
		entry.is_ghost = false
		_display_units[unit_id] = entry
		_ensure_animation(unit_id)
	var ghosts: Dictionary = payload.get("ghost_positions", {})
	for ghost_id in ghosts.keys():
		_display_units[ghost_id] = _ghost_entry(ghosts[ghost_id])
		_ensure_animation(ghost_id)
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


func _ensure_animation(unit_id: StringName) -> UnitAnimationState:
	if not _unit_animations.has(unit_id):
		_unit_animations[unit_id] = UnitAnimationStateScript.new()
	return _unit_animations[unit_id]


func _unit_screen_position(unit_id: StringName) -> Vector2:
	if not _display_units.has(unit_id):
		return Vector2.ZERO
	var entry: Dictionary = _display_units[unit_id]
	return _animated_positions.get(unit_id, grid_to_local(entry.get("position", Vector2i.ZERO)))


func _add_impact_flash(position: Vector2, color: Color) -> Dictionary:
	var flash := {
		"position": position,
		"color": color,
		"intensity": 0.0,
	}
	_impact_flashes.append(flash)
	return flash


func _add_floating_number(position: Vector2, text: String, color: Color) -> Dictionary:
	var number := {
		"position": position,
		"text": text,
		"color": color,
		"rise": 0.0,
		"alpha": 1.0,
	}
	_floating_numbers.append(number)
	return number


func _cardinal_direction(origin: Vector2i, target: Vector2i) -> Vector2i:
	return _cardinal_direction_from_vector(Vector2(target - origin))


func _cardinal_direction_from_vector(delta: Vector2) -> Vector2i:
	if absf(delta.x) >= absf(delta.y) and not is_zero_approx(delta.x):
		return Vector2i(signi(roundi(delta.x)), 0)
	if not is_zero_approx(delta.y):
		return Vector2i(0, signi(roundi(delta.y)))
	return Vector2i.ZERO


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
