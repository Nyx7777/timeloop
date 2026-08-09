class_name BattleScreen
extends Control

const BattleBoardViewScript := preload("res://presentation/battle/battle_board_view.gd")
const BattleEventPlayerScript := preload("res://presentation/battle/battle_event_player.gd")
const EnemyIntentPresentationScript := preload("res://presentation/battle/enemy_intent_presentation.gd")
const ReadabilityReviewFixturesScript := preload("res://presentation/battle/readability_review_fixtures.gd")
const DisplacementQueryScript := preload("res://core/queries/displacement_query.gd")
const HUD_PANEL_TEXTURE := preload("res://assets/ui/m42c/hud_panel_top.png")
const HINT_BAR_TEXTURE := preload("res://assets/ui/m42c/hint_bar_bg.png")
const ICON_MOVE_TEXTURE := preload("res://assets/ui/m50a/icon_move.png")
const ICON_ATTACK_TEXTURE := preload("res://assets/ui/m50a/icon_attack.png")
const ICON_CRYSTALLIZE_TEXTURE := preload("res://assets/ui/m50a/icon_crystallize.png")
const ICON_END_TURN_TEXTURE := preload("res://assets/ui/m50a/icon_end_turn.png")
const ICON_FIXED_TEXTURE := preload("res://assets/ui/m50a/icon_fixed.png")
const ICON_AWAKE_TEXTURE := preload("res://assets/ui/m50a/icon_awake.png")
const ICON_LOCK_TEXTURE := preload("res://assets/ui/m50a/icon_lock.png")
const BUTTON_PLATE_MOVE_TEXTURE := preload("res://assets/ui/m50a/button_plate_move.png")
const BUTTON_PLATE_ATTACK_TEXTURE := preload("res://assets/ui/m50a/button_plate_attack.png")
const BUTTON_PLATE_CRYSTALLIZE_TEXTURE := preload("res://assets/ui/m50a/button_plate_crystallize.png")
const BUTTON_PLATE_END_TURN_TEXTURE := preload("res://assets/ui/m50a/button_plate_end_turn.png")
const BUTTON_PLATE_SELECTED_MOVE_TEXTURE := preload("res://assets/ui/m50a/button_plate_selected_move.png")
const BUTTON_PLATE_SELECTED_ATTACK_TEXTURE := preload("res://assets/ui/m50a/button_plate_selected_attack.png")
const BUTTON_PLATE_SELECTED_CRYSTALLIZE_TEXTURE := preload("res://assets/ui/m50a/button_plate_selected_crystallize.png")
const BUTTON_PLATE_SELECTED_END_TURN_TEXTURE := preload("res://assets/ui/m50a/button_plate_selected_end_turn.png")
const BUTTON_INNER_GLOW_MOVE_TEXTURE := preload("res://assets/ui/m50a/button_inner_glow_move.png")
const BUTTON_INNER_GLOW_ATTACK_TEXTURE := preload("res://assets/ui/m50a/button_inner_glow_attack.png")
const BUTTON_INNER_GLOW_CRYSTALLIZE_TEXTURE := preload("res://assets/ui/m50a/button_inner_glow_crystallize.png")
const BUTTON_INNER_GLOW_END_TURN_TEXTURE := preload("res://assets/ui/m50a/button_inner_glow_end_turn.png")
const SEQUENCE_ACTIVE_TEXTURE := preload("res://assets/ui/m42c/sequence_frame_active.png")
const SEQUENCE_INACTIVE_TEXTURE := preload("res://assets/ui/m42c/sequence_frame_inactive.png")
const PLAYER_PORTRAIT_TEXTURE := preload("res://assets/characters/player_idle.png")
const GHOST_PORTRAIT_TEXTURE := preload("res://assets/characters/ghost_idle.png")
const ENEMY_PORTRAIT_TEXTURE := preload("res://assets/characters/guard_idle.png")

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
const COLOR_FIXED := Color("#ff8a3d")
const COLOR_GOLD := Color("#e9b95f")
const COLOR_MUTED := Color("#91a3c2")

var _session: BattleSession
var _board: Control
var _event_player: Node

var _timeline_label: Label
var _round_label: Label
var _time_label: Label
var _fixed_label: Label
var _awake_label: Label
var _fixed_icon: TextureRect
var _awake_icon: TextureRect
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
var _move_focus_ring: TextureRect
var _tutorial_focus_phase := 0.0
var _boss_build_review: Control
var _boss_review_button: Button
var _boss_review_active := false
var _boss_review_return_level := 0
var _readability_option: OptionButton
var _readability_button: Button
var _readability_details_label: Label
var _readability_cover: Control
var _readability_prompt_label: Label
var _readability_answer_label: Label
var _readability_timer: Timer
var _readability_review_active := false
var _readability_review_return_level := 0
var _readability_scenario_index := 0

var _busy := false
var _action_mode: StringName = &"smart"
var _active_actor: StringName = &""
var _focused_enemy_id: StringName = &""


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_interface()
	_start_battle()


func _process(delta: float) -> void:
	if _move_focus_ring == null or not _move_focus_ring.visible:
		return
	_tutorial_focus_phase = fmod(_tutorial_focus_phase + delta * 3.6, TAU)
	_move_focus_ring.modulate.a = 0.10 + sin(_tutorial_focus_phase) * 0.04


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
	_build_readability_cover()
	_build_timeline_overlay()


