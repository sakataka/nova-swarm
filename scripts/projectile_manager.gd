extends RefCounted
class_name ProjectileManager

var bullets: Array[Dictionary] = []
var hud_y := 76.0
var width := 960.0
var height := 720.0


func setup(play_width: float, play_height: float, hud_height: float) -> void:
	width = play_width
	height = play_height
	hud_y = hud_height


func clear() -> void:
	bullets.clear()


func fire_player(x: float, y: float, overdrive := false, pattern := "twin", growth := {}) -> void:
	var power_level := int(growth.get("power", 0))
	var spread_level := int(growth.get("spread", 0))
	var power_bonus := int(growth.get("power_bonus", 0))
	if overdrive:
		bullets.append({"x": x, "y": y - 54.0, "vx": 0.0, "vy": -780.0, "enemy": false, "r": 6.0, "power": 2 + power_bonus, "color": Color("#fff06a"), "sprite": "overdrive"})
		bullets.append({"x": x - 20.0, "y": y - 42.0, "vx": -95.0, "vy": -700.0, "enemy": false, "r": 5.0, "power": 1, "color": Color("#49dfff"), "sprite": "player"})
		bullets.append({"x": x + 20.0, "y": y - 42.0, "vx": 95.0, "vy": -700.0, "enemy": false, "r": 5.0, "power": 1, "color": Color("#ff7af0"), "sprite": "player"})
		if pattern == "wide":
			bullets.append({"x": x - 38.0, "y": y - 34.0, "vx": -175.0, "vy": -620.0, "enemy": false, "r": 4.0, "power": 1, "color": Color("#81ff88"), "sprite": "player"})
			bullets.append({"x": x + 38.0, "y": y - 34.0, "vx": 175.0, "vy": -620.0, "enemy": false, "r": 4.0, "power": 1, "color": Color("#81ff88"), "sprite": "player"})
		if pattern == "nova":
			for side in [-1, 1]:
				bullets.append({"x": x + side * 42.0, "y": y - 28.0, "vx": side * 220.0, "vy": -610.0, "enemy": false, "r": 4.0, "power": 1 + power_bonus, "color": Color("#7cff6b"), "sprite": "player"})
		return
	var main_power := 1 + power_bonus
	var speed := 660.0 + float(power_level) * 24.0
	bullets.append({"x": x - 12.0, "y": y - 44.0, "vx": 0.0, "vy": -speed, "enemy": false, "r": 4.0, "power": main_power, "color": Color("#eafcff"), "sprite": "player"})
	bullets.append({"x": x + 12.0, "y": y - 44.0, "vx": 0.0, "vy": -speed, "enemy": false, "r": 4.0, "power": main_power, "color": Color("#42d9ff"), "sprite": "player"})
	if pattern in ["wide", "nova"]:
		bullets.append({"x": x - 30.0, "y": y - 34.0, "vx": -135.0, "vy": -610.0, "enemy": false, "r": 3.5, "power": 1, "color": Color("#81ff88"), "sprite": "player"})
		bullets.append({"x": x + 30.0, "y": y - 34.0, "vx": 135.0, "vy": -610.0, "enemy": false, "r": 3.5, "power": 1, "color": Color("#81ff88"), "sprite": "player"})
	if pattern == "nova" and spread_level >= 3:
		bullets.append({"x": x - 42.0, "y": y - 26.0, "vx": -230.0, "vy": -560.0, "enemy": false, "r": 3.5, "power": 1, "color": Color("#ffd84a"), "sprite": "player"})
		bullets.append({"x": x + 42.0, "y": y - 26.0, "vx": 230.0, "vy": -560.0, "enemy": false, "r": 3.5, "power": 1, "color": Color("#ffd84a"), "sprite": "player"})


