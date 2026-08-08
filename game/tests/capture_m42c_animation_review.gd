extends SceneTree

const CAPTURE_SIZE := Vector2i(390, 844)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("capture_m42c_animation_review.gd requires an output directory argument")
		quit(1)
		return
	var output_dir := String(args[0]).replace("\\", "/").trim_suffix("/")
	DirAccess.make_dir_recursive_absolute(output_dir)
	root.size = CAPTURE_SIZE

	var packed_scene := load("res://presentation/battle/battle_screen.tscn") as PackedScene
	var screen := packed_scene.instantiate() as BattleScreen
	root.add_child(screen)
	await process_frame
	await process_frame
	screen.select_level_for_test(0)
	await process_frame
	var board: BattleBoardView = screen._board

	await board.play_event(BattleEvent.create(&"unit_moved", &"player", {
		"from": Vector2i(0, 7),
		"to": Vector2i(1, 6),
		"path": [Vector2i(0, 7), Vector2i(0, 6), Vector2i(1, 6)],
	}), 0.0)
	var player_animation: UnitAnimationState = board._ensure_animation(&"player")
	player_animation.begin(UnitAnimationState.ATTACK, Vector2i(0, -1))
	var attack_flash: Dictionary = board._add_impact_flash(board.grid_to_local(Vector2i(1, 5)), board.COLOR_HIT)
	board._set_attack_progress(0.52, &"player", Vector2i(0, -1), attack_flash)
	await _capture("attack_390x844.png", output_dir)

	board.sync_from_state(BattleStateFactory.create_from_level(load("res://content/levels/first_echo.tres"), 201))
	await board.play_event(BattleEvent.create(&"unit_moved", &"player", {
		"from": Vector2i(0, 7),
		"to": Vector2i(1, 6),
		"path": [Vector2i(0, 7), Vector2i(0, 6), Vector2i(1, 6)],
	}), 0.0)
	var guard_animation: UnitAnimationState = board._ensure_animation(&"guard_01")
	player_animation = board._ensure_animation(&"player")
	guard_animation.begin(UnitAnimationState.COLLISION, Vector2i(0, 1))
	player_animation.begin(UnitAnimationState.COLLISION, Vector2i(0, -1))
	var collision_flash: Dictionary = board._add_impact_flash(
		(board.grid_to_local(Vector2i(1, 5)) + board.grid_to_local(Vector2i(1, 6))) * 0.5,
		board.COLOR_COLLISION
	)
	board._add_floating_number(board.grid_to_local(Vector2i(1, 5)) - Vector2(19.0, 31.0), "-1", board.COLOR_COLLISION)
	board._add_floating_number(board.grid_to_local(Vector2i(1, 6)) + Vector2(19.0, -31.0), "-1", board.COLOR_COLLISION)
	board._set_collision_progress(0.48, &"guard_01", &"player", Vector2i(0, 1), collision_flash)
	await _capture("collision_390x844.png", output_dir)

	board.sync_from_state(BattleStateFactory.create_from_level(load("res://content/levels/collision_course.tres"), 202))
	player_animation = board._ensure_animation(&"player")
	player_animation.begin(UnitAnimationState.CRYSTALLIZE)
	var crystallize_flash: Dictionary = board._add_impact_flash(board._unit_screen_position(&"player"), board.COLOR_CRYSTALLIZE)
	board._set_crystallize_progress(0.50, &"player", crystallize_flash)
	await _capture("crystallize_390x844.png", output_dir)

	board.sync_from_state(BattleStateFactory.create_from_level(load("res://content/levels/collision_course.tres"), 203))
	guard_animation = board._ensure_animation(&"guard_01")
	guard_animation.begin(UnitAnimationState.DEATH)
	board._set_death_progress(0.58, &"guard_01")
	await _capture("death_390x844.png", output_dir)

	screen.queue_free()
	await process_frame
	quit(0)


func _capture(file_name: String, output_dir: String) -> void:
	await process_frame
	await process_frame
	var output_path := "%s/%s" % [output_dir, file_name]
	var error := root.get_texture().get_image().save_png(output_path)
	if error != OK:
		push_error("Unable to save %s: %s" % [output_path, error_string(error)])
		quit(1)
		return
	print("CAPTURED %s" % output_path)