func _build_top_hud(parent: VBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 54.0
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _texture_style(HUD_PANEL_TEXTURE, 8.0, 5.0))
	parent.add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	panel.add_child(row)

	_timeline_label = _hud_label("T1/2", COLOR_CYAN, HORIZONTAL_ALIGNMENT_CENTER, 17)
	row.add_child(_status_cell(_timeline_label, Color("#165164"), COLOR_CYAN, 58.0))

	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", -2)

	_round_label = _hud_label("回合 1", Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 16)
	center.add_child(_round_label)
	_time_label = _hud_label("未知时间", COLOR_MUTED, HORIZONTAL_ALIGNMENT_CENTER, 10)
	center.add_child(_time_label)
	row.add_child(_status_cell(center, Color("#25203f"), Color("#615185"), 76.0, true))

	_fixed_label = _hud_label("固定 0", COLOR_FIXED, HORIZONTAL_ALIGNMENT_CENTER, 13)
	var fixed_content := _icon_status_content(ICON_FIXED_TEXTURE, _fixed_label)
	_fixed_icon = fixed_content.get_node("Icon") as TextureRect
	row.add_child(_status_cell(fixed_content, Color("#4b2116"), COLOR_FIXED, 72.0))

	_awake_label = _hud_label("清醒 0", COLOR_GOLD, HORIZONTAL_ALIGNMENT_CENTER, 13)
	_awake_label.tooltip_text = "仅在当前时间线实时决策；进入下一条时间线后，新行为重新成为固定历史。"
	var awake_content := _icon_status_content(ICON_AWAKE_TEXTURE, _awake_label)
	_awake_icon = awake_content.get_node("Icon") as TextureRect
	row.add_child(_status_cell(awake_content, Color("#463715"), COLOR_GOLD, 72.0))

	var debug_button := Button.new()
	debug_button.text = "≡"
	debug_button.tooltip_text = "关卡与调试菜单"
	debug_button.custom_minimum_size = Vector2(28.0, 40.0)
	debug_button.focus_mode = Control.FOCUS_NONE
	debug_button.add_theme_font_size_override("font_size", 16)
	debug_button.add_theme_color_override("font_color", COLOR_MUTED)
	debug_button.add_theme_stylebox_override("normal", _panel_style(Color("#0c1220"), Color("#343050"), 1, 4, 2))
	debug_button.add_theme_stylebox_override("hover", _panel_style(Color("#171d30"), COLOR_CYAN.darkened(0.25), 1, 4, 2))
	debug_button.add_theme_stylebox_override("pressed", _panel_style(Color("#070b13"), COLOR_CYAN, 1, 4, 2))
	debug_button.pressed.connect(_open_debug_overlay)
	row.add_child(debug_button)


