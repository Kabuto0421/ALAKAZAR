extends RefCounted
## Rules for the rook boss stage, independent of rendering.
##
## The boss is a 2x2 piece that moves like a rook. Each of its turns is one of:
##   stunned  -> recover (it crashed into a wall last turn)
##   braced   -> charge along the locked lane until the wall or the player
##   adjacent -> swing at the player on any side (4-direction melee)
##   else     -> dash along one axis to put the player in its 2-wide lane, then brace

enum Phase { BOSS, PLAYER, WON, LOST }
enum State { IDLE, BRACE, STUN }
const SIZE := 6
const CARDINALS = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const Gold = preload("res://scripts/movement/shogi_gold_move.gd")
const Silver = preload("res://scripts/movement/shogi_silver_move.gd")
const Knight = preload("res://scripts/movement/shogi_knight_move.gd")
## Same order as battle_model.gd WEAPONS: 0 gold, 1 silver, 2 knight.
const WEAPON_NAMES = ["金 / ハンマー", "銀 / ソード", "桂 / アックス"]
const WEAPON_ROWS = [0, 2, 1]
const BOSS_HP := 12
const CHARGE_DAMAGE := 2
const MELEE_DAMAGE := 1
const STUNNED_HIT_DAMAGE := 2

var patterns: Array = [Gold.new(), Silver.new(), Knight.new()]
var phase: Phase = Phase.BOSS
var round_number := 0
var player := {}
var weapon := 1
var facing := 0
var boss := {}
var logs: Array[String] = []
## What the last boss turn did, for the view: {kind, from, to, hit}.
var last_boss_action: Dictionary = {}

func reset() -> void:
	phase = Phase.BOSS
	round_number = 0
	player = {"cell": Vector2i(0, 5), "hp": 5, "ap": 0}
	weapon = 1
	facing = 0
	boss = {"origin": Vector2i(2, 0), "hp": BOSS_HP, "state": State.IDLE, "facing": 2, "charge_dir": Vector2i.DOWN}
	logs.clear()
	last_boss_action = {}
	add_log("飛車の大将が現れた。")

# --- geometry -------------------------------------------------------------

func inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < SIZE and cell.y >= 0 and cell.y < SIZE

func boss_cells(origin: Vector2i = boss.origin) -> Array[Vector2i]:
	return [origin, origin + Vector2i(1, 0), origin + Vector2i(0, 1), origin + Vector2i(1, 1)]

func is_boss_cell(cell: Vector2i) -> bool:
	return boss_cells().has(cell)

func boss_fits(origin: Vector2i) -> bool:
	return origin.x >= 0 and origin.y >= 0 and origin.x + 1 < SIZE and origin.y + 1 < SIZE

## Cells orthogonally adjacent to the 2x2 body (the 4-direction melee reach).
func melee_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in boss_cells():
		for d in CARDINALS:
			var n: Vector2i = cell + d
			if inside(n) and not is_boss_cell(n) and not result.has(n):
				result.append(n)
	return result

func in_lane(cell: Vector2i, origin: Vector2i = boss.origin) -> bool:
	var cols := cell.x == origin.x or cell.x == origin.x + 1
	var rows := cell.y == origin.y or cell.y == origin.y + 1
	return cols or rows

## Cells the locked charge will sweep (for the telegraph), wall to wall.
func charge_lane() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if boss.state != State.BRACE:
		return result
	var origin: Vector2i = boss.origin
	while boss_fits(origin + boss.charge_dir):
		origin += boss.charge_dir
		for cell in boss_cells(origin):
			if not is_boss_cell(cell) and not result.has(cell):
				result.append(cell)
	return result

# --- player ---------------------------------------------------------------

func targets() -> Array[Vector2i]:
	return targets_for(weapon, facing)

func targets_for(weapon_index: int, direction_index: int) -> Array[Vector2i]:
	return patterns[weapon_index].get_destinations(player.cell, inside, CARDINALS[direction_index])

