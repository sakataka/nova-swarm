extends RefCounted
class_name EnemySwarm

const Config := preload("res://scripts/game_config.gd")

var enemies: Array[Dictionary] = []
var swarm_dir := 1.0
var next_id := 1
var width := 960.0
var hud_y := 76.0


func setup(play_width: float, hud_height: float) -> void:
	width = play_width
	hud_y = hud_height


func clear() -> void:
	enemies.clear()
	swarm_dir = 1.0


func load_stage(stage_data: Dictionary, enemy_stats: Dictionary, difficulty: float, wave_index := 0) -> void:
	clear()
	var start_x := 148.0
	var start_y := hud_y + 128.0
	var gap_x := 84.0
	var gap_y := 58.0
	var commander_y := hud_y + 64.0
	var is_midboss_wave: bool = int(stage_data.get("midbosses", 0)) > 0 and wave_index >= int(stage_data.get("waves", 1)) - 1
	var row_count: int = 0 if is_midboss_wave else int(stage_data.rows)
	for row in range(row_count):
		for col in range(stage_data.cols):
			var kind: String = stage_data.kinds[(row + col + wave_index) % stage_data.kinds.size()]
			var stats: Dictionary = enemy_stats[kind]
			var x := start_x + col * gap_x
			var y := start_y + row * gap_y
			enemies.append({
				"id": next_id,
				"kind": kind,
				"x": x,
				"y": y,
				"base_x": x,
				"base_y": y,
				"hp": int(stats.hp) + wave_index / 2,
				"max_hp": int(stats.hp) + wave_index / 2,
				"t": randf() * 10.0,
				"dive": 0.0,
				"shoot": maxf(0.35, (0.8 + randf() * 2.2) / difficulty),
				"score": int(stats.score),
				"size": float(stats.size),
			})
			next_id += 1
	if is_midboss_wave:
		_spawn_midbosses(int(stage_data.midbosses), enemy_stats, difficulty)
	elif stage_data.rows > 0 and wave_index >= int(stage_data.get("waves", 1)) - 1:
		var stats: Dictionary = enemy_stats["commander"]
		enemies.append({
			"id": next_id,
			"kind": "commander",
			"x": width / 2.0,
			"y": commander_y,
			"base_x": width / 2.0,
			"base_y": commander_y,
			"hp": int(stats.hp) + int(difficulty),
			"max_hp": int(stats.hp) + int(difficulty),
			"t": randf() * 10.0,
			"dive": 0.0,
			"shoot": maxf(0.45, 1.15 / difficulty),
			"score": int(stats.score),
			"size": float(stats.size),
		})
		next_id += 1


func _spawn_midbosses(count: int, enemy_stats: Dictionary, difficulty: float) -> void:
	var kinds := ["mid_lancer", "mid_orbit", "mid_anchor"]
	for i in range(count):
		var kind: String = kinds[i]
		var stats: Dictionary = enemy_stats[kind]
		var x := width * (float(i + 1) / float(count + 1))
		var hp_scale := 1.0 + maxf(0.0, difficulty - 1.0) * 0.55
		var hp := int(round(float(stats.hp) * hp_scale))
		enemies.append({
			"id": next_id,
			"kind": kind,
			"x": x,
			"y": hud_y + 142.0 + float(i % 2) * 42.0,
			"base_x": x,
			"base_y": hud_y + 142.0 + float(i % 2) * 42.0,
			"hp": hp,
			"max_hp": hp,
			"t": randf() * 8.0,
			"dive": 0.0,
			"shoot": 0.8 + float(i) * 0.2,
			"score": int(stats.score),
			"size": float(stats.size),
		})
		next_id += 1


func update(dt: float, stage_data: Dictionary, stage_index: int, stage_timer: float, difficulty: float, player_x: float, projectiles: RefCounted, enemy_stats: Dictionary) -> void:
	if enemies.is_empty():
		return
	var edge := false
	var commander_alive := false
	for enemy in enemies:
		if enemy.dive <= 0.0 and enemy.kind != "commander" and (enemy.x < 54.0 or enemy.x > width - 54.0):
			edge = true
		if enemy.kind == "commander" and enemy.hp > 0:
			commander_alive = true
		if edge and commander_alive:
			break
	if edge:
		swarm_dir *= -1.0
	var command_fire_mult := 1.22 if commander_alive else 1.0
	var command_dive_mult := 1.28 if commander_alive else 1.0

	for enemy in enemies:
		enemy.t += dt
		var is_commander: bool = enemy.kind == "commander"
		var is_midboss: bool = enemy.kind in ["mid_lancer", "mid_orbit", "mid_anchor"]
		if is_midboss:
			var slot_offset := -1.0 if enemy.kind == "mid_lancer" else 1.0 if enemy.kind == "mid_orbit" else 0.0
			enemy.x = enemy.base_x + sin(enemy.t * (0.72 + absf(slot_offset) * 0.12)) * (72.0 if enemy.kind != "mid_anchor" else 46.0)
			enemy.y = enemy.base_y + sin(enemy.t * 1.35 + enemy.id) * 22.0
		elif enemy.dive <= 0.0 and not is_commander and randf() < stage_data.dive * difficulty * command_dive_mult * dt * 0.035:
			enemy.dive = 1.0
		if enemy.dive > 0.0:
			enemy.y += (120.0 + stage_index * 24.0) * dt
			enemy.x += sin(enemy.t * (8.0 if enemy.kind == "zig" else 4.0)) * 160.0 * dt
			if enemy.y > Config.H + 40.0:
				enemy.y = hud_y + 50.0
				enemy.x = enemy.base_x
				enemy.dive = 0.0
		elif is_commander:
			enemy.x = enemy.base_x + sin(stage_timer * 1.15 + enemy.id) * 82.0
			enemy.y = enemy.base_y + sin(stage_timer * 1.85 + enemy.id) * 12.0
		else:
			enemy.x += swarm_dir * stage_data.speed * difficulty * dt
			enemy.y = enemy.base_y + sin(stage_timer * 1.6 + enemy.id) * 9.0

		enemy.shoot -= dt
		if enemy.shoot <= 0.0:
			if is_midboss and _midboss_is_resting(enemy, stage_timer):
				enemy.shoot = 0.35
				continue
			var kind_mult := 1.7 if enemy.kind == "saucer" else 1.45 if is_commander else 1.18 if is_midboss else 1.0
			var chance: float = stage_data.fire * difficulty * command_fire_mult * kind_mult
			enemy.shoot = 1.2 + (randf() * 3.4 / maxf(0.55, chance))
			if is_commander or is_midboss:
				projectiles.fire_enemy(enemy, player_x, enemy_stats)
			elif randf() < 0.2 + stage_index * 0.035 or enemy.dive > 0.0:
				projectiles.fire_enemy(enemy, player_x, enemy_stats)


func _midboss_is_resting(enemy: Dictionary, stage_timer: float) -> bool:
	var active_midbosses := enemies.filter(func(candidate: Dictionary) -> bool: return candidate.kind in ["mid_lancer", "mid_orbit", "mid_anchor"] and candidate.hp > 0)
	if active_midbosses.size() < 3:
		return false
	var resting_index := int(stage_timer / 3.0) % active_midbosses.size()
	return int(active_midbosses[resting_index].id) == int(enemy.id)


func remove_dead() -> void:
	enemies = enemies.filter(func(enemy: Dictionary) -> bool: return enemy.hp > 0)
