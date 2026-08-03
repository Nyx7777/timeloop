class_name BattleScreen
extends Control

const BattleBoardViewScript := preload("res://presentation/battle/battle_board_view.gd")
const BattleEventPlayerScript := preload("res://presentation/battle/battle_event_player.gd")
const DisplacementQueryScript := preload("res://core/queries/displacement_query.gd")
const LEVELS := [
	{"label": "1 · 留下第一个自己", "path": "res://content/levels/first_echo.tres", "number": 1},
	{"label": "2 · 双线交错", "path": "res://content/levels/crossed_paths.tres", "number": 2},
	{"label": "3 · 紫色交火区", "path": "res://content/levels/purple_crossfire.tres", "number": 3},
	{"label": "4 · 推力校准", "path": "res://content/levels/push_calibration.tres", "number": 4},
	{"label": "5 · 历史冲撞", "path": "res://content/levels/collision_course.tres", "number": 5},
	{"label": "6 · 坠落时间线", "path": "res://content/levels/falling_timeline.tres", "number": 6},
]

var _session: BattleSession
var _board: Control
var _event_player: Node
var _mission_label: Label
var _level_option: OptionButton
var _state_label: Label
var _instruction_label: Label
var _end_turn_button: Button
var _crystallize_button: Button
var _next_timeline_button: Button
var _timeline_overlay: Control
var _timeline_title_label: Label
var _timeline_summary_label: Label
var _timeline_explanation_label: Label
var _restart_button: Button
var _speed_option: OptionButton
var _log: RichTextLabel
var _busy := false


func _ready() -> void:
	_build_interface()
	_start_battle()


func _build_interface() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("#0b1120")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var left_panel := PanelContainer.new()
	left_panel.anchor_left = 0.0
	left_panel.anchor_top = 0.0
	left_panel.anchor_right = 0.25
	left_panel.anchor_bottom = 1.0
	left_panel.offset_left = 18.0
	left_panel.offset_top = 18.0
	left_panel.offset_right = -8.0
	left_panel.offset_bottom = -18.0
	left_panel.add_theme_stylebox_override("panel", _panel_style(Color("#111b2e")))
	add_child(left_panel)

	var sidebar_scroll := ScrollContainer.new()
	sidebar_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sidebar_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	sidebar_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_child(sidebar_scroll)

	var sidebar := VBoxContainer.new()
	sidebar.add_theme_constant_override("separation", 9)
	sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar_scroll.add_child(sidebar)

	var title := Label.new()
	title.text = "TIMELOOP · 战斗纵切"
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", Color("#9eeeff"))
	sidebar.add_child(title)

	_level_option = OptionButton.new()
	for level_data in LEVELS:
		_level_option.add_item(level_data.label)
	_level_option.select(0)
	_level_option.item_selected.connect(_on_level_selected)
	sidebar.add_child(_level_option)

	_mission_label = Label.new()
	_mission_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mission_label.add_theme_font_size_override("font_size", 16)
	sidebar.add_child(_mission_label)

	_state_label = Label.new()
	_state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_state_label.add_theme_color_override("font_color", Color("#cbd9ef"))
	sidebar.add_child(_state_label)

	_instruction_label = Label.new()
	_instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_instruction_label.add_theme_color_override("font_color", Color("#9fb0c9"))
	sidebar.add_child(_instruction_label)

	_end_turn_button = Button.new()
	_end_turn_button.text = "结束回合"
	_end_turn_button.custom_minimum_size.y = 44.0
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	sidebar.add_child(_end_turn_button)

	_crystallize_button = Button.new()
	_crystallize_button.text = "固化当前时间线"
	_crystallize_button.custom_minimum_size.y = 40.0
	_crystallize_button.pressed.connect(_on_crystallize_pressed)
	sidebar.add_child(_crystallize_button)

	_restart_button = Button.new()
	_restart_button.text = "重开战斗"
	_restart_button.custom_minimum_size.y = 40.0
	_restart_button.pressed.connect(_on_restart_pressed)
	sidebar.add_child(_restart_button)

	var speed_row := HBoxContainer.new()
	var speed_label := Label.new()
	speed_label.text = "播放速度"
	speed_row.add_child(speed_label)
	_speed_option = OptionButton.new()
	_speed_option.add_item("1×", 0)
	_speed_option.add_item("3×", 1)
	_speed_option.add_item("瞬时", 2)
	_speed_option.item_selected.connect(_on_speed_selected)
	speed_row.add_child(_speed_option)
	sidebar.add_child(speed_row)

	var hint := Label.new()
	hint.text = "绿色移动 · 红格攻击\n黄→击退 · 紫↓坠洞\n紫 G! 分身火线 · 红 ! 敌攻\n橙框敌移 · 洋红环扰动\nP 本体　E 敌人　G 分身"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color("#7386a6"))
	sidebar.add_child(hint)

	_board = BattleBoardViewScript.new()
	_board.anchor_left = 0.25
	_board.anchor_top = 0.0
	_board.anchor_right = 1.0
	_board.anchor_bottom = 0.72
	_board.offset_left = 0.0
	_board.offset_top = 8.0
	_board.offset_right = -12.0
	_board.offset_bottom = -4.0
	_board.cell_clicked.connect(_on_board_cell_clicked)
	add_child(_board)

	var log_panel := PanelContainer.new()
	log_panel.anchor_left = 0.25
	log_panel.anchor_top = 0.72
	log_panel.anchor_right = 1.0
	log_panel.anchor_bottom = 1.0
	log_panel.offset_left = 8.0
	log_panel.offset_top = 4.0
	log_panel.offset_right = -18.0
	log_panel.offset_bottom = -18.0
	log_panel.add_theme_stylebox_override("panel", _panel_style(Color("#0e1728")))
	add_child(log_panel)

	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.fit_content = false
	_log.add_theme_font_size_override("normal_font_size", 14)
	log_panel.add_child(_log)

	_event_player = BattleEventPlayerScript.new()
	_event_player.event_finished.connect(_on_event_finished)
	add_child(_event_player)
	_build_timeline_overlay()


