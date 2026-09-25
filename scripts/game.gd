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
const FxLayerScript := preload("res://scripts/fx_layer.gd")
const UiLayerScript := preload("res://scripts/ui_layer.gd")
const BeatClockScript := preload("res://scripts/beat_clock.gd")
const ResonanceNetworkScript := preload("res://scripts/resonance_network.gd")

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
var _web_document: Variant = null
var _web_window: Variant = null
var _web_visibility_callback: Variant = null
var _web_pagehide_callback: Variant = null
var _web_pageshow_callback: Variant = null
var _web_title_music_replayed := false

var player = PlayerScript.new()
var projectiles = ProjectileManagerScript.new()
var swarm = EnemySwarmScript.new()
var boss_controller = BossControllerScript.new()
var hud = HudScript.new()
var ai_pilot = AiPilotScript.new()
var beat_clock = BeatClockScript.new()
var network = ResonanceNetworkScript.new()
var best_chain := 0
const AI_PACE_PATH := "user://ai_pace.json"
const AI_PACE_STEP := 5.0
var show_ai_overlay := true
var highlight_timer := 0.0
var highlight_strength := 0.0
var highlight_focus := Vector2(480, 400)
var highlight_label := ""
var _graze_highlight_cooldown := 0.0
var run_time := 0.0
var ai_pace: Array = []
var _pace_record: Array = []
var _pending_beat_tick := false
var _sync_popup_cooldown := 0.0
var audio_manager

var explosions: Array[Dictionary] = []
var bomb_waves: Array[Dictionary] = []
var items: Array[Dictionary] = []
var stage_hazards: Array[Dictionary] = []
var score_crystals: Array[Dictionary] = []
var background_texture: Texture2D
var rock_obstacle_texture: Texture2D
var projectile_texture: Texture2D
var final_boss_texture: Texture2D
var boss_weakpoint_texture: Texture2D
var enemy_fleet_texture: Texture2D
var player_ship_texture: Texture2D
var title_background_texture: Texture2D
var title_controls_texture: Texture2D
var status_icons_texture: Texture2D
var shield_fx_texture: Texture2D
var hud_chassis_texture: Texture2D
var overdrive_mote_texture: Texture2D
var score_crystal_texture: Texture2D
var resonance_pod_texture: Texture2D
var explosion_texture: Texture2D
var beam_player_texture: Texture2D
var beam_enemy_texture: Texture2D
var ending_texture: Texture2D
var font: Font
var display_font: Font
var overdrive_aura: CPUParticles2D
var overdrive_burst: CPUParticles2D
var fx: Node2D
var ui_layer: Node2D
# Canvas used by the shared draw helpers: the world during _draw, the UI layer during draw_ui_pass.
var _c: CanvasItem
var _world_xform := Transform2D.IDENTITY
var _prev_player_pos := Vector2.ZERO
var player_velocity := Vector2.ZERO
var warp := 0.0


func _ready() -> void:
	randomize()
	_c = self
	_setup_native_window()
	_setup_runtime_models()
	touch_controls_available = _detect_touch_controls_available()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_setup_fonts()
	background_texture = load("res://public/assets/refresh/backgrounds.png")
	rock_obstacle_texture = _load_imported_or_png_texture("res://public/assets/refresh/rock.png")
	projectile_texture = _load_imported_or_png_texture("res://public/assets/refresh/projectiles.png")
	final_boss_texture = _load_imported_or_png_texture("res://public/assets/refresh/boss.png")
	boss_weakpoint_texture = _load_imported_or_png_texture("res://public/assets/refresh/props.png")
	enemy_fleet_texture = _load_imported_or_png_texture("res://public/assets/refresh/fleet.png")
	player_ship_texture = _load_imported_or_png_texture("res://public/assets/refresh/player.png")
	title_background_texture = _load_imported_or_png_texture("res://public/assets/refresh/title.png")
	title_controls_texture = _load_imported_or_png_texture("res://public/assets/refresh/panel.png")
	status_icons_texture = _load_imported_or_png_texture("res://public/assets/refresh/icons.png")
	shield_fx_texture = _load_imported_or_png_texture("res://public/assets/refresh/shield.png")
	hud_chassis_texture = title_controls_texture
	overdrive_mote_texture = _load_imported_or_png_texture("res://public/assets/refresh/mote.png")
	score_crystal_texture = _load_imported_or_png_texture("res://public/assets/refresh/props.png")
	resonance_pod_texture = _load_imported_or_png_texture("res://public/assets/refresh/pod.png")
	explosion_texture = _load_imported_or_png_texture("res://public/assets/refresh/explosions.png")
	beam_player_texture = _load_imported_or_png_texture("res://public/assets/refresh/beam_player.png")
	beam_enemy_texture = _load_imported_or_png_texture("res://public/assets/refresh/beam_enemy.png")
	ending_texture = _load_imported_or_png_texture("res://public/assets/refresh/ending.png")
	audio_manager = AudioManagerScript.new()
	add_child(audio_manager)
	_setup_web_audio_lifecycle()
	_setup_overdrive_particles()
	_setup_render_layers()
	_setup_spectator()
	audio_manager.play_music("title", 0.25)
	_parse_web_query()
	queue_redraw()


func _exit_tree() -> void:
	_teardown_web_audio_lifecycle()
	if audio_manager and audio_manager.has_method("shutdown"):
		audio_manager.shutdown()


func _notification(what: int) -> void:
	if not audio_manager:
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		audio_manager.set_app_active(false)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		audio_manager.set_app_active(true)


func _setup_web_audio_lifecycle() -> void:
	if OS.get_name() != "Web":
		return
	_web_document = JavaScriptBridge.get_interface("document")
	_web_window = JavaScriptBridge.get_interface("window")
	_web_visibility_callback = JavaScriptBridge.create_callback(_on_web_visibility_changed)
	_web_pagehide_callback = JavaScriptBridge.create_callback(_on_web_pagehide)
	_web_pageshow_callback = JavaScriptBridge.create_callback(_on_web_pageshow)
	_web_document.addEventListener("visibilitychange", _web_visibility_callback)
	_web_window.addEventListener("pagehide", _web_pagehide_callback)
	_web_window.addEventListener("pageshow", _web_pageshow_callback)
	_on_web_visibility_changed([])


func _teardown_web_audio_lifecycle() -> void:
	if _web_document != null and _web_visibility_callback != null:
		_web_document.removeEventListener("visibilitychange", _web_visibility_callback)
	if _web_window != null and _web_pagehide_callback != null:
		_web_window.removeEventListener("pagehide", _web_pagehide_callback)
	if _web_window != null and _web_pageshow_callback != null:
		_web_window.removeEventListener("pageshow", _web_pageshow_callback)
	_web_visibility_callback = null
	_web_pagehide_callback = null
	_web_pageshow_callback = null
	_web_document = null
	_web_window = null


func _on_web_visibility_changed(_arguments: Array) -> void:
	if _web_document != null:
		audio_manager.set_app_active(not bool(_web_document.hidden))


func _on_web_pagehide(_arguments: Array) -> void:
	audio_manager.set_app_active(false)


func _on_web_pageshow(_arguments: Array) -> void:
	if _web_document == null or not bool(_web_document.hidden):
		audio_manager.set_app_active(true)


func _setup_runtime_models() -> void:
	player.setup(Config.W / 2.0, Config.PLAYER_Y, 42.0, Config.W - 42.0, Config.PLAYER_MIN_Y, Config.PLAYER_MAX_Y)
	projectiles.setup(Config.W, Config.H, Config.HUD)
	swarm.setup(Config.W, Config.HUD)
	boss_controller.setup(Config.W, Config.HUD)


func _setup_fonts() -> void:
	var font_path := "res://public/assets/fonts/Oxanium-wght.ttf"
	var base_font := load(font_path) as FontFile if ResourceLoader.exists(font_path) else null
	if not base_font:
		base_font = FontFile.new()
	if base_font.data.is_empty() and base_font.load_dynamic_font(font_path) != OK:
		font = ThemeDB.fallback_font
		display_font = font
		return
	var ui_variation := FontVariation.new()
	ui_variation.base_font = base_font
	var weight_tag := TextServerManager.get_primary_interface().name_to_tag("wght")
	ui_variation.variation_opentype = {weight_tag: 500}
	ui_variation.variation_embolden = 0.12
	font = ui_variation
	var display_variation := FontVariation.new()
	display_variation.base_font = base_font
	display_variation.variation_opentype = {weight_tag: 700}
	display_variation.variation_embolden = 0.42
	display_font = display_variation


func _setup_overdrive_particles() -> void:
	overdrive_aura = CPUParticles2D.new()
	overdrive_aura.name = "OverdriveAura"
	overdrive_aura.amount = 8
	overdrive_aura.lifetime = 0.72
	overdrive_aura.local_coords = false
	overdrive_aura.emitting = false
	overdrive_aura.direction = Vector2(0, -1)
	overdrive_aura.spread = 180.0
	overdrive_aura.gravity = Vector2.ZERO
	overdrive_aura.initial_velocity_min = 26.0
	overdrive_aura.initial_velocity_max = 82.0
	overdrive_aura.scale_amount_min = 0.05
	overdrive_aura.scale_amount_max = 0.12
	overdrive_aura.angular_velocity_min = -160.0
	overdrive_aura.angular_velocity_max = 160.0
	overdrive_aura.color = Color(1.0, 1.0, 1.0, 0.78)
	overdrive_aura.texture = overdrive_mote_texture
	add_child(overdrive_aura)

	overdrive_burst = CPUParticles2D.new()
	overdrive_burst.name = "OverdriveBurst"
	overdrive_burst.amount = 16
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
	overdrive_burst.scale_amount_min = 0.08
	overdrive_burst.scale_amount_max = 0.2
	overdrive_burst.angular_velocity_min = -240.0
	overdrive_burst.angular_velocity_max = 240.0
	overdrive_burst.color = Color(0.8, 0.95, 1.0, 0.7)
	overdrive_burst.texture = overdrive_mote_texture
	add_child(overdrive_burst)


func _setup_render_layers() -> void:
	fx = FxLayerScript.new()
	fx.game = self
	add_child(fx)
	ui_layer = UiLayerScript.new()
	ui_layer.game = self
	add_child(ui_layer)


func _setup_spectator() -> void:
	if not InputMap.has_action("toggle_ai_overlay"):
		InputMap.add_action("toggle_ai_overlay")
		var key := InputEventKey.new()
		key.keycode = KEY_V
		InputMap.action_add_event("toggle_ai_overlay", key)
	ai_pace = _load_ai_pace()


func _load_ai_pace() -> Array:
	if not FileAccess.file_exists(AI_PACE_PATH):
		return []
	var file := FileAccess.open(AI_PACE_PATH, FileAccess.READ)
	if file == null:
		return []
	var data: Variant = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY or typeof(data.get("scores")) != TYPE_ARRAY:
		return []
	return data.scores


# Keeps the best AI Demo run's score curve so manual runs can race against it.
func _finish_run() -> void:
	if control_mode != ControlMode.AI:
		return
	_pace_record.append(score)
	var best_final: int = int(ai_pace[-1]) if not ai_pace.is_empty() else -1
	if score <= best_final:
		return
	ai_pace = _pace_record.duplicate()
	if DisplayServer.get_name() == "headless":
		return
	var file := FileAccess.open(AI_PACE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"scores": ai_pace, "step": AI_PACE_STEP}))


