class_name BattleScreen
extends Control

const BattleBoardViewScript := preload("res://presentation/battle/battle_board_view.gd")
const BattleEventPlayerScript := preload("res://presentation/battle/battle_event_player.gd")
const DisplacementQueryScript := preload("res://core/queries/displacement_query.gd")
const HUD_PANEL_TEXTURE := preload("res://assets/ui/m42c/hud_panel_top.png")
const HINT_BAR_TEXTURE := preload("res://assets/ui/m42c/hint_bar_bg.png")
const BUTTON_MOVE_TEXTURE := preload("res://assets/ui/m42c/button_move_9patch.png")
const BUTTON_ATTACK_TEXTURE := preload("res://assets/ui/m42c/button_attack_9patch.png")
const BUTTON_CRYSTALLIZE_TEXTURE := preload("res://assets/ui/m42c/button_crystallize_9patch.png")
const BUTTON_END_TURN_TEXTURE := preload("res://assets/ui/m42c/button_endturn_9patch.png")
const SEQUENCE_ACTIVE_TEXTURE := preload("res://assets/ui/m42c/sequence_frame_active.png")
const SEQUENCE_INACTIVE_TEXTURE := preload("res://assets/ui/m42c/sequence_frame_inactive.png")

const LEVELS := [
	{"label": "1 · 留下第一个自己", "path": "res://content/levels/first_echo.tres", "number": 1},
	{"label": "2 · 双线交错", "path": "res://content/levels/crossed_paths.tres", "number": 2},
	{"label": "3 · 紫色交火区", "path": "res://content/levels/purple_crossfire.tres", "number": 3},
	{"label": "4 · 推力校准", "path": "res://content/levels/push_calibration.tres", "number": 4},
	{"label": "5 · 历史冲撞", "path": "res://content/levels/collision_course.tres", "number": 5},
	{"label": "6 · 坠落时间线", "path": "res://content/levels/falling_timeline.tres", "number": 6},
]

const COLOR_BACKGROUND := Color("#070b16")
const COLOR_PANEL := Color("#101829")
const COLOR_PANEL_ALT := Color("#151d31")
const COLOR_CYAN := Color("#55e8ff")
const COLOR_PURPLE := Color("#b47cff")
const COLOR_RED := Color("#ff5d68")
const COLOR_GOLD := Color("#e9b95f")
const COLOR_MUTED := Color("#91a3c2")

var _session: BattleSession
var _board: Control
var _event_player: Node

var _timeline_label: Label
var _round_label: Label
var _time_label: Label
var _lives_label: Label
var _sequence_row: HBoxContainer

var _mission_label: Label
var _level_option: OptionButton
var _instruction_label: Label
var _move_button: Button
var _attack_button: Button
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
var _debug_overlay: Control

var _busy := false
var _action_mode: StringName = &"smart"
var _active_actor: StringName = &""


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_interface()
	_start_battle()