func player_action(cell: Vector2i) -> bool:
	if phase != Phase.PLAYER or player.ap <= 0 or not targets().has(cell):
		return false
	player.ap -= 1
	if is_boss_cell(cell):
		var damage := STUNNED_HIT_DAMAGE if boss.state == State.STUN else 1
		boss.hp -= damage
		add_log("大将に%dダメージ%s" % [damage, "（気絶中）" if damage > 1 else ""])
	else:
		player.cell = cell
	_check_outcome()
	return true

func turn_to(direction_index: int) -> bool:
	if phase != Phase.PLAYER or player.ap <= 0 or direction_index == facing:
		return false
	facing = direction_index
	player.ap -= 1
	return true

func equip(index: int) -> bool:
	if phase != Phase.PLAYER or player.ap <= 0 or index == weapon:
		return false
	weapon = index
	player.ap -= 1
	return true

func end_player_turn() -> void:
	if phase == Phase.PLAYER:
		phase = Phase.BOSS

# --- boss -----------------------------------------------------------------

func boss_turn() -> void:
	if phase != Phase.BOSS:
		return
	round_number += 1
	var start: Vector2i = boss.origin
	last_boss_action = {"kind": "wait", "from": start, "to": start, "hit": false}
	match boss.state:
		State.STUN:
			boss.state = State.IDLE
			last_boss_action.kind = "recover"
			add_log("大将が立ち上がる")
		State.BRACE:
			_charge()
		_:
			if melee_cells().has(player.cell):
				player.hp -= MELEE_DAMAGE
				last_boss_action = {"kind": "melee", "from": start, "to": start, "hit": true}
				add_log("大将の薙ぎ払い / HP −%d" % MELEE_DAMAGE)
			else:
				_align_and_brace()
	_check_outcome()
	if phase == Phase.BOSS:
		phase = Phase.PLAYER
		player.ap = 2

func _charge() -> void:
	var dir: Vector2i = boss.charge_dir
	var origin: Vector2i = boss.origin
	var hit := false
	while boss_fits(origin + dir):
		if boss_cells(origin + dir).has(player.cell):
			hit = true
			break
		origin += dir
	boss.origin = origin
	last_boss_action = {"kind": "charge", "from": last_boss_action.from, "to": origin, "hit": hit}
	if hit:
		player.hp -= CHARGE_DAMAGE
		boss.state = State.IDLE
		add_log("突進が直撃 / HP −%d" % CHARGE_DAMAGE)
	else:
		boss.state = State.STUN
		add_log("大将が壁に激突し、気絶した")

func _align_and_brace() -> void:
	var p: Vector2i = player.cell
	var origin: Vector2i = boss.origin
	if not in_lane(p, origin):
		# Rook dash along one axis; pick the shorter slide that puts the player in the lane.
		var ox := clampi(p.x if p.x > origin.x else p.x - 1, 0, SIZE - 2)
		var oy := clampi(p.y if p.y > origin.y else p.y - 1, 0, SIZE - 2)
		var horizontal := Vector2i(ox, origin.y)
		var vertical := Vector2i(origin.x, oy)
		origin = horizontal if absi(ox - origin.x) <= absi(oy - origin.y) else vertical
		boss.origin = origin
	var dir := _direction_to(p, origin)
	boss.charge_dir = dir
	boss.facing = CARDINALS.find(dir)
	boss.state = State.BRACE
	last_boss_action = {"kind": "brace", "from": last_boss_action.from, "to": origin, "hit": false}
	add_log("大将が構えた！ 次のターンに突進")

func _direction_to(p: Vector2i, origin: Vector2i) -> Vector2i:
	if p.x == origin.x or p.x == origin.x + 1:
		return Vector2i.DOWN if p.y > origin.y else Vector2i.UP
	return Vector2i.RIGHT if p.x > origin.x else Vector2i.LEFT

func _check_outcome() -> void:
	if player.hp <= 0:
		phase = Phase.LOST
	elif boss.hp <= 0:
		phase = Phase.WON

func terminal() -> bool:
	return phase == Phase.WON or phase == Phase.LOST

func add_log(message: String) -> void:
	logs.push_front(message)
	if logs.size() > 6:
		logs.resize(6)
