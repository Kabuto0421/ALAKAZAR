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
	# Rotorick's weapon verdict only binds the player's turn that just ended.
	model.locked_slot = -1
	model.events.clear()
	model.bless_heal()
	model.round_number += 1
	model.storm_enemy_turn()
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
				if model.distance(cell, model.player.cell) == 2 and not model.enemy_blocked(cell) and not reserved.has(cell) and not model.mines.has(cell) and (occupant.is_empty() or occupant.id == enemy.id):
					slots.append(cell)
		slots.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return infantry_behavior.score(model, enemy, a, enemy.cell) < infantry_behavior.score(model, enemy, b, enemy.cell))
		if not slots.is_empty():
			staging[enemy.id] = slots[0]
			reserved.append(slots[0])
	for enemy in model.enemies:
		enemy.ap = Rules.TYPES[enemy.type].ap
		if enemy.type == "jester" and enemy.get("awake", false):
			enemy.ap = Rules.JESTER_AWAKE_AP
		if enemy.type == "miner":
			enemy.intent = "移動・設置"
		elif enemy.type == "jester":
			enemy.intent = "四方へ・連続攻撃" if enemy.get("awake", false) else "左へ進む"
		elif enemy.type == "heavy":
			enemy.intent = "前進"
		elif enemy.type in Rules.JUMPERS:
			enemy.intent = "跳躍接近"
		elif enemy.type in ["rook", "slot"]:
			enemy.intent = "突進" if enemy.state == "brace" else "構える"
		elif enemy.type == "prison":
			enemy.intent = "接近"
		elif enemy.type == "storm_shark":
			enemy.intent = "浮上" if enemy.get("diving", false) else "接近・潜水"
		elif enemy.type == "shield":
			enemy.intent = "盾を構えて前進"
		elif enemy.type == "analyst":
			enemy.intent = "解析しながら前進"
		elif enemy.type == "javelin":
			enemy.intent = "接近・投擲"
		elif enemy.type == "archer":
			enemy.intent = "射撃" if enemy.state == "aim" else "照準合わせ"
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
		if enemy.type == "shadow":
			continue
		# 氷結妖精: a frozen enemy does nothing this turn (時の妖精: nobody does).
		if model.frozen(enemy) or model.time_stopped():
			enemy.ap = 0
			continue
		# 猫の妖精: every enemy that stands in the cat's field spends its action running out of it.
		if not model.cats.is_empty() and _cat_flee(model, enemy):
			continue
		if enemy.type == "slot":
			if enemy.state == "idle":
				model.rook_brace(enemy)
				model.slot_spin(enemy)
				enemy.ap = 0
			else:
				model.slot_turn(enemy)
			continue
		if enemy.type == "rook":
			if enemy.state == "brace":
				model.rook_charge(enemy)
			else:
				# Opening turn: it only turns red and aims (0 AP), so the first charge can be dodged.
				model.rook_brace(enemy)
				enemy.ap = 0
			continue
		if enemy.type == "prison":
			_prison_action(model, enemy)
			continue
		if enemy.type == "storm_shark":
			if enemy.get("diving", false) or enemy.ap == Rules.TYPES.storm_shark.ap:
				if model.shark_opening(enemy):
					continue
			_prison_action(model, enemy)
			continue
		if enemy.type == "king":
			model.king_turn(enemy)
			continue
		if enemy.type == "fortress":
			model.fortress_turn(enemy)
			continue
		if enemy.type == "javelin":
			_javelin_action(model, enemy)
			continue
		if enemy.type == "cross":
			_cross_action(model, enemy)
			continue
		if enemy.type == "archer":
			_archer_action(model, enemy)
			continue
		# 猫の妖精: ordinary walkers visibly steer clear of the cat's field.
		if not model.cats.is_empty() and enemy.type in CAT_AVOIDERS and _cat_avoid(model, enemy):
			continue
		var adjacent_ally := false
		# The mine soldier backs away and plants, and the dragon soldier shoots: neither strikes in melee.
		for offset in ([] if enemy.type in ["miner", "dragon"] else model.enemy_offsets(enemy)):
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
		elif enemy.type == "jester":
			_jester_action(model, enemy)
		elif enemy.type == "dragon":
			_dragon_action(model, enemy)
		elif enemy.type == "infantry":
			var action: Dictionary = infantry_behavior.decide(model, enemy, staging)
			if action.kind == "step":
				model.enemy_step(enemy, action.cell)
			else:
				enemy.ap = 0
		elif enemy.type in Rules.JUMPERS:
			_cavalry_action(model, enemy)
		elif enemy.type in Rules.GENERALS:
			_general_action(model, enemy)
		elif enemy.type in ["heavy", "executioner", "shield", "analyst"]:
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
		model.shadow_strike()
		model.tick_walls()
		_wake_jesters(model)
		model.phase = Rules.Phase.PLAYER
		model.player.ap = model.turn_start_ap()
		model.combo_boost = -1
		model.storm_roll_wind()
		model.add_log("TURN %02d / あなたのターン" % model.round_number)

