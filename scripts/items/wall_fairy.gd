extends RefCounted

func apply(model: RefCounted, cell: Vector2i, direction: Vector2i) -> void:
	# The upgraded wall also fills the next tile in the chosen direction (when free).
	var extra: Vector2i = model.wall_extension(cell, direction) if model.is_plus("wall_fairy") else Vector2i(-1, -1)
	model.place_wall(cell)
	if extra != Vector2i(-1, -1):
		model.place_wall(extra)