func _ai_pace_score(time: float) -> int:
	if ai_pace.is_empty():
		return -1
	var position := time / AI_PACE_STEP
	var index := int(floorf(position))
	if index >= ai_pace.size() - 1:
		return int(ai_pace[-1])
	return int(lerpf(float(ai_pace[index]), float(ai_pace[index + 1]), position - float(index)))


# AI Demo only: slow motion and a camera push toward a big moment.
func _trigger_highlight(focus: Vector2, label: String, duration := 0.8) -> void:
	if control_mode != ControlMode.AI or state != GameState.PLAYING:
		return
	highlight_timer = maxf(highlight_timer, duration)
	highlight_focus = focus
	highlight_label = label


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
	beat_clock.update(dt, audio_manager.current_music_key, audio_manager.get_music_position())
	if beat_clock.ticked:
		_pending_beat_tick = true
	if hitstop > 0.0:
		hitstop = maxf(0.0, hitstop - dt)
		_update_feedback(dt)
		audio_manager.update_music(dt)
		_update_visuals(dt * 0.25)
		return
	highlight_timer = maxf(0.0, highlight_timer - dt)
	highlight_strength = move_toward(highlight_strength, 1.0 if highlight_timer > 0.0 else 0.0, dt * (6.0 if highlight_timer > 0.0 else 2.5))
	var game_dt := dt * lerpf(1.0, 0.35, highlight_strength)
	if state == GameState.PLAYING:
		_update_game(game_dt)
	_update_feedback(dt)
	audio_manager.update_music(dt)
	_update_visuals(game_dt)


func _update_visuals(dt: float) -> void:
	var player_pos := Vector2(player.x, player.y)
	if dt > 0.0:
		player_velocity = player_velocity.lerp((player_pos - _prev_player_pos) / dt, clampf(dt * 14.0, 0.0, 1.0))
	_prev_player_pos = player_pos
	var warp_target := 1.0 if stage_transition_timer > 0.0 else 0.0
	warp = lerpf(warp, warp_target, clampf(dt * (5.0 if warp_target > warp else 2.2), 0.0, 1.0))
	if fx:
		if state == GameState.PLAYING:
			fx.update(dt)
		var shake := Vector2.ZERO
		if screen_shake > 0.0:
			shake = Vector2(fx.rng.randf_range(-screen_shake, screen_shake), fx.rng.randf_range(-screen_shake, screen_shake)).round()
		var zoom := overdrive_zoom * (1.0 + 0.08 * highlight_strength)
		var pivot := Vector2(Config.W, Config.H) * 0.5
		pivot = pivot.lerp(Vector2(highlight_focus.x, clampf(highlight_focus.y, Config.HUD + 120.0, Config.H - 120.0)), highlight_strength)
		_world_xform = Transform2D(0.0, Vector2(zoom, zoom), 0.0, shake + pivot - pivot * zoom)
		fx.transform = _world_xform
		fx.visible = state in [GameState.PLAYING, GameState.PAUSED]
		fx.queue_redraw()
	if ui_layer:
		ui_layer.queue_redraw()
	queue_redraw()


func _update_feedback(dt: float) -> void:
	screen_shake = maxf(0.0, screen_shake - dt * 26.0)
	flash = maxf(0.0, flash - dt * 3.8)
	stage_banner = maxf(0.0, stage_banner - dt)


func _unhandled_input(event: InputEvent) -> void:
	_replay_web_title_music_after_input(event)
	if _handle_title_pointer_input(event):
		get_viewport().set_input_as_handled()
	elif _handle_touch_controls_input(event):
		get_viewport().set_input_as_handled()
	elif state == GameState.TITLE and (event.is_action_pressed("move_left") or event.is_action_pressed("move_right")):
		_toggle_selected_control_mode()
		get_viewport().set_input_as_handled()
	elif state == GameState.TITLE and selected_control_mode == ControlMode.AI and (event.is_action_pressed("move_up") or event.is_action_pressed("move_down")):
		ai_pilot.cycle_personality()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_ai_overlay") and state in [GameState.PLAYING, GameState.PAUSED]:
		show_ai_overlay = not show_ai_overlay
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


func _replay_web_title_music_after_input(event: InputEvent) -> void:
	if _web_title_music_replayed or OS.get_name() != "Web" or state != GameState.TITLE:
		return
	var is_initial_press := false
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		is_initial_press = mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		is_initial_press = (event as InputEventScreenTouch).pressed
	elif event is InputEventKey:
		is_initial_press = (event as InputEventKey).pressed and not (event as InputEventKey).echo
	elif event is InputEventJoypadButton:
		is_initial_press = (event as InputEventJoypadButton).pressed
	if not is_initial_press:
		return

	_web_title_music_replayed = true
	audio_manager.replay_current_music(0.08)


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
	var hitboxes := _title_mode_hitboxes(0.0)
	if Rect2(hitboxes.manual).has_point(position):
		selected_control_mode = ControlMode.MANUAL
		return true
	if Rect2(hitboxes.ai).has_point(position):
		# Clicking AI DEMO again cycles the pilot personality.
		if selected_control_mode == ControlMode.AI:
			ai_pilot.cycle_personality()
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
	best_chain = 0
	control_mode = selected_control_mode
	ai_pilot.reset()
	ai_pilot.record_debug = control_mode == ControlMode.AI
	run_time = 0.0
	_pace_record = []
	highlight_timer = 0.0
	highlight_strength = 0.0
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
	if fx:
		fx.clear()
	swarm.clear()
	network.clear()
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
	network.build(swarm.enemies)
	_setup_stage_gimmicks()


func _start_wave(next_wave: int) -> void:
	stage_wave = next_wave
	wave_transition_timer = 0.0
	projectiles.clear_enemy_bullets()
	var st: Dictionary = Config.STAGES[stage]
	swarm.load_stage(st, Config.ENEMY_STATS, difficulty, stage_wave)
	network.build(swarm.enemies)
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
	run_time += dt
	_graze_highlight_cooldown = maxf(0.0, _graze_highlight_cooldown - dt)
	while float(_pace_record.size()) * AI_PACE_STEP <= run_time:
		_pace_record.append(score)
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
	var beat_tick := _pending_beat_tick
	_pending_beat_tick = false
	_sync_popup_cooldown = maxf(0.0, _sync_popup_cooldown - dt)
	swarm.update(dt, st, stage, stage_timer, difficulty, player.x, projectiles, Config.ENEMY_STATS, beat_tick)
	_track_enemy_motion(dt)
	_update_network(dt)
	if boss_controller.update(dt, projectiles, beat_tick):
		audio_manager.play_sfx("boss")
	projectiles.update(dt)
	_update_stage_gimmicks(dt)
	_update_overdrive_feedback()
	_update_explosions(dt)
	_update_items(dt)
	_check_collisions()
	_stage_max_combo = maxi(_stage_max_combo, player.combo)
	_check_stage_end()


func _track_enemy_motion(dt: float) -> void:
	if dt <= 0.0:
		return
	for enemy in swarm.enemies:
		var pos := Vector2(enemy.x, enemy.y)
		var previous: Vector2 = enemy.get("prev_pos", pos)
		var jump := pos.distance_to(previous) > 160.0
		var velocity := Vector2.ZERO if jump else (pos - previous) / dt
		enemy.vx = lerpf(float(enemy.get("vx", 0.0)), velocity.x, 0.25)
		enemy.vy = lerpf(float(enemy.get("vy", 0.0)), velocity.y, 0.25)
		enemy.prev_pos = pos
		enemy.flash = maxf(0.0, float(enemy.get("flash", 0.0)) - dt * 7.0)
		if float(enemy.get("dive", 0.0)) > 0.0 and not jump:
			var trail: Array = enemy.get("trail", [])
			enemy.trail_t = float(enemy.get("trail_t", 0.0)) + dt
			if enemy.trail_t >= 0.045:
				enemy.trail_t = 0.0
				trail.append(pos)
				if trail.size() > 4:
					trail.pop_front()
			enemy.trail = trail
		elif enemy.has("trail"):
			enemy.erase("trail")


func _update_network(dt: float) -> void:
	var by_id: Dictionary = ResonanceNetworkScript.index_enemies(swarm.enemies)
	for surge in network.update(dt):
		var target: Variant = by_id.get(int(surge.to_id))
		if target == null or int(target.hp) <= 0:
			continue
		var target_pos := Vector2(target.x, target.y)
		var damage := int(surge.power)
		if str(target.kind).begins_with("mid_"):
			damage = maxi(damage, int(float(target.max_hp) * 0.2))
		target.hp -= damage
		target.flash = 1.0
		if surge.get("collapse", false):
			target.stun = 1.6
		if fx:
			fx.bolt(surge.from, target_pos, Color(1.0, 0.62, 0.3), 0.24, 3.0)
			fx.burst(target_pos, Color(1.0, 0.8, 0.5), 5, 160.0, 0.25)
		if int(target.hp) <= 0:
			_on_enemy_surged(target, surge, by_id)
		else:
			audio_manager.play_sfx("hit")
	for enemy in swarm.enemies:
		enemy.chain_value = network.chain_value(enemy, 1, by_id)


# Surge power and reach grow on the beat and during Overdrive.
func _emit_kill_surge(enemy: Dictionary) -> void:
	var by_id: Dictionary = ResonanceNetworkScript.index_enemies(swarm.enemies)
	var on_beat: bool = beat_clock.is_on_beat()
	var overdrive: bool = player.is_overdrive_active()
	var hops := 1 + (1 if on_beat else 0) + (2 if overdrive else 0)
	var power := 2 if on_beat and overdrive else 1
	var chain_id: int = network.start_chain(Vector2(enemy.x, enemy.y))
	var sent: int = network.emit(enemy, power, hops, chain_id, by_id)
	if sent > 0 and on_beat and fx:
		fx.ring(Vector2(enemy.x, enemy.y), Color(1.0, 0.86, 0.45, 0.8), 110.0, 0.3, 3.0)


func _on_enemy_surged(enemy: Dictionary, surge: Dictionary, by_id: Dictionary) -> void:
	var chain_count: int = network.register_chain_kill(int(surge.chain_id))
	best_chain = maxi(best_chain, chain_count)
	var multiplier: float = player.register_kill() * (1.0 + 0.25 * float(chain_count - 1))
	if player.is_overdrive_active():
		multiplier *= 1.75
	score += int(float(enemy.score) * multiplier)
	player.add_resonance(2.0 + minf(6.0, float(chain_count)) * 0.5)
	var is_midboss: bool = str(enemy.kind).begins_with("mid_")
	var big: bool = enemy.kind in ["armor", "saucer", "commander"] or is_midboss
	explosions.append({"x": enemy.x, "y": enemy.y, "t": 0.0, "big": big})
	_spawn_death_fx(enemy, big)
	if chain_count == 6:
		_trigger_highlight(Vector2(enemy.x, enemy.y), "CHAIN x6")
	if fx and chain_count >= 3:
		var chain: Dictionary = network.chains.get(int(surge.chain_id), {})
		var origin: Vector2 = chain.get("origin", Vector2(enemy.x, enemy.y))
		fx.popup(origin + Vector2(0, -30), "CHAIN x" + str(chain_count), Color("#ffb46a") if chain_count < 6 else Color("#ffe27a"), 18 + mini(10, chain_count), 0.9)
	if enemy.kind == "commander":
		_handle_commander_defeat(enemy)
	elif is_midboss:
		_handle_midboss_defeat(enemy)
	elif randf() < 0.5:
		_maybe_drop_item(enemy, false)
	network.emit(enemy, int(surge.power), int(surge.hops_left), int(surge.chain_id), by_id)
	_add_shake(1.4)
	audio_manager.play_sfx("boom")


