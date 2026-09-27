extends RefCounted

func apply(model: RefCounted, cell: Vector2i, direction: Vector2i) -> void:
	model.place_cannon(cell, direction, "vane", model.is_plus("vane_cannon"))
