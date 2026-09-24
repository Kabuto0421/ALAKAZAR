extends RefCounted

# Grid rules are independent of rendering and animation timing.
enum Phase { ENEMY, PLAYER, WON, LOST }
const ItemDefinition = preload("res://scripts/items/item_definition.gd")
const ITEMS = [preload("res://items/magic_bolt.tres"), preload("res://items/stealth_fairy.tres"), preload("res://items/warp_fairy.tres")]
const CARDINALS = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const Gold = preload("res://scripts/movement/shogi_gold_move.gd")
const Silver = preload("res://scripts/movement/shogi_silver_move.gd")
const Knight = preload("res://scripts/movement/shogi_knight_move.gd")
const FormationLayout = preload("res://scripts/formation_layout.gd")
const WEAPONS = [
	{"name": "金 / ハンマー", "short": "金", "row": 0, "color": "ffbd59", "detail": "前3方向・左右・後ろ"},
	{"name": "銀 / ソード", "short": "銀", "row": 2, "color": "bda0ff", "detail": "前3方向・後ろ斜め"},
	{"name": "桂 / アックス", "short": "桂", "row": 1, "color": "2bdcc8", "detail": "前2マス＋左右1マス"},
]
const TYPES = {
	"infantry": {"name": "歩兵", "hp": 1, "ap": 2},
	"miner": {"name": "地雷兵", "hp": 1, "ap": 2},
	"heavy": {"name": "重装兵", "hp": 2, "ap": 1},
	"cavalry": {"name": "跳躍騎兵", "hp": 1, "ap": 2},
}
const FORMATIONS = [
	preload("res://scenes/formations/encounter_01.tscn"),
	preload("res://scenes/formations/encounter_02.tscn"),
	preload("res://scenes/formations/encounter_03.tscn"),
]
var patterns: Array = [Gold.new(), Silver.new(), Knight.new()]
var phase: Phase = Phase.ENEMY
var level := 0
var round_number := 0
var weapon := 1
var facing := 0
var player: Dictionary = {}
var enemies: Array[Dictionary] = []
var mines: Array[Vector2i] = []
var logs: Array[String] = []
var events: Array[Dictionary] = []
var kills := 0
const HAND_LIMIT := 7
var inventory: Dictionary = {}
var shortcuts: Array[String] = ["magic_bolt", "stealth_fairy", "warp_fairy"]
var fairies: Array[Vector2i] = []
var obstacles: Array[Vector2i] = []

func reset(next_level: int = 0, keep_inventory: bool = false) -> void:
	level = posmod(next_level, FORMATIONS.size())
	phase = Phase.ENEMY
	round_number = 0
	weapon = 1
	facing = 0
	kills = 0
	player = {"id": -1, "type": "player", "cell": Vector2i(2,5), "hp": 5, "ap": 2}
	enemies.clear()
	mines.clear()
	fairies.clear()
	obstacles.clear()
	if not keep_inventory:
		inventory.clear()
		for item in ITEMS:
			add_item(item.id,item.initial_count)
	logs.clear()
	events.clear()
	var layout: Node = FORMATIONS[level].instantiate()
	for placement in layout.get_children():
		var cell := FormationLayout.cell_at(placement.position)
		var kind: String = ["infantry","miner","heavy","cavalry"][placement.enemy_kind]
		enemies.append(make_enemy(kind,cell,enemies.size()))
	layout.free()
	add_log("敵部隊が接近。敵から行動します。")

func make_enemy(kind: String, cell: Vector2i, id: int) -> Dictionary:
	return {"id": id, "type": kind, "cell": cell, "hp": TYPES[kind].hp, "ap": TYPES[kind].ap, "facing": 2, "wait": 0, "intent": "接近", "state": "approach", "charge_round": -1}

func cavalry_jumps(direction: int) -> Array[Vector2i]:
	var forward: Vector2i = CARDINALS[direction]
	var side := Vector2i(-forward.y,forward.x)
	return [forward*2+side,forward*2-side]

func enemy_offsets(enemy: Dictionary) -> Array:
	return CARDINALS + cavalry_jumps(enemy.get("facing",2)) if enemy.type == "cavalry" else CARDINALS

func turn_enemy(enemy: Dictionary, direction: int) -> bool:
	if phase != Phase.ENEMY or enemy.hp <= 0 or enemy.ap <= 0 or direction < 0 or direction >= 4 or enemy.get("facing",2) == direction:
		return false
	enemy.facing = direction
	enemy.ap -= 1
	enemy.intent = "旋回"
	add_log("%sが%sへ旋回" % [TYPES[enemy.type].name,["↑","→","↓","←"][direction]])
	return true

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
	return obstacles.has(cell) or fairies.has(cell)

func item_targets(id: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var item := item_definition(id)
	if item == null:
		return result
	var weapon_cells := targets()
	for y in range(6):
		for x in range(6):
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

func use_item(id: String, cell: Vector2i, direction: Vector2i = Vector2i.ZERO) -> bool:
	var item := item_definition(id)
	if item == null or phase != Phase.PLAYER or player.ap < item.ap_cost or inventory.get(id,0) <= 0:
		return false
	if not item_targets(id).has(cell) or (item.directional and not CARDINALS.has(direction)):
		return false
	events.clear()
	player.ap -= item.ap_cost
	inventory[id] -= 1
	item.effect.new().apply(self, cell, direction)
	add_log("%sを使用" % item.title)
	check_outcome()
	return true

func hand_size() -> int:
	var total := 0
	for count in inventory.values():
		total += int(count)
	return total

func add_item(id: String, count: int = 1) -> int:
	if item_definition(id) == null or count <= 0:
		return 0
	var accepted := mini(count,maxi(0,HAND_LIMIT-hand_size()))
	inventory[id] = inventory.get(id,0)+accepted
	return accepted

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
	return cell.x >= 0 and cell.x < 6 and cell.y >= 0 and cell.y < 6

func distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func enemy_at(cell: Vector2i) -> Dictionary:
	for enemy in enemies:
		if enemy.cell == cell and enemy.hp > 0:
			return enemy
	return {}

func targets() -> Array[Vector2i]:
	return targets_for_facing(facing)

func targets_for_facing(direction_index: int) -> Array[Vector2i]:
	if direction_index < 0 or direction_index >= CARDINALS.size():
		return []
	return patterns[weapon].get_destinations(player.cell, inside, CARDINALS[direction_index])

func weapon_offsets(index: int, direction_index: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset in patterns[index].step_offsets:
		result.append(patterns[index]._to_world_offset(offset,CARDINALS[direction_index]))
	return result

func turn_to(direction_index: int) -> bool:
	if phase != Phase.PLAYER or player.ap <= 0 or direction_index < 0 or direction_index >= CARDINALS.size() or direction_index == facing:
		return false
	events.clear()
	facing = direction_index
	player.ap -= 1
	add_log("向き変更：" + ["↑","→","↓","←"][facing])
	return true

func equip(index: int) -> bool:
	if phase != Phase.PLAYER or index < 0 or index >= WEAPONS.size():
		return false
	if index == weapon:
		return true
	if player.ap <= 0:
		return false
	weapon = index
	player.ap -= 1
	return true

func player_action(cell: Vector2i) -> bool:
	if phase != Phase.PLAYER or player.ap <= 0 or blocked(cell) or not targets().has(cell):
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
	var label: String = "探索者" if unit.type == "player" else TYPES[unit.type].name
	add_log("地雷が爆発！ %sに1ダメージ" % label)
	if unit.type != "player" and unit.hp <= 0:
		kills += 1
	check_outcome()

func check_outcome() -> void:
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
