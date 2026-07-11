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
const PATH_SAMPLE_TIMES: Array[float] = [0.15, 0.35, 0.6, 0.9, 1.2, 1.6]
const LANE_HOLD_FRAMES := 12

var _held_target := Vector2.ZERO
var _held_intent := Vector2.ZERO
var _hold_frames := 0


func reset() -> void:
	_held_target = Vector2.ZERO
	_held_intent = Vector2.ZERO
	_hold_frames = 0


func get_command(player: RefCounted, enemies: Array, boss: Dictionary, bullets: Array, items: Array) -> Dictionary:
	var command := COMMAND_IDLE.duplicate()
	var has_target := not enemies.is_empty() or not boss.is_empty()
	command.shoot = has_target
	command.overdrive = has_target and player.can_overdrive()

	var player_pos := Vector2(player.x, player.y)
	var immediate_danger := _danger_at_position(player_pos, player, bullets, enemies, boss)
	var intent := _choose_intent_position(player, enemies, boss, items, immediate_danger)
	var lane := _choose_lane(player, bullets, enemies, boss, items, intent, enemies.size(), immediate_danger)
	var target: Vector2 = lane["position"]
	var danger: float = lane["danger"]
	var move_vector := _vector_toward(player_pos, target, danger)
	command.move_vector = move_vector
	command.move_axis = move_vector.x
	command.bomb = _should_use_bomb(player, enemies, boss, immediate_danger, danger)
	return command


func _choose_intent_position(player: RefCounted, enemies: Array, boss: Dictionary, items: Array, danger: float) -> Vector2:
	if _should_chase_item(player, items, danger, enemies.size()):
		var item := _best_item(items, player)
		return Vector2(float(item.x), clampf(float(item.y), MIN_Y, MAX_Y))
	if not enemies.is_empty() or not boss.is_empty():
		return _best_attack_position(player, enemies, boss)
	return Vector2(player.x, player.y)


func _choose_lane(player: RefCounted, bullets: Array, enemies: Array, boss: Dictionary, items: Array, intent: Vector2, enemy_count: int, immediate_danger: float) -> Dictionary:
	var current := Vector2(player.x, player.y)
	var candidates := _candidate_positions(current, intent)
	var best_position := current
	var best_score := INF
	var best_danger := 0.0
	var held_score := INF
	var held_danger := INF
	for candidate in candidates:
		var position: Vector2 = candidate
		var danger := _path_danger(current, position, player, bullets, enemies, boss)
		var travel_cost := position.distance_to(current) * (0.001 if danger < 1.0 else 0.0024)
		var intent_cost := position.distance_to(intent) * (0.0044 if danger < 0.9 else 0.00035)
		var edge_cost := 0.2 if position.x < 86.0 or position.x > Config.W - 86.0 else 0.0
		edge_cost += 0.16 if position.y < MIN_Y + 28.0 or position.y > MAX_Y - 28.0 else 0.0
		var item_bonus := _item_lane_bonus(position, player, items, danger, enemy_count)
		var score := danger * 6.4 + travel_cost + intent_cost + edge_cost - item_bonus
		if position.distance_to(_held_target) < 2.0:
			held_score = score
			held_danger = danger
		if score < best_score:
			best_score = score
			best_position = position
			best_danger = danger

	var intent_is_stable := intent.distance_to(_held_intent) < 84.0
	var held_lane_is_safe := _hold_frames > 0 and held_score <= best_score + 0.32 and held_danger < 1.45
	if immediate_danger < 1.7 and intent_is_stable and held_lane_is_safe:
		_hold_frames -= 1
		return {"position": _held_target, "danger": held_danger}

	_held_target = best_position
	_held_intent = intent
	_hold_frames = LANE_HOLD_FRAMES
	return {"position": best_position, "danger": best_danger}


func _candidate_positions(current: Vector2, intent: Vector2) -> Array[Vector2]:
	var x_lanes: Array[float] = [
		MIN_X, 112.0, 192.0, 272.0, 352.0, 432.0, 512.0, 592.0,
		672.0, 752.0, 832.0, MAX_X,
		clampf(current.x, MIN_X, MAX_X),
		clampf(current.x - 126.0, MIN_X, MAX_X),
		clampf(current.x + 126.0, MIN_X, MAX_X),
		clampf(intent.x, MIN_X, MAX_X),
	]
	var y_lanes: Array[float] = [
		MIN_Y, MIN_Y + 82.0, MIN_Y + 168.0, MAX_Y - 92.0, MAX_Y,
		clampf(current.y, MIN_Y, MAX_Y),
		clampf(intent.y, MIN_Y, MAX_Y),
	]
	var positions: Array[Vector2] = []
	var seen_positions := {}
	for x in x_lanes:
		for y in y_lanes:
			var position := Vector2(x, y)
			if seen_positions.has(position):
				continue
			seen_positions[position] = true
			positions.append(position)
	return positions


