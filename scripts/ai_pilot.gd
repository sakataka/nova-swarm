extends RefCounted
class_name AiPilot

const Config := preload("res://scripts/game_config.gd")

const COMMAND_IDLE := {"move_axis": 0.0, "shoot": false, "bomb": false, "overdrive": false}


func get_command(player: RefCounted, enemies: Array, boss: Dictionary, bullets: Array, items: Array) -> Dictionary:
	var command := COMMAND_IDLE.duplicate()
	var has_target := not enemies.is_empty() or not boss.is_empty()
	command.shoot = has_target
	command.overdrive = has_target and player.can_overdrive()

	var threat := _read_threat(player, bullets, enemies, boss)
	var target_x: float = player.x
	var danger: float = threat["danger"]
	if danger >= 1.0:
		target_x = threat["escape_x"]
	elif _should_collect_item(player, items, danger):
		target_x = _best_item(items, player).x
	elif has_target:
		target_x = _best_attack_x(player, enemies, boss)

	command.move_axis = _axis_toward(player.x, target_x, danger)
	command.bomb = player.can_bomb() and danger >= 2.3
	return command


func _read_threat(player: RefCounted, bullets: Array, enemies: Array, boss: Dictionary) -> Dictionary:
	var danger := 0.0
	var pressure_x := 0.0
	for bullet in bullets:
		if not bullet.enemy:
			continue
		var vy: float = maxf(1.0, bullet.vy)
		var time_to_player: float = (player.y - bullet.y) / vy
		if time_to_player < -0.12 or time_to_player > 1.35:
			continue
		var predicted_x: float = bullet.x + bullet.vx * time_to_player
		var lateral: float = absf(predicted_x - player.x)
		var radius: float = bullet.r + 34.0
		if lateral > radius:
			continue
		var weight: float = (1.0 - lateral / radius) * (1.35 - maxf(0.0, time_to_player))
		danger += weight
		pressure_x += (1.0 if predicted_x >= player.x else -1.0) * weight

	for enemy in enemies:
		if enemy.y < player.y - 210.0:
			continue
		var lateral_enemy: float = absf(enemy.x - player.x)
		if lateral_enemy < enemy.size + 46.0:
			var weight_enemy: float = (1.0 - lateral_enemy / (enemy.size + 46.0)) * 1.25
			danger += weight_enemy
			pressure_x += (1.0 if enemy.x >= player.x else -1.0) * weight_enemy

	if not boss.is_empty() and boss.get("tell", 0.0) > 0.0 and absf(boss.x - player.x) < 92.0:
		danger += 1.2
		pressure_x += 1.2 if boss.x >= player.x else -1.2

	var escape_x: float = player.x
	if danger > 0.0:
		escape_x = player.x - signf(pressure_x if pressure_x != 0.0 else randf() - 0.5) * 154.0
		escape_x = clampf(escape_x, 52.0, Config.W - 52.0)
	return {"danger": danger, "escape_x": escape_x}


func _should_collect_item(player: RefCounted, items: Array, danger: float) -> bool:
	if items.is_empty() or danger > 0.85:
		return false
	var item := _best_item(items, player)
	return item.y > Config.HUD + 40.0 and item.y < player.y + 28.0


func _best_item(items: Array, player: RefCounted) -> Dictionary:
	var best: Dictionary = items[0]
	var best_score := INF
	for item in items:
		var kind_bias := 0.0
		if item.kind == "life" and player.lives <= 2:
			kind_bias = -160.0
		elif item.kind == "shield" and player.shield <= 0:
			kind_bias = -90.0
		elif item.kind == "bomb" and player.bombs <= 1:
			kind_bias = -70.0
		var score := absf(item.x - player.x) + absf(item.y - player.y) * 0.38 + kind_bias
		if score < best_score:
			best_score = score
			best = item
	return best


func _best_attack_x(player: RefCounted, enemies: Array, boss: Dictionary) -> float:
	if not boss.is_empty():
		return clampf(float(boss.x), 52.0, Config.W - 52.0)
	if enemies.is_empty():
		return player.x

	var best: Dictionary = enemies[0]
	var best_score := INF
	for enemy in enemies:
		var vertical_bias: float = maxf(0.0, player.y - enemy.y) * 0.08
		var score := absf(enemy.x - player.x) - vertical_bias
		if score < best_score:
			best_score = score
			best = enemy
	return clampf(float(best.x), 52.0, Config.W - 52.0)


func _axis_toward(current_x: float, target_x: float, danger: float) -> float:
	var delta := target_x - current_x
	var dead_zone := 12.0 if danger < 1.0 else 5.0
	if absf(delta) <= dead_zone:
		return 0.0
	return clampf(delta / 78.0, -1.0, 1.0)
