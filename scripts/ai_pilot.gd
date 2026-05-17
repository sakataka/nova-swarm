extends RefCounted
class_name AiPilot

const Config := preload("res://scripts/game_config.gd")

const COMMAND_IDLE := {"move_axis": 0.0, "shoot": false, "bomb": false, "overdrive": false}
const MIN_X := 52.0
const MAX_X := Config.W - 52.0
const MIN_Y := Config.PLAYER_MIN_Y + 10.0
const MAX_Y := Config.PLAYER_MAX_Y - 10.0
const BOSS_TELL_DANGER_WIDTH := 154.0
const BOSS_BEAM_DANGER_WIDTH := 136.0


func get_command(player: RefCounted, enemies: Array, boss: Dictionary, bullets: Array, items: Array) -> Dictionary:
	var command := COMMAND_IDLE.duplicate()
	var has_target := not enemies.is_empty() or not boss.is_empty()
	command.shoot = has_target
	command.overdrive = has_target and player.can_overdrive()

	var player_pos := Vector2(player.x, player.y)
	var immediate_danger := _danger_at_position(player_pos, player, bullets, enemies, boss)
	var intent := _choose_intent_position(player, enemies, boss, items, immediate_danger)
	var lane := _choose_lane(player, bullets, enemies, boss, items, intent, enemies.size())
	var target: Vector2 = lane["position"]
	var danger: float = lane["danger"]
	var move_vector := _vector_toward(player_pos, target, danger)
	command.move_vector = move_vector
	command.move_axis = move_vector.x
	command.bomb = _should_use_bomb(player, boss, immediate_danger, danger)
	return command


func _choose_intent_position(player: RefCounted, enemies: Array, boss: Dictionary, items: Array, danger: float) -> Vector2:
	if _should_chase_item(player, items, danger, enemies.size()):
		var item := _best_item(items, player)
		return Vector2(float(item.x), clampf(float(item.y), MIN_Y, MAX_Y))
	if not enemies.is_empty() or not boss.is_empty():
		return _best_attack_position(player, enemies, boss)
	return Vector2(player.x, player.y)


func _choose_lane(player: RefCounted, bullets: Array, enemies: Array, boss: Dictionary, items: Array, intent: Vector2, enemy_count: int) -> Dictionary:
	var current := Vector2(player.x, player.y)
	var candidates := _candidate_positions(current, intent)
	var best_position := current
	var best_score := INF
	var best_danger := 0.0
	for candidate in candidates:
		var position: Vector2 = candidate
		var danger := _danger_at_position(position, player, bullets, enemies, boss)
		var travel_cost := position.distance_to(current) * (0.0011 if danger < 1.0 else 0.0028)
		var intent_cost := position.distance_to(intent) * (0.0045 if danger < 0.85 else 0.0004)
		var edge_cost := 0.18 if position.x < 86.0 or position.x > Config.W - 86.0 else 0.0
		edge_cost += 0.14 if position.y < MIN_Y + 28.0 or position.y > MAX_Y - 28.0 else 0.0
		var item_bonus := _item_lane_bonus(position, player, items, danger, enemy_count)
		var score := danger * 5.8 + travel_cost + intent_cost + edge_cost - item_bonus
		if score < best_score:
			best_score = score
			best_position = position
			best_danger = danger
	return {"position": best_position, "danger": best_danger}


func _candidate_positions(current: Vector2, intent: Vector2) -> Array[Vector2]:
	var x_lanes: Array[float] = [
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
		clampf(current.x, MIN_X, MAX_X),
		clampf(current.x - 118.0, MIN_X, MAX_X),
		clampf(current.x + 118.0, MIN_X, MAX_X),
		clampf(intent.x, MIN_X, MAX_X),
	]
	var y_lanes: Array[float] = [
		MIN_Y,
		MIN_Y + 72.0,
		MIN_Y + 150.0,
		MAX_Y - 92.0,
		MAX_Y,
		clampf(current.y, MIN_Y, MAX_Y),
		clampf(current.y - 92.0, MIN_Y, MAX_Y),
		clampf(current.y + 92.0, MIN_Y, MAX_Y),
		clampf(intent.y, MIN_Y, MAX_Y),
	]
	var positions: Array[Vector2] = []
	for x in x_lanes:
		for y in y_lanes:
			positions.append(Vector2(x, y))
	return positions