## Anything that can move and stands in the cat's field (a 2x2 with any tile in it) runs out of
## it instead of whatever it meant to do: to a tile outside the field if its own moves reach one,
## else to the tile furthest from the cat. Returns true when it used its action.
func _cat_flee(model: RefCounted, enemy: Dictionary) -> bool:
	if enemy.type in ["king", "fortress", "shadow"] or enemy.get("diving", false) or not model.in_cat_zone(enemy):
		return false
	var size: int = enemy.get("size", 1)
	var step := _flee_step(model, enemy)
	if step == Vector2i.ZERO:
		return false
	enemy.intent = "猫から逃げる"
	if size > 1:
		return model.big_step(enemy, step)
	return model.enemy_step(enemy, enemy.cell + step)

## The first move of the shortest way (by the enemy's own moves) to somewhere that is clear of
## the field, or ZERO when there is none.
func _flee_step(model: RefCounted, enemy: Dictionary) -> Vector2i:
	var size: int = enemy.get("size", 1)
	var moves: Array = DIRECTIONS if size > 1 else model.enemy_offsets(enemy)
	var first := {enemy.cell: Vector2i.ZERO}
	var queue: Array[Vector2i] = [enemy.cell]
	var head := 0
	while head < queue.size() and head < 400:
		var at: Vector2i = queue[head]
		head += 1
		for move in moves:
			var anchor: Vector2i = at + move
			if first.has(anchor) or not _flee_fits(model, enemy, anchor, size):
				continue
			first[anchor] = move if at == enemy.cell else first[at]
			var clear := true
			for y in range(size):
				for x in range(size):
					clear = clear and not model.cat_zone_at(anchor + Vector2i(x, y))
			if clear:
				return first[anchor]
			queue.append(anchor)
	return Vector2i.ZERO

## Whether the enemy could stand with its top-left tile on `anchor` (the field itself is no wall).
func _flee_fits(model: RefCounted, enemy: Dictionary, anchor: Vector2i, size: int) -> bool:
	for y in range(size):
		for x in range(size):
			var cell: Vector2i = anchor + Vector2i(x, y)
			if not model.inside(cell) or model._walled(cell) or cell == model.player.cell or model.mines.has(cell):
				return false
			var other: Dictionary = model.enemy_at(cell)
			if not other.is_empty() and other.id != enemy.id:
				return false
	return true

## Who steers round the cat's field (bosses and the like are left to their own rules).
const CAT_AVOIDERS := ["infantry", "recruit", "heavy", "executioner", "shield", "analyst", "javelin", "archer", "dragon"]