func _build_timeline_overlay() -> void:
	_timeline_overlay = Control.new()
	_timeline_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_timeline_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_timeline_overlay.visible = false
	add_child(_timeline_overlay)

	var scrim := ColorRect.new()
	scrim.color = Color(0.02, 0.04, 0.09, 0.76)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_timeline_overlay.add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_timeline_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(430.0, 250.0)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#151d35")))
	center.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	panel.add_child(content)

	_timeline_title_label = Label.new()
	_timeline_title_label.text = "时间线已记录"
	_timeline_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timeline_title_label.add_theme_font_size_override("font_size", 27)
	_timeline_title_label.add_theme_color_override("font_color", Color("#c69aff"))
	content.add_child(_timeline_title_label)

	_timeline_summary_label = Label.new()
	_timeline_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timeline_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_timeline_summary_label.add_theme_font_size_override("font_size", 17)
	_timeline_summary_label.add_theme_color_override("font_color", Color("#cbd9ef"))
	content.add_child(_timeline_summary_label)

	_timeline_explanation_label = Label.new()
	_timeline_explanation_label.text = "这一条时间线的行动已经成为事实。\n下一次开始时，它会作为分身自动重演。"
	_timeline_explanation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timeline_explanation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_timeline_explanation_label.add_theme_color_override("font_color", Color("#91a3c2"))
	content.add_child(_timeline_explanation_label)

	_next_timeline_button = Button.new()
	_next_timeline_button.text = "开始下一条时间线"
	_next_timeline_button.custom_minimum_size.y = 48.0
	_next_timeline_button.pressed.connect(_on_next_timeline_pressed)
	content.add_child(_next_timeline_button)


func _start_battle() -> void:
	var selected_index := _level_option.selected
	var level_data: Dictionary = LEVELS[selected_index]
	var level := load(level_data.path) as LevelDefinition
	var state := BattleStateFactory.create_from_level(level, 20260802)
	_session = BattleSession.new(state)
	_board.sync_from_state(_session.state)
	_mission_label.text = "%d. %s\n%s\n%s" % [level_data.number, level.display_name, level.briefing, level.hint]
	_log.clear()
	_append_log("[color=#9eeeff]%s开始。移动到敌人旁边并攻击。[/color]" % level.display_name)
	_refresh_interface()


func _on_level_selected(_index: int) -> void:
	if not _busy:
		_start_battle()


func _on_board_cell_clicked(cell: Vector2i) -> void:
	if _busy or _session.state.phase != BattlePhase.PLAYER_INPUT:
		return
	var player := _session.state.get_unit(_session.state.player_id)
	if player == null:
		return
	var enemy := _find_enemy_at(cell)
	if enemy != null and not player.has_acted and _manhattan(player.position, cell) == 1:
		_submit(BattleCommand.attack(player.unit_id, cell))
	elif not player.has_moved and _get_reachable_cells().has(cell):
		_submit(BattleCommand.move(player.unit_id, cell))
	else:
		_append_log("[color=#778ba8]这个格子当前不能选择。[/color]")


func _on_end_turn_pressed() -> void:
	if not _busy:
		_submit(BattleCommand.end_turn(_session.state.player_id))


