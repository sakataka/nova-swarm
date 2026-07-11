extends RefCounted
class_name HudRenderer

const Config := preload("res://scripts/game_config.gd")


func draw_hud(canvas: CanvasItem, font: Font, score: int, stage: int, wave: int, wave_count: int, lives: int, bombs: int, shield: int, combo: int, boss: Dictionary, resonance: float, overdrive_timer: float, overdrive_duration: float, chip_levels: Dictionary, chip_progress: Dictionary, muted: bool, chassis: Texture2D, icons: Texture2D) -> void:
	canvas.draw_rect(Rect2(0, 0, Config.W, Config.HUD + 12.0), Color("#020711"))
	if chassis:
		canvas.draw_texture_rect(chassis, Rect2(0, -5, Config.W, 102), false, Color(1, 1, 1, 0.98))
	_draw_score(canvas, font, score, combo)
	_draw_stage_progress(canvas, font, stage, wave, wave_count)
	_draw_resources(canvas, font, lives, bombs, shield, icons)
	_draw_growth_tracks(canvas, font, chip_levels, chip_progress, icons)
	_draw_resonance_bar(canvas, font, resonance, overdrive_timer, overdrive_duration, icons)
	if muted:
		_draw_badge(canvas, font, "MUTE", 646.0, 69.0, Config.UI_AMBER)
	if not boss.is_empty():
		_draw_boss_bar(canvas, font, boss, icons)


