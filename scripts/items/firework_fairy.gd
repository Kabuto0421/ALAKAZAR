extends RefCounted

func apply(model: RefCounted, cell: Vector2i, _direction: Vector2i) -> void:
	model.place_cannon(cell, Vector2i.ZERO, "firework")
