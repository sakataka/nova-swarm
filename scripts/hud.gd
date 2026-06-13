extends RefCounted
class_name HudRenderer

const Config := preload("res://scripts/game_config.gd")


func draw_hud(canvas: CanvasItem, font: Font, score: int, stage: int, lives: int, bombs: int, shield: int, combo: int, boss: Dictionary, resonance: float, overdrive_timer: float, overdrive_duration: float, ui_texture: Texture2D, ui_regions: Dictionary, muted: bool) -> void:
	canvas.draw_rect(Rect2(0, 0, Config.W, Config.HUD), Color(0.012, 0.031, 0.063, 0.94))
	canvas.draw_line(Vector2(0, Config.HUD - 1.0), Vector2(Config.W, Config.HUD - 1.0), Color(0.33, 0.91, 1.0, 0.5), 2.0)
	_draw_label(canvas, font, "SCORE", 22, 14)
	_draw_digits(canvas, str(score).pad_zeros(7), 118, 12, 5, Color("#7df7ff"))
	_draw_label(canvas, font, "STAGE", 330, 14)
	_draw_digits(canvas, str(stage + 1), 430, 12, 5, Color("#fff06a"))
	if ui_texture:
		_draw_resource_icon(canvas, ui_texture, ui_regions, "life", 512, 11)
		_draw_digits(canvas, str(lives), 543, 12, 5, Color("#81ff88"))
		_draw_resource_icon(canvas, ui_texture, ui_regions, "bomb", 604, 11)
		_draw_digits(canvas, str(bombs), 635, 12, 5, Color("#ff7af0"))
		_draw_resource_icon(canvas, ui_texture, ui_regions, "shield", 696, 11)
		_draw_digits(canvas, str(shield), 727, 12, 5, Color("#72eaff"))
	else:
		_draw_label(canvas, font, "LIFE", 512, 14)
		_draw_digits(canvas, str(lives), 594, 12, 5, Color("#81ff88"))
		_draw_label(canvas, font, "BOMB", 642, 14)
		_draw_digits(canvas, str(bombs), 730, 12, 5, Color("#ff7af0"))
		_draw_label(canvas, font, "SHLD", 790, 14)
		_draw_digits(canvas, str(shield), 874, 12, 5, Color("#72eaff"))
	if muted:
		_draw_mute_badge(canvas, font)
	if combo >= 2:
		_draw_label(canvas, font, "CHAIN", 790, 43)
		_draw_digits(canvas, str(combo), 874, 41, 4, Color("#ffef8b"))
	if not boss.is_empty():
		var bar_width := 330.0
		var hp_ratio := clampf(float(boss.hp) / maxf(1.0, float(boss.max_hp)), 0.0, 1.0)
		var boss_label: String = Config.STAGES[Config.STAGES.size() - 1].name
		canvas.draw_string(font, Vector2(218, 64), boss_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.89, 0.98, 1.0, 0.68))
		canvas.draw_rect(Rect2(315, 56, bar_width, 8), Color(1, 1, 1, 0.14))
		canvas.draw_rect(Rect2(315, 56, bar_width * hp_ratio, 8), Color("#fff06a") if hp_ratio < 0.35 else Color("#ff386f"))
		canvas.draw_rect(Rect2(315, 56, bar_width, 8), Color(0.33, 0.91, 1.0, 0.4), false, 1.0)
	_draw_resonance_bar(canvas, font, resonance, overdrive_timer, overdrive_duration)


func draw_centered(canvas: CanvasItem, font: Font, text: String, y: float, size: int, color: Color) -> void:
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	canvas.draw_string(font, Vector2((Config.W - text_size.x) / 2.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _draw_label(canvas: CanvasItem, font: Font, text: String, x: float, y: float) -> void:
	canvas.draw_string(font, Vector2(x, y + 18), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.89, 0.98, 1.0, 0.76))


func _draw_resource_icon(canvas: CanvasItem, ui_texture: Texture2D, ui_regions: Dictionary, key: String, x: float, y: float) -> void:
	if not ui_regions.has(key):
		return
	canvas.draw_texture_rect_region(ui_texture, Rect2(x, y, 22.0, 22.0), ui_regions[key])


func _draw_mute_badge(canvas: CanvasItem, font: Font) -> void:
	var label := "MUTE"
	var color := Color("#ff7af0")
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	var x := Config.W - text_size.x - 22.0
	var y := 31.0
	canvas.draw_rect(Rect2(x - 8.0, y - 15.0, text_size.x + 16.0, 20.0), Color(0.0, 0.0, 0.0, 0.34))
	canvas.draw_rect(Rect2(x - 8.0, y - 15.0, text_size.x + 16.0, 20.0), Color(color, 0.24), false, 1.0)
	canvas.draw_string(font, Vector2(x, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)


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
	var x := 22.0
	var y := Config.HUD - 12.0
	var width := Config.W - 44.0
	var height := 5.0
	var active := overdrive_timer > 0.0
	var ratio := clampf(overdrive_timer / overdrive_duration if active else resonance / 100.0, 0.0, 1.0)
	var color := Color("#fff06a") if active else Color("#49dfff")
	if not active and resonance >= 100.0:
		var pulse := 0.65 + sin(Time.get_ticks_msec() * 0.012) * 0.35
		color = Color(1.0, 0.45 + pulse * 0.2, 0.95, 1.0)
	canvas.draw_string(font, Vector2(x, Config.HUD - 19.0), "RESONANCE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.89, 0.98, 1.0, 0.55))
	canvas.draw_rect(Rect2(x, y, width, height), Color(1, 1, 1, 0.12))
	canvas.draw_rect(Rect2(x, y, width * ratio, height), color)
	canvas.draw_line(Vector2(x, y + height + 2.0), Vector2(x + width, y + height + 2.0), Color(color, 0.34), 1.0)
	if resonance >= 100.0 or active:
		var label := "OVERDRIVE" if active else "OVERDRIVE READY"
		canvas.draw_string(font, Vector2(Config.W - 174.0, Config.HUD - 19.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(color, 0.92))
