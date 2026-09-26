extends RefCounted

# Grid rules are independent of rendering and animation timing.
enum Phase { ENEMY, PLAYER, WON, LOST }
const ItemDefinition = preload("res://scripts/items/item_definition.gd")
const ITEMS = [preload("res://items/magic_bolt.tres"), preload("res://items/stealth_fairy.tres"), preload("res://items/warp_fairy.tres"), preload("res://items/acorn_fairy.tres"),
	preload("res://items/wall_fairy.tres"), preload("res://items/cannon_fairy.tres"), preload("res://items/vane_cannon.tres"), preload("res://items/firework_fairy.tres"), preload("res://items/slash_fairy.tres"), preload("res://items/flying_slash.tres")]
## Player turns a wall spirit stands, counting the turn it is placed.
const WALL_TURNS := 3
## Cannon kinds: "lance" fires straight, "vane" fires then turns clockwise, "firework" bursts around itself once.
const CANNON_TITLES = {"lance": "槍砲精霊", "vane": "風見砲の妖精", "firework": "花火妖精"}
const CARDINALS = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const Catalog = preload("res://scripts/run/weapon_catalog.gd")
const FormationLayout = preload("res://scripts/formation_layout.gd")
const WEAPONS = Catalog.DATA
const TYPES = {
	"recruit": {"name": "歩兵", "hp": 1, "ap": 1},
	"infantry": {"name": "歩兵", "hp": 1, "ap": 2},
	"miner": {"name": "地雷兵", "hp": 1, "ap": 2},
	"heavy": {"name": "重装兵", "hp": 2, "ap": 1},
	"cavalry": {"name": "跳躍騎兵", "hp": 1, "ap": 2},
}
const FORMATIONS = [
	preload("res://scenes/formations/run_01.tscn"),
	preload("res://scenes/formations/run_02.tscn"),
	preload("res://scenes/formations/run_03.tscn"),
]
var board_size := 4
var owned_weapons: Array[int] = [0,1,2]
var fairy_loadout: Array[String] = ["magic_bolt"]
var fairy_charges: Array[int] = []
var allies: Array[Dictionary] = []
var next_ally_id := -100
var phase: Phase = Phase.ENEMY
var level := 0
var round_number := 0
var weapon := 0
var facing := 1
var player: Dictionary = {}
var enemies: Array[Dictionary] = []
var mines: Array[Vector2i] = []
var logs: Array[String] = []
var events: Array[Dictionary] = []
var kills := 0
const HAND_LIMIT := 3
const WEAPON_LIMIT := 3
var inventory: Dictionary = {}
var shortcuts: Array[String] = ["magic_bolt", "stealth_fairy", "warp_fairy"]
var fairies: Array[Vector2i] = []
var obstacles: Array[Vector2i] = []
## Wall spirits: cell -> player turns left (including the current one).
var walls: Dictionary = {}
## Placed cannons: {cell, dir, kind}. They fire when the player attacks their tile.
var cannons: Array[Dictionary] = []

func reset(next_level: int = 0, keep_inventory: bool = false) -> void:
	level = clampi(next_level, 0, 2)
	var layout: Node = FORMATIONS[level].instantiate()
	board_size = layout.board_size
	phase = Phase.ENEMY
	round_number = 0
	if not keep_inventory:
		owned_weapons.assign([0,1,2])
		fairy_loadout.assign(["magic_bolt"])
	weapon = owned_weapons[0]
	facing = 1
	kills = 0
	player = {"id": -1, "type": "player", "cell": layout.player_start, "hp": 5, "ap": 2}
	enemies.clear()
	mines.clear()
	fairies.clear()
	allies.clear()
	next_ally_id = -100
	obstacles.clear()
	walls.clear()
	cannons.clear()
	refill_fairies()
	logs.clear()
	events.clear()
	for placement in layout.get_children():
		var cell := FormationLayout.cell_at(placement.position,board_size)
		var kind: String = ["infantry","miner","heavy","cavalry","recruit"][placement.enemy_kind]
		enemies.append(make_enemy(kind,cell,enemies.size()))
	layout.free()
	add_log("敵から行動。武器はタップで持ち替え・0 AP")

func refill_fairies() -> void:
	inventory.clear()
	fairy_charges.clear()
	for id in fairy_loadout:
		var count: int = item_definition(id).initial_count
		fairy_charges.append(count)
		inventory[id] = inventory.get(id,0)+count


func make_enemy(kind: String, cell: Vector2i, id: int) -> Dictionary:
	return {"id": id, "type": kind, "cell": cell, "hp": TYPES[kind].hp, "ap": TYPES[kind].ap, "facing": 3, "wait": 0, "intent": "接近", "state": "approach", "charge_round": -1}

