extends SceneTree


func _initialize() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame

	_assert(scene.audio_manager.current_music_key == "title", "title music starts on boot")
	_assert(scene.state == scene.GameState.TITLE, "game starts on title")
	_assert(scene.selected_control_mode == scene.ControlMode.MANUAL, "manual mode is selected by default")
	_assert(scene.control_mode == scene.ControlMode.MANUAL, "manual mode is active by default")

	scene._toggle_selected_control_mode()
	_assert(scene.selected_control_mode == scene.ControlMode.AI, "title selection toggles to ai")
	scene._toggle_selected_control_mode()
	_assert(scene.selected_control_mode == scene.ControlMode.MANUAL, "title selection toggles back to manual")

	scene.reset()
	_assert(scene.state == scene.GameState.PLAYING, "reset starts play")
	_assert(scene.control_mode == scene.ControlMode.MANUAL, "manual selection starts manual play")
	_assert(scene.stage == 0, "reset loads stage 1")
	_assert(scene.swarm.enemies.size() == 24, "stage 1 enemy count")
	_assert(scene.hitstop == 0.0, "stage banner does not stop play")
	_assert(scene.audio_manager.current_music_key == "stage_drive", "reset starts stage drive music")

	scene._toggle_control_mode()
	_assert(scene.control_mode == scene.ControlMode.AI, "toggle switches play to ai")
	_assert(scene.selected_control_mode == scene.ControlMode.AI, "toggle keeps ai for next run")
	scene._toggle_control_mode()
	_assert(scene.control_mode == scene.ControlMode.MANUAL, "toggle switches play back to manual")

	scene.selected_control_mode = scene.ControlMode.AI
	scene.reset()
	_assert(scene.control_mode == scene.ControlMode.AI, "ai selection starts ai play")
	scene.projectiles.clear()
	scene.player.shot_cd = 0.0
	scene._update_game(1.0 / 60.0)
	_assert(scene.projectiles.bullets.any(func(bullet: Dictionary) -> bool: return not bullet.enemy), "ai mode fires at enemies")

	var ai_command: Dictionary = scene.ai_pilot.get_command(scene.player, scene.swarm.enemies, scene.boss_controller.boss, [], [])
	_assert(ai_command.shoot, "ai shoots when enemies are present")
	var item_x: float = scene.player.x + 120.0
	ai_command = scene.ai_pilot.get_command(scene.player, [], {}, [], [{"kind": "shield", "x": item_x, "y": scene.player.y - 120.0, "vy": 0.0, "t": 0.0}])
	_assert(ai_command.move_axis > 0.0, "ai moves toward collectible item")
	scene.player.shield = 1
	ai_command = scene.ai_pilot.get_command(scene.player, scene.swarm.enemies, scene.boss_controller.boss, [], [{"kind": "shield", "x": scene.player.x + 240.0, "y": scene.player.y - 120.0, "vy": 0.0, "t": 0.0}])
	_assert(ai_command.shoot, "ai keeps shooting instead of waiting for non-urgent item")
	scene.load_stage(4)
	scene.boss_controller.boss.x = scene.player.x + 120.0
	ai_command = scene.ai_pilot.get_command(scene.player, [], scene.boss_controller.boss, [], [])
	_assert(ai_command.shoot, "ai shoots at boss")
	_assert(ai_command.move_axis != 0.0, "ai lines up with boss")
	scene.boss_controller.boss.phase = 1
	scene.player.bombs = 3
	scene.player.bomb_cd = 0.0
	scene.boss_controller.boss.x = scene.player.x
	ai_command = scene.ai_pilot.get_command(scene.player, [], scene.boss_controller.boss, [], [])
	_assert(ai_command.bomb, "ai uses bombs during pressured boss phases")

	var bombs_before: int = scene.player.bombs
	scene._use_bomb()
	_assert(scene.player.bombs == bombs_before - 1, "bomb is consumed")
	_assert(scene.bomb_waves.size() == 1, "bomb wave is spawned")

	scene.projectiles.clear()
	scene.player.resonance = 0.0
	_assert(not scene.player.can_overdrive(), "overdrive is locked below full resonance")
	scene._fire_player()
	_assert(scene.projectiles.bullets.size() == 2, "normal shot fires two bullets")
	_assert(scene.projectiles.bullets[0].power == 1, "normal shot uses base power")

	scene.projectiles.clear()
	scene.player.resonance = 100.0
	scene._start_overdrive()
	_assert(scene.player.is_overdrive_active(), "full resonance starts overdrive")
	_assert(scene.player.resonance == 0.0, "overdrive spends resonance")
	scene._fire_player()
	_assert(scene.projectiles.bullets.size() == 3, "overdrive shot fires three bullets")
	_assert(scene.projectiles.bullets.any(func(bullet: Dictionary) -> bool: return bullet.power == 2), "overdrive shot adds high power bullet")
	scene.player.update(5.1, 0.0)
	_assert(not scene.player.is_overdrive_active(), "overdrive expires back to normal")
	scene.projectiles.clear()
	scene._fire_player()
	_assert(scene.projectiles.bullets.size() == 2, "normal shot returns after overdrive")

	scene.projectiles.clear()
	scene.player.invuln = 0.0
	scene.player.resonance = 0.0
	scene.projectiles.bullets.append({"x": scene.player.x + 50.0, "y": scene.player.y, "vx": 0.0, "vy": 0.0, "enemy": true, "r": 5.0, "power": 1, "color": Color.WHITE})
	scene._check_collisions()
	var resonance_after_graze: float = scene.player.resonance
	_assert(resonance_after_graze > 0.0, "enemy bullet graze adds resonance")
	scene._check_collisions()
	_assert(scene.player.resonance == resonance_after_graze, "enemy bullet graze is awarded once")

	scene.load_stage(0)
	_assert(scene.audio_manager.current_music_key == "stage_drive", "early stages use drive music")
	scene.swarm.enemies.clear()
	scene._check_stage_end()
	_assert(scene.stage == 1, "clearing enemies advances stage")
	scene.load_stage(2)
	_assert(scene.audio_manager.current_music_key == "stage_pressure", "later stages use pressure music")

	scene.load_stage(4)
	_assert(scene.boss_controller.is_alive(), "boss stage spawns boss")
	_assert(scene.audio_manager.current_music_key == "boss_core", "boss stage starts boss music")
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
	_assert(scene.audio_manager.current_music_key == "victory_clear", "victory starts clear music")

	scene.reset()
	scene.player.invuln = 0.0
	scene.player.lives = 1
	scene.projectiles.bullets.append({"x": scene.player.x, "y": scene.player.y, "vx": 0.0, "vy": 0.0, "enemy": true, "r": 8.0, "power": 1, "color": Color.WHITE})
	scene._check_collisions()
	_assert(scene.state == scene.GameState.GAME_OVER, "fatal hit ends run")
	_assert(scene.audio_manager.current_music_key == "game_over", "game over starts game over music")

	scene.reset()
	scene.state = scene.GameState.PAUSED
	scene.audio_manager.set_music_ducked(true)
	_assert(scene.audio_manager._music_ducked, "pause ducks music")
	scene.state = scene.GameState.PLAYING
	scene.audio_manager.set_music_ducked(false)
	_assert(not scene.audio_manager._music_ducked, "unpause restores music volume")

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
