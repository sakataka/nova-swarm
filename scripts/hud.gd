extends RefCounted
class_name HudRenderer

const Config := preload("res://scripts/game_config.gd")


func draw_hud(canvas: CanvasItem, font: Font, display_font: Font, score: int, stage: int, wave: int, wave_count: int, lives: int, bombs: int, shield: int, combo: int, boss: Dictionary, resonance: float, overdrive_timer: float, overdrive_duration: float, chip_levels: Dictionary, chip_progress: Dictionary, muted: bool, chassis: Texture2D, icons: Texture2D, pulse := 0.0) -> void:
	canvas.draw_rect(Rect2(0, 0, Config.W, Config.HUD + 12.0), Color("#020711"))
	canvas.draw_line(Vector2(20, 75), Vector2(Config.W - 20, 75), Color(Config.UI_CYAN, 0.34), 1)
	for x in [298.0, 708.0]:
		canvas.draw_line(Vector2(x, 12), Vector2(x, 64), Color(Config.UI_CYAN, 0.18), 1)
	_draw_score(canvas, font, display_font, score)
	_draw_stage_progress(canvas, font, display_font, stage, wave, wave_count, pulse)
	_draw_resources(canvas, display_font, lives, bombs, shield, icons)
	_draw_growth_tracks(canvas, font, chip_levels, chip_progress, icons)
	_draw_resonance_bar(canvas, font, resonance, overdrive_timer, overdrive_duration, combo, muted, icons, pulse)
	if not boss.is_empty():
		_draw_boss_bar(canvas, display_font, boss, icons)


