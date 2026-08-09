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
	screen.open_debug_overlay_for_test()
	await _capture("%s/m50a_boss_review_entry.png" % output_dir)
	screen.close_debug_overlay_for_test()

	# Maximum-information representative: T3, two ghosts, four enemies, mixed
	# temporal states, an available attack, and the Boss + Build review rail.
	screen.enter_boss_build_review_for_test()
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