func _on_crystallize_pressed() -> void:
	if not _busy:
		_submit(BattleCommand.crystallize(_session.state.player_id))


func _on_next_timeline_pressed() -> void:
	if not _busy:
		_submit(BattleCommand.start_next_timeline())


func _on_restart_pressed() -> void:
	if _busy:
		return
	_start_battle()


func _on_speed_selected(index: int) -> void:
	match index:
		0:
			_event_player.playback_speed = 1.0
		1:
			_event_player.playback_speed = 3.0
		_:
			_event_player.playback_speed = 0.0


func _submit(command: BattleCommand) -> void:
	if _busy:
		return
	var result := _session.submit(command)
	if not result.accepted:
		_append_log("[color=#ff7780]操作失败：%s[/color]" % result.reason)
		_refresh_interface()
		return
	_busy = true
	_refresh_interface()
	await _event_player.play(result.events, _board)
	_board.sync_from_state(_session.state)
	_busy = false
	_refresh_interface()


func set_instant_playback_for_test() -> void:
	_event_player.playback_speed = 0.0


func submit_command_for_test(command: BattleCommand) -> void:
	await _submit(command)


func select_level_for_test(index: int) -> void:
	_level_option.select(index)
	_start_battle()


func get_state_snapshot_for_test() -> Dictionary:
	return _session.state.to_dict()


func get_board_preview_snapshot_for_test() -> Dictionary:
	return _board.get_preview_snapshot_for_test()


func get_ui_snapshot_for_test() -> Dictionary:
	return {
		"instruction": _instruction_label.text,
		"next_timeline_visible": _timeline_overlay.visible,
		"end_turn_disabled": _end_turn_button.disabled,
		"crystallize_visible": _crystallize_button.visible,
		"crystallize_disabled": _crystallize_button.disabled,
		"busy": _busy,
	}


func _refresh_interface() -> void:
	if _session == null or _session.state == null:
		return
	var state := _session.state
	var player := state.get_unit(state.player_id)
	var hp_text := "—" if player == null else "%d/%d" % [player.hp, player.max_hp]
	_state_label.text = "时间线 T%d　回合 %d\n剩余命数 %d　HP %s\n%s · %s" % [
		state.timeline_index,
		state.turn_index,
		state.lives_left,
		hp_text,
		_time_state_text(state.time_state),
		_phase_text(state.phase),
	]

	var player_input := state.phase == BattlePhase.PLAYER_INPUT and not _busy
	_end_turn_button.disabled = not player_input
	_crystallize_button.visible = bool(state.rules.get("crystallize_enabled", false))
	_crystallize_button.disabled = not player_input or state.lives_left <= 1
	_timeline_overlay.visible = state.phase == BattlePhase.TIMELINE_TRANSITION and not _busy
	_next_timeline_button.disabled = _busy
	_timeline_summary_label.text = "T%d 结束　·　剩余命数 %d" % [state.timeline_index, state.lives_left]
	var last_end_reason: StringName = &""
	if not state.timeline_recordings.is_empty():
		last_end_reason = state.timeline_recordings[state.timeline_recordings.size() - 1].get("end_reason", &"")
	_timeline_title_label.text = "固化完成" if last_end_reason == &"crystallized" else "时间线已记录"
	_timeline_explanation_label.text = "当前行动已主动写入录像。\n下一次开始时，它会作为分身自动重演。" if last_end_reason == &"crystallized" else "这一条时间线的行动已经成为事实。\n下一次开始时，它会作为分身自动重演。"
	_restart_button.disabled = _busy
	_level_option.disabled = _busy

	if state.phase == BattlePhase.TIMELINE_TRANSITION:
		_instruction_label.text = "当前时间线已经结束。过去的行动已成为分身。"
	elif state.phase == BattlePhase.BATTLE_OVER:
		_instruction_label.text = "战斗胜利！" if state.battle_outcome == &"victory" else "战斗失败。"
	elif _busy:
		_instruction_label.text = "时间正在结算……"
	elif player != null and player.has_moved:
		_instruction_label.text = "选择相邻红色敌人攻击，或结束回合。"
	else:
		_instruction_label.text = "点击绿色格移动，也可以直接攻击或结束回合。"

	var reachable: Array[Vector2i] = []
	var attackable: Array[Vector2i] = []
	var push_previews: Array = []
	if player_input and player != null:
		if not player.has_moved:
			reachable = _get_reachable_cells()
		if not player.has_acted:
			attackable = _get_attackable_cells(player)
			push_previews = _get_push_previews(player, attackable)
	_board.set_interaction(reachable, attackable, player_input, push_previews)


