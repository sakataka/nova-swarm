extends Node2D
class_name GameController

const AudioManagerScript := preload("res://scripts/audio_manager.gd")
const Config := preload("res://scripts/game_config.gd")
const PlayerScript := preload("res://scripts/player.gd")
const ProjectileManagerScript := preload("res://scripts/projectile_manager.gd")
const EnemySwarmScript := preload("res://scripts/enemy_swarm.gd")
const BossControllerScript := preload("res://scripts/boss_controller.gd")
const HudScript := preload("res://scripts/hud.gd")
const AiPilotScript := preload("res://scripts/ai_pilot.gd")

enum GameState { TITLE, PLAYING, PAUSED, GAME_OVER, VICTORY }
enum ControlMode { MANUAL, AI }

var state := GameState.TITLE
var selected_control_mode := ControlMode.MANUAL
var control_mode := ControlMode.MANUAL
var stage := 0
var score := 0
var stage_timer := 0.0
var difficulty := 1.0
var screen_shake := 0.0
var flash := 0.0
var hitstop := 0.0
var stage_banner := 0.0
var overdrive_zoom := 1.0
var pending_stage := 0
var stage_wave := 0
var wave_transition_timer := 0.0
var stage_transition_timer := 0.0
var stage_results: Array[Dictionary] = []
var _stage_start_score := 0
var _stage_start_time := 0.0
var _stage_damage := 0
var _stage_bombs_used := 0
var _stage_max_combo := 0
var touch_controls_available := false
var touch_controls_forced := false
var touch_move_index := -1
var touch_move_origin := Vector2.ZERO
var touch_move_vector := Vector2.ZERO
var touch_button_indices := {"shoot": -1, "bomb": -1, "overdrive": -1}
var touch_button_pressed := {"shoot": false, "bomb": false}
var touch_overdrive_queued := false

var player = PlayerScript.new()
var projectiles = ProjectileManagerScript.new()
var swarm = EnemySwarmScript.new()
var boss_controller = BossControllerScript.new()
var hud = HudScript.new()
var ai_pilot = AiPilotScript.new()
var audio_manager

var explosions: Array[Dictionary] = []
var bomb_waves: Array[Dictionary] = []
var items: Array[Dictionary] = []
var stage_hazards: Array[Dictionary] = []
var score_crystals: Array[Dictionary] = []
var sprite_texture: Texture2D
var background_texture: Texture2D
var ui_texture: Texture2D
var ui_chrome_texture: Texture2D
var commander_texture: Texture2D
var commander_fx_texture: Texture2D
var rock_obstacle_texture: Texture2D
var projectile_texture: Texture2D
var final_boss_texture: Texture2D
var boss_weakpoint_texture: Texture2D
var enemy_fleet_texture: Texture2D
var player_ship_texture: Texture2D
var font: Font
var overdrive_aura: CPUParticles2D
var overdrive_burst: CPUParticles2D
var sprites: Dictionary = Config.sprites()
var ui_regions := {
	"logo": Rect2(105, 44, 1045, 320),
	"life": Rect2(165, 391, 248, 248),
	"bomb": Rect2(504, 391, 248, 248),
	"shield": Rect2(844, 391, 248, 248),
	"banner": Rect2(109, 685, 1038, 148),
	"ending": Rect2(97, 849, 1060, 334),
}
var ui_chrome_regions := {
	"panel": Rect2(0, 0, 192, 72),
	"core": Rect2(208, 0, 96, 96),
	"warning": Rect2(320, 0, 64, 64),
	"shot": Rect2(0, 112, 72, 72),
	"bomb": Rect2(80, 112, 72, 72),
	"overdrive": Rect2(160, 112, 72, 72),
	"pause": Rect2(240, 112, 72, 72),
}


func _ready() -> void:
	randomize()
	_setup_native_window()
	_setup_runtime_models()
	touch_controls_available = _detect_touch_controls_available()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	font = ThemeDB.fallback_font
	sprite_texture = _load_sprite_texture()
	background_texture = load("res://public/assets/renewal/background_atlas.png")
	ui_texture = _load_imported_or_png_texture("res://public/assets/ui_atlas.png")
	ui_chrome_texture = _load_png_texture("res://public/assets/ui_chrome.png")
	commander_texture = _load_imported_or_png_texture("res://public/assets/commander.png")
	commander_fx_texture = _load_imported_or_png_texture("res://public/assets/commander_fx.png")
	rock_obstacle_texture = _load_imported_or_png_texture("res://public/assets/rock_obstacle.png")
	projectile_texture = _load_imported_or_png_texture("res://public/assets/projectile_atlas.png")
	final_boss_texture = _load_imported_or_png_texture("res://public/assets/renewal/final_boss.png")
	boss_weakpoint_texture = _load_imported_or_png_texture("res://public/assets/boss_weakpoints.png")
	enemy_fleet_texture = _load_imported_or_png_texture("res://public/assets/renewal/enemy_fleet.png")
	player_ship_texture = _load_imported_or_png_texture("res://public/assets/renewal/player_ship.png")
	audio_manager = AudioManagerScript.new()
	add_child(audio_manager)
	_setup_overdrive_particles()
	audio_manager.play_music("title", 0.25)
	_parse_web_query()
	queue_redraw()


func _exit_tree() -> void:
	if audio_manager and audio_manager.has_method("shutdown"):
		audio_manager.shutdown()


func _setup_runtime_models() -> void:
	player.setup(Config.W / 2.0, Config.PLAYER_Y, 42.0, Config.W - 42.0, Config.PLAYER_MIN_Y, Config.PLAYER_MAX_Y)
	projectiles.setup(Config.W, Config.H, Config.HUD)
	swarm.setup(Config.W, Config.HUD)
	boss_controller.setup(Config.W, Config.HUD)


func _setup_overdrive_particles() -> void:
	overdrive_aura = CPUParticles2D.new()
	overdrive_aura.name = "OverdriveAura"
	overdrive_aura.amount = 42
	overdrive_aura.lifetime = 0.5
	overdrive_aura.local_coords = false
	overdrive_aura.emitting = false
	overdrive_aura.direction = Vector2(0, -1)
	overdrive_aura.spread = 180.0
	overdrive_aura.gravity = Vector2.ZERO
	overdrive_aura.initial_velocity_min = 26.0
	overdrive_aura.initial_velocity_max = 96.0
	overdrive_aura.scale_amount_min = 1.4
	overdrive_aura.scale_amount_max = 3.8
	overdrive_aura.color = Color(1.0, 0.74, 0.2, 0.72)
	add_child(overdrive_aura)

	overdrive_burst = CPUParticles2D.new()
	overdrive_burst.name = "OverdriveBurst"
	overdrive_burst.amount = 90
	overdrive_burst.lifetime = 0.42
	overdrive_burst.one_shot = true
	overdrive_burst.explosiveness = 0.95
	overdrive_burst.local_coords = false
	overdrive_burst.emitting = false
	overdrive_burst.direction = Vector2(0, -1)
	overdrive_burst.spread = 180.0
	overdrive_burst.gravity = Vector2.ZERO
	overdrive_burst.initial_velocity_min = 130.0
	overdrive_burst.initial_velocity_max = 310.0
	overdrive_burst.scale_amount_min = 2.0
	overdrive_burst.scale_amount_max = 5.0
	overdrive_burst.color = Color(1.0, 0.34, 0.92, 0.78)
	add_child(overdrive_burst)


func _setup_native_window() -> void:
	if OS.get_name() == "Web":
		return
	var window_size := Vector2i(int(Config.W * 2.0), int(Config.H * 2.0))
	DisplayServer.window_set_size(window_size)
	var screen_size := DisplayServer.screen_get_size()
	DisplayServer.window_set_position(Vector2i(
		int((screen_size.x - window_size.x) * 0.5),
		int((screen_size.y - window_size.y) * 0.5)
	))


func _process(delta: float) -> void:
	var dt: float = min(delta, 0.033)
	if hitstop > 0.0:
		hitstop = maxf(0.0, hitstop - dt)
		_update_feedback(dt)
		audio_manager.update_music(dt)
		queue_redraw()
		return
	if state == GameState.PLAYING:
		_update_game(dt)
	_update_feedback(dt)
	audio_manager.update_music(dt)
	queue_redraw()


func _update_feedback(dt: float) -> void:
	screen_shake = maxf(0.0, screen_shake - dt * 26.0)
	flash = maxf(0.0, flash - dt * 3.8)
	stage_banner = maxf(0.0, stage_banner - dt)


func _unhandled_input(event: InputEvent) -> void:
	if _handle_title_pointer_input(event):
		get_viewport().set_input_as_handled()
	elif _handle_touch_controls_input(event):
		get_viewport().set_input_as_handled()
	elif state == GameState.TITLE and (event.is_action_pressed("move_left") or event.is_action_pressed("move_right")):
		_toggle_selected_control_mode()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") and state in [GameState.TITLE, GameState.GAME_OVER, GameState.VICTORY]:
		reset()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause_game") and state == GameState.PLAYING:
		state = GameState.PAUSED
		audio_manager.set_music_ducked(true)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause_game") and state == GameState.PAUSED:
		state = GameState.PLAYING
		audio_manager.set_music_ducked(false)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("mute_audio"):
		audio_manager.toggle_mute()
		get_viewport().set_input_as_handled()


func _handle_title_pointer_input(event: InputEvent) -> bool:
	if state != GameState.TITLE:
		return false
	var position: Variant = _pointer_press_position(event)
	if position == null:
		return false
	return _select_title_mode_at(position)


func _pointer_press_position(event: InputEvent) -> Variant:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			return mouse_event.position
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			return touch_event.position
	return null


func _handle_touch_controls_input(event: InputEvent) -> bool:
	if not _touch_controls_enabled():
		return false
	if event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			return _begin_touch_control(touch_event.index, touch_event.position)
		return _end_touch_control(touch_event.index)
	if event is InputEventScreenDrag:
		var drag_event := event as InputEventScreenDrag
		if drag_event.index == touch_move_index:
			touch_move_vector = ((drag_event.position - touch_move_origin) / 62.0).limit_length(1.0)
			return true
	return false


func _begin_touch_control(index: int, position: Vector2) -> bool:
	if _touch_pause_hitbox().has_point(position):
		if state == GameState.PLAYING:
			state = GameState.PAUSED
			audio_manager.set_music_ducked(true)
		elif state == GameState.PAUSED:
			state = GameState.PLAYING
			audio_manager.set_music_ducked(false)
		return true
	if state != GameState.PLAYING:
		return false

	var button_hitboxes := _touch_button_hitboxes()
	for action in ["shoot", "bomb", "overdrive"]:
		if Rect2(button_hitboxes[action]).has_point(position):
			touch_button_indices[action] = index
			if action == "overdrive":
				touch_overdrive_queued = true
			else:
				touch_button_pressed[action] = true
			return true

	if _touch_move_hitbox().has_point(position):
		touch_move_index = index
		touch_move_origin = position
		touch_move_vector = Vector2.ZERO
		return true
	return false