func _path_danger(start: Vector2, target: Vector2, player: RefCounted, bullets: Array, enemies: Array, boss: Dictionary) -> float:
	var travel_time := maxf(absf(target.x - start.x) / 430.0, absf(target.y - start.y) / 360.0)
	travel_time = maxf(0.12, travel_time)
	var danger := _danger_at_position(target, player, bullets, enemies, boss) * 0.42
	for sample_time in PATH_SAMPLE_TIMES:
		var progress := clampf(sample_time / travel_time, 0.0, 1.0)
		var sample_position := start.lerp(target, progress)
		danger += _danger_at_time(sample_position, sample_time, enemies, boss, bullets) * (1.0 - sample_time * 0.28)
	return maxf(0.0, danger)


func _danger_at_time(test_pos: Vector2, horizon: float, enemies: Array, boss: Dictionary, bullets: Array) -> float:
	var danger := 0.0
	for bullet in bullets:
		if not bullet.enemy:
			continue
		var predicted := Vector2(float(bullet.x) + float(bullet.vx) * horizon, float(bullet.y) + float(bullet.vy) * horizon)
		var is_beam: bool = str(bullet.get("sprite", "")) == "beam"
		var radius := float(bullet.r) + (BOSS_BEAM_DANGER_WIDTH if is_beam else 42.0)
		var distance := predicted.distance_to(test_pos)
		if distance >= radius:
			continue
		var ratio := 1.0 - distance / radius
		danger += ratio * ratio * (3.1 if is_beam else 1.5) / (0.35 + horizon)

	for enemy in enemies:
		var predicted_enemy := Vector2(float(enemy.x), float(enemy.y))
		if float(enemy.get("dive", 0.0)) > 0.0:
			var frequency := 8.0 if str(enemy.get("kind", "")) == "zig" else 4.0
			predicted_enemy.y += 220.0 * horizon
			predicted_enemy.x += sin(float(enemy.get("t", 0.0)) * frequency + horizon * frequency) * 72.0 * horizon
		var radius_enemy := float(enemy.size) + (78.0 if float(enemy.get("dive", 0.0)) > 0.0 else 52.0)
		var enemy_distance := predicted_enemy.distance_to(test_pos)
		if enemy_distance < radius_enemy:
			danger += (1.0 - enemy_distance / radius_enemy) * (2.8 if float(enemy.get("dive", 0.0)) > 0.0 else 1.35)

	if not boss.is_empty() and float(boss.get("tell", 0.0)) > 0.0 and test_pos.y > float(boss.y):
		var lateral := absf(float(boss.x) - test_pos.x)
		if lateral < BOSS_TELL_DANGER_WIDTH:
			danger += 2.2 + (1.0 - lateral / BOSS_TELL_DANGER_WIDTH) * 2.0
	return danger


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
		if enemy.y < test_pos.y - 240.0:
			continue
		var enemy_distance := Vector2(float(enemy.x), float(enemy.y)).distance_to(test_pos)
		var radius_enemy: float = enemy.size + (88.0 if float(enemy.get("dive", 0.0)) > 0.0 else 74.0)
		if enemy_distance < radius_enemy:
			var weight_enemy: float = (1.0 - enemy_distance / radius_enemy) * (2.6 if float(enemy.get("dive", 0.0)) > 0.0 else 1.9)
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
	if items.is_empty() or danger > 1.1:
		return false
	var item := _best_item(items, player)
	var priority := _item_priority(item, player)
	var end_stage_pickup: bool = enemy_count <= 1 and item.y > player.y - 340.0
	var close_x: bool = absf(item.x - player.x) < (280.0 if priority >= 0.75 or end_stage_pickup else 190.0)
	return (priority >= 0.5 or end_stage_pickup) and close_x and item.y > player.y - 330.0 and item.y < player.y + 34.0


