extends SceneTree

const Config := preload("res://scripts/game_config.gd")


func _initialize() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame

	_assert(scene.audio_manager.current_music_key == "title", "title music starts on boot")
	scene.audio_manager._pending_music_key = ""
	scene.audio_manager.replay_current_music()
	_assert(scene.audio_manager._pending_music_key == "title", "title music is queued again after browser interaction")
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
	var title_touch := InputEventScreenTouch.new()
	title_touch.index = 1
	title_touch.pressed = true
	title_touch.position = Rect2(title_hitboxes.ai).get_center()
	_assert(scene._handle_title_pointer_input(title_touch), "title touch selects ai")
	_assert(scene.selected_control_mode == scene.ControlMode.AI, "touch selection switches title mode to ai")
	title_touch.position = Rect2(title_hitboxes.manual).get_center()
	_assert(scene._handle_title_pointer_input(title_touch), "title touch selects manual")
	_assert(scene.selected_control_mode == scene.ControlMode.MANUAL, "touch selection switches title mode back to manual")
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
	_assert(scene.swarm.enemies.size() == 21, "stage 1 starts with a compact first wave")
	_assert(not scene.swarm.enemies.any(func(enemy: Dictionary) -> bool: return enemy.kind == "commander"), "commander is reserved for the final wave")
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

	scene.touch_controls_forced = true
	var move_touch := InputEventScreenTouch.new()
	move_touch.index = 4
	move_touch.pressed = true
	move_touch.position = scene._touch_move_center()
	_assert(scene._handle_touch_controls_input(move_touch), "touch move pad starts")
	var move_drag := InputEventScreenDrag.new()
	move_drag.index = 4
	move_drag.position = scene._touch_move_center() + Vector2(52.0, -38.0)
	_assert(scene._handle_touch_controls_input(move_drag), "touch move pad drags")
	var touch_command: Dictionary = scene._read_player_command()
	_assert(touch_command.move_vector.x > 0.3 and touch_command.move_vector.y < -0.2, "touch move vector feeds manual command")
	var shoot_touch := InputEventScreenTouch.new()
	shoot_touch.index = 5
	shoot_touch.pressed = true
	shoot_touch.position = Rect2(scene._touch_button_hitboxes().shoot).get_center()
	_assert(scene._handle_touch_controls_input(shoot_touch), "touch shot button starts")
	touch_command = scene._read_player_command()
	_assert(touch_command.shoot, "touch shot feeds manual command")
	var overdrive_touch := InputEventScreenTouch.new()
	overdrive_touch.index = 6
	overdrive_touch.pressed = true
	overdrive_touch.position = Rect2(scene._touch_button_hitboxes().overdrive).get_center()
	_assert(scene._handle_touch_controls_input(overdrive_touch), "touch overdrive button starts")
	touch_command = scene._read_player_command()
	_assert(touch_command.overdrive, "touch overdrive is queued once")
	touch_command = scene._read_player_command()
	_assert(not touch_command.overdrive, "touch overdrive queue is consumed")
	var pause_touch := InputEventScreenTouch.new()
	pause_touch.index = 7
	pause_touch.pressed = true
	pause_touch.position = scene._touch_pause_hitbox().get_center()
	_assert(scene._handle_touch_controls_input(pause_touch), "touch pause button pauses")
	_assert(scene.state == scene.GameState.PAUSED, "touch pause enters pause state")
	_assert(scene._handle_touch_controls_input(pause_touch), "touch pause button resumes")
	_assert(scene.state == scene.GameState.PLAYING, "touch pause resumes play")
	move_touch.pressed = false
	_assert(scene._handle_touch_controls_input(move_touch), "touch move pad releases")
	shoot_touch.pressed = false
	_assert(scene._handle_touch_controls_input(shoot_touch), "touch shot button releases")

	scene.selected_control_mode = scene.ControlMode.AI
	scene.reset()
	_assert(scene.control_mode == scene.ControlMode.AI, "ai selection starts ai play")
	_assert(scene.font != ThemeDB.fallback_font, "embedded Oxanium font replaces the system fallback")
	_assert(scene.overdrive_mote_texture != null, "overdrive aura texture is loaded")
	_assert(scene.score_crystal_texture != null, "score crystal atlas is loaded")
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
	scene.load_stage(5)
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

	scene.ai_pilot.reset()
	scene.load_stage(0)
	scene.player.x = Config.W * 0.5
	scene.player.y = Config.PLAYER_Y
	var power_item := {"kind": "power", "x": scene.player.x + 150.0, "y": scene.player.y - 130.0, "vy": 0.0, "t": 0.0}
	ai_command = scene.ai_pilot.get_command(scene.player, scene.swarm.enemies, {}, [], [power_item])
	_assert(ai_command.move_axis > 0.0, "ai safely pursues combat growth chips")

	scene.ai_pilot.reset()
	var diving_enemy := {"id": 991, "kind": "diver", "x": scene.player.x, "y": scene.player.y - 170.0, "hp": 2, "max_hp": 2, "size": 44.0, "dive": 1.0, "t": 0.4}
	ai_command = scene.ai_pilot.get_command(scene.player, [diving_enemy], {}, [], [])
	_assert(Vector2(ai_command.move_vector).length() > 0.35, "ai escapes a predicted diving-enemy path")

	scene.ai_pilot.reset()
	scene.player.bombs = 1
	scene.player.bomb_cd = 0.0
	var moderate_bullet := {"x": scene.player.x + 82.0, "y": scene.player.y - 210.0, "vx": 0.0, "vy": 220.0, "enemy": true, "r": 5.0, "power": 1, "color": Color.WHITE, "sprite": "enemy"}
	ai_command = scene.ai_pilot.get_command(scene.player, scene.swarm.enemies, {}, [moderate_bullet], [])
	_assert(not ai_command.bomb, "ai preserves its last bomb when a normal-wave escape lane exists")

	scene.ai_pilot.reset()
	var lethal_bullets := []
	for offset in [-24.0, 0.0, 24.0]:
		lethal_bullets.append({"x": scene.player.x + offset, "y": scene.player.y - 58.0, "vx": 0.0, "vy": 260.0, "enemy": true, "r": 8.0, "power": 1, "color": Color.WHITE, "sprite": "enemy"})
	ai_command = scene.ai_pilot.get_command(scene.player, scene.swarm.enemies, {}, lethal_bullets, [])
	_assert(ai_command.bomb, "ai spends its last bomb when immediate normal-wave pressure is lethal")

	var bombs_before: int = scene.player.bombs
	scene._use_bomb()
	_assert(scene.player.bombs == bombs_before - 1, "bomb is consumed")
	_assert(scene.bomb_waves.size() == 1, "bomb wave is spawned")

	_assert(not scene.player.collect_chip("power"), "first power chip adds partial progress")
	_assert(not scene.player.collect_chip("power"), "second power chip remains partial")
	_assert(scene.player.collect_chip("power"), "third power chip levels the weapon")
	_assert(scene.player.chip_levels.power == 1, "power level is tracked during combat")
	_assert(scene.player.shot_cooldown_scale < 1.0, "power level improves shot cooldown")
	for _i in range(3):
		scene.player.collect_chip("spread")
	_assert(scene.player.shot_pattern == "wide", "spread chips change the live shot pattern")
	for _i in range(6):
		scene.player.collect_chip("resonance")
	_assert(scene.player.resonance_gain_scale > 1.0, "resonance chips improve gauge gain")
	scene.player.reset_combat_growth()

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
	scene._start_wave(int(Config.STAGES[0].waves) - 1)
	var commander: Dictionary = scene.swarm.enemies.filter(func(enemy: Dictionary) -> bool: return enemy.kind == "commander")[0]
	scene.player.resonance = 0.0
	var items_before_commander: int = scene.items.size()
	scene._handle_commander_defeat(commander)
	_assert(scene.player.resonance > 0.0, "commander defeat adds resonance")
	_assert(scene.items.size() == items_before_commander + 1, "commander drops reward item")
	scene.swarm.enemies.clear()
	scene._check_stage_end()
	_assert(scene.stage_transition_timer > 0.0, "final wave clear schedules a seamless stage transition")
	_assert(scene.state == scene.GameState.PLAYING, "stage clear never opens an upgrade menu")
	_assert(scene.stage_results.size() == 1, "stage result is recorded without interrupting play")
	scene._update_stage_progression(2.0)
	_assert(scene.stage == 1, "seamless transition advances to stage 2")
	scene.load_stage(3)
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
	scene.load_stage(4)
	_assert(scene.stage_hazards.any(func(hazard: Dictionary) -> bool: return str(hazard.kind).begins_with("plasma")), "plasma nest spawns reflectors")
	scene.load_stage(2)
	scene._start_wave(int(Config.STAGES[2].waves) - 1)
	_assert(scene.swarm.enemies.filter(func(enemy: Dictionary) -> bool: return str(enemy.kind).begins_with("mid_")).size() == 2, "stage 3 final wave spawns twin midbosses")
	scene.load_stage(4)
	scene._start_wave(int(Config.STAGES[4].waves) - 1)
	_assert(scene.swarm.enemies.filter(func(enemy: Dictionary) -> bool: return str(enemy.kind).begins_with("mid_")).size() == 3, "stage 5 final wave spawns a midboss trio")
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

	scene.load_stage(5)
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
	_assert(scene.stage_results.any(func(result: Dictionary) -> bool: return int(result.stage) == 5), "stage 6 boss result is recorded")

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
	scene.audio_manager.set_app_active(false)
	_assert(not scene.audio_manager._app_active, "backgrounding deactivates audio")
	_assert(scene.audio_manager.current_music_key == "stage_drive", "backgrounding preserves the current music key")
	scene.audio_manager.set_app_active(true)
	_assert(scene.audio_manager._app_active, "foregrounding reactivates audio")

	scene.player.lives = 2
	scene.items.append({"kind": "life", "x": scene.player.x, "y": scene.player.y, "vy": 0.0, "t": 0.0})
	scene._check_collisions()
	_assert(scene.player.lives == 3, "life item heals")

	scene.items.append({"kind": "shield", "x": scene.player.x, "y": scene.player.y, "vy": 0.0, "t": 0.0})
	scene._check_collisions()
	_assert(scene.player.shield == 1, "shield item is collected")

	scene.items.append({"kind": "power", "x": scene.player.x, "y": scene.player.y, "vy": 0.0, "t": 0.0})
	scene._check_collisions()
	_assert(scene.player.chip_progress.power == 1, "combat chip is collected without pausing")

	root.remove_child(scene)
	scene.free()
	await process_frame
	quit()


func _assert(condition: bool, label: String) -> void:
	if condition:
		return
	push_error("Gameplay test failed: " + label)
	quit(1)