func _build_sequence_bar(parent: VBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 78.0
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#080d19"), Color("#342554"), 1, 7, 4))
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
	_build_boss_build_review(board_panel)


func _build_boss_build_review(parent: Control) -> void:
	_boss_build_review = Control.new()
	_boss_build_review.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_boss_build_review.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_build_review.visible = false
	parent.add_child(_boss_build_review)

	var banner := PanelContainer.new()
	banner.anchor_left = 0.0
	banner.anchor_top = 0.0
	banner.anchor_right = 1.0
	banner.anchor_bottom = 0.0
	banner.offset_left = 6.0
	banner.offset_top = 6.0
	banner.offset_right = -6.0
	banner.offset_bottom = 66.0
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_theme_stylebox_override("panel", _panel_style(Color("#0b1020e8"), COLOR_RED.darkened(0.15), 2, 7, 5))
	_boss_build_review.add_child(banner)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	banner.add_child(row)

	var portrait := TextureRect.new()
	portrait.texture = _upper_body_portrait(ENEMY_PORTRAIT_TEXTURE)
	portrait.custom_minimum_size = Vector2(42.0, 48.0)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(portrait)

	var boss_info := VBoxContainer.new()
	boss_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boss_info.add_theme_constant_override("separation", 2)
	row.add_child(boss_info)

	var boss_name := Label.new()
	boss_name.text = "裂隙监理者 · 阶段 2"
	boss_name.add_theme_font_size_override("font_size", 12)
	boss_name.add_theme_color_override("font_color", Color("#ffd6dc"))
	boss_info.add_child(boss_name)

	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 2)
	boss_info.add_child(hp_row)
	for segment_index in range(8):
		var segment := Panel.new()
		segment.custom_minimum_size = Vector2(11.0, 8.0)
		var segment_color := COLOR_RED if segment_index < 6 else Color("#39253a")
		segment.add_theme_stylebox_override("panel", _panel_style(segment_color, Color("#ff9ca4"), 1, 2, 0))
		hp_row.add_child(segment)

	var boss_states := HBoxContainer.new()
	boss_states.add_theme_constant_override("separation", 3)
	boss_info.add_child(boss_states)
	boss_states.add_child(_compact_icon(ICON_FIXED_TEXTURE, 18.0, "行为固定"))
	boss_states.add_child(_compact_icon(ICON_AWAKE_TEXTURE, 18.0, "受扰后下回合清醒"))

	var build_info := VBoxContainer.new()
	build_info.alignment = BoxContainer.ALIGNMENT_CENTER
	build_info.add_theme_constant_override("separation", 1)
	row.add_child(build_info)
	var build_label := Label.new()
	build_label.text = "BUILD 3"
	build_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	build_label.add_theme_font_size_override("font_size", 9)
	build_label.add_theme_color_override("font_color", COLOR_CYAN)
	build_info.add_child(build_label)
	var build_row := HBoxContainer.new()
	build_row.add_theme_constant_override("separation", 2)
	build_info.add_child(build_row)
	build_row.add_child(_compact_icon(ICON_MOVE_TEXTURE, 20.0, "位移增幅"))
	build_row.add_child(_compact_icon(ICON_CRYSTALLIZE_TEXTURE, 20.0, "固化返还"))
	build_row.add_child(_compact_icon(ICON_AWAKE_TEXTURE, 20.0, "扰动观测"))


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

	_move_button = _action_button("移动", COLOR_CYAN, ICON_MOVE_TEXTURE, BUTTON_PLATE_MOVE_TEXTURE, BUTTON_PLATE_SELECTED_MOVE_TEXTURE, BUTTON_INNER_GLOW_MOVE_TEXTURE)
	_move_focus_ring = _move_button.get_node("FocusRing") as TextureRect
	_move_button.toggle_mode = true
	_move_button.pressed.connect(_on_move_pressed)
	actions.add_child(_move_button)

	_attack_button = _action_button("攻击", COLOR_RED, ICON_ATTACK_TEXTURE, BUTTON_PLATE_ATTACK_TEXTURE, BUTTON_PLATE_SELECTED_ATTACK_TEXTURE, BUTTON_INNER_GLOW_ATTACK_TEXTURE)
	_attack_button.toggle_mode = true
	_attack_button.pressed.connect(_on_attack_pressed)
	actions.add_child(_attack_button)

	_crystallize_button = _action_button("固化", COLOR_PURPLE, ICON_CRYSTALLIZE_TEXTURE, BUTTON_PLATE_CRYSTALLIZE_TEXTURE, BUTTON_PLATE_SELECTED_CRYSTALLIZE_TEXTURE, BUTTON_INNER_GLOW_CRYSTALLIZE_TEXTURE)
	_crystallize_button.pressed.connect(_on_crystallize_pressed)
	actions.add_child(_crystallize_button)

	_end_turn_button = _action_button("结束", COLOR_GOLD, ICON_END_TURN_TEXTURE, BUTTON_PLATE_END_TURN_TEXTURE, BUTTON_PLATE_SELECTED_END_TURN_TEXTURE, BUTTON_INNER_GLOW_END_TURN_TEXTURE)
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

	_boss_review_button = Button.new()
	_boss_review_button.text = "进入 M5.0A · Boss + Build 评审态"
	_boss_review_button.custom_minimum_size.y = 46.0
	_boss_review_button.tooltip_text = "仅用于检查最大信息量，不对应六关中的实际 Boss 关卡。"
	_boss_review_button.add_theme_color_override("font_color", Color("#ffd6dc"))
	_boss_review_button.add_theme_stylebox_override("normal", _panel_style(Color("#251425"), Color("#c64d68"), 1, 6, 8))
	_boss_review_button.add_theme_stylebox_override("hover", _panel_style(Color("#3b1728"), Color("#ff7186"), 2, 6, 8))
	_boss_review_button.pressed.connect(_on_boss_review_pressed)
	content.add_child(_boss_review_button)

	var readability_title := Label.new()
	readability_title.text = "M5.0C · 2—3 秒无日志读图"
	readability_title.add_theme_color_override("font_color", COLOR_GOLD)
	content.add_child(readability_title)

	_readability_option = OptionButton.new()
	for scenario_index in range(ReadabilityReviewFixturesScript.count()):
		var scenario := ReadabilityReviewFixturesScript.describe(scenario_index)
		_readability_option.add_item(String(scenario.label))
	_readability_option.item_selected.connect(_on_readability_scenario_selected)
	content.add_child(_readability_option)

	_readability_details_label = Label.new()
	_readability_details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_readability_details_label.add_theme_font_size_override("font_size", 12)
	_readability_details_label.add_theme_color_override("font_color", Color("#cbd9ef"))
	content.add_child(_readability_details_label)

	_readability_button = Button.new()
	_readability_button.text = "进入 M5.0C · 只读读图评审"
	_readability_button.custom_minimum_size.y = 44.0
	_readability_button.tooltip_text = "进入后关闭工具与日志；观察 2—3 秒，再回来对照问题和答案。"
	_readability_button.add_theme_color_override("font_color", Color("#ffe1a6"))
	_readability_button.add_theme_stylebox_override("normal", _panel_style(Color("#2b2514"), Color("#9a7435"), 1, 6, 8))
	_readability_button.add_theme_stylebox_override("hover", _panel_style(Color("#403318"), COLOR_GOLD, 2, 6, 8))
	_readability_button.pressed.connect(_on_readability_review_pressed)
	content.add_child(_readability_button)
	_refresh_readability_details()

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


func _build_readability_cover() -> void:
	_readability_cover = Control.new()
	_readability_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_readability_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	_readability_cover.visible = false
	add_child(_readability_cover)

	var scrim := ColorRect.new()
	scrim.color = Color(0.015, 0.025, 0.06, 0.96)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_readability_cover.add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_readability_cover.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(330.0, 300.0)
	panel.add_theme_stylebox_override("panel", _panel_style(Color("#11192d"), COLOR_GOLD, 2, 12, 18))
	center.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	panel.add_child(content)

	var title := Label.new()
	title.text = "3 秒读图结束"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", COLOR_GOLD)
	content.add_child(title)

	_readability_prompt_label = Label.new()
	_readability_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_readability_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_readability_prompt_label.add_theme_font_size_override("font_size", 16)
	_readability_prompt_label.add_theme_color_override("font_color", Color("#e7eefb"))
	content.add_child(_readability_prompt_label)

	_readability_answer_label = Label.new()
	_readability_answer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_readability_answer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_readability_answer_label.add_theme_font_size_override("font_size", 13)
	_readability_answer_label.add_theme_color_override("font_color", Color("#9eeeff"))
	_readability_answer_label.visible = false
	content.add_child(_readability_answer_label)

	var reveal_button := Button.new()
	reveal_button.text = "显示对照答案"
	reveal_button.custom_minimum_size.y = 44.0
	reveal_button.pressed.connect(_on_readability_reveal_pressed)
	content.add_child(reveal_button)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	content.add_child(actions)
	var replay_button := Button.new()
	replay_button.text = "再看 3 秒"
	replay_button.custom_minimum_size.y = 44.0
	replay_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	replay_button.pressed.connect(_begin_readability_exposure)
	actions.add_child(replay_button)
	var exit_button := Button.new()
	exit_button.text = "退出评审"
	exit_button.custom_minimum_size.y = 44.0
	exit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exit_button.pressed.connect(_exit_readability_review)
	actions.add_child(exit_button)

	_readability_timer = Timer.new()
	_readability_timer.one_shot = true
	_readability_timer.wait_time = 3.0
	_readability_timer.timeout.connect(_on_readability_exposure_finished)
	add_child(_readability_timer)