func fire_enemy(enemy: Dictionary, player_x: float, enemy_stats: Dictionary) -> void:
	if enemy.kind in ["mid_lancer", "mid_orbit", "mid_anchor"]:
		_fire_midboss(enemy, player_x)
		return
	if enemy.kind == "commander":
		var aim := clampf((player_x - enemy.x) * 0.18, -86.0, 86.0)
		for side in [-1, 0, 1]:
			bullets.append({"x": enemy.x + side * 22.0, "y": enemy.y + 34.0, "vx": aim + side * 58.0, "vy": 238.0 + absf(side) * 18.0, "enemy": true, "r": 6.0, "power": 1, "color": Color("#ff5ff0") if side != 0 else Color("#fff06a"), "sprite": "enemy"})
		return
	if enemy.kind == "saucer":
		for side in [-1, 1]:
			bullets.append({"x": enemy.x, "y": enemy.y + 22.0, "vx": side * 70.0, "vy": 215.0, "enemy": true, "r": 5.0, "power": 1, "color": Color("#ff63f7"), "sprite": "enemy"})
		return

	var aim := clampf((player_x - enemy.x) * 0.22, -90.0, 90.0)
	var stats: Dictionary = enemy_stats[enemy.kind]
	bullets.append({"x": enemy.x, "y": enemy.y + 22.0, "vx": aim, "vy": 260.0 if enemy.kind == "armor" else 230.0, "enemy": true, "r": 6.0 if enemy.kind == "armor" else 5.0, "power": 1, "color": stats.color, "sprite": "enemy"})


func _fire_midboss(enemy: Dictionary, player_x: float) -> void:
	var aim := clampf((player_x - enemy.x) * 0.2, -120.0, 120.0)
	if enemy.kind == "mid_lancer":
		for side in [-2, -1, 0, 1, 2]:
			bullets.append({"x": enemy.x + side * 15.0, "y": enemy.y + 48.0, "vx": aim + side * 46.0, "vy": 235.0 + absf(side) * 14.0, "enemy": true, "r": 6.0, "power": 1, "color": Color("#ff4d6d"), "sprite": "boss"})
	elif enemy.kind == "mid_orbit":
		for i in range(8):
			var angle := TAU * float(i) / 8.0 + float(enemy.t) * 0.4
			bullets.append({"x": enemy.x, "y": enemy.y + 28.0, "vx": cos(angle) * 122.0, "vy": 165.0 + sin(angle) * 88.0, "enemy": true, "r": 5.0, "power": 1, "color": Color("#a95cff"), "sprite": "enemy"})
	else:
		for side in [-1, 0, 1]:
			bullets.append({"x": enemy.x + side * 34.0, "y": enemy.y + 54.0, "vx": aim * 0.55 + side * 24.0, "vy": 285.0, "enemy": true, "r": 8.0, "power": 1, "color": Color("#ffb84d"), "sprite": "boss"})


func fire_boss(x: float, y: float, phase: int) -> void:
	var spread := 3 if phase == 0 else 4 if phase == 1 else 5
	for i in range(spread):
		var dx := i - (spread - 1.0) / 2.0
		bullets.append({"x": x + dx * 42.0, "y": y + 128.0, "vx": dx * 42.0, "vy": 220.0 + absf(dx) * 16.0, "enemy": true, "r": 6.0, "power": 1, "color": Color("#ff49df") if i % 2 else Color("#ff7a2b"), "sprite": "boss"})


func fire_boss_beam(x: float, y: float) -> void:
	bullets.append({"x": x, "y": y + 148.0, "vx": 0.0, "vy": 360.0, "enemy": true, "r": 14.0, "power": 1, "color": Color("#ff3c37"), "sprite": "beam"})


func update(dt: float) -> void:
	for bullet in bullets:
		bullet.x += bullet.vx * dt
		bullet.y += bullet.vy * dt
	bullets = bullets.filter(func(bullet: Dictionary) -> bool: return bullet.y > hud_y - 40.0 and bullet.y < height + 50.0 and bullet.x > -50.0 and bullet.x < width + 50.0)


func clear_enemy_bullets() -> void:
	bullets = bullets.filter(func(bullet: Dictionary) -> bool: return not bullet.enemy)


func cull_marked_player_bullets() -> void:
	bullets = bullets.filter(func(bullet: Dictionary) -> bool: return bullet.y > -900.0)
