extends RefCounted

func apply(model: RefCounted, cell: Vector2i, direction: Vector2i) -> void:
	for target in model.ray_cells(cell, direction):
		model.events.append({"kind": "bolt", "cell": target, "id": -2})
		var enemy: Dictionary = model.enemy_at(target)
		if not enemy.is_empty():
			model.damage_enemy(enemy, 1)