func draw_centered(canvas: CanvasItem, font: Font, text: String, y: float, size: int, color: Color) -> void:
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	canvas.draw_string(font, Vector2((Config.W - text_size.x) / 2.0, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func draw_fitted_text(canvas: CanvasItem, font: Font, text: String, rect: Rect2, preferred_size: int, minimum_size: int, color: Color, alignment := HORIZONTAL_ALIGNMENT_LEFT, optional := false) -> bool:
	var size := preferred_size
	while size > minimum_size and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > rect.size.x:
		size -= 1
	if optional and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > rect.size.x:
		return false
	canvas.draw_string(font, Vector2(rect.position.x, rect.position.y + size), text, alignment, rect.size.x, size, color)
	return true


func _draw_score(canvas: CanvasItem, font: Font, display_font: Font, score: int) -> void:
	canvas.draw_string(display_font, Vector2(34, 25), "SCORE", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Config.UI_TEXT_DIM)
	draw_fitted_text(canvas, display_font, str(score).pad_zeros(7), Rect2(90, 7, 190, 34), 30, 24, Config.UI_TEXT)


# Stage name sits beside the counter; waves are discrete segments so the remaining fight reads at a glance.
func _draw_stage_progress(canvas: CanvasItem, font: Font, display_font: Font, stage: int, wave: int, wave_count: int, pulse: float) -> void:
	var stage_label := "STAGE " + str(stage + 1) + " / " + str(Config.STAGES.size())
	canvas.draw_string(display_font, Vector2(312, 24), stage_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Config.UI_TEXT)
	var label_width := display_font.get_string_size(stage_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_fitted_text(canvas, font, str(Config.STAGES[stage].name), Rect2(324.0 + label_width, 12.0, 250.0 - label_width, 14.0), 11, 8, Config.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT, true)
	if wave_count > 1:
		draw_fitted_text(canvas, font, "WAVE " + str(wave + 1) + " / " + str(wave_count), Rect2(586.0, 12.0, 100.0, 14.0), 11, 9, Config.UI_TEXT_DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	var count := maxi(1, wave_count)
	var gap := 4.0
	var segment := (374.0 - gap * float(count - 1)) / float(count)
	for i in range(count):
		var rect := Rect2(312.0 + float(i) * (segment + gap), 33.0, segment, 6.0)
		canvas.draw_rect(rect, Color(0.1, 0.2, 0.34, 0.9))
		if i < wave:
			canvas.draw_rect(rect, Config.UI_CYAN)
		elif i == wave:
			canvas.draw_rect(rect, Color(Config.UI_CYAN, 0.45 + 0.35 * pulse))
		canvas.draw_rect(Rect2(rect.position + Vector2(0, 6), Vector2(rect.size.x, 1.0)), Color(1, 1, 1, 0.22 if i <= wave else 0.06))


func _draw_resources(canvas: CanvasItem, font: Font, lives: int, bombs: int, shield: int, icons: Texture2D) -> void:
	var metrics := [
		{"value": lives, "icon": 3, "color": Config.UI_TEXT},
		{"value": bombs, "icon": 5, "color": Config.UI_AMBER},
		{"value": shield, "icon": 4, "color": Config.UI_CYAN},
	]
	for i in range(metrics.size()):
		var metric: Dictionary = metrics[i]
		var x := 728.0 + float(i) * 76.0
		_draw_atlas_icon(canvas, icons, int(metric.icon), Rect2(x + 7.0, 20.0, 26.0, 26.0), Color.WHITE)
		canvas.draw_string(font, Vector2(x + 40.0, 44.0), str(metric.value), HORIZONTAL_ALIGNMENT_LEFT, 28, 24, metric.color)


func _draw_growth_tracks(canvas: CanvasItem, font: Font, levels: Dictionary, progress: Dictionary, icons: Texture2D) -> void:
	var keys := ["power", "spread", "resonance"]
	var labels := ["POW", "SPR", "RES"]
	for i in range(keys.size()):
		var key: String = keys[i]
		var track: Dictionary = Config.CHIP_TRACKS[key]
		var x := 312.0 + float(i) * 126.0
		var level := int(levels.get(key, 0))
		_draw_atlas_icon(canvas, icons, i, Rect2(x - 2.0, 46.0, 24.0, 24.0), Color.WHITE)
		canvas.draw_string(font, Vector2(x + 25.0, 58.0), labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(track.color, 0.95 if level > 0 else 0.62))
		for level_index in range(4):
			var filled := level_index < level
			canvas.draw_rect(Rect2(x + 54.0 + level_index * 15.0, 50.0, 12.0, 6.0), Color(track.color, 0.96 if filled else 0.16))
		if level >= 4:
			canvas.draw_string(font, Vector2(x + 54.0, 68.0), "MAX", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(track.color, 0.9))
			continue
		var partial := int(progress.get(key, 0))
		for pip in range(3):
			canvas.draw_circle(Vector2(x + 58.0 + pip * 11.0, 64.0), 2.4, Color(track.color, 0.94 if pip < partial else 0.18))


# The Drive gauge is the one resource the player spends by choice, so its ready state glows and the beat pips sit right under it.
func _draw_resonance_bar(canvas: CanvasItem, font: Font, resonance: float, overdrive_timer: float, overdrive_duration: float, combo: int, muted: bool, icons: Texture2D, pulse: float) -> void:
	var active := overdrive_timer > 0.0
	var ready := resonance >= 100.0 and not active
	var ratio := clampf(overdrive_timer / overdrive_duration if active else resonance / 100.0, 0.0, 1.0)
	var color := Config.UI_AMBER if active or ready else Config.UI_CYAN
	var gauge := Rect2(88, 52, 144, 8)
	_draw_atlas_icon(canvas, icons, 6, Rect2(28, 47, 22, 22), Color.WHITE)
	canvas.draw_string(font, Vector2(52, 60), "DRIVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(color, 0.92))
	canvas.draw_rect(gauge, Color(0.08, 0.17, 0.28, 0.96))
	var fill := color.lerp(Color.WHITE, 0.45 * pulse) if ready else color
	canvas.draw_rect(Rect2(gauge.position, Vector2(gauge.size.x * ratio, gauge.size.y)), fill)
	if ready:
		canvas.draw_rect(gauge.grow(2.0), Color(Config.UI_AMBER, 0.35 + 0.5 * pulse), false, 1.5)
	var status_text := "MUTE" if muted else "READY" if ready else "x" + str(combo) if combo >= 2 else ""
	if status_text != "":
		var status_color := Config.UI_AMBER if muted or ready else Color("#ffd47a")
		draw_fitted_text(canvas, font, status_text, Rect2(236.0, 49.0, 56.0, 16.0), 11, 8, status_color, HORIZONTAL_ALIGNMENT_RIGHT, true)


func _draw_boss_bar(canvas: CanvasItem, font: Font, boss: Dictionary, icons: Texture2D) -> void:
	var rect := Rect2(206.0, Config.HUD + 12.0, 548.0, 12.0)
	var hp_ratio := clampf(float(boss.hp) / maxf(1.0, float(boss.max_hp)), 0.0, 1.0)
	canvas.draw_rect(rect.grow(5.0), Color("#04101f"))
	canvas.draw_rect(rect, Color(0.08, 0.16, 0.26, 1.0))
	canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x * hp_ratio, rect.size.y)), Color("#ff5f45"))
	_draw_atlas_icon(canvas, icons, 8, Rect2(rect.position.x - 34.0, rect.position.y - 9.0, 28.0, 28.0), Color.WHITE)
	canvas.draw_string(font, Vector2(rect.position.x, rect.position.y - 5.0), "NOVA SOVEREIGN", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Config.UI_TEXT)


func _draw_atlas_icon(canvas: CanvasItem, texture: Texture2D, index: int, rect: Rect2, tint: Color) -> void:
	if not texture:
		return
	var cell := float(texture.get_width()) / 3.0
	var region := Rect2(float(index % 3) * cell, float(index / 3) * cell, cell, cell)
	canvas.draw_texture_rect_region(texture, rect, region, tint)
