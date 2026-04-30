extends Node2D

const W := 960.0
const H := 720.0
const HUD := 76.0
const PLAY_H := H - HUD
const PLAYER_Y := H - 58.0
const SPRITE_SHEET_SIZE := 1254.0
const SPRITE_GRID := 4.0
const SPRITE_CELL := SPRITE_SHEET_SIZE / SPRITE_GRID
const SPRITE_PAD := 12.0

enum GameState { TITLE, PLAYING, PAUSED, GAME_OVER, VICTORY }

var state := GameState.TITLE
var stage := 0
var score := 0
var lives := 3
var bombs := 3
var player_x := W / 2.0
var invuln := 0.0
var shot_cd := 0.0
var bomb_cd := 0.0
var stage_timer := 0.0
var swarm_dir := 1.0
var next_id := 1
var muted := false
var music_timer := 0.0
var music_step := 0

var enemies: Array[Dictionary] = []
var bullets: Array[Dictionary] = []
var explosions: Array[Dictionary] = []
var bomb_waves: Array[Dictionary] = []
var boss: Dictionary = {}

var sprite_texture: Texture2D
var background_texture: Texture2D
var font: Font
var audio_players: Array[AudioStreamPlayer] = []
var sfx_streams: Dictionary = {}

var sprites := {
	"player": _sprite_cell(0, 0),
	"bug": _sprite_cell(1, 0),
	"diver": _sprite_cell(2, 0),
	"zig": _sprite_cell(3, 0),
	"armor": _sprite_cell(0, 1),
	"saucer": _sprite_cell(1, 1),
	"bomb": _sprite_cell(2, 1),
	"laser": _sprite_cell(3, 1),
	"orb": _sprite_cell(0, 2),
	"boom1": _sprite_cell(1, 2),
	"boom2": _sprite_cell(2, 2),
	"boom3": _sprite_cell(3, 2),
	"boss": _sprite_cell(0, 3),
	"turret": _sprite_cell(1, 3),
	"core": _sprite_cell(2, 3),
	"flame": _sprite_cell(3, 3),
}

var bg_panels := [
	Rect2(14, 12, 599, 431),
	Rect2(642, 12, 599, 431),
	Rect2(14, 462, 599, 403),
	Rect2(642, 462, 599, 403),
	Rect2(14, 881, 1227, 359),
]

var stages := [
	{"name": "STAR DRIFT", "bg": 0, "rows": 3, "cols": 8, "kinds": ["bug", "bug", "diver"], "speed": 24.0, "fire": 0.62, "dive": 0.45, "boss": false},
	{"name": "VENOM NEBULA", "bg": 1, "rows": 4, "cols": 8, "kinds": ["bug", "zig", "diver"], "speed": 32.0, "fire": 0.86, "dive": 0.8, "boss": false},
	{"name": "ROCK BELT", "bg": 2, "rows": 4, "cols": 9, "kinds": ["armor", "bug", "zig"], "speed": 36.0, "fire": 1.05, "dive": 1.0, "boss": false},
	{"name": "PLASMA NEST", "bg": 3, "rows": 5, "cols": 9, "kinds": ["saucer", "zig", "armor", "diver"], "speed": 42.0, "fire": 1.2, "dive": 1.35, "boss": false},
	{"name": "CITADEL CORE", "bg": 4, "rows": 0, "cols": 0, "kinds": [], "speed": 0.0, "fire": 0.0, "dive": 0.0, "boss": true},
]

var enemy_stats := {
	"bug": {"hp": 1, "score": 120, "size": 34.0, "color": Color("#78ff69")},
	"diver": {"hp": 1, "score": 240, "size": 44.0, "color": Color("#b76cff")},
	"zig": {"hp": 1, "score": 180, "size": 36.0, "color": Color("#39eaff")},
	"armor": {"hp": 1, "score": 420, "size": 46.0, "color": Color("#8dff5d")},
	"saucer": {"hp": 1, "score": 360, "size": 44.0, "color": Color("#ff57f0")},
}

