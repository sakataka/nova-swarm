extends RefCounted
class_name BossController

var boss: Dictionary = {}
var hud_y := 76.0
var width := 960.0


func setup(play_width: float, hud_height: float) -> void:
	width = play_width
	hud_y = hud_height


func clear() -> void:
	boss.clear()


func spawn() -> void:
	boss = {
		"x": width / 2.0,
		"y": hud_y + 210.0,
		"hp": 380,
		"max_hp": 380,
		"t": 0.0,
		"phase": 0,
		"shoot": 0.5,
		"beam": 0.0,
		"tell": 0.0,
		"parts": [
			{"id": "left", "offset": Vector2(-96, 18), "hp": 34, "alive": true},
			{"id": "right", "offset": Vector2(96, 18), "hp": 34, "alive": true},
			{"id": "core", "offset": Vector2(0, 104), "hp": 48, "alive": true},
		],
	}


func update(dt: float, projectiles: RefCounted) -> bool:
	if boss.is_empty():
		return false
	boss.t += dt
	boss.phase = 2 if boss.hp < boss.max_hp * 0.35 else 1 if boss.hp < boss.max_hp * 0.68 else 0
	boss.x = width / 2.0 + sin(boss.t * (0.7 + boss.phase * 0.22)) * (90.0 + boss.phase * 38.0)
	boss.y = hud_y + 205.0 + sin(boss.t * 1.3) * 18.0
	boss.tell = maxf(0.0, boss.tell - dt)
	boss.shoot -= dt
	if boss.shoot <= 0.0:
		var alive_parts := _alive_part_count()
		boss.shoot = [1.15, 0.9, 0.68][boss.phase] + float(3 - alive_parts) * 0.08
		projectiles.fire_boss(boss.x, boss.y, boss.phase)

	boss.beam -= dt
	if boss.phase >= 1 and boss.beam <= 0.0 and _part_alive("core"):
		boss.tell = 0.45
		boss.beam = 3.6 if boss.phase == 1 else 2.7
		projectiles.fire_boss_beam(boss.x, boss.y)
		return true
	return false


func is_alive() -> bool:
	return not boss.is_empty() and boss.hp > 0


func _alive_part_count() -> int:
	if boss.is_empty() or not boss.has("parts"):
		return 0
	var count := 0
	for part in boss.parts:
		if part.alive:
			count += 1
	return count


func _part_alive(part_id: String) -> bool:
	if boss.is_empty() or not boss.has("parts"):
		return false
	for part in boss.parts:
		if part.id == part_id:
			return part.alive
	return false
