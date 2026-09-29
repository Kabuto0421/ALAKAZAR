extends RefCounted

func apply(model: RefCounted, cell: Vector2i, direction: Vector2i) -> void:
	model.strike_under(cell, "bolt", direction)
	# The upgraded bolt fires both ways along the chosen line.
	var directions: Array = [direction, -direction] if model.is_plus("magic_bolt") else [direction]
	# Like a cannon shot, the bolt flies through cannons and sets them off.
	var passed: Array = []
	for aim: Vector2i in directions:
		for target in model.cannon_line(cell, aim, passed):
			model.events.append({"kind": "bolt", "cell": target, "id": -2, "dir": aim})
			var enemy: Dictionary = model.enemy_at(target)
			if not enemy.is_empty():
				model.damage_enemy(enemy, 1, aim)
	# The bolt's own tile counts as the first link, so the cannons go off after it.
	model.start_chain()
	model._resonate(passed, [cell])