var digit_map := {
	"0": ["111", "101", "101", "101", "111"],
	"1": ["010", "110", "010", "010", "111"],
	"2": ["111", "001", "111", "100", "111"],
	"3": ["111", "001", "111", "001", "111"],
	"4": ["101", "101", "111", "001", "001"],
	"5": ["111", "100", "111", "001", "111"],
	"6": ["111", "100", "111", "101", "111"],
	"7": ["111", "001", "010", "010", "010"],
	"8": ["111", "101", "111", "101", "111"],
	"9": ["111", "101", "111", "001", "111"],
	" ": ["000", "000", "000", "000", "000"],
}


func _ready() -> void:
	randomize()
	_setup_native_window()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	font = ThemeDB.fallback_font
	sprite_texture = _load_sprite_texture()
	background_texture = load("res://public/assets/backgrounds.png")
	_setup_audio()
	_parse_web_query()
	queue_redraw()


func _setup_native_window() -> void:
	if OS.get_name() == "Web":
		return
	var window_size := Vector2i(int(W * 2.0), int(H * 2.0))
	DisplayServer.window_set_size(window_size)
	var screen_size := DisplayServer.screen_get_size()
	DisplayServer.window_set_position(Vector2i(
		int((screen_size.x - window_size.x) * 0.5),
		int((screen_size.y - window_size.y) * 0.5)
	))


func _process(delta: float) -> void:
	var dt: float = min(delta, 0.033)
	if state == GameState.PLAYING:
		_update_game(dt)
	_update_music(dt)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER and state in [GameState.TITLE, GameState.GAME_OVER, GameState.VICTORY]:
			reset()
		elif event.keycode == KEY_P and state == GameState.PLAYING:
			state = GameState.PAUSED
		elif event.keycode == KEY_P and state == GameState.PAUSED:
			state = GameState.PLAYING
		elif event.keycode == KEY_M:
			muted = not muted
		get_viewport().set_input_as_handled()


func reset() -> void:
	stage = 0
	score = 0
	lives = 3
	bombs = 3
	player_x = W / 2.0
	state = GameState.PLAYING
	load_stage(0)
	_play_sfx("clear")


func load_stage(index: int) -> void:
	stage = index
	stage_timer = 0.0
	bullets.clear()
	explosions.clear()
	bomb_waves.clear()
	enemies.clear()
	boss.clear()
	player_x = W / 2.0
	invuln = 1.4

	var st: Dictionary = stages[index]
	if st.boss:
		boss = {"x": W / 2.0, "y": HUD + 210.0, "hp": 520, "max_hp": 520, "t": 0.0, "phase": 0, "shoot": 0.5, "beam": 0.0}
		_play_sfx("boss")
		return

	var start_x := 148.0
	var start_y := HUD + 68.0
	var gap_x := 84.0
	var gap_y := 58.0
	for row in range(st.rows):
		for col in range(st.cols):
			var kind: String = st.kinds[(row + col) % st.kinds.size()]
			var stats: Dictionary = enemy_stats[kind]
			var x := start_x + col * gap_x
			var y := start_y + row * gap_y
			enemies.append({
				"id": next_id,
				"kind": kind,
				"x": x,
				"y": y,
				"base_x": x,
				"base_y": y,
				"hp": stats.hp,
				"max_hp": stats.hp,
				"t": randf() * 10.0,
				"dive": 0.0,
				"shoot": 0.8 + randf() * 2.2,
				"score": stats.score,
				"size": stats.size,
			})
			next_id += 1