func _spawn_death_fx(enemy: Dictionary, big: bool) -> void:
	if not fx:
		return
	var pos := Vector2(enemy.x, enemy.y)
	var color: Color = Config.ENEMY_STATS.get(enemy.kind, {"color": Config.UI_AMBER}).color
	var scale := 1.8 if str(enemy.kind).begins_with("mid_") else 1.3 if big else 1.0
	fx.shatter(pos, int(8 * scale), 210.0 * scale, scale)
	fx.burst(pos, Color(1.0, 0.75, 0.4), int(14 * scale), 340.0 * scale, 0.45)
	fx.ring(pos, Color(1.0, 0.6, 0.3, 0.8), 70.0 * scale, 0.32)
	fx.flash_glow(pos, Color(1.0, 0.8, 0.5, 0.9), 160.0 * scale, 0.24)
	if scale > 1.5:
		fx.ring(pos, Color(1.0, 0.95, 0.8, 0.6), 190.0, 0.55, 4.0)


func _update_overdrive_feedback() -> void:
	var active := player.is_overdrive_active()
	if overdrive_aura:
		overdrive_aura.global_position = Vector2(player.x, player.y + 12.0)
		overdrive_aura.emitting = active and state == GameState.PLAYING
	audio_manager.set_music_overdriven(active and state == GameState.PLAYING)


func _read_player_command() -> Dictionary:
	if control_mode == ControlMode.AI:
		return ai_pilot.get_command(player, swarm.enemies, boss_controller.boss, projectiles.bullets, items, beat_clock.is_on_beat(0.12))
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
	if beat_clock.is_on_beat():
		player.overdrive_timer += 1.5
		score += 500
		if fx:
			fx.popup(Vector2(player.x, player.y - 96.0), "PERFECT SYNC", Color("#ffe27a"), 24, 1.2)
			fx.ring(Vector2(player.x, player.y), Color(1.0, 0.88, 0.45, 0.9), 420.0, 0.7, 4.0, 60.0)
	audio_manager.set_music_overdriven(true)
	audio_manager.play_sfx("overdrive")
	_add_shake(4.0)
	_add_flash(0.58, 0.025)
	if fx:
		fx.ring(Vector2(player.x, player.y), Color(0.55, 0.95, 1.0, 0.95), 320.0, 0.55, 6.0, 40.0)
		fx.ring(Vector2(player.x, player.y), Color(1.0, 0.92, 0.6, 0.7), 200.0, 0.4, 3.0, 20.0)
		fx.flash_glow(Vector2(player.x, player.y), Color(0.6, 0.95, 1.0, 0.8), 380.0, 0.35)
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
	if fx:
		fx.ring(Vector2(player.x, player.y - 40.0), Color(0.6, 0.95, 1.0, 0.9), 260.0, 0.5, 5.0, 30.0)
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
			_spawn_death_fx(enemy, enemy.kind in ["armor", "saucer"])
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
			var impact := Vector2(bullet.x, bullet.y)
			bullet.y = -999.0 if not bullet.enemy else Config.H + 999.0
			if not bullet.enemy:
				hazard.hp -= bullet.power
				score += 20
				if fx:
					fx.directional_sparks(impact, Vector2(0, 1), Color(1.0, 0.75, 0.45), 3, 220.0)
				explosions.append({"x": impact.x, "y": impact.y, "t": 0.0, "big": false})
		if hazard.hp <= 0:
			score += 320
			explosions.append({"x": hazard.x, "y": hazard.y, "t": 0.0, "big": true})
			if fx:
				fx.shatter(Vector2(hazard.x, hazard.y), 14, 240.0, 1.4)
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
			if fx:
				fx.flash_glow(Vector2(bullet.x, bullet.y), Color(0.6, 1.0, 1.0, 0.8), 44.0, 0.2)
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
				var impact := Vector2(bullet.x, bullet.y)
				bullet.y = -999.0
				enemy.hp -= bullet.power
				enemy.flash = 1.0
				if enemy.hp <= 0:
					_on_enemy_shot_down(enemy)
				else:
					if enemy.kind in ["armor", "commander", "mid_lancer", "mid_orbit", "mid_anchor"]:
						hitstop = maxf(hitstop, 0.012)
					if fx:
						fx.directional_sparks(impact + Vector2(0, 6.0), Vector2(0, 1), Color(1.0, 0.78, 0.45), 4, 280.0)
					audio_manager.play_sfx("hit")
				break

		if bullet.y > -900.0 and boss_controller.is_alive() and _boss_hit_test(Vector2(bullet.x, bullet.y), bullet.r):
			var impact := Vector2(bullet.x, bullet.y)
			bullet.y = -999.0
			var weak_bonus := _damage_boss_part(impact, bullet.power)
			boss_controller.boss.hp -= bullet.power + weak_bonus
			player.add_resonance(1.4 + float(bullet.power) * 0.65)
			var boss_score: int = 8 + min(player.combo, 20) + weak_bonus * 14
			score += int(boss_score * (2.0 if player.is_overdrive_active() else 1.0))
			explosions.append({"x": impact.x, "y": impact.y + 20.0, "t": 0.0, "big": false})
			if fx:
				fx.directional_sparks(impact + Vector2(0, 12.0), Vector2(0, 1), Color(1.0, 0.7, 0.4), 3 + weak_bonus, 300.0)
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
				var synced := beat_clock.is_on_beat()
				if distance < 36.0 + bullet.r and _graze_highlight_cooldown <= 0.0 and control_mode == ControlMode.AI:
					_graze_highlight_cooldown = 6.0
					_trigger_highlight(Vector2(player.x, player.y), "RAZOR GRAZE", 0.45)
				if fx:
					fx.burst(Vector2(bullet.x, bullet.y), Color(1.0, 0.9, 0.5) if synced else Color(0.55, 0.95, 1.0), 6 if synced else 4, 150.0, 0.22, 1.4)
					if synced and _sync_popup_cooldown <= 0.0:
						_sync_popup_cooldown = 0.5
						fx.popup(Vector2(player.x + 40.0, player.y - 40.0), "SYNC", Color("#ffe27a"), 14, 0.6)
				player.add_resonance(12.0 if synced else 7.5)
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
			if fx:
				var pickup_color: Color = Config.CHIP_TRACKS[item.kind].color if Config.CHIP_TRACKS.has(item.kind) else Config.UI_GREEN
				fx.ring(Vector2(player.x, player.y), pickup_color, 120.0 if leveled_up else 64.0, 0.34, 3.0, 20.0)
				fx.burst(Vector2(item.x, item.y), pickup_color, 10 if leveled_up else 5, 220.0, 0.32)
				if leveled_up:
					fx.popup(Vector2(player.x, player.y - 70.0), str(Config.CHIP_TRACKS[item.kind].name) + " LV" + str(player.chip_levels[item.kind]), pickup_color, 20, 1.1)
			flash = maxf(flash, 0.25 if leveled_up else 0.12)
			_add_shake(2.2 if leveled_up else 0.5)
			audio_manager.play_sfx("level_up" if leveled_up else "chip")
	items = items.filter(func(item: Dictionary) -> bool: return item.y < Config.H + 100.0)


func _on_enemy_shot_down(enemy: Dictionary) -> void:
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
	var big: bool = enemy.kind in ["armor", "saucer", "commander"] or is_midboss
	explosions.append({"x": enemy.x, "y": enemy.y, "t": 0.0, "big": big})
	_spawn_death_fx(enemy, big)
	if enemy.kind == "commander":
		_handle_commander_defeat(enemy)
	elif is_midboss:
		_handle_midboss_defeat(enemy)
	else:
		_maybe_drop_item(enemy, false)
	_emit_kill_surge(enemy)
	if is_midboss:
		_add_shake(4.5)
		_add_flash(0.46, 0.055)
		audio_manager.play_sfx("midboss_break")
	else:
		_add_shake(1.8)
		hitstop = maxf(hitstop, 0.025)
		audio_manager.play_sfx("boom")


func _hurt() -> void:
	_stage_damage += 1
	var shield_absorb: bool = player.shield > 0
	var dead: bool = player.hurt()
	explosions.append({"x": player.x, "y": player.y, "t": 0.0, "big": true})
	if fx:
		fx.ring(Vector2(player.x, player.y), Color(0.7, 0.95, 1.0, 0.9), 240.0, 0.45, 5.0, 30.0)
		fx.burst(Vector2(player.x, player.y), Color(0.7, 0.95, 1.0), 24, 420.0, 0.5, 2.2)
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
		_finish_run()
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
		_finish_run()
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
			wave_transition_timer = 0.55
			projectiles.clear_enemy_bullets()
			audio_manager.play_sfx("wave")
			return
		score += 1200 + stage * 550 + (900 if player.no_miss_stage else 0)
		_record_stage_result()
		player.bombs = mini(5, player.bombs + 1)
		player.shield = player.shield_max
		if player.lives <= 2:
			player.lives += 1
		audio_manager.play_sfx("stage_clear")
		pending_stage = stage + 1
		stage_transition_timer = 0.95
		stage_banner = 0.95


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
	# Network collapse: the hub's destruction surges through every linked node and severs the fleet.
	var by_id: Dictionary = ResonanceNetworkScript.index_enemies(swarm.enemies)
	var chain_id: int = network.start_chain(Vector2(enemy.x, enemy.y))
	if network.collapse(enemy, chain_id, by_id) > 0 and fx:
		fx.popup(Vector2(enemy.x, enemy.y + 40.0), "NETWORK COLLAPSE", Color("#ffe27a"), 24, 1.2)
		_trigger_highlight(Vector2(enemy.x, enemy.y), "NETWORK COLLAPSE", 1.0)
		fx.ring(Vector2(enemy.x, enemy.y), Color(1.0, 0.75, 0.4, 0.9), 520.0, 0.8, 5.0, 40.0)
	var kept_bullets: Array[Dictionary] = []
	for bullet in projectiles.bullets:
		if not bullet.enemy or Vector2(bullet.x, bullet.y).distance_to(Vector2(enemy.x, enemy.y)) > 185.0:
			kept_bullets.append(bullet)
	projectiles.bullets = kept_bullets
	_drop_commander_reward(enemy)


func _handle_midboss_defeat(enemy: Dictionary) -> void:
	_trigger_highlight(Vector2(enemy.x, enemy.y), "MIDBOSS DOWN", 0.9)
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
	_c = self
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_rect(Rect2(0, 0, Config.W, Config.H), Color("#02040c"))
	if state == GameState.TITLE:
		return
	draw_set_transform_matrix(_world_xform)
	_draw_background()
	_draw_playfield()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func draw_ui_pass(canvas: CanvasItem) -> void:
	_c = canvas
	if fx and state in [GameState.PLAYING, GameState.PAUSED]:
		fx.draw_popups(canvas, display_font if display_font else font, _world_xform)
	if state in [GameState.PLAYING, GameState.PAUSED]:
		hud.draw_hud(_c, font, display_font, score, stage, stage_wave, int(Config.STAGES[stage].get("waves", 1)), player.lives, player.bombs, player.shield, player.combo, boss_controller.boss, player.resonance, player.overdrive_timer, player.get_overdrive_duration(), player.chip_levels, player.chip_progress, audio_manager.muted, hud_chassis_texture, status_icons_texture)
	if state in [GameState.PLAYING, GameState.PAUSED]:
		_draw_beat_pips()
		_draw_highlight_frame()
		if control_mode == ControlMode.AI:
			_draw_ai_readout()
		else:
			_draw_ai_pace()
	if flash > 0.0:
		_c.draw_rect(Rect2(0, Config.HUD, Config.W, Config.PLAY_H), Color(1.0, 0.92, 0.72, flash * 0.34))
	if stage_banner > 0.0 and state == GameState.PLAYING:
		var alpha := minf(1.0, stage_banner)
		_draw_stage_banner(Config.STAGES[stage].name, Config.HUD + 118.0, alpha)
	if state != GameState.PLAYING:
		_draw_overlay()
	if _should_draw_touch_controls():
		_draw_touch_controls()
	_c = self


