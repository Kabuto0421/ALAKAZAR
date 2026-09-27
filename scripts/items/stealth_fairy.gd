extends RefCounted

func apply(model: RefCounted, cell: Vector2i, _direction: Vector2i) -> void:
	model.place_stealth(cell)
	model.events.append({"kind": "summon", "cell": cell, "id": -2, "fx": "stealth"})
	model.trigger_fairies()
