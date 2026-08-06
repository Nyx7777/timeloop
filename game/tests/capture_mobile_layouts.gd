extends SceneTree

const CASES := [
	{"name": "mobile_360x800.png", "size": Vector2i(360, 800)},
	{"name": "mobile_390x844.png", "size": Vector2i(390, 844)},
	{"name": "mobile_430x932.png", "size": Vector2i(430, 932)},
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("capture_mobile_layouts.gd requires an output directory argument")
		quit(1)
		return
	var output_dir := String(args[0]).replace("\\", "/").trim_suffix("/")
	var level_index := int(args[1]) if args.size() > 1 else 0
	var capture_cases: Array = CASES.duplicate(true)
	if args.size() > 2:
		capture_cases.clear()
		for size_text in String(args[2]).split(",", false):
			var parts := size_text.to_lower().split("x", false)
			if parts.size() != 2:
				push_error("Invalid capture size: %s" % size_text)
				quit(1)
				return
			var capture_size := Vector2i(int(parts[0]), int(parts[1]))
			capture_cases.append({"name": "custom_%dx%d.png" % [capture_size.x, capture_size.y], "size": capture_size})
	DirAccess.make_dir_recursive_absolute(output_dir)

	var packed_scene := load("res://presentation/battle/battle_screen.tscn") as PackedScene
	if packed_scene == null:
		push_error("Unable to load the battle screen")
		quit(1)
		return

	for layout_case in capture_cases:
		root.size = layout_case.size
		var screen := packed_scene.instantiate() as BattleScreen
		root.add_child(screen)
		await process_frame
		await process_frame
		screen.select_level_for_test(level_index)
		await process_frame
		await process_frame
		var image := root.get_texture().get_image()
		var output_path := "%s/%s" % [output_dir, layout_case.name]
		var error := image.save_png(output_path)
		if error != OK:
			push_error("Unable to save %s: %s" % [output_path, error_string(error)])
			screen.queue_free()
			quit(1)
			return
		print("CAPTURED %s (%dx%d)" % [output_path, layout_case.size.x, layout_case.size.y])
		screen.queue_free()
		await process_frame

	quit(0)