func _update_game(dt: float) -> void:
	stage_timer += dt
	invuln = max(0.0, invuln - dt)
	shot_cd = max(0.0, shot_cd - dt)
	bomb_cd = max(0.0, bomb_cd - dt)

	var move := 0.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		move += 1.0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		move -= 1.0
	player_x = clampf(player_x + move * 430.0 * dt, 42.0, W - 42.0)

	if Input.is_key_pressed(KEY_SPACE) and shot_cd <= 0.0:
		_fire_player()
	if (Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_B)) and bomb_cd <= 0.0:
		_use_bomb()

	_update_enemies(dt)
	_update_boss(dt)
	_update_bullets(dt)
	_update_explosions(dt)
	_check_collisions()
	_check_stage_end()


func _fire_player() -> void:
	shot_cd = 0.14
	bullets.append({"x": player_x - 12.0, "y": PLAYER_Y - 44.0, "vx": 0.0, "vy": -660.0, "enemy": false, "r": 4.0, "power": 1, "color": Color("#49dfff")})
	bullets.append({"x": player_x + 12.0, "y": PLAYER_Y - 44.0, "vx": 0.0, "vy": -660.0, "enemy": false, "r": 4.0, "power": 1, "color": Color("#49dfff")})
	_play_sfx("shot")


func _use_bomb() -> void:
	if bombs <= 0:
		return
	bomb_cd = 0.85
	bombs -= 1
	_play_sfx("bomb")
	var blast := {"x": player_x, "y": PLAYER_Y - 54.0, "t": 0.0, "width": 172.0}
	bomb_waves.append(blast)

	var kept_bullets: Array[Dictionary] = []
	for bullet in bullets:
		if not bullet.enemy or absf(bullet.x - blast.x) > blast.width * 0.62:
			kept_bullets.append(bullet)
	bullets = kept_bullets

	for enemy in enemies:
		if absf(enemy.x - blast.x) < blast.width * 0.54 and enemy.y < PLAYER_Y - 22.0:
			enemy.hp = 0
			explosions.append({"x": enemy.x, "y": enemy.y, "t": 0.0, "big": enemy.kind in ["armor", "saucer"]})
			score += int(enemy.score * 0.6)
	enemies = enemies.filter(func(enemy: Dictionary) -> bool: return enemy.hp > 0)

	if not boss.is_empty() and absf(boss.x - blast.x) < 205.0:
		boss.hp = max(0, boss.hp - 42)
		for i in range(5):
			explosions.append({"x": blast.x - 58.0 + i * 29.0, "y": boss.y - 80.0 + i * 28.0, "t": 0.0, "big": true})

	for i in range(7):
		explosions.append({"x": blast.x + sin(i * 2.2) * 42.0, "y": PLAYER_Y - 110.0 - i * 74.0, "t": -i * 0.035, "big": i % 2 == 0})


func _update_enemies(dt: float) -> void:
	if enemies.is_empty():
		return
	var st: Dictionary = stages[stage]
	var edge := enemies.any(func(enemy: Dictionary) -> bool: return enemy.x < 54.0 or enemy.x > W - 54.0)
	if edge:
		swarm_dir *= -1.0

	for enemy in enemies:
		enemy.t += dt
		if enemy.dive <= 0.0 and randf() < st.dive * dt * 0.035:
			enemy.dive = 1.0
		if enemy.dive > 0.0:
			enemy.y += (120.0 + stage * 24.0) * dt
			enemy.x += sin(enemy.t * (8.0 if enemy.kind == "zig" else 4.0)) * 160.0 * dt
			if enemy.y > H + 40.0:
				enemy.y = HUD + 50.0
				enemy.x = enemy.base_x
				enemy.dive = 0.0
		else:
			enemy.x += swarm_dir * st.speed * dt
			enemy.y = enemy.base_y + sin(stage_timer * 1.6 + enemy.id) * 9.0

		enemy.shoot -= dt
		if enemy.shoot <= 0.0:
			var chance: float = st.fire * (1.7 if enemy.kind == "saucer" else 1.0)
			enemy.shoot = 1.2 + randf() * 3.4 / maxf(0.55, chance)
			if randf() < 0.2 + stage * 0.035 or enemy.dive > 0.0:
				_fire_enemy(enemy)