func _draw_background() -> void:
	var st: Dictionary = Config.STAGES[stage]
	var tint: Color = st.tint
	if background_texture:
		var cell_width := float(background_texture.get_width()) / 2.0
		var cell_height := float(background_texture.get_height()) / 3.0
		# Crop inside the cell so the plate can drift with the player for parallax depth.
		var crop_width := cell_width * 0.9
		var crop_height := crop_width * Config.PLAY_H / Config.W
		var spare := Vector2(cell_width - crop_width, cell_height - crop_height)
		var sway_x := clampf((player.x - Config.W * 0.5) / (Config.W * 0.5), -1.0, 1.0) * 0.4
		var drift_y := sin(stage_timer * 0.07) * 0.5
		var source_x := float(stage % 2) * cell_width + spare.x * (0.5 + sway_x)
		var source_y := float(stage / 2) * cell_height + spare.y * (0.5 + drift_y)
		var panel := Rect2(source_x, source_y, crop_width, crop_height)
		_c.draw_texture_rect_region(background_texture, Rect2(0, Config.HUD, Config.W, Config.PLAY_H), panel, Color.WHITE)
	else:
		_c.draw_rect(Rect2(0, Config.HUD, Config.W, Config.PLAY_H), Color("#081323"))
	_c.draw_rect(Rect2(0, Config.HUD, Config.W, Config.PLAY_H), Color(0, 0, 0, 0.16))
	# Three star layers: far dust, mid stars and near streaks that stretch into a warp between stages.
	var speed_scale: float = st.scroll * (1.0 + warp * 9.0)
	var layers := [
		{"count": 70, "speed": 10.0, "size": 1.0, "alpha": 0.35, "streak": 0.0},
		{"count": 38, "speed": 42.0, "size": 1.5, "alpha": 0.6, "streak": 0.02},
		{"count": 14, "speed": 150.0, "size": 2.0, "alpha": 0.8, "streak": 0.06},
	]
	var sway: float = player.x - Config.W * 0.5
	for layer_index in range(layers.size()):
		var layer: Dictionary = layers[layer_index]
		var count := int(float(layer.count) * st.stars)
		for i in range(count):
			var seed_x := fmod(float(i) * 149.3 + float(layer_index) * 311.0, Config.W)
			var x := fposmod(seed_x - sway * float(layer_index + 1) * 0.025, Config.W)
			var y: float = Config.HUD + fposmod(float(i) * 61.7 + float(layer_index) * 97.0 + stage_timer * float(layer.speed) * speed_scale, Config.PLAY_H)
			var streak: float = (float(layer.streak) + warp * 0.9) * float(layer.speed) * speed_scale
			var color := Color(tint, float(layer.alpha)) if i % 5 == 0 else Color(1, 1, 1, float(layer.alpha))
			if streak > 1.5:
				_c.draw_line(Vector2(x, y - streak), Vector2(x, y), color, float(layer.size))
			else:
				_c.draw_rect(Rect2(x, y, float(layer.size), float(layer.size)), color)


func _draw_playfield() -> void:
	for hazard in stage_hazards:
		_draw_stage_hazard(hazard)
	_draw_threat_previews()
	_draw_network_links()
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
	if fx:
		fx.draw_debris(_c)
	for explosion in explosions:
		_draw_explosion(explosion)


func _draw_player() -> void:
	var tint := Color(1, 1, 1, 0.52) if player.invuln > 0.0 and int(stage_timer * 16.0) % 2 == 0 else Color.WHITE
	if player.is_overdrive_active():
		_draw_resonance_pods()
	if player_ship_texture:
		var size := 92.0
		var bank := clampf(player_velocity.x / 430.0, -1.0, 1.0)
		_draw_sprite_banked(player_ship_texture, Rect2(), Vector2(player.x, player.y), Vector2(size, size), bank * 0.16, Vector2(1.0 - absf(bank) * 0.12, 1.0), tint)
	if player.shield > 0:
		_draw_player_shield()
	# The cockpit marks the unchanged collision center even during Overdrive.
	_c.draw_circle(Vector2(player.x, player.y), 3.0, Color.WHITE)
	_c.draw_arc(Vector2(player.x, player.y), 4.5, 0.0, TAU, 16, Config.UI_CYAN, 1.0)


# Draws a sprite rotated/squashed around its center while keeping the world transform.
func _draw_sprite_banked(texture: Texture2D, region: Rect2, center: Vector2, size: Vector2, rotation: float, squash: Vector2, tint: Color) -> void:
	_c.draw_set_transform_matrix(_world_xform * Transform2D(rotation, squash, 0.0, center))
	var rect := Rect2(-size * 0.5, size)
	if region.has_area():
		_c.draw_texture_rect_region(texture, rect, region, tint)
	else:
		_c.draw_texture_rect(texture, rect, false, tint)
	_c.draw_set_transform_matrix(_world_xform)


func _draw_resonance_pods() -> void:
	if not resonance_pod_texture:
		return
	for side in [-1.0, 1.0]:
		var position := Vector2(player.x + side * (56.0 + sin(stage_timer * 2.4) * 4.0), player.y - 14.0 + cos(stage_timer * 2.4) * 5.0)
		var origin := Vector2(player.x + side * 23.0, player.y + 5.0)
		_c.draw_line(origin, position, Color(Config.UI_CYAN, 0.2), 1.0)
		_c.draw_texture_rect(resonance_pod_texture, Rect2(position - Vector2(15, 19), Vector2(30, 38)), false)


func _draw_player_shield() -> void:
	if not shield_fx_texture:
		return
	var cell := float(shield_fx_texture.get_width()) / 2.0
	var frame := int(stage_timer * 7.0) % 4
	var region := Rect2(float(frame % 2) * cell, float(frame / 2) * cell, cell, cell)
	var size := 118.0 + float(clampi(player.shield, 1, 2) - 1) * 8.0
	var tint := Color(1, 1, 1, 0.48 if player.shield == 1 else 0.7)
	_c.draw_texture_rect_region(shield_fx_texture, Rect2(player.x - size * 0.5, player.y - size * 0.5, size, size), region, tint)


func _draw_enemy(enemy: Dictionary) -> void:
	if enemy_fleet_texture:
		_draw_renewal_enemy(enemy)


func _enemy_region(enemy: Dictionary) -> Rect2:
	var order := ["bug", "diver", "zig", "armor", "saucer", "commander", "mid_lancer", "mid_orbit", "mid_anchor"]
	var index := order.find(str(enemy.kind))
	var cell := float(enemy_fleet_texture.get_width()) / 3.0
	return Rect2(float(index % 3) * cell, float(index / 3) * cell, cell, cell)


func _enemy_draw_size(enemy: Dictionary) -> float:
	var is_midboss: bool = str(enemy.kind).begins_with("mid_")
	var pulse := 1.0 + sin(stage_timer * 5.0 + float(enemy.id)) * (0.025 if is_midboss else 0.012)
	# The whole formation breathes with the BGM beat.
	pulse += beat_clock.pulse(6.0) * (0.03 if is_midboss else 0.05)
	return float(enemy.size) * (1.92 if is_midboss else 1.74) * pulse


func _enemy_rotation(enemy: Dictionary) -> float:
	var velocity := Vector2(float(enemy.get("vx", 0.0)), float(enemy.get("vy", 0.0)))
	if float(enemy.get("dive", 0.0)) > 0.0 and velocity.length() > 30.0:
		# Sprites face down; lean the nose into the dive direction.
		return clampf(-atan2(velocity.x, velocity.y), -0.7, 0.7)
	return clampf(-velocity.x / 260.0, -0.22, 0.22)


func _draw_renewal_enemy(enemy: Dictionary) -> void:
	var region := _enemy_region(enemy)
	var is_midboss: bool = str(enemy.kind).begins_with("mid_")
	var draw_size := _enemy_draw_size(enemy)
	var center := Vector2(enemy.x, enemy.y)
	var rotation := _enemy_rotation(enemy)
	var tint := Color.WHITE
	var stunned := float(enemy.get("stun", 0.0)) > 0.0
	if stunned:
		center += Vector2(fx.rng.randf_range(-2.0, 2.0), fx.rng.randf_range(-1.5, 1.5)) if fx else Vector2.ZERO
		rotation += sin(stage_timer * 30.0 + float(enemy.id)) * 0.08
	if enemy.max_hp > 1 and not is_midboss:
		var hp_ratio := clampf(float(enemy.hp) / float(enemy.max_hp), 0.0, 1.0)
		tint = Color(1.0, 0.72 + hp_ratio * 0.28, 0.7 + hp_ratio * 0.3, 1.0)
	if enemy.has("trail"):
		var trail: Array = enemy.trail
		for t_index in range(trail.size()):
			var ghost_alpha := 0.07 + 0.2 * float(t_index) / float(maxi(1, trail.size()))
			_draw_sprite_banked(enemy_fleet_texture, region, trail[t_index], Vector2.ONE * draw_size * 0.96, rotation, Vector2.ONE, Color(1.0, 0.55, 0.3, ghost_alpha))
	if is_midboss:
		var aura_color: Color = Config.ENEMY_STATS[enemy.kind].color
		_c.draw_circle(center, draw_size * 0.48, Color(aura_color, 0.07))
		_c.draw_arc(center, draw_size * 0.5, stage_timer * 0.8, stage_timer * 0.8 + TAU * 0.7, 44, Color(aura_color, 0.55), 2.0)
		_c.draw_arc(center, draw_size * 0.56, -stage_timer * 1.1, -stage_timer * 1.1 + TAU * 0.35, 24, Color(aura_color, 0.35), 2.0)
	if stunned:
		tint = Color(0.62, 0.66, 0.78, 1.0)
	_draw_sprite_banked(enemy_fleet_texture, region, center, Vector2.ONE * draw_size, rotation, Vector2(1.0 - absf(rotation) * 0.25, 1.0), tint)
	if is_midboss:
		var bar_width := 108.0
		var hp_ratio := clampf(float(enemy.hp) / maxf(1.0, float(enemy.max_hp)), 0.0, 1.0)
		var bar_y: float = enemy.y + draw_size * 0.5
		_c.draw_rect(Rect2(enemy.x - bar_width * 0.5, bar_y, bar_width, 3.0), Color(1, 1, 1, 0.12))
		_c.draw_rect(Rect2(enemy.x - bar_width * 0.5, bar_y, bar_width * hp_ratio, 3.0), Config.ENEMY_STATS[enemy.kind].color)


