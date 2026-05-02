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


func fire_player(x: float, y: float, overdrive := false, pattern := "twin") -> void:
	if overdrive:
		bullets.append({"x": x, "y": y - 54.0, "vx": 0.0, "vy": -760.0, "enemy": false, "r": 6.0, "power": 2, "color": Color("#fff06a"), "sprite": "overdrive"})
		bullets.append({"x": x - 20.0, "y": y - 42.0, "vx": -95.0, "vy": -700.0, "enemy": false, "r": 5.0, "power": 1, "color": Color("#49dfff"), "sprite": "player"})
		bullets.append({"x": x + 20.0, "y": y - 42.0, "vx": 95.0, "vy": -700.0, "enemy": false, "r": 5.0, "power": 1, "color": Color("#ff7af0"), "sprite": "player"})
		if pattern == "wide":
			bullets.append({"x": x - 38.0, "y": y - 34.0, "vx": -175.0, "vy": -620.0, "enemy": false, "r": 4.0, "power": 1, "color": Color("#81ff88"), "sprite": "player"})
			bullets.append({"x": x + 38.0, "y": y - 34.0, "vx": 175.0, "vy": -620.0, "enemy": false, "r": 4.0, "power": 1, "color": Color("#81ff88"), "sprite": "player"})
		return
	bullets.append({"x": x - 12.0, "y": y - 44.0, "vx": 0.0, "vy": -660.0, "enemy": false, "r": 4.0, "power": 1, "color": Color("#49dfff"), "sprite": "player"})
	bullets.append({"x": x + 12.0, "y": y - 44.0, "vx": 0.0, "vy": -660.0, "enemy": false, "r": 4.0, "power": 1, "color": Color("#49dfff"), "sprite": "player"})
	if pattern == "wide":
		bullets.append({"x": x - 30.0, "y": y - 34.0, "vx": -135.0, "vy": -610.0, "enemy": false, "r": 3.5, "power": 1, "color": Color("#81ff88"), "sprite": "player"})
		bullets.append({"x": x + 30.0, "y": y - 34.0, "vx": 135.0, "vy": -610.0, "enemy": false, "r": 3.5, "power": 1, "color": Color("#81ff88"), "sprite": "player"})


func fire_enemy(enemy: Dictionary, player_x: float, enemy_stats: Dictionary) -> void:
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