func _fire_enemy(enemy: Dictionary) -> void:
	if enemy.kind == "saucer":
		for side in [-1, 1]:
			bullets.append({"x": enemy.x, "y": enemy.y + 22.0, "vx": side * 70.0, "vy": 215.0, "enemy": true, "r": 5.0, "power": 1, "color": Color("#ff63f7")})
		return

	var aim := clampf((player_x - enemy.x) * 0.22, -90.0, 90.0)
	var stats: Dictionary = enemy_stats[enemy.kind]
	bullets.append({"x": enemy.x, "y": enemy.y + 22.0, "vx": aim, "vy": 260.0 if enemy.kind == "armor" else 230.0, "enemy": true, "r": 6.0 if enemy.kind == "armor" else 5.0, "power": 1, "color": stats.color})


func _update_boss(dt: float) -> void:
	if boss.is_empty():
		return
	boss.t += dt
	boss.phase = 2 if boss.hp < boss.max_hp * 0.35 else 1 if boss.hp < boss.max_hp * 0.68 else 0
	boss.x = W / 2.0 + sin(boss.t * (0.7 + boss.phase * 0.22)) * (90.0 + boss.phase * 38.0)
	boss.y = HUD + 205.0 + sin(boss.t * 1.3) * 18.0
	boss.shoot -= dt
	if boss.shoot <= 0.0:
		boss.shoot = [1.15, 0.9, 0.68][boss.phase]
		var spread := 3 if boss.phase == 0 else 4 if boss.phase == 1 else 5
		for i in range(spread):
			var dx := i - (spread - 1.0) / 2.0
			bullets.append({"x": boss.x + dx * 42.0, "y": boss.y + 128.0, "vx": dx * 42.0, "vy": 220.0 + absf(dx) * 16.0, "enemy": true, "r": 6.0, "power": 1, "color": Color("#ff49df") if i % 2 else Color("#ff7a2b")})

	boss.beam -= dt
	if boss.phase >= 1 and boss.beam <= 0.0:
		boss.beam = 3.6 if boss.phase == 1 else 2.7
		bullets.append({"x": boss.x, "y": boss.y + 148.0, "vx": 0.0, "vy": 360.0, "enemy": true, "r": 14.0, "power": 1, "color": Color("#ff3c37")})
		_play_sfx("boss")


func _update_bullets(dt: float) -> void:
	for bullet in bullets:
		bullet.x += bullet.vx * dt
		bullet.y += bullet.vy * dt
	bullets = bullets.filter(func(bullet: Dictionary) -> bool: return bullet.y > HUD - 40.0 and bullet.y < H + 50.0 and bullet.x > -50.0 and bullet.x < W + 50.0)


func _update_explosions(dt: float) -> void:
	for explosion in explosions:
		explosion.t += dt
	explosions = explosions.filter(func(explosion: Dictionary) -> bool: return explosion.t < 0.58)
	for wave in bomb_waves:
		wave.t += dt
	bomb_waves = bomb_waves.filter(func(wave: Dictionary) -> bool: return wave.t < 0.62)


