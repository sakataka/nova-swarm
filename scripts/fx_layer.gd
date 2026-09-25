extends Node2D
class_name FxLayer

# Additive light pass drawn between the world and the UI.
# Visual randomness uses its own RNG so gameplay seeds stay deterministic.

const Config := preload("res://scripts/game_config.gd")
const MAX_SPARKS := 420
const MAX_DEBRIS := 140

var game: Node2D
var glow_texture: Texture2D
var sparks: Array[Dictionary] = []
var rings: Array[Dictionary] = []
var glows: Array[Dictionary] = []
var debris: Array[Dictionary] = []
var popups: Array[Dictionary] = []
var bolts: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()


func _init() -> void:
	name = "FxLayer"
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	rng.seed = 7331
	glow_texture = _make_glow_texture()


func clear() -> void:
	sparks.clear()
	rings.clear()
	glows.clear()
	debris.clear()
	popups.clear()
	bolts.clear()


func update(dt: float) -> void:
	for spark in sparks:
		spark.t += dt
		spark.p += spark.v * dt
		spark.v *= pow(spark.drag, dt * 60.0)
	sparks = sparks.filter(func(spark: Dictionary) -> bool: return spark.t < spark.life)
	for ring in rings:
		ring.t += dt
	rings = rings.filter(func(ring: Dictionary) -> bool: return ring.t < ring.life)
	for glow in glows:
		glow.t += dt
	glows = glows.filter(func(glow: Dictionary) -> bool: return glow.t < glow.life)
	for chunk in debris:
		chunk.t += dt
		chunk.p += chunk.v * dt
		chunk.v *= pow(0.96, dt * 60.0)
		chunk.rot += chunk.spin * dt
	debris = debris.filter(func(chunk: Dictionary) -> bool: return chunk.t < chunk.life)
	for popup in popups:
		popup.t += dt
		popup.p.y -= 34.0 * dt
	popups = popups.filter(func(popup: Dictionary) -> bool: return popup.t < popup.life)
	for bolt in bolts:
		bolt.t += dt
	bolts = bolts.filter(func(bolt: Dictionary) -> bool: return bolt.t < bolt.life)


func burst(position: Vector2, color: Color, count: int, speed: float, life := 0.42, size := 2.0) -> void:
	for i in range(count):
		if sparks.size() >= MAX_SPARKS:
			sparks.pop_front()
		var angle := rng.randf() * TAU
		var velocity := Vector2(cos(angle), sin(angle)) * speed * rng.randf_range(0.35, 1.0)
		sparks.append({"p": position, "v": velocity, "t": 0.0, "life": life * rng.randf_range(0.6, 1.15), "color": color, "size": size, "drag": 0.9})


func directional_sparks(position: Vector2, direction: Vector2, color: Color, count: int, speed: float, spread := 0.7) -> void:
	var base := direction.angle()
	for i in range(count):
		if sparks.size() >= MAX_SPARKS:
			sparks.pop_front()
		var angle := base + rng.randf_range(-spread, spread)
		var velocity := Vector2(cos(angle), sin(angle)) * speed * rng.randf_range(0.4, 1.0)
		sparks.append({"p": position, "v": velocity, "t": 0.0, "life": rng.randf_range(0.14, 0.3), "color": color, "size": 1.6, "drag": 0.86})


func ring(position: Vector2, color: Color, radius: float, life := 0.36, width := 3.0, start_radius := 6.0) -> void:
	rings.append({"p": position, "color": color, "r0": start_radius, "r1": radius, "t": 0.0, "life": life, "w": width})


func flash_glow(position: Vector2, color: Color, size: float, life := 0.22) -> void:
	glows.append({"p": position, "color": color, "size": size, "t": 0.0, "life": life})


func shatter(position: Vector2, count: int, speed: float, scale := 1.0) -> void:
	for i in range(count):
		if debris.size() >= MAX_DEBRIS:
			debris.pop_front()
		var angle := rng.randf() * TAU
		var velocity := Vector2(cos(angle), sin(angle)) * speed * rng.randf_range(0.3, 1.0)
		debris.append({
			"p": position + velocity.normalized() * rng.randf_range(0.0, 10.0) * scale,
			"v": velocity,
			"t": 0.0,
			"life": rng.randf_range(0.5, 0.95),
			"rot": rng.randf() * TAU,
			"spin": rng.randf_range(-9.0, 9.0),
			"size": rng.randf_range(3.0, 7.5) * scale,
			"hot": rng.randf() < 0.45,
		})


