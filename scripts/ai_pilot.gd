extends RefCounted
class_name AiPilot

const Config := preload("res://scripts/game_config.gd")

const COMMAND_IDLE := {"move_axis": 0.0, "shoot": false, "bomb": false, "overdrive": false}
const MIN_X := 52.0
const MAX_X := Config.W - 52.0
const BOSS_TELL_DANGER_WIDTH := 154.0
const BOSS_BEAM_DANGER_WIDTH := 136.0


func get_command(player: RefCounted, enemies: Array, boss: Dictionary, bullets: Array, items: Array) -> Dictionary:
	var command := COMMAND_IDLE.duplicate()
	var has_target := not enemies.is_empty() or not boss.is_empty()
	command.shoot = has_target
	command.overdrive = has_target and player.can_overdrive()

	var immediate_danger := _danger_at_x(player.x, player, bullets, enemies, boss)
	var intent_x := _choose_intent_x(player, enemies, boss, items, immediate_danger)
	var lane := _choose_lane(player, bullets, enemies, boss, items, intent_x, enemies.size())
	var target_x: float = lane["x"]
	var danger: float = lane["danger"]
	command.move_axis = _axis_toward(player.x, target_x, danger)
	command.bomb = _should_use_bomb(player, boss, immediate_danger, danger)
	return command


func _choose_intent_x(player: RefCounted, enemies: Array, boss: Dictionary, items: Array, danger: float) -> float:
	if _should_chase_item(player, items, danger, enemies.size()):
		return _best_item(items, player).x
	if not enemies.is_empty() or not boss.is_empty():
		return _best_attack_x(player, enemies, boss)
	return player.x


func _choose_lane(player: RefCounted, bullets: Array, enemies: Array, boss: Dictionary, items: Array, intent_x: float, enemy_count: int) -> Dictionary:
	var candidates := _candidate_lanes(player.x, intent_x)
	var best_x: float = player.x
	var best_score := INF
	var best_danger := 0.0
	for candidate_x in candidates:
		var x: float = candidate_x
		var danger := _danger_at_x(x, player, bullets, enemies, boss)
		var travel_cost := absf(x - player.x) * (0.0015 if danger < 1.0 else 0.0032)
		var intent_cost := absf(x - intent_x) * (0.006 if danger < 0.85 else 0.00045)
		var edge_cost := 0.18 if x < 86.0 or x > Config.W - 86.0 else 0.0
		var item_bonus := _item_lane_bonus(x, player, items, danger, enemy_count)
		var score := danger * 5.8 + travel_cost + intent_cost + edge_cost - item_bonus
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
		var is_boss_beam: bool = str(bullet.get("sprite", "")) == "beam"
		var vy: float = maxf(1.0, bullet.vy)
		var time_to_player: float = (player.y - bullet.y) / vy
		if time_to_player < -0.2 or time_to_player > 2.15:
			continue
		var predicted_x: float = bullet.x + bullet.vx * time_to_player
		var lateral: float = absf(predicted_x - test_x)
		var radius: float = bullet.r + (BOSS_BEAM_DANGER_WIDTH if is_boss_beam else 68.0)
		var slack := 54.0 if is_boss_beam else 34.0
		if lateral > radius + slack:
			continue
		var lane_ratio := clampf(1.0 - lateral / (radius + slack), 0.0, 1.0)
		var urgency := clampf(2.15 - maxf(0.0, time_to_player), 0.32, 2.15)
		var weight: float = lane_ratio * lane_ratio * urgency * 1.24
		if is_boss_beam:
			weight *= 1.75
		if time_to_player < 0.55:
			weight *= 1.55
		danger += weight

	for enemy in enemies:
		if enemy.y < player.y - 210.0:
			continue
		var lateral_enemy: float = absf(enemy.x - test_x)
		var radius_enemy: float = enemy.size + 58.0
		if lateral_enemy < radius_enemy:
			var weight_enemy: float = (1.0 - lateral_enemy / radius_enemy) * 1.7
			danger += weight_enemy

	if not boss.is_empty() and boss.get("tell", 0.0) > 0.0:
		var tell_lateral := absf(float(boss.x) - test_x)
		if tell_lateral < BOSS_TELL_DANGER_WIDTH:
			var tell_ratio := clampf(1.0 - tell_lateral / BOSS_TELL_DANGER_WIDTH, 0.0, 1.0)
			danger += 1.15 + tell_ratio * tell_ratio * 2.15
	elif not boss.is_empty() and boss.get("phase", 0) >= 1 and absf(boss.x - test_x) < 64.0:
		danger += 0.55
	return danger


func _should_chase_item(player: RefCounted, items: Array, danger: float, enemy_count: int) -> bool:
	if items.is_empty() or danger > 0.85:
		return false
	var item := _best_item(items, player)
	var urgent: bool = (item.kind == "life" and player.lives <= 2) or (item.kind == "shield" and player.shield <= 0) or (item.kind == "bomb" and player.bombs <= 1)
	var end_stage_pickup: bool = enemy_count <= 1 and item.y > player.y - 320.0
	var close_x: bool = absf(item.x - player.x) < (210.0 if end_stage_pickup else 210.0 if urgent else 120.0)
	return (urgent or end_stage_pickup) and close_x and item.y > player.y - 280.0 and item.y < player.y + 28.0


func _item_lane_bonus(test_x: float, player: RefCounted, items: Array, danger: float, enemy_count: int) -> float:
	if items.is_empty() or danger > 0.85:
		return 0.0
	var bonus := 0.0
	for item in items:
		if item.y < Config.HUD + 60.0 or item.y > player.y + 38.0:
			continue
		var horizontal := absf(item.x - test_x)
		if horizontal > 92.0:
			continue
		var priority := 0.22
		if item.kind == "life" and player.lives <= 2:
			priority = 0.82
		elif item.kind == "shield" and player.shield <= 0:
			priority = 0.54
		elif item.kind == "bomb" and player.bombs <= 2:
			priority = 0.48
		if enemy_count <= 1:
			priority += 0.26
		var approach := clampf(1.0 - horizontal / 92.0, 0.0, 1.0)
		var timing := clampf(1.0 - absf(item.y - (player.y - 120.0)) / 260.0, 0.0, 1.0)
		bonus = maxf(bonus, priority * approach * (0.5 + timing * 0.5))
	return bonus


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
		var side := 1.0 if player.x >= float(boss.x) else -1.0
		return clampf(float(boss.x) + side * 72.0, MIN_X, MAX_X)
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


func _should_use_bomb(player: RefCounted, boss: Dictionary, immediate_danger: float, lane_danger: float) -> bool:
	if not player.can_bomb():
		return false
	if immediate_danger >= 2.55 or lane_danger >= 2.25:
		return true
	if boss.is_empty():
		return false
	var boss_hp_ratio: float = float(boss.hp) / maxf(1.0, float(boss.max_hp))
	var boss_aligned: bool = absf(boss.x - player.x) < 205.0
	var boss_pressure: bool = boss.get("phase", 0) >= 1 or boss.get("tell", 0.0) > 0.0
	if boss_aligned and boss_pressure and player.bombs >= 2:
		return true
	if boss_aligned and boss_hp_ratio <= 0.38 and player.bombs >= 1:
		return true
	return false


func _axis_toward(current_x: float, target_x: float, danger: float) -> float:
	var delta := target_x - current_x
	var dead_zone := 10.0 if danger < 0.9 else 3.0
	if absf(delta) <= dead_zone:
		return 0.0
	return clampf(delta / (42.0 if danger >= 1.0 else 78.0), -1.0, 1.0)
