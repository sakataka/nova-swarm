extends RefCounted
class_name NovaPlayer

var x := 480.0
var y := 662.0
var lives := 3
var bombs := 3
var shield := 0
var invuln := 0.0
var shot_cd := 0.0
var bomb_cd := 0.0
var combo := 0
var combo_timer := 0.0
var no_miss_stage := true
var resonance := 0.0
var overdrive_timer := 0.0
var shot_cooldown_scale := 1.0
var overdrive_duration_bonus := 0.0
var resonance_gain_scale := 1.0
var shield_max := 2
var shot_pattern := "twin"
var graze_chain_bonus := false
var bomb_refund_chance := 0.0
var shield_retaliate := false
var close_kill_extend := false

var _min_x := 42.0
var _max_x := 918.0
var _min_y := 282.0
var _max_y := 676.0

const RESONANCE_MAX := 100.0
const OVERDRIVE_DURATION := 5.0


func setup(start_x: float, start_y: float, min_x: float, max_x: float, min_y: float, max_y: float) -> void:
	x = start_x
	y = start_y
	_min_x = min_x
	_max_x = max_x
	_min_y = min_y
	_max_y = max_y


func reset_run(start_x: float, start_y: float) -> void:
	x = start_x
	y = start_y
	lives = 3
	bombs = 3
	shield = 0
	invuln = 0.0
	shot_cd = 0.0
	bomb_cd = 0.0
	combo = 0
	combo_timer = 0.0
	no_miss_stage = true
	resonance = 0.0
	overdrive_timer = 0.0
	reset_upgrade_modifiers()


func start_stage(start_x: float, start_y: float) -> void:
	x = start_x
	y = start_y
	invuln = 1.4
	shot_cd = 0.0
	bomb_cd = 0.0
	combo = 0
	combo_timer = 0.0
	no_miss_stage = true
	overdrive_timer = 0.0


func update(dt: float, move_vector: Vector2) -> void:
	invuln = maxf(0.0, invuln - dt)
	shot_cd = maxf(0.0, shot_cd - dt)
	bomb_cd = maxf(0.0, bomb_cd - dt)
	combo_timer = maxf(0.0, combo_timer - dt)
	overdrive_timer = maxf(0.0, overdrive_timer - dt)
	if combo_timer <= 0.0:
		combo = 0
	var input := move_vector.limit_length(1.0)
	x = clampf(x + input.x * 430.0 * dt, _min_x, _max_x)
	y = clampf(y + input.y * 360.0 * dt, _min_y, _max_y)


func can_shoot() -> bool:
	return shot_cd <= 0.0


func mark_shot() -> void:
	shot_cd = (0.08 if is_overdrive_active() else 0.14) * shot_cooldown_scale


func can_bomb() -> bool:
	return bombs > 0 and bomb_cd <= 0.0


func consume_bomb() -> void:
	bomb_cd = 0.85
	bombs -= 1


func can_overdrive() -> bool:
	return resonance >= RESONANCE_MAX and overdrive_timer <= 0.0


func start_overdrive() -> void:
	resonance = 0.0
	overdrive_timer = get_overdrive_duration()
	shot_cd = minf(shot_cd, 0.04)


func add_resonance(amount: float) -> void:
	if overdrive_timer > 0.0:
		return
	resonance = clampf(resonance + amount * resonance_gain_scale, 0.0, RESONANCE_MAX)


func is_overdrive_active() -> bool:
	return overdrive_timer > 0.0


func register_kill() -> float:
	combo += 1
	combo_timer = 2.2
	return 1.0 + minf(1.0, float(combo - 1) * 0.08)


func hurt() -> bool:
	if shield > 0:
		shield -= 1
		invuln = 1.0
		combo = 0
		combo_timer = 0.0
		overdrive_timer = 0.0
		no_miss_stage = false
		return false
	lives -= 1
	invuln = 1.8
	combo = 0
	combo_timer = 0.0
	overdrive_timer = 0.0
	no_miss_stage = false
	return lives <= 0


func apply_item(item_kind: String) -> void:
	if item_kind == "life":
		lives = mini(5, lives + 1)
	elif item_kind == "bomb":
		bombs = mini(5, bombs + 1)
	elif item_kind == "shield":
		shield = mini(shield_max, shield + 1)


func get_overdrive_duration() -> float:
	return OVERDRIVE_DURATION + overdrive_duration_bonus


func reset_upgrade_modifiers() -> void:
	shot_cooldown_scale = 1.0
	overdrive_duration_bonus = 0.0
	resonance_gain_scale = 1.0
	shield_max = 2
	shot_pattern = "twin"
	graze_chain_bonus = false
	bomb_refund_chance = 0.0
	shield_retaliate = false
	close_kill_extend = false
