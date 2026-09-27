extends RefCounted

func apply(model: RefCounted, cell: Vector2i, direction: Vector2i) -> void:
	# The upgraded wall runs three tiles in the chosen direction (fewer if blocked).
	var extra: Array = model.wall_extension(cell, direction) if model.is_plus("wall_fairy") else []
	model.place_wall(cell)
	for tile: Vector2i in extra:
		model.place_wall(tile)
