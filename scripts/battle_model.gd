extends RefCounted

# Grid rules are independent of rendering and animation timing.
enum Phase { ENEMY, PLAYER, WON, LOST }
const ItemDefinition = preload("res://scripts/items/item_definition.gd")
const ITEMS = [preload("res://items/magic_bolt.tres"), preload("res://items/stealth_fairy.tres"), preload("res://items/warp_fairy.tres"), preload("res://items/acorn_fairy.tres"),
	preload("res://items/wall_fairy.tres"), preload("res://items/cannon_fairy.tres"), preload("res://items/vane_cannon.tres"), preload("res://items/firework_fairy.tres"), preload("res://items/slash_fairy.tres"), preload("res://items/flying_slash.tres"),
	preload("res://items/capacitor_fairy.tres")]
## Player turns a placed spirit (wall, cannons, stealth) stands, counting the turn it is placed.
const WALL_TURNS := 3
## Cannon kinds: "lance" fires straight, "vane" fires then turns clockwise, "firework" bursts around itself once.
const CANNON_TITLES = {"lance": "槍砲精霊", "vane": "風見砲の妖精", "firework": "花火妖精", "capacitor": "蓄電の妖精"}
## Capacitor: hits (weapon or a chained shot) needed to discharge.
const CAPACITOR_FULL := 3
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
	"horse": {"name": "馬", "hp": 2, "ap": 2},
	"javelin": {"name": "投げ槍兵", "hp": 1, "ap": 2},
	"archer": {"name": "弓兵", "hp": 1, "ap": 1},
	"rook": {"name": "突進くん", "hp": 3, "ap": 1, "size": 2},
	"prison": {"name": "移動監獄", "hp": 1, "ap": 1, "size": 2},
	"executioner": {"name": "執行兵", "hp": 2, "ap": 2},
	"slot": {"name": "ロトリック", "hp": 3, "ap": 1, "size": 2},
	"shadow": {"name": "ロトリックの影", "hp": 1, "ap": 0, "size": 2},
}
## Two-by-two bosses: their cell is the top-left of the footprint.
const BIG = ["rook", "prison", "slot", "shadow"]
## Chargers that move like a rook (飛車) with a braced direction.
const CHARGERS = ["rook", "slot"]
## Ranged soldiers never melee; they attack from their own tile.
const RANGED = ["javelin", "archer"]
## Horses move and jump exactly like cavalry, with more HP.
const JUMPERS = ["cavalry", "horse"]
const MAX_HP := 5
const FORMATIONS = [
	preload("res://scenes/formations/run_01.tscn"),
	preload("res://scenes/formations/run_02.tscn"),
	preload("res://scenes/formations/run_03.tscn"),
	preload("res://scenes/formations/run_boss_01.tscn"),
	preload("res://scenes/formations/run_mid_01.tscn"),
	preload("res://scenes/formations/run_mid_02.tscn"),
	preload("res://scenes/formations/run_mid_03.tscn"),
	preload("res://scenes/formations/run_boss_03.tscn"),
]
const BOSS_LEVEL := 3
## The second boss (Rotorick) after the mid-game camp.
const BOSS2_LEVEL := 7
const BOSS_LEVELS = [3, 7]
## The first boss is drawn from these rooms: three horses, or the rook and the moving prison.
const BOSS_FORMATIONS = [
	preload("res://scenes/formations/run_boss_01.tscn"),
	preload("res://scenes/formations/run_boss_02.tscn"),
]
var boss_variant := 0
## Rotorick's reel: results are drawn from this seed so look-ahead copies never disturb them.
var slot_seed := 0
var slot_rolls := 0
## Reel 1-3: the only weapon slot the player may use this turn (-1 = free).
var locked_slot := -1
## Reel 4: tiles that burn at the start of the next enemy turn.
var floor_cells: Array[Vector2i] = []
## Mid-game fights after the first boss, then a camp and the second boss.
const MID_LEVELS = [4, 5, 6]
const LAST_LEVEL := 7
var board_size := 4
var owned_weapons: Array[int] = [0,1,2]
var fairy_loadout: Array[String] = ["magic_bolt"]
var fairy_charges: Array[int] = []
## HP the player starts this fight with; the run carries it between fights.
var start_hp := MAX_HP
## Camp forging: weapon index -> extra damage.
var weapon_power: Dictionary = {}
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
## Stealth fairies: cell -> player turns left.
var fairy_turns: Dictionary = {}
var obstacles: Array[Vector2i] = []
## Wall spirits: cell -> player turns left (including the current one).
var walls: Dictionary = {}
## Placed cannons: {cell, dir, kind}. They fire when the player attacks their tile.
var cannons: Array[Dictionary] = []

