extends RefCounted

func apply(model: RefCounted, cell: Vector2i, _direction: Vector2i) -> void:
	model.strike_under(cell, "slash", Vector2i.DOWN)
	model.side_slash(cell)