func _check_collisions() -> void:
	for bullet in bullets:
		if bullet.enemy:
			continue
		for enemy in enemies:
			if _distance(bullet, enemy) < enemy.size * 0.62 + bullet.r:
				bullet.y = -999.0
				enemy.hp -= bullet.power
				if enemy.hp <= 0:
					score += enemy.score
					explosions.append({"x": enemy.x, "y": enemy.y, "t": 0.0, "big": enemy.kind in ["armor", "saucer"]})
					_play_sfx("boom")
				else:
					_play_sfx("hit")

		if not boss.is_empty() and bullet.y < boss.y + 185.0 and bullet.y > boss.y - 165.0 and absf(bullet.x - boss.x) < 245.0:
			bullet.y = -999.0
			boss.hp -= bullet.power
			score += 8
			explosions.append({"x": bullet.x, "y": bullet.y + 20.0, "t": 0.0, "big": false})
			_play_sfx("hit")

	enemies = enemies.filter(func(enemy: Dictionary) -> bool: return enemy.hp > 0)
	bullets = bullets.filter(func(bullet: Dictionary) -> bool: return bullet.y > -900.0)

	if invuln <= 0.0:
		var player_pos := {"x": player_x, "y": PLAYER_Y}
		var hit_bullet := bullets.any(func(bullet: Dictionary) -> bool: return bullet.enemy and _distance(bullet, player_pos) < 27.0 + bullet.r)
		var hit_enemy := enemies.any(func(enemy: Dictionary) -> bool: return _distance(enemy, player_pos) < enemy.size + 22.0)
		if hit_bullet or hit_enemy:
			_hurt()


func _hurt() -> void:
	lives -= 1
	invuln = 1.8
	bullets = bullets.filter(func(bullet: Dictionary) -> bool: return not bullet.enemy)
	explosions.append({"x": player_x, "y": PLAYER_Y, "t": 0.0, "big": true})
	_play_sfx("hurt")
	if lives <= 0:
		state = GameState.GAME_OVER


func _check_stage_end() -> void:
	if not boss.is_empty() and boss.hp <= 0:
		score += 8000
		explosions.append({"x": boss.x, "y": boss.y, "t": 0.0, "big": true})
		boss.clear()
		state = GameState.VICTORY
		_play_sfx("clear")
		return

	if not stages[stage].boss and enemies.is_empty():
		score += 1000 + stage * 500
		bombs = mini(5, bombs + 1)
		_play_sfx("clear")
		load_stage(stage + 1)


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color("#04050a"))
	_draw_background()
	_draw_hud()
	_draw_playfield()
	if state != GameState.PLAYING:
		_draw_overlay()


func _draw_background() -> void:
	var st: Dictionary = stages[stage]
	var panel: Rect2 = bg_panels[st.bg]
	if background_texture:
		draw_texture_rect_region(background_texture, Rect2(0, HUD, W, PLAY_H), panel, Color(1, 1, 1, 0.92))
	else:
		draw_rect(Rect2(0, HUD, W, PLAY_H), Color("#081323"))
	draw_rect(Rect2(0, HUD, W, PLAY_H), Color(0, 0, 0, 0.34))
	for i in range(65):
		var x := fmod(i * 149.0 + stage_timer * (12.0 + i % 4), W)
		var y := HUD + fmod(i * 61.0 + stage_timer * (35.0 + i % 5), PLAY_H)
		var size := 2.0 if i % 7 == 0 else 1.0
		draw_rect(Rect2(x, y, size, size), Color("#bdfbff") if i % 7 == 0 else Color(1, 1, 1, 0.55))


func _draw_hud() -> void:
	draw_rect(Rect2(0, 0, W, HUD), Color(0.012, 0.031, 0.063, 0.94))
	draw_line(Vector2(0, HUD - 1.0), Vector2(W, HUD - 1.0), Color(0.33, 0.91, 1.0, 0.5), 2.0)
	_draw_label("SCORE", 26, 18)
	_draw_digits(str(score).pad_zeros(7), 132, 15, 5, Color("#7df7ff"))
	_draw_label("STAGE", 382, 18)
	_draw_digits(str(stage + 1), 486, 15, 5, Color("#fff06a"))
	_draw_label("LIFE", 574, 18)
	_draw_digits(str(lives), 664, 15, 5, Color("#81ff88"))
	_draw_label("BOMB", 742, 18)
	_draw_digits(str(bombs), 834, 15, 5, Color("#ff7af0"))
	if not boss.is_empty():
		var width := 330.0
		draw_rect(Rect2(315, 56, width, 8), Color(1, 1, 1, 0.14))
		draw_rect(Rect2(315, 56, width * maxf(0.0, float(boss.hp) / float(boss.max_hp)), 8), Color("#ff386f"))


