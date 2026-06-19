extends RefCounted
class_name HudRenderer

const Config := preload("res://scripts/game_config.gd")


func draw_hud(canvas: CanvasItem, font: Font, score: int, stage: int, lives: int, bombs: int, shield: int, combo: int, boss: Dictionary, resonance: float, overdrive_timer: float, overdrive_duration: float, ui_texture: Texture2D, ui_regions: Dictionary, muted: bool) -> void:
	var pulse := _pulse()
	canvas.draw_rect(Rect2(0, 0, Config.W, Config.HUD), Config.UI_BG)
	canvas.draw_rect(Rect2(0, 0, Config.W, Config.HUD), Color(Config.UI_DEEP_RED, 0.2 + pulse * 0.08))
	canvas.draw_line(Vector2(0, Config.HUD - 2.0), Vector2(Config.W, Config.HUD - 2.0), Color(Config.UI_RED, 0.74), 2.0)
	canvas.draw_line(Vector2(0, Config.HUD - 6.0), Vector2(Config.W, Config.HUD - 6.0), Color(Config.UI_CYAN, 0.18), 1.0)

	_draw_hud_cell(canvas, Rect2(16, 10, 280, 46), Config.UI_RED, "SCORE", str(score).pad_zeros(7), Color("#ffecdd"), 5)
	_draw_hud_cell(canvas, Rect2(306, 10, 150, 46), Config.UI_AMBER, "STAGE", str(stage + 1), Config.UI_AMBER, 5)

	_draw_resource_cluster(canvas, font, ui_texture, ui_regions, lives, bombs, shield)
	if combo >= 2:
		_draw_combo(canvas, font, combo)
	if muted:
		_draw_mute_badge(canvas, font)
	if not boss.is_empty():
		_draw_boss_bar(canvas, font, boss)
	_draw_resonance_bar(canvas, font, resonance, overdrive_timer, overdrive_duration)


func draw_centered(canvas: CanvasItem, font: Font, text: String, y: float, size: int, color: Color) -> void:
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	canvas.draw_string(font, Vector2((Config.W - text_size.x) / 2.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _draw_hud_cell(canvas: CanvasItem, rect: Rect2, accent: Color, label: String, value: String, value_color: Color, pixel_size: int) -> void:
	_draw_panel(canvas, rect, accent, 0.78)
	canvas.draw_string(ThemeDB.fallback_font, rect.position + Vector2(12, 17), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Config.UI_TEXT_DIM)
	_draw_digits(canvas, value, rect.position.x + 92.0, rect.position.y + 10.0, pixel_size, value_color)
	canvas.draw_line(rect.position + Vector2(8, rect.size.y - 7), rect.position + Vector2(rect.size.x - 8, rect.size.y - 7), Color(accent, 0.2), 1.0)


func _draw_resource_cluster(canvas: CanvasItem, font: Font, ui_texture: Texture2D, ui_regions: Dictionary, lives: int, bombs: int, shield: int) -> void:
	var start_x := 472.0
	var metrics := [
		{"key": "life", "label": "VITAL", "value": lives, "color": Config.UI_GREEN},
		{"key": "bomb", "label": "BOMB", "value": bombs, "color": Config.UI_MAGENTA},
		{"key": "shield", "label": "AEGIS", "value": shield, "color": Config.UI_CYAN},
	]
	for i in range(metrics.size()):
		var metric: Dictionary = metrics[i]
		var rect := Rect2(start_x + float(i) * 92.0, 10.0, 82.0, 46.0)
		var color: Color = metric.color
		_draw_panel(canvas, rect, color, 0.58)
		if ui_texture and ui_regions.has(metric.key):
			canvas.draw_texture_rect_region(ui_texture, Rect2(rect.position.x + 8.0, rect.position.y + 11.0, 24.0, 24.0), ui_regions[metric.key], Color(1, 1, 1, 0.94))
		else:
			canvas.draw_circle(rect.position + Vector2(20, 23), 10.0, Color(color, 0.68))
		canvas.draw_string(font, rect.position + Vector2(36, 18), str(metric.label), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Config.UI_TEXT_DIM)
		_draw_digits(canvas, str(metric.value), rect.position.x + 38.0, rect.position.y + 23.0, 4, color)


func _draw_combo(canvas: CanvasItem, font: Font, combo: int) -> void:
	var rect := Rect2(746, 34, 104, 30)
	_draw_panel(canvas, rect, Config.UI_AMBER, 0.56)
	canvas.draw_string(font, rect.position + Vector2(10, 17), "CHAIN", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Config.UI_TEXT_DIM)
	_draw_digits(canvas, str(combo), rect.position.x + 62.0, rect.position.y + 8.0, 4, Config.UI_AMBER)


func _draw_mute_badge(canvas: CanvasItem, font: Font) -> void:
	var rect := Rect2(Config.W - 84.0, 10.0, 66.0, 24.0)
	_draw_panel(canvas, rect, Config.UI_MAGENTA, 0.6)
	canvas.draw_string(font, rect.position + Vector2(12, 17), "MUTE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Config.UI_MAGENTA)


func _draw_boss_bar(canvas: CanvasItem, font: Font, boss: Dictionary) -> void:
	var rect := Rect2(222.0, 55.0, 424.0, 13.0)
	var hp_ratio := clampf(float(boss.hp) / maxf(1.0, float(boss.max_hp)), 0.0, 1.0)
	var color := Config.UI_AMBER if hp_ratio < 0.35 else Config.UI_RED
	canvas.draw_string(font, Vector2(124, 66), "CITADEL CORE", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(Config.UI_TEXT, 0.72))
	canvas.draw_rect(rect, Color(1, 1, 1, 0.1))
	canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x * hp_ratio, rect.size.y)), Color(color, 0.86))
	canvas.draw_rect(rect, Color(Config.UI_RED, 0.45), false, 1.0)
	for i in range(8):
		var x := rect.position.x + float(i) * rect.size.x / 8.0
		canvas.draw_line(Vector2(x, rect.position.y), Vector2(x + 11.0, rect.end.y), Color(0, 0, 0, 0.26), 1.0)


