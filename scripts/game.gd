extends Node2D
class_name GameController

const AudioManagerScript := preload("res://scripts/audio_manager.gd")
const Config := preload("res://scripts/game_config.gd")
const PlayerScript := preload("res://scripts/player.gd")
const ProjectileManagerScript := preload("res://scripts/projectile_manager.gd")
const EnemySwarmScript := preload("res://scripts/enemy_swarm.gd")
const BossControllerScript := preload("res://scripts/boss_controller.gd")
const HudScript := preload("res://scripts/hud.gd")

enum GameState { TITLE, PLAYING, PAUSED, GAME_OVER, VICTORY }

var state := GameState.TITLE
var stage := 0
var score := 0
var stage_timer := 0.0
var difficulty := 1.0
var screen_shake := 0.0
var flash := 0.0
var hitstop := 0.0
var stage_banner := 0.0

var player = PlayerScript.new()
var projectiles = ProjectileManagerScript.new()
var swarm = EnemySwarmScript.new()
var boss_controller = BossControllerScript.new()
var hud = HudScript.new()
var audio_manager

var explosions: Array[Dictionary] = []
var bomb_waves: Array[Dictionary] = []
var items: Array[Dictionary] = []
var sprite_texture: Texture2D
var background_texture: Texture2D
var ui_texture: Texture2D
var font: Font
var sprites: Dictionary = Config.sprites()
var ui_regions := {
	"logo": Rect2(105, 44, 1045, 320),
	"life": Rect2(165, 391, 248, 248),
	"bomb": Rect2(504, 391, 248, 248),
	"shield": Rect2(844, 391, 248, 248),
	"banner": Rect2(109, 685, 1038, 148),
	"ending": Rect2(97, 849, 1060, 334),
}


func _ready() -> void:
	randomize()
	_setup_native_window()
	_setup_runtime_models()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	font = ThemeDB.fallback_font
	sprite_texture = _load_sprite_texture()
	background_texture = load("res://public/assets/backgrounds.png")
	ui_texture = _load_png_texture("res://public/assets/ui_atlas.png")
	audio_manager = AudioManagerScript.new()
	add_child(audio_manager)
	_parse_web_query()
	queue_redraw()


func _exit_tree() -> void:
	if audio_manager and audio_manager.has_method("shutdown"):
		audio_manager.shutdown()


func _setup_runtime_models() -> void:
	player.setup(Config.W / 2.0, Config.PLAYER_Y, 42.0, Config.W - 42.0)
	projectiles.setup(Config.W, Config.H, Config.HUD)
	swarm.setup(Config.W, Config.HUD)
	boss_controller.setup(Config.W, Config.HUD)


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
	if event.is_action_pressed("ui_accept") and state in [GameState.TITLE, GameState.GAME_OVER, GameState.VICTORY]:
		reset()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause_game") and state == GameState.PLAYING:
		state = GameState.PAUSED
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause_game") and state == GameState.PAUSED:
		state = GameState.PLAYING
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("mute_audio"):
		audio_manager.toggle_mute()
		get_viewport().set_input_as_handled()


func reset() -> void:
	stage = 0
	score = 0
	difficulty = 1.0
	player.reset_run(Config.W / 2.0)
	state = GameState.PLAYING
	load_stage(0)
	audio_manager.play_sfx("clear")


func load_stage(index: int) -> void:
	stage = index
	stage_timer = 0.0
	stage_banner = 1.65
	projectiles.clear()
	explosions.clear()
	bomb_waves.clear()
	items.clear()
	swarm.clear()
	boss_controller.clear()
	player.start_stage(Config.W / 2.0)
	_recalculate_difficulty()
	flash = maxf(flash, 0.18)

	var st: Dictionary = Config.STAGES[index]
	if st.boss:
		boss_controller.spawn()
		audio_manager.play_sfx("boss")
		return

	swarm.load_stage(st, Config.ENEMY_STATS, difficulty)


func _recalculate_difficulty() -> void:
	var score_pressure := minf(0.18, float(score) / 90000.0)
	var survival_pressure := 0.06 if player.no_miss_stage else 0.0
	difficulty = 1.0 + float(stage) * 0.08 + score_pressure + survival_pressure


func _update_game(dt: float) -> void:
	stage_timer += dt
	player.update(dt, _read_move_axis())

	if Input.is_action_pressed("shoot") and player.can_shoot():
		_fire_player()
	if Input.is_action_pressed("bomb") and player.can_bomb():
		_use_bomb()

	var st: Dictionary = Config.STAGES[stage]
	swarm.update(dt, st, stage, stage_timer, difficulty, player.x, projectiles, Config.ENEMY_STATS)
	if boss_controller.update(dt, projectiles):
		audio_manager.play_sfx("boss")
	projectiles.update(dt)
	_update_explosions(dt)
	_update_items(dt)
	_check_collisions()
	_check_stage_end()