# Additive pass rendered by FxLayer on top of the world (under the HUD).
func draw_light_pass(canvas: Node2D) -> void:
	var st: Dictionary = Config.STAGES[stage]
	var tint: Color = st.tint
	var beat_pulse: float = beat_clock.pulse()
	var bar_pulse: float = beat_clock.bar_pulse()
	for i in range(4):
		var nebula_pos := Vector2(fposmod(float(i) * 263.0 + stage_timer * 6.0, Config.W + 400.0) - 200.0, Config.HUD + 90.0 + float(i) * 150.0 + sin(stage_timer * 0.2 + float(i)) * 40.0)
		canvas.glow(nebula_pos, Color(tint, 0.05 + bar_pulse * 0.05), 520.0)
	# Rhythm frame: side rails flash on each beat, a sonar sweep crosses the field once per bar.
	var rail_color := Color(tint, 0.1 + beat_pulse * 0.45)
	for rail_x in [5.0, Config.W - 5.0]:
		canvas.draw_line(Vector2(rail_x, Config.HUD), Vector2(rail_x, Config.H), rail_color, 2.0)
		canvas.glow_stretched(Vector2(rail_x, (Config.HUD + Config.H) * 0.5), Color(tint, beat_pulse * 0.22), Vector2(34.0, Config.PLAY_H))
	var sweep_y := Config.HUD + fposmod(beat_clock.beat, 4.0) / 4.0 * Config.PLAY_H
	canvas.glow_stretched(Vector2(Config.W * 0.5, sweep_y), Color(tint, 0.05), Vector2(Config.W * 1.4, 26.0))
	for bullet in projectiles.bullets:
		var pos := Vector2(bullet.x, bullet.y)
		var color: Color = bullet.color
		if bullet.enemy:
			var visual := str(bullet.get("sprite", "enemy"))
			if visual == "beam":
				canvas.glow_stretched(pos, Color(1.0, 0.3, 0.15, 0.55), Vector2(110.0, 190.0))
				continue
			var pulse := 0.8 + sin(stage_timer * 18.0 + pos.x * 0.05) * 0.2
			canvas.glow(pos, Color(color, 0.85 * pulse), float(bullet.r) * 8.0)
			canvas.glow(pos, Color(1, 1, 1, 0.35), float(bullet.r) * 2.6)
		else:
			var velocity := Vector2(bullet.vx, bullet.vy)
			var length := clampf(velocity.length() * 0.07, 20.0, 64.0)
			canvas.glow_stretched(pos + Vector2(0, length * 0.3), Color(color, 0.5), Vector2(float(bullet.r) * 5.0, length))
	_draw_network_lights(canvas)
	for enemy in swarm.enemies:
		_draw_enemy_lights(canvas, enemy)
	if boss_controller.is_alive() and boss_controller.boss.has("parts"):
		for part in boss_controller.boss.parts:
			if not part.alive:
				continue
			var part_pos: Vector2 = Vector2(boss_controller.boss.x, boss_controller.boss.y) + part.offset
			var core_pulse := 0.6 + sin(stage_timer * 6.0 + part_pos.x) * 0.25
			canvas.glow(part_pos, Color(1.0, 0.35, 0.2, 0.75 * core_pulse), 170.0)
		for engine_x in [-62.0, 62.0]:
			var engine := Vector2(boss_controller.boss.x + engine_x, boss_controller.boss.y - 150.0)
			canvas.glow_stretched(engine + Vector2(0, -20), Color(1.0, 0.45, 0.2, 0.4 + fx.rng.randf() * 0.15), Vector2(34.0, 90.0))
	for item in items:
		var item_color := Config.UI_GREEN
		if Config.CHIP_TRACKS.has(item.kind):
			item_color = Config.CHIP_TRACKS[item.kind].color
		canvas.glow(Vector2(item.x, item.y), Color(item_color, 0.32 + sin(item.t * 7.0) * 0.08), 96.0)
	for crystal in score_crystals:
		canvas.glow(Vector2(crystal.x, crystal.y), Color(0.45, 0.95, 1.0, 0.4), 46.0)
	for wave in bomb_waves:
		var progress := clampf(wave.t / 0.62, 0.0, 1.0)
		canvas.glow_stretched(Vector2(wave.x, (Config.HUD + player.y) * 0.5), Color(0.5, 0.95, 1.0, 0.5 * (1.0 - progress)), Vector2(wave.width * 1.6, player.y - Config.HUD))
	if state == GameState.PLAYING or state == GameState.PAUSED:
		_draw_player_lights(canvas)
		if control_mode == ControlMode.AI and show_ai_overlay:
			_draw_ai_overlay(canvas)


# Tactical hologram of the AI Pilot's reasoning: sampled lanes, chosen path, threats and lock-on.
func _draw_ai_overlay(canvas: Node2D) -> void:
	var debug: Dictionary = ai_pilot.debug
	if debug.is_empty():
		return
	var player_pos := Vector2(player.x, player.y)
	var holo := Color(0.35, 0.95, 1.0)
	for sample in debug.get("samples", []):
		var sample_danger := clampf(float(sample[1]) / 2.4, 0.0, 1.0)
		var color := Color(0.3, 1.0, 0.65).lerp(Color(1.0, 0.3, 0.25), sample_danger)
		var pos: Vector2 = sample[0]
		canvas.draw_rect(Rect2(pos - Vector2(2, 2), Vector2(4, 4)), Color(color, 0.16 + sample_danger * 0.2))
	for bullet in projectiles.bullets:
		if not bullet.enemy:
			continue
		var bullet_pos := Vector2(bullet.x, bullet.y)
		if bullet_pos.distance_to(player_pos) > 320.0:
			continue
		var future := bullet_pos + Vector2(bullet.vx, bullet.vy) * 0.45
		canvas.draw_line(bullet_pos, future, Color(1.0, 0.4, 0.3, 0.32), 1.0, true)
	var target: Vector2 = debug.get("target", player_pos)
	if target.distance_to(player_pos) > 6.0:
		var steps := 10
		for i in range(steps):
			if i % 2 == 1:
				continue
			var a := player_pos.lerp(target, float(i) / float(steps))
			var b := player_pos.lerp(target, float(i + 1) / float(steps))
			canvas.draw_line(a, b, Color(holo, 0.55), 1.5, true)
	canvas.draw_arc(target, 9.0, 0.0, TAU, 20, Color(holo, 0.7), 1.5, true)
	canvas.draw_line(target + Vector2(-14, 0), target + Vector2(-6, 0), Color(holo, 0.7), 1.0)
	canvas.draw_line(target + Vector2(6, 0), target + Vector2(14, 0), Color(holo, 0.7), 1.0)
	var lock_pos := Vector2.INF
	var lock_radius := 40.0
	var target_id := int(debug.get("target_id", -1))
	if target_id == -2 and boss_controller.is_alive():
		lock_pos = Vector2(boss_controller.boss.x, boss_controller.boss.y + 40.0)
		lock_radius = 120.0
	elif target_id >= 0:
		for enemy in swarm.enemies:
			if int(enemy.id) == target_id:
				lock_pos = Vector2(enemy.x, enemy.y)
				lock_radius = _enemy_draw_size(enemy) * 0.62
				break
	if lock_pos != Vector2.INF:
		var spin := stage_timer * 2.2
		for i in range(4):
			var start_angle := spin + float(i) * PI * 0.5
			canvas.draw_arc(lock_pos, lock_radius, start_angle, start_angle + 0.5, 8, Color(1.0, 0.8, 0.4, 0.75), 2.0, true)


func _link_color(link: Dictionary) -> Color:
	match str(link.kind):
		"hub":
			return Color("#ffc46a")
		"tether":
			return Color("#ff7a5a")
	return Color("#d98a4e")


func _draw_network_links() -> void:
	var by_id: Dictionary = ResonanceNetworkScript.index_enemies(swarm.enemies)
	for link in network.active_links(by_id):
		var a: Dictionary = by_id[int(link.a)]
		var b: Dictionary = by_id[int(link.b)]
		var width := 3.0 if link.kind != "grid" else 1.6
		_c.draw_line(Vector2(a.x, a.y), Vector2(b.x, b.y), Color(0.08, 0.05, 0.04, 0.55), width + 2.0)
		_c.draw_line(Vector2(a.x, a.y), Vector2(b.x, b.y), Color(_link_color(link), 0.34), width)


func _draw_network_lights(canvas: Node2D) -> void:
	var by_id: Dictionary = ResonanceNetworkScript.index_enemies(swarm.enemies)
	var pulse: float = beat_clock.pulse(4.0)
	var travel: float = beat_clock.phase()
	for link in network.active_links(by_id):
		var a: Dictionary = by_id[int(link.a)]
		var b: Dictionary = by_id[int(link.b)]
		var start := Vector2(a.x, a.y)
		var end := Vector2(b.x, b.y)
		var color := _link_color(link)
		canvas.draw_line(start, end, Color(color, 0.1 + pulse * 0.32), 2.0 if link.kind == "grid" else 3.0, true)
		# Energy packets travel along the links once per beat.
		var packet := start.lerp(end, travel if (int(link.a) + int(link.b)) % 2 == 0 else 1.0 - travel)
		canvas.glow(packet, Color(color, 0.35 + pulse * 0.3), 16.0 if link.kind == "grid" else 24.0)
	for surge in network.surges:
		var target: Variant = by_id.get(int(surge.to_id))
		if target == null:
			continue
		var ratio := clampf(float(surge.t) / ResonanceNetworkScript.SURGE_HOP_TIME, 0.0, 1.0)
		if float(surge.t) < 0.0:
			continue
		var head: Vector2 = Vector2(surge.from).lerp(Vector2(target.x, target.y), ratio)
		canvas.draw_line(surge.from, head, Color(1.0, 0.75, 0.4, 0.8), 3.0, true)
		canvas.glow(head, Color(1.0, 0.9, 0.6, 0.9), 34.0)


func _draw_enemy_lights(canvas: Node2D, enemy: Dictionary) -> void:
	var center := Vector2(enemy.x, enemy.y)
	var draw_size := _enemy_draw_size(enemy)
	var rotation := _enemy_rotation(enemy)
	var is_midboss: bool = str(enemy.kind).begins_with("mid_")
	var base_color: Color = Config.ENEMY_STATS[enemy.kind].color
	var up := Vector2(0, -1).rotated(rotation)
	var diving: bool = float(enemy.get("dive", 0.0)) > 0.0
	var flame_len: float = draw_size * (0.55 if diving else 0.32) * (0.85 + fx.rng.randf() * 0.3)
	var engine_pos := center + up * draw_size * 0.38
	canvas.glow_stretched(engine_pos + up * flame_len * 0.35, Color(1.0, 0.5, 0.22, 0.8 if diving else 0.55), Vector2(draw_size * 0.32, flame_len))
	if float(enemy.get("stun", 0.0)) > 0.0:
		if fx.rng.randf() < 0.35:
			var arc_end := center + Vector2(fx.rng.randf_range(-1.0, 1.0), fx.rng.randf_range(-1.0, 1.0)) * draw_size * 0.5
			canvas.draw_line(center, arc_end, Color(0.6, 0.85, 1.0, 0.7), 1.5, true)
		return
	var core_pulse := 0.55 + sin(stage_timer * 4.0 + float(enemy.id)) * 0.2
	canvas.glow(center, Color(base_color, (0.4 if is_midboss else 0.26) * core_pulse), draw_size * (1.3 if is_midboss else 0.95))
	if enemy.get("armed", false):
		# Shot telegraph: the core charges and a ring closes in until the next beat releases the shot.
		var remaining := 1.0 - beat_clock.phase()
		canvas.glow(center, Color(1.0, 0.45, 0.3, 0.55 * (1.0 - remaining) + 0.15), draw_size * 0.8)
		canvas.draw_arc(center, draw_size * (0.22 + remaining * 0.45), 0.0, TAU, 28, Color(1.0, 0.55, 0.35, 0.3 + (1.0 - remaining) * 0.5), 2.0, true)
	var hit_flash := float(enemy.get("flash", 0.0))
	if hit_flash > 0.0 and enemy_fleet_texture:
		canvas.draw_set_transform_matrix(Transform2D(rotation, center))
		canvas.draw_texture_rect_region(enemy_fleet_texture, Rect2(-Vector2.ONE * draw_size * 0.5, Vector2.ONE * draw_size), _enemy_region(enemy), Color(1, 1, 1, hit_flash * 0.9))
		canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
		canvas.glow(center, Color(1.0, 0.9, 0.75, hit_flash * 0.45), draw_size * 1.1)


