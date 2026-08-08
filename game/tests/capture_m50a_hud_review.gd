extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("capture_m50a_hud_review.gd requires an output directory argument")
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

	# T1: unknown time, no fixed or awake enemies, crystallize locked.
	screen.select_level_for_test(5)
	screen.set_action_mode_for_test(&"move")
	await _capture(screen, "%s/m50a_t1_unknown.png" % output_dir)

	# T2: the first known-time history exposes one fixed enemy.
	screen.select_level_for_test(0)
	await screen.submit_command_for_test(BattleCommand.move(&"player", Vector2i(1, 6)))
	await screen.submit_command_for_test(BattleCommand.attack(&"player", Vector2i(1, 5)))
	await screen.submit_command_for_test(BattleCommand.end_turn(&"player"))
	await screen.submit_command_for_test(BattleCommand.start_next_timeline())
	await _capture(screen, "%s/m50a_t2_fixed.png" % output_dir)

	# Mixed-time presentation fixture: the same enemy has now left fixed history.
	var mixed_state := BattleState.from_dict(screen.get_state_snapshot_for_test())
	mixed_state.get_unit(&"guard_01").statuses["disturbed"] = true
	mixed_state.get_unit(&"guard_01").statuses["awake_from_turn"] = mixed_state.turn_index
	mixed_state.locked_enemy_intents[0]["reactive"] = true
	mixed_state.time_state = &"disturbed"
	screen.set_state_for_test(mixed_state)
	await _capture(screen, "%s/m50a_t2_awake.png" % output_dir)

	screen.queue_free()
	await process_frame
	quit(0)


func _capture(screen: BattleScreen, output_path: String) -> void:
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var error := image.save_png(output_path)
	if error != OK:
		push_error("Unable to save %s: %s" % [output_path, error_string(error)])
		quit(1)
		return
	print("CAPTURED %s (%dx%d)" % [output_path, root.size.x, root.size.y])