func _end_touch_control(index: int) -> bool:
	var handled := false
	if index == touch_move_index:
		touch_move_index = -1
		touch_move_origin = Vector2.ZERO
		touch_move_vector = Vector2.ZERO
		handled = true
	for action in touch_button_indices.keys():
		if int(touch_button_indices[action]) != index:
			continue
		touch_button_indices[action] = -1
		if touch_button_pressed.has(action):
			touch_button_pressed[action] = false
		handled = true
	return handled


func _select_title_mode_at(position: Vector2) -> bool:
	var hitboxes := _title_mode_hitboxes(Config.HUD + 330.0)
	if Rect2(hitboxes.manual).has_point(position):
		selected_control_mode = ControlMode.MANUAL
		return true
	if Rect2(hitboxes.ai).has_point(position):
		selected_control_mode = ControlMode.AI
		return true
	if _title_start_hitbox().has_point(position):
		reset()
		return true
	return false


func reset() -> void:
	stage = 0
	score = 0
	difficulty = 1.0
	stage_wave = 0
	wave_transition_timer = 0.0
	stage_transition_timer = 0.0
	stage_results.clear()
	control_mode = selected_control_mode
	player.reset_run(Config.W / 2.0, Config.PLAYER_Y)
	state = GameState.PLAYING
	audio_manager.set_music_overdriven(false)
	audio_manager.set_music_ducked(false)
	load_stage(0)
	audio_manager.play_sfx("clear")


func load_stage(index: int) -> void:
	stage = index
	stage_wave = 0
	wave_transition_timer = 0.0
	stage_transition_timer = 0.0
	stage_timer = 0.0
	stage_banner = 1.65
	overdrive_zoom = 1.0
	projectiles.clear()
	explosions.clear()
	bomb_waves.clear()
	items.clear()
	stage_hazards.clear()
	score_crystals.clear()
	swarm.clear()
	boss_controller.clear()
	player.start_stage(Config.W / 2.0, Config.PLAYER_Y)
	_start_stage_metrics()
	_recalculate_difficulty()
	flash = maxf(flash, 0.18)

	var st: Dictionary = Config.STAGES[index]
	if st.boss:
		boss_controller.spawn()
		_setup_stage_gimmicks()
		audio_manager.play_music("boss_core")
		audio_manager.play_sfx("boss")
		return

	audio_manager.play_music("stage_pressure" if index >= 2 else "stage_drive")
	swarm.load_stage(st, Config.ENEMY_STATS, difficulty, stage_wave)
	_setup_stage_gimmicks()


func _start_wave(next_wave: int) -> void:
	stage_wave = next_wave
	wave_transition_timer = 0.0
	projectiles.clear_enemy_bullets()
	var st: Dictionary = Config.STAGES[stage]
	swarm.load_stage(st, Config.ENEMY_STATS, difficulty, stage_wave)
	stage_banner = 0.9
	audio_manager.play_sfx("wave")


func _update_stage_progression(dt: float) -> void:
	if wave_transition_timer > 0.0:
		wave_transition_timer = maxf(0.0, wave_transition_timer - dt)
		if wave_transition_timer <= 0.0:
			_start_wave(stage_wave + 1)
	if stage_transition_timer > 0.0:
		stage_transition_timer = maxf(0.0, stage_transition_timer - dt)
		if stage_transition_timer <= 0.0:
			load_stage(pending_stage)


func _recalculate_difficulty() -> void:
	var score_pressure := minf(0.18, float(score) / 90000.0)
	var survival_pressure := 0.06 if player.no_miss_stage else 0.0
	difficulty = 1.0 + float(stage) * 0.08 + score_pressure + survival_pressure


func _setup_stage_gimmicks() -> void:
	stage_hazards.clear()
	if stage == 3:
		for i in range(6):
			stage_hazards.append({
				"kind": "rock",
				"x": 150.0 + float(i) * 132.0,
				"y": Config.HUD + 132.0 + float(i % 3) * 118.0,
				"r": 28.0 + float(i % 2) * 9.0,
				"hp": 3 + i % 2,
				"t": float(i) * 0.7,
				"seed": i * 37 + 11,
			})
	elif stage == 4:
		stage_hazards.append({"kind": "plasma_left", "x": 34.0, "t": 0.0})
		stage_hazards.append({"kind": "plasma_right", "x": Config.W - 34.0, "t": 0.0})


func _update_stage_gimmicks(dt: float) -> void:
	if stage == 3:
		for hazard in stage_hazards:
			hazard.t += dt
			hazard.y += sin(stage_timer * 0.7 + hazard.t) * 10.0 * dt
			hazard.x += cos(stage_timer * 0.5 + hazard.t) * 14.0 * dt
			hazard.x = clampf(hazard.x, 92.0, Config.W - 92.0)
		_check_rock_collisions()
	elif stage == 4:
		_update_plasma_reflectors()
	if player.is_overdrive_active():
		_convert_overdrive_bullets(dt)
	_update_score_crystals(dt)


func _update_game(dt: float) -> void:
	stage_timer += dt
	_update_stage_progression(dt)
	var command := _read_player_command()
	player.update(dt, command["move_vector"])

	if command["overdrive"] and player.can_overdrive():
		_start_overdrive()
	if command["shoot"] and player.can_shoot():
		_fire_player()
	if command["bomb"] and player.can_bomb():
		_use_bomb()

	var st: Dictionary = Config.STAGES[stage]
	swarm.update(dt, st, stage, stage_timer, difficulty, player.x, projectiles, Config.ENEMY_STATS)
	if boss_controller.update(dt, projectiles):
		audio_manager.play_sfx("boss")
	projectiles.update(dt)
	_update_stage_gimmicks(dt)
	_update_overdrive_feedback()
	_update_explosions(dt)
	_update_items(dt)
	_check_collisions()
	_stage_max_combo = maxi(_stage_max_combo, player.combo)
	_check_stage_end()


func _update_overdrive_feedback() -> void:
	var active := player.is_overdrive_active()
	if overdrive_aura:
		overdrive_aura.global_position = Vector2(player.x, player.y + 12.0)
		overdrive_aura.emitting = active and state == GameState.PLAYING
	audio_manager.set_music_overdriven(active and state == GameState.PLAYING)


func _read_player_command() -> Dictionary:
	if control_mode == ControlMode.AI:
		return ai_pilot.get_command(player, swarm.enemies, boss_controller.boss, projectiles.bullets, items)
	var touch_command := _read_touch_command()
	return {
		"move_axis": Input.get_axis("move_left", "move_right"),
		"move_vector": touch_command.move_vector if touch_command.active else Input.get_vector("move_left", "move_right", "move_up", "move_down"),
		"shoot": Input.is_action_pressed("shoot") or bool(touch_command.shoot),
		"bomb": Input.is_action_pressed("bomb") or bool(touch_command.bomb),
		"overdrive": Input.is_action_just_pressed("overdrive") or bool(touch_command.overdrive),
	}


func _read_touch_command() -> Dictionary:
	if not _touch_controls_enabled() or state != GameState.PLAYING:
		return {"active": false, "move_vector": Vector2.ZERO, "shoot": false, "bomb": false, "overdrive": false}
	var overdrive_pressed := touch_overdrive_queued
	touch_overdrive_queued = false
	return {
		"active": touch_move_index != -1 or bool(touch_button_pressed.shoot) or bool(touch_button_pressed.bomb) or overdrive_pressed,
		"move_vector": touch_move_vector,
		"shoot": bool(touch_button_pressed.shoot),
		"bomb": bool(touch_button_pressed.bomb),
		"overdrive": overdrive_pressed,
	}


func _toggle_selected_control_mode() -> void:
	selected_control_mode = ControlMode.AI if selected_control_mode == ControlMode.MANUAL else ControlMode.MANUAL


func _toggle_control_mode() -> void:
	control_mode = ControlMode.AI if control_mode == ControlMode.MANUAL else ControlMode.MANUAL
	selected_control_mode = control_mode


func _fire_player() -> void:
	player.mark_shot()
	projectiles.fire_player(player.x, player.y, player.is_overdrive_active(), player.shot_pattern, player.combat_growth())
	audio_manager.play_sfx("shot")