func cavalry_jumps(direction: int) -> Array[Vector2i]:
	var forward: Vector2i = CARDINALS[direction]
	var side := Vector2i(-forward.y,forward.x)
	return [forward*2+side,forward*2-side]

func enemy_offsets(enemy: Dictionary) -> Array:
	return CARDINALS + cavalry_jumps(enemy.get("facing",2)) if enemy.type == "cavalry" else CARDINALS

func turn_enemy(_enemy: Dictionary, _direction: int) -> bool:
	return false

func enemy_step(enemy: Dictionary, cell: Vector2i) -> bool:
	if phase != Phase.ENEMY or enemy.hp <= 0 or enemy.ap <= 0 or not inside(cell) or not enemy_offsets(enemy).has(cell-enemy.cell):
		return false
	if cell == player.cell:
		enemy.ap -= 1
		player.hp -= 1
		enemy.intent = "攻撃"
		events.append({"kind": "hit", "cell": cell, "id": -1})
		add_log("%sの攻撃 / HP −1" % TYPES[enemy.type].name)
		check_outcome()
		return true
	var ally := ally_at(cell)
	if not ally.is_empty():
		enemy.ap -= 1
		ally.hp -= 1
		events.append({"kind":"hit", "cell":cell, "id":ally.id})
		allies = allies.filter(func(unit: Dictionary) -> bool: return unit.hp > 0)
		return true
	if blocked(cell) or not enemy_at(cell).is_empty():
		return false
	enemy.ap -= 1
	enemy.cell = cell
	trigger_mine(enemy)
	if not terminal():
		trigger_fairies()
	check_outcome()
	return true

func item_definition(id: String) -> Resource:
	for item in ITEMS:
		if item.id == id:
			return item
	return null

func blocked(cell: Vector2i) -> bool:
	return obstacles.has(cell) or walls.has(cell) or fairies.has(cell) or not cannon_at(cell).is_empty() or not ally_at(cell).is_empty()