func _read_move_axis() -> float:
	return Input.get_axis("move_left", "move_right")


func _fire_player() -> void:
	player.mark_shot()
	projectiles.fire_player(player.x, player.y)
	audio_manager.play_sfx("shot")


func _use_bomb() -> void:
	player.consume_bomb()
	audio_manager.play_sfx("bomb")
	_add_shake(3.0)
	_add_flash(0.42, 0.18)
	hitstop = 0.025
	var blast := {"x": player.x, "y": player.y - 54.0, "t": 0.0, "width": 172.0}
	bomb_waves.append(blast)

	var kept_bullets: Array[Dictionary] = []
	for bullet in projectiles.bullets:
		if not bullet.enemy or absf(bullet.x - blast.x) > blast.width * 0.62:
			kept_bullets.append(bullet)
	projectiles.bullets = kept_bullets

	for enemy in swarm.enemies:
		if absf(enemy.x - blast.x) < blast.width * 0.54 and enemy.y < player.y - 22.0:
			enemy.hp = 0
			explosions.append({"x": enemy.x, "y": enemy.y, "t": 0.0, "big": enemy.kind in ["armor", "saucer"]})
			score += int(enemy.score * 0.6)
			_maybe_drop_item(enemy, true)
	swarm.remove_dead()

	if boss_controller.is_alive() and absf(boss_controller.boss.x - blast.x) < 205.0:
		boss_controller.boss.hp = max(0, boss_controller.boss.hp - 42)
		for i in range(5):
			explosions.append({"x": blast.x - 58.0 + i * 29.0, "y": boss_controller.boss.y - 80.0 + i * 28.0, "t": 0.0, "big": true})

	for i in range(7):
		explosions.append({"x": blast.x + sin(i * 2.2) * 42.0, "y": player.y - 110.0 - i * 74.0, "t": -i * 0.035, "big": i % 2 == 0})


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


func _maybe_drop_item(enemy: Dictionary, from_bomb: bool) -> void:
	var base_chance := 0.08
	if enemy.kind in ["armor", "saucer"]:
		base_chance += 0.06
	if player.lives <= 1:
		base_chance += 0.07
	if from_bomb:
		base_chance *= 0.55
	if randf() > base_chance:
		return
	var roll := randf()
	var item_kind := "bomb"
	if player.lives <= 2 and roll < 0.42:
		item_kind = "life"
	elif roll < 0.72:
		item_kind = "shield"
	items.append({"kind": item_kind, "x": enemy.x, "y": enemy.y, "vy": 88.0, "t": 0.0})


func _check_collisions() -> void:
	for bullet in projectiles.bullets:
		if bullet.enemy:
			continue
		for enemy in swarm.enemies:
			if _distance(bullet, enemy) < enemy.size * 0.62 + bullet.r:
				bullet.y = -999.0
				enemy.hp -= bullet.power
				if enemy.hp <= 0:
					var multiplier: float = player.register_kill()
					score += int(enemy.score * multiplier)
					explosions.append({"x": enemy.x, "y": enemy.y, "t": 0.0, "big": enemy.kind in ["armor", "saucer"]})
					_maybe_drop_item(enemy, false)
					audio_manager.play_sfx("boom")
				else:
					audio_manager.play_sfx("hit")

		if boss_controller.is_alive() and _boss_hit_test(Vector2(bullet.x, bullet.y), bullet.r):
			bullet.y = -999.0
			boss_controller.boss.hp -= bullet.power
			score += 8 + min(player.combo, 20)
			explosions.append({"x": bullet.x, "y": bullet.y + 20.0, "t": 0.0, "big": false})
			audio_manager.play_sfx("hit")

	swarm.remove_dead()
	projectiles.cull_marked_player_bullets()

	if player.invuln <= 0.0:
		var player_pos := {"x": player.x, "y": player.y}
		var hit_bullet: bool = projectiles.bullets.any(func(bullet: Dictionary) -> bool: return bullet.enemy and _distance(bullet, player_pos) < 27.0 + bullet.r)
		var hit_enemy: bool = swarm.enemies.any(func(enemy: Dictionary) -> bool: return _distance(enemy, player_pos) < enemy.size + 22.0)
		if hit_bullet or hit_enemy:
			_hurt()

	for item in items:
		if Vector2(item.x, item.y).distance_to(Vector2(player.x, player.y)) < 42.0:
			player.apply_item(item.kind)
			item.y = Config.H + 999.0
			score += 150
			flash = maxf(flash, 0.18)
			audio_manager.play_sfx("clear")
	items = items.filter(func(item: Dictionary) -> bool: return item.y < Config.H + 100.0)


