extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("capture_m50a_completion_review.gd requires an output directory argument")
		quit(1)
		return

	var output_dir := String(args[0]).replace("\\", "/").trim_suffix("/")
	DirAccess.make_dir_recursive_absolute(output_dir)
	root.size = Vector2i(390, 844)

	var packed_scene := load("res://presentation/battle/battle_screen.tscn") as PackedScene
	if packed_scene == null:
		push_error("Unable to load the battle screen")
		quit(1)
		return

	var screen := packed_scene.instantiate() as BattleScreen
	root.add_child(screen)
	await process_frame
	await process_frame
	screen.set_instant_playback_for_test()

	# First-contact state: the move action receives a non-blocking tutorial focus.
	screen.select_level_for_test(0)
	await _capture("%s/m50a_tutorial_focus.png" % output_dir)

	# Maximum-information representative: T3, two ghosts, four enemies, mixed
	# temporal states, an available attack, and the Boss + Build review rail.
	screen.select_level_for_test(5)
	var max_state := BattleState.from_dict(screen.get_state_snapshot_for_test())
	max_state.timeline_index = 3
	max_state.lives_left = 1
	max_state.turn_index = 6
	max_state.time_state = &"disturbed"
	max_state.ghost_positions = {
		&"ghost_t1": Vector2i(0, 6),
		&"ghost_t2": Vector2i(2, 6),
	}
	var player := max_state.get_unit(max_state.player_id)
	player.position = Vector2i(0, 5)
	player.has_moved = true
	player.has_acted = false
	max_state.locked_enemy_intents.clear()
	var enemy_index := 0
	for unit_id in max_state.unit_order:
		var unit := max_state.get_unit(unit_id)
		if unit == null or unit.team != &"enemy":
			continue
		enemy_index += 1
		var reactive := enemy_index == 4
		max_state.locked_enemy_intents.append({"enemy_id": unit_id, "reactive": reactive})
		if reactive:
			unit.statuses["disturbed"] = true
			unit.statuses["awake_from_turn"] = max_state.turn_index
	screen.set_state_for_test(max_state)
	screen.set_action_mode_for_test(&"attack")
	screen.set_boss_build_review_for_test(true)
	await _capture("%s/m50a_boss_build_max.png" % output_dir)

	screen.queue_free()
	await process_frame
	quit(0)


func _capture(output_path: String) -> void:
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var error := image.save_png(output_path)
	if error != OK:
		push_error("Unable to save %s: %s" % [output_path, error_string(error)])
		quit(1)
		return
	print("CAPTURED %s (%dx%d)" % [output_path, root.size.x, root.size.y])
