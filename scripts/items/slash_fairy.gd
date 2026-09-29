extends RefCounted

func apply(model: RefCounted, cell: Vector2i, direction: Vector2i) -> void:
	# 斬撃精霊+ throws the wave: a 5x3 block in the chosen direction.
	if model.is_plus("slash_fairy"):
		model.strike_under(cell, "slash", direction)
		model.slash(cell, direction)
		return
	model.strike_under(cell, "slash", Vector2i.DOWN)
	model.side_slash(cell)
