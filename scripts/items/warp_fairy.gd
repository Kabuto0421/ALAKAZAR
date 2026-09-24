extends RefCounted

func apply(model: RefCounted, cell: Vector2i, _direction: Vector2i) -> void:
	model.events.append({"kind": "warp", "cell": model.player.cell, "id": -2})
	model.player.cell = cell
	model.events.append({"kind": "warp", "cell": cell, "id": -2})
	model.trigger_mine(model.player)
