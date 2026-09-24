extends RefCounted

const DIRECTIONS = [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]

func decide(model: RefCounted, enemy: Dictionary) -> Dictionary:
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
			if first_steps.has(next) or not model.inside(next) or model.blocked(next):
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