func reset(next_level: int = 0, keep_inventory: bool = false) -> void:
	level = clampi(next_level, 0, FORMATIONS.size()-1)
	var scene: PackedScene = BOSS_FORMATIONS[boss_variant] if level == BOSS_LEVEL else FORMATIONS[level]
	var layout: Node = scene.instantiate()
	board_size = layout.board_size
	# The player always opens the fight.
	phase = Phase.PLAYER
	round_number = 1
	if not keep_inventory:
		owned_weapons.assign([0,1,2])
		fairy_loadout.assign(["magic_bolt"])
		start_hp = MAX_HP
		weapon_power.clear()
	weapon = owned_weapons[0]
	facing = 1
	kills = 0
	player = {"id": -1, "type": "player", "cell": layout.player_start, "hp": start_hp, "ap": 2}
	enemies.clear()
	mines.clear()
	fairies.clear()
	fairy_turns.clear()
	allies.clear()
	next_ally_id = -100
	obstacles.clear()
	walls.clear()
	cannons.clear()
	locked_slot = -1
	floor_cells.clear()
	slot_rolls = 0
	slot_seed = randi()
	refill_fairies()
	logs.clear()
	events.clear()
	for placement in layout.get_children():
		var cell := FormationLayout.cell_at(placement.position,board_size)
		var kind: String = ["infantry","miner","heavy","cavalry","recruit","horse","javelin","archer","rook","prison","executioner","slot"][placement.enemy_kind]
		enemies.append(make_enemy(kind,cell,enemies.size()))
	layout.free()
	add_log("あなたから行動。武器はタップで持ち替え・0 AP")

## Deep copy used to look ahead (e.g. which enemies would hit the player).
func clone() -> RefCounted:
	var copy: RefCounted = get_script().new()
	for property in get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value: Variant = get(property.name)
			copy.set(property.name, value.duplicate(true) if value is Array or value is Dictionary else value)
	return copy

func refill_fairies() -> void:
	inventory.clear()
	fairy_charges.clear()
	for id in fairy_loadout:
		var count: int = item_definition(id).initial_count
		fairy_charges.append(count)
		inventory[id] = inventory.get(id,0)+count


func make_enemy(kind: String, cell: Vector2i, id: int) -> Dictionary:
	var state := "idle" if kind in CHARGERS else "approach"
	return {"id": id, "type": kind, "cell": cell, "hp": TYPES[kind].hp, "ap": TYPES[kind].ap, "facing": 3, "wait": 0, "intent": "接近", "state": state, "charge_round": -1, "size": int(TYPES[kind].get("size", 1)), "reel": 0, "last_reel": 0}