func _build_interface() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.color = COLOR_BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var edge_glow := PanelContainer.new()
	edge_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	edge_glow.offset_left = 4.0
	edge_glow.offset_top = 4.0
	edge_glow.offset_right = -4.0
	edge_glow.offset_bottom = -4.0
	edge_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	edge_glow.add_theme_stylebox_override("panel", _panel_style(Color("#090d1a"), Color("#4d2575"), 2, 10, 0))
	add_child(edge_glow)

	var safe_margin := MarginContainer.new()
	safe_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		safe_margin.add_theme_constant_override(side, 8)
	add_child(safe_margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	safe_margin.add_child(layout)

	_build_top_hud(layout)
	_build_sequence_bar(layout)
	_build_board(layout)
	_build_action_area(layout)

	_event_player = BattleEventPlayerScript.new()
	_event_player.event_started.connect(_on_event_started)
	_event_player.event_finished.connect(_on_event_finished)
	add_child(_event_player)

	_build_debug_overlay()
	_build_timeline_overlay()


func _build_top_hud(parent: VBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 48.0
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _texture_style(HUD_PANEL_TEXTURE, 8.0, 8.0))
	parent.add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)

	_timeline_label = _hud_label("T1/2", COLOR_CYAN, HORIZONTAL_ALIGNMENT_LEFT)
	_timeline_label.custom_minimum_size.x = 72.0
	row.add_child(_timeline_label)

	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", -2)
	row.add_child(center)

	_round_label = _hud_label("回合 1", Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	center.add_child(_round_label)
	_time_label = _hud_label("未知时间", COLOR_MUTED, HORIZONTAL_ALIGNMENT_CENTER, 12)
	center.add_child(_time_label)

	_lives_label = _hud_label("◆◆", COLOR_CYAN, HORIZONTAL_ALIGNMENT_RIGHT)
	_lives_label.custom_minimum_size.x = 66.0
	row.add_child(_lives_label)

	var debug_button := Button.new()
	debug_button.text = "≡"
	debug_button.tooltip_text = "关卡与调试菜单"
	debug_button.custom_minimum_size = Vector2(34.0, 34.0)
	debug_button.focus_mode = Control.FOCUS_NONE
	debug_button.pressed.connect(_open_debug_overlay)
	row.add_child(debug_button)


func _build_sequence_bar(parent: VBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 42.0
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#0b1020"), Color("#28213f"), 1, 7, 4))
	parent.add_child(panel)

	var center := CenterContainer.new()
	panel.add_child(center)
	_sequence_row = HBoxContainer.new()
	_sequence_row.add_theme_constant_override("separation", 4)
	center.add_child(_sequence_row)


func _build_board(parent: VBoxContainer) -> void:
	var board_panel := PanelContainer.new()
	board_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_panel.custom_minimum_size.y = 420.0
	board_panel.add_theme_stylebox_override("panel", _panel_style(Color("#0a0f1b"), Color("#201936"), 1, 10, 3))
	parent.add_child(board_panel)

	_board = BattleBoardViewScript.new()
	_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board.cell_clicked.connect(_on_board_cell_clicked)
	board_panel.add_child(_board)


func _build_action_area(parent: VBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 174.0
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#0d1423"), Color("#33254e"), 1, 10, 8))
	parent.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 7)
	panel.add_child(content)

	var hint_panel := PanelContainer.new()
	hint_panel.custom_minimum_size.y = 34.0
	hint_panel.add_theme_stylebox_override("panel", _texture_style(HINT_BAR_TEXTURE, 7.0, 5.0))
	content.add_child(hint_panel)

	_instruction_label = Label.new()
	_instruction_label.custom_minimum_size.y = 34.0
	_instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instruction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_instruction_label.add_theme_font_size_override("font_size", 13)
	_instruction_label.add_theme_color_override("font_color", Color("#d7e5f7"))
	hint_panel.add_child(_instruction_label)

	var actions := HBoxContainer.new()
	actions.size_flags_vertical = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("separation", 6)
	content.add_child(actions)

	_move_button = _action_button("↕\n移动", COLOR_CYAN, BUTTON_MOVE_TEXTURE)
	_move_button.toggle_mode = true
	_move_button.pressed.connect(_on_move_pressed)
	actions.add_child(_move_button)

	_attack_button = _action_button("⚔\n攻击", COLOR_RED, BUTTON_ATTACK_TEXTURE)
	_attack_button.toggle_mode = true
	_attack_button.pressed.connect(_on_attack_pressed)
	actions.add_child(_attack_button)

	_crystallize_button = _action_button("◆\n固化", COLOR_PURPLE, BUTTON_CRYSTALLIZE_TEXTURE)
	_crystallize_button.pressed.connect(_on_crystallize_pressed)
	actions.add_child(_crystallize_button)

	_end_turn_button = _action_button("⌛\n结束", COLOR_GOLD, BUTTON_END_TURN_TEXTURE)
	_end_turn_button.pressed.connect(_on_end_turn_pressed)
	actions.add_child(_end_turn_button)


func _build_debug_overlay() -> void:
	_debug_overlay = Control.new()
	_debug_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_debug_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_debug_overlay.visible = false
	add_child(_debug_overlay)

	var scrim := ColorRect.new()
	scrim.color = Color(0.01, 0.02, 0.05, 0.86)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_debug_overlay.add_child(scrim)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.06
	panel.anchor_top = 0.08
	panel.anchor_right = 0.94
	panel.anchor_bottom = 0.92
	panel.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL_ALT, Color("#42637c"), 2, 12, 14))
	_debug_overlay.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)

	var title_row := HBoxContainer.new()
	content.add_child(title_row)
	var title := Label.new()
	title.text = "试玩工具"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", COLOR_CYAN)
	title_row.add_child(title)
	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.pressed.connect(_close_debug_overlay)
	title_row.add_child(close_button)

	_level_option = OptionButton.new()
	for level_data in LEVELS:
		_level_option.add_item(level_data.label)
	_level_option.select(0)
	_level_option.item_selected.connect(_on_level_selected)
	content.add_child(_level_option)

	_mission_label = Label.new()
	_mission_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mission_label.add_theme_font_size_override("font_size", 13)
	_mission_label.add_theme_color_override("font_color", Color("#cbd9ef"))
	content.add_child(_mission_label)

	var tool_row := HBoxContainer.new()
	tool_row.add_theme_constant_override("separation", 8)
	content.add_child(tool_row)

	_restart_button = Button.new()
	_restart_button.text = "重开战斗"
	_restart_button.custom_minimum_size.y = 44.0
	_restart_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_restart_button.pressed.connect(_on_restart_pressed)
	tool_row.add_child(_restart_button)

	_speed_option = OptionButton.new()
	_speed_option.custom_minimum_size.y = 44.0
	_speed_option.add_item("1×", 0)
	_speed_option.add_item("3×", 1)
	_speed_option.add_item("瞬时", 2)
	_speed_option.item_selected.connect(_on_speed_selected)
	tool_row.add_child(_speed_option)

	var log_title := Label.new()
	log_title.text = "战斗日志"
	log_title.add_theme_color_override("font_color", COLOR_MUTED)
	content.add_child(log_title)

	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.fit_content = false
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_font_size_override("normal_font_size", 13)
	content.add_child(_log)


