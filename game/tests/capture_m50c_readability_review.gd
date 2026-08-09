extends SceneTree


const ReadabilityReviewFixturesScript := preload("res://presentation/battle/readability_review_fixtures.gd")
const SIZES := [Vector2i(360, 800), Vector2i(390, 844), Vector2i(430, 932)]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("capture_m50c_readability_review.gd requires an output directory argument")
		quit(1)
		return
	var output_dir := String(args[0]).replace("\\", "/").trim_suffix("/")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var packed_scene := load("res://presentation/battle/battle_screen.tscn") as PackedScene
	for viewport_size in SIZES:
		for scenario_index in range(ReadabilityReviewFixturesScript.count()):
			root.size = viewport_size
			var screen := packed_scene.instantiate() as BattleScreen
			root.add_child(screen)
			await process_frame
			await process_frame
			if scenario_index == 0:
				screen.open_debug_overlay_for_test()
				await process_frame
				var menu_path := "%s/m50c_menu_%dx%d.png" % [output_dir, viewport_size.x, viewport_size.y]
				var menu_error := root.get_texture().get_image().save_png(menu_path)
				if menu_error != OK:
					push_error("Unable to save %s: %s" % [menu_path, error_string(menu_error)])
					quit(1)
					return
				print("CAPTURED %s" % menu_path)
				screen.close_debug_overlay_for_test()
			screen.enter_readability_review_for_test(scenario_index)
			await process_frame
			await process_frame
			var scenario := ReadabilityReviewFixturesScript.describe(scenario_index)
			var file_name := "m50c_%02d_%s_%dx%d.png" % [
				scenario_index + 1,
				String(scenario.id),
				viewport_size.x,
				viewport_size.y,
			]
			var output_path := "%s/%s" % [output_dir, file_name]
			var error := root.get_texture().get_image().save_png(output_path)
			if error != OK:
				push_error("Unable to save %s: %s" % [output_path, error_string(error)])
				quit(1)
				return
			print("CAPTURED %s" % output_path)
			if scenario_index == 4:
				screen.finish_readability_exposure_for_test()
				await process_frame
				var cover_path := "%s/m50c_cover_%dx%d.png" % [output_dir, viewport_size.x, viewport_size.y]
				error = root.get_texture().get_image().save_png(cover_path)
				if error != OK:
					push_error("Unable to save %s: %s" % [cover_path, error_string(error)])
					quit(1)
					return
				print("CAPTURED %s" % cover_path)
			screen.queue_free()
			await process_frame
	quit(0)