func item_targets(id: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var item := item_definition(id)
	if item == null:
		return result
	var weapon_cells := targets()
	for y in range(board_size):
		for x in range(board_size):
			var cell := Vector2i(x,y)
			if cell == player.cell or blocked(cell) or not enemy_at(cell).is_empty():
				continue
			if item.target == ItemDefinition.Target.ANY_EMPTY or weapon_cells.has(cell):
				result.append(cell)
	return result

func ray_cells(origin: Vector2i, direction: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not CARDINALS.has(direction):
		return result
	var cell := origin + direction
	while inside(cell) and not blocked(cell):
		result.append(cell)
		cell += direction
	return result

func use_item(id: String, cell: Vector2i, direction: Vector2i = Vector2i.ZERO, slot: int = -1) -> bool:
	var item := item_definition(id)
	if item == null or phase != Phase.PLAYER or player.ap < item.ap_cost or inventory.get(id,0) <= 0:
		return false
	if slot < 0:
		for i in fairy_loadout.size():
			if fairy_loadout[i] == id and fairy_charges[i] > 0:
				slot = i
				break
	if slot < 0 or slot >= fairy_loadout.size() or fairy_loadout[slot] != id or fairy_charges[slot] <= 0:
		return false
	if not item_targets(id).has(cell) or (item.directional and not CARDINALS.has(direction)):
		return false
	events.clear()
	player.ap -= item.ap_cost
	inventory[id] -= 1
	fairy_charges[slot] -= 1
	item.effect.new().apply(self, cell, direction)
	add_log("%sを使用" % item.title)
	check_outcome()
	return true

func hand_size() -> int:
	return fairy_loadout.size()

func add_item(id: String, count: int = 1) -> int:
	if item_definition(id) == null or count <= 0 or fairy_loadout.size() >= HAND_LIMIT:
		return 0
	fairy_loadout.append(id)
	var count_per_battle: int = item_definition(id).initial_count
	fairy_charges.append(count_per_battle)
	inventory[id] = inventory.get(id,0)+count_per_battle
	return 1

func assign_shortcut(slot: int, id: String) -> bool:
	if slot < 0 or slot >= shortcuts.size() or item_definition(id) == null:
		return false
	var previous := shortcuts.find(id)
	if previous >= 0:
		shortcuts[previous] = shortcuts[slot]
	shortcuts[slot] = id
	return true

func damage_enemy(enemy: Dictionary, amount: int) -> void:
	if enemy.hp <= 0:
		return
	enemy.hp -= amount
	events.append({"kind": "hit", "cell": enemy.cell, "id": enemy.id})
	if enemy.hp <= 0:
		kills += 1

func trigger_fairies() -> void:
	# Placement order, then enemy ID, resolves simultaneous opportunities.
	var ordered := enemies.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
	for cell in fairies.duplicate():
		for enemy in ordered:
			if enemy.hp > 0 and distance(cell, enemy.cell) == 1:
				fairies.erase(cell)
				events.append({"kind": "ambush", "cell": cell, "id": -2})
				damage_enemy(enemy, 1)
				break
	check_outcome()

func inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < board_size and cell.y >= 0 and cell.y < board_size

func distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func enemy_at(cell: Vector2i) -> Dictionary:
	for enemy in enemies:
		if enemy.cell == cell and enemy.hp > 0:
			return enemy
	return {}

func targets() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset in Catalog.offsets(weapon):
		var cell: Vector2i = player.cell + offset
		if inside(cell):
			result.append(cell)
	return result

func targets_for_facing(_direction_index: int) -> Array[Vector2i]:
	return targets()

func weapon_offsets(index: int, _direction_index: int = 1) -> Array[Vector2i]:
	return Catalog.offsets(index)

func turn_to(_direction_index: int) -> bool:
	return false

func equip(index: int) -> bool:
	if phase != Phase.PLAYER or not owned_weapons.has(index):
		return false
	weapon = index
	return true

func player_action(cell: Vector2i) -> bool:
	if phase != Phase.PLAYER or player.ap <= 0 or not targets().has(cell):
		return false
	var cannon := cannon_at(cell)
	if not cannon.is_empty():
		# Striking a placed cannon fires it.
		events.clear()
		player.ap -= 1
		fire_cannon(cannon)
		check_outcome()
		return true
	if blocked(cell):
		return false
	events.clear()
	player.ap -= 1
	var enemy := enemy_at(cell)
	if not enemy.is_empty():
		enemy.hp -= 1
		events.append({"kind": "hit", "cell": cell, "id": enemy.id})
		add_log("%sで%sを攻撃" % [WEAPONS[weapon].short, TYPES[enemy.type].name])
		if enemy.hp <= 0:
			kills += 1
			add_log("%sを撃破" % TYPES[enemy.type].name)
	else:
		player.cell = cell
		trigger_mine(player)
	check_outcome()
	return true

func trigger_mine(unit: Dictionary) -> void:
	if unit.type == "miner" or not mines.has(unit.cell):
		return
	mines.erase(unit.cell)
	unit.hp -= 1
	events.append({"kind": "mine", "cell": unit.cell, "id": unit.id})
	var label: String = "探索者" if unit.type == "player" else "どんぐり妖精" if unit.type == "acorn" else TYPES[unit.type].name
	add_log("地雷が爆発！ %sに1ダメージ" % label)
	if unit.type not in ["player","acorn"] and unit.hp <= 0:
		kills += 1
	check_outcome()

func check_outcome() -> void:
	allies = allies.filter(func(unit: Dictionary) -> bool: return unit.hp > 0)
	enemies = enemies.filter(func(e: Dictionary) -> bool: return e.hp > 0)
	if player.hp <= 0:
		phase = Phase.LOST
	elif enemies.is_empty():
		phase = Phase.WON

func terminal() -> bool:
	return phase == Phase.WON or phase == Phase.LOST

func add_log(message: String) -> void:
	logs.push_front(message)
	if logs.size() > 8:
		logs.resize(8)

func ally_at(cell: Vector2i) -> Dictionary:
	for ally in allies:
		if ally.hp > 0 and ally.cell == cell:
			return ally
	return {}

func summon_acorn(cell: Vector2i) -> void:
	allies.append({"id":next_ally_id, "type":"acorn", "cell":cell, "hp":1, "ap":1, "facing":1})
	next_ally_id -= 1
	events.append({"kind":"summon", "cell":cell, "id":-2})

func act_allies() -> void:
	if terminal():
		return
	events.clear()
	for ally in allies.duplicate():
		if ally.hp <= 0 or terminal():
			continue
		ally.ap = 1
		var adjacent: Array[Dictionary] = []
		for enemy in enemies:
			if enemy.hp > 0 and distance(ally.cell,enemy.cell) == 1:
				adjacent.append(enemy)
		adjacent.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
			return a.hp < b.hp if a.hp != b.hp else a.id < b.id)
		if not adjacent.is_empty():
			damage_enemy(adjacent[0],1)
			ally.ap = 0
			add_log("どんぐり妖精が攻撃")
			check_outcome()
			continue
		# Breadth-first search finds the nearest reachable enemy without crossing allies.
		var start: Vector2i = ally.cell
		var queue: Array[Vector2i] = [start]
		var first: Dictionary = {start:start}
		var destination := start
		var head := 0
		while head < queue.size() and destination == start:
			var current := queue[head]
			head += 1
			for direction in CARDINALS:
				var next: Vector2i = current + direction
				if first.has(next) or not inside(next) or blocked(next) or next == player.cell or mines.has(next):
					continue
				first[next] = next if current == start else first[current]
				if not enemy_at(next).is_empty():
					destination = first[next]
					break
				queue.append(next)
		if destination != start and enemy_at(destination).is_empty():
			ally.cell = destination
			trigger_mine(ally)
		ally.ap = 0
	check_outcome()


# --- wall, cannon and slash fairies ---------------------------------------

func place_wall(cell: Vector2i) -> void:
	walls[cell] = WALL_TURNS
	events.append({"kind":"summon", "cell":cell, "id":-2})

## Called when a new player turn begins: walls count down and crumble.
func tick_walls() -> void:
	for cell in walls.keys():
		walls[cell] -= 1
		if walls[cell] <= 0:
			walls.erase(cell)
			add_log("壁精霊が消えた")

func cannon_at(cell: Vector2i) -> Dictionary:
	for cannon in cannons:
		if cannon.cell == cell:
			return cannon
	return {}

func place_cannon(cell: Vector2i, direction: Vector2i, kind: String) -> void:
	cannons.append({"cell":cell, "dir":direction, "kind":kind})
	events.append({"kind":"summon", "cell":cell, "id":-2})

## Fire a cannon. A shot or burst that reaches another cannon sets it off too.
func fire_cannon(cannon: Dictionary, fired: Array = []) -> void:
	if fired.has(cannon.cell):
		return
	fired.append(cannon.cell)
	add_log("%sが発射" % CANNON_TITLES[cannon.kind])
	if cannon.kind == "firework":
		cannons.erase(cannon)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var cell: Vector2i = cannon.cell + Vector2i(dx, dy)
				if cell == cannon.cell or not inside(cell):
					continue
				events.append({"kind":"blast", "cell":cell, "id":-2})
				var enemy := enemy_at(cell)
				if not enemy.is_empty():
					damage_enemy(enemy, 1)
				var other := cannon_at(cell)
				if not other.is_empty():
					fire_cannon(other, fired)
		return
	var cells := ray_cells(cannon.cell, cannon.dir)
	for cell in cells:
		events.append({"kind":"bolt", "cell":cell, "id":-2})
		var enemy := enemy_at(cell)
		if not enemy.is_empty():
			damage_enemy(enemy, 1)
	var end: Vector2i = (cells[-1] if not cells.is_empty() else cannon.cell) + cannon.dir
	if cannon.kind == "vane":
		cannon.dir = CARDINALS[(CARDINALS.find(cannon.dir) + 1) % 4]
	var other := cannon_at(end)
	if not other.is_empty():
		fire_cannon(other, fired)

## Three parallel lanes: the lane through the placed tile and its two neighbours.
func slash_cells(origin: Vector2i, direction: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not CARDINALS.has(direction):
		return result
	var side := Vector2i(-direction.y, direction.x)
	for k in [-1, 0, 1]:
		for cell in ray_cells(origin + side * k, direction):
			if not result.has(cell):
				result.append(cell)
	return result

## 斬撃精霊: the three tiles directly in front of the placed tile.
func front_slash_cells(origin: Vector2i, direction: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not CARDINALS.has(direction):
		return result
	var side := Vector2i(-direction.y, direction.x)
	for k in [-1, 0, 1]:
		var cell: Vector2i = origin + direction + side * k
		if inside(cell):
			result.append(cell)
	return result

func front_slash(origin: Vector2i, direction: Vector2i) -> void:
	_slash_hit(front_slash_cells(origin, direction))

## 飛刃精霊 (the slash's class-up): the three-lane wave flies to the edge.
func slash(origin: Vector2i, direction: Vector2i) -> void:
	_slash_hit(slash_cells(origin, direction))

func _slash_hit(cells: Array[Vector2i]) -> void:
	for cell in cells:
		events.append({"kind":"slash", "cell":cell, "id":-2})
		var enemy := enemy_at(cell)
		if not enemy.is_empty():
			damage_enemy(enemy, 1)

## Cells a directional fairy will affect, for the placement preview.
func directional_preview(id: String, origin: Vector2i, direction: Vector2i) -> Array[Vector2i]:
	if id == "slash_fairy":
		return front_slash_cells(origin, direction)
	if id == "flying_slash":
		return slash_cells(origin, direction)
	return ray_cells(origin, direction)
