extends RefCounted

const Rules = preload("res://scripts/battle_model.gd")
const Infantry = preload("res://scripts/infantry_behavior.gd")
const Heavy = preload("res://scripts/heavy_behavior.gd")
const DIRECTIONS = [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]
var infantry_behavior := Infantry.new()
var heavy_behavior := Heavy.new()
var staging: Dictionary = {}

func begin(model: RefCounted) -> void:
	model.phase = Rules.Phase.ENEMY
	model.round_number += 1
	staging.clear()
	var infantry: Array = model.enemies.filter(func(e: Dictionary) -> bool: return e.type == "infantry")
	var reserved: Array[Vector2i] = []
	for enemy in infantry:
		if enemy.state == Infantry.CHARGE:
			continue
		var slots: Array[Vector2i] = []
		for y in range(model.board_size):
			for x in range(model.board_size):
				var cell := Vector2i(x,y)
				var occupant: Dictionary = model.enemy_at(cell)
				if model.distance(cell, model.player.cell) == 2 and not model.blocked(cell) and not reserved.has(cell) and not model.mines.has(cell) and (occupant.is_empty() or occupant.id == enemy.id):
					slots.append(cell)
		slots.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return infantry_behavior.score(model, enemy, a, enemy.cell) < infantry_behavior.score(model, enemy, b, enemy.cell))
		if not slots.is_empty():
			staging[enemy.id] = slots[0]
			reserved.append(slots[0])
	for enemy in model.enemies:
		enemy.ap = Rules.TYPES[enemy.type].ap
		if enemy.type == "miner":
			enemy.intent = "移動・設置"
		elif enemy.type == "heavy":
			enemy.intent = "前進"
		elif enemy.type in Rules.JUMPERS:
			enemy.intent = "跳躍接近"
		elif enemy.state == Infantry.CHARGE:
			enemy.intent = "突撃"

func beat(model: RefCounted, index: int) -> void:
	model.events.clear()
	var ordered: Array = model.enemies.duplicate()
	ordered.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		if (a.type == "heavy") != (b.type == "heavy"):
			return a.type == "heavy"
		return a.id < b.id)
	for enemy in ordered:
		if model.terminal():
			break
		if enemy.hp <= 0 or enemy.ap <= 0:
			continue
		var adjacent_ally := false
		for offset in model.enemy_offsets(enemy):
			var cell: Vector2i = enemy.cell + offset
			if not model.ally_at(cell).is_empty():
				model.enemy_step(enemy,cell)
				adjacent_ally = true
				break
		if adjacent_ally:
			continue
		if enemy.type == "recruit":
			var action: Dictionary = heavy_behavior.decide(model,enemy)
			if action.kind == "step":
				model.enemy_step(enemy,action.cell)
			else:
				enemy.ap = 0
		elif enemy.type == "miner":
			_miner_action(model, enemy, index)
		elif enemy.type == "infantry":
			var action: Dictionary = infantry_behavior.decide(model, enemy, staging)
			if action.kind == "step":
				model.enemy_step(enemy, action.cell)
			else:
				enemy.ap = 0
		elif enemy.type in Rules.JUMPERS:
			_cavalry_action(model, enemy)
		elif enemy.type == "heavy":
			var action: Dictionary = heavy_behavior.decide(model,enemy)
			if action.kind == "step":
				model.enemy_step(enemy,action.cell)
			else:
				enemy.ap = 0
	model.check_outcome()

func finish(model: RefCounted) -> void:
	if not model.terminal():
		var infantry: Array = model.enemies.filter(func(e: Dictionary) -> bool: return e.type == "infantry")
		var nearby := 0
		for enemy in infantry:
			if model.distance(enemy.cell, model.player.cell) <= 2:
				nearby += 1
		for enemy in infantry:
			var request: Dictionary = infantry_behavior.finish_request(model, enemy, nearby, infantry.size())
			for key in request:
				enemy[key] = request[key]
		model.tick_walls()
		model.phase = Rules.Phase.PLAYER
		model.player.ap = 2
		model.add_log("TURN %02d / あなたのターン" % model.round_number)

func _options(model: RefCounted, enemy: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for direction in DIRECTIONS:
		var cell: Vector2i = enemy.cell + direction
		if model.inside(cell) and not model.blocked(cell) and model.enemy_at(cell).is_empty() and cell != model.player.cell:
			result.append(cell)
	return result

func _cavalry_options(model: RefCounted, enemy: Dictionary, offsets: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset in offsets:
		var cell: Vector2i = enemy.cell + offset
		if model.inside(cell) and not model.blocked(cell) and cell != model.player.cell and model.enemy_at(cell).is_empty():
			result.append(cell)
	return result

func _cavalry_action(model: RefCounted, enemy: Dictionary) -> void:
	if model.enemy_offsets(enemy).has(model.player.cell-enemy.cell):
		model.enemy_step(enemy,model.player.cell)
		return
	var distance: int = model.distance(enemy.cell,model.player.cell)
	var jumps := _cavalry_options(model,enemy,model.cavalry_jumps(enemy.facing))
	jumps = jumps.filter(func(cell: Vector2i) -> bool: return model.distance(cell,model.player.cell) < distance)
	jumps.sort_custom(func(a: Vector2i,b: Vector2i) -> bool: return model.distance(a,model.player.cell) < model.distance(b,model.player.cell))
	if not jumps.is_empty():
		model.enemy_step(enemy,jumps[0])
		return
	var options := _cavalry_options(model,enemy,DIRECTIONS)
	options = options.filter(func(cell: Vector2i) -> bool: return model.distance(cell,model.player.cell) < distance)
	options.sort_custom(func(a: Vector2i,b: Vector2i) -> bool: return model.distance(a,model.player.cell) < model.distance(b,model.player.cell))
	if not options.is_empty():
		model.enemy_step(enemy,options[0])
	else:
		enemy.ap = 0

func _move(model: RefCounted, enemy: Dictionary, cell: Vector2i) -> void:
	model.enemy_step(enemy, cell)

func _miner_action(model: RefCounted, enemy: Dictionary, index: int) -> void:
	if index == 1:
		if not model.mines.has(enemy.cell):
			model.mines.append(enemy.cell)
			model.events.append({"kind": "plant", "cell": enemy.cell, "id": enemy.id})
			model.add_log("地雷兵が地雷を設置")
		enemy.ap -= 1
		return
	var options := _options(model, enemy)
	options.sort_custom(func(a: Vector2i,b: Vector2i) -> bool: return _miner_score(model,a) < _miner_score(model,b))
	if not options.is_empty():
		_move(model, enemy, options[0])
	else:
		enemy.ap -= 1

func _miner_score(model: RefCounted, cell: Vector2i) -> float:
	return absf(model.distance(cell,model.player.cell)-3)*3.0 + (5.0 if model.mines.has(cell) else 0.0) - cell.y*0.1