func _draw_playfield() -> void:
	for enemy in enemies:
		_draw_enemy(enemy)
	if not boss.is_empty():
		_draw_boss()
	for bullet in bullets:
		_draw_bullet(bullet)
	for wave in bomb_waves:
		_draw_bomb_wave(wave)
	_draw_player()
	for explosion in explosions:
		_draw_explosion(explosion)


func _draw_player() -> void:
	var tint := Color(1, 1, 1, 0.52) if invuln > 0.0 and int(stage_timer * 16.0) % 2 == 0 else Color.WHITE
	_draw_sprite("player", player_x, PLAYER_Y, 150, 150, tint)


func _draw_enemy(enemy: Dictionary) -> void:
	_draw_sprite(enemy.kind, enemy.x, enemy.y, enemy.size * 2.35, enemy.size * 2.35)


func _draw_boss() -> void:
	_draw_sprite("boss", boss.x, boss.y, 390, 390)


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
	var top := HUD + 8.0
	var height := PLAYER_Y - top
	var beam_width: float = wave.width * (1.0 - progress * 0.38)
	var alpha := 1.0 - progress
	draw_rect(Rect2(wave.x - beam_width / 2.0, top, beam_width, height), Color(1.0, 0.36, 0.84, 0.22 * alpha))
	draw_rect(Rect2(wave.x - beam_width * 0.22, top, beam_width * 0.44, height), Color(1.0, 0.97, 0.51, 0.28 * alpha))
	draw_line(Vector2(wave.x, PLAYER_Y), Vector2(wave.x + sin(wave.t * 48.0) * 18.0, top), Color(1, 1, 1, 0.8 * alpha), 4.0)


func _draw_sprite(key: String, cx: float, cy: float, dw: float, dh: float, tint := Color.WHITE) -> void:
	if sprite_texture and sprites.has(key):
		draw_texture_rect_region(sprite_texture, Rect2(cx - dw / 2.0, cy - dh / 2.0, dw, dh), sprites[key], tint)
	else:
		draw_rect(Rect2(cx - dw / 2.0, cy - dh / 2.0, dw, dh), Color("#7df7ff"))


func _draw_overlay() -> void:
	draw_rect(Rect2(0, HUD, W, PLAY_H), Color(0, 0, 0, 0.62))
	var title := "NOVA SWARM"
	if state == GameState.PAUSED:
		title = "PAUSED"
	elif state == GameState.VICTORY:
		title = "MISSION CLEAR"
	elif state == GameState.GAME_OVER:
		title = "GAME OVER"
	var sub := "PRESS P TO RETURN" if state == GameState.PAUSED else "PRESS ENTER TO START"
	_draw_centered(title, HUD + 220, 58, Color("#dffcff"))
	_draw_centered(sub, HUD + 292, 22, Color("#ff7af0"))
	_draw_centered("5 STAGES / VARIANT ALIENS / BOMB / BOSS BATTLE", HUD + 340, 17, Color(0.89, 0.98, 1.0, 0.82))


func _draw_label(text: String, x: float, y: float) -> void:
	draw_string(font, Vector2(x, y + 18), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.89, 0.98, 1.0, 0.76))