## An enemy in the cat's field walks out of it first; one whose straight way to the player runs
## through the field goes round it (the shortest way over free tiles), or waits at its edge when
## there is no way. Returns true when it used its action.
func _cat_avoid(model: RefCounted, enemy: Dictionary) -> bool:
	var to_player: int = model.distance(enemy.cell, model.player.cell)
	if to_player <= 1:
		return false
	# The shortest way over free tiles to a tile beside the player (the field is a wall to it).
	var first := {enemy.cell: enemy.cell}
	var depth := {enemy.cell: 0}
	var queue: Array[Vector2i] = [enemy.cell]
	var head := 0
	var step: Vector2i = enemy.cell
	var length := -1
	while head < queue.size() and length < 0:
		var current: Vector2i = queue[head]
		head += 1
		for direction in DIRECTIONS:
			var next: Vector2i = current + direction
			if first.has(next) or not model.inside(next) or model.enemy_blocked(next) or next == model.player.cell or model.mines.has(next):
				continue
			if not model.enemy_at(next).is_empty() and model.enemy_at(next).id != enemy.id:
				continue
			first[next] = next if current == enemy.cell else first[current]
			depth[next] = depth[current] + 1
			if model.distance(next, model.player.cell) <= 1:
				step = first[next]
				length = depth[next]
				break
			queue.append(next)
	if length > 0:
		# Only when the field really is in the way (the straight route would be shorter).
		if length > to_player - 1:
			enemy.intent = "猫を避けて回り込む"
			model.enemy_step(enemy, step)
			return true
		return false
	# No way at all: if the field is what shuts the straight way, hold at its edge.
	for direction in DIRECTIONS:
		var cell: Vector2i = enemy.cell + direction
		if model.inside(cell) and model.distance(cell, model.player.cell) < to_player and model.cat_zone_at(cell):
			enemy.intent = "猫を避けて足止め"
			enemy.ap = 0
			return true
	return false