func _draw_panel(canvas: CanvasItem, rect: Rect2, accent: Color, alpha: float) -> void:
	canvas.draw_rect(rect, Color(Config.UI_PANEL_DARK, alpha))
	canvas.draw_rect(rect.grow(-2.0), Color(Config.UI_PANEL, alpha * 0.74))
	canvas.draw_rect(rect, Color(accent, Config.UI_LINE_ALPHA), false, 1.0)
	canvas.draw_line(rect.position + Vector2(7, 3), rect.position + Vector2(rect.size.x * 0.38, 3), Color(accent, 0.78), 2.0)
	canvas.draw_line(rect.end - Vector2(rect.size.x * 0.38, 3), rect.end - Vector2(7, 3), Color(accent, 0.38), 1.0)


func _draw_digits(canvas: CanvasItem, text: String, x: float, y: float, pixel_size: int, color: Color) -> void:
	var cursor := x
	for ch in text:
		var rows: Array = Config.DIGIT_MAP.get(ch, Config.DIGIT_MAP[" "])
		for row in range(rows.size()):
			for col in range(rows[row].length()):
				if rows[row][col] == "1":
					canvas.draw_rect(Rect2(cursor + col * pixel_size, y + row * pixel_size, pixel_size - 1, pixel_size - 1), color)
		cursor += pixel_size * 4


func _draw_resonance_bar(canvas: CanvasItem, font: Font, resonance: float, overdrive_timer: float, overdrive_duration: float) -> void:
	var x := 18.0
	var y := Config.HUD - 11.0
	var width := Config.W - 36.0
	var height := 5.0
	var active := overdrive_timer > 0.0
	var ratio := clampf(overdrive_timer / overdrive_duration if active else resonance / 100.0, 0.0, 1.0)
	var color := Config.UI_AMBER if active else Config.UI_CYAN
	if not active and resonance >= 100.0:
		var pulse := _pulse()
		color = Color(1.0, 0.14 + pulse * 0.28, 0.25 + pulse * 0.2, 1.0)
	canvas.draw_string(font, Vector2(x, Config.HUD - 18.0), "RESONANCE CORE", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(Config.UI_TEXT, 0.58))
	canvas.draw_rect(Rect2(x, y, width, height), Color(1, 1, 1, 0.11))
	canvas.draw_rect(Rect2(x, y, width * ratio, height), color)
	canvas.draw_line(Vector2(x, y + height + 2.0), Vector2(x + width, y + height + 2.0), Color(color, 0.32), 1.0)
	if resonance >= 100.0 or active:
		var label := "OVERDRIVE ACTIVE" if active else "OVERDRIVE READY"
		canvas.draw_string(font, Vector2(Config.W - 190.0, Config.HUD - 18.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(color, 0.94))


func _pulse() -> float:
	return 0.5 + sin(Time.get_ticks_msec() * 0.008) * 0.5
