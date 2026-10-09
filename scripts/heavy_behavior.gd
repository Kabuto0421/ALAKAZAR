extends RefCounted

const DIRECTIONS = [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]

## A heavy soldier (or executioner) that is level with a player it cannot reach yet would trudge along the row forever
## (and a player who keeps stepping away is never caught). When it is off the player's row it
## sometimes steps up or down towards that row instead, chosen from the fight's own seed so
## look-ahead copies agree.
## Per kind: the AP-1 walkers (heavy, analyst, shield) 50%, the executioner (same walk, AP 2) 30%.
const SIDESTEP_CHANCES := {"heavy": 0.5, "executioner": 0.3, "analyst": 0.5, "shield": 0.5}

func decide(model: RefCounted, enemy: Dictionary) -> Dictionary:
	var side := _sidestep(model, enemy)
	if side != enemy.cell:
		return {"kind": "step", "cell": side}
	var start: Vector2i = enemy.cell
	var target: Vector2i = model.player.cell
	var queue: Array[Vector2i] = [start]
	var first_steps: Dictionary = {start: start}
	var nearest: Vector2i = start
	var head := 0
	# Breadth-first search ignores danger; only occupied or blocked tiles stop movement.
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		for direction in DIRECTIONS:
			var next: Vector2i = current+direction
			if first_steps.has(next) or not model.inside(next) or (model.enemy_blocked(next) and next != target):
				continue
			if not model.enemy_at(next).is_empty():
				continue
			first_steps[next] = next if current == start else first_steps[current]
			if next == target:
				return {"kind": "step", "cell": first_steps[next]}
			queue.append(next)
			if model.distance(next,target) < model.distance(nearest,target):
				nearest = next
	# If the player is enclosed, advance to the nearest reachable tile.
	if nearest != start:
		return {"kind": "step", "cell": first_steps[nearest]}
	return {"kind": "wait"}

## How many steps the shortest walk to `target` takes (-1 when it cannot be reached; other enemies and
## obstacles in the way count, mines do not).
func walk_length(model: RefCounted, from_cell: Vector2i, target: Vector2i) -> int:
	var depth := {from_cell: 0}
	var queue: Array[Vector2i] = [from_cell]
	var head := 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		for direction in DIRECTIONS:
			var next: Vector2i = current + direction
			if depth.has(next) or not model.inside(next):
				continue
			if next == target:
				return int(depth[current]) + 1
			if model.enemy_blocked(next) or not model.enemy_at(next).is_empty():
				continue
			depth[next] = int(depth[current]) + 1
			queue.append(next)
	return -1

## The tile a heavy soldier or executioner sidesteps to this beat (towards the player's row), or its own tile for none.
func _sidestep(model: RefCounted, enemy: Dictionary) -> Vector2i:
	var chance: float = SIDESTEP_CHANCES.get(enemy.type, 0.0)
	if chance <= 0.0:
		return enemy.cell
	var rows: int = model.player.cell.y - enemy.cell.y
	if rows == 0:
		return enemy.cell
	var roll := RandomNumberGenerator.new()
	roll.seed = hash([model.slot_seed, model.round_number, int(enemy.id), "sidestep"])
	if roll.randf() >= chance:
		return enemy.cell
	var cell: Vector2i = enemy.cell + Vector2i(0, signi(rows))
	if model.inside(cell) and not model.enemy_blocked(cell) and model.enemy_at(cell).is_empty() and cell != model.player.cell:
		return cell
	return enemy.cell
