extends SceneTree

const CASES := [
	{"name": "m50b_fixed_390x844.png", "size": Vector2i(390, 844), "mode": &"fixed"},
	{"name": "m50b_focus_e2_390x844.png", "size": Vector2i(390, 844), "mode": &"focus"},
	{"name": "m50b_mixed_360x800.png", "size": Vector2i(360, 800), "mode": &"mixed"},
	{"name": "m50b_mixed_390x844.png", "size": Vector2i(390, 844), "mode": &"mixed"},
	{"name": "m50b_mixed_430x932.png", "size": Vector2i(430, 932), "mode": &"mixed"},
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("capture_m50b_intent_review.gd requires an output directory argument")
		quit(1)
		return
	var output_dir := String(args[0]).replace("\\", "/").trim_suffix("/")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var packed_scene := load("res://presentation/battle/battle_screen.tscn") as PackedScene
	for capture_case in CASES:
		root.size = capture_case.size
		var screen := packed_scene.instantiate() as BattleScreen
		root.add_child(screen)
		await process_frame
		await process_frame
		var state := _intent_fixture(capture_case.mode == &"mixed")
		screen.set_state_for_test(state)
		if capture_case.mode == &"focus":
			screen.focus_enemy_for_test(&"guard_02")
		await process_frame
		await process_frame
		var image := root.get_texture().get_image()
		var output_path := "%s/%s" % [output_dir, capture_case.name]
		var error := image.save_png(output_path)
		if error != OK:
			push_error("Unable to save %s: %s" % [output_path, error_string(error)])
			quit(1)
			return
		print("CAPTURED %s (%dx%d)" % [output_path, capture_case.size.x, capture_case.size.y])
		screen.queue_free()
		await process_frame
	quit(0)


func _intent_fixture(mixed: bool) -> BattleState:
	var level := load("res://content/levels/falling_timeline.tres") as LevelDefinition
	var state := BattleStateFactory.create_from_level(level, 20260809)
	state.timeline_index = 2
	state.lives_left = 2
	state.turn_index = 3
	state.time_state = &"known"
	state.ghost_positions = {&"ghost_t1": Vector2i(0, 6)}
	state.locked_enemy_intents = [
		_intent(&"guard_01", Vector2i(1, 5), [Vector2i(1, 5), Vector2i(1, 4), Vector2i(0, 4)], Vector2i(0, 5), &"move_attack"),
		_intent(&"guard_02", Vector2i(3, 4), [Vector2i(3, 4), Vector2i(4, 4), Vector2i(4, 5)], Vector2i(4, 6), &"move_attack"),
		_intent(&"guard_03", Vector2i(5, 2), [Vector2i(5, 2)], Vector2i(-1, -1), &"wait"),
		_intent(&"guard_04", Vector2i(7, 5), [Vector2i(7, 5), Vector2i(7, 6)], Vector2i(6, 6), &"move_attack"),
	]
	if mixed:
		state.time_state = &"disturbed"
		state.get_unit(&"guard_03").statuses["disturbed"] = true
		state.get_unit(&"guard_03").statuses["awake_from_turn"] = 4
		state.get_unit(&"guard_04").statuses["disturbed"] = true
		state.get_unit(&"guard_04").statuses["awake_from_turn"] = 3
		state.locked_enemy_intents[3]["reactive"] = true
	return state


func _intent(enemy_id: StringName, origin: Vector2i, path: Array[Vector2i], target: Vector2i, intent_type: StringName) -> Dictionary:
	return {
		"enemy_id": enemy_id,
		"from": origin,
		"to": path[path.size() - 1],
		"path": path,
		"last_direction": Vector2i.ZERO if path.size() <= 1 else path[path.size() - 1] - path[path.size() - 2],
		"target": target,
		"damage": 2,
		"intent_type": intent_type,
		"reactive": false,
	}
