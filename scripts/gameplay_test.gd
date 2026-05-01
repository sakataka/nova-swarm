extends SceneTree


func _initialize() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame

	scene.reset()
	_assert(scene.state == scene.GameState.PLAYING, "reset starts play")
	_assert(scene.stage == 0, "reset loads stage 1")
	_assert(scene.swarm.enemies.size() == 24, "stage 1 enemy count")
	_assert(scene.hitstop == 0.0, "stage banner does not stop play")

	var bombs_before: int = scene.player.bombs
	scene._use_bomb()
	_assert(scene.player.bombs == bombs_before - 1, "bomb is consumed")
	_assert(scene.bomb_waves.size() == 1, "bomb wave is spawned")

	scene.load_stage(0)
	scene.swarm.enemies.clear()
	scene._check_stage_end()
	_assert(scene.stage == 1, "clearing enemies advances stage")

	scene.load_stage(4)
	_assert(scene.boss_controller.is_alive(), "boss stage spawns boss")
	var boss_hp: int = scene.boss_controller.boss.hp
	scene.projectiles.bullets.append({"x": scene.boss_controller.boss.x + 220.0, "y": scene.boss_controller.boss.y, "vx": 0.0, "vy": 0.0, "enemy": false, "r": 4.0, "power": 1, "color": Color.WHITE})
	scene._check_collisions()
	_assert(scene.boss_controller.boss.hp == boss_hp, "boss edge miss does not consume bullet")
	scene.projectiles.bullets.clear()
	scene.projectiles.bullets.append({"x": scene.boss_controller.boss.x, "y": scene.boss_controller.boss.y, "vx": 0.0, "vy": 0.0, "enemy": false, "r": 4.0, "power": 1, "color": Color.WHITE})
	scene._check_collisions()
	_assert(scene.boss_controller.boss.hp == boss_hp - 1, "boss core hit applies damage")
	scene.boss_controller.boss.hp = 0
	scene._check_stage_end()
	_assert(scene.state == scene.GameState.VICTORY, "boss defeat wins")

	scene.reset()
	scene.player.invuln = 0.0
	scene.player.lives = 1
	scene.projectiles.bullets.append({"x": scene.player.x, "y": scene.player.y, "vx": 0.0, "vy": 0.0, "enemy": true, "r": 8.0, "power": 1, "color": Color.WHITE})
	scene._check_collisions()
	_assert(scene.state == scene.GameState.GAME_OVER, "fatal hit ends run")

	scene.reset()
	scene.player.lives = 2
	scene.items.append({"kind": "life", "x": scene.player.x, "y": scene.player.y, "vy": 0.0, "t": 0.0})
	scene._check_collisions()
	_assert(scene.player.lives == 3, "life item heals")

	scene.items.append({"kind": "shield", "x": scene.player.x, "y": scene.player.y, "vy": 0.0, "t": 0.0})
	scene._check_collisions()
	_assert(scene.player.shield == 1, "shield item is collected")

	root.remove_child(scene)
	scene.free()
	await process_frame
	quit()


func _assert(condition: bool, label: String) -> void:
	if condition:
		return
	push_error("Gameplay test failed: " + label)
	quit(1)
