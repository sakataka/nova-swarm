extends RefCounted
class_name HudRenderer

const Config := preload("res://scripts/game_config.gd")


func draw_hud(canvas: CanvasItem, font: Font, score: int, stage: int, lives: int, bombs: int, combo: int, boss: Dictionary) -> void:
	canvas.draw_rect(Rect2(0, 0, Config.W, Config.HUD), Color(0.012, 0.031, 0.063, 0.94))
	canvas.draw_line(Vector2(0, Config.HUD - 1.0), Vector2(Config.W, Config.HUD - 1.0), Color(0.33, 0.91, 1.0, 0.5), 2.0)
	_draw_label(canvas, font, "SCORE", 22, 14)
	_draw_digits(canvas, str(score).pad_zeros(7), 118, 12, 5, Color("#7df7ff"))
	_draw_label(canvas, font, "STAGE", 330, 14)
	_draw_digits(canvas, str(stage + 1), 430, 12, 5, Color("#fff06a"))
	_draw_label(canvas, font, "LIFE", 512, 14)
	_draw_digits(canvas, str(lives), 594, 12, 5, Color("#81ff88"))
	_draw_label(canvas, font, "BOMB", 662, 14)
	_draw_digits(canvas, str(bombs), 750, 12, 5, Color("#ff7af0"))
	if combo >= 2:
		_draw_label(canvas, font, "CHAIN", 830, 14)
		_draw_digits(canvas, str(combo), 902, 12, 5, Color("#ffef8b"))
	if not boss.is_empty():
		var bar_width := 330.0
		canvas.draw_rect(Rect2(315, 56, bar_width, 8), Color(1, 1, 1, 0.14))
		canvas.draw_rect(Rect2(315, 56, bar_width * maxf(0.0, float(boss.hp) / float(boss.max_hp)), 8), Color("#ff386f"))


func draw_centered(canvas: CanvasItem, font: Font, text: String, y: float, size: int, color: Color) -> void:
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	canvas.draw_string(font, Vector2((Config.W - text_size.x) / 2.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _draw_label(canvas: CanvasItem, font: Font, text: String, x: float, y: float) -> void:
	canvas.draw_string(font, Vector2(x, y + 18), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.89, 0.98, 1.0, 0.76))


func _draw_digits(canvas: CanvasItem, text: String, x: float, y: float, pixel_size: int, color: Color) -> void:
	var cursor := x
	for ch in text:
		var rows: Array = Config.DIGIT_MAP.get(ch, Config.DIGIT_MAP[" "])
		for row in range(rows.size()):
			for col in range(rows[row].length()):
				if rows[row][col] == "1":
					canvas.draw_rect(Rect2(cursor + col * pixel_size, y + row * pixel_size, pixel_size - 1, pixel_size - 1), color)
		cursor += pixel_size * 4