func _start_battle() -> void:
	if _readability_timer != null:
		_readability_timer.stop()
	if _readability_cover != null:
		_readability_cover.visible = false
	_boss_review_active = false
	_readability_review_active = false
	_boss_build_review.visible = false
	_boss_review_button.text = "进入 M5.0A · Boss + Build 评审态"
	_readability_button.text = "进入 M5.0C · 只读读图评审"
	var selected_index := _level_option.selected
	var level_data: Dictionary = LEVELS[selected_index]
	var level := load(level_data.path) as LevelDefinition
	var state := BattleStateFactory.create_from_level(level, 20260802)
	_session = BattleSession.new(state)
	_action_mode = &"smart"
	_active_actor = state.player_id
	_focused_enemy_id = &""
	_board.sync_from_state(_session.state)
	_mission_label.text = "%d. %s\n%s\n%s" % [level_data.number, level.display_name, level.briefing, level.hint]
	_log.clear()
	_append_log("[color=#9eeeff]%s开始。移动到敌人旁边并攻击。[/color]" % level.display_name)
	_refresh_interface()


func _enter_boss_build_review() -> void:
	_readability_timer.stop()
	_readability_cover.visible = false
	_readability_review_active = false
	_readability_button.text = "进入 M5.0C · 只读读图评审"
	_boss_review_return_level = _level_option.selected
	_level_option.select(5)
	var level := load(LEVELS[5].path) as LevelDefinition
	var state := BattleStateFactory.create_from_level(level, 20260802)
	state.timeline_index = 3
	state.lives_left = 1
	state.turn_index = 6
	state.time_state = &"disturbed"
	state.ghost_positions = {
		&"ghost_t1": Vector2i(0, 6),
		&"ghost_t2": Vector2i(2, 6),
	}
	var player := state.get_unit(state.player_id)
	player.position = Vector2i(0, 5)
	player.has_moved = true
	player.has_acted = false
	state.locked_enemy_intents.clear()
	var enemy_index := 0
	for unit_id in state.unit_order:
		var unit := state.get_unit(unit_id)
		if unit == null or unit.team != &"enemy":
			continue
		enemy_index += 1
		var reactive := enemy_index == 4
		state.locked_enemy_intents.append({"enemy_id": unit_id, "reactive": reactive})
		if reactive:
			unit.statuses["disturbed"] = true
			unit.statuses["awake_from_turn"] = state.turn_index

	_session = BattleSession.new(state)
	_action_mode = &"attack"
	_active_actor = state.player_id
	_focused_enemy_id = &""
	_boss_review_active = true
	_boss_build_review.visible = true
	_boss_review_button.text = "退出评审态并返回原关卡"
	_mission_label.text = "M5.0A · Boss + Build 最大信息评审态\n仅检查 HUD 容量和视觉层级，不对应六关中的真实 Boss 玩法。"
	_log.clear()
	_append_log("[color=#ff9cad]已进入只读 Boss + Build 评审态。[/color]")
	_board.sync_from_state(state)
	_refresh_interface()


func _enter_readability_review(scenario_index: int) -> void:
	_readability_review_return_level = _level_option.selected
	_readability_scenario_index = scenario_index
	var scenario := ReadabilityReviewFixturesScript.describe(scenario_index)
	_level_option.select(int(scenario.level_index))
	var state := ReadabilityReviewFixturesScript.build_state(scenario_index)
	_session = BattleSession.new(state)
	_action_mode = &"smart"
	_active_actor = state.player_id
	_focused_enemy_id = &""
	_boss_review_active = false
	_readability_review_active = true
	_boss_build_review.visible = bool(scenario.get("show_boss_rail", false))
	_boss_review_button.text = "进入 M5.0A · Boss + Build 评审态"
	_readability_button.text = "退出读图评审并返回原关卡"
	_log.clear()
	_board.sync_from_state(state)
	_refresh_interface()
	_begin_readability_exposure()


func _on_level_selected(_index: int) -> void:
	if not _busy:
		_start_battle()


func _on_move_pressed() -> void:
	if _is_read_only_review():
		_refresh_interface()
		return
	if _move_button.disabled:
		return
	_action_mode = &"smart" if _action_mode == &"move" else &"move"
	_refresh_interface()


func _on_attack_pressed() -> void:
	if _is_read_only_review():
		_refresh_interface()
		return
	if _attack_button.disabled:
		return
	_action_mode = &"smart" if _action_mode == &"attack" else &"attack"
	_refresh_interface()


func _on_board_cell_clicked(cell: Vector2i) -> void:
	if _busy or _is_read_only_review() or _session.state.phase != BattlePhase.PLAYER_INPUT:
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
	if not _busy and not _is_read_only_review():
		_submit(BattleCommand.end_turn(_session.state.player_id))


func _on_crystallize_pressed() -> void:
	if not _busy and not _is_read_only_review():
		_submit(BattleCommand.crystallize(_session.state.player_id))


func _on_next_timeline_pressed() -> void:
	if not _busy:
		_submit(BattleCommand.start_next_timeline())


func _on_restart_pressed() -> void:
	if _busy:
		return
	_start_battle()
	_debug_overlay.visible = false