func _get_reachable_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var state := _session.state
	var player := state.get_unit(state.player_id)
	if player == null:
		return cells
	for y in range(state.board_size.y):
		for x in range(state.board_size.x):
			var cell := Vector2i(x, y)
			if not GridQuery.find_path(state, player.position, cell, player.move_range, player.unit_id).is_empty():
				cells.append(cell)
	return cells


func _get_attackable_cells(player: UnitState) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for unit_id in _session.state.unit_order:
		var unit := _session.state.get_unit(unit_id)
		if unit != null and unit.active and unit.team == &"enemy" and _manhattan(player.position, unit.position) == 1:
			cells.append(unit.position)
	return cells


func _get_push_previews(player: UnitState, attackable: Array[Vector2i]) -> Array:
	var previews: Array = []
	if not bool(_session.state.rules.get("push_enabled", false)):
		return previews
	for target_cell in attackable:
		var target := _find_enemy_at(target_cell)
		if target == null or target.hp <= player.attack_damage:
			continue
		var preview: Dictionary = DisplacementQueryScript.evaluate_knockback(_session.state, target, target_cell - player.position)
		preview["target_cell"] = target_cell
		preview["display_cell"] = preview.to if GridQuery.is_in_bounds(_session.state, preview.to) else target_cell
		previews.append(preview)
	return previews


func _find_enemy_at(cell: Vector2i) -> UnitState:
	for unit_id in _session.state.unit_order:
		var unit := _session.state.get_unit(unit_id)
		if unit != null and unit.active and unit.team == &"enemy" and unit.position == cell:
			return unit
	return null


func _on_event_finished(event: BattleEvent) -> void:
	match event.event_type:
		&"unit_moved":
			var label := "分身" if bool(event.payload.get("is_ghost", false)) else String(event.actor_id)
			_append_log("%s 移动到 %s" % [label, event.payload.get("to", Vector2i.ZERO)])
		&"unit_pushed":
			var outcome: StringName = event.payload.get("outcome", &"moved")
			if outcome == &"time_hole":
				_append_log("[color=#ff7780]%s 被推入时间空洞。[/color]" % event.actor_id)
			else:
				_append_log("[color=#f2b86b]%s 被推到 %s。[/color]" % [event.actor_id, event.payload.get("to", Vector2i.ZERO)])
		&"push_blocked":
			_append_log("%s 的击退被阻挡。" % event.actor_id)
		&"enemy_disturbed":
			_append_log("[color=#ff8fc7]%s 发生扰动，将从回合 %d 开始清醒。[/color]" % [event.actor_id, int(event.payload.get("wake_turn", 0))])
		&"attack_performed":
			_append_log("%s 攻击 %s" % [event.actor_id, event.payload.get("target_cell", Vector2i.ZERO)])
		&"damage_applied":
			_append_log("造成 %d 点伤害" % int(event.payload.get("damage", 0)))
		&"unit_died":
			_append_log("[color=#ff7780]%s 被击倒。[/color]" % event.actor_id)
		&"timeline_ended":
			var reason: StringName = event.payload.get("end_reason", &"death")
			var label := "已主动固化" if reason == &"crystallized" else "已记录为分身"
			_append_log("[color=#b993ff]T%d %s。[/color]" % [int(event.payload.get("timeline_index", 0)), label])
		&"timeline_started":
			_append_log("[color=#b993ff]T%d 开始，旧时间线正在重演。[/color]" % int(event.payload.get("timeline_index", 0)))
		&"battle_won":
			_append_log("[color=#73f0b5]时间编排成功，战斗胜利！[/color]")
		&"battle_lost":
			_append_log("[color=#ff7780]所有命数耗尽，战斗失败。[/color]")


func _append_log(text: String) -> void:
	_log.append_text(text + "\n")


func _panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("#283a57")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16.0
	style.content_margin_top = 16.0
	style.content_margin_right = 16.0
	style.content_margin_bottom = 16.0
	return style


func _time_state_text(time_state: StringName) -> String:
	if time_state == &"known":
		return "已知时间"
	if time_state == &"disturbed":
		return "扰动时间"
	return "未知时间"


func _phase_text(phase: StringName) -> String:
	match phase:
		BattlePhase.PLAYER_INPUT:
			return "本体行动"
		BattlePhase.GHOST_PLAYBACK:
			return "分身重演"
		BattlePhase.ENEMY_EXECUTION:
			return "敌方行动"
		BattlePhase.TIMELINE_TRANSITION:
			return "时间线结束"
		BattlePhase.BATTLE_OVER:
			return "战斗结束"
		_:
			return String(phase)


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