func draw_centered(canvas: CanvasItem, font: Font, text: String, y: float, size: int, color: Color) -> void:
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	canvas.draw_string(font, Vector2((Config.W - text_size.x) / 2.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _draw_score(canvas: CanvasItem, font: Font, score: int, combo: int) -> void:
	canvas.draw_string(font, Vector2(34, 25), "SCORE", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Config.UI_TEXT_DIM)
	_draw_digits(canvas, str(score).pad_zeros(7), 92.0, 12.0, 5, Config.UI_TEXT)
	if combo >= 2:
		canvas.draw_string(font, Vector2(34, 51), "CHAIN  x" + str(combo), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Config.UI_AMBER)
	else:
		canvas.draw_string(font, Vector2(34, 51), "AURORA WING", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(Config.UI_CYAN, 0.7))


func _draw_stage_progress(canvas: CanvasItem, font: Font, stage: int, wave: int, wave_count: int) -> void:
	canvas.draw_string(font, Vector2(312, 24), "STAGE  " + str(stage + 1) + " / 6", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Config.UI_TEXT)
	canvas.draw_string(font, Vector2(566, 24), "WAVE  " + str(wave + 1) + " / " + str(wave_count), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Config.UI_TEXT_DIM)
	var progress := clampf((float(wave) + 0.35) / maxf(1.0, float(wave_count)), 0.0, 1.0)
	canvas.draw_rect(Rect2(312, 37, 374, 6), Color(0.1, 0.2, 0.34, 0.9))
	canvas.draw_rect(Rect2(312, 37, 374.0 * progress, 6), Color("#42d9ff"))
	canvas.draw_rect(Rect2(312, 43, 374.0 * progress, 2), Color(1, 1, 1, 0.46))


func _draw_resources(canvas: CanvasItem, font: Font, lives: int, bombs: int, shield: int, icons: Texture2D) -> void:
	var metrics := [
		{"label": "VITAL", "value": lives, "icon": 4, "color": Config.UI_GREEN},
		{"label": "BOMB", "value": bombs, "icon": 5, "color": Color("#ff68e8")},
		{"label": "AEGIS", "value": shield, "icon": 3, "color": Config.UI_CYAN},
	]
	for i in range(metrics.size()):
		var metric: Dictionary = metrics[i]
		var x := 728.0 + float(i) * 76.0
		_draw_atlas_icon(canvas, icons, int(metric.icon), Rect2(x + 7.0, 15.0, 23.0, 23.0), Color.WHITE)
		canvas.draw_string(font, Vector2(x + 33.0, 21.0), str(metric.label), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Config.UI_TEXT_DIM)
		_draw_digits(canvas, str(metric.value), x + 39.0, 29.0, 4, metric.color)


func _draw_growth_tracks(canvas: CanvasItem, font: Font, levels: Dictionary, progress: Dictionary, icons: Texture2D) -> void:
	var keys := ["power", "spread", "resonance"]
	for i in range(keys.size()):
		var key: String = keys[i]
		var track: Dictionary = Config.CHIP_TRACKS[key]
		var x := 368.0 + float(i) * 112.0
		_draw_atlas_icon(canvas, icons, i, Rect2(x, 51.0, 30.0, 30.0), Color.WHITE)
		canvas.draw_string(font, Vector2(x + 33.0, 62.0), str(track.name).substr(0, 3), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(track.color, 0.94))
		for level_index in range(4):
			var filled := level_index < int(levels.get(key, 0))
			canvas.draw_rect(Rect2(x + 33.0 + level_index * 12.0, 67.0, 9.0, 4.0), Color(track.color, 0.96 if filled else 0.16))
		var partial := int(progress.get(key, 0))
		for pip in range(3):
			canvas.draw_circle(Vector2(x + 36.0 + pip * 9.0, 76.0), 2.0, Color(track.color, 0.94 if pip < partial else 0.16))


func _draw_resonance_bar(canvas: CanvasItem, font: Font, resonance: float, overdrive_timer: float, overdrive_duration: float, icons: Texture2D) -> void:
	var active := overdrive_timer > 0.0
	var ratio := clampf(overdrive_timer / overdrive_duration if active else resonance / 100.0, 0.0, 1.0)
	var color := Config.UI_AMBER if active else Config.UI_CYAN
	_draw_atlas_icon(canvas, icons, 6, Rect2(24, 55, 24, 24), Color.WHITE)
	canvas.draw_string(font, Vector2(50, 67), "OVERDRIVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(color, 0.92))
	canvas.draw_rect(Rect2(112, 61, 132, 7), Color(0.08, 0.17, 0.28, 0.96))
	canvas.draw_rect(Rect2(112, 61, 132.0 * ratio, 7), color)
	if resonance >= 100.0 and not active:
		canvas.draw_string(font, Vector2(203, 58), "READY", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Config.UI_AMBER)


func _draw_boss_bar(canvas: CanvasItem, font: Font, boss: Dictionary, icons: Texture2D) -> void:
	var rect := Rect2(206.0, Config.HUD + 12.0, 548.0, 12.0)
	var hp_ratio := clampf(float(boss.hp) / maxf(1.0, float(boss.max_hp)), 0.0, 1.0)
	canvas.draw_rect(rect.grow(5.0), Color("#04101f"))
	canvas.draw_rect(rect, Color(0.08, 0.16, 0.26, 1.0))
	canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x * hp_ratio, rect.size.y)), Color("#ff5f45"))
	_draw_atlas_icon(canvas, icons, 8, Rect2(rect.position.x - 34.0, rect.position.y - 9.0, 28.0, 28.0), Color.WHITE)
	canvas.draw_string(font, Vector2(rect.position.x, rect.position.y - 5.0), "NOVA SOVEREIGN", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Config.UI_TEXT)


func _draw_badge(canvas: CanvasItem, font: Font, label: String, x: float, y: float, color: Color) -> void:
	canvas.draw_rect(Rect2(x, y - 13.0, 58.0, 17.0), Color("#061328"))
	canvas.draw_string(font, Vector2(x + 10.0, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, color)


func _draw_atlas_icon(canvas: CanvasItem, texture: Texture2D, index: int, rect: Rect2, tint: Color) -> void:
	if not texture:
		return
	var cell := float(texture.get_width()) / 3.0
	var region := Rect2(float(index % 3) * cell, float(index / 3) * cell, cell, cell)
	canvas.draw_texture_rect_region(texture, rect, region, tint)


func _draw_digits(canvas: CanvasItem, text: String, x: float, y: float, pixel_size: int, color: Color) -> void:
	var cursor := x
	for ch in text:
		var rows: Array = Config.DIGIT_MAP.get(ch, Config.DIGIT_MAP[" "])
		for row in range(rows.size()):
			for col in range(rows[row].length()):
				if rows[row][col] == "1":
					canvas.draw_rect(Rect2(cursor + col * pixel_size, y + row * pixel_size, pixel_size - 1, pixel_size - 1), color)
		cursor += pixel_size * 4
