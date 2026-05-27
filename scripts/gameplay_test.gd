extends SceneTree

const Config := preload("res://scripts/game_config.gd")


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
	var title_hitboxes: Dictionary = scene._title_mode_hitboxes(Config.HUD + 330.0)
	_assert(scene._select_title_mode_at(Rect2(title_hitboxes.ai).get_center()), "title pointer selects ai")
	_assert(scene.selected_control_mode == scene.ControlMode.AI, "mouse selection switches title mode to ai")
	_assert(scene._select_title_mode_at(Rect2(title_hitboxes.manual).get_center()), "title pointer selects manual")
	_assert(scene.selected_control_mode == scene.ControlMode.MANUAL, "mouse selection switches title mode to manual")
	scene.selected_control_mode = scene.ControlMode.AI
	_assert(scene._select_title_mode_at(scene._title_start_hitbox().get_center()), "title pointer starts game")
	_assert(scene.state == scene.GameState.PLAYING, "mouse start enters play")
	_assert(scene.control_mode == scene.ControlMode.AI, "mouse start keeps selected control mode")
	scene.state = scene.GameState.TITLE
	scene.selected_control_mode = scene.ControlMode.MANUAL

	scene.reset()
	_assert(scene.state == scene.GameState.PLAYING, "reset starts play")
	_assert(scene.control_mode == scene.ControlMode.MANUAL, "manual selection starts manual play")
	_assert(scene.stage == 0, "reset loads stage 1")
	_assert(scene.swarm.enemies.size() == 25, "stage 1 enemy count includes commander")
	_assert(scene.swarm.enemies.any(func(enemy: Dictionary) -> bool: return enemy.kind == "commander"), "stage 1 includes commander")
	_assert(scene.hitstop == 0.0, "stage banner does not stop play")
	_assert(scene.audio_manager.current_music_key == "stage_drive", "reset starts stage drive music")
	var start_y: float = scene.player.y
	scene.player.update(0.25, Vector2(0.0, -1.0))
	_assert(scene.player.y < start_y, "player can move upward")
	scene.player.update(4.0, Vector2(0.0, -1.0))
	_assert(scene.player.y >= Config.PLAYER_MIN_Y, "player vertical movement clamps to top play area")
	scene.player.update(4.0, Vector2(0.0, 1.0))
	_assert(scene.player.y <= Config.PLAYER_MAX_Y, "player vertical movement clamps to bottom play area")

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
	scene.swarm.enemies.clear()
	scene.swarm.enemies.append({"kind": "bug", "x": scene.player.x - 60.0, "y": scene.player.y - 360.0, "hp": 1, "max_hp": 1, "size": 34.0})
	ai_command = scene.ai_pilot.get_command(scene.player, scene.swarm.enemies, {}, [], [{"kind": "bomb", "x": scene.player.x + 140.0, "y": scene.player.y - 170.0, "vy": 0.0, "t": 0.0}])
	_assert(ai_command.move_axis > 0.0, "ai prioritizes item pickup before clearing final enemy")
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

	scene.player.shot_cooldown_scale = 1.0
	scene._apply_upgrade("rapid")
	_assert(scene.player.shot_cooldown_scale < 1.0, "rapid upgrade improves shot cooldown")
	scene.bomb_range_scale = 1.0
	scene._apply_upgrade("bomb_refund")
	_assert(scene.bomb_range_scale > 1.0, "bomb loop increases range")
	_assert(scene.player.bomb_refund_chance > 0.0, "bomb loop enables refunds")
	scene._apply_upgrade("spread")
	_assert(scene.player.shot_pattern == "wide", "spread upgrade changes shot pattern")
	scene._apply_upgrade("graze_core")
	_assert(scene.player.graze_chain_bonus, "graze core enables graze chain")
	scene._apply_upgrade("shield_burst")
	_assert(scene.player.shield_retaliate, "shield burst enables counter")
	scene.player.shot_pattern = "twin"

	scene.projectiles.clear()
	scene.player.resonance = 0.0
	_assert(not scene.player.can_overdrive(), "overdrive is locked below full resonance")
	scene._fire_player()
	_assert(scene.projectiles.bullets.size() == 2, "normal shot fires two bullets")
	_assert(scene.projectiles.bullets[0].power == 1, "normal shot uses base power")
	scene.projectiles.clear()
	scene.swarm.enemies.clear()
	scene.score = 0
	scene.player.combo = 0
	scene.player.combo_timer = 0.0
	scene.swarm.enemies.append({"id": 999, "kind": "bug", "x": scene.player.x, "y": scene.player.y - 220.0, "hp": 1, "max_hp": 1, "score": 120, "size": 34.0})
	scene.projectiles.bullets.append({"x": scene.player.x, "y": scene.player.y - 220.0, "vx": 0.0, "vy": 0.0, "enemy": false, "r": 6.0, "power": 1, "color": Color.WHITE})
	scene.projectiles.bullets.append({"x": scene.player.x, "y": scene.player.y - 220.0, "vx": 0.0, "vy": 0.0, "enemy": false, "r": 6.0, "power": 1, "color": Color.WHITE})
	scene._check_collisions()
	_assert(scene.score == 120, "dead enemy is scored once per frame")
	_assert(scene.swarm.enemies.is_empty(), "dead enemy is removed before later collisions")

	scene.projectiles.clear()
	scene.player.resonance = 100.0
	scene._start_overdrive()
	_assert(scene.player.is_overdrive_active(), "full resonance starts overdrive")
	_assert(scene.player.resonance == 0.0, "overdrive spends resonance")
	_assert(scene.audio_manager._music_overdriven, "overdrive raises music tension")
	_assert(scene.audio_manager.has_overdrive_music_layer("stage_drive"), "stage drive has an overdrive music layer")
	scene._fire_player()
	_assert(scene.projectiles.bullets.size() == 3, "overdrive shot fires three bullets")
	_assert(scene.projectiles.bullets.any(func(bullet: Dictionary) -> bool: return bullet.power == 2), "overdrive shot adds high power bullet")
	scene.projectiles.bullets.append({"x": scene.player.x + 24.0, "y": scene.player.y - 90.0, "vx": 0.0, "vy": 0.0, "enemy": true, "r": 5.0, "power": 1, "color": Color.WHITE})
	scene._update_stage_gimmicks(1.0 / 60.0)
	_assert(scene.score_crystals.size() > 0, "overdrive converts nearby enemy bullets into score crystals")
	scene.player.update(5.1, Vector2.ZERO)
	_assert(not scene.player.is_overdrive_active(), "overdrive expires back to normal")
	scene._update_overdrive_feedback()
	_assert(not scene.audio_manager._music_overdriven, "overdrive music layer drops out after expiry")
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
	var commander: Dictionary = scene.swarm.enemies.filter(func(enemy: Dictionary) -> bool: return enemy.kind == "commander")[0]
	scene.player.resonance = 0.0
	var items_before_commander: int = scene.items.size()
	scene._handle_commander_defeat(commander)
	_assert(scene.player.resonance > 0.0, "commander defeat adds resonance")
	_assert(scene.items.size() == items_before_commander + 1, "commander drops reward item")
	scene.swarm.enemies.clear()
	scene._check_stage_end()
	_assert(scene.state == scene.GameState.UPGRADE, "clearing enemies enters upgrade state")
	_assert(scene.stage_results.size() == 1, "stage result is recorded")
	_assert(["SSS", "SS", "S", "A", "B", "C"].has(scene.stage_results[0].rank), "stage result has rank")
	_assert(scene.upgrade_options.size() == 3, "upgrade state rolls three choices")
	scene._apply_selected_upgrade()
	_assert(scene.stage == 1, "upgrade confirmation advances stage")
	_assert(scene.state == scene.GameState.PLAYING, "upgrade confirmation resumes play")
	scene.load_stage(2)
	_assert(scene.audio_manager.current_music_key == "stage_pressure", "later stages use pressure music")
	_assert(scene.stage_hazards.any(func(hazard: Dictionary) -> bool: return hazard.kind == "rock"), "rock belt spawns rock hazards")
	scene.stage_hazards.clear()
	scene.stage_hazards.append({"kind": "rock", "x": 240.0, "y": Config.HUD + 150.0, "r": 28.0, "hp": 1, "t": 0.0, "seed": 42})
	scene.projectiles.clear()
	scene.score = 0
	scene.projectiles.bullets.append({"x": 240.0, "y": Config.HUD + 150.0, "vx": 0.0, "vy": 0.0, "enemy": false, "r": 6.0, "power": 1, "color": Color.WHITE})
	scene.projectiles.bullets.append({"x": 240.0, "y": Config.HUD + 150.0, "vx": 0.0, "vy": 0.0, "enemy": false, "r": 6.0, "power": 1, "color": Color.WHITE})
	scene._check_rock_collisions()
	_assert(scene.score == 340, "destroyed rock is scored once per frame")
	_assert(scene.stage_hazards.is_empty(), "destroyed rock is removed before later collisions")
	scene.load_stage(3)
	_assert(scene.stage_hazards.any(func(hazard: Dictionary) -> bool: return str(hazard.kind).begins_with("plasma")), "plasma nest spawns reflectors")
	scene.load_stage(1)
	var diver: Dictionary = scene.swarm.enemies.filter(func(enemy: Dictionary) -> bool: return enemy.kind == "diver")[0]
	diver.dive = 1.0
	diver.x = 18.0
	var dive_preview_left: float = scene._enemy_dive_preview_end_x(diver)
	_assert(dive_preview_left >= 36.0, "dive preview clamps to left playfield")
	diver.x = Config.W - 18.0
	var dive_preview_right: float = scene._enemy_dive_preview_end_x(diver)
	_assert(dive_preview_right <= Config.W - 36.0, "dive preview clamps to right playfield")
	scene.queue_redraw()
	await process_frame

	scene.load_stage(4)
	_assert(scene.boss_controller.is_alive(), "boss stage spawns boss")
	_assert(scene.boss_controller.boss.has("parts"), "boss has breakable parts")
	_assert(scene.audio_manager.current_music_key == "boss_core", "boss stage starts boss music")
	_assert(scene.audio_manager.has_overdrive_music_layer("boss_core"), "boss stage has an overdrive music layer")
	scene.boss_controller.boss.tell = 0.45
	var beam_preview: Rect2 = scene._boss_beam_preview_rect()
	_assert(beam_preview.position.x < scene.boss_controller.boss.x and beam_preview.end.x > scene.boss_controller.boss.x, "boss beam preview covers boss lane")
	_assert(beam_preview.position.y > scene.boss_controller.boss.y and beam_preview.end.y == Config.H, "boss beam preview reaches playfield bottom")
	scene.queue_redraw()
	await process_frame
	scene.boss_controller.boss.tell = 0.0
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
	_assert(scene.stage_results.any(func(result: Dictionary) -> bool: return int(result.stage) == 4), "boss result is recorded")

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