func _on_boss_review_pressed() -> void:
	if _busy:
		return
	if _boss_review_active:
		_level_option.select(_boss_review_return_level)
		_start_battle()
	else:
		_enter_boss_build_review()
	_debug_overlay.visible = false


func _on_readability_scenario_selected(index: int) -> void:
	_readability_scenario_index = index
	_refresh_readability_details()


func _on_readability_review_pressed() -> void:
	if _busy:
		return
	if _readability_review_active:
		_level_option.select(_readability_review_return_level)
		_start_battle()
	else:
		_enter_readability_review(_readability_option.selected)
	_debug_overlay.visible = false


func _begin_readability_exposure() -> void:
	if not _readability_review_active:
		return
	_readability_cover.visible = false
	_readability_answer_label.visible = false
	_readability_timer.start()


func _on_readability_exposure_finished() -> void:
	if not _readability_review_active:
		return
	var scenario := ReadabilityReviewFixturesScript.describe(_readability_scenario_index)
	_readability_prompt_label.text = String(scenario.prompt)
	_readability_answer_label.text = "对照：%s" % String(scenario.answer)
	_readability_answer_label.visible = false
	_readability_cover.visible = true


func _on_readability_reveal_pressed() -> void:
	_readability_answer_label.visible = true


func _exit_readability_review() -> void:
	if not _readability_review_active:
		return
	_level_option.select(_readability_review_return_level)
	_start_battle()


func _refresh_readability_details() -> void:
	if _readability_details_label == null:
		return
	_readability_details_label.text = "进入后只显示战场 3 秒并自动遮罩。\n遮罩后先作答，再显示对照答案。"


func _is_read_only_review() -> bool:
	return _boss_review_active or _readability_review_active


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
	if _busy or _is_read_only_review():
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


func set_playback_speed_for_test(speed: float) -> void:
	_event_player.playback_speed = speed


func submit_command_for_test(command: BattleCommand) -> void:
	await _submit(command)


func select_level_for_test(index: int) -> void:
	_level_option.select(index)
	_start_battle()


func set_state_for_test(state: BattleState) -> void:
	_session = BattleSession.new(BattleState.from_dict(state.to_dict()))
	_action_mode = &"smart"
	_active_actor = _session.state.player_id
	_focused_enemy_id = &""
	_board.sync_from_state(_session.state)
	_refresh_interface()


func set_action_mode_for_test(mode: StringName) -> void:
	_action_mode = mode
	_refresh_interface()


func focus_enemy_for_test(enemy_id: StringName) -> void:
	_set_focused_enemy(enemy_id)


func open_debug_overlay_for_test() -> void:
	_open_debug_overlay()


func close_debug_overlay_for_test() -> void:
	_close_debug_overlay()


func set_boss_build_review_for_test(enabled: bool) -> void:
	_boss_build_review.visible = enabled


func enter_boss_build_review_for_test() -> void:
	_enter_boss_build_review()


func exit_boss_build_review_for_test() -> void:
	if not _boss_review_active:
		return
	_level_option.select(_boss_review_return_level)
	_start_battle()


func enter_readability_review_for_test(scenario_index: int) -> void:
	_enter_readability_review(scenario_index)


func exit_readability_review_for_test() -> void:
	_exit_readability_review()


func finish_readability_exposure_for_test() -> void:
	_readability_timer.stop()
	_on_readability_exposure_finished()


func reveal_readability_answer_for_test() -> void:
	_on_readability_reveal_pressed()


func get_state_snapshot_for_test() -> Dictionary:
	return _session.state.to_dict()


func get_board_preview_snapshot_for_test() -> Dictionary:
	return _board.get_preview_snapshot_for_test()