func _hurt() -> void:
	var dead: bool = player.hurt()
	projectiles.clear_enemy_bullets()
	explosions.append({"x": player.x, "y": player.y, "t": 0.0, "big": true})
	_add_shake(6.0)
	_add_flash(0.55, 0.05)
	hitstop = 0.055
	audio_manager.play_sfx("hurt")
	if dead:
		state = GameState.GAME_OVER


func _check_stage_end() -> void:
	if not boss_controller.boss.is_empty() and boss_controller.boss.hp <= 0:
		score += 8000 + (2500 if player.no_miss_stage else 0)
		explosions.append({"x": boss_controller.boss.x, "y": boss_controller.boss.y, "t": 0.0, "big": true})
		boss_controller.clear()
		state = GameState.VICTORY
		_add_shake(7.0)
		_add_flash(0.72, 0.04)
		audio_manager.play_sfx("clear")
		return

	if not Config.STAGES[stage].boss and swarm.enemies.is_empty():
		score += 1000 + stage * 500 + (900 if player.no_miss_stage else 0)
		player.bombs = mini(5, player.bombs + 1)
		audio_manager.play_sfx("clear")
		load_stage(stage + 1)


func _add_shake(amount: float) -> void:
	screen_shake = maxf(screen_shake, amount)


func _add_flash(amount: float, hitstop_time: float) -> void:
	flash = maxf(flash, amount)
	hitstop = maxf(hitstop, hitstop_time)


func _draw() -> void:
	var shake := Vector2.ZERO
	if screen_shake > 0.0:
		shake = Vector2(randf_range(-screen_shake, screen_shake), randf_range(-screen_shake, screen_shake)).round()
	draw_set_transform(shake, 0.0, Vector2.ONE)
	draw_rect(Rect2(0, 0, Config.W, Config.H), Color("#04050a"))
	_draw_background()
	hud.draw_hud(self, font, score, stage, player.lives, player.bombs, player.shield, player.combo, boss_controller.boss)
	_draw_playfield()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if flash > 0.0:
		draw_rect(Rect2(0, Config.HUD, Config.W, Config.PLAY_H), Color(1.0, 0.92, 0.72, flash * 0.34))
	if stage_banner > 0.0 and state == GameState.PLAYING:
		var alpha := minf(1.0, stage_banner)
		_draw_stage_banner(Config.STAGES[stage].name, Config.HUD + 118.0, alpha)
	if state != GameState.PLAYING:
		_draw_overlay()


func _draw_background() -> void:
	var st: Dictionary = Config.STAGES[stage]
	var panel: Rect2 = Config.BG_PANELS[st.bg]
	if background_texture:
		draw_texture_rect_region(background_texture, Rect2(0, Config.HUD, Config.W, Config.PLAY_H), panel, Color(st.tint, 0.92))
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
	_draw_player()
	for explosion in explosions:
		_draw_explosion(explosion)


func _draw_player() -> void:
	var tint := Color(1, 1, 1, 0.52) if player.invuln > 0.0 and int(stage_timer * 16.0) % 2 == 0 else Color.WHITE
	_draw_sprite("player", player.x, player.y, 150, 150, tint)
	if player.shield > 0:
		draw_arc(Vector2(player.x, player.y), 55.0, 0.0, TAU, 48, Color(0.52, 0.94, 1.0, 0.56), 3.0)


func _draw_enemy(enemy: Dictionary) -> void:
	var tint := Color.WHITE
	if enemy.max_hp > 1:
		tint = Color(1.0, 0.85 + 0.15 * float(enemy.hp) / float(enemy.max_hp), 0.72 + 0.28 * float(enemy.hp) / float(enemy.max_hp), 1.0)
	_draw_sprite(enemy.kind, enemy.x, enemy.y, enemy.size * 2.35, enemy.size * 2.35, tint)


func _draw_boss() -> void:
	if boss_controller.boss.tell > 0.0:
		draw_line(Vector2(boss_controller.boss.x, boss_controller.boss.y + 140.0), Vector2(player.x, player.y), Color(1, 0.18, 0.12, 0.55), 3.0)
	var tint := Color(1, 0.86, 0.86, 1) if boss_controller.boss.phase >= 2 else Color.WHITE
	_draw_sprite("boss", boss_controller.boss.x, boss_controller.boss.y, 390, 390, tint)