func popup(position: Vector2, text: String, color: Color, size := 18, life := 0.9) -> void:
	if popups.size() > 10:
		popups.pop_front()
	popups.append({"p": position, "text": text, "color": color, "size": size, "t": 0.0, "life": life})


func bolt(from: Vector2, to: Vector2, color: Color, life := 0.26, width := 3.0) -> void:
	var points := PackedVector2Array()
	var steps := 6
	var normal := (to - from).orthogonal().normalized()
	for i in range(steps + 1):
		var ratio := float(i) / float(steps)
		var jitter := 0.0 if i == 0 or i == steps else rng.randf_range(-9.0, 9.0)
		points.append(from.lerp(to, ratio) + normal * jitter)
	bolts.append({"points": points, "color": color, "t": 0.0, "life": life, "w": width})


func glow(position: Vector2, color: Color, size: float) -> void:
	draw_texture_rect(glow_texture, Rect2(position - Vector2.ONE * size * 0.5, Vector2.ONE * size), false, color)


func glow_stretched(position: Vector2, color: Color, size: Vector2) -> void:
	draw_texture_rect(glow_texture, Rect2(position - size * 0.5, size), false, color)


func _draw() -> void:
	if game == null:
		return
	if game.has_method("draw_light_pass"):
		game.draw_light_pass(self)
	for g in glows:
		var ratio: float = g.t / g.life
		glow(g.p, Color(g.color, (1.0 - ratio) * g.color.a), g.size * (0.7 + ratio * 0.5))
	for r in rings:
		var ratio: float = r.t / r.life
		var eased := 1.0 - pow(1.0 - ratio, 3.0)
		var radius: float = lerpf(r.r0, r.r1, eased)
		draw_arc(r.p, radius, 0.0, TAU, 48, Color(r.color, (1.0 - ratio) * r.color.a), r.w * (1.0 - ratio * 0.6), true)
	for b in bolts:
		var ratio: float = b.t / b.life
		var alpha := 1.0 - ratio
		draw_polyline(b.points, Color(b.color, alpha * 0.35), b.w * 3.2, true)
		draw_polyline(b.points, Color(1, 1, 1, alpha * 0.9), b.w * 0.7, true)
	for s in sparks:
		var ratio: float = s.t / s.life
		var tail: Vector2 = s.v * 0.035
		draw_line(s.p - tail, s.p, Color(s.color, 1.0 - ratio), s.size, true)


func draw_debris(canvas: CanvasItem) -> void:
	for chunk in debris:
		var ratio: float = chunk.t / chunk.life
		var half: float = chunk.size * 0.5
		var dir := Vector2(cos(chunk.rot), sin(chunk.rot))
		var side := dir.orthogonal() * 0.62
		var points := PackedVector2Array([
			chunk.p + dir * half,
			chunk.p + side * half,
			chunk.p - dir * half * 0.8,
			chunk.p - side * half * 1.1,
		])
		var color := Color("#ff8a3d") if chunk.hot and ratio < 0.5 else Color(0.2, 0.17, 0.16)
		canvas.draw_colored_polygon(points, Color(color, 1.0 - ratio * ratio))


func draw_popups(canvas: CanvasItem, font: Font, xform: Transform2D) -> void:
	if font == null:
		return
	for p in popups:
		var ratio: float = p.t / p.life
		var alpha := 1.0 - maxf(0.0, ratio - 0.55) / 0.45
		var pop := 1.0 + maxf(0.0, 0.12 - p.t) * 3.0
		var size := int(float(p.size) * pop)
		var pos: Vector2 = xform * p.p
		var width := font.get_string_size(p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var origin := Vector2(pos.x - width * 0.5, pos.y)
		canvas.draw_string(font, origin + Vector2(2, 2), p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.6 * alpha))
		canvas.draw_string(font, origin, p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(p.color, alpha))


func _make_glow_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.18, 0.5, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.62), Color(1, 1, 1, 0.16), Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	return texture