func _draw_centered(text: String, y: float, size: int, color: Color) -> void:
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	draw_string(font, Vector2((W - text_size.x) / 2.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _draw_digits(text: String, x: float, y: float, pixel_size: int, color: Color) -> void:
	var cursor := x
	for ch in text:
		var rows: Array = digit_map.get(ch, digit_map[" "])
		for row in range(rows.size()):
			for col in range(rows[row].length()):
				if rows[row][col] == "1":
					draw_rect(Rect2(cursor + col * pixel_size, y + row * pixel_size, pixel_size - 1, pixel_size - 1), color)
		cursor += pixel_size * 4


func _sprite_cell(col: int, row: int, pad := SPRITE_PAD) -> Rect2:
	return Rect2(col * SPRITE_CELL + pad, row * SPRITE_CELL + pad, SPRITE_CELL - pad * 2.0, SPRITE_CELL - pad * 2.0)


func _distance(a: Dictionary, b: Dictionary) -> float:
	return Vector2(a.x, a.y).distance_to(Vector2(b.x, b.y))


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


func _setup_audio() -> void:
	for i in range(10):
		var player := AudioStreamPlayer.new()
		add_child(player)
		audio_players.append(player)
	sfx_streams = {
		"shot": _make_tone(720, 0.08, "square", 0.18, -0.58),
		"hit": _make_noise(0.13, 0.2),
		"boom": _make_noise(0.42, 0.38),
		"bomb": _make_noise(0.72, 0.44),
		"hurt": _make_tone(220, 0.24, "square", 0.3, -0.36),
		"boss": _make_tone(110, 0.72, "saw", 0.32, -0.15),
		"clear": _make_tone(440, 0.32, "square", 0.22, 0.18),
	}


func _update_music(dt: float) -> void:
	if muted:
		return
	music_timer -= dt
	if music_timer > 0.0:
		return
	music_timer = 0.19
	var notes := [110.0, 146.83, 164.81, 220.0, 196.0, 164.81, 146.83, 130.81]
	var note: float = notes[music_step % notes.size()]
	music_step += 1
	_play_stream(_make_tone(note, 0.18, "square", 0.055, 0.0), -24.0)
	if music_step % 4 == 0:
		_play_stream(_make_tone(note * 2.0, 0.12, "triangle", 0.04, 0.0), -27.0)


func _play_sfx(sfx_name: String) -> void:
	if muted or not sfx_streams.has(sfx_name):
		return
	_play_stream(sfx_streams[sfx_name], -8.0 if sfx_name in ["bomb", "boss"] else -12.0)


func _play_stream(stream: AudioStream, volume_db: float) -> void:
	for player in audio_players:
		if not player.playing:
			player.stream = stream
			player.volume_db = volume_db
			player.play()
			return


func _make_tone(freq: float, duration: float, wave: String, volume: float, freq_ramp: float) -> AudioStreamWAV:
	var mix_rate := 22050
	var frames := int(duration * mix_rate)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in range(frames):
		var t := float(i) / mix_rate
		var p := t / duration
		var f := maxf(30.0, freq * (1.0 + freq_ramp * p))
		var phase := f * t
		var sample := 0.0
		if wave == "square":
			sample = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
		elif wave == "triangle":
			sample = 2.0 * absf(2.0 * fmod(phase, 1.0) - 1.0) - 1.0
		elif wave == "saw":
			sample = 2.0 * fmod(phase, 1.0) - 1.0
		else:
			sample = sin(TAU * phase)
		var env := pow(1.0 - p, 1.8)
		_write_sample(data, i, sample * env * volume)
	return _make_wav(data, mix_rate)


func _make_noise(duration: float, volume: float) -> AudioStreamWAV:
	var mix_rate := 22050
	var frames := int(duration * mix_rate)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var last := 0.0
	for i in range(frames):
		var p := float(i) / frames
		last = lerpf(last, randf_range(-1.0, 1.0), 0.38)
		_write_sample(data, i, last * pow(1.0 - p, 2.2) * volume)
	return _make_wav(data, mix_rate)


func _write_sample(data: PackedByteArray, index: int, value: float) -> void:
	var sample := int(clampf(value, -1.0, 1.0) * 32767.0)
	var unsigned := sample if sample >= 0 else sample + 65536
	data[index * 2] = unsigned & 0xff
	data[index * 2 + 1] = (unsigned >> 8) & 0xff


func _make_wav(data: PackedByteArray, mix_rate: int) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = data
	return stream


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
		if raw_stage >= 1 and raw_stage <= stages.size():
			load_stage(raw_stage - 1)
