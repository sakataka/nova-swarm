extends RefCounted
class_name AiPilot

const Config := preload("res://scripts/game_config.gd")

const COMMAND_IDLE := {"move_axis": 0.0, "shoot": false, "bomb": false, "overdrive": false}
const MIN_X := 52.0
const MAX_X := Config.W - 52.0


func get_command(player: RefCounted, enemies: Array, boss: Dictionary, bullets: Array, items: Array) -> Dictionary:
	var command := COMMAND_IDLE.duplicate()
	var has_target := not enemies.is_empty() or not boss.is_empty()
	command.shoot = has_target
	command.overdrive = has_target and player.can_overdrive()

	var immediate_danger := _danger_at_x(player.x, player, bullets, enemies, boss)
	var intent_x := _choose_intent_x(player, enemies, boss, items, immediate_danger)
	var lane := _choose_lane(player, bullets, enemies, boss, intent_x)
	var target_x: float = lane["x"]
	var danger: float = lane["danger"]
	command.move_axis = _axis_toward(player.x, target_x, danger)
	command.bomb = player.can_bomb() and immediate_danger >= 2.2
	return command


func _choose_intent_x(player: RefCounted, enemies: Array, boss: Dictionary, items: Array, danger: float) -> float:
	if _should_collect_item(player, items, danger):
		return _best_item(items, player).x
	if not enemies.is_empty() or not boss.is_empty():
		return _best_attack_x(player, enemies, boss)
	return player.x


func _choose_lane(player: RefCounted, bullets: Array, enemies: Array, boss: Dictionary, intent_x: float) -> Dictionary:
	var candidates := _candidate_lanes(player.x, intent_x)
	var best_x: float = player.x
	var best_score := INF
	var best_danger := 0.0
	for candidate_x in candidates:
		var x: float = candidate_x
		var danger := _danger_at_x(x, player, bullets, enemies, boss)
		var travel_cost := absf(x - player.x) * (0.002 if danger < 1.0 else 0.004)
		var intent_cost := absf(x - intent_x) * (0.006 if danger < 1.0 else 0.0008)
		var edge_cost := 0.18 if x < 86.0 or x > Config.W - 86.0 else 0.0
		var score := danger * 4.2 + travel_cost + intent_cost + edge_cost
		if score < best_score:
			best_score = score
			best_x = x
			best_danger = danger
	return {"x": best_x, "danger": best_danger}


func _candidate_lanes(current_x: float, intent_x: float) -> Array[float]:
	var lanes: Array[float] = [
		MIN_X,
		102.0,
		172.0,
		242.0,
		312.0,
		382.0,
		452.0,
		522.0,
		592.0,
		662.0,
		732.0,
		802.0,
		872.0,
		MAX_X,
		clampf(current_x, MIN_X, MAX_X),
		clampf(current_x - 118.0, MIN_X, MAX_X),
		clampf(current_x + 118.0, MIN_X, MAX_X),
		clampf(intent_x, MIN_X, MAX_X),
	]
	return lanes


func _danger_at_x(test_x: float, player: RefCounted, bullets: Array, enemies: Array, boss: Dictionary) -> float:
	var danger := 0.0
	for bullet in bullets:
		if not bullet.enemy:
			continue
		var vy: float = maxf(1.0, bullet.vy)
		var time_to_player: float = (player.y - bullet.y) / vy
		if time_to_player < -0.2 or time_to_player > 1.65:
			continue
		var predicted_x: float = bullet.x + bullet.vx * time_to_player
		var lateral: float = absf(predicted_x - test_x)
		var radius: float = bullet.r + 52.0
		if lateral > radius + 24.0:
			continue
		var lane_ratio := clampf(1.0 - lateral / (radius + 24.0), 0.0, 1.0)
		var urgency := clampf(1.65 - maxf(0.0, time_to_player), 0.25, 1.65)
		var weight: float = lane_ratio * lane_ratio * urgency
		danger += weight

	for enemy in enemies:
		if enemy.y < player.y - 210.0:
			continue
		var lateral_enemy: float = absf(enemy.x - test_x)
		var radius_enemy: float = enemy.size + 58.0
		if lateral_enemy < radius_enemy:
			var weight_enemy: float = (1.0 - lateral_enemy / radius_enemy) * 1.7
			danger += weight_enemy

	if not boss.is_empty() and boss.get("tell", 0.0) > 0.0 and absf(boss.x - test_x) < 118.0:
		danger += 1.8
	return danger


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
		return clampf(float(boss.x), MIN_X, MAX_X)
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
	return clampf(float(best.x), MIN_X, MAX_X)


func _axis_toward(current_x: float, target_x: float, danger: float) -> float:
	var delta := target_x - current_x
	var dead_zone := 10.0 if danger < 1.0 else 4.0
	if absf(delta) <= dead_zone:
		return 0.0
	return clampf(delta / (52.0 if danger >= 1.0 else 78.0), -1.0, 1.0)
