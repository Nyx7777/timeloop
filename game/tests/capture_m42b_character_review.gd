extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("capture_m42b_character_review.gd requires an output path argument")
		quit(1)
		return

	var output_path := String(args[0]).replace("\\", "/")
	DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
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
	screen.select_level_for_test(0)
	screen.set_instant_playback_for_test()
	await screen.submit_command_for_test(BattleCommand.move(&"player", Vector2i(1, 6)))
	await screen.submit_command_for_test(BattleCommand.attack(&"player", Vector2i(1, 5)))
	await screen.submit_command_for_test(BattleCommand.end_turn(&"player"))
	await screen.submit_command_for_test(BattleCommand.start_next_timeline())
	await process_frame
	await process_frame

	var image := root.get_texture().get_image()
	var error := image.save_png(output_path)
	if error != OK:
		push_error("Unable to save %s: %s" % [output_path, error_string(error)])
		quit(1)
		return
	print("CAPTURED %s (390x844)" % output_path)
	screen.queue_free()
	await process_frame
	quit(0)
