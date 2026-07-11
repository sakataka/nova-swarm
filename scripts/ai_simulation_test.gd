extends SceneTree

const DEFAULT_SECONDS := 720.0
const DEFAULT_SEED := 20260501
const DEFAULT_MIN_STAGE := 1
const DEFAULT_START_STAGE := 1


func _initialize() -> void:
	var options := _read_options()
	seed(options.seed)
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	scene.set_physics_process(false)

	seed(options.seed)
	scene.selected_control_mode = scene.ControlMode.AI
	scene.reset()
	if options.start_stage > 0:
		scene.load_stage(options.start_stage)
	var frames := int(options.seconds * 60.0)
	var last_stage: int = scene.stage
	var damage_taken := 0
	var previous_lives: int = scene.player.lives
	var previous_shield: int = scene.player.shield
	var frames_elapsed := 0

	for i in range(frames):
		frames_elapsed = i + 1
		scene._process(1.0 / 60.0)
		if scene.stage != last_stage:
			last_stage = scene.stage
			print("AI_SIM_STAGE stage=", scene.stage + 1, " frame=", i, " score=", scene.score)
		if scene.player.lives < previous_lives or scene.player.shield < previous_shield:
			damage_taken += 1
		previous_lives = scene.player.lives
		previous_shield = scene.player.shield
		if i % 30 == 0:
			await process_frame
		if scene.state == scene.GameState.GAME_OVER or scene.state == scene.GameState.VICTORY:
			break

	var result := {
		"state": _state_name(scene),
		"stage": scene.stage + 1,
		"score": scene.score,
		"lives": scene.player.lives,
		"bombs": scene.player.bombs,
		"shield": scene.player.shield,
		"damage": damage_taken,
		"seed": options.seed,
		"seconds": options.seconds,
		"start_stage": options.start_stage + 1,
		"elapsed_seconds": snappedf(float(frames_elapsed) / 60.0, 0.01),
	}
	print("AI_SIM_RESULT ", JSON.stringify(result))
	var passed: bool = scene.state != scene.GameState.GAME_OVER and scene.stage >= options.min_stage

	root.remove_child(scene)
	scene.free()
	await process_frame
	quit(0 if passed else 1)


func _read_options() -> Dictionary:
	var options := {"seconds": DEFAULT_SECONDS, "seed": DEFAULT_SEED, "min_stage": DEFAULT_MIN_STAGE, "start_stage": DEFAULT_START_STAGE - 1}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seconds="):
			options.seconds = maxf(1.0, float(arg.trim_prefix("--seconds=")))
		elif arg.begins_with("--seed="):
			options.seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--min-stage="):
			options.min_stage = maxi(0, int(arg.trim_prefix("--min-stage=")) - 1)
		elif arg.begins_with("--start-stage="):
			options.start_stage = clampi(int(arg.trim_prefix("--start-stage=")) - 1, 0, 5)
	return options


func _state_name(scene: Node) -> String:
	if scene.state == scene.GameState.TITLE:
		return "TITLE"
	if scene.state == scene.GameState.PLAYING:
		return "PLAYING"
	if scene.state == scene.GameState.PAUSED:
		return "PAUSED"
	if scene.state == scene.GameState.GAME_OVER:
		return "GAME_OVER"
	if scene.state == scene.GameState.VICTORY:
		return "VICTORY"
	return "UNKNOWN"
