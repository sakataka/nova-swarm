extends SceneTree


func _initialize() -> void:
	seed(20260502)
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame

	scene.selected_control_mode = scene.ControlMode.AI
	scene.reset()
	scene.load_stage(4)
	_assert(scene.stage == 4, "boss test starts at stage 5")
	_assert(scene.control_mode == scene.ControlMode.AI, "stage 5 boss test uses ai control")
	_assert(scene.boss_controller.is_alive(), "stage 5 boss is alive")

	_assert_beam_tell_escape(scene)
	_assert_beam_projectile_escape(scene)
	_assert_pressure_bomb(scene)
	await _assert_stage5_survival(scene, 24.0)

	root.remove_child(scene)
	scene.free()
	await process_frame
	quit()


func _assert_beam_tell_escape(scene: Node) -> void:
	scene.projectiles.clear()
	scene.player.bombs = 3
	scene.player.bomb_cd = 0.0
	scene.boss_controller.boss.phase = 1
	scene.boss_controller.boss.tell = 0.45
	scene.boss_controller.boss.x = scene.player.x
	var command: Dictionary = scene.ai_pilot.get_command(scene.player, [], scene.boss_controller.boss, [], [])
	_assert(absf(float(command.move_axis)) > 0.35, "ai moves laterally during boss beam tell")
	_assert(command.bomb, "ai bombs when centered under a boss beam tell")


func _assert_beam_projectile_escape(scene: Node) -> void:
	scene.projectiles.clear()
	scene.player.bombs = 0
	scene.player.bomb_cd = 0.0
	scene.boss_controller.boss.phase = 1
	scene.boss_controller.boss.tell = 0.0
	scene.boss_controller.boss.x = scene.player.x
	scene.projectiles.bullets.append({"x": scene.player.x, "y": scene.player.y - 210.0, "vx": 0.0, "vy": 360.0, "enemy": true, "r": 14.0, "power": 1, "color": Color.WHITE, "sprite": "beam"})
	var command: Dictionary = scene.ai_pilot.get_command(scene.player, [], scene.boss_controller.boss, scene.projectiles.bullets, [])
	_assert(absf(float(command.move_axis)) > 0.35, "ai moves laterally away from active boss beam")


func _assert_pressure_bomb(scene: Node) -> void:
	scene.projectiles.clear()
	scene.player.bombs = 1
	scene.player.bomb_cd = 0.0
	scene.boss_controller.boss.phase = 2
	scene.boss_controller.boss.tell = 0.0
	scene.boss_controller.boss.x = scene.player.x
	for offset in [-26.0, 0.0, 26.0]:
		scene.projectiles.bullets.append({"x": scene.player.x + offset, "y": scene.player.y - 126.0, "vx": 0.0, "vy": 260.0, "enemy": true, "r": 6.0, "power": 1, "color": Color.WHITE, "sprite": "boss"})
	var command: Dictionary = scene.ai_pilot.get_command(scene.player, [], scene.boss_controller.boss, scene.projectiles.bullets, [])
	_assert(command.bomb, "ai uses last bomb under heavy boss pressure")


func _assert_stage5_survival(scene: Node, seconds: float) -> void:
	scene.projectiles.clear()
	scene.load_stage(4)
	scene.player.bombs = 3
	scene.player.shield = 0
	scene.player.invuln = 0.0
	var frames := int(seconds * 60.0)
	var damage_taken := 0
	var previous_lives: int = scene.player.lives
	var previous_shield: int = scene.player.shield
	for _i in range(frames):
		scene._process(1.0 / 60.0)
		if scene.player.lives < previous_lives or scene.player.shield < previous_shield:
			damage_taken += 1
		previous_lives = scene.player.lives
		previous_shield = scene.player.shield
		await process_frame
		if scene.state == scene.GameState.GAME_OVER or scene.state == scene.GameState.VICTORY:
			break
	_assert(scene.state != scene.GameState.GAME_OVER, "ai survives stage 5 boss opening")
	_assert(damage_taken <= 1, "ai keeps boss opening damage controlled")


func _assert(condition: bool, label: String) -> void:
	if condition:
		return
	push_error("AI boss stage 5 test failed: " + label)
	quit(1)