func _draw_player_lights(canvas: Node2D) -> void:
	var center := Vector2(player.x, player.y)
	var thrust := clampf(0.6 - player_velocity.y / 360.0 * 0.5, 0.25, 1.2)
	var bank := clampf(player_velocity.x / 430.0, -1.0, 1.0)
	for side in [-1.0, 1.0]:
		var nozzle := center + Vector2(side * 11.0 * (1.0 - absf(bank) * 0.12), 38.0)
		var flicker: float = 0.85 + fx.rng.randf() * 0.3
		var length: float = 44.0 * thrust * flicker
		canvas.glow_stretched(nozzle + Vector2(0, length * 0.42), Color(0.35, 0.8, 1.0, 1.0), Vector2(20.0, length * 1.2))
		canvas.glow(nozzle + Vector2(0, 4), Color(0.85, 0.97, 1.0, 0.9), 24.0)
	canvas.glow(center, Color(0.3, 0.75, 1.0, 0.12), 150.0)
	if player.is_overdrive_active():
		var radius: float = 114.0 + player.overdrive_duration_bonus * 8.0
		var pulse := 0.5 + sin(stage_timer * 10.0) * 0.5
		canvas.draw_arc(center, radius, 0.0, TAU, 64, Color(0.5, 0.95, 1.0, 0.18 + pulse * 0.12), 2.0, true)
		canvas.draw_arc(center, radius - 6.0, stage_timer * 2.0, stage_timer * 2.0 + PI * 0.6, 24, Color(1.0, 0.95, 0.6, 0.35), 3.0, true)
		canvas.draw_arc(center, radius - 6.0, stage_timer * 2.0 + PI, stage_timer * 2.0 + PI * 1.6, 24, Color(1.0, 0.95, 0.6, 0.35), 3.0, true)
		canvas.glow(center, Color(0.4, 0.9, 1.0, 0.16 + pulse * 0.06), radius * 2.1)


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
	_c.draw_rect(rect, lane_color)
	_c.draw_rect(Rect2(rect.position.x + rect.size.x * 0.38, rect.position.y, rect.size.x * 0.24, rect.size.y), core_color)
	_c.draw_line(rect.position, rect.position + Vector2(0.0, rect.size.y), Color(1.0, 0.32, 0.18, 0.54), 2.0)
	_c.draw_line(rect.position + Vector2(rect.size.x, 0.0), rect.position + rect.size, Color(1.0, 0.32, 0.18, 0.54), 2.0)


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
	_c.draw_polyline(PackedVector2Array([start, mid, end]), warning, 14.0, true)
	_c.draw_polyline(PackedVector2Array([start, mid, end]), edge, 2.0, true)
	for i in range(3):
		var ratio := 0.22 + float(i) * 0.2
		var center := start.lerp(end, ratio)
		var size := 9.0 + pulse * 2.0
		var points := PackedVector2Array([
			center + Vector2(-size, -size * 0.7),
			center + Vector2(size, -size * 0.7),
			center + Vector2(0.0, size),
		])
		_c.draw_colored_polygon(points, Color(1.0, 0.86, 0.24, 0.28 + pulse * 0.16))


func _enemy_dive_preview_end_x(enemy: Dictionary) -> float:
	var freq := 8.0 if str(enemy.get("kind", "")) == "zig" else 4.0
	var sway := sin(float(enemy.get("t", 0.0)) * freq) * 42.0
	return clampf(float(enemy.get("x", Config.W * 0.5)) + sway, 36.0, Config.W - 36.0)


func _draw_boss() -> void:
	var tint := Color(1, 0.86, 0.86, 1) if boss_controller.boss.phase >= 2 else Color.WHITE
	if final_boss_texture:
		# Generated reactor centers align with the existing (-96,18), (96,18), (0,104) hit zones.
		_c.draw_texture_rect(final_boss_texture, Rect2(boss_controller.boss.x - 190.0, boss_controller.boss.y - 157.0, 380.0, 396.0), false, tint)
	if boss_controller.boss.has("parts"):
		for part in boss_controller.boss.parts:
			var part_pos: Vector2 = Vector2(boss_controller.boss.x, boss_controller.boss.y) + part.offset
			_draw_boss_weakpoint(part, part_pos)


func _draw_boss_weakpoint(part: Dictionary, part_pos: Vector2) -> void:
	var pulse := 0.5 + sin(stage_timer * 8.0 + part_pos.x * 0.03) * 0.5
	var part_color: Color = Config.UI_RED if part.alive else Color(0.2, 0.26, 0.34, 0.62)
	var radius := 27.0 if part.id == "core" else 22.0
	if boss_weakpoint_texture:
		var cell := float(boss_weakpoint_texture.get_width()) / 2.0
		var region := Rect2(0.0 if part.alive else cell, cell, cell, cell)
		var size := 102.0 if part.id == "core" else 90.0
		_c.draw_texture_rect_region(boss_weakpoint_texture, Rect2(part_pos - Vector2.ONE * size * 0.5, Vector2.ONE * size), region, Color.WHITE if part.alive else Color(0.6, 0.6, 0.6, 1))
	_c.draw_circle(part_pos, radius + 6.0, Color(part_color, 0.08 + pulse * 0.05))
	_c.draw_arc(part_pos, radius, 0.0, TAU, 32, Color(part_color, 0.72), 3.0)
	_c.draw_arc(part_pos, radius + 7.0, -PI * 0.35, PI * 0.7, 18, Color(Config.UI_AMBER, 0.38 if part.alive else 0.1), 2.0)
	if part.alive:
		_c.draw_circle(part_pos, 7.0 + pulse * 2.0, Color(0.82, 0.98, 1.0, 0.9))


func _draw_stage_hazard(hazard: Dictionary) -> void:
	if hazard.kind == "rock":
		var center := Vector2(hazard.x, hazard.y)
		var radius: float = hazard.r
		if rock_obstacle_texture:
			var size := radius * 2.65
			var pulse := 0.94 + sin(stage_timer * 1.1 + float(hazard.seed)) * 0.035
			_c.draw_texture_rect(rock_obstacle_texture, Rect2(center.x - size * 0.5, center.y - size * 0.5, size, size), false, Color(1.0, 1.0, 1.0, pulse))
			return
		var points := PackedVector2Array()
		var seed_value: int = int(hazard.get("seed", 0))
		for i in range(11):
			var angle := -PI * 0.5 + float(i) / 11.0 * TAU
			var chip := 0.78 + float((seed_value + i * 19) % 9) * 0.035
			points.append(center + Vector2(cos(angle), sin(angle)) * radius * chip)
		_c.draw_colored_polygon(points, Color("#493f54"))
		_c.draw_polyline(points, Color("#d7b56f"), 3.0, true)
		var inner := PackedVector2Array()
		for i in range(points.size()):
			inner.append(center.lerp(points[i], 0.52))
		_c.draw_colored_polygon(inner, Color(0.78, 0.66, 0.45, 0.32))
		var crack_a := center + Vector2(-radius * 0.36, -radius * 0.18)
		var crack_b := center + Vector2(radius * 0.18, radius * 0.08)
		var crack_c := center + Vector2(radius * 0.42, -radius * 0.2)
		_c.draw_polyline(PackedVector2Array([crack_a, crack_b, crack_c]), Color(1.0, 0.88, 0.55, 0.58), 2.0)
	elif str(hazard.kind).begins_with("plasma"):
		var x: float = hazard.x
		_c.draw_rect(Rect2(x - 10.0, Config.HUD, 20.0, Config.PLAY_H), Color(0.52, 0.9, 1.0, 0.1))
		_c.draw_line(Vector2(x, Config.HUD), Vector2(x, Config.H), Color("#72eaff"), 3.0)


func _draw_score_crystal(crystal: Dictionary) -> void:
	var center := Vector2(crystal.x, crystal.y)
	var pulse := 0.5 + sin(crystal.t * 14.0) * 0.5
	_c.draw_circle(center, 15.0 + pulse * 4.0, Color(0.35, 0.9, 1.0, 0.15))
	if score_crystal_texture:
		var cell := float(score_crystal_texture.get_width()) / 2.0
		var region := Rect2(cell, 0, cell, cell)
		var size := 24.0 + pulse * 3.0
		_c.draw_texture_rect_region(score_crystal_texture, Rect2(center.x - size * 0.5, center.y - size * 0.5, size, size), region, Color.WHITE)
	else:
		var points := PackedVector2Array([
			center + Vector2(0.0, -10.0),
			center + Vector2(7.0, 0.0),
			center + Vector2(0.0, 10.0),
			center + Vector2(-7.0, 0.0),
		])
		_c.draw_colored_polygon(points, Color("#a9f7ff"))


func _draw_bullet(bullet: Dictionary) -> void:
	if projectile_texture:
		var visual := str(bullet.get("sprite", "enemy" if bullet.enemy else "player"))
		if visual == "beam" and beam_enemy_texture:
			_c.draw_texture_rect(beam_enemy_texture, Rect2(bullet.x - 15.0, bullet.y - 48.0, 30.0, 96.0), false)
			return
		var region := _projectile_region(visual)
		var width := 10.0
		var height := 40.0
		if visual == "overdrive":
			width = 18.0
			height = 50.0
		elif visual == "boss":
			width = maxf(20.0, float(bullet.r) * 2.0 + 6.0)
			height = 38.0
		elif visual == "beam":
			width = 58.0
			height = 118.0
		elif visual == "enemy":
			width = maxf(16.0, float(bullet.r) * 2.0 + 6.0)
			height = 26.0
		var tint := Color.WHITE
		_c.draw_texture_rect_region(projectile_texture, Rect2(bullet.x - width * 0.5, bullet.y - height * 0.5, width, height), region, tint)
		return
	var rx: float = bullet.r
	var ry: float = bullet.r * (1.6 if bullet.enemy else 2.4)
	_c.draw_circle(Vector2(bullet.x, bullet.y), maxf(rx, ry), Color(bullet.color, 0.16))
	_c.draw_ellipse(Vector2(bullet.x, bullet.y), rx, ry, bullet.color)


func _projectile_region(visual: String) -> Rect2:
	var index := 0
	if visual == "overdrive":
		index = 1
	elif visual == "enemy":
		index = 2
	elif visual == "boss" or visual == "beam":
		index = 3
	# Trim transparent padding and isolated glow specks; keep the luminous body readable.
	var regions := [Rect2(50, 5, 28, 109), Rect2(174, 10, 37, 107), Rect2(39, 157, 44, 67), Rect2(173, 136, 40, 99)]
	return regions[index]


func _draw_explosion(explosion: Dictionary) -> void:
	if explosion.t < 0.0:
		return
	var size := 104.0 if explosion.big else 68.0
	if explosion_texture:
		var cell := float(explosion_texture.get_width()) / 2.0
		var frame := mini(3, int(explosion.t / 0.13))
		var region := Rect2(float(frame % 2) * cell, float(frame / 2) * cell, cell, cell)
		_c.draw_texture_rect_region(explosion_texture, Rect2(explosion.x - size * 0.5, explosion.y - size * 0.5, size, size), region, Color(1, 1, 1, 1.0 - explosion.t * 1.2))


