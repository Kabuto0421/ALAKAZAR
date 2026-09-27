extends RefCounted

func apply(model: RefCounted, cell: Vector2i, direction: Vector2i) -> void:
	model.strike_under(cell, "slash", direction)
	model.front_slash(cell, direction)
