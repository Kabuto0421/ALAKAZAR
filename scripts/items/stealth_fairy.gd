extends RefCounted

func apply(model: RefCounted, cell: Vector2i, _direction: Vector2i) -> void:
	model.fairies.append(cell)
	model.events.append({"kind": "summon", "cell": cell, "id": -2})
	model.trigger_fairies()