func _draw_bomb_wave(wave: Dictionary) -> void:
	var progress := clampf(wave.t / 0.62, 0.0, 1.0)
	var top: float = Config.HUD + 8.0
	var height: float = player.y - top
	var beam_width: float = wave.width * (1.0 - progress * 0.38)
	var alpha := 1.0 - progress
	if beam_player_texture:
		_c.draw_texture_rect(beam_player_texture, Rect2(wave.x - beam_width * 0.5, top, beam_width, height), false, Color(1, 1, 1, 0.72 * alpha))


func _draw_item(item: Dictionary) -> void:
	var bob := sin(item.t * 8.0) * 3.0
	var center := Vector2(item.x, item.y + bob)
	var icon_index := 3
	var color := Config.UI_GREEN
	if Config.CHIP_TRACKS.has(item.kind):
		var track: Dictionary = Config.CHIP_TRACKS[item.kind]
		color = track.color
		icon_index = ["power", "spread", "resonance"].find(str(item.kind))
	elif item.kind == "bomb":
		color = Config.UI_AMBER
		icon_index = 5
	elif item.kind == "shield":
		color = Color("#72eaff")
		icon_index = 4
	var pulse := 1.0 + sin(item.t * 7.0) * 0.08
	_c.draw_circle(center, 30.0 * pulse, Color(color, 0.11))
	_draw_status_icon(icon_index, Rect2(center.x - 27.0 * pulse, center.y - 27.0 * pulse, 54.0 * pulse, 54.0 * pulse), Color.WHITE)


func _draw_status_icon(index: int, rect: Rect2, tint := Color.WHITE) -> void:
	if not status_icons_texture:
		return
	var cell := float(status_icons_texture.get_width()) / 3.0
	var region := Rect2(float(index % 3) * cell, float(index / 3) * cell, cell, cell)
	_c.draw_texture_rect_region(status_icons_texture, rect, region, tint)


func _draw_infection_overlay() -> void:
	_c.draw_rect(Rect2(0, 0, Config.W, Config.H), Color(0.0, 0.025, 0.07, 0.78))
	_c.draw_rect(Rect2(0, 0, Config.W, Config.H), Color(Config.UI_CYAN, 0.035))
	for i in range(12):
		var y := 18.0 + float(i) * 58.0
		var alpha := 0.08 + float(i % 3) * 0.025
		_c.draw_line(Vector2(0, y), Vector2(Config.W, y), Color(Config.UI_CYAN, alpha), 1.0)
	for i in range(8):
		var x := fmod(stage_timer * 18.0 + float(i) * 137.0, Config.W)
		_c.draw_line(Vector2(x, Config.HUD), Vector2(x - 180.0, Config.H), Color(Config.UI_AMBER, 0.045), 1.0)


func _draw_terminal_panel(rect: Rect2, accent: Color, fill_alpha := Config.UI_PANEL_ALPHA, selected := false) -> void:
	if title_controls_texture:
		_c.draw_texture_rect(title_controls_texture, rect, false, Color(1, 1, 1, fill_alpha))
	if selected:
		_c.draw_line(rect.position + Vector2(16, rect.size.y - 7), rect.end - Vector2(16, 7), accent, 3.0)


func _draw_chrome_icon(key: String, rect: Rect2, tint := Color.WHITE) -> void:
	var icons := {"shot": 0, "bomb": 5, "overdrive": 6, "core": 8, "warning": 8}
	if icons.has(key):
		_draw_status_icon(int(icons[key]), rect, tint)
	elif key == "pause":
		for offset in [0.28, 0.6]:
			_c.draw_rect(Rect2(rect.position + Vector2(rect.size.x * offset, rect.size.y * 0.15), rect.size * Vector2(0.13, 0.7)), tint)


func _draw_core_glyph(center: Vector2, radius: float, accent: Color, active := false) -> void:
	var pulse := 0.5 + sin(Time.get_ticks_msec() * 0.009) * 0.5
	var size := radius * 1.7
	var rect := Rect2(center.x - size * 0.5, center.y - size * 0.5, size, size)
	if active:
		_draw_status_icon(3, rect, Color(1, 1, 1, 0.46 + pulse * 0.14))
	else:
		_draw_chrome_icon("pause", rect, Color(Config.UI_CYAN, 0.78))


func _draw_overlay() -> void:
	if state == GameState.TITLE and title_background_texture:
		_c.draw_texture_rect(title_background_texture, Rect2(0, 0, Config.W, Config.H), false, Color.WHITE)
		_draw_title_wordmark()
		_c.draw_rect(Rect2(0, Config.H - 118.0, Config.W, 118.0), Color(0.01, 0.035, 0.075, 0.58))
		_draw_title_mode_select(0.0)
		_draw_title_start_button()
		return
	_draw_infection_overlay()
	var title := "NOVA SWARM"
	if state == GameState.PAUSED:
		title = "PAUSED"
	elif state == GameState.VICTORY:
		title = "MISSION CLEAR"
	elif state == GameState.GAME_OVER:
		title = "GAME OVER"
	var sub := "P TO RESUME" if state == GameState.PAUSED else "ENTER TO DEPLOY"
	if state == GameState.VICTORY and ending_texture:
		_draw_terminal_panel(Rect2(118, Config.HUD + 48, 724, 214), Config.UI_CYAN, 0.58)
		_c.draw_texture_rect(ending_texture, Rect2(146, Config.HUD + 56, 668, 198), false)
		_draw_arcade_title(title, Config.HUD + 300.0, 44, Config.UI_TEXT)
		hud.draw_centered(_c, font, "FINAL SCORE " + str(score).pad_zeros(7), Config.HUD + 326, 22, Config.UI_AMBER)
		_draw_results_table(Config.HUD + 372.0)
		hud.draw_centered(_c, font, _control_mode_label(control_mode) + " / ENTER TO REDEPLOY", Config.HUD + 620, 18, Config.UI_CYAN)
	else:
		_draw_core_glyph(Vector2(Config.W * 0.5, Config.HUD + 116.0), 38.0, Config.UI_CYAN, state == GameState.GAME_OVER)
		_draw_arcade_title(title, Config.HUD + 216.0, 58, Config.UI_TEXT)
		hud.draw_centered(_c, font, sub, Config.HUD + 292, 22, Config.UI_CYAN)
		if state == GameState.PAUSED:
			_draw_controls_panel(Config.HUD + 332.0)
		elif state == GameState.GAME_OVER and not stage_results.is_empty():
			_draw_results_table(Config.HUD + 334.0)
		else:
			hud.draw_centered(_c, font, "CORE SIGNAL LOST / REBUILD AND REDEPLOY", Config.HUD + 340, 17, Color(Config.UI_TEXT, 0.82))


