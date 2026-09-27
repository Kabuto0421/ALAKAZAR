extends RefCounted

func apply(model: RefCounted, cell: Vector2i, direction: Vector2i) -> void:
	model.strike_under(cell, "bolt", direction)
	# The upgraded bolt fires both ways along the chosen line.
	var directions: Array = [direction, -direction] if model.is_plus("magic_bolt") else [direction]
	for aim: Vector2i in directions:
		for target in model.ray_cells(cell, aim):
			model.events.append({"kind": "bolt", "cell": target, "id": -2, "dir": aim})
			var enemy: Dictionary = model.enemy_at(target)
			if not enemy.is_empty():
				model.damage_enemy(enemy, 1, aim)