func get_board_animation_snapshot_for_test() -> Dictionary:
	return _board.get_animation_snapshot_for_test()


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
		"timeline_text": _timeline_label.text,
		"time_text": _time_label.text,
		"fixed_text": _fixed_label.text,
		"awake_text": _awake_label.text,
		"sequence_temporal_states": _sequence_temporal_snapshot(),
		"sequence_portrait_modes": _sequence_portrait_snapshot(),
		"sequence_focus_states": _sequence_focus_snapshot(),
		"focused_enemy_id": _focused_enemy_id,
		"next_timeline_visible": _timeline_overlay.visible,
		"end_turn_disabled": _end_turn_button.disabled,
		"crystallize_visible": _crystallize_button.visible,
		"crystallize_disabled": _crystallize_button.disabled,
		"move_disabled": _move_button.disabled,
		"attack_disabled": _attack_button.disabled,
		"move_selected": _move_button.button_pressed,
		"attack_selected": _attack_button.button_pressed,
		"tutorial_focus_target": "move" if _move_focus_ring.visible else "",
		"tutorial_other_actions_dimmed": _attack_button.modulate.a < 0.8,
		"action_icons": {
			"move": _action_button_icon_path(_move_button),
			"attack": _action_button_icon_path(_attack_button),
			"crystallize": _action_button_icon_path(_crystallize_button),
			"end_turn": _action_button_icon_path(_end_turn_button),
		},
		"action_plates": {
			"move": _action_button_plate_paths(_move_button),
			"attack": _action_button_plate_paths(_attack_button),
			"crystallize": _action_button_plate_paths(_crystallize_button),
			"end_turn": _action_button_plate_paths(_end_turn_button),
		},
		"action_legacy_frame_visible": _move_button.has_node("FrameGlow"),
		"action_inner_glows": {
			"move": _action_button_inner_glow_path(_move_button),
			"attack": _action_button_inner_glow_path(_attack_button),
			"crystallize": _action_button_inner_glow_path(_crystallize_button),
			"end_turn": _action_button_inner_glow_path(_end_turn_button),
		},
		"crystallize_caption": (_crystallize_button.get_node("Caption") as Label).text,
		"boss_build_review_visible": _boss_build_review.visible,
		"boss_build_review_mode": _boss_review_active,
		"boss_review_button_text": _boss_review_button.text,
		"readability_review_mode": _readability_review_active,
		"readability_scenario_index": _readability_scenario_index,
		"readability_review_button_text": _readability_button.text,
		"readability_review_details": _readability_details_label.text,
		"readability_cover_visible": _readability_cover.visible,
		"readability_answer_visible": _readability_answer_label.visible,
		"readability_prompt_text": _readability_prompt_label.text,
		"debug_overlay_visible": _debug_overlay.visible,
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
	var temporal_counts := _enemy_temporal_counts(state)
	_fixed_label.text = "固定 %d" % int(temporal_counts.fixed)
	_awake_label.text = "清醒 %d" % int(temporal_counts.awake)
	_fixed_label.modulate = Color.WHITE if int(temporal_counts.fixed) > 0 else Color(1.0, 1.0, 1.0, 0.48)
	_awake_label.modulate = Color.WHITE if int(temporal_counts.awake) > 0 else Color(1.0, 1.0, 1.0, 0.48)
	_fixed_icon.modulate = _fixed_label.modulate
	_awake_icon.modulate = _awake_label.modulate
	_validate_focused_enemy(state)
	_refresh_sequence_bar(state)
	if not _busy:
		_sync_enemy_intent_presentations(state)

	var player_input := state.phase == BattlePhase.PLAYER_INPUT and not _busy and not _is_read_only_review()
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
	if not bool(state.rules.get("crystallize_enabled", false)):
		_set_action_button_content(_crystallize_button, "固化", ICON_LOCK_TEXTURE)
	elif state.lives_left <= 1:
		_set_action_button_content(_crystallize_button, "固化", ICON_CRYSTALLIZE_TEXTURE)
	else:
		_set_action_button_content(_crystallize_button, "固化", ICON_CRYSTALLIZE_TEXTURE)
	_move_button.button_pressed = _action_mode == &"move" and not _move_button.disabled
	_attack_button.button_pressed = _action_mode == &"attack" and not _attack_button.disabled
	_refresh_tutorial_focus(state, player, player_input)

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
	elif _first_pending_enemy(state) != &"":
		var pending_id := _first_pending_enemy(state)
		var pending_label := String(EnemyIntentPresentationScript.enemy_labels(state).get(pending_id, pending_id))
		var pending_unit := state.get_unit(pending_id)
		_instruction_label.text = "%s 已扰动·本回合仍锁定；回合 %d 起清醒。" % [pending_label, int(pending_unit.statuses.get("awake_from_turn", state.turn_index + 1))]
	elif _move_focus_ring.visible:
		_instruction_label.text = "第一步：点击移动，再选择青色格。"
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
		_sequence_row.add_child(_sequence_chip(
			"G%d" % (ghost_index + 1),
			COLOR_PURPLE,
			ghost_ids[ghost_index] == _active_actor,
			GHOST_PORTRAIT_TEXTURE,
			"录",
			COLOR_PURPLE
		))

	var player_active := state.phase == BattlePhase.PLAYER_INPUT and not _busy
	_sequence_row.add_child(_sequence_chip("本体", COLOR_CYAN, player_active or _active_actor == state.player_id, PLAYER_PORTRAIT_TEXTURE))

	var enemy_labels: Dictionary = EnemyIntentPresentationScript.enemy_labels(state)
	for unit_id in state.unit_order:
		var unit := state.get_unit(unit_id)
		if unit == null or not unit.active or unit.team != &"enemy":
			continue
		var temporal_status := _enemy_temporal_status(state, unit)
		var status_text := ""
		var status_color := COLOR_RED
		match temporal_status:
			&"fixed":
				status_text = "定"
				status_color = COLOR_FIXED
			&"pending_awake":
				status_text = "待醒"
				status_color = Color("#ff8fc7")
			&"awake":
				status_text = "醒"
				status_color = COLOR_GOLD
		_sequence_row.add_child(_sequence_chip(
			String(enemy_labels.get(unit_id, "?")),
			status_color if temporal_status != &"unknown" else COLOR_RED,
			unit_id == _active_actor or unit_id == _focused_enemy_id,
			ENEMY_PORTRAIT_TEXTURE,
			status_text,
			status_color,
			unit_id
		))


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
	if event.event_type == &"turn_started":
		_sync_enemy_intent_presentations(_session.state)
	elif event.event_type == &"enemy_disturbed":
		_sync_enemy_intent_presentations(_session.state)
		var label := String(EnemyIntentPresentationScript.enemy_labels(_session.state).get(event.actor_id, event.actor_id))
		_instruction_label.text = "%s 已扰动·本回合行为仍已锁定" % label


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