func _build_timeline_overlay() -> void:
	_timeline_overlay = Control.new()
	_timeline_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_timeline_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_timeline_overlay.visible = false
	add_child(_timeline_overlay)

	var scrim := ColorRect.new()
	scrim.color = Color(0.02, 0.04, 0.09, 0.82)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_timeline_overlay.add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_timeline_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(330.0, 238.0)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#151d35"), Color("#744ca8"), 2, 12, 18))
	center.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	panel.add_child(content)

	_timeline_title_label = Label.new()
	_timeline_title_label.text = "时间线已记录"
	_timeline_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timeline_title_label.add_theme_font_size_override("font_size", 24)
	_timeline_title_label.add_theme_color_override("font_color", Color("#c69aff"))
	content.add_child(_timeline_title_label)

	_timeline_summary_label = Label.new()
	_timeline_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timeline_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_timeline_summary_label.add_theme_font_size_override("font_size", 16)
	_timeline_summary_label.add_theme_color_override("font_color", Color("#cbd9ef"))
	content.add_child(_timeline_summary_label)

	_timeline_explanation_label = Label.new()
	_timeline_explanation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timeline_explanation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_timeline_explanation_label.add_theme_color_override("font_color", COLOR_MUTED)
	content.add_child(_timeline_explanation_label)

	_next_timeline_button = Button.new()
	_next_timeline_button.text = "开始下一条时间线"
	_next_timeline_button.custom_minimum_size.y = 52.0
	_next_timeline_button.pressed.connect(_on_next_timeline_pressed)
	content.add_child(_next_timeline_button)


func _start_battle() -> void:
	var selected_index := _level_option.selected
	var level_data: Dictionary = LEVELS[selected_index]
	var level := load(level_data.path) as LevelDefinition
	var state := BattleStateFactory.create_from_level(level, 20260802)
	_session = BattleSession.new(state)
	_action_mode = &"smart"
	_active_actor = state.player_id
	_board.sync_from_state(_session.state)
	_mission_label.text = "%d. %s\n%s\n%s" % [level_data.number, level.display_name, level.briefing, level.hint]
	_log.clear()
	_append_log("[color=#9eeeff]%s开始。移动到敌人旁边并攻击。[/color]" % level.display_name)
	_refresh_interface()


func _on_level_selected(_index: int) -> void:
	if not _busy:
		_start_battle()


func _on_move_pressed() -> void:
	if _move_button.disabled:
		return
	_action_mode = &"smart" if _action_mode == &"move" else &"move"
	_refresh_interface()


func _on_attack_pressed() -> void:
	if _attack_button.disabled:
		return
	_action_mode = &"smart" if _action_mode == &"attack" else &"attack"
	_refresh_interface()


