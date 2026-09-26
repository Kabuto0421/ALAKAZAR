extends RefCounted

## Plays the coming enemy turn on a copy of the board, assuming the player
## stays put, and reports which enemies would land a hit.
const Planner = preload("res://scripts/enemy_planner.gd")

static func attackers(model: RefCounted) -> Array[int]:
	var result: Array[int] = []
	if model.terminal():
		return result
	var sim: RefCounted = model.clone()
	sim.act_allies()
	if sim.terminal():
		return result
	var planner := Planner.new()
	planner.begin(sim)
	for beat in range(2):
		planner.beat(sim,beat)
		for event in sim.events:
			if event.kind == "hit" and event.id == -1 and event.has("by") and not result.has(int(event.by)):
				result.append(int(event.by))
		if sim.terminal():
			break
	return result
