extends RefCounted
class_name HudRenderer

const Config := preload("res://scripts/game_config.gd")


func draw_hud(canvas: CanvasItem, font: Font, score: int, stage: int, wave: int, wave_count: int, lives: int, bombs: int, shield: int, combo: int, boss: Dictionary, resonance: float, overdrive_timer: float, overdrive_duration: float, chip_levels: Dictionary, chip_progress: Dictionary, muted: bool) -> void:
	canvas.draw_rect(Rect2(0, 0, Config.W, Config.HUD), Color(Config.UI_BG, 0.98))
	canvas.draw_rect(Rect2(0, 0, Config.W, Config.HUD), Color(Config.UI_CYAN, 0.035))
	canvas.draw_line(Vector2(0, Config.HUD - 2.0), Vector2(Config.W, Config.HUD - 2.0), Color(Config.UI_CYAN, 0.72), 2.0)
	canvas.draw_line(Vector2(0, Config.HUD - 6.0), Vector2(Config.W, Config.HUD - 6.0), Color(Config.UI_MAGENTA, 0.2), 1.0)

	_draw_score(canvas, font, score, combo)
	_draw_stage_progress(canvas, font, stage, wave, wave_count)
	_draw_resources(canvas, font, lives, bombs, shield)
	_draw_growth_tracks(canvas, font, chip_levels, chip_progress)
	_draw_resonance_bar(canvas, font, resonance, overdrive_timer, overdrive_duration)
	if muted:
		_draw_badge(canvas, font, "MUTE", Config.W - 80.0, 62.0, Config.UI_MAGENTA)
	if not boss.is_empty():
		_draw_boss_bar(canvas, font, boss)


