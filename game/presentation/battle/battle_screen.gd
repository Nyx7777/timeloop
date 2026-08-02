class_name BattleScreen
extends Control

const BattleBoardViewScript := preload("res://presentation/battle/battle_board_view.gd")
const BattleEventPlayerScript := preload("res://presentation/battle/battle_event_player.gd")

var _session: BattleSession
var _board: Control
var _event_player: Node
var _mission_label: Label
var _state_label: Label
var _instruction_label: Label
var _end_turn_button: Button
var _next_timeline_button: Button
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

	var sidebar := VBoxContainer.new()
	sidebar.add_theme_constant_override("separation", 12)
	left_panel.add_child(sidebar)

	var title := Label.new()
	title.text = "TIMELOOP · 战斗纵切"
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", Color("#9eeeff"))
	sidebar.add_child(title)

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

	_next_timeline_button = Button.new()
	_next_timeline_button.text = "开始下一条时间线"
	_next_timeline_button.custom_minimum_size.y = 44.0
	_next_timeline_button.pressed.connect(_on_next_timeline_pressed)
	sidebar.add_child(_next_timeline_button)

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
	hint.text = "绿色：可移动\n红色：可攻击\nP：本体　E：敌人　G：分身"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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


func _start_battle() -> void:
	var level := load("res://content/levels/first_echo.tres") as LevelDefinition
	var state := BattleStateFactory.create_from_level(level, 20260802)
	_session = BattleSession.new(state)
	_board.sync_from_state(_session.state)
	_mission_label.text = "1. 留下第一个自己\n守卫需要两次攻击才能击败。第一次失败会留下分身。"
	_log.clear()
	_append_log("[color=#9eeeff]战斗开始。移动到敌人旁边并攻击。[/color]")
	_refresh_interface()


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


func get_state_snapshot_for_test() -> Dictionary:
	return _session.state.to_dict()


func get_ui_snapshot_for_test() -> Dictionary:
	return {
		"instruction": _instruction_label.text,
		"next_timeline_visible": _next_timeline_button.visible,
		"end_turn_disabled": _end_turn_button.disabled,
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
	_next_timeline_button.visible = state.phase == BattlePhase.TIMELINE_TRANSITION
	_next_timeline_button.disabled = _busy
	_restart_button.disabled = _busy

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
	if player_input and player != null:
		if not player.has_moved:
			reachable = _get_reachable_cells()
		if not player.has_acted:
			attackable = _get_attackable_cells(player)
	_board.set_interaction(reachable, attackable, player_input)


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
		&"attack_performed":
			_append_log("%s 攻击 %s" % [event.actor_id, event.payload.get("target_cell", Vector2i.ZERO)])
		&"damage_applied":
			_append_log("造成 %d 点伤害" % int(event.payload.get("damage", 0)))
		&"unit_died":
			_append_log("[color=#ff7780]%s 被击倒。[/color]" % event.actor_id)
		&"timeline_ended":
			_append_log("[color=#b993ff]T%d 已固化为分身。[/color]" % int(event.payload.get("timeline_index", 0)))
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
	return "已知时间" if time_state == &"known" else "未知时间"


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