func _danger_at_x(test_x: float, player: RefCounted, bullets: Array, enemies: Array, boss: Dictionary) -> float:
	return _danger_at_position(Vector2(test_x, player.y), player, bullets, enemies, boss)


func _danger_at_position(test_pos: Vector2, player: RefCounted, bullets: Array, enemies: Array, boss: Dictionary) -> float:
	var danger := 0.0
	for bullet in bullets:
		if not bullet.enemy:
			continue
		var is_boss_beam: bool = str(bullet.get("sprite", "")) == "beam"
		var vy: float = maxf(1.0, bullet.vy)
		var time_to_player: float = (test_pos.y - bullet.y) / vy
		if time_to_player < -0.2 or time_to_player > 2.15:
			continue
		var predicted_x: float = bullet.x + bullet.vx * time_to_player
		var lateral: float = absf(predicted_x - test_pos.x)
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
		if enemy.y < test_pos.y - 210.0:
			continue
		var enemy_distance := Vector2(float(enemy.x), float(enemy.y)).distance_to(test_pos)
		var radius_enemy: float = enemy.size + 74.0
		if enemy_distance < radius_enemy:
			var weight_enemy: float = (1.0 - enemy_distance / radius_enemy) * 1.9
			danger += weight_enemy

	if not boss.is_empty() and boss.get("tell", 0.0) > 0.0:
		var tell_lateral := absf(float(boss.x) - test_pos.x)
		if tell_lateral < BOSS_TELL_DANGER_WIDTH and test_pos.y > float(boss.y):
			var tell_ratio := clampf(1.0 - tell_lateral / BOSS_TELL_DANGER_WIDTH, 0.0, 1.0)
			danger += 1.15 + tell_ratio * tell_ratio * 2.15
	elif not boss.is_empty() and boss.get("phase", 0) >= 1 and absf(boss.x - test_pos.x) < 64.0 and test_pos.y > float(boss.y):
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


func _item_lane_bonus(test_pos: Vector2, player: RefCounted, items: Array, danger: float, enemy_count: int) -> float:
	if items.is_empty() or danger > 0.85:
		return 0.0
	var bonus := 0.0
	for item in items:
		if item.y < Config.HUD + 60.0 or item.y > MAX_Y + 44.0:
			continue
		var distance := Vector2(float(item.x), float(item.y)).distance_to(test_pos)
		if distance > 116.0:
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
		var approach := clampf(1.0 - distance / 116.0, 0.0, 1.0)
		var timing := clampf(1.0 - absf(item.y - player.y) / 260.0, 0.0, 1.0)
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


func _best_attack_position(player: RefCounted, enemies: Array, boss: Dictionary) -> Vector2:
	if not boss.is_empty():
		var side := 1.0 if player.x >= float(boss.x) else -1.0
		return Vector2(clampf(float(boss.x) + side * 92.0, MIN_X, MAX_X), clampf(Config.PLAYER_Y - 54.0, MIN_Y, MAX_Y))
	if enemies.is_empty():
		return Vector2(player.x, player.y)

	var best: Dictionary = enemies[0]
	var best_score := INF
	for enemy in enemies:
		var vertical_bias: float = maxf(0.0, player.y - enemy.y) * 0.08
		var score := absf(enemy.x - player.x) - vertical_bias
		if score < best_score:
			best_score = score
			best = enemy
	var target_y := clampf(float(best.y) + 250.0, MIN_Y, MAX_Y)
	return Vector2(clampf(float(best.x), MIN_X, MAX_X), target_y)


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


func _vector_toward(current: Vector2, target: Vector2, danger: float) -> Vector2:
	var delta := target - current
	var dead_zone := 7.0 if danger >= 1.0 else 13.0
	if delta.length() <= dead_zone:
		return Vector2.ZERO
	var scale := 54.0 if danger >= 1.0 else 96.0
	return (delta / scale).limit_length(1.0)