func draw_centered(canvas: CanvasItem, font: Font, text: String, y: float, size: int, color: Color) -> void:
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	canvas.draw_string(font, Vector2((Config.W - text_size.x) / 2.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _draw_score(canvas: CanvasItem, font: Font, score: int, combo: int) -> void:
	var rect := Rect2(18, 10, 252, 48)
	_draw_panel(canvas, rect, Config.UI_CYAN)
	canvas.draw_string(font, rect.position + Vector2(12, 17), "SCORE", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Config.UI_TEXT_DIM)
	_draw_digits(canvas, str(score).pad_zeros(7), rect.position.x + 78.0, rect.position.y + 10.0, 5, Config.UI_TEXT)
	if combo >= 2:
		canvas.draw_string(font, rect.position + Vector2(12, 40), "CHAIN x" + str(combo), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Config.UI_AMBER)


func _draw_stage_progress(canvas: CanvasItem, font: Font, stage: int, wave: int, wave_count: int) -> void:
	var rect := Rect2(282, 10, 250, 48)
	_draw_panel(canvas, rect, Config.UI_MAGENTA)
	canvas.draw_string(font, rect.position + Vector2(12, 18), "STAGE " + str(stage + 1) + " / 6", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Config.UI_TEXT)
	canvas.draw_string(font, rect.position + Vector2(150, 18), "WAVE " + str(wave + 1) + " / " + str(wave_count), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Config.UI_TEXT_DIM)
	var progress := clampf((float(wave) + 0.35) / maxf(1.0, float(wave_count)), 0.0, 1.0)
	canvas.draw_rect(Rect2(rect.position + Vector2(12, 31), Vector2(rect.size.x - 24, 6)), Color(1, 1, 1, 0.08))
	canvas.draw_rect(Rect2(rect.position + Vector2(12, 31), Vector2((rect.size.x - 24) * progress, 6)), Color(Config.UI_MAGENTA, 0.9))


func _draw_resources(canvas: CanvasItem, font: Font, lives: int, bombs: int, shield: int) -> void:
	var metrics := [
		{"label": "VITAL", "value": lives, "color": Config.UI_GREEN},
		{"label": "BOMB", "value": bombs, "color": Config.UI_MAGENTA},
		{"label": "AEGIS", "value": shield, "color": Config.UI_CYAN},
	]
	for i in range(metrics.size()):
		var metric: Dictionary = metrics[i]
		var rect := Rect2(544.0 + float(i) * 108.0, 10.0, 98.0, 48.0)
		_draw_panel(canvas, rect, metric.color)
		canvas.draw_string(font, rect.position + Vector2(10, 17), str(metric.label), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Config.UI_TEXT_DIM)
		_draw_digits(canvas, str(metric.value), rect.position.x + 62.0, rect.position.y + 12.0, 5, metric.color)


func _draw_growth_tracks(canvas: CanvasItem, font: Font, levels: Dictionary, progress: Dictionary) -> void:
	var start_x := 286.0
	for i in range(3):
		var key: String = ["power", "spread", "resonance"][i]
		var track: Dictionary = Config.CHIP_TRACKS[key]
		var x := start_x + float(i) * 82.0
		canvas.draw_string(font, Vector2(x, 67), str(track.name).substr(0, 3), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(track.color, 0.84))
		for level_index in range(4):
			var filled := level_index < int(levels.get(key, 0))
			canvas.draw_rect(Rect2(x + 27.0 + level_index * 11.0, 60.0, 8.0, 5.0), Color(track.color, 0.94 if filled else 0.13))
		var partial := int(progress.get(key, 0))
		for pip in range(3):
			canvas.draw_circle(Vector2(x + 29.0 + pip * 8.0, 70.0), 2.0, Color(track.color, 0.9 if pip < partial else 0.12))


func _draw_resonance_bar(canvas: CanvasItem, font: Font, resonance: float, overdrive_timer: float, overdrive_duration: float) -> void:
	var x := 18.0
	var y := Config.HUD - 9.0
	var width := 250.0
	var active := overdrive_timer > 0.0
	var ratio := clampf(overdrive_timer / overdrive_duration if active else resonance / 100.0, 0.0, 1.0)
	var color := Config.UI_AMBER if active else Config.UI_CYAN
	canvas.draw_string(font, Vector2(x, y - 3.0), "OVERDRIVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(color, 0.8))
	canvas.draw_rect(Rect2(x + 70.0, y - 8.0, width - 70.0, 6.0), Color(1, 1, 1, 0.1))
	canvas.draw_rect(Rect2(x + 70.0, y - 8.0, (width - 70.0) * ratio, 6.0), color)
	if resonance >= 100.0 and not active:
		canvas.draw_string(font, Vector2(192, y - 3.0), "READY", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Config.UI_AMBER)


func _draw_boss_bar(canvas: CanvasItem, font: Font, boss: Dictionary) -> void:
	var rect := Rect2(190.0, Config.HUD + 9.0, 580.0, 12.0)
	var hp_ratio := clampf(float(boss.hp) / maxf(1.0, float(boss.max_hp)), 0.0, 1.0)
	canvas.draw_rect(rect.grow(4.0), Color(Config.UI_PANEL_DARK, 0.82))
	canvas.draw_rect(rect, Color(1, 1, 1, 0.1))
	canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x * hp_ratio, rect.size.y)), Color(Config.UI_RED, 0.94))
	canvas.draw_string(font, Vector2(rect.position.x, rect.position.y - 5.0), "NOVA SOVEREIGN", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Config.UI_TEXT)


func _draw_badge(canvas: CanvasItem, font: Font, label: String, x: float, y: float, color: Color) -> void:
	canvas.draw_rect(Rect2(x, y - 13.0, 62.0, 17.0), Color(Config.UI_PANEL_DARK, 0.82))
	canvas.draw_rect(Rect2(x, y - 13.0, 62.0, 17.0), Color(color, 0.6), false, 1.0)
	canvas.draw_string(font, Vector2(x + 10.0, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)


func _draw_panel(canvas: CanvasItem, rect: Rect2, accent: Color) -> void:
	canvas.draw_rect(rect, Color(Config.UI_PANEL_DARK, 0.82))
	canvas.draw_rect(rect.grow(-2.0), Color(Config.UI_PANEL, 0.62))
	canvas.draw_rect(rect, Color(accent, 0.42), false, 1.0)
	canvas.draw_line(rect.position + Vector2(7, 3), rect.position + Vector2(rect.size.x * 0.42, 3), Color(accent, 0.86), 2.0)


func _draw_digits(canvas: CanvasItem, text: String, x: float, y: float, pixel_size: int, color: Color) -> void:
	var cursor := x
	for ch in text:
		var rows: Array = Config.DIGIT_MAP.get(ch, Config.DIGIT_MAP[" "])
		for row in range(rows.size()):
			for col in range(rows[row].length()):
				if rows[row][col] == "1":
					canvas.draw_rect(Rect2(cursor + col * pixel_size, y + row * pixel_size, pixel_size - 1, pixel_size - 1), color)
		cursor += pixel_size * 4
