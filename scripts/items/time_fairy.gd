extends RefCounted

func apply(model: RefCounted, _cell: Vector2i, _direction: Vector2i) -> void:
	model.stop_time()
