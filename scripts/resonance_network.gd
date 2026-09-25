extends RefCounted
class_name ResonanceNetwork

# The enemy fleet shares its reactors through resonance links.
# Destroying a node sends a surge along its links; surges that destroy the next
# node keep travelling, so the order of targets decides how far a chain spreads.

const SURGE_HOP_TIME := 0.09
# Links stretched beyond this range (e.g. a node returning from a dive) carry no resonance.
const LINK_RANGE := 230.0

var links: Array[Dictionary] = []
var surges: Array[Dictionary] = []
var next_chain_id := 1
var chains: Dictionary = {}


func clear() -> void:
	links.clear()
	surges.clear()
	chains.clear()


func build(enemies: Array) -> void:
	clear()
	var by_cell := {}
	var commander: Dictionary = {}
	var midbosses: Array[Dictionary] = []
	for enemy in enemies:
		if str(enemy.kind) == "commander":
			commander = enemy
		elif str(enemy.kind).begins_with("mid_"):
			midbosses.append(enemy)
		elif enemy.has("row") and enemy.has("col"):
			by_cell[Vector2i(int(enemy.col), int(enemy.row))] = enemy
	for cell in by_cell.keys():
		var enemy: Dictionary = by_cell[cell]
		for offset in [Vector2i(1, 0), Vector2i(0, 1)]:
			var neighbor_cell: Vector2i = cell + offset
			if by_cell.has(neighbor_cell):
				_add_link(enemy, by_cell[neighbor_cell], "grid")
	if not commander.is_empty():
		# The commander is the hub: it links to the nearest nodes of the top row.
		var top_row := by_cell.keys().filter(func(cell: Vector2i) -> bool: return cell.y == 0)
		top_row.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return absf(float(by_cell[a].x) - float(commander.x)) < absf(float(by_cell[b].x) - float(commander.x)))
		for i in range(mini(4, top_row.size())):
			_add_link(commander, by_cell[top_row[i]], "hub")
	for i in range(midbosses.size()):
		for j in range(i + 1, midbosses.size()):
			_add_link(midbosses[i], midbosses[j], "tether")


func _add_link(a: Dictionary, b: Dictionary, kind: String) -> void:
	links.append({"a": int(a.id), "b": int(b.id), "kind": kind})


static func index_enemies(enemies: Array) -> Dictionary:
	var by_id := {}
	for enemy in enemies:
		by_id[int(enemy.id)] = enemy
	return by_id


static func is_node_live(enemy: Variant) -> bool:
	return enemy != null and int(enemy.hp) > 0 and float(enemy.get("dive", 0.0)) <= 0.0


func active_links(by_id: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for link in links:
		if _link_live(link, by_id.get(link.a), by_id.get(link.b)):
			result.append(link)
	return result


static func _link_live(link: Dictionary, a: Variant, b: Variant) -> bool:
	if not is_node_live(a) or not is_node_live(b):
		return false
	var range_limit := LINK_RANGE * (2.2 if str(link.kind) != "grid" else 1.0)
	return Vector2(a.x, a.y).distance_to(Vector2(b.x, b.y)) <= range_limit


func neighbors(enemy_id: int, by_id: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for link in links:
		var other_id := -1
		if int(link.a) == enemy_id:
			other_id = int(link.b)
		elif int(link.b) == enemy_id:
			other_id = int(link.a)
		if other_id == -1:
			continue
		var other: Variant = by_id.get(other_id)
		# The source may already be destroyed; only its position matters for range.
		var source: Variant = by_id.get(enemy_id)
		if not is_node_live(other) or source == null:
			continue
		var range_limit := LINK_RANGE * (2.2 if str(link.kind) != "grid" else 1.0)
		if Vector2(source.x, source.y).distance_to(Vector2(other.x, other.y)) <= range_limit:
			result.append(other)
	return result


func remove_node(enemy_id: int) -> void:
	links = links.filter(func(link: Dictionary) -> bool: return int(link.a) != enemy_id and int(link.b) != enemy_id)


# Commander destroyed: every networked node takes a surge, arriving as a wave, and all links drop.
func collapse(source: Dictionary, chain_id: int, by_id: Dictionary) -> int:
	var ids := {}
	for link in links:
		ids[int(link.a)] = true
		ids[int(link.b)] = true
	ids.erase(int(source.id))
	var origin := Vector2(source.x, source.y)
	var sent := 0
	for enemy_id in ids.keys():
		var target: Variant = by_id.get(enemy_id)
		if target == null or int(target.hp) <= 0:
			continue
		var distance := origin.distance_to(Vector2(target.x, target.y))
		surges.append({"from": origin, "to_id": int(enemy_id), "t": -distance / 1500.0, "power": 1, "hops_left": 0, "chain_id": chain_id, "collapse": true})
		sent += 1
	links.clear()
	return sent


func start_chain(origin: Vector2) -> int:
	var chain_id := next_chain_id
	next_chain_id += 1
	chains[chain_id] = {"count": 1, "origin": origin, "t": 0.0}
	return chain_id


# Queues surges from `source` (already destroyed) into its live neighbors.
func emit(source: Dictionary, power: int, hops_left: int, chain_id: int, by_id: Dictionary) -> int:
	if hops_left <= 0:
		return 0
	var sent := 0
	for other in neighbors(int(source.id), by_id):
		surges.append({
			"from": Vector2(source.x, source.y),
			"to_id": int(other.id),
			"t": 0.0,
			"power": power,
			"hops_left": hops_left - 1,
			"chain_id": chain_id,
		})
		sent += 1
	remove_node(int(source.id))
	return sent


# Advances surges and returns the ones that reached their target this frame.
func update(dt: float) -> Array[Dictionary]:
	var arrived: Array[Dictionary] = []
	var travelling: Array[Dictionary] = []
	for surge in surges:
		surge.t += dt
		if surge.t >= SURGE_HOP_TIME:
			arrived.append(surge)
		else:
			travelling.append(surge)
	surges = travelling
	for chain_id in chains.keys():
		chains[chain_id].t += dt
	for chain_id in chains.keys():
		if chains[chain_id].t > 2.0 and not surges.any(func(surge: Dictionary) -> bool: return int(surge.chain_id) == int(chain_id)):
			chains.erase(chain_id)
	return arrived


func register_chain_kill(chain_id: int) -> int:
	if not chains.has(chain_id):
		return 1
	chains[chain_id].count += 1
	chains[chain_id].t = 0.0
	return int(chains[chain_id].count)


# How many live neighbors a kill on `enemy` would finish with a surge of `power`.
func chain_value(enemy: Dictionary, power: int, by_id: Dictionary) -> int:
	var value := 0
	for other in neighbors(int(enemy.id), by_id):
		if int(other.hp) <= power:
			value += 1
	return value