func _on_board_cell_clicked(cell: Vector2i) -> void:
	if _busy or _session.state.phase != BattlePhase.PLAYER_INPUT:
		return
	var player := _session.state.get_unit(_session.state.player_id)
	if player == null:
		return
	var enemy := _find_enemy_at(cell)
	var can_attack := enemy != null and not player.has_acted and _manhattan(player.position, cell) == 1
	var can_move := not player.has_moved and _get_reachable_cells().has(cell)
	if _action_mode != &"move" and can_attack:
		_submit(BattleCommand.attack(player.unit_id, cell))
	elif _action_mode != &"attack" and can_move:
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
	_debug_overlay.visible = false


func _on_speed_selected(index: int) -> void:
	match index:
		0:
			_event_player.playback_speed = 1.0
		1:
			_event_player.playback_speed = 3.0
		_:
			_event_player.playback_speed = 0.0


func _open_debug_overlay() -> void:
	if not _busy:
		_debug_overlay.visible = true


func _close_debug_overlay() -> void:
	_debug_overlay.visible = false


func _submit(command: BattleCommand) -> void:
	if _busy:
		return
	var result := _session.submit(command)
	if not result.accepted:
		_append_log("[color=#ff7780]操作失败：%s[/color]" % result.reason)
		_refresh_interface()
		return
	_action_mode = &"smart"
	_busy = true
	_refresh_interface()
	await _event_player.play(result.events, _board)
	_board.sync_from_state(_session.state)
	_busy = false
	_active_actor = _session.state.player_id
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


func get_layout_snapshot_for_test() -> Dictionary:
	var board_layout: Dictionary = _board.get_layout_snapshot_for_test()
	return {
		"viewport_size": size,
		"logical_size": Vector2(
			float(ProjectSettings.get_setting("display/window/size/viewport_width", 0)),
			float(ProjectSettings.get_setting("display/window/size/viewport_height", 0))
		),
		"board_size": _board.size,
		"board_cell_size": board_layout.get("cell_size", 0.0),
		"board_rect": board_layout.get("board_rect", Rect2()),
		"action_button_count": 4,
		"action_button_height": _move_button.size.y,
		"sequence_count": _sequence_row.get_child_count(),
	}


func get_ui_snapshot_for_test() -> Dictionary:
	return {
		"instruction": _instruction_label.text,
		"next_timeline_visible": _timeline_overlay.visible,
		"end_turn_disabled": _end_turn_button.disabled,
		"crystallize_visible": _crystallize_button.visible,
		"crystallize_disabled": _crystallize_button.disabled,
		"move_disabled": _move_button.disabled,
		"attack_disabled": _attack_button.disabled,
		"busy": _busy,
	}


func _refresh_interface() -> void:
	if _session == null or _session.state == null:
		return
	var state := _session.state
	var player := state.get_unit(state.player_id)
	var total_lives := state.timeline_index + state.lives_left - 1
	_timeline_label.text = "T%d/%d" % [state.timeline_index, total_lives]
	_round_label.text = "回合 %d" % state.turn_index
	_time_label.text = _time_state_text(state.time_state)
	_time_label.add_theme_color_override("font_color", COLOR_GOLD if state.time_state == &"known" else (Color("#ff8fc7") if state.time_state == &"disturbed" else COLOR_MUTED))
	_lives_label.text = "◆".repeat(state.lives_left)
	_refresh_sequence_bar(state)

	var player_input := state.phase == BattlePhase.PLAYER_INPUT and not _busy
	var reachable: Array[Vector2i] = []
	var attackable: Array[Vector2i] = []
	var push_previews: Array = []
	if player_input and player != null:
		if not player.has_moved:
			reachable = _get_reachable_cells()
		if not player.has_acted:
			attackable = _get_attackable_cells(player)
			push_previews = _get_push_previews(player, attackable)

	_move_button.disabled = not player_input or player == null or player.has_moved or reachable.is_empty()
	_attack_button.disabled = not player_input or player == null or player.has_acted or attackable.is_empty()
	_end_turn_button.disabled = not player_input
	_crystallize_button.visible = true
	_crystallize_button.disabled = not player_input or not bool(state.rules.get("crystallize_enabled", false)) or state.lives_left <= 1
	_move_button.button_pressed = _action_mode == &"move" and not _move_button.disabled
	_attack_button.button_pressed = _action_mode == &"attack" and not _attack_button.disabled

	var visible_reachable: Array[Vector2i] = []
	var visible_attackable: Array[Vector2i] = []
	var visible_push_previews: Array = []
	if _action_mode != &"attack":
		visible_reachable.assign(reachable)
	if _action_mode != &"move":
		visible_attackable.assign(attackable)
		visible_push_previews = push_previews
	_board.set_interaction(visible_reachable, visible_attackable, player_input, visible_push_previews)

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
	elif _action_mode == &"move":
		_instruction_label.text = "选择青色格移动；再次点击移动可取消。"
	elif _action_mode == &"attack":
		_instruction_label.text = "选择红框敌人攻击；黄色标记为击退落点。"
	elif player != null and player.has_moved:
		_instruction_label.text = "选择相邻敌人攻击，或结束回合。"
	else:
		_instruction_label.text = "直接点格行动，也可先选择移动或攻击。"