func _action_button(
	text_value: String,
	accent: Color,
	icon_texture: Texture2D,
	plate_texture: Texture2D,
	selected_plate_texture: Texture2D,
	inner_glow_texture: Texture2D
) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(72.0, 100.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.set_meta("accent", accent)
	var empty_style := StyleBoxEmpty.new()
	for state_name in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state_name, empty_style)

	var plate := _button_plate(plate_texture)
	plate.name = "Plate"
	button.add_child(plate)
	button.set_meta("plate_path", plate_texture.resource_path)
	button.set_meta("selected_plate_path", selected_plate_texture.resource_path)
	button.set_meta("plate_texture", plate_texture)
	button.set_meta("selected_plate_texture", selected_plate_texture)

	var focus_ring := _button_plate(selected_plate_texture)
	focus_ring.name = "FocusRing"
	focus_ring.offset_left = -1.0
	focus_ring.offset_top = -1.0
	focus_ring.offset_right = 1.0
	focus_ring.offset_bottom = 1.0
	focus_ring.modulate = Color(1.0, 1.0, 1.0, 0.10)
	focus_ring.visible = false
	button.add_child(focus_ring)

	var inner_glow := TextureRect.new()
	inner_glow.name = "InnerGlow"
	inner_glow.texture = inner_glow_texture
	inner_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner_glow.offset_left = 2.0
	inner_glow.offset_top = 2.0
	inner_glow.offset_right = -2.0
	inner_glow.offset_bottom = -2.0
	inner_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	inner_glow.stretch_mode = TextureRect.STRETCH_SCALE
	inner_glow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	inner_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(inner_glow)
	button.set_meta("inner_glow_path", inner_glow_texture.resource_path)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.anchor_left = 0.5
	icon.anchor_top = 0.0
	icon.anchor_right = 0.5
	icon.anchor_bottom = 0.0
	icon.offset_left = -19.0
	icon.offset_top = 14.0
	icon.offset_right = 19.0
	icon.offset_bottom = 52.0
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)

	var caption := Label.new()
	caption.name = "Caption"
	caption.anchor_left = 0.0
	caption.anchor_top = 0.54
	caption.anchor_right = 1.0
	caption.anchor_bottom = 0.98
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 15)
	caption.add_theme_constant_override("outline_size", 1)
	caption.add_theme_color_override("font_color", accent.lightened(0.18))
	caption.add_theme_color_override("font_outline_color", Color("#050812"))
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(caption)

	_set_action_button_content(button, text_value, icon_texture)
	return button


func _set_action_button_content(button: Button, caption_text: String, icon_texture: Texture2D) -> void:
	var caption := button.get_node("Caption") as Label
	var icon := button.get_node("Icon") as TextureRect
	caption.text = caption_text
	icon.texture = icon_texture
	button.set_meta("icon_path", icon_texture.resource_path)


func _action_button_icon_path(button: Button) -> String:
	return String(button.get_meta("icon_path", ""))


func _action_button_plate_paths(button: Button) -> Dictionary:
	return {
		"normal": String(button.get_meta("plate_path", "")),
		"selected": String(button.get_meta("selected_plate_path", "")),
	}


func _action_button_inner_glow_path(button: Button) -> String:
	return String(button.get_meta("inner_glow_path", ""))


func _button_plate(texture: Texture2D) -> TextureRect:
	var plate := TextureRect.new()
	plate.texture = texture
	plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate.stretch_mode = TextureRect.STRETCH_SCALE
	plate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return plate


func _refresh_tutorial_focus(state: BattleState, player: UnitState, player_input: bool) -> void:
	var tutorial_active := (
		player_input
		and state.level_id == &"first_echo"
		and state.timeline_index == 1
		and state.turn_index == 1
		and player != null
		and not player.has_moved
		and not player.has_acted
		and not _move_button.disabled
	)
	_move_focus_ring.visible = tutorial_active
	if not tutorial_active:
		_tutorial_focus_phase = 0.0
		_move_focus_ring.modulate.a = 0.10

	var buttons: Array[Button] = [_move_button, _attack_button, _crystallize_button, _end_turn_button]
	for button in buttons:
		button.modulate = Color.WHITE if not tutorial_active or button == _move_button else Color(0.62, 0.68, 0.78, 0.58)
		var icon := button.get_node("Icon") as TextureRect
		var caption := button.get_node("Caption") as Label
		var plate := button.get_node("Plate") as TextureRect
		var inner_glow := button.get_node("InnerGlow") as TextureRect
		var emphasized := button.button_pressed or (tutorial_active and button == _move_button)
		plate.texture = (button.get_meta("selected_plate_texture") as Texture2D) if emphasized else (button.get_meta("plate_texture") as Texture2D)
		icon.modulate = Color.WHITE if not button.disabled else Color(0.58, 0.62, 0.70, 0.38)
		caption.modulate = Color.WHITE if not button.disabled else Color(0.68, 0.72, 0.80, 0.46)
		if button.disabled:
			plate.modulate = Color(0.48, 0.52, 0.62, 1.0)
			inner_glow.modulate = Color(0.56, 0.60, 0.68, 0.10)
		elif emphasized:
			plate.modulate = Color(1.04, 1.04, 1.04, 1.0)
			inner_glow.modulate = Color(1.0, 1.0, 1.0, 0.38)
		else:
			plate.modulate = Color(0.92, 0.96, 1.0, 1.0)
			inner_glow.modulate = Color(1.0, 1.0, 1.0, 0.20)


func _icon_status_content(icon_texture: Texture2D, label: Label) -> HBoxContainer:
	var content := HBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 2)
	var icon := _compact_icon(icon_texture, 18.0)
	icon.name = "Icon"
	content.add_child(icon)
	content.add_child(label)
	return content


func _compact_icon(icon_texture: Texture2D, icon_size: float, tooltip := "") -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = icon_texture
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.tooltip_text = tooltip
	return icon