func _item_lane_bonus(test_pos: Vector2, player: RefCounted, items: Array, danger: float, enemy_count: int) -> float:
	if items.is_empty() or danger > 1.15:
		return 0.0
	var bonus := 0.0
	for item in items:
		if item.y < Config.HUD + 60.0 or item.y > MAX_Y + 44.0:
			continue
		var distance := Vector2(float(item.x), float(item.y)).distance_to(test_pos)
		if distance > 142.0:
			continue
		var priority := _item_priority(item, player)
		if enemy_count <= 1:
			priority += 0.2
		var approach := clampf(1.0 - distance / 142.0, 0.0, 1.0)
		var timing := clampf(1.0 - absf(item.y - player.y) / 300.0, 0.0, 1.0)
		bonus = maxf(bonus, priority * approach * (0.62 + timing * 0.48))
	return bonus


func _item_priority(item: Dictionary, player: RefCounted) -> float:
	match str(item.kind):
		"life":
			return 1.45 if player.lives <= 2 else 0.32
		"shield":
			return 1.2 if player.shield <= 0 else 0.44
		"bomb":
			return 0.86 if player.bombs <= 2 else 0.3
		"power":
			return 0.92 if int(player.chip_levels.power) < 3 else 0.48 if int(player.chip_levels.power) < 4 else 0.0
		"spread":
			return 0.82 if int(player.chip_levels.spread) < 3 else 0.42 if int(player.chip_levels.spread) < 4 else 0.0
		"resonance":
			return 0.72 if int(player.chip_levels.resonance) < 3 else 0.38 if int(player.chip_levels.resonance) < 4 else 0.0
	return 0.18


func _best_item(items: Array, player: RefCounted) -> Dictionary:
	var best: Dictionary = items[0]
	var best_score := INF
	for item in items:
		var distance := absf(item.x - player.x) + absf(item.y - player.y) * 0.42
		var falling_urgency := clampf((float(item.y) - Config.HUD) / Config.PLAY_H, 0.0, 1.0) * 48.0
		var score := distance - _item_priority(item, player) * 230.0 - falling_urgency
		if score < best_score:
			best_score = score
			best = item
	return best


func _best_attack_position(player: RefCounted, enemies: Array, boss: Dictionary) -> Vector2:
	if not boss.is_empty():
		var side := 1.0 if player.x >= float(boss.x) else -1.0
		return Vector2(clampf(float(boss.x) + side * 108.0, MIN_X, MAX_X), clampf(Config.PLAYER_Y - 62.0, MIN_Y, MAX_Y))
	if enemies.is_empty():
		return Vector2(player.x, player.y)

	var best: Dictionary = enemies[0]
	var best_score := INF
	for enemy in enemies:
		var vertical_bias: float = maxf(0.0, player.y - enemy.y) * 0.08
		var midboss_bonus := -90.0 if str(enemy.kind).begins_with("mid_") else 0.0
		var score := absf(enemy.x - player.x) - vertical_bias + midboss_bonus
		if score < best_score:
			best_score = score
			best = enemy
	var target_y := clampf(float(best.y) + (285.0 if str(best.kind).begins_with("mid_") else 250.0), MIN_Y, MAX_Y)
	return Vector2(clampf(float(best.x), MIN_X, MAX_X), target_y)


func _should_use_bomb(player: RefCounted, enemies: Array, boss: Dictionary, immediate_danger: float, lane_danger: float) -> bool:
	if not player.can_bomb():
		return false
	var is_midboss_fight: bool = enemies.any(func(enemy: Dictionary) -> bool: return str(enemy.kind).begins_with("mid_") and int(enemy.hp) > 0)
	var lethal_pressure := immediate_danger >= 4.4 or lane_danger >= 3.8
	if lethal_pressure:
		return true
	if boss.is_empty() and not is_midboss_fight:
		if player.bombs <= 1:
			return immediate_danger >= 3.5 and lane_danger >= 2.8
		return immediate_danger >= 2.9 or lane_danger >= 2.65
	if is_midboss_fight:
		return player.bombs >= 2 and (immediate_danger >= 2.35 or lane_danger >= 2.2)
	var boss_hp_ratio: float = float(boss.hp) / maxf(1.0, float(boss.max_hp))
	var boss_aligned: bool = absf(boss.x - player.x) < 205.0
	var boss_pressure: bool = boss.get("phase", 0) >= 1 or boss.get("tell", 0.0) > 0.0
	if boss_aligned and boss_pressure and player.bombs >= 2:
		return true
	if boss_aligned and boss_hp_ratio <= 0.32 and player.bombs >= 1:
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
	var scale := 48.0 if danger >= 1.0 else 92.0
	return (delta / scale).limit_length(1.0)