func _refresh_sequence_bar(state: BattleState) -> void:
	for child in _sequence_row.get_children():
		_sequence_row.remove_child(child)
		child.queue_free()

	var ghost_ids: Array = state.ghost_positions.keys()
	ghost_ids.sort()
	for ghost_index in range(ghost_ids.size()):
		_sequence_row.add_child(_sequence_chip("G%d" % (ghost_index + 1), COLOR_PURPLE, ghost_ids[ghost_index] == _active_actor))

	var player_active := state.phase == BattlePhase.PLAYER_INPUT and not _busy
	_sequence_row.add_child(_sequence_chip("本体", COLOR_CYAN, player_active or _active_actor == state.player_id))

	var enemy_index := 0
	for unit_id in state.unit_order:
		var unit := state.get_unit(unit_id)
		if unit == null or not unit.active or unit.team != &"enemy":
			continue
		enemy_index += 1
		_sequence_row.add_child(_sequence_chip("E%d" % enemy_index, COLOR_RED, unit_id == _active_actor))


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


func _on_event_started(event: BattleEvent) -> void:
	if event.actor_id != &"":
		_active_actor = event.actor_id
		_refresh_sequence_bar(_session.state)


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
		&"units_collided":
			_append_log("[color=#ff9e64]%s 撞上 %s，双方各受到 %d 点碰撞伤害。[/color]" % [
				event.payload.get("first_unit_id", &""),
				event.payload.get("second_unit_id", &""),
				int(event.payload.get("damage", 1)),
			])
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


func _hud_label(text_value: String, color: Color, alignment: HorizontalAlignment, font_size := 18) -> Label:
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _action_button(text_value: String, accent: Color, texture: Texture2D) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(72.0, 92.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", accent.lightened(0.18))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color("#606a7d"))
	button.add_theme_stylebox_override("normal", _texture_style(texture, 10.0, 7.0))
	button.add_theme_stylebox_override("hover", _texture_style(texture, 10.0, 7.0, Color(1.18, 1.18, 1.18, 1.0)))
	button.add_theme_stylebox_override("pressed", _texture_style(texture, 10.0, 7.0, Color(0.70, 0.78, 0.88, 1.0)))
	button.add_theme_stylebox_override("disabled", _texture_style(texture, 10.0, 7.0, Color(0.34, 0.36, 0.42, 0.82)))
	return button


func _sequence_chip(text_value: String, accent: Color, active: bool) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2(42.0, 30.0)
	chip.add_theme_stylebox_override("panel", _texture_style(SEQUENCE_ACTIVE_TEXTURE if active else SEQUENCE_INACTIVE_TEXTURE, 8.0, 3.0))
	var label := Label.new()
	label.text = "▼ %s" % text_value if active else text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color.WHITE if active else accent.lightened(0.05))
	chip.add_child(label)
	return chip


func _texture_style(texture: Texture2D, texture_margin: float, content_margin: float, modulate := Color.WHITE) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = texture_margin
	style.texture_margin_top = texture_margin
	style.texture_margin_right = texture_margin
	style.texture_margin_bottom = texture_margin
	style.content_margin_left = content_margin
	style.content_margin_top = content_margin
	style.content_margin_right = content_margin
	style.content_margin_bottom = content_margin
	style.modulate_color = modulate
	return style


func _panel_style(color: Color, border_color := Color("#283a57"), border_width := 1, radius := 8, margin := 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin
	style.content_margin_top = margin
	style.content_margin_right = margin
	style.content_margin_bottom = margin
	return style


func _time_state_text(time_state: StringName) -> String:
	if time_state == &"known":
		return "已知时间"
	if time_state == &"disturbed":
		return "扰动时间"
	return "未知时间"


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