func _sequence_chip(
	text_value: String,
	accent: Color,
	active: bool,
	portrait_texture: Texture2D,
	status_text := "",
	status_color := COLOR_MUTED,
	enemy_id: StringName = &""
) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2(44.0, 66.0)
	chip.set_meta("unit_label", text_value)
	chip.set_meta("temporal_status", status_text)
	chip.set_meta("enemy_id", enemy_id)
	chip.set_meta("focused", enemy_id != &"" and enemy_id == _focused_enemy_id)
	var chip_tint := Color(1.14, 1.14, 1.14, 1.0) if active else Color.WHITE
	if status_text == "醒":
		chip_tint *= Color(1.12, 1.02, 0.70, 1.0)
	elif status_text == "待醒":
		chip_tint *= Color(1.10, 0.76, 0.96, 1.0)
	chip.add_theme_stylebox_override("panel", _texture_style(SEQUENCE_ACTIVE_TEXTURE if active else SEQUENCE_INACTIVE_TEXTURE, 8.0, 3.0, chip_tint))
	if enemy_id != &"":
		chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		chip.mouse_filter = Control.MOUSE_FILTER_STOP
		chip.tooltip_text = "点击聚焦 %s 的时间意图；再次点击取消" % text_value
		chip.gui_input.connect(_on_sequence_chip_input.bind(enemy_id))

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", -1)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(content)

	var portrait := TextureRect.new()
	portrait.texture = _upper_body_portrait(portrait_texture)
	portrait.custom_minimum_size = Vector2(36.0, 42.0)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.modulate = Color.WHITE if active else Color(0.86, 0.90, 1.0, 0.90)
	chip.set_meta("portrait_mode", "upper_body")
	content.add_child(portrait)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 2)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(footer)

	var label := Label.new()
	label.text = "▼%s" % text_value if active else text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color.WHITE if active else accent.lightened(0.05))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(label)

	if not status_text.is_empty():
		var status := Label.new()
		status.text = status_text
		status.tooltip_text = _temporal_status_tooltip(status_text)
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		status.add_theme_font_size_override("font_size", 9 if status_text.length() <= 1 else 8)
		status.add_theme_color_override("font_color", status_color.lightened(0.12))
		status.add_theme_stylebox_override("normal", _panel_style(Color(status_color, 0.12), status_color.darkened(0.08), 1, 4, 2))
		status.mouse_filter = Control.MOUSE_FILTER_IGNORE
		footer.add_child(status)
	return chip


func _upper_body_portrait(source: Texture2D) -> AtlasTexture:
	var portrait := AtlasTexture.new()
	portrait.atlas = source
	var source_size := source.get_size()
	portrait.region = Rect2(
		source_size.x * 0.12,
		source_size.y * 0.03,
		source_size.x * 0.76,
		source_size.y * 0.66
	)
	return portrait


func _status_cell(content: Control, background: Color, border: Color, minimum_width: float, expand := false) -> PanelContainer:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(minimum_width, 40.0)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL if expand else Control.SIZE_SHRINK_CENTER
	cell.add_theme_stylebox_override("panel", _panel_style(background, border.darkened(0.08), 1, 5, 4))
	cell.add_child(content)
	return cell


func _enemy_temporal_counts(state: BattleState) -> Dictionary:
	var counts := {"fixed": 0, "awake": 0}
	for unit_id in state.unit_order:
		var unit := state.get_unit(unit_id)
		if unit == null or not unit.active or unit.team != &"enemy":
			continue
		var status := _enemy_temporal_status(state, unit)
		if status == &"awake":
			counts.awake += 1
		elif status == &"fixed" or status == &"pending_awake":
			counts.fixed += 1
	return counts


func _enemy_temporal_status(state: BattleState, unit: UnitState) -> StringName:
	return EnemyIntentPresentationScript.temporal_status(state, unit)


func _temporal_status_tooltip(status_text: String) -> String:
	if status_text == "定":
		return "固定历史：本回合行为可预知"
	if status_text == "待醒":
		return "已扰动：本回合仍锁定，下回合清醒"
	if status_text == "醒":
		return "本线清醒：玩家行动后实时决策；下一条时间线重新固化"
	if status_text == "录":
		return "已记录的分身行动"
	return ""


func _sequence_temporal_snapshot() -> Dictionary:
	var snapshot := {}
	for child in _sequence_row.get_children():
		var label := String(child.get_meta("unit_label", ""))
		if label.is_empty():
			continue
		snapshot[label] = String(child.get_meta("temporal_status", ""))
	return snapshot


func _sequence_portrait_snapshot() -> Dictionary:
	var snapshot := {}
	for child in _sequence_row.get_children():
		var label := String(child.get_meta("unit_label", ""))
		if label.is_empty():
			continue
		snapshot[label] = String(child.get_meta("portrait_mode", ""))
	return snapshot


func _sequence_focus_snapshot() -> Dictionary:
	var snapshot := {}
	for child in _sequence_row.get_children():
		var label := String(child.get_meta("unit_label", ""))
		if label.is_empty():
			continue
		snapshot[label] = bool(child.get_meta("focused", false))
	return snapshot


func _on_sequence_chip_input(event: InputEvent, enemy_id: StringName) -> void:
	var pressed := false
	if event is InputEventMouseButton:
		pressed = event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	elif event is InputEventScreenTouch:
		pressed = event.pressed
	if pressed and not _busy and not _boss_review_active:
		_set_focused_enemy(enemy_id)


func _set_focused_enemy(enemy_id: StringName) -> void:
	_focused_enemy_id = &"" if _focused_enemy_id == enemy_id else enemy_id
	_refresh_sequence_bar(_session.state)
	_sync_enemy_intent_presentations(_session.state)


func _validate_focused_enemy(state: BattleState) -> void:
	if _focused_enemy_id == &"":
		return
	var unit := state.get_unit(_focused_enemy_id)
	if unit == null or not unit.active or unit.team != &"enemy":
		_focused_enemy_id = &""


func _sync_enemy_intent_presentations(state: BattleState) -> void:
	_validate_focused_enemy(state)
	_board.set_enemy_intent_presentations(EnemyIntentPresentationScript.build(state, _focused_enemy_id))


func _first_pending_enemy(state: BattleState) -> StringName:
	for intent in EnemyIntentPresentationScript.build(state):
		if intent.get("temporal_status", &"unknown") == &"pending_awake":
			return StringName(intent.get("enemy_id", &""))
	return &""


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
