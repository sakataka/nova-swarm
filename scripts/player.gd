extends RefCounted
class_name NovaPlayer

var x := 480.0
var y := 662.0
var lives := 3
var bombs := 3
var invuln := 0.0
var shot_cd := 0.0
var bomb_cd := 0.0
var combo := 0
var combo_timer := 0.0
var no_miss_stage := true

var _min_x := 42.0
var _max_x := 918.0


func setup(start_x: float, start_y: float, min_x: float, max_x: float) -> void:
	x = start_x
	y = start_y
	_min_x = min_x
	_max_x = max_x


func reset_run(start_x: float) -> void:
	x = start_x
	lives = 3
	bombs = 3
	invuln = 0.0
	shot_cd = 0.0
	bomb_cd = 0.0
	combo = 0
	combo_timer = 0.0
	no_miss_stage = true


func start_stage(start_x: float) -> void:
	x = start_x
	invuln = 1.4
	shot_cd = 0.0
	bomb_cd = 0.0
	combo = 0
	combo_timer = 0.0
	no_miss_stage = true


func update(dt: float, move_axis: float) -> void:
	invuln = maxf(0.0, invuln - dt)
	shot_cd = maxf(0.0, shot_cd - dt)
	bomb_cd = maxf(0.0, bomb_cd - dt)
	combo_timer = maxf(0.0, combo_timer - dt)
	if combo_timer <= 0.0:
		combo = 0
	x = clampf(x + move_axis * 430.0 * dt, _min_x, _max_x)


func can_shoot() -> bool:
	return shot_cd <= 0.0


func mark_shot() -> void:
	shot_cd = 0.14


func can_bomb() -> bool:
	return bombs > 0 and bomb_cd <= 0.0


func consume_bomb() -> void:
	bomb_cd = 0.85
	bombs -= 1


func register_kill() -> float:
	combo += 1
	combo_timer = 2.2
	return 1.0 + minf(1.0, float(combo - 1) * 0.08)


func hurt() -> bool:
	lives -= 1
	invuln = 1.8
	combo = 0
	combo_timer = 0.0
	no_miss_stage = false
	return lives <= 0
