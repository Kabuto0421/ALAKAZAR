extends RefCounted

const APPROACH = "approach"
const ENCIRCLE = "encircle"
const CHARGE = "charge"
const DIRECTIONS = [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]

# Decisions are read-only. The planner applies state requests and the model
# resolves movement, AP, damage and mines.
func decide(model: RefCounted, enemy: Dictionary, staging: Dictionary) -> Dictionary:
	if enemy.ap <= 0:
		return {"kind": "wait"}
	var charging: bool = enemy.state == CHARGE and model.round_number >= enemy.charge_round
	if model.distance(enemy.cell, model.player.cell) == 1:
		return {"kind": "step", "cell": model.player.cell}
	var options: Array[Vector2i] = []
	var distance: int = model.distance(enemy.cell, model.player.cell)
	for direction in DIRECTIONS:
		var cell: Vector2i = enemy.cell + direction
		if model.inside(cell) and not model.blocked(cell) and cell != model.player.cell and model.enemy_at(cell).is_empty() and model.distance(cell, model.player.cell) < distance:
			options.append(cell)
	var target: Vector2i = staging.get(enemy.id, enemy.cell)
	# Safe progress takes precedence over staging assignments and crowding.
	# Announced charges may still enter weapon range to reach the player.
	var safe: Array[Vector2i] = []
	var threat: Array = model.targets()
	for cell in options:
		if not threat.has(cell) and not model.mines.has(cell):
			safe.append(cell)
	if not charging and not safe.is_empty():
		safe.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return score(model, enemy, a, target) < score(model, enemy, b, target))
		return {"kind": "step", "cell": safe[0]}
	# A reachable attack takes priority over waiting for a charge announcement.
	# Leave one AP for the hit, and do not route HP1 infantry through a mine.
	if distance == 2 and enemy.ap >= 2:
		var attack_steps: Array[Vector2i] = options.filter(func(cell: Vector2i) -> bool: return not model.mines.has(cell))
		attack_steps.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return score(model, enemy, a, target, charging) < score(model, enemy, b, target, charging))
		if not attack_steps.is_empty():
			return {"kind": "step", "cell": attack_steps[0]}
	options.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return score(model, enemy, a, target, charging) < score(model, enemy, b, target, charging))
	if not options.is_empty():
		var improves: bool = score(model, enemy, options[0], target, charging) < score(model, enemy, enemy.cell, target, charging)
		if improves:
			return {"kind": "step", "cell": options[0]}
	return {"kind": "wait"}

func score(model: RefCounted, enemy: Dictionary, cell: Vector2i, target: Vector2i, charging: bool = false) -> int:
	var result: int = (model.distance(cell, model.player.cell) if charging else model.distance(cell, target)) * 10
	if not charging and model.targets().has(cell):
		result += 20
	if model.mines.has(cell):
		result += 25
	for other in model.enemies:
		if other.id != enemy.id and model.distance(other.cell, cell) == 1:
			result += 5
	return result

func finish_request(model: RefCounted, enemy: Dictionary, nearby: int, total: int) -> Dictionary:
	var near: bool = model.distance(enemy.cell, model.player.cell) <= 2
	var waited := 0
	if near:
		waited = (0 if enemy.state == CHARGE else int(enemy.wait)) + 1
	if near and (nearby >= 2 or total == 1 or waited >= 2):
		return {"state": CHARGE, "wait": 0, "charge_round": model.round_number + 1, "intent": "突撃予告"}
	return {"state": ENCIRCLE if near else APPROACH, "wait": waited, "charge_round": -1, "intent": "包囲" if near else "接近"}