## Every tile a unit covers (four for the two-by-two bosses).
func footprint(enemy: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var size: int = enemy.get("size", 1)
	for y in range(size):
		for x in range(size):
			result.append(enemy.cell + Vector2i(x, y))
	return result

func cavalry_jumps(direction: int) -> Array[Vector2i]:
	var forward: Vector2i = CARDINALS[direction]
	var side := Vector2i(-forward.y,forward.x)
	return [forward*2+side,forward*2-side]

func enemy_offsets(enemy: Dictionary) -> Array:
	if enemy.type == "archer":
		return [Vector2i.UP, Vector2i.DOWN]
	return CARDINALS + cavalry_jumps(enemy.get("facing",2)) if enemy.type in JUMPERS else CARDINALS

## Offsets a ranged soldier attacks (relative to its tile) for the inspector.
func enemy_attack_offsets(enemy: Dictionary) -> Array:
	var forward: Vector2i = CARDINALS[enemy.get("facing",3)]
	var side := Vector2i(-forward.y,forward.x)
	if enemy.type == "javelin":
		return [forward*2-side, forward*2, forward*2+side]
	if enemy.type == "archer":
		return [forward, forward*2]
	return []

## Javelin: the row of three tiles one square beyond the tile in front.
func javelin_cells(enemy: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset in enemy_attack_offsets(enemy):
		if inside(enemy.cell+offset):
			result.append(enemy.cell+offset)
	return result

func arrow_stopped(cell: Vector2i) -> bool:
	return obstacles.has(cell) or walls.has(cell) or not cannon_at(cell).is_empty()

## Archer: straight line ahead (like a lance) until terrain stops it.
func archer_lane(enemy: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var forward: Vector2i = CARDINALS[enemy.get("facing",3)]
	var cell: Vector2i = enemy.cell + forward
	while inside(cell) and not arrow_stopped(cell):
		result.append(cell)
		cell += forward
	return result

func javelin_throw(enemy: Dictionary) -> bool:
	if phase != Phase.ENEMY or enemy.hp <= 0 or enemy.ap <= 0 or not javelin_cells(enemy).has(player.cell):
		return false
	# One javelin per turn.
	enemy.ap = 0
	enemy.intent = "投擲"
	events.append({"kind":"javelin", "cell":player.cell, "from":enemy.cell, "id":-2})
	_hit_player(enemy)
	return true

func archer_aim(enemy: Dictionary) -> bool:
	if phase != Phase.ENEMY or enemy.hp <= 0 or enemy.ap <= 0:
		return false
	enemy.ap -= 1
	enemy.state = "aim"
	enemy.intent = "構え"
	add_log("弓兵が弓を構えた")
	return true

## The arrow hits the first unit on the lane: the player, an ally or another enemy.
func archer_shoot(enemy: Dictionary) -> bool:
	if phase != Phase.ENEMY or enemy.hp <= 0 or enemy.ap <= 0 or enemy.state != "aim":
		return false
	enemy.ap -= 1
	enemy.state = "approach"
	enemy.intent = "射撃"
	var lane := archer_lane(enemy)
	var end: Vector2i = lane[-1] if not lane.is_empty() else enemy.cell
	for cell in lane:
		if cell == player.cell:
			end = cell
			_hit_player(enemy)
			break
		var other := enemy_at(cell)
		if not other.is_empty():
			end = cell
			damage_enemy(other,1)
			add_log("弓兵の矢が%sに当たった" % TYPES[other.type].name)
			break
		var ally := ally_at(cell)
		if not ally.is_empty():
			end = cell
			ally.hp -= 1
			events.append({"kind":"hit", "cell":cell, "id":ally.id})
			allies = allies.filter(func(unit: Dictionary) -> bool: return unit.hp > 0)
			break
	events.append({"kind":"arrow", "cell":end, "from":enemy.cell, "id":-2, "dir":CARDINALS[enemy.get("facing",3)]})
	check_outcome()
	return true

func _hit_player(enemy: Dictionary) -> void:
	player.hp -= 1
	events.append({"kind": "hit", "cell": player.cell, "id": -1, "by": enemy.id})
	add_log("%sの攻撃 / HP −1" % TYPES[enemy.type].name)
	check_outcome()

func turn_enemy(_enemy: Dictionary, _direction: int) -> bool:
	return false

func enemy_step(enemy: Dictionary, cell: Vector2i) -> bool:
	if phase != Phase.ENEMY or enemy.hp <= 0 or enemy.ap <= 0 or not inside(cell) or not enemy_offsets(enemy).has(cell-enemy.cell):
		return false
	if cell == player.cell:
		if enemy.type in RANGED:
			return false
		enemy.ap -= 1
		player.hp -= 1
		enemy.intent = "攻撃"
		events.append({"kind": "hit", "cell": cell, "id": -1, "by": enemy.id})
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
	# The bow cannot move, but fairies may be placed anywhere along its diagonal lines.
	var weapon_cells: Array[Vector2i] = bow_lines() if WEAPONS[weapon].get("ranged","") == "bishop" else targets()
	for y in range(board_size):
		for x in range(board_size):
			var cell := Vector2i(x,y)
			if cell == player.cell or blocked(cell):
				continue
			if not enemy_at(cell).is_empty() and item.target != ItemDefinition.Target.WEAPON_ANY:
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
	strike_guard = true
	struck_ids.clear()
	item.effect.new().apply(self, cell, direction)
	strike_guard = false
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

## While a fairy or cannon resolves, a big enemy covering several struck tiles is hit once.
var strike_guard := false
var struck_ids: Array = []

func damage_enemy(enemy: Dictionary, amount: int) -> void:
	if enemy.hp <= 0:
		return
	if strike_guard:
		if struck_ids.has(enemy.id):
			return
		struck_ids.append(enemy.id)
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
				fairy_turns.erase(cell)
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
		if enemy.hp > 0 and (enemy.cell == cell or (enemy.get("size", 1) > 1 and footprint(enemy).has(cell))):
			return enemy
	return {}

const DIAGONALS = [Vector2i(-1,-1), Vector2i(1,-1), Vector2i(1,1), Vector2i(-1,1)]

## Bow: diagonal lines like a bishop; only the first enemy (or cannon) on each line.
func bow_lines() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for direction in DIAGONALS:
		var cell: Vector2i = player.cell + direction
		while inside(cell):
			result.append(cell)
			if not enemy_at(cell).is_empty() or blocked(cell):
				break
			cell += direction
	return result

## Hammer: the struck tile, its two side tiles, and the three tiles beyond.
func hammer_area(target: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset in [Vector2i(0,0), Vector2i(0,-1), Vector2i(0,1), Vector2i(1,-1), Vector2i(1,0), Vector2i(1,1)]:
		if inside(target + offset):
			result.append(target + offset)
	return result

func targets() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if WEAPONS[weapon].get("ranged","") == "bishop":
		for cell in bow_lines():
			if not enemy_at(cell).is_empty() or not cannon_at(cell).is_empty():
				result.append(cell)
		return result
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
	if locked_slot >= 0 and locked_slot < owned_weapons.size() and owned_weapons[locked_slot] != index:
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
		strike_guard = true
		struck_ids.clear()
		fire_cannon(cannon)
		strike_guard = false
		check_outcome()
		return true
	if blocked(cell):
		return false
	events.clear()
	player.ap -= 1
	var enemy := enemy_at(cell)
	if not enemy.is_empty():
		var struck: Array = [enemy]
		if WEAPONS[weapon].id == "hammer":
			events.append({"kind":"quake", "cell":cell, "id":-2, "cells":hammer_area(cell)})
			for area_cell in hammer_area(cell):
				var other := enemy_at(area_cell)
				if not other.is_empty() and not struck.has(other):
					struck.append(other)
		elif WEAPONS[weapon].get("ranged","") == "bishop":
			events.append({"kind":"arrow", "cell":cell, "from":player.cell, "id":-2})
		for target in struck:
			target.hp -= weapon_damage(weapon)
			events.append({"kind": "hit", "cell": target.cell, "id": target.id})
			add_log("%sで%sを攻撃" % [WEAPONS[weapon].short, TYPES[target.type].name])
			if target.hp <= 0:
				kills += 1
				add_log("%sを撃破" % TYPES[target.type].name)
			elif Catalog.knockback(weapon) > 0:
				var away := Vector2i(signi(cell.x - player.cell.x), signi(cell.y - player.cell.y))
				knock_back(target, away, Catalog.knockback(weapon))
	elif WEAPONS[weapon].get("ranged","") == "bishop":
		return false
	else:
		player.cell = cell
		trigger_mine(player)
		shadow_strike()
	check_outcome()
	return true

## Shove an enemy `tiles` squares. Blocked by the edge, terrain, a cannon, the
## player or another enemy, it slams into it: 1 damage (and 1 to an enemy it hits).
func knock_back(enemy: Dictionary, direction: Vector2i, tiles: int) -> void:
	var big: bool = int(enemy.get("size", 1)) > 1
	if direction == Vector2i.ZERO or (big and direction.x != 0 and direction.y != 0):
		return
	for step in tiles:
		var front: Array[Vector2i] = [enemy.cell + direction]
		if big:
			front = _front_cells(enemy, direction)
		var obstacle := {}
		var stopped := false
		for cell in front:
			if not inside(cell) or blocked(cell) or cell == player.cell:
				stopped = true
			elif not enemy_at(cell).is_empty() and enemy_at(cell).id != enemy.id:
				stopped = true
				obstacle = enemy_at(cell)
		if stopped:
			events.append({"kind":"bump", "cell":enemy.cell, "id":-2, "dir":direction})
			add_log("%sが叩きつけられた" % TYPES[enemy.type].name)
			damage_enemy(enemy, 1)
			if not obstacle.is_empty():
				damage_enemy(obstacle, 1)
			return
		enemy.cell += direction
		events.append({"kind":"push", "cell":enemy.cell, "id":-2, "dir":direction})
		trigger_mine(enemy)
		if enemy.hp <= 0:
			return

func weapon_damage(index: int) -> int:
	return Catalog.base_damage(index) + int(weapon_power.get(index, 0))

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
	_release_prisoners()
	allies = allies.filter(func(unit: Dictionary) -> bool: return unit.hp > 0)
	enemies = enemies.filter(func(e: Dictionary) -> bool: return e.hp > 0)
	if not enemies.any(func(e: Dictionary) -> bool: return e.type == "slot"):
		locked_slot = -1
		floor_cells.clear()
	if player.hp <= 0:
		phase = Phase.LOST
	elif enemies.all(func(e: Dictionary) -> bool: return e.type == "shadow"):
		# Shadows are traps, not foes: the fight ends with the boss.
		enemies.clear()
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
	events.append({"kind":"summon", "cell":cell, "id":-2, "fx":"acorn"})

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
	events.append({"kind":"summon", "cell":cell, "id":-2, "fx":"wall"})

## Called when a new player turn begins: walls count down and crumble.
func tick_walls() -> void:
	for cell in walls.keys():
		walls[cell] -= 1
		if walls[cell] <= 0:
			walls.erase(cell)
			add_log("壁精霊が消えた")
	for cannon in cannons.duplicate():
		cannon.turns = int(cannon.get("turns", WALL_TURNS)) - 1
		if cannon.turns <= 0:
			cannons.erase(cannon)
			add_log("%sが消えた" % CANNON_TITLES[cannon.kind])
	for cell in fairy_turns.keys():
		fairy_turns[cell] -= 1
		if fairy_turns[cell] <= 0:
			fairy_turns.erase(cell)
			fairies.erase(cell)
			add_log("隠密妖精が消えた")

func place_stealth(cell: Vector2i) -> void:
	fairies.append(cell)
	fairy_turns[cell] = WALL_TURNS

func cannon_at(cell: Vector2i) -> Dictionary:
	for cannon in cannons:
		if cannon.cell == cell:
			return cannon
	return {}

func place_cannon(cell: Vector2i, direction: Vector2i, kind: String) -> void:
	cannons.append({"cell":cell, "dir":direction, "kind":kind, "turns":WALL_TURNS, "charge":0})
	events.append({"kind":"summon", "cell":cell, "id":-2, "fx":"cannon"})

## Fire a cannon. A shot or burst that reaches another cannon sets it off too.
func fire_cannon(cannon: Dictionary, fired: Array = []) -> void:
	if fired.has(cannon.cell):
		return
	fired.append(cannon.cell)
	if cannon.kind == "capacitor":
		_charge_capacitor(cannon, fired)
		return
	add_log("%sが発射" % CANNON_TITLES[cannon.kind])
	if cannon.kind == "firework":
		# The burst does not pick sides: enemies, allies and the player all take 1.
		cannons.erase(cannon)
		events.append({"kind":"firework", "cell":cannon.cell, "id":-2})
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var cell: Vector2i = cannon.cell + Vector2i(dx, dy)
				if cell == cannon.cell or not inside(cell):
					continue
				events.append({"kind":"blast", "cell":cell, "id":-2, "from":cannon.cell})
				var enemy := enemy_at(cell)
				if not enemy.is_empty():
					damage_enemy(enemy, 1)
				if cell == player.cell:
					player.hp -= 1
					events.append({"kind":"hit", "cell":cell, "id":-1})
					add_log("花火に巻き込まれた / HP −1")
				var ally := ally_at(cell)
				if not ally.is_empty():
					ally.hp -= 1
					events.append({"kind":"hit", "cell":cell, "id":ally.id})
				var other := cannon_at(cell)
				if not other.is_empty():
					fire_cannon(other, fired)
		return
	var shot_dir: Vector2i = cannon.dir
	var passed: Array = []
	var cells := cannon_line(cannon.cell, shot_dir, passed)
	events.append({"kind":"muzzle", "cell":cannon.cell, "id":-2, "dir":shot_dir})
	for cell in cells:
		events.append({"kind":"shot", "cell":cell, "id":-2, "dir":shot_dir})
		var enemy := enemy_at(cell)
		if not enemy.is_empty():
			damage_enemy(enemy, 1)
	if cannon.kind == "vane":
		cannon.dir = CARDINALS[(CARDINALS.find(cannon.dir) + 1) % 4]
	_resonate(passed, fired)

## A cannon shot's path: it flies through other cannons (collected in `passed`,
## which then resonate) and stops only at walls, obstacles, allies or the edge.
func cannon_line(origin: Vector2i, direction: Vector2i, passed: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not CARDINALS.has(direction):
		return result
	var cell := origin + direction
	while inside(cell):
		var other := cannon_at(cell)
		if not other.is_empty():
			passed.append(other)
		elif blocked(cell):
			break
		result.append(cell)
		cell += direction
	return result

## Cannons a shot passed through fire too, each in its own way.
func _resonate(passed: Array, fired: Array) -> void:
	for other in passed:
		if cannons.has(other) and not fired.has(other.cell):
			events.append({"kind":"resonate", "cell":other.cell, "id":-2})
			fire_cannon(other, fired)

## Capacitor: every strike (a weapon or a chained cannon shot) stores 1; at 3 it
## discharges down all four lines, then starts charging again.
func _charge_capacitor(cannon: Dictionary, fired: Array) -> void:
	cannon.charge = int(cannon.get("charge", 0)) + 1
	events.append({"kind":"spark", "cell":cannon.cell, "id":-2})
	if cannon.charge < CAPACITOR_FULL:
		add_log("蓄電の妖精に電気が溜まった（%d/%d）" % [cannon.charge, CAPACITOR_FULL])
		return
	cannon.charge = 0
	add_log("蓄電の妖精が放電！")
	var passed: Array = []
	for direction in CARDINALS:
		for cell in cannon_line(cannon.cell, direction, passed):
			events.append({"kind":"zap", "cell":cell, "id":-2, "dir":direction})
			var enemy := enemy_at(cell)
			if not enemy.is_empty():
				damage_enemy(enemy, 1)
	_resonate(passed, fired)

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

## 斬撃精霊: the two tiles to the left and right of where it is placed.
func side_slash_cells(origin: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for side in [Vector2i.LEFT, Vector2i.RIGHT]:
		if inside(origin + side):
			result.append(origin + side)
	return result

func side_slash(origin: Vector2i) -> void:
	_slash_hit(side_slash_cells(origin), Vector2i.RIGHT)

func front_slash(origin: Vector2i, direction: Vector2i) -> void:
	_slash_hit(front_slash_cells(origin, direction), direction)

## 飛刃精霊 (the slash's class-up): the three-lane wave flies to the edge.
func slash(origin: Vector2i, direction: Vector2i) -> void:
	_slash_hit(slash_cells(origin, direction), direction)

func _slash_hit(cells: Array[Vector2i], direction: Vector2i) -> void:
	for cell in cells:
		events.append({"kind":"slash", "cell":cell, "id":-2, "dir":direction})
		var enemy := enemy_at(cell)
		if not enemy.is_empty():
			damage_enemy(enemy, 1)

## Cells a directional fairy will affect, for the placement preview.
func directional_preview(id: String, origin: Vector2i, direction: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	# A spirit placed on an enemy also strikes the enemy under it.
	if not enemy_at(origin).is_empty():
		result.append(origin)
	if id == "slash_fairy":
		result.append_array(front_slash_cells(origin, direction))
	elif id == "flying_slash":
		result.append_array(slash_cells(origin, direction))
	elif id in ["cannon_fairy", "vane_cannon"]:
		result.append_array(cannon_line(origin, direction, []))
	else:
		result.append_array(ray_cells(origin, direction))
	return result

## Bolt and slash spirits placed on an enemy hit it first.
func strike_under(cell: Vector2i, kind: String, direction: Vector2i) -> void:
	var enemy := enemy_at(cell)
	if not enemy.is_empty():
		events.append({"kind":kind, "cell":cell, "id":-2, "dir":direction})
		damage_enemy(enemy, 1)


# --- two-by-two bosses -------------------------------------------------------

## A broken moving prison lets out two executioners on a diagonal of its footprint.
func _release_prisoners() -> void:
	for prison in enemies.duplicate():
		if prison.type != "prison" or prison.hp > 0 or prison.get("released", false):
			continue
		prison.released = true
		var pairs := [[Vector2i(0,0), Vector2i(1,1)], [Vector2i(1,0), Vector2i(0,1)]]
		var spots: Array[Vector2i] = []
		for pair in pairs:
			spots.clear()
			for offset in pair:
				var cell: Vector2i = prison.cell + offset
				if cell != player.cell and not blocked(cell) and enemy_at(cell).is_empty():
					spots.append(cell)
			if spots.size() == 2:
				break
		var next_id := 0
		for enemy in enemies:
			next_id = maxi(next_id, int(enemy.id) + 1)
		for cell in spots:
			var guard := make_enemy("executioner", cell, next_id)
			guard.facing = prison.facing
			guard.ap = 0
			enemies.append(guard)
			events.append({"kind":"summon", "cell":cell, "id":-2, "fx":"prison"})
			next_id += 1
		add_log("移動監獄が壊れ、執行兵が現れた")

## Boss entrance: every blue rook turns red and aims before the player's first turn.
func boss_intro() -> bool:
	var any := false
	events.clear()
	for enemy in enemies:
		if enemy.type in CHARGERS and enemy.state == "idle":
			rook_brace(enemy)
			if enemy.type == "slot":
				slot_spin(enemy)
			events.append({"kind":"roar", "cell":enemy.cell + Vector2i.ONE, "id":-2})
			any = true
	if any:
		add_log("ボスが構えた！")
	return any

## Rook: face the player. Aligned with its two rows/columns it aims straight at them.
func rook_brace(enemy: Dictionary) -> void:
	var rows := [enemy.cell.y, enemy.cell.y + 1]
	var cols := [enemy.cell.x, enemy.cell.x + 1]
	var direction: Vector2i
	if rows.has(player.cell.y):
		direction = Vector2i.RIGHT if player.cell.x > enemy.cell.x else Vector2i.LEFT
	elif cols.has(player.cell.x):
		direction = Vector2i.DOWN if player.cell.y > enemy.cell.y else Vector2i.UP
	else:
		var dx: float = player.cell.x - (enemy.cell.x + 0.5)
		var dy: float = player.cell.y - (enemy.cell.y + 0.5)
		if absf(dx) >= absf(dy):
			direction = Vector2i.RIGHT if dx > 0 else Vector2i.LEFT
		else:
			direction = Vector2i.DOWN if dy > 0 else Vector2i.UP
	enemy.facing = CARDINALS.find(direction)
	enemy.state = "brace"
	enemy.intent = "突進構え"

## Tiles a braced rook will sweep, lane by lane, until the edge or terrain.
func rook_lane(enemy: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var forward: Vector2i = CARDINALS[enemy.facing]
	var cells := footprint(enemy)
	for start in cells:
		if cells.has(start + forward):
			continue
		var cell: Vector2i = start + forward
		while inside(cell) and not arrow_stopped(cell):
			result.append(cell)
			cell += forward
	return result

func _front_cells(enemy: Dictionary, forward: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var cells := footprint(enemy)
	for cell in cells:
		if not cells.has(cell + forward):
			result.append(cell + forward)
	return result

## Charge like a rook. A player in the lane is hit once and shoved to the wall with it.
## A player who dodged is chased along the lane until they share an axis, then it re-aims.
func rook_charge(enemy: Dictionary) -> bool:
	if phase != Phase.ENEMY or enemy.hp <= 0 or enemy.ap <= 0 or enemy.state != "brace":
		return false
	enemy.ap -= 1
	var forward: Vector2i = CARDINALS[enemy.facing]
	var side := Vector2i(absi(forward.y), absi(forward.x))
	var in_lane := func() -> bool:
		var across: int = player.cell.x if side.x == 1 else player.cell.y
		var base: int = enemy.cell.x if side.x == 1 else enemy.cell.y
		return across == base or across == base + 1
	var ramming: bool = in_lane.call()
	var hit := false
	var pushed := false
	var steps := 0
	while steps < board_size * 2:
		steps += 1
		var front := _front_cells(enemy, forward)
		var stop := false
		for cell in front:
			if not inside(cell) or arrow_stopped(cell) or not ally_at(cell).is_empty() or fairies.has(cell):
				stop = true
			elif not enemy_at(cell).is_empty() and enemy_at(cell).id != enemy.id:
				stop = true
		if stop:
			break
		if front.has(player.cell):
			if not hit:
				hit = true
				_hit_player(enemy)
				if terminal():
					break
			var shove: Vector2i = player.cell + forward
			if not inside(shove) or blocked(shove) or not enemy_at(shove).is_empty():
				break
			player.cell = shove
			pushed = true
		events.append({"kind":"dash", "cell":enemy.cell, "id":-2, "dir":forward})
		enemy.cell += forward
		if not ramming and in_lane_perpendicular(enemy, forward):
			break
	if pushed and not terminal():
		trigger_mine(player)
	add_log("%sの突進" % TYPES[enemy.type].name + ("！ 壁まで押し込まれた" if hit else ""))
	check_outcome()
	if not terminal() and enemy.hp > 0:
		rook_brace(enemy)
	return true

## True once the player shares the rook's other axis (it can turn and aim at them).
func in_lane_perpendicular(enemy: Dictionary, forward: Vector2i) -> bool:
	if forward.x != 0:
		return player.cell.x == enemy.cell.x or player.cell.x == enemy.cell.x + 1
	return player.cell.y == enemy.cell.y or player.cell.y == enemy.cell.y + 1

## Moving prison: slides its whole footprint one tile; stepping into the player attacks.
func big_step(enemy: Dictionary, forward: Vector2i) -> bool:
	if phase != Phase.ENEMY or enemy.hp <= 0 or enemy.ap <= 0:
		return false
	var front := _front_cells(enemy, forward)
	if front.has(player.cell):
		enemy.ap -= 1
		enemy.facing = CARDINALS.find(forward)
		_hit_player(enemy)
		return true
	for cell in front:
		if not inside(cell) or blocked(cell) or mines.has(cell) or not enemy_at(cell).is_empty():
			return false
	enemy.ap -= 1
	enemy.facing = CARDINALS.find(forward)
	enemy.cell += forward
	trigger_fairies()
	check_outcome()
	return true

func footprint_distance(enemy: Dictionary, target: Vector2i) -> int:
	var best := 999
	for cell in footprint(enemy):
		best = mini(best, distance(cell, target))
	return best


# --- Rotorick: the slot boss --------------------------------------------------

const REEL_WEIGHTS = {1: 2, 2: 2, 3: 2, 4: 2, 5: 2, 6: 2, 7: 1}

## Draws the next reel (never the same number twice in a row; 7 is rarer).
func slot_roll(enemy: Dictionary) -> int:
	var pool: Array = []
	for reel in REEL_WEIGHTS:
		if reel != int(enemy.get("last_reel", 0)):
			for i in REEL_WEIGHTS[reel]:
				pool.append(reel)
	var pick: int = absi(hash([slot_seed, slot_rolls])) % pool.size()
	slot_rolls += 1
	return pool[pick]

## Spin after acting (0 AP): the result is shown for the whole player turn.
func slot_spin(enemy: Dictionary) -> void:
	var reel := slot_roll(enemy)
	enemy.reel = reel
	enemy.last_reel = reel
	match reel:
		1, 2, 3:
			if reel - 1 < owned_weapons.size():
				locked_slot = reel - 1
				weapon = owned_weapons[locked_slot]
		4:
			floor_cells.clear()
			var parity: int = (enemy.cell.x + enemy.cell.y) % 2
			for y in range(board_size):
				for x in range(board_size):
					if (x + y) % 2 == parity:
						floor_cells.append(Vector2i(x, y))
		5:
			enemy.state = "stun"
	enemy.intent = "出目 %d" % reel
	add_log("ロトリックの出目：%d" % reel)

## Enemy turn: resolve the shown reel, charge, then spin again.
func slot_turn(enemy: Dictionary) -> void:
	if phase != Phase.ENEMY or enemy.hp <= 0:
		return
	_burn_floor(enemy)
	if terminal():
		return
	match int(enemy.reel):
		5:
			# The reel jammed: no charge this turn, no damage to itself.
			enemy.ap = 0
			add_log("ロトリック：再起動中")
			rook_brace(enemy)
		6:
			_leave_shadow(enemy)
			rook_charge(enemy)
		7:
			enemy.ap = 2
			_sure_charge(enemy)
			if enemy.ap > 0 and not terminal() and enemy.hp > 0:
				rook_charge(enemy)
		_:
			rook_charge(enemy)
	shadow_strike()
	if not terminal() and enemy.hp > 0:
		if enemy.state != "brace":
			rook_brace(enemy)
		slot_spin(enemy)

func _burn_floor(enemy: Dictionary) -> void:
	if floor_cells.is_empty():
		return
	for cell in floor_cells:
		events.append({"kind":"burn", "cell":cell, "id":-2})
		if player.cell == cell:
			_hit_player(enemy)
		var other := enemy_at(cell)
		if not other.is_empty() and other.type not in ["slot", "shadow"]:
			damage_enemy(other, 1)
		var ally := ally_at(cell)
		if not ally.is_empty():
			ally.hp -= 1
			events.append({"kind":"hit", "cell":cell, "id":ally.id})
	add_log("刑場の床が焼けた")
	floor_cells.clear()
	check_outcome()

## Reel 7: the first charge always reaches the player (walls and blockers still stop it).
func _sure_charge(enemy: Dictionary) -> void:
	var before: int = player.hp
	rook_charge(enemy)
	for attempt in 3:
		if player.hp < before or terminal() or enemy.hp <= 0:
			return
		# The homing follow-up is part of the same sure strike, so it costs no extra AP.
		var from: Vector2i = enemy.cell
		enemy.ap += 1
		rook_charge(enemy)
		if enemy.cell == from:
			return

## Reel 6: a stealth fairy leaves a shadow of Rotorick where it stood.
func _leave_shadow(enemy: Dictionary) -> void:
	for old in enemies:
		if old.type == "shadow":
			old.hp = 0
	var next_id := 0
	for other in enemies:
		next_id = maxi(next_id, int(other.id) + 1)
	var shadow := make_enemy("shadow", enemy.cell, next_id)
	shadow.ap = 0
	shadow.state = "lurk"
	enemies.append(shadow)
	events.append({"kind":"summon", "cell":enemy.cell + Vector2i.ONE, "id":-2, "fx":"stealth"})
	add_log("隠密妖精がロトリックの影を残した")

## A shadow cuts a player who stands next to it, once, then fades.
func shadow_strike() -> void:
	for shadow in enemies:
		if shadow.type != "shadow" or shadow.hp <= 0:
			continue
		var cells := footprint(shadow)
		for cell in cells:
			for direction in CARDINALS:
				if cell + direction == player.cell and not cells.has(player.cell):
					shadow.hp = 0
					events.append({"kind":"slash", "cell":player.cell, "id":-2, "dir":direction})
					_hit_player(shadow)
					break
			if shadow.hp <= 0:
				break
	check_outcome()