func _draw_bullet(bullet: Dictionary) -> void:
	var rx: float = bullet.r
	var ry: float = bullet.r * (1.6 if bullet.enemy else 2.4)
	draw_circle(Vector2(bullet.x, bullet.y), maxf(rx, ry), Color(bullet.color, 0.16))
	draw_ellipse(Vector2(bullet.x, bullet.y), rx, ry, bullet.color)


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


func _draw_overlay() -> void:
	draw_rect(Rect2(0, Config.HUD, Config.W, Config.PLAY_H), Color(0, 0, 0, 0.66))
	var title := "NOVA SWARM"
	if state == GameState.PAUSED:
		title = "PAUSED"
	elif state == GameState.VICTORY:
		title = "MISSION CLEAR"
	elif state == GameState.GAME_OVER:
		title = "GAME OVER"
	var sub := "PRESS P TO RETURN" if state == GameState.PAUSED else "PRESS ENTER TO START"
	if state == GameState.TITLE and ui_texture:
		draw_texture_rect_region(ui_texture, Rect2(130, Config.HUD + 92, 700, 214), ui_regions.logo)
		hud.draw_centered(self, font, sub, Config.HUD + 330, 22, Color("#ff7af0"))
		hud.draw_centered(self, font, "5 STAGES / CHAIN SCORE / ITEMS / BOSS PHASES", Config.HUD + 378, 17, Color(0.89, 0.98, 1.0, 0.82))
	elif state == GameState.VICTORY and ui_texture:
		draw_texture_rect_region(ui_texture, Rect2(146, Config.HUD + 72, 668, 210), ui_regions.ending)
		_draw_arcade_title(title, Config.HUD + 330.0, 44, Color("#dffcff"))
		hud.draw_centered(self, font, "FINAL SCORE " + str(score).pad_zeros(7), Config.HUD + 382, 22, Color("#ffef8b"))
		hud.draw_centered(self, font, sub, Config.HUD + 430, 20, Color("#ff7af0"))
	else:
		_draw_arcade_title(title, Config.HUD + 214.0, 58, Color("#dffcff"))
		hud.draw_centered(self, font, sub, Config.HUD + 292, 22, Color("#ff7af0"))
		hud.draw_centered(self, font, "5 STAGES / CHAIN SCORE / ITEMS / BOSS PHASES", Config.HUD + 340, 17, Color(0.89, 0.98, 1.0, 0.82))


func _draw_stage_banner(text: String, y: float, alpha: float) -> void:
	var size := 30
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var x := (Config.W - text_size.x) / 2.0
	if ui_texture:
		draw_texture_rect_region(ui_texture, Rect2(250, y - 45.0, 460, 66), ui_regions.banner, Color(1, 1, 1, alpha))
	else:
		var panel := Rect2(x - 34.0, y - 28.0, text_size.x + 68.0, 46.0)
		draw_rect(panel, Color(0.02, 0.06, 0.12, 0.42 * alpha))
		draw_line(panel.position + Vector2(0, 2), panel.position + Vector2(panel.size.x, 2), Color(0.33, 0.91, 1.0, 0.65 * alpha), 2.0)
		draw_line(panel.position + Vector2(0, panel.size.y - 2), panel.position + Vector2(panel.size.x, panel.size.y - 2), Color(1.0, 0.48, 0.94, 0.65 * alpha), 2.0)
	draw_string(font, Vector2(x + 2.0, y + 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.62 * alpha))
	draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.88, 1.0, 1.0, alpha))


func _draw_arcade_title(text: String, y: float, size: int, color: Color) -> void:
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var x := (Config.W - text_size.x) / 2.0
	draw_string(font, Vector2(x + 3.0, y + 3.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.0, 0.0, 0.0, 0.72))
	draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
	draw_line(Vector2(x - 34.0, y + 10.0), Vector2(x - 8.0, y + 10.0), Color("#ff7af0"), 3.0)
	draw_line(Vector2(x + text_size.x + 8.0, y + 10.0), Vector2(x + text_size.x + 34.0, y + 10.0), Color("#ff7af0"), 3.0)


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


func _parse_web_query() -> void:
	if not Engine.has_singleton("JavaScriptBridge"):
		return
	var bridge: Object = Engine.get_singleton("JavaScriptBridge")
	var search: Variant = bridge.eval("window.location.search", true)
	if typeof(search) != TYPE_STRING:
		return
	if search.find("autostart=1") == -1:
		return
	reset()
	var stage_pos: int = search.find("stage=")
	if stage_pos != -1:
		var raw_stage := int(search.substr(stage_pos + 6, 1))
		if raw_stage >= 1 and raw_stage <= Config.STAGES.size():
			load_stage(raw_stage - 1)