func _options(model: RefCounted, enemy: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for direction in DIRECTIONS:
		var cell: Vector2i = enemy.cell + direction
		if model.inside(cell) and not model.enemy_blocked(cell) and model.enemy_at(cell).is_empty() and cell != model.player.cell:
			result.append(cell)
	return result

func _cavalry_options(model: RefCounted, enemy: Dictionary, offsets: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset in offsets:
		var cell: Vector2i = enemy.cell + offset
		if model.inside(cell) and not model.enemy_blocked(cell) and cell != model.player.cell and model.enemy_at(cell).is_empty():
			result.append(cell)
	return result

func _cavalry_action(model: RefCounted, enemy: Dictionary) -> void:
	if model.enemy_offsets(enemy).has(model.player.cell-enemy.cell):
		model.enemy_step(enemy,model.player.cell)
		return
	var moves: Array = model.enemy_offsets(enemy)
	var goal := func(cell: Vector2i) -> bool: return moves.has(model.player.cell - cell)
	var distance: int = model.distance(enemy.cell,model.player.cell)
	var jumps := _cavalry_options(model,enemy,model.cavalry_jumps(enemy.facing))
	jumps = jumps.filter(func(cell: Vector2i) -> bool: return model.distance(cell,model.player.cell) < distance)
	jumps.sort_custom(func(a: Vector2i,b: Vector2i) -> bool: return model.distance(a,model.player.cell) < model.distance(b,model.player.cell))
	if not jumps.is_empty() and _makes_progress(model, enemy, jumps[0], moves, goal):
		model.enemy_step(enemy,jumps[0])
		return
	var options := _cavalry_options(model,enemy,DIRECTIONS)
	options = options.filter(func(cell: Vector2i) -> bool: return model.distance(cell,model.player.cell) < distance)
	options.sort_custom(func(a: Vector2i,b: Vector2i) -> bool: return model.distance(a,model.player.cell) < model.distance(b,model.player.cell))
	if not options.is_empty() and _makes_progress(model, enemy, options[0], moves, goal):
		model.enemy_step(enemy,options[0])
		return
	# Nothing nearer as the crow flies helps (a wall in the way): take the shortest walk round it.
	var route := _route(model, enemy, enemy.cell, moves, goal)
	if int(route.len) > 0 and model.enemy_step(enemy, route.step):
		return
	enemy.ap = 0

## 金将兵・銀将兵: strike when the player sits on one of its move tiles; otherwise take
## the first step of the shortest route (over its own moves) to a tile that threatens them.
func _general_action(model: RefCounted, enemy: Dictionary) -> void:
	var moves: Array = model.enemy_offsets(enemy)
	if moves.has(model.player.cell - enemy.cell):
		model.enemy_step(enemy, model.player.cell)
		return
	var start: Vector2i = enemy.cell
	var first := {start: start}
	var queue: Array[Vector2i] = [start]
	var head := 0
	var step := start
	while head < queue.size() and step == start:
		var current: Vector2i = queue[head]
		head += 1
		for offset in moves:
			var next: Vector2i = current + offset
			if first.has(next) or not model.inside(next) or model.enemy_blocked(next) or next == model.player.cell or model.mines.has(next):
				continue
			var other: Dictionary = model.enemy_at(next)
			if not other.is_empty() and other.id != enemy.id:
				continue
			first[next] = next if current == start else first[current]
			if moves.has(model.player.cell - next):
				step = first[next]
				break
			queue.append(next)
	if step == start:
		# No route to a striking tile: close the distance with whatever move it has.
		var best := start
		for offset in moves:
			var next: Vector2i = start + offset
			if model.inside(next) and not model.enemy_blocked(next) and next != model.player.cell and model.enemy_at(next).is_empty() and model.distance(next, model.player.cell) < model.distance(best, model.player.cell):
				best = next
		step = best
	if step == start or not model.enemy_step(enemy, step):
		enemy.ap = 0

## Shortest walk (over `moves`) from `from_cell` to a tile satisfying `goal`: {"step": first tile to
## step on, "len": number of moves}; len -1 when none is reachable. Greedy "nearer as the crow flies"
## steps get stuck against a wall; this is what they are checked against.
func _route(model: RefCounted, enemy: Dictionary, from_cell: Vector2i, moves: Array, goal: Callable) -> Dictionary:
	if goal.call(from_cell):
		return {"step": from_cell, "len": 0}
	var first := {from_cell: from_cell}
	var depth := {from_cell: 0}
	var queue: Array[Vector2i] = [from_cell]
	var head := 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		for offset in moves:
			var next: Vector2i = current + offset
			if first.has(next) or not model.inside(next) or model.enemy_blocked(next) or next == model.player.cell or model.mines.has(next):
				continue
			var other: Dictionary = model.enemy_at(next)
			if not other.is_empty() and other.id != enemy.id:
				continue
			first[next] = next if current == from_cell else first[current]
			depth[next] = int(depth[current]) + 1
			if goal.call(next):
				return {"step": first[next], "len": depth[next]}
			queue.append(next)
	return {"step": from_cell, "len": -1}

## Whether stepping to `cell` really shortens the walk to the goal (or the goal cannot be reached at all).
func _makes_progress(model: RefCounted, enemy: Dictionary, cell: Vector2i, moves: Array, goal: Callable) -> bool:
	var now := _route(model, enemy, enemy.cell, moves, goal)
	if int(now.len) < 0:
		return true
	var after := _route(model, enemy, cell, moves, goal)
	return int(after.len) >= 0 and int(after.len) < int(now.len)

## The same for a big (2x2) body sliding a tile at a time: first direction and length of the shortest
## slide to a spot where the player touches one of its sides.
func _big_route(model: RefCounted, enemy: Dictionary, from_cell: Vector2i) -> Dictionary:
	var probe: Dictionary = enemy.duplicate()
	var first := {from_cell: Vector2i.ZERO}
	var depth := {from_cell: 0}
	var queue: Array[Vector2i] = [from_cell]
	var head := 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		probe.cell = cell
		for side in DIRECTIONS:
			if model._front_cells(probe, side).has(model.player.cell):
				return {"dir": first[cell], "len": int(depth[cell])}
		for direction in DIRECTIONS:
			probe.cell = cell
			if not _big_free(model, probe, direction):
				continue
			var next: Vector2i = cell + direction
			if first.has(next):
				continue
			first[next] = direction if cell == from_cell else first[cell]
			depth[next] = int(depth[cell]) + 1
			queue.append(next)
	return {"dir": Vector2i.ZERO, "len": -1}

## バッテン兵: walks and strikes along the diagonals. It hits whoever stands on a diagonal neighbour (the
## player first, then an ally); otherwise it takes the first step of the shortest diagonal walk to a tile
## diagonal to the player. A diagonal walker never leaves its colour of the board, so from the other
## colour it just comes as close as it can and waits for the player to step into its reach.
func _cross_action(model: RefCounted, enemy: Dictionary) -> void:
	var strikes: Array[Vector2i] = model.CROSS_STRIKES
	if strikes.has(model.player.cell - enemy.cell):
		model.enemy_step(enemy, model.player.cell)
		return
	for offset in strikes:
		if not model.ally_at(enemy.cell + offset).is_empty():
			model.enemy_step(enemy, enemy.cell + offset)
			return
	var goal := func(cell: Vector2i) -> bool: return strikes.has(model.player.cell - cell)
	var route := _route(model, enemy, enemy.cell, strikes, goal)
	if int(route.len) > 0 and model.enemy_step(enemy, route.step):
		return
	var near := _route(model, enemy, enemy.cell, strikes, func(cell: Vector2i) -> bool: return model.distance(cell, model.player.cell) == 1)
	if int(near.len) > 0 and model.enemy_step(enemy, near.step):
		return
	enemy.ap = 0

## The jesters that have now marched three enemy turns wake up at the end of that turn, so the player
## sees them awake (and can read what they will do) on their own turn.
func _wake_jesters(model: RefCounted) -> void:
	for enemy in model.enemies:
		if enemy.type != "jester" or enemy.hp <= 0 or enemy.get("awake", false):
			continue
		enemy.age = int(enemy.get("age", 0)) + 1
		if enemy.age >= Rules.JESTER_SLEEP_TURNS:
			enemy.awake = true
			model.events.append({"kind": "awaken", "cell": enemy.cell, "id": enemy.id})
			model.add_log("道化兵が覚醒した！")

## 竜装兵: fire the arm cannon when the player (or an ally) is in the three tiles to its left; otherwise
## take the first step of the shortest walk to a tile from which the player would be in that line.
func _dragon_action(model: RefCounted, enemy: Dictionary) -> void:
	if model.dragon_fire(enemy):
		return
	var goal := func(cell: Vector2i) -> bool: return model.dragon_cells(cell).has(model.player.cell)
	var route := _route(model, enemy, enemy.cell, DIRECTIONS, goal)
	if int(route.len) > 0 and model.enemy_step(enemy, route.step):
		return
	# No firing spot reachable: just close in on the player.
	var action: Dictionary = heavy_behavior.decide(model, enemy)
	if action.kind == "step" and action.cell != model.player.cell and model.enemy_step(enemy, action.cell):
		return
	enemy.ap = 0

## 道化兵: asleep it only steps left (and strikes what stands there); awake it goes straight for the
## player round whatever is in the way and hits with every AP it has.
func _jester_action(model: RefCounted, enemy: Dictionary) -> void:
	if enemy.get("awake", false):
		var action: Dictionary = heavy_behavior.decide(model, enemy)
		if action.kind == "step" and model.enemy_step(enemy, action.cell):
			return
		enemy.ap = 0
		return
	if not model.enemy_step(enemy, enemy.cell + Vector2i.LEFT):
		enemy.ap = 0

## How many beats the enemy turn has (call after `begin`, which hands out the AP): two, or more while
## something has AP for more blows, like the awakened jester's three.
func beat_count(model: RefCounted) -> int:
	var count := 2
	for enemy in model.enemies:
		count = maxi(count, int(enemy.ap))
	return count

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

## Throw if the player stands in the javelin row; otherwise walk (4 ways) to a tile that can.
func _javelin_action(model: RefCounted, enemy: Dictionary) -> void:
	if model.javelin_throw(enemy):
		return
	var spots: Array[Vector2i] = []
	for offset in model.enemy_attack_offsets(enemy):
		var spot: Vector2i = model.player.cell - offset
		if model.inside(spot) and not model.enemy_blocked(spot) and spot != model.player.cell and (model.enemy_at(spot).is_empty() or model.enemy_at(spot).id == enemy.id):
			spots.append(spot)
	if spots.is_empty():
		spots.append(model.player.cell)
	var score := func(cell: Vector2i) -> int:
		var best := 999
		for spot in spots:
			best = mini(best, model.distance(cell, spot))
		return best
	var options := _options(model, enemy).filter(func(cell: Vector2i) -> bool: return not model.mines.has(cell))
	options.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return score.call(a) < score.call(b))
	var goal := func(cell: Vector2i) -> bool: return spots.has(cell)
	if not options.is_empty() and score.call(options[0]) < score.call(enemy.cell) and _makes_progress(model, enemy, options[0], DIRECTIONS, goal):
		model.enemy_step(enemy, options[0])
		return
	var route := _route(model, enemy, enemy.cell, DIRECTIONS, goal)
	if int(route.len) > 0 and model.enemy_step(enemy, route.step):
		return
	enemy.ap = 0

## Aim (1 AP) when the player is on the lane, shoot with the next AP, otherwise line up vertically.
func _archer_action(model: RefCounted, enemy: Dictionary) -> void:
	if enemy.state == "aim":
		model.archer_shoot(enemy)
		return
	if model.archer_lane(enemy).has(model.player.cell):
		model.archer_aim(enemy)
		return
	var dy := signi(model.player.cell.y - enemy.cell.y)
	var cell: Vector2i = enemy.cell + Vector2i(0, dy)
	if dy != 0 and model.inside(cell) and not model.enemy_blocked(cell) and model.enemy_at(cell).is_empty() and cell != model.player.cell and not model.mines.has(cell):
		model.enemy_step(enemy, cell)
	else:
		enemy.ap = 0

## Moving prison: attack when the player touches a side, otherwise slide closer.
func _prison_action(model: RefCounted, enemy: Dictionary) -> void:
	for direction in DIRECTIONS:
		if model._front_cells(enemy, direction).has(model.player.cell):
			model.big_step(enemy, direction)
			return
	var best: Vector2i = Vector2i.ZERO
	var best_score: int = model.footprint_distance(enemy, model.player.cell)
	for direction in DIRECTIONS:
		var probe: Dictionary = enemy.duplicate()
		probe.cell = enemy.cell + direction
		var score: int = model.footprint_distance(probe, model.player.cell)
		if score < best_score and _big_free(model, enemy, direction):
			best = direction
			best_score = score
	# A slide that does not shorten the real way round (a wall in the way) is no progress.
	var here := _big_route(model, enemy, enemy.cell)
	if best != Vector2i.ZERO and int(here.len) >= 0:
		var after := _big_route(model, enemy, enemy.cell + best)
		if int(after.len) < 0 or int(after.len) >= int(here.len):
			best = here.dir if int(here.len) > 0 else Vector2i.ZERO
	elif best == Vector2i.ZERO and int(here.len) > 0:
		best = here.dir
	if best == Vector2i.ZERO or not model.big_step(enemy, best):
		enemy.ap = 0

func _big_free(model: RefCounted, enemy: Dictionary, direction: Vector2i) -> bool:
	for cell in model._front_cells(enemy, direction):
		if not model.inside(cell) or model.enemy_blocked(cell) or model.mines.has(cell) or not model.enemy_at(cell).is_empty():
			return false
	return true
