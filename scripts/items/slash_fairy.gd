extends RefCounted

func apply(model: RefCounted, cell: Vector2i, direction: Vector2i) -> void:
	model.slash(cell, direction)