func _start_overdrive() -> void:
	player.start_overdrive()
	audio_manager.set_music_overdriven(true)
	audio_manager.play_sfx("overdrive")
	_add_shake(4.0)
	_add_flash(0.58, 0.025)
	if overdrive_burst:
		overdrive_burst.global_position = Vector2(player.x, player.y)
		overdrive_burst.restart()
		overdrive_burst.emitting = true
	var tween := create_tween()
	tween.tween_property(self, "overdrive_zoom", 1.018, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "overdrive_zoom", 1.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _use_bomb() -> void:
	player.consume_bomb()
	_stage_bombs_used += 1
	audio_manager.play_sfx("bomb")
	_add_shake(3.0)
	_add_flash(0.42, 0.18)
	hitstop = 0.025
	var blast := {"x": player.x, "y": player.y - 54.0, "t": 0.0, "width": 172.0}
	bomb_waves.append(blast)
	var bomb_kills := 0

	var kept_bullets: Array[Dictionary] = []
	for bullet in projectiles.bullets:
		if not bullet.enemy or absf(bullet.x - blast.x) > blast.width * 0.62:
			kept_bullets.append(bullet)
	projectiles.bullets = kept_bullets

	for enemy in swarm.enemies:
		if absf(enemy.x - blast.x) < blast.width * 0.54 and enemy.y < player.y - 22.0:
			enemy.hp = 0
			bomb_kills += 1
			explosions.append({"x": enemy.x, "y": enemy.y, "t": 0.0, "big": enemy.kind in ["armor", "saucer", "mid_lancer", "mid_orbit", "mid_anchor"]})
			score += int(enemy.score * 0.6)
			if enemy.kind == "commander":
				_handle_commander_defeat(enemy)
			elif enemy.kind in ["mid_lancer", "mid_orbit", "mid_anchor"]:
				_handle_midboss_defeat(enemy)
			else:
				_maybe_drop_item(enemy, true)
	swarm.remove_dead()

	if boss_controller.is_alive() and absf(boss_controller.boss.x - blast.x) < 205.0:
		boss_controller.boss.hp = max(0, boss_controller.boss.hp - 42)
		for i in range(5):
			explosions.append({"x": blast.x - 58.0 + i * 29.0, "y": boss_controller.boss.y - 80.0 + i * 28.0, "t": 0.0, "big": true})

	for i in range(7):
		explosions.append({"x": blast.x + sin(i * 2.2) * 42.0, "y": player.y - 110.0 - i * 74.0, "t": -i * 0.035, "big": i % 2 == 0})
	if bomb_kills >= 3 and player.bomb_refund_chance > 0.0 and randf() < player.bomb_refund_chance:
		player.bombs = mini(5, player.bombs + 1)
		score += 450
		audio_manager.play_sfx("clear")


func _update_explosions(dt: float) -> void:
	for explosion in explosions:
		explosion.t += dt
	explosions = explosions.filter(func(explosion: Dictionary) -> bool: return explosion.t < 0.58)
	for wave in bomb_waves:
		wave.t += dt
	bomb_waves = bomb_waves.filter(func(wave: Dictionary) -> bool: return wave.t < 0.62)


func _update_items(dt: float) -> void:
	for item in items:
		item.t += dt
		item.y += item.vy * dt
		item.x += sin(item.t * 4.0) * 18.0 * dt
	items = items.filter(func(item: Dictionary) -> bool: return item.y < Config.H + 36.0)


func _check_rock_collisions() -> void:
	if stage_hazards.is_empty():
		return
	for hazard in stage_hazards:
		if hazard.kind != "rock":
			continue
		for bullet in projectiles.bullets:
			if hazard.hp <= 0:
				break
			if Vector2(bullet.x, bullet.y).distance_to(Vector2(hazard.x, hazard.y)) >= float(hazard.r) + bullet.r:
				continue
			bullet.y = -999.0 if not bullet.enemy else Config.H + 999.0
			if not bullet.enemy:
				hazard.hp -= bullet.power
				score += 20
				explosions.append({"x": bullet.x, "y": bullet.y, "t": 0.0, "big": false})
		if hazard.hp <= 0:
			score += 320
			explosions.append({"x": hazard.x, "y": hazard.y, "t": 0.0, "big": true})
			if randf() < 0.34:
				items.append({"kind": "shield", "x": hazard.x, "y": hazard.y, "vy": 78.0, "t": 0.0})
			continue
		if player.invuln <= 0.0 and Vector2(player.x, player.y).distance_to(Vector2(hazard.x, hazard.y)) < float(hazard.r) + 24.0:
			_hurt()
	stage_hazards = stage_hazards.filter(func(hazard: Dictionary) -> bool: return hazard.kind != "rock" or hazard.hp > 0)
	projectiles.bullets = projectiles.bullets.filter(func(bullet: Dictionary) -> bool: return bullet.y > -900.0 and bullet.y < Config.H + 900.0)


func _update_plasma_reflectors() -> void:
	for bullet in projectiles.bullets:
		if not bullet.enemy:
			continue
		if bullet.get("reflected", false):
			continue
		if bullet.x < 42.0 or bullet.x > Config.W - 42.0:
			bullet.x = clampf(bullet.x, 42.0, Config.W - 42.0)
			bullet.vx = -bullet.vx + (player.x - bullet.x) * 0.08
			bullet.vy += 24.0
			bullet.reflected = true
			bullet.color = Color("#fff06a")
			explosions.append({"x": bullet.x, "y": bullet.y, "t": 0.0, "big": false})


func _convert_overdrive_bullets(dt: float) -> void:
	var kept: Array[Dictionary] = []
	var converted := 0
	var radius: float = 114.0 + player.overdrive_duration_bonus * 8.0
	for bullet in projectiles.bullets:
		if bullet.enemy and Vector2(bullet.x, bullet.y).distance_to(Vector2(player.x, player.y)) < radius:
			converted += 1
			score_crystals.append({"x": bullet.x, "y": bullet.y, "vx": randf_range(-38.0, 38.0), "vy": -90.0 - randf() * 40.0, "value": 95, "t": 0.0})
		else:
			kept.append(bullet)
	if converted > 0:
		projectiles.bullets = kept
		score += converted * 35
		player.overdrive_timer = minf(player.get_overdrive_duration() + 2.0, player.overdrive_timer + converted * 0.035 * dt * 60.0)
		audio_manager.play_sfx("graze")


func _update_score_crystals(dt: float) -> void:
	for crystal in score_crystals:
		crystal.t += dt
		var to_player := Vector2(player.x - crystal.x, player.y - crystal.y)
		if to_player.length() < 220.0:
			var pull := to_player.normalized() * 260.0 * dt
			crystal.vx += pull.x
			crystal.vy += pull.y
		crystal.x += crystal.vx * dt
		crystal.y += crystal.vy * dt
	for crystal in score_crystals:
		if Vector2(crystal.x, crystal.y).distance_to(Vector2(player.x, player.y)) < 42.0:
			score += int(crystal.value)
			crystal.y = Config.H + 999.0
	score_crystals = score_crystals.filter(func(crystal: Dictionary) -> bool: return crystal.y < Config.H + 100.0 and crystal.t < 6.0)


func _maybe_drop_item(enemy: Dictionary, from_bomb: bool) -> void:
	var is_midboss: bool = enemy.kind in ["mid_lancer", "mid_orbit", "mid_anchor"]
	var base_chance := 0.2
	if enemy.kind in ["armor", "saucer"]:
		base_chance += 0.08
	if enemy.kind == "commander":
		base_chance = 1.0
	if is_midboss:
		base_chance = 1.0
	if player.lives <= 1:
		base_chance += 0.07
	if from_bomb:
		base_chance *= 0.55
	if randf() > base_chance:
		return
	var item_kind := _growth_chip_for_enemy(enemy)
	var recovery_roll := randf()
	if player.lives <= 1 and recovery_roll < 0.32:
		item_kind = "life"
	elif player.shield <= 0 and recovery_roll < 0.38:
		item_kind = "shield"
	items.append({"kind": item_kind, "x": enemy.x, "y": enemy.y, "vy": 88.0, "t": 0.0})


func _growth_chip_for_enemy(enemy: Dictionary) -> String:
	if enemy.kind in ["armor", "mid_anchor"]:
		return "power"
	if enemy.kind in ["diver", "saucer", "mid_lancer"]:
		return "spread"
	if enemy.kind in ["zig", "commander", "mid_orbit"]:
		return "resonance"
	var tracks := ["power", "spread", "resonance"]
	return tracks[randi() % tracks.size()]


func _check_collisions() -> void:
	for bullet in projectiles.bullets:
		if bullet.enemy:
			continue
		for enemy in swarm.enemies:
			if enemy.hp <= 0:
				continue
			if _distance(bullet, enemy) < enemy.size * 0.62 + bullet.r:
				bullet.y = -999.0
				enemy.hp -= bullet.power
				if enemy.hp <= 0:
					var multiplier: float = player.register_kill()
					var close_bonus := maxf(0.0, 1.0 - Vector2(enemy.x, enemy.y).distance_to(Vector2(player.x, player.y)) / 180.0)
					player.add_resonance(3.0 + minf(10.0, float(player.combo)) * 0.55 + close_bonus * 6.0)
					if player.close_kill_extend and player.is_overdrive_active() and close_bonus > 0.25:
						player.overdrive_timer = minf(player.get_overdrive_duration() + 2.0, player.overdrive_timer + 0.18 + close_bonus * 0.18)
					if player.is_overdrive_active():
						multiplier *= 1.75
					if close_bonus > 0.45:
						multiplier *= 1.12
					score += int(enemy.score * multiplier)
					var is_midboss: bool = enemy.kind in ["mid_lancer", "mid_orbit", "mid_anchor"]
					explosions.append({"x": enemy.x, "y": enemy.y, "t": 0.0, "big": enemy.kind in ["armor", "saucer", "commander"] or is_midboss})
					if enemy.kind == "commander":
						_handle_commander_defeat(enemy)
					elif is_midboss:
						_handle_midboss_defeat(enemy)
					else:
						_maybe_drop_item(enemy, false)
					if is_midboss:
						_add_shake(4.5)
						_add_flash(0.46, 0.055)
						audio_manager.play_sfx("midboss_break")
					else:
						_add_shake(1.8)
						hitstop = maxf(hitstop, 0.025)
						audio_manager.play_sfx("boom")
				else:
					if enemy.kind in ["armor", "commander", "mid_lancer", "mid_orbit", "mid_anchor"]:
						hitstop = maxf(hitstop, 0.012)
					audio_manager.play_sfx("hit")
				break

		if bullet.y > -900.0 and boss_controller.is_alive() and _boss_hit_test(Vector2(bullet.x, bullet.y), bullet.r):
			bullet.y = -999.0
			var weak_bonus := _damage_boss_part(Vector2(bullet.x, bullet.y), bullet.power)
			boss_controller.boss.hp -= bullet.power + weak_bonus
			player.add_resonance(1.4 + float(bullet.power) * 0.65)
			var boss_score: int = 8 + min(player.combo, 20) + weak_bonus * 14
			score += int(boss_score * (2.0 if player.is_overdrive_active() else 1.0))
			explosions.append({"x": bullet.x, "y": bullet.y + 20.0, "t": 0.0, "big": false})
			audio_manager.play_sfx("hit")

	swarm.remove_dead()
	projectiles.cull_marked_player_bullets()

	if player.invuln <= 0.0:
		var player_pos := {"x": player.x, "y": player.y}
		for bullet in projectiles.bullets:
			if not bullet.enemy:
				continue
			if bullet.get("grazed", false):
				continue
			var distance := _distance(bullet, player_pos)
			if distance >= 27.0 + bullet.r and distance < 58.0 + bullet.r:
				bullet.grazed = true
				player.add_resonance(7.5)
				score += 25 if player.is_overdrive_active() else 5
				if player.graze_chain_bonus:
					player.combo = maxi(1, player.combo + 1)
					player.combo_timer = maxf(player.combo_timer, 1.25)
					score += 18 + player.combo * 2
				audio_manager.play_sfx("graze")
		var hit_bullet: bool = projectiles.bullets.any(func(bullet: Dictionary) -> bool: return bullet.enemy and _distance(bullet, player_pos) < 27.0 + bullet.r)
		var hit_enemy: bool = swarm.enemies.any(func(enemy: Dictionary) -> bool: return _distance(enemy, player_pos) < enemy.size + 22.0)
		if hit_bullet or hit_enemy:
			_hurt()

	for item in items:
		if Vector2(item.x, item.y).distance_to(Vector2(player.x, player.y)) < 42.0:
			var leveled_up := false
			if Config.CHIP_TRACKS.has(item.kind):
				leveled_up = player.collect_chip(item.kind)
			else:
				player.apply_item(item.kind)
			item.y = Config.H + 999.0
			score += 300 if leveled_up else 120
			flash = maxf(flash, 0.25 if leveled_up else 0.12)
			_add_shake(2.2 if leveled_up else 0.5)
			audio_manager.play_sfx("level_up" if leveled_up else "chip")
	items = items.filter(func(item: Dictionary) -> bool: return item.y < Config.H + 100.0)


func _hurt() -> void:
	_stage_damage += 1
	var shield_absorb: bool = player.shield > 0
	var dead: bool = player.hurt()
	explosions.append({"x": player.x, "y": player.y, "t": 0.0, "big": true})
	if shield_absorb and player.shield_retaliate:
		_trigger_shield_burst()
	projectiles.clear_enemy_bullets()
	_add_shake(6.0)
	_add_flash(0.55, 0.05)
	hitstop = 0.055
	audio_manager.play_sfx("hurt")
	if dead:
		if not _has_stage_result(stage):
			_record_stage_result()
		state = GameState.GAME_OVER
		audio_manager.set_music_overdriven(false)
		audio_manager.set_music_ducked(false)
		audio_manager.play_music("game_over")


func _trigger_shield_burst() -> void:
	var burst_radius := 185.0
	for enemy in swarm.enemies:
		if Vector2(enemy.x, enemy.y).distance_to(Vector2(player.x, player.y)) < burst_radius:
			enemy.hp -= 1
			explosions.append({"x": enemy.x, "y": enemy.y, "t": 0.0, "big": false})
	var kept: Array[Dictionary] = []
	for bullet in projectiles.bullets:
		if bullet.enemy and Vector2(bullet.x, bullet.y).distance_to(Vector2(player.x, player.y)) < burst_radius:
			score_crystals.append({"x": bullet.x, "y": bullet.y, "vx": 0.0, "vy": -120.0, "value": 70, "t": 0.0})
		else:
			kept.append(bullet)
	projectiles.bullets = kept
	score += 300
	_add_flash(0.34, 0.025)


func _check_stage_end() -> void:
	if not boss_controller.boss.is_empty() and boss_controller.boss.hp <= 0:
		score += 8000 + (2500 if player.no_miss_stage else 0)
		_record_stage_result()
		explosions.append({"x": boss_controller.boss.x, "y": boss_controller.boss.y, "t": 0.0, "big": true})
		boss_controller.clear()
		state = GameState.VICTORY
		audio_manager.set_music_overdriven(false)
		_add_shake(7.0)
		_add_flash(0.72, 0.04)
		audio_manager.set_music_ducked(false)
		audio_manager.play_music("victory_clear")
		audio_manager.play_sfx("clear")
		return

	if not Config.STAGES[stage].boss and swarm.enemies.is_empty():
		if wave_transition_timer > 0.0 or stage_transition_timer > 0.0:
			return
		var wave_count := int(Config.STAGES[stage].get("waves", 1))
		if stage_wave + 1 < wave_count:
			score += 260 + stage_wave * 90
			wave_transition_timer = 0.85
			projectiles.clear_enemy_bullets()
			audio_manager.play_sfx("wave")
			return
		score += 1200 + stage * 550 + (900 if player.no_miss_stage else 0)
		_record_stage_result()
		player.bombs = mini(5, player.bombs + 1)
		player.shield = mini(player.shield_max, player.shield + 1)
		if player.lives <= 2:
			player.lives += 1
		audio_manager.play_sfx("stage_clear")
		pending_stage = stage + 1
		stage_transition_timer = 1.35
		stage_banner = 1.35


func _start_stage_metrics() -> void:
	_stage_start_score = score
	_stage_start_time = stage_timer
	_stage_damage = 0
	_stage_bombs_used = 0
	_stage_max_combo = 0


func _record_stage_result() -> void:
	var score_gain := score - _stage_start_score
	var clear_time := maxf(0.0, stage_timer - _stage_start_time)
	var result := {
		"stage": stage,
		"name": Config.STAGES[stage].name,
		"score": score_gain,
		"chain": _stage_max_combo,
		"damage": _stage_damage,
		"bombs": _stage_bombs_used,
		"time": clear_time,
		"rank": _rank_for_stage(stage, score_gain, _stage_max_combo, _stage_damage, _stage_bombs_used, clear_time),
		"tip": _tip_for_stage(score_gain, _stage_max_combo, _stage_damage, _stage_bombs_used, clear_time),
	}
	if stage_results.size() > stage and stage_results[stage].stage == stage:
		stage_results[stage] = result
	else:
		stage_results.append(result)


func _has_stage_result(stage_index: int) -> bool:
	return stage_results.any(func(result: Dictionary) -> bool: return int(result.stage) == stage_index)


func _rank_for_stage(stage_index: int, score_gain: int, max_chain: int, damage: int, bombs_used: int, clear_time: float) -> String:
	var score_targets := [5200.0, 7600.0, 10000.0, 12400.0, 15000.0]
	var target: float = score_targets[clampi(stage_index, 0, score_targets.size() - 1)]
	var points := minf(1.25, float(score_gain) / target) * 70.0
	points += minf(20.0, float(max_chain) * 1.15)
	points += 12.0 if damage == 0 else maxf(0.0, 7.0 - float(damage) * 2.2)
	points += 8.0 if bombs_used == 0 else maxf(0.0, 4.0 - float(bombs_used))
	points += 8.0 if clear_time <= 38.0 else 4.0 if clear_time <= 55.0 else 0.0
	if points >= 122.0 and damage == 0 and bombs_used == 0 and max_chain >= 18:
		return "SSS"
	if points >= 108.0 and damage <= 1:
		return "SS"
	if points >= 94.0:
		return "S"
	if points >= 78.0:
		return "A"
	if points >= 62.0:
		return "B"
	return "C"


func _tip_for_stage(score_gain: int, max_chain: int, damage: int, bombs_used: int, clear_time: float) -> String:
	if damage > 0:
		return "NEXT: HOLD SAFE LANES"
	if max_chain < 10:
		return "NEXT: KEEP CHAIN ALIVE"
	if bombs_used > 1:
		return "NEXT: SAVE BOMBS"
	if clear_time > 55.0:
		return "NEXT: PUSH CLOSER"
	if score_gain < 8000:
		return "NEXT: GRAZE FOR RESONANCE"
	return "NEXT: AIM FOR SSS"


func _handle_commander_defeat(enemy: Dictionary) -> void:
	player.add_resonance(26.0)
	_add_shake(4.6)
	_add_flash(0.42, 0.025)
	for i in range(5):
		explosions.append({"x": enemy.x + sin(float(i) * 1.7) * 54.0, "y": enemy.y + cos(float(i) * 1.3) * 42.0, "t": -float(i) * 0.025, "big": true})
	for other in swarm.enemies:
		if other.id == enemy.id or other.hp <= 0:
			continue
		if Vector2(other.x, other.y).distance_to(Vector2(enemy.x, enemy.y)) < 155.0:
			other.hp -= 1
			explosions.append({"x": other.x, "y": other.y, "t": 0.0, "big": false})
	var kept_bullets: Array[Dictionary] = []
	for bullet in projectiles.bullets:
		if not bullet.enemy or Vector2(bullet.x, bullet.y).distance_to(Vector2(enemy.x, enemy.y)) > 185.0:
			kept_bullets.append(bullet)
	projectiles.bullets = kept_bullets
	_drop_commander_reward(enemy)


func _handle_midboss_defeat(enemy: Dictionary) -> void:
	player.add_resonance(34.0)
	player.shield = mini(player.shield_max, player.shield + 1)
	for i in range(8):
		explosions.append({"x": enemy.x + sin(float(i) * 1.9) * 72.0, "y": enemy.y + cos(float(i) * 1.5) * 58.0, "t": -float(i) * 0.022, "big": true})
	projectiles.clear_enemy_bullets()
	for offset in [-28.0, 28.0]:
		items.append({"kind": _growth_chip_for_enemy(enemy), "x": enemy.x + offset, "y": enemy.y, "vy": 72.0, "t": 0.0})


func _drop_commander_reward(enemy: Dictionary) -> void:
	var item_kind := _growth_chip_for_enemy(enemy)
	items.append({"kind": item_kind, "x": enemy.x, "y": enemy.y, "vy": 82.0, "t": 0.0})


func _add_shake(amount: float) -> void:
	screen_shake = maxf(screen_shake, amount)


func _add_flash(amount: float, hitstop_time: float) -> void:
	flash = maxf(flash, amount)
	hitstop = maxf(hitstop, hitstop_time)


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_rect(Rect2(0, 0, Config.W, Config.H), Color("#02040c"))
	var shake := Vector2.ZERO
	if screen_shake > 0.0:
		shake = Vector2(randf_range(-screen_shake, screen_shake), randf_range(-screen_shake, screen_shake)).round()
	var zoom_offset := Vector2(Config.W, Config.H) * 0.5 * (1.0 - overdrive_zoom)
	draw_set_transform(shake + zoom_offset, 0.0, Vector2(overdrive_zoom, overdrive_zoom))
	_draw_background()
	_draw_playfield()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if state in [GameState.PLAYING, GameState.PAUSED]:
		hud.draw_hud(self, font, score, stage, stage_wave, int(Config.STAGES[stage].get("waves", 1)), player.lives, player.bombs, player.shield, player.combo, boss_controller.boss, player.resonance, player.overdrive_timer, player.get_overdrive_duration(), player.chip_levels, player.chip_progress, audio_manager.muted)
		_draw_control_mode_badge()
	if flash > 0.0:
		draw_rect(Rect2(0, Config.HUD, Config.W, Config.PLAY_H), Color(1.0, 0.92, 0.72, flash * 0.34))
	if stage_banner > 0.0 and state == GameState.PLAYING:
		var alpha := minf(1.0, stage_banner)
		_draw_stage_banner(Config.STAGES[stage].name, Config.HUD + 118.0, alpha)
	if state != GameState.PLAYING:
		_draw_overlay()
	if _should_draw_touch_controls():
		_draw_touch_controls()


func _draw_background() -> void:
	var st: Dictionary = Config.STAGES[stage]
	if background_texture:
		var cell_width := float(background_texture.get_width()) / 2.0
		var cell_height := float(background_texture.get_height()) / 3.0
		var crop_width := cell_height * Config.W / Config.PLAY_H
		var source_x := float(stage % 2) * cell_width + (cell_width - crop_width) * 0.5
		var source_y := float(stage / 2) * cell_height
		var panel := Rect2(source_x, source_y, crop_width, cell_height)
		draw_texture_rect_region(background_texture, Rect2(0, Config.HUD, Config.W, Config.PLAY_H), panel, Color(st.tint, 0.82))
	else:
		draw_rect(Rect2(0, Config.HUD, Config.W, Config.PLAY_H), Color("#081323"))
	draw_rect(Rect2(0, Config.HUD, Config.W, Config.PLAY_H), Color(0, 0, 0, 0.34))
	var star_count := int(65.0 * st.stars)
	for i in range(star_count):
		var x := fmod(i * 149.0 + stage_timer * (12.0 + i % 4) * st.scroll, Config.W)
		var y: float = Config.HUD + fmod(i * 61.0 + stage_timer * (35.0 + i % 5) * st.scroll, Config.PLAY_H)
		var size := 2.0 if i % 7 == 0 else 1.0
		draw_rect(Rect2(x, y, size, size), Color("#bdfbff") if i % 7 == 0 else Color(1, 1, 1, 0.55))


func _draw_playfield() -> void:
	for hazard in stage_hazards:
		_draw_stage_hazard(hazard)
	_draw_threat_previews()
	for enemy in swarm.enemies:
		_draw_enemy(enemy)
	if boss_controller.is_alive():
		_draw_boss()
	for bullet in projectiles.bullets:
		_draw_bullet(bullet)
	for wave in bomb_waves:
		_draw_bomb_wave(wave)
	for item in items:
		_draw_item(item)
	for crystal in score_crystals:
		_draw_score_crystal(crystal)
	_draw_player()
	for explosion in explosions:
		_draw_explosion(explosion)


func _draw_player() -> void:
	var tint := Color(1, 1, 1, 0.52) if player.invuln > 0.0 and int(stage_timer * 16.0) % 2 == 0 else Color.WHITE
	if player.is_overdrive_active():
		tint = Color(1.0, 0.93, 0.48, 1.0)
		var pulse := 0.5 + sin(stage_timer * 18.0) * 0.5
		draw_arc(Vector2(player.x, player.y), 64.0 + pulse * 8.0, 0.0, TAU, 64, Color(1.0, 0.86, 0.28, 0.48), 4.0)
		draw_arc(Vector2(player.x, player.y), 78.0 - pulse * 6.0, 0.0, TAU, 64, Color(1.0, 0.32, 0.9, 0.32), 2.0)
	if player_ship_texture:
		var size := 118.0 if not player.is_overdrive_active() else 126.0
		draw_texture_rect(player_ship_texture, Rect2(player.x - size * 0.5, player.y - size * 0.5, size, size), false, tint)
	else:
		_draw_sprite("player", player.x, player.y, 150, 150, tint)
	if player.shield > 0:
		_draw_player_shield()


func _draw_player_shield() -> void:
	var center := Vector2(player.x, player.y)
	var pulse := 0.5 + sin(stage_timer * 7.5) * 0.5
	var shield_count: int = clampi(player.shield, 1, 2)
	for layer in range(shield_count):
		var radius := 58.0 + layer * 13.0 + pulse * 3.0
		var alpha := 0.34 + layer * 0.1
		var color := Color(0.38, 0.92, 1.0, alpha)
		draw_arc(center, radius, -PI * 0.42 + layer * 0.5, PI * 0.72 + layer * 0.5, 32, color, 4.0)
		draw_arc(center, radius, PI * 0.58 + layer * 0.5, PI * 1.72 + layer * 0.5, 32, color, 4.0)
		draw_arc(center, radius + 5.0, -PI * 0.06 - layer * 0.35, PI * 0.2 - layer * 0.35, 14, Color(1.0, 1.0, 1.0, alpha + 0.16), 2.0)

	for i in range(shield_count):
		var angle := stage_timer * (1.6 + i * 0.32) + i * TAU / float(shield_count)
		var icon_center := center + Vector2(cos(angle), sin(angle)) * (66.0 + i * 10.0)
		if ui_texture:
			draw_texture_rect_region(ui_texture, Rect2(icon_center.x - 17.0, icon_center.y - 17.0, 34.0, 34.0), ui_regions["shield"], Color(1.0, 1.0, 1.0, 0.92))
		else:
			draw_circle(icon_center, 12.0, Color(0.45, 0.92, 1.0, 0.78))


func _draw_enemy(enemy: Dictionary) -> void:
	if enemy_fleet_texture and enemy.kind in ["bug", "diver", "zig", "armor", "saucer", "commander", "mid_lancer", "mid_orbit", "mid_anchor"]:
		_draw_renewal_enemy(enemy)
		return
	if enemy.kind == "commander":
		_draw_commander(enemy)
		return
	var tint := Color.WHITE
	if enemy.max_hp > 1:
		tint = Color(1.0, 0.85 + 0.15 * float(enemy.hp) / float(enemy.max_hp), 0.72 + 0.28 * float(enemy.hp) / float(enemy.max_hp), 1.0)
	_draw_sprite(enemy.kind, enemy.x, enemy.y, enemy.size * 2.35, enemy.size * 2.35, tint)


func _draw_renewal_enemy(enemy: Dictionary) -> void:
	var order := ["bug", "diver", "zig", "armor", "saucer", "commander", "mid_lancer", "mid_orbit", "mid_anchor"]
	var index := order.find(str(enemy.kind))
	var cell := 1254.0 / 3.0
	var region := Rect2(float(index % 3) * cell, float(index / 3) * cell, cell, cell)
	var is_midboss: bool = enemy.kind in ["mid_lancer", "mid_orbit", "mid_anchor"]
	var draw_size := float(enemy.size) * (1.92 if is_midboss else 1.74)
	var pulse := 1.0 + sin(stage_timer * 5.0 + float(enemy.id)) * (0.025 if is_midboss else 0.012)
	var tint := Color.WHITE
	if enemy.max_hp > 1 and not is_midboss:
		var hp_ratio := clampf(float(enemy.hp) / float(enemy.max_hp), 0.0, 1.0)
		tint = Color(1.0, 0.78 + hp_ratio * 0.22, 0.78 + hp_ratio * 0.22, 1.0)
	if is_midboss:
		var aura_color: Color = Config.ENEMY_STATS[enemy.kind].color
		draw_circle(Vector2(enemy.x, enemy.y), draw_size * 0.48, Color(aura_color, 0.08))
		draw_arc(Vector2(enemy.x, enemy.y), draw_size * 0.5, 0.0, TAU, 44, Color(aura_color, 0.5), 3.0)
	draw_texture_rect_region(enemy_fleet_texture, Rect2(enemy.x - draw_size * pulse * 0.5, enemy.y - draw_size * pulse * 0.5, draw_size * pulse, draw_size * pulse), region, tint)
	if enemy.max_hp > 2:
		var bar_width := 116.0 if is_midboss else 74.0
		var hp_ratio := clampf(float(enemy.hp) / maxf(1.0, float(enemy.max_hp)), 0.0, 1.0)
		draw_rect(Rect2(enemy.x - bar_width * 0.5, enemy.y + draw_size * 0.48, bar_width, 5.0), Color(1, 1, 1, 0.13))
		draw_rect(Rect2(enemy.x - bar_width * 0.5, enemy.y + draw_size * 0.48, bar_width * hp_ratio, 5.0), Config.ENEMY_STATS[enemy.kind].color)


func _draw_commander(enemy: Dictionary) -> void:
	var pulse := 0.5 + sin(stage_timer * 6.4 + enemy.id) * 0.5
	var center := Vector2(enemy.x, enemy.y)
	if commander_fx_texture:
		var fx_size := 150.0 + pulse * 16.0
		draw_texture_rect(commander_fx_texture, Rect2(center.x - fx_size / 2.0, center.y - fx_size / 2.0, fx_size, fx_size), false, Color(1.0, 1.0, 1.0, 0.45 + pulse * 0.22))
	else:
		draw_arc(center, 76.0 + pulse * 8.0, 0.0, TAU, 48, Color(1.0, 0.42, 0.92, 0.45), 4.0)
	var hp_ratio := clampf(float(enemy.hp) / maxf(1.0, float(enemy.max_hp)), 0.0, 1.0)
	var tint := Color(1.0, 0.82 + hp_ratio * 0.18, 0.9 + hp_ratio * 0.1, 1.0)
	if commander_texture:
		var size: float = float(enemy.size) * 2.45
		draw_texture_rect(commander_texture, Rect2(center.x - size / 2.0, center.y - size / 2.0, size, size), false, tint)
	else:
		_draw_sprite("saucer", enemy.x, enemy.y, enemy.size * 2.4, enemy.size * 2.4, tint)
	draw_rect(Rect2(center.x - 44.0, center.y + enemy.size + 12.0, 88.0, 5.0), Color(1, 1, 1, 0.16))
	draw_rect(Rect2(center.x - 44.0, center.y + enemy.size + 12.0, 88.0 * hp_ratio, 5.0), Color("#ff5ff0"))


func _draw_threat_previews() -> void:
	if boss_controller.is_alive() and float(boss_controller.boss.get("tell", 0.0)) > 0.0:
		_draw_boss_beam_preview()
	for enemy in swarm.enemies:
		if float(enemy.get("dive", 0.0)) > 0.0:
			_draw_enemy_dive_preview(enemy)


func _draw_boss_beam_preview() -> void:
	var rect := _boss_beam_preview_rect()
	var charge := clampf(float(boss_controller.boss.tell) / 0.45, 0.0, 1.0)
	var pulse := 0.5 + sin(stage_timer * 34.0) * 0.5
	var lane_color := Color(1.0, 0.13, 0.08, 0.11 + pulse * 0.08 + charge * 0.05)
	var core_color := Color(1.0, 0.92, 0.28, 0.18 + pulse * 0.12 + charge * 0.05)
	draw_rect(rect, lane_color)
	draw_rect(Rect2(rect.position.x + rect.size.x * 0.38, rect.position.y, rect.size.x * 0.24, rect.size.y), core_color)
	draw_line(rect.position, rect.position + Vector2(0.0, rect.size.y), Color(1.0, 0.32, 0.18, 0.54), 2.0)
	draw_line(rect.position + Vector2(rect.size.x, 0.0), rect.position + rect.size, Color(1.0, 0.32, 0.18, 0.54), 2.0)


func _boss_beam_preview_rect() -> Rect2:
	if boss_controller.boss.is_empty():
		return Rect2()
	var width := 96.0
	var top := float(boss_controller.boss.y) + 122.0
	return Rect2(float(boss_controller.boss.x) - width * 0.5, top, width, Config.H - top)


func _draw_enemy_dive_preview(enemy: Dictionary) -> void:
	var start := Vector2(float(enemy.x), float(enemy.y) + float(enemy.size) * 0.72)
	var end := Vector2(_enemy_dive_preview_end_x(enemy), Config.H - 22.0)
	var mid := Vector2(lerpf(start.x, end.x, 0.54), lerpf(start.y, end.y, 0.48))
	var pulse := 0.5 + sin(stage_timer * 18.0 + float(enemy.id)) * 0.5
	var warning := Color(1.0, 0.28, 0.14, 0.22 + pulse * 0.08)
	var edge := Color(1.0, 0.94, 0.38, 0.42 + pulse * 0.14)
	draw_polyline(PackedVector2Array([start, mid, end]), warning, 14.0, true)
	draw_polyline(PackedVector2Array([start, mid, end]), edge, 2.0, true)
	for i in range(3):
		var ratio := 0.22 + float(i) * 0.2
		var center := start.lerp(end, ratio)
		var size := 9.0 + pulse * 2.0
		var points := PackedVector2Array([
			center + Vector2(-size, -size * 0.7),
			center + Vector2(size, -size * 0.7),
			center + Vector2(0.0, size),
		])
		draw_colored_polygon(points, Color(1.0, 0.86, 0.24, 0.28 + pulse * 0.16))


func _enemy_dive_preview_end_x(enemy: Dictionary) -> float:
	var freq := 8.0 if str(enemy.get("kind", "")) == "zig" else 4.0
	var sway := sin(float(enemy.get("t", 0.0)) * freq) * 42.0
	return clampf(float(enemy.get("x", Config.W * 0.5)) + sway, 36.0, Config.W - 36.0)


func _draw_boss() -> void:
	var tint := Color(1, 0.86, 0.86, 1) if boss_controller.boss.phase >= 2 else Color.WHITE
	if final_boss_texture:
		draw_texture_rect(final_boss_texture, Rect2(boss_controller.boss.x - 205.0, boss_controller.boss.y - 205.0, 410.0, 410.0), false, tint)
	else:
		_draw_sprite("boss", boss_controller.boss.x, boss_controller.boss.y, 390, 390, tint)
	if boss_controller.boss.has("parts"):
		for part in boss_controller.boss.parts:
			var part_pos: Vector2 = Vector2(boss_controller.boss.x, boss_controller.boss.y) + part.offset
			_draw_boss_weakpoint(part, part_pos)


func _draw_boss_weakpoint(part: Dictionary, part_pos: Vector2) -> void:
	var pulse := 0.5 + sin(stage_timer * 8.0 + part_pos.x * 0.03) * 0.5
	var part_color: Color = Color("#42d9ff") if part.alive else Color(0.2, 0.26, 0.34, 0.62)
	var radius := 27.0 if part.id == "core" else 22.0
	draw_circle(part_pos, radius + 6.0, Color(part_color, 0.08 + pulse * 0.05))
	draw_arc(part_pos, radius, 0.0, TAU, 32, Color(part_color, 0.72), 3.0)
	draw_arc(part_pos, radius + 7.0, -PI * 0.35, PI * 0.7, 18, Color(Config.UI_AMBER, 0.38 if part.alive else 0.1), 2.0)
	if part.alive:
		draw_circle(part_pos, 7.0 + pulse * 2.0, Color(0.82, 0.98, 1.0, 0.9))


func _boss_weakpoint_region(part_id: String, alive: bool) -> Rect2:
	var cell_w := 1254.0 / 6.0
	var index := 0
	if part_id == "left":
		index = 0 if alive else 1
	elif part_id == "right":
		index = 2 if alive else 3
	else:
		index = 4 if alive else 5
	return Rect2(cell_w * float(index), 0.0, cell_w, 1254.0)


func _draw_stage_hazard(hazard: Dictionary) -> void:
	if hazard.kind == "rock":
		var center := Vector2(hazard.x, hazard.y)
		var radius: float = hazard.r
		if rock_obstacle_texture:
			var size := radius * 2.65
			var pulse := 0.94 + sin(stage_timer * 1.1 + float(hazard.seed)) * 0.035
			draw_texture_rect(rock_obstacle_texture, Rect2(center.x - size * 0.5, center.y - size * 0.5, size, size), false, Color(1.0, 1.0, 1.0, pulse))
			return
		var points := PackedVector2Array()
		var seed_value: int = int(hazard.get("seed", 0))
		for i in range(11):
			var angle := -PI * 0.5 + float(i) / 11.0 * TAU
			var chip := 0.78 + float((seed_value + i * 19) % 9) * 0.035
			points.append(center + Vector2(cos(angle), sin(angle)) * radius * chip)
		draw_colored_polygon(points, Color("#493f54"))
		draw_polyline(points, Color("#d7b56f"), 3.0, true)
		var inner := PackedVector2Array()
		for i in range(points.size()):
			inner.append(center.lerp(points[i], 0.52))
		draw_colored_polygon(inner, Color(0.78, 0.66, 0.45, 0.32))
		var crack_a := center + Vector2(-radius * 0.36, -radius * 0.18)
		var crack_b := center + Vector2(radius * 0.18, radius * 0.08)
		var crack_c := center + Vector2(radius * 0.42, -radius * 0.2)
		draw_polyline(PackedVector2Array([crack_a, crack_b, crack_c]), Color(1.0, 0.88, 0.55, 0.58), 2.0)
	elif str(hazard.kind).begins_with("plasma"):
		var x: float = hazard.x
		draw_rect(Rect2(x - 10.0, Config.HUD, 20.0, Config.PLAY_H), Color(0.52, 0.9, 1.0, 0.1))
		draw_line(Vector2(x, Config.HUD), Vector2(x, Config.H), Color("#72eaff"), 3.0)


func _draw_score_crystal(crystal: Dictionary) -> void:
	var center := Vector2(crystal.x, crystal.y)
	var pulse := 0.5 + sin(crystal.t * 14.0) * 0.5
	draw_circle(center, 14.0 + pulse * 4.0, Color(1.0, 0.94, 0.36, 0.18))
	draw_rect(Rect2(center.x - 6.0, center.y - 6.0, 12.0, 12.0), Color("#fff06a"))


func _draw_bullet(bullet: Dictionary) -> void:
	if projectile_texture:
		var visual := str(bullet.get("sprite", "enemy" if bullet.enemy else "player"))
		var region := _projectile_region(visual)
		var width := 34.0
		var height := 74.0
		if visual == "overdrive":
			width = 48.0
			height = 98.0
		elif visual == "boss":
			width = 48.0
			height = 92.0
		elif visual == "beam":
			width = 58.0
			height = 118.0
		elif visual == "enemy":
			width = 34.0
			height = 68.0
		var tint := Color.WHITE
		if bullet.enemy and visual != "beam":
			tint = Color(1.0, 0.78, 0.98, 0.96)
		draw_texture_rect_region(projectile_texture, Rect2(bullet.x - width * 0.5, bullet.y - height * 0.5, width, height), region, tint)
		return
	var rx: float = bullet.r
	var ry: float = bullet.r * (1.6 if bullet.enemy else 2.4)
	draw_circle(Vector2(bullet.x, bullet.y), maxf(rx, ry), Color(bullet.color, 0.16))
	draw_ellipse(Vector2(bullet.x, bullet.y), rx, ry, bullet.color)


func _projectile_region(visual: String) -> Rect2:
	var cell_w := 1254.0 / 4.0
	var index := 0
	if visual == "overdrive":
		index = 1
	elif visual == "enemy":
		index = 2
	elif visual == "boss" or visual == "beam":
		index = 3
	return Rect2(cell_w * float(index), 0.0, cell_w, 1254.0)


func _draw_explosion(explosion: Dictionary) -> void:
	if explosion.t < 0.0:
		return
	var key := "boom1" if explosion.t < 0.17 else "boom2" if explosion.t < 0.34 else "boom3"
	var size := 104.0 if explosion.big else 68.0
	_draw_sprite(key, explosion.x, explosion.y, size, size, Color(1, 1, 1, 1.0 - explosion.t * 1.2))


func _draw_bomb_wave(wave: Dictionary) -> void:
	var progress := clampf(wave.t / 0.62, 0.0, 1.0)
	var top: float = Config.HUD + 8.0
	var height: float = player.y - top
	var beam_width: float = wave.width * (1.0 - progress * 0.38)
	var alpha := 1.0 - progress
	draw_rect(Rect2(wave.x - beam_width / 2.0, top, beam_width, height), Color(1.0, 0.36, 0.84, 0.22 * alpha))
	draw_rect(Rect2(wave.x - beam_width * 0.22, top, beam_width * 0.44, height), Color(1.0, 0.97, 0.51, 0.28 * alpha))
	draw_line(Vector2(wave.x, player.y), Vector2(wave.x + sin(wave.t * 48.0) * 18.0, top), Color(1, 1, 1, 0.8 * alpha), 4.0)


func _draw_item(item: Dictionary) -> void:
	var bob := sin(item.t * 8.0) * 3.0
	var center := Vector2(item.x, item.y + bob)
	var color := Color("#ff6f88")
	var label := "+"
	var region_key := "life"
	if Config.CHIP_TRACKS.has(item.kind):
		var track: Dictionary = Config.CHIP_TRACKS[item.kind]
		color = track.color
		draw_circle(center, 25.0, Color(color, 0.12))
		draw_arc(center, 21.0 + sin(item.t * 6.0) * 2.0, 0.0, TAU, 24, Color(color, 0.9), 2.0)
		if track.shape == "triangle":
			draw_colored_polygon(PackedVector2Array([center + Vector2(0, -13), center + Vector2(12, 10), center + Vector2(-12, 10)]), color)
		elif track.shape == "fan":
			draw_colored_polygon(PackedVector2Array([center + Vector2(0, 12), center + Vector2(-15, -8), center, center + Vector2(15, -8)]), color)
		else:
			var points := PackedVector2Array()
			for i in range(6):
				points.append(center + Vector2(cos(TAU * i / 6.0), sin(TAU * i / 6.0)) * 13.0)
			draw_colored_polygon(points, color)
		return
	if item.kind == "bomb":
		color = Color("#ff7af0")
		label = "B"
		region_key = "bomb"
	elif item.kind == "shield":
		color = Color("#72eaff")
		label = "S"
		region_key = "shield"
	if ui_texture:
		draw_texture_rect_region(ui_texture, Rect2(center.x - 24.0, center.y - 24.0, 48.0, 48.0), ui_regions[region_key])
	else:
		draw_circle(center, 20.0, Color(color, 0.18))
		draw_circle(center, 12.0, Color(color, 0.88))
		draw_arc(center, 18.0, -PI * 0.5, PI * 1.5, 28, Color(1, 1, 1, 0.72), 2.0)
		var label_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
		draw_string(font, center + Vector2(-label_size.x / 2.0, 5.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#06121c"))


func _draw_sprite(key: String, cx: float, cy: float, dw: float, dh: float, tint := Color.WHITE) -> void:
	if sprite_texture and sprites.has(key):
		draw_texture_rect_region(sprite_texture, Rect2(cx - dw / 2.0, cy - dh / 2.0, dw, dh), sprites[key], tint)
	else:
		draw_rect(Rect2(cx - dw / 2.0, cy - dh / 2.0, dw, dh), Color("#7df7ff"))


func _draw_infection_overlay() -> void:
	draw_rect(Rect2(0, 0, Config.W, Config.H), Color(0.0, 0.0, 0.03, 0.72))
	draw_rect(Rect2(0, 0, Config.W, Config.H), Color(Config.UI_MAGENTA, 0.06))
	for i in range(12):
		var y := 18.0 + float(i) * 58.0
		var alpha := 0.08 + float(i % 3) * 0.025
		draw_line(Vector2(0, y), Vector2(Config.W, y), Color(Config.UI_CYAN, alpha), 1.0)
	for i in range(8):
		var x := fmod(stage_timer * 18.0 + float(i) * 137.0, Config.W)
		draw_line(Vector2(x, Config.HUD), Vector2(x - 180.0, Config.H), Color(Config.UI_RED, 0.06), 1.0)


func _draw_terminal_panel(rect: Rect2, accent: Color, fill_alpha := Config.UI_PANEL_ALPHA, selected := false) -> void:
	draw_rect(rect, Color(Config.UI_PANEL_DARK, fill_alpha))
	if ui_chrome_texture and ui_chrome_regions.has("panel"):
		draw_texture_rect_region(ui_chrome_texture, rect, ui_chrome_regions.panel, Color(1, 1, 1, 0.2 + (0.12 if selected else 0.0)))
	draw_rect(rect.grow(-3.0), Color(Config.UI_PANEL, fill_alpha * 0.74))
	draw_rect(rect, Color(accent, 0.76 if selected else Config.UI_LINE_ALPHA), false, 2.0 if selected else 1.0)
	draw_line(rect.position + Vector2(12, 5), rect.position + Vector2(rect.size.x * 0.4, 5), Color(accent, 0.8), 2.0)
	draw_line(rect.end - Vector2(rect.size.x * 0.4, 5), rect.end - Vector2(12, 5), Color(accent, 0.35), 1.0)
	_draw_corner_marks(rect, accent, selected)


func _draw_corner_marks(rect: Rect2, accent: Color, selected: bool) -> void:
	var length := 18.0 if selected else 12.0
	var alpha := 0.92 if selected else 0.5
	var points := [
		[rect.position, Vector2(1, 0), Vector2(0, 1)],
		[Vector2(rect.end.x, rect.position.y), Vector2(-1, 0), Vector2(0, 1)],
		[Vector2(rect.position.x, rect.end.y), Vector2(1, 0), Vector2(0, -1)],
		[rect.end, Vector2(-1, 0), Vector2(0, -1)],
	]
	for point in points:
		var origin: Vector2 = point[0]
		var axis_a: Vector2 = point[1]
		var axis_b: Vector2 = point[2]
		draw_line(origin, origin + axis_a * length, Color(accent, alpha), 2.0)
		draw_line(origin, origin + axis_b * length, Color(accent, alpha), 2.0)


func _draw_chrome_icon(key: String, rect: Rect2, tint := Color.WHITE) -> void:
	if ui_chrome_texture and ui_chrome_regions.has(key):
		draw_texture_rect_region(ui_chrome_texture, rect, ui_chrome_regions[key], tint)


func _draw_core_glyph(center: Vector2, radius: float, accent: Color, active := false) -> void:
	var pulse := 0.5 + sin(Time.get_ticks_msec() * 0.009) * 0.5
	if ui_chrome_texture and ui_chrome_regions.has("core"):
		var size := radius * 2.0
		draw_texture_rect_region(ui_chrome_texture, Rect2(center.x - radius, center.y - radius, size, size), ui_chrome_regions.core, Color(1, 1, 1, 0.76))
	draw_circle(center, radius * 0.48, Color(accent, 0.14 + pulse * 0.1))
	draw_arc(center, radius * (0.72 + pulse * 0.08), 0.0, TAU, 48, Color(accent, 0.6 if active else 0.36), 3.0)
	draw_arc(center, radius * 0.42, -PI * 0.25, PI * 1.35, 32, Color(Config.UI_CYAN, 0.42), 2.0)


func _draw_terminal_button(rect: Rect2, label: String, sublabel: String, accent: Color, selected := false) -> void:
	_draw_terminal_panel(rect, accent, 0.7, selected)
	if selected:
		draw_rect(rect.grow(-7.0), Color(accent, 0.14))
	_draw_centered_in_width(label, rect.position.x, rect.size.x, rect.position.y + rect.size.y * 0.47, 22, Color("#fff6f4"))
	if sublabel != "":
		_draw_centered_in_width(sublabel, rect.position.x, rect.size.x, rect.position.y + rect.size.y * 0.72, 11, Config.UI_TEXT_DIM)


func _draw_overlay() -> void:
	_draw_infection_overlay()
	var title := "NOVA SWARM"
	if state == GameState.PAUSED:
		title = "PAUSED"
	elif state == GameState.VICTORY:
		title = "MISSION CLEAR"
	elif state == GameState.GAME_OVER:
		title = "GAME OVER"
	var sub := "P TO RESUME" if state == GameState.PAUSED else "ENTER TO DEPLOY"
	if state == GameState.TITLE and ui_texture:
		_draw_terminal_panel(Rect2(86, Config.HUD + 58, 788, 234), Config.UI_RED, 0.5)
		_draw_core_glyph(Vector2(480, Config.HUD + 176), 80.0, Config.UI_RED, true)
		draw_texture_rect_region(ui_texture, Rect2(124, Config.HUD + 74, 712, 218), ui_regions.logo, Color(1, 1, 1, 0.96))
		hud.draw_centered(self, font, "AURORA FRONT ONLINE", Config.HUD + 286, 13, Color(Config.UI_CYAN, 0.9))
		_draw_title_mode_select(Config.HUD + 330.0)
		_draw_title_start_button()
		hud.draw_centered(self, font, sub, Config.HUD + 512, 15, Config.UI_MAGENTA)
		hud.draw_centered(self, font, "COLLECT POWER / BREAK THE SIEGE / IGNITE OVERDRIVE", Config.HUD + 548, 16, Color(Config.UI_TEXT, 0.84))
		hud.draw_centered(self, font, "SPACE SHOT / B BOMB / E OVERDRIVE / P PAUSE / M MUTE", Config.HUD + 580, 12, Config.UI_TEXT_DIM)
	elif state == GameState.VICTORY and ui_texture:
		_draw_terminal_panel(Rect2(118, Config.HUD + 48, 724, 214), Config.UI_CYAN, 0.58)
		draw_texture_rect_region(ui_texture, Rect2(146, Config.HUD + 62, 668, 210), ui_regions.ending, Color(1, 1, 1, 0.88))
		_draw_arcade_title(title, Config.HUD + 292.0, 44, Config.UI_TEXT)
		hud.draw_centered(self, font, "FINAL SCORE " + str(score).pad_zeros(7), Config.HUD + 344, 22, Config.UI_AMBER)
		_draw_results_table(Config.HUD + 384.0)
		hud.draw_centered(self, font, _control_mode_label(control_mode) + " / ENTER TO REDEPLOY", Config.HUD + 640, 18, Config.UI_MAGENTA)
	else:
		_draw_core_glyph(Vector2(Config.W * 0.5, Config.HUD + 168.0), 74.0, Config.UI_RED, state == GameState.GAME_OVER)
		_draw_arcade_title(title, Config.HUD + 216.0, 58, Config.UI_TEXT)
		hud.draw_centered(self, font, sub, Config.HUD + 292, 22, Config.UI_MAGENTA)
		if state == GameState.PAUSED:
			_draw_controls_panel(Config.HUD + 332.0)
		elif state == GameState.GAME_OVER and not stage_results.is_empty():
			_draw_results_table(Config.HUD + 334.0)
		else:
			hud.draw_centered(self, font, "CORE SIGNAL LOST / REBUILD AND REDEPLOY", Config.HUD + 340, 17, Color(Config.UI_TEXT, 0.82))


func _draw_controls_panel(y: float) -> void:
	var rect := Rect2(260.0, y, 440.0, 226.0)
	_draw_terminal_panel(rect, Config.UI_CYAN, 0.78)
	draw_string(font, rect.position + Vector2(34.0, 36.0), "CONTROL CHANNELS", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Config.UI_CYAN)
	var rows := [
		["MOVE", "WASD / ARROWS"],
		["SHOT", "SPACE"],
		["BOMB", "B / SHIFT"],
		["OVERDRIVE", "E"],
		["AI MODE", "T"],
		["PAUSE", "P"],
		["MUTE", "M"],
	]
	for i in range(rows.size()):
		var row_y := y + 66.0 + float(i) * 22.0
		draw_string(font, Vector2(rect.position.x + 34.0, row_y), rows[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Config.UI_AMBER if i == 3 else Config.UI_CYAN)
		draw_string(font, Vector2(rect.position.x + 184.0, row_y), rows[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(Config.UI_TEXT, 0.82))


func _draw_centered_in_width(text: String, x: float, width: float, y: float, size: int, color: Color) -> void:
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	draw_string(font, Vector2(x + (width - text_size.x) / 2.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _draw_results_table(y: float) -> void:
	var x := 128.0
	var row_h := 31.0
	var headers := ["STAGE", "SCORE", "CHAIN", "DMG", "BOMB", "RANK"]
	var cols := [x, x + 230.0, x + 382.0, x + 500.0, x + 590.0, x + 704.0]
	_draw_terminal_panel(Rect2(x - 24.0, y - 28.0, 760.0, row_h * 6.0 + 40.0), Config.UI_RED, 0.74)
	for i in range(headers.size()):
		draw_string(font, Vector2(cols[i], y), headers[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Config.UI_TEXT_DIM)
	for r in range(stage_results.size()):
		var result: Dictionary = stage_results[r]
		var row_y := y + 30.0 + float(r) * row_h
		var rank_color := _rank_color(str(result.rank))
		if r % 2 == 0:
			draw_rect(Rect2(x - 10.0, row_y - 16.0, 720.0, 23.0), Color(Config.UI_RED, 0.07))
		draw_string(font, Vector2(cols[0], row_y), str(result.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Config.UI_TEXT)
		draw_string(font, Vector2(cols[1], row_y), str(result.score).pad_zeros(5), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Config.UI_CYAN)
		draw_string(font, Vector2(cols[2], row_y), str(result.chain), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Config.UI_AMBER)
		draw_string(font, Vector2(cols[3], row_y), str(result.damage), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#ff9aa8"))
		draw_string(font, Vector2(cols[4], row_y), str(result.bombs), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Config.UI_MAGENTA)
		draw_string(font, Vector2(cols[5], row_y), str(result.rank), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, rank_color)
	if not stage_results.is_empty():
		var last_result: Dictionary = stage_results[stage_results.size() - 1]
		draw_string(font, Vector2(x, y + row_h * 6.0 + 24.0), str(last_result.get("tip", "NEXT: AIM FOR SSS")), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Config.UI_AMBER)


func _rank_color(rank: String) -> Color:
	if rank in ["SSS", "SS"]:
		return Config.UI_AMBER
	if rank == "S":
		return Config.UI_MAGENTA
	if rank == "A":
		return Config.UI_CYAN
	if rank == "B":
		return Config.UI_GREEN
	return Color(Config.UI_TEXT, 0.72)


func _draw_control_mode_badge() -> void:
	if state != GameState.PLAYING:
		return
	var label := _control_mode_label(control_mode)
	var color := Config.UI_AMBER if control_mode == ControlMode.AI else Config.UI_CYAN
	var x := 858.0
	var y := 42.0
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	var rect := Rect2(x - 9.0, y - 15.0, text_size.x + 18.0, 20.0)
	draw_rect(rect, Color(Config.UI_PANEL_DARK, 0.52))
	draw_rect(rect, Color(color, 0.18), false, 1.0)
	draw_string(font, Vector2(x, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)


func _draw_touch_controls() -> void:
	var move_center := _touch_move_center()
	var move_radius := Config.UI_TOUCH_STICK_RADIUS
	var stick_offset := touch_move_vector * 38.0
	var active_color := Config.UI_AMBER if touch_move_index != -1 else Color(Config.UI_TEXT, 0.38)
	draw_circle(move_center, move_radius, Color(Config.UI_PANEL_DARK, 0.34))
	draw_arc(move_center, move_radius, 0.0, TAU, 56, Color(Config.UI_RED, 0.36), 3.0)
	draw_arc(move_center, move_radius - 15.0, -PI * 0.15, PI * 1.15, 44, Color(Config.UI_CYAN, 0.24), 2.0)
	draw_line(move_center + Vector2(-move_radius + 16.0, 0), move_center + Vector2(move_radius - 16.0, 0), Color(Config.UI_RED, 0.12), 1.0)
	draw_line(move_center + Vector2(0, -move_radius + 16.0), move_center + Vector2(0, move_radius - 16.0), Color(Config.UI_RED, 0.12), 1.0)
	draw_circle(move_center + stick_offset, Config.UI_TOUCH_KNOB, Color(active_color, 0.34))
	draw_arc(move_center + stick_offset, Config.UI_TOUCH_KNOB, 0.0, TAU, 32, active_color, 2.0)

	var button_hitboxes := _touch_button_hitboxes()
	_draw_touch_button(Rect2(button_hitboxes.shoot), "SHOT", "shot", Config.UI_CYAN, bool(touch_button_pressed.shoot))
	_draw_touch_button(Rect2(button_hitboxes.bomb), "BOMB", "bomb", Config.UI_MAGENTA, bool(touch_button_pressed.bomb))
	_draw_touch_button(Rect2(button_hitboxes.overdrive), "OVER", "overdrive", Config.UI_AMBER, touch_overdrive_queued)
	_draw_touch_button(_touch_pause_hitbox(), "PAUSE", "pause", Color(Config.UI_TEXT, 0.78), state == GameState.PAUSED)


func _draw_touch_button(rect: Rect2, label: String, icon_key: String, color: Color, active: bool) -> void:
	var fill_alpha := 0.34 if active else 0.16
	draw_circle(rect.get_center(), rect.size.x * 0.5, Color(Config.UI_PANEL_DARK, 0.36))
	draw_circle(rect.get_center(), rect.size.x * 0.5 - 6.0, Color(color, fill_alpha))
	draw_arc(rect.get_center(), rect.size.x * 0.5 - 4.0, 0.0, TAU, 40, Color(color, 0.78 if active else 0.46), 3.0 if active else 2.0)
	_draw_chrome_icon(icon_key, Rect2(rect.get_center().x - rect.size.x * 0.24, rect.get_center().y - rect.size.y * 0.3, rect.size.x * 0.48, rect.size.y * 0.48), Color(1, 1, 1, 0.82))
	_draw_centered_in_width(label, rect.position.x, rect.size.x, rect.position.y + rect.size.y * 0.74, 12, Color(0.98, 1.0, 1.0, 0.86))


func _should_draw_touch_controls() -> bool:
	return _touch_controls_enabled() and state in [GameState.PLAYING, GameState.PAUSED]


func _touch_controls_enabled() -> bool:
	return control_mode == ControlMode.MANUAL and (touch_controls_available or touch_controls_forced)


func _detect_touch_controls_available() -> bool:
	if OS.has_feature("mobile") or OS.get_name() in ["Android", "iOS"]:
		return true
	if not Engine.has_singleton("JavaScriptBridge"):
		return false
	var bridge: Object = Engine.get_singleton("JavaScriptBridge")
	var max_touch_points: Variant = bridge.eval("navigator.maxTouchPoints || 0", true)
	return typeof(max_touch_points) in [TYPE_INT, TYPE_FLOAT] and float(max_touch_points) > 0.0


func _touch_move_center() -> Vector2:
	return Vector2(124.0, Config.H - 118.0)


func _touch_move_hitbox() -> Rect2:
	return Rect2(_touch_move_center() - Vector2(Config.UI_TOUCH_STICK_HIT * 0.5, Config.UI_TOUCH_STICK_HIT * 0.5), Vector2(Config.UI_TOUCH_STICK_HIT, Config.UI_TOUCH_STICK_HIT))


func _touch_button_hitboxes() -> Dictionary:
	return {
		"shoot": Rect2(Config.W - 174.0, Config.H - 194.0, Config.UI_TOUCH_SHOT_SIZE, Config.UI_TOUCH_SHOT_SIZE),
		"bomb": Rect2(Config.W - 288.0, Config.H - 148.0, Config.UI_TOUCH_BOMB_SIZE, Config.UI_TOUCH_BOMB_SIZE),
		"overdrive": Rect2(Config.W - 394.0, Config.H - 134.0, Config.UI_TOUCH_OVERDRIVE_SIZE, Config.UI_TOUCH_OVERDRIVE_SIZE),
	}


func _touch_pause_hitbox() -> Rect2:
	return Rect2(Config.W - 86.0, Config.HUD + 12.0, Config.UI_TOUCH_PAUSE_SIZE, Config.UI_TOUCH_PAUSE_SIZE)


func _draw_title_mode_select(y: float) -> void:
	var manual := "MANUAL"
	var ai := "AI DEMO"
	var manual_color := Config.UI_AMBER if selected_control_mode == ControlMode.MANUAL else Color(Config.UI_TEXT, 0.58)
	var ai_color := Config.UI_AMBER if selected_control_mode == ControlMode.AI else Color(Config.UI_TEXT, 0.58)
	var manual_text := manual
	var ai_text := ai
	var positions := _title_mode_text_positions(y, manual_text, ai_text)
	var hitboxes := _title_mode_hitboxes(y)
	_draw_title_mode_button(Rect2(hitboxes.manual), selected_control_mode == ControlMode.MANUAL, manual_color)
	_draw_title_mode_button(Rect2(hitboxes.ai), selected_control_mode == ControlMode.AI, ai_color)
	draw_string(font, positions.manual, manual_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, manual_color)
	draw_string(font, positions.ai, ai_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, ai_color)
	hud.draw_centered(self, font, "CLICK OR LEFT / RIGHT SELECT CONTROL CHANNEL", y + 54.0, 14, Config.UI_TEXT_DIM)


func _draw_title_start_button() -> void:
	var rect := _title_start_hitbox()
	_draw_terminal_button(rect, "START", _control_mode_label(selected_control_mode) + " DEPLOYMENT", Config.UI_MAGENTA, true)


func _title_start_hitbox() -> Rect2:
	return Rect2((Config.W - 256.0) * 0.5, Config.HUD + 404.0, 256.0, 78.0)


func _draw_title_mode_button(rect: Rect2, selected: bool, color: Color) -> void:
	_draw_terminal_panel(rect, color, 0.62, selected)


func _title_mode_hitboxes(y: float) -> Dictionary:
	var manual_text := "MANUAL"
	var ai_text := "AI DEMO"
	var positions := _title_mode_text_positions(y, manual_text, ai_text)
	var manual_size := font.get_string_size(manual_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
	var ai_size := font.get_string_size(ai_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
	return {
		"manual": Rect2(positions.manual.x - 26.0, y - 32.0, manual_size.x + 52.0, 52.0),
		"ai": Rect2(positions.ai.x - 26.0, y - 32.0, ai_size.x + 52.0, 52.0),
	}


func _title_mode_text_positions(y: float, manual_text: String, ai_text: String) -> Dictionary:
	var gap := 84.0
	var manual_size := font.get_string_size(manual_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
	var ai_size := font.get_string_size(ai_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
	var total_width := manual_size.x + gap + ai_size.x
	var start_x := (Config.W - total_width) / 2.0
	return {
		"manual": Vector2(start_x, y),
		"ai": Vector2(start_x + manual_size.x + gap, y),
	}


func _control_mode_label(mode: int) -> String:
	return "AI DEMO" if mode == ControlMode.AI else "MANUAL"


func _draw_stage_banner(text: String, y: float, alpha: float) -> void:
	var size := 30
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var x := (Config.W - text_size.x) / 2.0
	var panel := Rect2((Config.W - 520.0) * 0.5, y - 48.0, 520.0, 72.0)
	_draw_terminal_panel(panel, Config.UI_RED, 0.42 * alpha, true)
	if ui_texture:
		draw_texture_rect_region(ui_texture, Rect2(250, y - 45.0, 460, 66), ui_regions.banner, Color(1, 1, 1, alpha * 0.46))
	draw_string(font, Vector2(x + 2.0, y + 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.62 * alpha))
	draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(Config.UI_TEXT, alpha))


func _draw_arcade_title(text: String, y: float, size: int, color: Color) -> void:
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var x := (Config.W - text_size.x) / 2.0
	draw_string(font, Vector2(x + 3.0, y + 3.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.0, 0.0, 0.0, 0.72))
	draw_string(font, Vector2(x + 1.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(Config.UI_RED, 0.42))
	draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
	draw_line(Vector2(x - 42.0, y + 10.0), Vector2(x - 10.0, y + 10.0), Config.UI_RED, 3.0)
	draw_line(Vector2(x + text_size.x + 10.0, y + 10.0), Vector2(x + text_size.x + 42.0, y + 10.0), Config.UI_RED, 3.0)
	draw_line(Vector2(x - 24.0, y + 17.0), Vector2(x + text_size.x + 24.0, y + 17.0), Color(Config.UI_CYAN, 0.16), 1.0)


func _distance(a: Dictionary, b: Dictionary) -> float:
	return Vector2(a.x, a.y).distance_to(Vector2(b.x, b.y))


func _boss_hit_test(point: Vector2, radius: float) -> bool:
	var b: Dictionary = boss_controller.boss
	var zones := [
		{"offset": Vector2(0, -4), "r": 98.0},
		{"offset": Vector2(-96, 18), "r": 54.0},
		{"offset": Vector2(96, 18), "r": 54.0},
		{"offset": Vector2(0, 104), "r": 42.0},
	]
	for zone in zones:
		if point.distance_to(Vector2(b.x, b.y) + zone.offset) <= zone.r + radius:
			return true
	return false


func _damage_boss_part(point: Vector2, power: int) -> int:
	var b: Dictionary = boss_controller.boss
	if b.is_empty() or not b.has("parts"):
		return 0
	for part in b.parts:
		if not part.alive:
			continue
		var part_pos: Vector2 = Vector2(b.x, b.y) + part.offset
		if point.distance_to(part_pos) > 42.0:
			continue
		part.hp -= power
		if part.hp <= 0:
			part.alive = false
			score += 1200
			player.add_resonance(18.0)
			_add_shake(3.8)
			_add_flash(0.34, 0.02)
			for i in range(4):
				explosions.append({"x": part_pos.x + randf_range(-24.0, 24.0), "y": part_pos.y + randf_range(-24.0, 24.0), "t": -float(i) * 0.025, "big": true})
			return 8
		return 2
	return 0


func _load_sprite_texture() -> Texture2D:
	var bytes := FileAccess.get_file_as_bytes("res://public/assets/spritesheet.png")
	if bytes.is_empty():
		push_warning("Failed to read spritesheet.png")
		return null
	var image := Image.new()
	var err := image.load_png_from_buffer(bytes)
	if err != OK:
		push_warning("Failed to decode spritesheet.png")
		return null
	image.convert(Image.FORMAT_RGBA8)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			if color.r < 0.12 and color.g < 0.12 and color.b < 0.13:
				color.a = 0.0
				image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)


func _load_png_texture(path: String) -> Texture2D:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		push_warning("Failed to read " + path)
		return null
	var image := Image.new()
	var err := image.load_png_from_buffer(bytes)
	if err != OK:
		push_warning("Failed to decode " + path)
		return null
	image.convert(Image.FORMAT_RGBA8)
	return ImageTexture.create_from_image(image)


func _load_imported_or_png_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var imported := load(path)
		if imported is Texture2D:
			return imported
	return _load_png_texture(path)


func _parse_web_query() -> void:
	if not Engine.has_singleton("JavaScriptBridge"):
		return
	var bridge: Object = Engine.get_singleton("JavaScriptBridge")
	var search: Variant = bridge.eval("window.location.search", true)
	if typeof(search) != TYPE_STRING:
		return
	if search.find("touch=1") != -1:
		touch_controls_forced = true
	if search.find("autostart=1") == -1:
		return
	reset()
	var stage_pos: int = search.find("stage=")
	if stage_pos != -1:
		var raw_stage := int(search.substr(stage_pos + 6, 1))
		if raw_stage >= 1 and raw_stage <= Config.STAGES.size():
			load_stage(raw_stage - 1)