func _draw_controls_panel(y: float) -> void:
	var rect := Rect2(260.0, y, 440.0, 202.0)
	_draw_terminal_panel(rect, Config.UI_CYAN, 0.78)
	_c.draw_string(font, rect.position + Vector2(34.0, 36.0), "CONTROL CHANNELS", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Config.UI_CYAN)
	var rows := [
		["MOVE", "WASD / ARROWS"],
		["SHOT", "SPACE"],
		["BOMB", "B / SHIFT"],
		["OVERDRIVE", "E"],
		["PAUSE", "P"],
		["MUTE", "M"],
	]
	for i in range(rows.size()):
		var row_y := y + 66.0 + float(i) * 22.0
		_c.draw_string(font, Vector2(rect.position.x + 34.0, row_y), rows[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Config.UI_AMBER if i == 3 else Config.UI_CYAN)
		_c.draw_string(font, Vector2(rect.position.x + 184.0, row_y), rows[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(Config.UI_TEXT, 0.82))


func _draw_title_wordmark() -> void:
	_draw_title_line("NOVA", Rect2(190.0, 48.0, 580.0, 82.0), 78, 56, Color("#baf7ff"))
	_draw_title_line("SWARM", Rect2(120.0, 126.0, 720.0, 104.0), 96, 68, Color("#f7fbff"))


func _draw_title_line(text: String, rect: Rect2, preferred_size: int, minimum_size: int, color: Color) -> void:
	var title_font := display_font if display_font else font
	var size := preferred_size
	while size > minimum_size and title_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > rect.size.x:
		size -= 1
	var text_size := title_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var position := Vector2(rect.position.x + (rect.size.x - text_size.x) * 0.5, rect.position.y + size)
	_c.draw_string(title_font, position + Vector2(5.0, 6.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.0, 0.03, 0.1, 0.92))
	_c.draw_string(title_font, position + Vector2(2.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(Config.UI_CYAN, 0.72))
	_c.draw_string(title_font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _draw_centered_in_width(text: String, x: float, width: float, y: float, size: int, color: Color) -> void:
	var label_font := display_font if display_font else font
	var fitted_size := size
	while fitted_size > 8 and label_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted_size).x > width - 10.0:
		fitted_size -= 1
	var text_size := label_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted_size)
	_c.draw_string(label_font, Vector2(x + (width - text_size.x) / 2.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted_size, color)


func _draw_results_table(y: float) -> void:
	var x := 128.0
	var row_h := 31.0
	var headers := ["STAGE", "SCORE", "CHAIN", "DMG", "BOMB", "RANK"]
	var cols := [x, x + 230.0, x + 382.0, x + 500.0, x + 590.0, x + 704.0]
	_draw_terminal_panel(Rect2(x - 24.0, y - 28.0, 760.0, row_h * 6.0 + 60.0), Config.UI_RED, 0.74)
	for i in range(headers.size()):
		_c.draw_string(font, Vector2(cols[i], y), headers[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Config.UI_TEXT_DIM)
	for r in range(stage_results.size()):
		var result: Dictionary = stage_results[r]
		var row_y := y + 30.0 + float(r) * row_h
		var rank_color := _rank_color(str(result.rank))
		if r % 2 == 0:
			_c.draw_rect(Rect2(x - 10.0, row_y - 16.0, 720.0, 23.0), Color(Config.UI_RED, 0.07))
		_c.draw_string(font, Vector2(cols[0], row_y), str(result.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Config.UI_TEXT)
		_c.draw_string(font, Vector2(cols[1], row_y), str(result.score).pad_zeros(5), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Config.UI_CYAN)
		_c.draw_string(font, Vector2(cols[2], row_y), str(result.chain), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Config.UI_AMBER)
		_c.draw_string(font, Vector2(cols[3], row_y), str(result.damage), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#ff9aa8"))
		_c.draw_string(font, Vector2(cols[4], row_y), str(result.bombs), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Config.UI_AMBER)
		_c.draw_string(font, Vector2(cols[5], row_y), str(result.rank), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, rank_color)
	if not stage_results.is_empty():
		var last_result: Dictionary = stage_results[stage_results.size() - 1]
		_c.draw_string(font, Vector2(x, y + row_h * 6.0 + 24.0), str(last_result.get("tip", "NEXT: AIM FOR SSS")), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Config.UI_AMBER)


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
	if state != GameState.PLAYING or control_mode != ControlMode.AI:
		return
	var label := _control_mode_label(control_mode)
	var color := Config.UI_AMBER if control_mode == ControlMode.AI else Config.UI_CYAN
	var x := 858.0
	var y := 42.0
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	var rect := Rect2(x - 9.0, y - 15.0, text_size.x + 18.0, 20.0)
	_c.draw_rect(rect, Color(Config.UI_PANEL_DARK, 0.52))
	_c.draw_rect(rect, Color(color, 0.18), false, 1.0)
	_c.draw_string(font, Vector2(x, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)


func _draw_touch_controls() -> void:
	var move_center := _touch_move_center()
	var move_radius := Config.UI_TOUCH_STICK_RADIUS
	var stick_offset := touch_move_vector * 38.0
	var active_color := Config.UI_AMBER if touch_move_index != -1 else Color(Config.UI_TEXT, 0.38)
	_c.draw_circle(move_center, move_radius, Color(Config.UI_PANEL_DARK, 0.34))
	_c.draw_arc(move_center, move_radius, 0.0, TAU, 56, Color(Config.UI_CYAN, 0.36), 3.0)
	_c.draw_arc(move_center, move_radius - 15.0, -PI * 0.15, PI * 1.15, 44, Color(Config.UI_CYAN, 0.24), 2.0)
	_c.draw_line(move_center + Vector2(-move_radius + 16.0, 0), move_center + Vector2(move_radius - 16.0, 0), Color(Config.UI_CYAN, 0.12), 1.0)
	_c.draw_line(move_center + Vector2(0, -move_radius + 16.0), move_center + Vector2(0, move_radius - 16.0), Color(Config.UI_CYAN, 0.12), 1.0)
	_c.draw_circle(move_center + stick_offset, Config.UI_TOUCH_KNOB, Color(active_color, 0.34))
	_c.draw_arc(move_center + stick_offset, Config.UI_TOUCH_KNOB, 0.0, TAU, 32, active_color, 2.0)

	var button_hitboxes := _touch_button_hitboxes()
	_draw_touch_button(Rect2(button_hitboxes.shoot), "SHOT", "shot", Config.UI_CYAN, bool(touch_button_pressed.shoot))
	_draw_touch_button(Rect2(button_hitboxes.bomb), "BOMB", "bomb", Config.UI_AMBER, bool(touch_button_pressed.bomb))
	_draw_touch_button(Rect2(button_hitboxes.overdrive), "OVER", "overdrive", Config.UI_AMBER, touch_overdrive_queued)
	_draw_touch_button(_touch_pause_hitbox(), "PAUSE", "pause", Color(Config.UI_TEXT, 0.78), state == GameState.PAUSED)


func _draw_touch_button(rect: Rect2, label: String, icon_key: String, color: Color, active: bool) -> void:
	var fill_alpha := 0.34 if active else 0.16
	_c.draw_circle(rect.get_center(), rect.size.x * 0.5, Color(Config.UI_PANEL_DARK, 0.36))
	_c.draw_circle(rect.get_center(), rect.size.x * 0.5 - 6.0, Color(color, fill_alpha))
	_c.draw_arc(rect.get_center(), rect.size.x * 0.5 - 4.0, 0.0, TAU, 40, Color(color, 0.78 if active else 0.46), 3.0 if active else 2.0)
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
	var hitboxes := _title_mode_hitboxes(y)
	_draw_title_control(Rect2(hitboxes.manual), selected_control_mode == ControlMode.MANUAL, "MANUAL")
	_draw_title_control(Rect2(hitboxes.ai), selected_control_mode == ControlMode.AI, "AI DEMO")
	var ai_rect := Rect2(hitboxes.ai)
	var personality_color := Config.UI_AMBER if selected_control_mode == ControlMode.AI else Color(Config.UI_TEXT, 0.45)
	_draw_centered_in_width("< " + str(ai_pilot.personality).to_upper() + " >", ai_rect.position.x, ai_rect.size.x, ai_rect.position.y + 54.0, 10, personality_color)


func _draw_title_start_button() -> void:
	var rect := _title_start_hitbox()
	_draw_terminal_panel(rect, Config.UI_CYAN, 1.0, true)
	_draw_centered_in_width("DEPLOY", rect.position.x, rect.size.x, rect.position.y + 51.0, 25, Color.WHITE)


func _title_start_hitbox() -> Rect2:
	return Rect2(500.0, 614.0, 392.0, 80.0)


func _draw_title_control(rect: Rect2, selected: bool, label: String) -> void:
	_draw_terminal_panel(rect, Config.UI_CYAN, 1.0 if selected else 0.62, selected)
	_draw_centered_in_width(label, rect.position.x, rect.size.x, rect.position.y + 39.0, 16, Color.WHITE if selected else Color(Config.UI_TEXT, 0.62))


func _title_mode_hitboxes(y: float) -> Dictionary:
	return {
		"manual": Rect2(70.0, 626.0, 196.0, 60.0),
		"ai": Rect2(264.0, 626.0, 196.0, 60.0),
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


func _draw_highlight_frame() -> void:
	if highlight_strength <= 0.01:
		return
	var bar := 28.0 * highlight_strength
	_c.draw_rect(Rect2(0, Config.HUD, Config.W, bar), Color(0, 0, 0, 0.85))
	_c.draw_rect(Rect2(0, Config.H - bar, Config.W, bar), Color(0, 0, 0, 0.85))
	if highlight_label != "" and highlight_strength > 0.5:
		var alpha := (highlight_strength - 0.5) * 2.0
		_c.draw_string(font, Vector2(18, Config.H - 9.0), "AI HIGHLIGHT  /  " + highlight_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(Config.UI_AMBER, alpha))


func _draw_ai_readout() -> void:
	var debug: Dictionary = ai_pilot.debug
	var rect := Rect2(12.0, Config.HUD + (40.0 if boss_controller.is_alive() else 10.0), 176.0, 44.0)
	_c.draw_rect(rect, Color(Config.UI_PANEL_DARK, 0.62))
	_c.draw_rect(rect, Color(Config.UI_CYAN, 0.28), false, 1.0)
	_c.draw_string(font, rect.position + Vector2(10, 16), "AI PILOT / " + str(ai_pilot.personality).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Config.UI_CYAN)
	var mode := str(debug.get("mode", "STANDBY"))
	var mode_color := Config.UI_RED if mode in ["EVADE", "BOMB"] else Config.UI_AMBER if mode in ["OVERDRIVE", "SYNC WAIT", "CHAIN HUNT"] else Config.UI_TEXT
	_c.draw_string(display_font if display_font else font, rect.position + Vector2(10, 34), mode, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, mode_color)
	var danger := clampf(float(debug.get("danger", 0.0)) / 3.0, 0.0, 1.0)
	var meter := Rect2(rect.position.x + 112.0, rect.position.y + 26.0, 54.0, 5.0)
	_c.draw_rect(meter, Color(1, 1, 1, 0.1))
	_c.draw_rect(Rect2(meter.position, Vector2(meter.size.x * danger, meter.size.y)), Color(0.3, 1.0, 0.65).lerp(Config.UI_RED, danger))
	if not show_ai_overlay:
		_c.draw_string(font, rect.position + Vector2(112, 16), "V: HOLO", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(Config.UI_TEXT, 0.5))


# Manual runs race the best recorded AI Demo run.
func _draw_ai_pace() -> void:
	var pace := _ai_pace_score(run_time)
	if pace < 0:
		return
	var delta := score - pace
	var text := ("+" if delta >= 0 else "") + str(delta)
	var rect := Rect2(Config.W - 172.0, Config.HUD + 10.0, 160.0, 24.0)
	_c.draw_rect(rect, Color(Config.UI_PANEL_DARK, 0.55))
	_c.draw_string(font, rect.position + Vector2(8, 16), "VS AI", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(Config.UI_TEXT, 0.7))
	draw_text_right(text, Rect2(rect.position.x + 50.0, rect.position.y + 3.0, 102.0, 18.0), 14, Config.UI_GREEN if delta >= 0 else Config.UI_RED)


func draw_text_right(text: String, rect: Rect2, size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_c.draw_string(font, Vector2(rect.end.x - width, rect.position.y + float(size)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


# Four pips under the Overdrive gauge show the bar; the lit window marks a sync-bonus timing.
func _draw_beat_pips() -> void:
	var bar_index: int = beat_clock.bar_position()
	var on_beat: bool = beat_clock.is_on_beat()
	var pulse: float = beat_clock.pulse()
	for i in range(4):
		var rect := Rect2(84.0 + float(i) * 24.0, 65.0, 20.0, 3.0)
		var active := i == bar_index
		var color := Color("#ffe27a") if active and on_beat else Config.UI_CYAN
		_c.draw_rect(rect, Color(color, 0.85 * pulse + 0.15 if active else 0.18))


func _draw_stage_banner(text: String, y: float, alpha: float) -> void:
	var size := 30
	var banner_font := display_font if display_font else font
	var text_size := banner_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var x := (Config.W - text_size.x) / 2.0
	var panel := Rect2((Config.W - 520.0) * 0.5, y - 48.0, 520.0, 72.0)
	if title_controls_texture:
		_c.draw_texture_rect(title_controls_texture, panel, false, Color(1, 1, 1, alpha * 0.84))
	_c.draw_string(banner_font, Vector2(x + 2.0, y + 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.62 * alpha))
	_c.draw_string(banner_font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(Config.UI_TEXT, alpha))


func _draw_arcade_title(text: String, y: float, size: int, color: Color) -> void:
	var title_font := display_font if display_font else font
	var text_size := title_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var x := (Config.W - text_size.x) / 2.0
	_c.draw_string(title_font, Vector2(x + 3.0, y + 3.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.0, 0.0, 0.0, 0.72))
	_c.draw_string(title_font, Vector2(x + 1.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(Config.UI_CYAN, 0.42))
	_c.draw_string(title_font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
	_c.draw_line(Vector2(x - 42.0, y + 10.0), Vector2(x - 10.0, y + 10.0), Config.UI_AMBER, 3.0)
	_c.draw_line(Vector2(x + text_size.x + 10.0, y + 10.0), Vector2(x + text_size.x + 42.0, y + 10.0), Config.UI_AMBER, 3.0)
	_c.draw_line(Vector2(x - 24.0, y + 17.0), Vector2(x + text_size.x + 24.0, y + 17.0), Color(Config.UI_CYAN, 0.16), 1.0)


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
			if part.id != "core":
				_overload_boss_core(part_pos)
			if fx:
				fx.shatter(part_pos, 18, 320.0, 1.8)
				fx.ring(part_pos, Color(1.0, 0.7, 0.4, 0.9), 200.0, 0.5, 5.0)
				fx.flash_glow(part_pos, Color(1.0, 0.85, 0.6, 1.0), 260.0, 0.3)
				fx.popup(part_pos, "CORE BREAK", Config.UI_AMBER, 22, 1.0)
			_trigger_highlight(part_pos, "CORE BREAK", 0.9)
			return 8
		return 2
	return 0


# A broken side reactor surges into the central core through the boss's own network.
func _overload_boss_core(from: Vector2) -> void:
	var b: Dictionary = boss_controller.boss
	for part in b.parts:
		if part.id != "core" or not part.alive:
			continue
		var core_pos: Vector2 = Vector2(b.x, b.y) + part.offset
		part.hp = maxi(1, int(part.hp) - 60)
		b.hp = maxi(1, int(b.hp) - 150)
		if fx:
			fx.bolt(from, core_pos, Color(1.0, 0.6, 0.3), 0.5, 5.0)
			fx.bolt(from, core_pos, Color(1.0, 0.85, 0.5), 0.35, 3.0)
			fx.popup(core_pos + Vector2(0, 40), "OVERLOAD", Color("#ffe27a"), 22, 1.0)


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
