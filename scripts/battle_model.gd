extends RefCounted

# Grid rules are independent of rendering and animation timing.
enum Phase { ENEMY, PLAYER, WON, LOST }
const ItemDefinition = preload("res://scripts/items/item_definition.gd")
const ITEMS = [preload("res://items/magic_bolt.tres"), preload("res://items/stealth_fairy.tres"), preload("res://items/warp_fairy.tres"), preload("res://items/acorn_fairy.tres"),
	preload("res://items/wall_fairy.tres"), preload("res://items/cannon_fairy.tres"), preload("res://items/vane_cannon.tres"), preload("res://items/firework_fairy.tres"), preload("res://items/slash_fairy.tres"),
	preload("res://items/capacitor_fairy.tres"), preload("res://items/axe_spirit.tres"), preload("res://items/holy_spirit.tres"),
	preload("res://items/shadow_stitch.tres"), preload("res://items/lone_wolf.tres"), preload("res://items/abyss_spirit.tres"),
	preload("res://items/gravity_fairy.tres"),
	preload("res://items/glutton_fairy.tres"), preload("res://items/freeze_fairy.tres"), preload("res://items/blessing_fairy.tres"),
	preload("res://items/meteor_fairy.tres"), preload("res://items/guardian_fairy.tres"), preload("res://items/time_fairy.tres")]
## Rare 2x2 fairies: they need a free 2x2 block that includes the chosen tile.
const BIG_FAIRIES = ["axe_spirit", "holy_spirit", "guardian_fairy"]
## Ally unit types, for logs (enemies use TYPES).
## The two knights a broken holy spirit leaves: HP 2, AP 2 (like the executioner).
const HOLY_KNIGHT_HP := 2
const HOLY_KNIGHT_AP := 2
const ALLY_NAMES = {"acorn": "どんぐり妖精", "holy": "聖精霊", "holy_knight": "聖騎士", "wolf": "一匹狼の妖精", "glutton": "暴食妖精", "guardian": "守護神"}
## Summoned allies, by fairy: HP, AP and HP once classed up. The summons, the reward
## cards, the ally panel and every text that quotes these numbers read them from here.
const SUMMON_STATS := {
	"acorn_fairy": {"hp": 1, "ap": 1, "hp_plus": 2},
	"glutton_fairy": {"hp": 1, "ap": 2, "hp_plus": 1},
	"guardian_fairy": {"hp": 3, "ap": 1, "hp_plus": 4},
	"holy_spirit": {"hp": 1, "ap": 1, "hp_plus": 1},
	"lone_wolf": {"hp": 3, "ap": 2, "hp_plus": 3},
}
## Which fairy each summoned ally type comes from.
const ALLY_FAIRY := {"acorn": "acorn_fairy", "glutton": "glutton_fairy", "guardian": "guardian_fairy", "holy": "holy_spirit", "wolf": "lone_wolf"}
## 守護神の妖精: HP added to every ally it calls back.
const GUARDIAN_BONUS_HP := 1
## 暴食妖精: HP gained per bite.
const GLUTTON_GROWTH := 1
## 一匹狼の妖精: a bite alone / with someone next to it.
const WOLF_BITE := 2
const WOLF_CROWDED_BITE := 1
## 重力妖精: pull reach and push distance (one more each, classed up).
const GRAVITY_PULL := 2
const GRAVITY_PUSH := 1
## 影縫い精霊: AP to swap with the shadow (one less classed up).
const SHADOW_SWAP_AP := 1
## 加護の妖精+: HP healed for ending the turn on the blessed ground.
const BLESS_HEAL := 1
## 時の妖精: enemy turns that time stands still for.
const TIME_STOP_TURNS := 1
## 奈落: what a charging 2x2 takes for stumbling over a pit.
## Class-ups beyond one: the meteor fairy can be upgraded four times.
const MAX_PLUS = {"meteor_fairy": 4}
## 氷結妖精: enemy turns a frozen enemy skips (one more upgraded).
const FREEZE_TURNS := 3
const METEOR_DAMAGE := 3
## Player turns a placed spirit (wall, cannons, stealth) stands, counting the turn it is placed.
const WALL_TURNS := 5
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
	"archer": {"name": "弓兵", "hp": 1, "ap": 2},
	"rook": {"name": "突進くん", "hp": 3, "ap": 1, "size": 2},
	"prison": {"name": "移動監獄", "hp": 1, "ap": 1, "size": 2},
	"executioner": {"name": "執行兵", "hp": 2, "ap": 2},
	"slot": {"name": "ロトリック", "hp": 7, "ap": 1, "size": 2},
	"shield": {"name": "盾兵", "hp": 1, "ap": 1},
	"analyst": {"name": "解析兵", "hp": 2, "ap": 1},
	"shadow": {"name": "ロトリックの残像", "hp": 1, "ap": 0, "size": 2},
	"silver": {"name": "銀将兵", "hp": 1, "ap": 2},
	"king": {"name": "監獄の王", "hp": 10, "ap": 1, "size": 3},
	"fortress": {"name": "要塞監獄", "hp": 3, "ap": 1, "size": 2},
	"gold": {"name": "金将兵", "hp": 2, "ap": 1},
}
## Final boss room: soldiers the fortresses send out and the king raises again (no bosses).
## How each soldier tends to act, in two short lines for the inspector (taken from the
## enemy planner: its "intent" and the rules it follows).
const HABITS := {
	"infantry": ["仲間と囲むように接近", "囲んだら突撃してくる"],
	"recruit": ["まっすぐ近づいて", "隣に来たら攻撃"],
	"heavy": ["毎ターン前進して", "隣に来たら攻撃"],
	"miner": ["近づくと離れる(距離3)", "2回目の行動で地雷設置"],
	"cavalry": ["跳んで接近し、", "着地した所を攻撃"],
	"horse": ["跳んで接近し、", "着地した所を攻撃"],
	"javelin": ["同じ列に来ると投擲。", "届く所まで歩いてくる"],
	"archer": ["照準を合わせ、次の", "ターンに左へ一直線"],
	"shield": ["盾を構えて前進。", "真左の攻撃は防ぐ"],
	"analyst": ["殴られた武器を覚え、", "同じ武器を無効化"],
	"gold": ["将棋の金の動きで", "近づいて攻撃"],
	"silver": ["将棋の銀の動きで", "近づいて攻撃"],
}
const SOLDIERS = ["infantry", "recruit", "heavy", "cavalry", "horse", "javelin", "archer", "shield", "analyst", "gold", "silver", "executioner", "miner"]
## Fixed in place: shoves, pulls, blasts and charges cannot move them.
const IMMOVABLE = ["king", "fortress"]
## At this HP or below the Prison King is enraged: each fortress sends out two a turn.
const KING_REVIVE_EVERY := 2
const KING_RAGE_HP := 5
## Shogi generals: they always face left (towards where the player starts).
const GENERALS = ["gold", "silver"]
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
	preload("res://scenes/formations/run_late_01.tscn"),
	preload("res://scenes/formations/run_late_02.tscn"),
	preload("res://scenes/formations/run_late_03.tscn"),
	preload("res://scenes/formations/run_final.tscn"),
]
const BOSS_LEVEL := 3
## The second boss (Rotorick) after the mid-game camp.
const BOSS2_LEVEL := 7
const BOSS_LEVELS = [3, 7, 11]
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
## Late-game fights after Rotorick; a camp follows and ends the run (no boss yet).
const LATE_LEVELS = [8, 9, 10]
## The final boss, the Prison King, on a 10x10 board after the last camp.
const FINAL_LEVEL := 11
const LAST_LEVEL := 11
var board_size := 4
var owned_weapons: Array[int] = [0,1,2]
var fairy_loadout: Array[String] = ["magic_bolt"]
var fairy_charges: Array[int] = []
## HP the player starts this fight with; the run carries it between fights.
var start_hp := MAX_HP
## Camp forging: weapon index -> extra damage (each weapon can be forged once).
var weapon_power: Dictionary = {}
## Weapon enchantments: weapon index -> "circle" (the magic circle).
var enchants: Dictionary = {}
## Magic circle: tiles the player has walked over with a circle weapon (they stay all fight).
var circle_tiles: Array[Vector2i] = []
const CIRCLE_DAMAGE := 99
## 溜め大剣: extra damage stored by turns it was not used (reset when it hits).
var blade_charge := 0
var blade_used := false
## Forged swap weapons (入替の杖・王将の杖): the first swap each turn costs no AP.
var free_swap_used := false
const BLADE_MAX := 2
## Forged, it stores one more (its hits then run 2 up to 5).
const BLADE_MAX_FORGED := 3

## How much the 溜め大剣 can store right now (more once forged).
func blade_max() -> int:
	for index in owned_weapons:
		if WEAPONS[index].has("charge"):
			return BLADE_MAX_FORGED if weapon_power.has(index) else BLADE_MAX
	return BLADE_MAX
## Camp class-ups: fairy id -> true. Upgraded fairies show a yellow "+".
var fairy_plus: Dictionary = {}
## Class-ups: [the short line, the full text]. {name}s are filled by fairy_text().
const PLUS_TEXT := {
	"magic_bolt": ["前後の直線上の敵すべてに1", "攻撃範囲に配置（敵の上なら\nその敵にも1）。\n選んだ向きとその反対向きの\n直線上の敵すべてに1。"],
	"stealth_fairy": ["刺しても消えない", "攻撃範囲の空きマスに配置。\n隠密中は通行をふさぐ。\n縦横に隣接した敵1体に{stealth}。\n刺しても消えず{turns}ターン残る\n（1ターンに1回）。"],
	"acorn_fairy": ["HP{hp_plus}・斜めも攻撃する味方", "攻撃範囲の空きマスに召喚。\nHP{hp_plus}・AP{ally_ap}、縦横斜め1マス。\nターン終了後、敵より先に行動。\n隣の大砲は叩いて撃たせる。"],
	"warp_fairy": ["毎戦闘{uses_plus}回ワープできる", "敵や障害物のないマスへ\nプレイヤーが瞬間移動。\n距離の制限なし。\n着地先の地雷は踏む。"],
	"wall_fairy": ["{turns}ターン残る3マスの壁", "攻撃範囲の空きマスから、選んだ\n向きへ一直線に3マスの壁を置く。\n置いたターンを含め{turns}ターン\n完全な障害物として残る。"],
	"cannon_fairy": ["{cost_plus} APで置ける・毎戦闘{uses_plus}回", "攻撃範囲の空きマスに設置し、\n縦横の向きを決める。\nこのマスを攻撃すると、その\n向きの直線上の敵すべてに1。"],
	"vane_cannon": ["叩くと2連射になる", "設置してこのマスを攻撃すると\n向きの直線上に2連射（各1）。\n撃つたびに向きが時計回りに\n90度回る。他の大砲も誘爆。"],
	"firework_fairy": ["叩くと周囲8マスの敵に爆発", "攻撃範囲の空きマスに設置。\n攻撃すると爆発して消える。\n周囲8マスの敵に1ダメージ。\n自分と味方は巻き込まない。"],
	"shadow_stitch": ["置くのも入れ替わりも{cost_plus} AP", "全武器の範囲外の空きマスに\n影を縫い止める。{turns}ターン残る。\n{swap_ap_plus} APで影と入れ替わる\n（1ターン1回）。"],
	"lone_wolf": ["{cost_plus} APで呼べる", "攻撃範囲内の空きマスに\n召喚。HP{hp_plus}・AP{ally_ap}。銀の動きで\n1歩ずつ近づき、届く敵に噛む。\n単独で{wolf_bite}、隣に誰かいると{wolf_crowded}。\n武器が届く所ではすねる。"],
	"glutton_fairy": ["{cost_plus} APで呼べる", "攻撃範囲に召喚。HP{hp_plus}・AP{ally_ap}。\n金の動き・右向き固定。\n一番近い相手（1×1）に噛みつく。\n同距離ならあなたを優先。\n噛むと{bite}ダメージ、HP+{growth}。"],
	"freeze_fairy": ["{freeze_plus}ターン凍らせる", "攻撃範囲のマスに置く。\n周囲3×3の敵が凍りつき、\n{freeze_plus}ターン動けず攻撃もしない。"],
	"blessing_fairy": ["5×5に広がり、中でターンを終えるとHP+{bless_heal}", "攻撃範囲の空きマスに置く。\n周囲5×5が{turns}ターン加護の地に。\n中にいる間、攻撃が当たった\nマスの上下左右にも当たる。\n中でターンを終えるとHP+{bless_heal}。"],
	"meteor_fairy": ["隕石が2個落ちる", ""],
	"guardian_fairy": ["HP{hp_plus}で降臨する", "攻撃範囲に2×2の守護神（HP{hp_plus}・\nAP{ally_ap}）を呼ぶ。この戦闘で召喚\nした妖精を種類ごとに1体ずつ\nHP+{guardian_bonus}で呼び直す。暴食も来る。"],
	"slash_fairy": ["上下2マスに加え、3マス幅の斬撃を飛ばす", "向きを選ぶ。置いたマスの上下2マスと\n3マス幅×5マスの斬撃を同時に\n飛ばす。当たった敵すべてに1。\n大砲に当たると誘爆させる。"],
	"gravity_fairy": ["もっと遠くから引き寄せ、{push_plus}マス弾く", "空きマスならどこでも置ける。\n範囲外なら、もっと遠く（周囲\n{pull_plus}マス）から1マス引き寄せる。\n攻撃範囲なら、周りの敵を\n{push_plus}マス弾く。ダメージなし。"],
	"abyss_spirit": ["{abyss_plus}ターン続く奈落", "自分のマスを押して呼ぶ。\n{abyss_plus}ターン、どの武器も届かない\n空きマスがすべて奈落になる。\n押し込んだ敵は落ちて即撃破。\n2×2は落ちず、手前で止まる。"],
	"holy_spirit": ["壊れると聖騎士が4体出る", "激レア・2×2の味方（HP{hp_plus}）。\n辺に触れた敵に1、いなければ\n敵へ1マス寄る。壊れると\n聖騎士（HP{knight_hp}・AP{knight_ap}）が4体出る。"],
	"axe_spirit": ["毎戦闘{uses_plus}回使える", "2×2。選んだマスを含む2×2から\n向きへ突進。当たった敵に1、\n押し出してぶつけるとさらに1。\n消える。毎戦闘{uses_plus}回。\n大砲に当たると誘爆。"],
	"time_fairy": ["{cost_plus} APで・毎戦闘{uses_plus}回止められる", "自分のマスを押して呼ぶ。\n時が止まり、次の敵のターン\n（{time_stop}ターン）は敵が誰も動かず、\n攻撃もしない。\n味方は動ける。毎戦闘{uses_plus}回。"],
	"capacitor_fairy": ["{cost_plus} APで置ける・毎戦闘{uses_plus}回", "攻撃範囲の空きマスに設置。\n叩いた時に電気が1溜まる。\n{charge}溜まると縦横4方向の直線上の\n敵すべてに1。溜め直せる。"],
}
## The slash spirit's class-up is an evolution into the flying slash.
## Class-ups that turn a fairy into another one (none now: the flying slash became 斬撃精霊+).
const EVOLUTIONS := {}
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
## Upgraded stealth fairies: cell -> the round they last struck (once per enemy turn).
var stealth_struck: Dictionary = {}
var obstacles: Array[Vector2i] = []
## Wall spirits: cell -> player turns left (including the current one).
var walls: Dictionary = {}
## Placed cannons: {cell, dir, kind}. They fire when the player attacks their tile.
var cannons: Array[Dictionary] = []
## 影縫い精霊: {cell, turns, ready}. The player may swap onto it for 0 AP once a turn.
var shadow: Dictionary = {}
## 奈落の精霊: while abyss_turns > 0, every empty tile no carried weapon reaches is a pit.
var abyss_turns := 0
## 時の妖精: enemy turns left in which no enemy acts.
var time_stop := 0
## 加護の妖精: {cell, turns, radius}. While the player stands in it, attacks also hit up and down.
var blessing: Dictionary = {}
## Ally kinds summoned by fairies this battle, in order (the guardian calls them all back).
var summoned_kinds: Array[String] = []
var pits: Array[Vector2i] = []
## Final boss: soldiers that fell while the Prison King lived, in the order they fell.
var fallen: Array[String] = []
## Where broken fortresses left their rubble (top-left of each 2x2), for the view.
var ruins: Array[Vector2i] = []

## What happened this battle, for the achievements (Achievements.check reads it): the
## highest CHAIN, the rounds each 設置 fairy was put down in, the most allies one 守護神
## called, whether a 暴食妖精 ate the player, whether an attacking fairy set off a placed
## one, and the magic circles closed.
var stats := _fresh_stats()

func _fresh_stats() -> Dictionary:
	return {"max_chain": 0, "placed_rounds": [], "guardian_calls": 0, "eaten": false, "fairy_set_off": false, "circles": 0}

## The fairies that are put down on the board and stay (the cards' 設置 label).
const PLACED_FAIRIES := ["stealth_fairy", "wall_fairy", "cannon_fairy", "vane_cannon", "firework_fairy", "capacitor_fairy", "shadow_stitch", "blessing_fairy", "abyss_spirit"]

## How many 設置 fairies were put down within the last WALL_TURNS rounds (so still standing).
func placed_recently() -> int:
	return stats.placed_rounds.filter(func(r: int) -> bool: return round_number - r < WALL_TURNS).size()

func reset(next_level: int = 0, keep_inventory: bool = false) -> void:
	stats = _fresh_stats()
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
		fairy_plus.clear()
		enchants.clear()
	weapon = owned_weapons[0]
	facing = 1
	kills = 0
	player = {"id": -1, "type": "player", "cell": layout.player_start, "hp": start_hp, "ap": 2}
	enemies.clear()
	mines.clear()
	fairies.clear()
	fairy_turns.clear()
	stealth_struck.clear()
	allies.clear()
	next_ally_id = -100
	obstacles.clear()
	walls.clear()
	cannons.clear()
	shadow = {}
	blessing = {}
	summoned_kinds.clear()
	abyss_turns = 0
	time_stop = 0
	pits.clear()
	fallen.clear()
	ruins.clear()
	locked_slot = -1
	floor_cells.clear()
	circle_tiles.clear()
	blade_charge = 0
	blade_used = false
	free_swap_used = false
	turn_chain = 0
	slot_rolls = 0
	slot_seed = randi()
	refill_fairies()
	logs.clear()
	events.clear()
	for placement in layout.get_children():
		var cell := FormationLayout.cell_at(placement.position,board_size)
		var kind: String = ["infantry","miner","heavy","cavalry","recruit","horse","javelin","archer","rook","prison","executioner","slot","shield","analyst","gold","silver","king","fortress"][placement.enemy_kind]
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
		var count: int = fairy_uses(id)
		fairy_charges.append(count)
		inventory[id] = inventory.get(id,0)+count


func make_enemy(kind: String, cell: Vector2i, id: int) -> Dictionary:
	var state := "idle" if kind in CHARGERS else "approach"
	return {"id": id, "type": kind, "cell": cell, "hp": TYPES[kind].hp, "ap": TYPES[kind].ap, "facing": 3, "wait": 0, "intent": "接近", "state": state, "charge_round": -1, "size": int(TYPES[kind].get("size", 1)), "reel": 0, "last_reel": 0, "learned": -1}

## Shogi moves with the front to the left: gold everywhere but the back diagonals,
## silver the three front tiles and the two back diagonals.
func general_offsets(kind: String, f: Vector2i = Vector2i.LEFT) -> Array:
	if kind == "gold":
		return [f, f + Vector2i.UP, f + Vector2i.DOWN, Vector2i.UP, Vector2i.DOWN, -f]
	return [f, f + Vector2i.UP, f + Vector2i.DOWN, -f + Vector2i.UP, -f + Vector2i.DOWN]

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
	if enemy.type in GENERALS:
		return general_offsets(enemy.type)
	if enemy.type == "king":
		# Shown as a shogi king: he reaches every tile touching him.
		return [Vector2i(-1,-1), Vector2i(0,-1), Vector2i(1,-1), Vector2i(-1,0), Vector2i(1,0), Vector2i(-1,1), Vector2i(0,1), Vector2i(1,1)]
	if enemy.type == "fortress":
		return []
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

## Anything a charge crashes into and stops at (it is smashed in the process).
func charge_stopped(cell: Vector2i) -> bool:
	return arrow_stopped(cell) or fairies.has(cell) or not ally_at(cell).is_empty() or shadow.get("cell", Vector2i(-1, -1)) == cell

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
	# Aiming ends its turn, so the lane is always on show before the shot.
	enemy.ap = 0
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
			_bury_allies()
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
		_bury_allies()
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

func is_plus(id: String) -> bool:
	return fairy_plus.has(id)

## Class-up level (0 = none). Most fairies stop at 1; the meteor fairy goes to 4.
func plus_level(id: String) -> int:
	return int(fairy_plus.get(id, 0))

## Fairies that can still take a class-up (or evolve).
func can_class_up(id: String) -> bool:
	return plus_level(id) < int(MAX_PLUS.get(id, 1)) and (PLUS_TEXT.has(id) or EVOLUTIONS.has(id))

## Upgrade the fairy in a loadout slot: a "+" for most, an evolution for the slash.
func class_up(slot: int) -> bool:
	if slot < 0 or slot >= fairy_loadout.size() or not can_class_up(fairy_loadout[slot]):
		return false
	var id: String = fairy_loadout[slot]
	if EVOLUTIONS.has(id):
		fairy_loadout[slot] = EVOLUTIONS[id]
	else:
		fairy_plus[id] = plus_level(id) + 1
	refill_fairies()
	return true

func fairy_title(id: String) -> String:
	var item := item_definition(id)
	if item == null:
		return ""
	var level := plus_level(id)
	return item.title + ("" if level == 0 else "+" if level == 1 else "+%d" % level)

## `plus`: 1 the classed-up text, 0 the plain one, -1 whatever this fairy is now.
func fairy_summary(id: String, plus: int = -1) -> String:
	var upgraded := _upgraded(id, plus)
	if id == "meteor_fairy" and upgraded:
		return "隕石が%d個落ちる" % _meteors_at(id, plus)
	return fairy_text(id, PLUS_TEXT[id][0] if upgraded else item_definition(id).summary)

func fairy_description(id: String, plus: int = -1) -> String:
	var upgraded := _upgraded(id, plus)
	if id == "meteor_fairy" and upgraded:
		return meteor_text(_meteors_at(id, plus))
	return fairy_text(id, PLUS_TEXT[id][1] if upgraded else item_definition(id).description)

## The meteor count to describe: a class-up preview of a plain meteor fairy shows two.
func _meteors_at(id: String, plus: int) -> int:
	return meteor_count() + (1 if plus == 1 and not is_plus(id) else 0)

func _upgraded(id: String, plus: int) -> bool:
	return is_plus(id) if plus < 0 else plus == 1 and PLUS_TEXT.has(id)

## The meteor fairy's text for n meteors (the class-up only changes the count).
static func meteor_text(n: int) -> String:
	return fairy_text("meteor_fairy", "自分のマスを押して呼ぶ。\n武器の範囲のランダムな%dマスに\n3×3の隕石が落ちる。\n敵に{meteor}ダメージ。\n自分と味方は無事。\n落ちた所の大砲は誘爆する。" % n)

## Fairy texts never write a number the rules own: they write {name} and this fills it
## from the constants above and the fairy's item data, so changing a value (a fairy's
## AP, a summon's HP, a duration) changes every text that quotes it.
static func fairy_text(id: String, text: String) -> String:
	return text.format(text_values(id))

static func text_values(id: String) -> Dictionary:
	var values := {
		"turns": WALL_TURNS, "freeze": FREEZE_TURNS, "freeze_plus": FREEZE_TURNS + 1,
		"abyss_plus": WALL_TURNS + 2, "meteor": METEOR_DAMAGE, "stealth": STEALTH_DAMAGE, "charge": CAPACITOR_FULL,
		"bite": CIRCLE_DAMAGE, "growth": GLUTTON_GROWTH, "guardian_bonus": GUARDIAN_BONUS_HP,
		"knight_hp": HOLY_KNIGHT_HP, "knight_ap": HOLY_KNIGHT_AP,
		"wolf_bite": WOLF_BITE, "wolf_crowded": WOLF_CROWDED_BITE,
		"pull": GRAVITY_PULL, "pull_plus": GRAVITY_PULL + 1, "push": GRAVITY_PUSH, "push_plus": GRAVITY_PUSH + 1,
		"swap_ap": SHADOW_SWAP_AP, "swap_ap_plus": maxi(0, SHADOW_SWAP_AP - 1),
		"bless_heal": BLESS_HEAL, "time_stop": TIME_STOP_TURNS,
	}
	for item in ITEMS:
		if item.id == id:
			values.cost = fairy_ap_cost_at(item, false)
			values.cost_plus = fairy_ap_cost_at(item, true)
			values.uses = fairy_uses_at(item, false)
			values.uses_plus = fairy_uses_at(item, true)
	if SUMMON_STATS.has(id):
		values.hp = SUMMON_STATS[id].hp
		values.hp_plus = SUMMON_STATS[id].hp_plus
		values.ally_ap = SUMMON_STATS[id].ap
	return values

## Besides its own change (PLUS_TEXT), a class-up gives one more use per battle, keeping
## the AP cost. Summoners also get 1 AP off; a few are set by hand: the lone wolf and
## the shadow get 0 AP instead of an extra use, the holy spirit only its four knights, the meteor and the stealth fairy only
## their own change.
const PLUS_AP_CUT: Array[String] = ["time_fairy", "acorn_fairy", "glutton_fairy", "guardian_fairy", "lone_wolf", "shadow_stitch", "cannon_fairy", "capacitor_fairy"]
const PLUS_NO_EXTRA_USE: Array[String] = ["glutton_fairy", "lone_wolf", "shadow_stitch", "meteor_fairy", "stealth_fairy", "holy_spirit"]
## A fairy's AP and uses per battle come only from its item data (ap_cost,
## initial_count) and these class-up rules. `plus`: 1 classed up, 0 plain, -1 as it is now.
func fairy_ap_cost(id: String, plus: int = -1) -> int:
	return fairy_ap_cost_at(item_definition(id), _upgraded(id, plus))

func fairy_uses(id: String, plus: int = -1) -> int:
	return fairy_uses_at(item_definition(id), _upgraded(id, plus))

static func fairy_ap_cost_at(item: Resource, upgraded: bool) -> int:
	return maxi(0, item.ap_cost - (1 if upgraded and PLUS_AP_CUT.has(item.id) else 0))

static func fairy_uses_at(item: Resource, upgraded: bool) -> int:
	return item.initial_count + (1 if upgraded and not PLUS_NO_EXTRA_USE.has(item.id) else 0)

## A summon's HP (its class-up HP once classed up) and AP.
func summon_hp(id: String) -> int:
	return int(SUMMON_STATS[id].hp_plus if is_plus(id) else SUMMON_STATS[id].hp)

static func summon_ap(id: String) -> int:
	return int(SUMMON_STATS[id].ap)

## An ally unit's AP per turn (the holy knights have their own).
static func ally_ap(type: String) -> int:
	return HOLY_KNIGHT_AP if type == "holy_knight" else summon_ap(ALLY_FAIRY[type]) if ALLY_FAIRY.has(type) else 1

## Directional fairies ask for a direction after the tile (the upgraded wall does too).
func is_directional(id: String) -> bool:
	return item_definition(id).directional or (id in ["wall_fairy", "slash_fairy"] and is_plus(id))

func blocked(cell: Vector2i) -> bool:
	return pits.has(cell) or shadow.get("cell", Vector2i(-1, -1)) == cell or obstacles.has(cell) or walls.has(cell) or fairies.has(cell) or not cannon_at(cell).is_empty() or not ally_at(cell).is_empty()

func item_targets(id: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var item := item_definition(id)
	if item == null:
		return result
	# The bow cannot move, but fairies may be placed anywhere along its diagonal lines.
	var weapon_cells: Array[Vector2i] = bow_lines() if WEAPONS[weapon].get("ranged","") == "bishop" else targets()
	if item.target == ItemDefinition.Target.SELF:
		result.append(player.cell)
		return result
	var reach: Array[Vector2i] = []
	if item.target == ItemDefinition.Target.UNREACHED:
		reach = all_reach()
	for y in range(board_size):
		for x in range(board_size):
			var cell := Vector2i(x,y)
			if cell == player.cell or blocked(cell):
				continue
			if not enemy_at(cell).is_empty() and item.target != ItemDefinition.Target.WEAPON_ANY:
				continue
			if BIG_FAIRIES.has(id) and big_anchor(cell) == Vector2i(-1, -1):
				continue
			if item.target == ItemDefinition.Target.SELF:
				continue
			if item.target == ItemDefinition.Target.UNREACHED:
				if not reach.has(cell):
					result.append(cell)
			elif item.target == ItemDefinition.Target.ANY_EMPTY or weapon_cells.has(cell):
				result.append(cell)
	return result

## Tiles one weapon reaches from where the player stands (the bow: its diagonal lines).
func weapon_reach(index: int) -> Array[Vector2i]:
	var held := weapon
	weapon = index
	var result: Array[Vector2i] = []
	result.assign(bow_lines() if WEAPONS[index].get("ranged","") == "bishop" else targets())
	weapon = held
	return result

## Every tile any carried weapon reaches: switching is free, so this is what counts.
func all_reach() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for index in owned_weapons:
		for cell in weapon_reach(index):
			if not result.has(cell):
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
	if item == null or phase != Phase.PLAYER or player.ap < fairy_ap_cost(id) or inventory.get(id,0) <= 0:
		return false
	if slot < 0:
		for i in fairy_loadout.size():
			if fairy_loadout[i] == id and fairy_charges[i] > 0:
				slot = i
				break
	if slot < 0 or slot >= fairy_loadout.size() or fairy_loadout[slot] != id or fairy_charges[slot] <= 0:
		return false
	if not item_targets(id).has(cell) or (is_directional(id) and not CARDINALS.has(direction)):
		return false
	events.clear()
	player.ap -= fairy_ap_cost(id)
	inventory[id] -= 1
	fairy_charges[slot] -= 1
	strike_guard = true
	struck_ids.clear()
	item.effect.new().apply(self, cell, direction)
	strike_guard = false
	if id in PLACED_FAIRIES:
		stats.placed_rounds.append(round_number)
	add_log("%sを使用" % fairy_title(id))
	check_outcome()
	dig_abyss()
	return true

func hand_size() -> int:
	return fairy_loadout.size()

func add_item(id: String, count: int = 1) -> int:
	if item_definition(id) == null or count <= 0 or fairy_loadout.size() >= HAND_LIMIT:
		return 0
	fairy_loadout.append(id)
	var count_per_battle: int = fairy_uses(id)
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

## Shield soldier: its shield faces left, so a hit from the tile directly to its
## left, or a shot flying rightward into it, is blocked.
func shield_blocks(enemy: Dictionary, attacker_cell: Vector2i = Vector2i(-99, -99), travel: Vector2i = Vector2i.ZERO) -> bool:
	if enemy.get("type", "") != "shield":
		return false
	return attacker_cell == enemy.cell + Vector2i.LEFT or travel == Vector2i.RIGHT

func _block(enemy: Dictionary) -> void:
	events.append({"kind":"block", "cell":enemy.cell, "id":-2})
	add_log("盾兵が盾で防いだ")

func damage_enemy(enemy: Dictionary, amount: int, travel: Vector2i = Vector2i.ZERO) -> void:
	if enemy.hp <= 0:
		return
	if shield_blocks(enemy, Vector2i(-99, -99), travel):
		_block(enemy)
		return
	if strike_guard:
		if struck_ids.has(enemy.id):
			return
		struck_ids.append(enemy.id)
	enemy.hp -= amount
	# HP before and after, so a delayed chain hit can take its hearts when it lands.
	events.append({"kind": "hit", "cell": enemy.cell, "id": enemy.id, "hp_before": enemy.hp + amount, "hp": enemy.hp})
	if enemy.hp <= 0:
		kills += 1

## 隠密妖精: what its strike does.
const STEALTH_DAMAGE := 2

func trigger_fairies() -> void:
	# Placement order, then enemy ID, resolves simultaneous opportunities.
	var ordered := enemies.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
	# The upgraded fairy stays after striking (once per enemy turn) until its turns run out.
	var stays := is_plus("stealth_fairy")
	for cell in fairies.duplicate():
		if stays and int(stealth_struck.get(cell, -1)) == round_number:
			continue
		for enemy in ordered:
			if enemy.hp > 0 and distance(cell, enemy.cell) == 1:
				if stays:
					stealth_struck[cell] = round_number
				else:
					fairies.erase(cell)
					fairy_turns.erase(cell)
				events.append({"kind": "ambush", "cell": cell, "id": -2})
				damage_enemy(enemy, STEALTH_DAMAGE)
				break
	check_outcome()

func inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < board_size and cell.y >= 0 and cell.y < board_size

func distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

## Rotorick's shadow (reel 6) is a hologram: it blocks nothing and cannot be hit,
## so it is not an "enemy at" its tiles (see shadow_at).
func enemy_at(cell: Vector2i) -> Dictionary:
	for enemy in enemies:
		if enemy.hp > 0 and enemy.type != "shadow" and (enemy.cell == cell or (enemy.get("size", 1) > 1 and footprint(enemy).has(cell))):
			return enemy
	return {}

func shadow_at(cell: Vector2i) -> Dictionary:
	for enemy in enemies:
		if enemy.hp > 0 and enemy.type == "shadow" and footprint(enemy).has(cell):
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
## Where a hammer's blow spreads: the target, the tiles above and below it and the
## column beyond; the cross hammer, the target and the four tiles around it.
func hammer_area(target: Vector2i, index: int = weapon) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset in Catalog.hammer_shape(index):
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
	var lines: Array = Catalog.slides(weapon)
	if not lines.is_empty():
		# Sliding weapons: every free tile along each line, up to (and including) the first enemy or cannon.
		for direction in lines:
			var cell: Vector2i = player.cell + direction
			while inside(cell):
				if not enemy_at(cell).is_empty() or not cannon_at(cell).is_empty():
					result.append(cell)
					break
				if blocked(cell):
					break
				result.append(cell)
				cell += direction
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
	var done := _player_action(cell)
	if done:
		dig_abyss()
	return done

func _player_action(cell: Vector2i) -> bool:
	if can_swap_shadow(cell):
		swap_shadow()
		return true
	if phase != Phase.PLAYER or player.ap <= 0 or not targets().has(cell):
		return false
	var cannon := cannon_at(cell)
	if not cannon.is_empty() and not is_circle(weapon):
		# Striking a placed cannon fires it.
		events.clear()
		player.ap -= 1
		strike_guard = true
		struck_ids.clear()
		start_chain()
		fire_cannon(cannon)
		strike_guard = false
		check_outcome()
		return true
	# A magic circle weapon cannot attack: it only moves (and draws).
	if is_circle(weapon) and (not cannon_at(cell).is_empty() or not enemy_at(cell).is_empty()):
		return false
	if blocked(cell):
		return false
	# The swap staff cannot trade places with a 2x2 enemy.
	if WEAPONS[weapon].get("swap", false) and int(enemy_at(cell).get("size", 1)) > 1:
		return false
	events.clear()
	var enemy := enemy_at(cell)
	if free_swap_ready() and not enemy.is_empty():
		free_swap_used = true
	else:
		player.ap -= 1
	if WEAPONS[weapon].has("charge"):
		blade_used = true
	if not enemy.is_empty() and WEAPONS[weapon].get("swap", false):
		# 入替の杖: trade places, no damage.
		var from: Vector2i = player.cell
		enemy.cell = from
		player.cell = cell
		events.append({"kind":"swap", "cell":cell, "id":-2, "from":from})
		add_log("入替の杖で%sと位置を入れ替えた" % TYPES[enemy.type].name)
		trigger_mine(player)
		trigger_mine(enemy)
		check_outcome()
		return true
	if not enemy.is_empty():
		var struck: Array = [enemy]
		if Catalog.is_hammer(weapon):
			events.append({"kind":"quake", "cell":cell, "id":-2, "cells":hammer_area(cell)})
			for area_cell in hammer_area(cell):
				var other := enemy_at(area_cell)
				if not other.is_empty() and not struck.has(other):
					struck.append(other)
		elif WEAPONS[weapon].get("ranged","") == "bishop":
			events.append({"kind":"arrow", "cell":cell, "from":player.cell, "id":-2})
		# 加護: standing in the blessed ground, the blow also lands on the four tiles
		# around the struck one (a cross).
		if blessed(player.cell):
			for side in CARDINALS:
				events.append({"kind":"slash", "cell":cell + side, "id":-2, "dir":Vector2i.DOWN if side.x == 0 else Vector2i.RIGHT})
				var other := enemy_at(cell + side)
				if not other.is_empty() and not struck.has(other):
					struck.append(other)
		for target in struck:
			if shield_blocks(target, player.cell):
				_block(target)
				continue
			# Analyst: a weapon it has already analysed does nothing.
			if target.type == "analyst" and int(target.get("learned", -1)) == weapon:
				events.append({"kind":"analyzed", "cell":target.cell, "id":-2})
				add_log("解析兵：その武器は解析済み")
				continue
			# Knockback weapons deal no damage of their own (unless forged): only the shove.
			var damage := weapon_damage(weapon)
			if damage > 0:
				target.hp -= damage
				events.append({"kind": "hit", "cell": target.cell, "id": target.id, "damage": damage})
			add_log("%sで%sを攻撃" % [WEAPONS[weapon].short, TYPES[target.type].name])
			if target.type == "analyst" and target.hp > 0:
				target.learned = weapon
				add_log("解析兵が%sを解析した" % WEAPONS[weapon].name)
			if target.hp <= 0:
				kills += 1
				add_log("%sを撃破" % TYPES[target.type].name)
			elif Catalog.knockback(weapon) > 0:
				var away := Vector2i(signi(cell.x - player.cell.x), signi(cell.y - player.cell.y))
				# Shoved all the way, until something stops it.
				knock_back(target, away, board_size * 2)
			elif WEAPONS[weapon].get("pull", false) and target == enemy and int(target.get("size", 1)) == 1:
				# 鎖鎌: drag the enemy to the tile in between.
				var middle: Vector2i = player.cell + (cell - player.cell) / 2
				if inside(middle) and middle != player.cell and not blocked(middle) and enemy_at(middle).is_empty():
					events.append({"kind":"pull", "cell":middle, "id":-2, "from":cell})
					target.cell = middle
					trigger_mine(target)
		if WEAPONS[weapon].has("charge"):
			blade_charge = 0
	elif WEAPONS[weapon].get("ranged","") == "bishop":
		return false
	else:
		var from: Vector2i = player.cell
		player.cell = cell
		if is_circle(weapon):
			_draw_circle_path(from, cell)
		trigger_mine(player)
		shadow_strike()
		if is_circle(weapon) and not terminal():
			_cast_circle()
	check_outcome()
	return true

# --- magic circle ------------------------------------------------------------

func is_circle(index: int) -> bool:
	return enchants.get(index, "") == "circle"

## Tiles a circle move paints: where the player stood and where they land.
func circle_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [from]
	var gap := to - from
	# A sliding weapon paints every tile it passed.
	if not Catalog.slides(weapon).is_empty() and (gap.x == 0 or gap.y == 0 or absi(gap.x) == absi(gap.y)):
		var step := Vector2i(signi(gap.x), signi(gap.y))
		var tile := from + step
		while tile != to:
			path.append(tile)
			tile += step
	path.append(to)
	return path

func _draw_circle_path(from: Vector2i, to: Vector2i) -> void:
	for tile in circle_path(from, to):
		if inside(tile) and not circle_tiles.has(tile):
			circle_tiles.append(tile)
			events.append({"kind":"chalk", "cell":tile, "id":-2})

## Go-style capture: tiles the outside cannot reach (4-way) past the white
## tiles are enclosed; white tiles touch each other diagonally too, so a
## diamond of four encloses its centre. The board edge is not a wall.
## Returns {"inside": enclosed tiles, "line": the white tiles around them}.
func circle_enclosure(tiles: Array) -> Dictionary:
	var reached := {}
	var queue: Array[Vector2i] = [Vector2i(-1, -1)]
	reached[Vector2i(-1, -1)] = true
	while not queue.is_empty():
		var current: Vector2i = queue.pop_back()
		for direction in CARDINALS:
			var next: Vector2i = current + direction
			if next.x < -1 or next.y < -1 or next.x > board_size or next.y > board_size:
				continue
			if reached.has(next) or tiles.has(next):
				continue
			reached[next] = true
			queue.append(next)
	var inside_tiles: Array[Vector2i] = []
	for y in board_size:
		for x in board_size:
			var tile := Vector2i(x, y)
			if not reached.has(tile) and not tiles.has(tile):
				inside_tiles.append(tile)
	var line: Array[Vector2i] = []
	for tile in tiles:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if inside_tiles.has(tile + Vector2i(dx, dy)) and not line.has(tile):
					line.append(tile)
	return {"inside": inside_tiles, "line": line}

## The area a move to `cell` would set off (empty when it closes nothing).
func circle_preview(cell: Vector2i) -> Array[Vector2i]:
	var tiles: Array = circle_tiles.duplicate()
	for tile in circle_path(player.cell, cell):
		if not tiles.has(tile):
			tiles.append(tile)
	var found := circle_enclosure(tiles)
	var area: Array[Vector2i] = []
	area.append_array(found.inside)
	area.append_array(found.line)
	return area

## Closing a circle: everything enclosed, and on its white line, takes 99.
## The white tiles that formed it are used up.
func _cast_circle() -> void:
	var found := circle_enclosure(circle_tiles)
	if found.inside.is_empty():
		return
	var area: Array[Vector2i] = []
	area.append_array(found.inside)
	area.append_array(found.line)
	var struck: Array[Dictionary] = []
	for enemy in enemies:
		if enemy.hp > 0 and footprint(enemy).any(func(tile: Vector2i) -> bool: return area.has(tile)):
			struck.append(enemy)
	var hit_units: Array = struck.map(func(enemy: Dictionary) -> Dictionary: return {"cell": enemy.cell, "size": enemy.get("size", 1)})
	stats.circles += 1
	events.append({"kind":"circle", "cell":player.cell, "id":-2, "cells":area, "line":found.line, "targets":hit_units})
	for enemy in struck:
		damage_enemy(enemy, CIRCLE_DAMAGE)
	for tile in found.line:
		circle_tiles.erase(tile)
	add_log("魔法陣が発動！ %d体に%dダメージ" % [struck.size(), CIRCLE_DAMAGE])

## Shove an enemy `tiles` squares. Blocked by the edge, terrain, a cannon, the
## player or another enemy, it slams into it: 1 damage (and 1 to an enemy it hits).
func knock_back(enemy: Dictionary, direction: Vector2i, tiles: int) -> void:
	if enemy.type in IMMOVABLE:
		# Rooted to the floor: it does not budge (and, like a wall, takes nothing).
		events.append({"kind":"bump", "cell":enemy.cell, "id":-2, "dir":direction})
		return
	var big: bool = int(enemy.get("size", 1)) > 1
	if direction == Vector2i.ZERO or (big and direction.x != 0 and direction.y != 0):
		return
	for step in tiles:
		var front: Array[Vector2i] = [enemy.cell + direction]
		if big:
			front = _front_cells(enemy, direction)
		if not big and pits.has(enemy.cell + direction):
			_fall(enemy, enemy.cell + direction)
			return
		var stopped := false
		var struck: Array[Dictionary] = []
		for cell in front:
			if not inside(cell) or blocked(cell) or cell == player.cell:
				stopped = true
			elif not enemy_at(cell).is_empty() and enemy_at(cell).id != enemy.id:
				stopped = true
				if not struck.has(enemy_at(cell)):
					struck.append(enemy_at(cell))
		if stopped:
			# Slammed into another enemy, both take 1. Against anything else (the edge,
			# walls, obstacles, the player, allies, cannons) it just stops, unhurt.
			events.append({"kind":"bump", "cell":enemy.cell, "id":-2, "dir":direction, "hurt":not struck.is_empty()})
			if not struck.is_empty():
				add_log("%sが叩きつけられた" % TYPES[enemy.type].name)
				_bump_damage(enemy)
				for other in struck:
					_bump_damage(other)
			return
		enemy.cell += direction
		events.append({"kind":"push", "cell":enemy.cell, "id":-2, "dir":direction})
		trigger_mine(enemy)
		if enemy.hp <= 0:
			return

## 1 damage from a collision, marked so the board shows it apart from the attack
## (it lands a beat later, in its own colour). It counts even if the attack
## already hit this enemy.
func _bump_damage(enemy: Dictionary) -> void:
	var guard := strike_guard
	strike_guard = false
	var before := events.size()
	damage_enemy(enemy, 1)
	strike_guard = guard
	for k in range(before, events.size()):
		if events[k].kind == "hit":
			events[k].bump = true

func weapon_damage(index: int) -> int:
	var bonus: int = blade_charge if WEAPONS[index].has("charge") else 0
	return Catalog.base_damage(index) + int(weapon_power.get(index, 0)) + bonus

func trigger_mine(unit: Dictionary) -> void:
	if unit.type == "miner" or not mines.has(unit.cell):
		return
	mines.erase(unit.cell)
	unit.hp -= 1
	events.append({"kind": "mine", "cell": unit.cell, "id": unit.id})
	var label: String = "探索者" if unit.type == "player" else ALLY_NAMES[unit.type] if ALLY_NAMES.has(unit.type) else TYPES[unit.type].name
	add_log("地雷が爆発！ %sに1ダメージ" % label)
	if unit.type != "player" and not ALLY_NAMES.has(unit.type) and unit.hp <= 0:
		kills += 1
	check_outcome()

func check_outcome() -> void:
	_note_fallen()
	_check_rage()
	_release_prisoners()
	_bury_allies()
	enemies = enemies.filter(func(e: Dictionary) -> bool: return e.hp > 0)
	if not enemies.any(func(e: Dictionary) -> bool: return e.type == "slot"):
		locked_slot = -1
		floor_cells.clear()
	if player.hp <= 0:
		phase = Phase.LOST
	elif level == FINAL_LEVEL and not enemies.any(func(e: Dictionary) -> bool: return e.type == "king"):
		# The Prison King is down: the prison falls with him.
		enemies.clear()
		phase = Phase.WON
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
		if ally.hp > 0 and (ally.cell == cell or (int(ally.get("size", 1)) > 1 and footprint(ally).has(cell))):
			return ally
	return {}

## Removes fallen allies. A broken holy spirit lets out two holy knights on a
## diagonal of its footprint (the friendly mirror of the moving prison); classed up,
## one from every free tile of it (up to four).
func _bury_allies() -> void:
	for holy in allies.duplicate():
		if holy.type != "holy" or holy.hp > 0 or holy.get("released", false):
			continue
		holy.released = true
		var layouts := [[Vector2i(0,0), Vector2i(1,0), Vector2i(0,1), Vector2i(1,1)]] if holy.get("plus", false) else [[Vector2i(0,0), Vector2i(1,1)], [Vector2i(1,0), Vector2i(0,1)]]
		for pair in layouts:
			var spots: Array[Vector2i] = []
			for offset in pair:
				var cell: Vector2i = holy.cell + offset
				if inside(cell) and cell != player.cell and enemy_at(cell).is_empty() and not obstacles.has(cell) and not walls.has(cell) and cannon_at(cell).is_empty() and not fairies.has(cell):
					spots.append(cell)
			if spots.size() == 2 or (holy.get("plus", false) and not spots.is_empty()):
				for cell in spots:
					allies.append({"id":next_ally_id, "type":"holy_knight", "cell":cell, "hp":HOLY_KNIGHT_HP, "ap":HOLY_KNIGHT_AP, "facing":2})
					next_ally_id -= 1
					events.append({"kind":"summon", "cell":cell, "id":-2, "fx":"holy"})
				add_log("聖精霊が壊れ、聖騎士が%d体現れた" % spots.size())
				break
	allies = allies.filter(func(unit: Dictionary) -> bool: return unit.hp > 0)

## Top-left of a free 2x2 block that contains `cell`, preferring blocks away
## from the player; (-1,-1) when none fits.
func big_anchor(cell: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_gap := -1.0
	for offset in [Vector2i(0,0), Vector2i(1,0), Vector2i(0,1), Vector2i(1,1)]:
		var anchor: Vector2i = cell - offset
		var free := true
		for tile in footprint({"cell":anchor, "size":2}):
			if not inside(tile) or blocked(tile) or tile == player.cell or not enemy_at(tile).is_empty():
				free = false
		var gap := (Vector2(anchor) + Vector2.ONE * 0.5).distance_to(Vector2(player.cell))
		if free and gap > best_gap:
			best = anchor
			best_gap = gap
	return best

func _note_summon(kind: String) -> void:
	if not summoned_kinds.has(kind):
		summoned_kinds.append(kind)

## 守護神の妖精: a 2x2 guardian (HP3, AP1) descends and, one by one, calls back one of
## every ally kind summoned this battle (the glutton too), onto the free tiles around it.
## Every ally it calls arrives with +1 HP. Each call is stamped with a delay for the entrance: the guardian lands, then they pop in.
const GUARDIAN_LAND := 0.75
const GUARDIAN_STEP := 0.15
func summon_guardian(cell: Vector2i) -> void:
	var anchor := big_anchor(cell)
	if anchor == Vector2i(-1, -1):
		return
	var guardian := {"id":next_ally_id, "type":"guardian", "cell":anchor, "hp":summon_hp("guardian_fairy"), "ap":summon_ap("guardian_fairy"), "facing":2, "size":2}
	allies.append(guardian)
	next_ally_id -= 1
	var calls: Array = []
	for kind in summoned_kinds.duplicate():
		var spot := _guardian_spot(anchor, kind == "holy")
		if spot == Vector2i(-1, -1):
			continue
		var first := events.size()
		match kind:
			"acorn": summon_acorn(spot)
			"glutton": summon_glutton(spot)
			"wolf": summon_wolf(spot)
			"holy": summon_holy(spot)
			"stealth":
				place_stealth(spot)
				events.append({"kind":"summon", "cell":spot, "id":-2, "fx":"stealth"})
		# The guardian's blessing: everyone it calls comes with 1 more HP (the stealth
		# fairy has none, it just stands its five turns again).
		var ally_id := -1
		if kind != "stealth":
			allies[-1].hp += GUARDIAN_BONUS_HP
			ally_id = int(allies[-1].id)
		var delay := GUARDIAN_LAND + GUARDIAN_STEP * calls.size()
		for i in range(first, events.size()):
			events[i].delay = delay
			events[i].called = true
		calls.append({"cell":spot, "delay":delay, "ally":ally_id})
	stats.guardian_calls = maxi(int(stats.guardian_calls), calls.size())
	events.append({"kind":"guardian", "cell":anchor, "id":-2, "ally":int(guardian.id), "calls":calls})
	add_log("守護神が降臨し、%d体を呼び寄せた" % calls.size())

## A free tile for a called ally: the ring around the guardian first, then further out.
## A called holy spirit needs a free 2x2 block (its anchor is returned).
func _guardian_spot(anchor: Vector2i, big: bool) -> Vector2i:
	var center := Vector2(anchor) + Vector2.ONE * 0.5
	for radius in range(1, board_size):
		var ring: Array[Vector2i] = []
		for y in range(anchor.y - radius, anchor.y + 2 + radius):
			for x in range(anchor.x - radius, anchor.x + 2 + radius):
				var tile := Vector2i(x, y)
				var gap := maxi(maxi(anchor.x - x, x - anchor.x - 1), maxi(anchor.y - y, y - anchor.y - 1))
				if gap == radius and inside(tile):
					ring.append(tile)
		ring.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return Vector2(a).distance_to(center) < Vector2(b).distance_to(center))
		for tile in ring:
			if tile == player.cell or blocked(tile) or not enemy_at(tile).is_empty() or mines.has(tile):
				continue
			if big:
				var block := big_anchor(tile)
				if block != Vector2i(-1, -1):
					return block
				continue
			return tile
	return Vector2i(-1, -1)

func summon_holy(cell: Vector2i) -> void:
	var anchor := big_anchor(cell)
	if anchor == Vector2i(-1, -1):
		return
	allies.append({"id":next_ally_id, "type":"holy", "cell":anchor, "hp":summon_hp("holy_spirit"), "ap":summon_ap("holy_spirit"), "facing":2, "size":2, "plus":is_plus("holy_spirit")})
	_note_summon("holy")
	next_ally_id -= 1
	for tile in footprint({"cell":anchor, "size":2}):
		events.append({"kind":"summon", "cell":tile, "id":-2, "fx":"holy"})

## 風斧精霊: a 2x2 axe that charges like the rook in the chosen direction and
## vanishes. Enemies it meets take 1 and are driven ahead of it; one slammed
## into something takes 1 more (the knockback rule), and the axe stops there.
func axe_charge(cell: Vector2i, direction: Vector2i) -> void:
	var anchor := big_anchor(cell)
	if anchor == Vector2i(-1, -1) or not CARDINALS.has(direction):
		return
	var axe := {"cell":anchor, "size":2}
	var start := anchor
	# Knockback bumps must land even on an enemy the axe already cut.
	var guard := strike_guard
	strike_guard = false
	var cut: Array[int] = []
	var steps := 0
	while steps < board_size * 2:
		steps += 1
		var front := _front_cells(axe, direction)
		var stop := false
		for tile in front:
			if not inside(tile) or blocked(tile) or tile == player.cell:
				stop = true
		if stop:
			break
		var shoved: Array[Dictionary] = []
		for tile in front:
			var enemy := enemy_at(tile)
			if not enemy.is_empty() and not shoved.has(enemy):
				shoved.append(enemy)
		for enemy in shoved:
			if not cut.has(enemy.id):
				cut.append(enemy.id)
				damage_enemy(enemy, 1, direction)
			if enemy.hp > 0:
				knock_back(enemy, direction, 1)
		var still_blocked := false
		for tile in front:
			if not enemy_at(tile).is_empty():
				still_blocked = true
		if still_blocked:
			break
		axe.cell += direction
	strike_guard = guard
	events.append({"kind":"axe", "cell":start, "id":-2, "dir":direction, "to":axe.cell})
	add_log("風斧精霊の突進")
	# Where it stopped: a cannon right in front of it goes off.
	_detonate(_cannons_in(_front_cells(axe, direction)))
	check_outcome()

## Cells the axe will sweep, for the placement preview.
func axe_preview(cell: Vector2i, direction: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var anchor := big_anchor(cell)
	if anchor == Vector2i(-1, -1):
		return result
	var axe := {"cell":anchor, "size":2}
	result.append_array(footprint(axe))
	if not CARDINALS.has(direction):
		return result
	for step in board_size:
		var front := _front_cells(axe, direction)
		if front.any(func(tile: Vector2i) -> bool: return not inside(tile) or blocked(tile) or tile == player.cell):
			break
		result.append_array(front)
		axe.cell += direction
	return result

func summon_acorn(cell: Vector2i) -> void:
	var plus := is_plus("acorn_fairy")
	allies.append({"id":next_ally_id, "type":"acorn", "cell":cell, "hp":summon_hp("acorn_fairy"), "ap":summon_ap("acorn_fairy"), "facing":1, "plus":plus})
	_note_summon("acorn")
	next_ally_id -= 1
	events.append({"kind":"summon", "cell":cell, "id":-2, "fx":"acorn"})

## 影縫い精霊: pin the player's shadow on a tile no weapon reaches.
func place_shadow(cell: Vector2i) -> void:
	shadow = {"cell":cell, "turns":WALL_TURNS, "ready":true}
	events.append({"kind":"summon", "cell":cell, "id":-2, "fx":"shadow"})

## Clicking the shadow swaps with it: 1 AP (0 once classed up), once a player turn.
func shadow_swap_cost() -> int:
	return maxi(0, SHADOW_SWAP_AP - (1 if is_plus("shadow_stitch") else 0))

func can_swap_shadow(cell: Vector2i) -> bool:
	return phase == Phase.PLAYER and not shadow.is_empty() and shadow.cell == cell and shadow.ready and player.ap >= shadow_swap_cost()

func swap_shadow() -> void:
	events.clear()
	var from: Vector2i = player.cell
	player.cell = shadow.cell
	shadow.cell = from
	shadow.ready = false
	player.ap -= shadow_swap_cost()
	events.append({"kind":"warp", "cell":from, "id":-2})
	events.append({"kind":"warp", "cell":player.cell, "id":-2})
	add_log("影縫い精霊と入れ替わった")
	trigger_mine(player)
	check_outcome()

## 重力妖精: in the equipped weapon's range it pulls, outside it pushes.
## Placed outside the weapon's reach it pulls enemies in; inside it, it throws them out.
func gravity_pulls(cell: Vector2i) -> bool:
	return not targets().has(cell)

func gravity(cell: Vector2i) -> void:
	var plus := is_plus("gravity_fairy")
	events.append({"kind":"gravity", "cell":cell, "id":-2, "pull":gravity_pulls(cell)})
	if gravity_pulls(cell):
		_gravity_pull(cell, GRAVITY_PULL + (1 if plus else 0))
		add_log("重力妖精が敵を引き寄せた")
	else:
		_gravity_push(cell, GRAVITY_PUSH + (1 if plus else 0))
		add_log("重力妖精が敵を弾き飛ばした")
	check_outcome()

## Enemies within `radius` (not already touching) take one step towards the centre,
## nearest first (a 2x2 or a 3x3 too: measured from its nearest tile, and it can only
## be drawn straight). No damage, but mines and pits along the way still count.
func _gravity_pull(center: Vector2i, radius: int) -> void:
	var gap_of := func(e: Dictionary) -> int:
		var best := 999
		for c in footprint(e):
			best = mini(best, maxi(absi(c.x - center.x), absi(c.y - center.y)))
		return best
	var movers: Array = enemies.filter(func(e: Dictionary) -> bool:
		var gap: int = gap_of.call(e)
		return e.hp > 0 and not e.type in IMMOVABLE and gap >= 2 and gap <= radius)
	movers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return footprint_distance(a, center) < footprint_distance(b, center))
	for enemy in movers:
		if enemy.hp <= 0 or terminal():
			continue
		var big := int(enemy.get("size", 1)) > 1
		var nearest: Vector2i = enemy.cell
		for c in footprint(enemy):
			if distance(c, center) < distance(nearest, center):
				nearest = c
		var toward := Vector2i(signi(center.x - nearest.x), signi(center.y - nearest.y))
		var tries: Array = [toward]
		if big:
			# Straight only: along the axis it is furthest from the centre.
			var gap: Vector2i = center - nearest
			tries = [Vector2i(signi(gap.x), 0) if absi(gap.x) >= absi(gap.y) else Vector2i(0, signi(gap.y))]
		elif toward.x != 0 and toward.y != 0:
			tries.append_array([Vector2i(toward.x, 0), Vector2i(0, toward.y)])
		for step in tries:
			if step == Vector2i.ZERO:
				continue
			if big:
				# Too big to fall: a pit, like any obstacle, just stops it.
				var front := _front_cells(enemy, step)
				if front.any(func(c: Vector2i) -> bool: return not inside(c) or blocked(c) or c == player.cell or c == center or (not enemy_at(c).is_empty() and enemy_at(c).id != enemy.id)):
					continue
				events.append({"kind":"pull", "cell":enemy.cell + step, "id":-2, "from":enemy.cell})
				enemy.cell += step
				trigger_mine(enemy)
				break
			var next: Vector2i = enemy.cell + step
			if next == center or not inside(next) or next == player.cell or not enemy_at(next).is_empty():
				continue
			if pits.has(next):
				_fall(enemy, next)
				break
			if blocked(next):
				continue
			events.append({"kind":"pull", "cell":next, "id":-2, "from":enemy.cell})
			enemy.cell = next
			trigger_mine(enemy)
			break

## Enemies on the eight tiles around the centre are blown `tiles` away. No damage:
## a blown enemy just stops at whatever is in the way (a pit still swallows it).
func _gravity_push(center: Vector2i, tiles: int) -> void:
	var movers: Array = enemies.filter(func(e: Dictionary) -> bool:
		return e.hp > 0 and not e.type in IMMOVABLE and footprint(e).any(func(c: Vector2i) -> bool: return maxi(absi(c.x - center.x), absi(c.y - center.y)) == 1))
	# The outer ones move first so the inner ones have room.
	movers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return distance(a.cell, center) > distance(b.cell, center))
	for enemy in movers:
		if enemy.hp <= 0 or terminal():
			continue
		var big := int(enemy.get("size", 1)) > 1
		var near := footprint(enemy).filter(func(c: Vector2i) -> bool: return maxi(absi(c.x - center.x), absi(c.y - center.y)) == 1)
		var away: Vector2i = near[0] - center
		if big:
			# A 2x2 can only be blown straight.
			away = Vector2i(signi(away.x), 0) if absi(away.x) >= absi(away.y) else Vector2i(0, signi(away.y))
		for step in tiles:
			var front: Array[Vector2i] = [enemy.cell + away]
			if big:
				front = _front_cells(enemy, away)
			if not big and pits.has(front[0]):
				_fall(enemy, front[0])
				break
			if front.any(func(c: Vector2i) -> bool: return not inside(c) or blocked(c) or c == player.cell or c == center or (not enemy_at(c).is_empty() and enemy_at(c).id != enemy.id)):
				break
			enemy.cell += away
			events.append({"kind":"push", "cell":enemy.cell, "id":-2, "dir":away})
			trigger_mine(enemy)
			if enemy.hp <= 0:
				break

## 奈落の精霊: for WALL_TURNS turns (2 more upgraded) the tiles no weapon reaches become pits.
func summon_abyss() -> void:
	abyss_turns = WALL_TURNS + 2 if is_plus("abyss_spirit") else WALL_TURNS
	events.append({"kind":"summon", "cell":player.cell, "id":-2, "fx":"abyss"})
	add_log("奈落が口を開けた")
	dig_abyss()

## 時の妖精: time stands still for the next enemy turn(s): no enemy moves or strikes
## (the shadow's strike waits too). Allies still act.
func stop_time() -> void:
	time_stop = maxi(time_stop, TIME_STOP_TURNS)
	events.append({"kind":"time_stop", "cell":player.cell, "id":-2})
	add_log("時が止まった")

func time_stopped() -> bool:
	return time_stop > 0

## 氷結妖精: every enemy in the 3x3 around the cell is frozen for FREEZE_TURNS enemy turns.
func freeze(cell: Vector2i) -> void:
	var turns := FREEZE_TURNS + (1 if is_plus("freeze_fairy") else 0)
	var area := square_around(cell, 1)
	events.append({"kind":"freeze", "cell":cell, "id":-2, "cells":area})
	var frozen := 0
	for tile in area:
		var enemy := enemy_at(tile)
		if not enemy.is_empty() and int(enemy.get("frozen", 0)) < turns:
			if int(enemy.get("frozen", 0)) == 0:
				frozen += 1
			enemy.frozen = turns
	add_log("氷結妖精が%d体を凍らせた" % frozen)

func frozen(enemy: Dictionary) -> bool:
	return int(enemy.get("frozen", 0)) > 0

## Tiles of the (2r+1)x(2r+1) square around a cell, on the board.
func square_around(cell: Vector2i, radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var tile := cell + Vector2i(dx, dy)
			if inside(tile):
				result.append(tile)
	return result

## 加護の妖精: blessed ground around the cell for WALL_TURNS turns (5x5 upgraded).
func place_blessing(cell: Vector2i) -> void:
	blessing = {"cell":cell, "turns":WALL_TURNS, "radius":2 if is_plus("blessing_fairy") else 1, "plus":is_plus("blessing_fairy")}
	events.append({"kind":"summon", "cell":cell, "id":-2, "fx":"holy"})
	add_log("加護の地が生まれた")

## 加護の妖精+: ending the player's turn on the blessed ground heals 1 (up to MAX_HP).
func bless_heal() -> void:
	if blessing.is_empty() or not blessing.get("plus", false) or not blessed(player.cell) or player.hp <= 0 or player.hp >= MAX_HP:
		return
	player.hp = mini(player.hp + BLESS_HEAL, MAX_HP)
	events.append({"kind":"heal", "cell":player.cell, "id":-1})
	add_log("加護の地でHPが%d回復した" % BLESS_HEAL)

func blessed(cell: Vector2i) -> bool:
	if blessing.is_empty():
		return false
	var gap: Vector2i = (cell - blessing.cell).abs()
	return gap.x <= int(blessing.radius) and gap.y <= int(blessing.radius)

## 隕石妖精: how many meteors fall (1, plus one per class-up level).
func meteor_count() -> int:
	return 1 + plus_level("meteor_fairy")

## 隕石妖精: meteors fall on random tiles of the current weapon's reach; each crushes the
## 3x3 around it for 3. The player and allies are spared. The pick is seeded, so the
## threat preview (a clone) sees the same tiles.
func meteor_strike() -> void:
	var pool: Array[Vector2i] = []
	pool.assign(bow_lines() if WEAPONS[weapon].get("ranged","") == "bishop" else targets())
	var picks: Array[Vector2i] = []
	var salt := 0
	while picks.size() < meteor_count() and not pool.is_empty():
		var index: int = absi(hash([slot_seed, round_number, player.cell, salt, "meteor"])) % pool.size()
		picks.append(pool.pop_at(index))
		salt += 1
	for center in picks:
		var area := square_around(center, 1)
		events.append({"kind":"meteor", "cell":center, "id":-2, "cells":area})
		var struck: Array = []
		for tile in area:
			var enemy := enemy_at(tile)
			if enemy.is_empty() or struck.has(enemy):
				continue
			struck.append(enemy)
			enemy.hp -= METEOR_DAMAGE
			events.append({"kind":"hit", "cell":enemy.cell, "id":enemy.id, "damage":METEOR_DAMAGE})
			if enemy.hp <= 0:
				kills += 1
				add_log("隕石が%sを押し潰した" % TYPES[enemy.type].name)
	add_log("隕石が%d個落ちた" % picks.size())
	var cannons_hit: Array = []
	for center in picks:
		for cannon in _cannons_in(square_around(center, 1)):
			if not cannons_hit.has(cannon):
				cannons_hit.append(cannon)
	_detonate(cannons_hit)
	check_outcome()

## Re-dig: every empty tile outside all weapons' reach is a pit (occupied tiles are spared).
func dig_abyss() -> void:
	if abyss_turns <= 0:
		return
	pits.clear()
	var reach := all_reach()
	for y in board_size:
		for x in board_size:
			var cell := Vector2i(x, y)
			if cell == player.cell or reach.has(cell) or blocked(cell) or not enemy_at(cell).is_empty() or mines.has(cell):
				continue
			pits.append(cell)

## A single-tile enemy shoved into a pit is gone, whatever its HP.
func _fall(enemy: Dictionary, cell: Vector2i) -> void:
	enemy.cell = cell
	enemy.hp = 0
	kills += 1
	pits.erase(cell)
	events.append({"kind":"fall", "cell":cell, "id":-2})
	events.append({"kind":"hit", "cell":cell, "id":enemy.id})
	add_log("%sが奈落に落ちた" % TYPES[enemy.type].name)
	check_outcome()

# --- 暴食妖精 -------------------------------------------------------------------

## Gold moves with the front to the right (the player's side of the fight).
const GLUTTON_MOVES = [Vector2i(1,0), Vector2i(1,-1), Vector2i(1,1), Vector2i(0,-1), Vector2i(0,1), Vector2i(-1,0)]

func summon_glutton(cell: Vector2i) -> void:
	var plus := is_plus("glutton_fairy")
	allies.append({"id":next_ally_id, "type":"glutton", "cell":cell, "hp":summon_hp("glutton_fairy"), "ap":summon_ap("glutton_fairy"), "facing":1, "plus":plus})
	_note_summon("glutton")
	next_ally_id -= 1
	events.append({"kind":"summon", "cell":cell, "id":-2, "fx":"acorn"})

## What it may bite from `cell`: the player, or a 1x1 enemy or ally (2x2 ones are too big).
func glutton_prey(glutton: Dictionary, cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset in GLUTTON_MOVES:
		var tile: Vector2i = cell + offset
		if tile == player.cell:
			result.append(tile)
			continue
		var other := enemy_at(tile)
		# Only 1x1 enemies fit in its mouth.
		if not other.is_empty() and other.type != "shadow" and int(other.get("size", 1)) == 1:
			result.append(tile)
			continue
		var ally := ally_at(tile)
		if not ally.is_empty() and ally.id != glutton.id and int(ally.get("size", 1)) == 1:
			result.append(tile)
	return result

## One bite deals 99, like the magic circle: the player, an enemy or an ally is swallowed
## whole. Every bite adds 1 HP.
func glutton_bite(glutton: Dictionary, tile: Vector2i) -> void:
	glutton.ap -= 1
	glutton.hp += GLUTTON_GROWTH
	var gap: Vector2i = tile - glutton.cell
	if CARDINALS.has(gap):
		glutton.facing = CARDINALS.find(gap)
	# "gulp" (the player, after a wind-up) or "devour" (swallowed whole), for the show.
	var big := int(enemy_at(tile).get("size", 1)) > 1 if tile != player.cell else false
	events.append({"kind":"gulp" if tile == player.cell else "devour", "cell":tile, "id":-2, "by":glutton.id, "from":glutton.cell, "big":big})
	if tile == player.cell:
		stats.eaten = true
		player.hp = maxi(player.hp - CIRCLE_DAMAGE, 0)
		events.append({"kind":"hit", "cell":tile, "id":-1, "by":glutton.id, "damage":CIRCLE_DAMAGE})
		add_log("暴食妖精があなたに噛みついた / %dダメージ" % CIRCLE_DAMAGE)
		check_outcome()
		return
	var other := enemy_at(tile)
	if not other.is_empty():
		other.hp = 0
		kills += 1
		events.append({"kind":"hit", "cell":tile, "id":other.id, "damage":CIRCLE_DAMAGE})
		add_log("暴食妖精が%sを喰らった" % TYPES[other.type].name)
		check_outcome()
		return
	var ally := ally_at(tile)
	if not ally.is_empty():
		ally.hp = 0
		events.append({"kind":"hit", "cell":tile, "id":ally.id, "damage":CIRCLE_DAMAGE})
		add_log("暴食妖精が%sを喰らった" % ALLY_NAMES.get(ally.type, "味方"))
		_bury_allies()
		check_outcome()

## Two actions: bite whatever is in reach (the player first); otherwise step along the
## shortest route over its own moves to a tile with prey in reach, the player's first.
func _glutton_action(glutton: Dictionary) -> void:
	glutton.ap = summon_ap("glutton_fairy")
	while glutton.ap > 0 and glutton.hp > 0 and not terminal():
		var prey := glutton_prey(glutton, glutton.cell)
		if not prey.is_empty():
			glutton_bite(glutton, player.cell if prey.has(player.cell) else prey[0])
			continue
		var start: Vector2i = glutton.cell
		var first := {start: start}
		var layer: Array[Vector2i] = [start]
		var step := start
		while not layer.is_empty() and step == start:
			var next_layer: Array[Vector2i] = []
			var found_other := start
			for current in layer:
				for offset in GLUTTON_MOVES:
					var next: Vector2i = current + offset
					if first.has(next) or not inside(next) or blocked(next) or next == player.cell or not enemy_at(next).is_empty():
						continue
					first[next] = next if current == start else first[current]
					var reach := glutton_prey(glutton, next)
					if reach.has(player.cell):
						step = first[next]
						break
					if not reach.is_empty() and found_other == start:
						found_other = first[next]
					next_layer.append(next)
				if step != start:
					break
			if step == start and found_other != start:
				step = found_other
			layer = next_layer
		if step == start:
			break
		glutton.ap -= 1
		var moved: Vector2i = step - glutton.cell
		if CARDINALS.has(moved):
			glutton.facing = CARDINALS.find(moved)
		glutton.cell = step
		trigger_mine(glutton)
	glutton.ap = 0

## 一匹狼の妖精: a lone ally that hunts on its own until it falls. It moves like a
## silver general facing right and bites the tiles it could move to.
const WOLF_MOVES = [Vector2i(1,0), Vector2i(1,-1), Vector2i(1,1), Vector2i(-1,-1), Vector2i(-1,1)]
func summon_wolf(cell: Vector2i) -> void:
	var plus := is_plus("lone_wolf")
	allies.append({"id":next_ally_id, "type":"wolf", "cell":cell, "hp":summon_hp("lone_wolf"), "ap":summon_ap("lone_wolf"), "facing":1, "plus":plus})
	_note_summon("wolf")
	next_ally_id -= 1
	events.append({"kind":"summon", "cell":cell, "id":-2, "fx":"wolf"})

## True when someone (the player or another ally) stands right next to the wolf.
func wolf_crowded(wolf: Dictionary) -> bool:
	for direction in CARDINALS:
		var cell: Vector2i = wolf.cell + direction
		if cell == player.cell:
			return true
		var other := ally_at(cell)
		if not other.is_empty() and other.id != wolf.id:
			return true
	return false

## Within any weapon's reach the wolf sulks. Otherwise it spends its 3 AP one at a
## time: a bite on an enemy it reaches (2 alone, 1 with company), or a silver step
## toward one. (The class-up only makes it free to summon.)
func _wolf_action(wolf: Dictionary) -> void:
	wolf.sulking = all_reach().has(wolf.cell)
	if wolf.sulking:
		add_log("一匹狼の妖精はそっぽを向いた")
		wolf.ap = 0
		return
	wolf.ap = summon_ap("lone_wolf")
	while wolf.ap > 0 and wolf.hp > 0 and not terminal():
		var prey := _wolf_prey(wolf, wolf.cell)
		if not prey.is_empty():
			wolf.ap -= 1
			var target: Dictionary = prey.enemy
			events.append({"kind":"bite", "cell":wolf.cell + prey.dir, "id":-2})
			damage_enemy(target, WOLF_CROWDED_BITE if wolf_crowded(wolf) else WOLF_BITE, prey.dir)
			add_log("一匹狼の妖精が噛みついた")
			check_outcome()
			continue
		var step := _wolf_step(wolf)
		if step == wolf.cell:
			break
		wolf.ap -= 1
		wolf.cell = step
		trigger_mine(wolf)
	wolf.ap = 0

## The weakest enemy the wolf reaches from `from`, as {enemy, dir}; empty when none.
func _wolf_prey(wolf: Dictionary, from: Vector2i) -> Dictionary:
	var best: Dictionary = {}
	for direction in WOLF_MOVES:
		var enemy := enemy_at(from + direction)
		if enemy.is_empty():
			continue
		if best.is_empty() or enemy.hp < best.enemy.hp or (enemy.hp == best.enemy.hp and enemy.id < best.enemy.id):
			best = {"enemy":enemy, "dir":direction}
	return best

## The first silver step on the shortest way to a tile from which an enemy is in reach.
func _wolf_step(wolf: Dictionary) -> Vector2i:
	var start: Vector2i = wolf.cell
	var first := {start: start}
	var layer: Array[Vector2i] = [start]
	while not layer.is_empty():
		var next_layer: Array[Vector2i] = []
		for current in layer:
			for offset in WOLF_MOVES:
				var next: Vector2i = current + offset
				if first.has(next) or not inside(next) or blocked(next) or next == player.cell or mines.has(next) or not enemy_at(next).is_empty():
					continue
				first[next] = next if current == start else first[current]
				if not _wolf_prey(wolf, next).is_empty():
					return first[next]
				next_layer.append(next)
		layer = next_layer
	return start

func act_allies() -> void:
	if terminal():
		return
	events.clear()
	for ally in allies.duplicate():
		if ally.hp <= 0 or terminal():
			continue
		ally.ap = 1
		if ally.type in ["holy", "guardian"]:
			# The guardian moves and strikes like the holy spirit.
			_holy_action(ally)
			continue
		if ally.type == "wolf":
			_wolf_action(ally)
			continue
		if ally.type == "glutton":
			_glutton_action(ally)
			continue
		# 聖騎士 act twice a turn (HP 2, AP 2, like the executioner); others once.
		for k in HOLY_KNIGHT_AP if ally.type == "holy_knight" else 1:
			if ally.hp <= 0 or terminal():
				break
			_basic_ally_action(ally)
	check_outcome()

## どんぐり妖精・聖騎士: set off a touching cannon, else bite the weakest neighbour,
## else take a step toward the nearest enemy.
func _basic_ally_action(ally: Dictionary) -> void:
	# A cannon next to it is fair game: the acorn sets it off (a chain beats a single hit).
	var touched := {}
	var touch_dir := Vector2i.ZERO
	for offset in CARDINALS + (DIAGONALS if ally.get("plus", false) else []):
		var cannon := cannon_at(ally.cell + offset)
		if not cannon.is_empty() and touched.is_empty():
			touched = cannon
			touch_dir = offset
	if not touched.is_empty():
		ally.ap = 0
		events.append({"kind":"bump", "cell":ally.cell, "id":-2, "dir":touch_dir})
		add_log("%sが%sを叩いた" % [ALLY_NAMES[ally.type], CANNON_TITLES[touched.kind]])
		start_chain()
		fire_cannon(touched)
		check_outcome()
		return
	var adjacent: Array[Dictionary] = []
	for enemy in enemies:
		var gap: Vector2i = (enemy.cell - ally.cell).abs()
		# The upgraded acorn also reaches the diagonal neighbours.
		if enemy.hp > 0 and (distance(ally.cell,enemy.cell) == 1 or (ally.get("plus", false) and gap == Vector2i.ONE)):
			adjacent.append(enemy)
	adjacent.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		return a.hp < b.hp if a.hp != b.hp else a.id < b.id)
	if not adjacent.is_empty():
		var gap_to: Vector2i = adjacent[0].cell - ally.cell
		if absi(gap_to.x) + absi(gap_to.y) == 1:
			ally.facing = CARDINALS.find(gap_to)
		damage_enemy(adjacent[0],1)
		ally.ap = 0
		add_log("%sが攻撃" % ALLY_NAMES[ally.type])
		check_outcome()
		return
	_step_toward_enemy(ally)
	ally.ap = 0

## One step toward the nearest reachable enemy (breadth-first, never crossing
## allies or mines). False when no enemy can be reached or none is left.
func _step_toward_enemy(ally: Dictionary) -> bool:
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
		ally.facing = CARDINALS.find(destination - start)
		ally.cell = destination
		trigger_mine(ally)
		return true
	return false


## 聖精霊: like the moving prison, but on the player's side. It strikes an enemy
## touching one of its sides, otherwise slides one tile toward the nearest enemy.
func _holy_action(holy: Dictionary) -> void:
	holy.ap = 0
	for direction in CARDINALS:
		for tile in _front_cells(holy, direction):
			var enemy := enemy_at(tile)
			if not enemy.is_empty():
				holy.facing = CARDINALS.find(direction)
				damage_enemy(enemy, 1, direction)
				add_log("%sが攻撃" % ALLY_NAMES[holy.type])
				check_outcome()
				return
	var best := Vector2i.ZERO
	var best_score := _holy_distance(holy)
	for direction in CARDINALS:
		var free := true
		for tile in _front_cells(holy, direction):
			if not inside(tile) or blocked(tile) or tile == player.cell or mines.has(tile) or not enemy_at(tile).is_empty():
				free = false
		if not free:
			continue
		var probe := holy.duplicate()
		probe.cell = holy.cell + direction
		var score := _holy_distance(probe)
		if score < best_score:
			best = direction
			best_score = score
	if best != Vector2i.ZERO:
		holy.cell += best
		holy.facing = CARDINALS.find(best)

func _holy_distance(holy: Dictionary) -> int:
	var best := 999
	for enemy in enemies:
		if enemy.hp > 0:
			for tile in footprint(enemy):
				best = mini(best, footprint_distance(holy, tile))
	return best

# --- wall, cannon and slash fairies ---------------------------------------

func place_wall(cell: Vector2i) -> void:
	walls[cell] = WALL_TURNS
	events.append({"kind":"summon", "cell":cell, "id":-2, "fx":"wall"})

## The upgraded wall: up to two more tiles in a straight line from the first,
## stopping at the first tile that is taken or off the board.
func wall_extension(cell: Vector2i, direction: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not CARDINALS.has(direction):
		return result
	var next := cell + direction
	while result.size() < 2 and inside(next) and not blocked(next) and next != player.cell and enemy_at(next).is_empty():
		result.append(next)
		next += direction
	return result

## A forged swap weapon's free swap is still unused this turn.
func free_swap_ready() -> bool:
	return WEAPONS[weapon].get("swap", false) and weapon_power.has(weapon) and not free_swap_used

## Called when a new player turn begins: walls count down and crumble.
func tick_walls() -> void:
	free_swap_used = false
	turn_chain = 0
	# 溜め大剣 stores one more point for every turn it sat unused.
	if not blade_used:
		blade_charge = mini(blade_charge + 1, blade_max())
	blade_used = false
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
	if abyss_turns > 0:
		abyss_turns -= 1
		if abyss_turns <= 0:
			pits.clear()
			add_log("奈落が閉じた")
		else:
			dig_abyss()
	if not blessing.is_empty():
		blessing.turns -= 1
		if blessing.turns <= 0:
			blessing = {}
			add_log("加護が消えた")
	for enemy in enemies:
		if int(enemy.get("frozen", 0)) > 0:
			enemy.frozen -= 1
	if time_stop > 0:
		time_stop -= 1
		if time_stop == 0:
			add_log("時が動き出した")
	if not shadow.is_empty():
		shadow.turns -= 1
		shadow.ready = true
		if shadow.turns <= 0:
			shadow = {}
			add_log("影縫い精霊が消えた")
	for cell in fairy_turns.keys():
		fairy_turns[cell] -= 1
		if fairy_turns[cell] <= 0:
			fairy_turns.erase(cell)
			fairies.erase(cell)
			add_log("隠密妖精が消えた")

func place_stealth(cell: Vector2i) -> void:
	fairies.append(cell)
	fairy_turns[cell] = WALL_TURNS
	_note_summon("stealth")

func cannon_at(cell: Vector2i) -> Dictionary:
	for cannon in cannons:
		if cannon.cell == cell:
			return cannon
	return {}

func place_cannon(cell: Vector2i, direction: Vector2i, kind: String, plus: bool = false) -> void:
	cannons.append({"cell":cell, "dir":direction, "kind":kind, "turns":WALL_TURNS, "charge":0, "plus":plus})
	events.append({"kind":"summon", "cell":cell, "id":-2, "fx":"cannon"})

const CANNON_VOLLEYS := 2

## Fire a cannon. A shot or burst that reaches another cannon sets it off too.
func fire_cannon(cannon: Dictionary, fired: Array = []) -> void:
	if fired.has(cannon.cell):
		return
	fired.append(cannon.cell)
	# Each cannon in a chain goes off one beat after the last (chain_clock), so the
	# chain reads; its events are stamped with the moment it fires.
	var first_event := events.size()
	var at := chain_clock
	# The chain counts every cannon going off this player turn: a new strike carries
	# the count on instead of starting over.
	turn_chain += 1
	stats.max_chain = maxi(int(stats.max_chain), turn_chain)
	if turn_chain >= 2:
		events.append({"kind":"chain", "cell":cannon.cell, "id":-2, "count":turn_chain, "delay":at})
	_fire_cannon(cannon, fired)
	for i in range(first_event, events.size()):
		if not events[i].has("delay"):
			events[i].delay = at

const CHAIN_BEAT := 0.18
## The second volley follows the first volley's whole chain after a clear beat.
const VOLLEY_GAP := 0.3
## Timeline of the chain being resolved (seconds from its first shot).
var chain_clock := 0.0
## Cannons gone off this player turn, through its end (CHAIN ×n keeps counting).
var turn_chain := 0

## Start a new chain's timeline (a strike, a bolt, an acorn, the turn-end charge).
func start_chain() -> void:
	chain_clock = 0.0

## The next link: one beat later, another cannon goes off.
func _chain_to(other: Dictionary, fired: Array) -> void:
	if fired.has(other.cell) or not cannons.has(other):
		return
	chain_clock += CHAIN_BEAT
	events.append({"kind":"resonate", "cell":other.cell, "id":-2, "delay":chain_clock})
	fire_cannon(other, fired)

func _fire_cannon(cannon: Dictionary, fired: Array) -> void:
	if cannon.kind == "capacitor":
		_charge_capacitor(cannon, fired)
		return
	add_log("%sが発射" % CANNON_TITLES[cannon.kind])
	if cannon.kind == "firework":
		# The burst does not pick sides: enemies, allies and the player all take 1.
		cannons.erase(cannon)
		struck_ids.clear()
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
				var spared: bool = cannon.get("plus", false)
				if cell == player.cell and not spared:
					player.hp -= 1
					events.append({"kind":"hit", "cell":cell, "id":-1})
					add_log("花火に巻き込まれた / HP −1")
				var ally := ally_at(cell)
				if not ally.is_empty() and not spared:
					ally.hp -= 1
					events.append({"kind":"hit", "cell":cell, "id":ally.id})
				var other := cannon_at(cell)
				if not other.is_empty():
					_chain_to(other, fired)
		return
	var passed: Array = []
	# Lance and vane cannons fire straight ahead twice (the vane turns after the pair).
	var shot_dir: Vector2i = cannon.dir
	# The first volley, then everything it sets off, then the second volley at once.
	# One shot; the classed-up vane fires two (the lance's class-up is 0 AP and a second use instead).
	var volleys := CANNON_VOLLEYS if cannon.get("plus", false) and cannon.kind == "vane" else 1
	for volley in volleys:
		# Each volley may hit a big enemy once (the guard counts per volley, not per chain).
		struck_ids.clear()
		var first_event := events.size()
		var cells := cannon_line(cannon.cell, shot_dir, passed)
		events.append({"kind":"muzzle", "cell":cannon.cell, "id":-2, "dir":shot_dir})
		for cell in cells:
			events.append({"kind":"shot", "cell":cell, "id":-2, "dir":shot_dir})
			var enemy := enemy_at(cell)
			if not enemy.is_empty():
				damage_enemy(enemy, 1, shot_dir)
		if volley > 0:
			chain_clock += VOLLEY_GAP
			for i in range(first_event, events.size()):
				events[i].delay = chain_clock
		else:
			_resonate(passed, fired)
	if cannon.kind == "vane":
		cannon.dir = CARDINALS[(CARDINALS.find(cannon.dir) + 1) % 4]

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
		_chain_to(other, fired)

## Capacitor: every strike (a weapon or a chained cannon shot) stores 1; at 3 it
## discharges down all four lines, then starts charging again.
func _charge_capacitor(cannon: Dictionary, fired: Array) -> void:
	cannon.charge = int(cannon.get("charge", 0)) + 1
	events.append({"kind":"spark", "cell":cannon.cell, "id":-2})
	if cannon.charge < CAPACITOR_FULL:
		add_log("蓄電の妖精に電気が溜まった（%d/%d）" % [cannon.charge, CAPACITOR_FULL])
		return
	cannon.charge = 0
	struck_ids.clear()
	events.append({"kind":"discharge", "cell":cannon.cell, "id":-2})
	add_log("蓄電の妖精が放電！")
	var passed: Array = []
	for direction in CARDINALS:
		for cell in cannon_line(cannon.cell, direction, passed):
			events.append({"kind":"zap", "cell":cell, "id":-2, "dir":direction})
			var enemy := enemy_at(cell)
			if not enemy.is_empty():
				damage_enemy(enemy, 1, direction)
	_resonate(passed, fired)

## Three parallel lanes: the lane through the placed tile and its two neighbours; the
## plain slash's tiles above and below the placed tile are cut as well.
func slash_cells(origin: Vector2i, direction: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not CARDINALS.has(direction):
		return result
	result.append_array(side_slash_cells(origin))
	var side := Vector2i(-direction.y, direction.x)
	for k in [-1, 0, 1]:
		for cell in ray_cells(origin + side * k, direction).slice(0, SLASH_REACH):
			if not result.has(cell):
				result.append(cell)
	return result

## 斬撃精霊+: the wave covers a solid 5x3 block ahead (each lane stops at a blocker).
const SLASH_REACH := 5

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

## 斬撃精霊: the two tiles above and below where it is placed.
func side_slash_cells(origin: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for side in [Vector2i.UP, Vector2i.DOWN]:
		if inside(origin + side):
			result.append(origin + side)
	return result

func side_slash(origin: Vector2i) -> void:
	_slash_hit(side_slash_cells(origin), Vector2i.DOWN)
	_detonate(_cannons_in(side_slash_cells(origin)))

func front_slash(origin: Vector2i, direction: Vector2i) -> void:
	_slash_hit(front_slash_cells(origin, direction), direction)

## 飛刃精霊 (the slash's class-up): the three-lane wave flies to the edge.
func slash(origin: Vector2i, direction: Vector2i) -> void:
	_slash_hit(slash_cells(origin, direction), direction)
	# A lane stops at a cannon: the cannon it ran into goes off.
	var hit: Array = _cannons_in(side_slash_cells(origin))
	var side := Vector2i(-direction.y, direction.x)
	for k in [-1, 0, 1]:
		var cell: Vector2i = origin + side * k + direction
		for step in SLASH_REACH:
			if not inside(cell):
				break
			var cannon := cannon_at(cell)
			if not cannon.is_empty():
				if not hit.has(cannon):
					hit.append(cannon)
				break
			if blocked(cell):
				break
			cell += direction
	_detonate(hit)

## Damage-dealing fairies set off the cannons they strike: a chain, like a cannon shot
## that passed through them.
func _cannons_in(cells: Array) -> Array:
	var found: Array = []
	for cell in cells:
		var cannon := cannon_at(cell)
		if not cannon.is_empty() and not found.has(cannon):
			found.append(cannon)
	return found

func _detonate(cannons_hit: Array) -> void:
	if cannons_hit.is_empty():
		return
	stats.fairy_set_off = true
	start_chain()
	_resonate(cannons_hit, [])

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
	if id == "axe_spirit":
		return axe_preview(origin, direction)
	if id == "wall_fairy":
		result.append(origin)
		result.append_array(wall_extension(origin, direction))
	elif id == "slash_fairy":
		result.append_array(slash_cells(origin, direction) if is_plus(id) else side_slash_cells(origin))
	elif id in ["cannon_fairy", "vane_cannon"]:
		result.append_array(cannon_line(origin, direction, []))
		if is_plus(id):
			result.append_array(cannon_line(origin, -direction, []))
	else:
		result.append_array(ray_cells(origin, direction))
		if id == "magic_bolt" and is_plus(id):
			result.append_array(ray_cells(origin, -direction))
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
	for fortress in enemies.duplicate():
		if fortress.type == "fortress" and fortress.hp <= 0 and not fortress.get("released", false):
			fortress.released = true
			ruins.append(fortress.cell)
			add_log("要塞監獄が崩れた")
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
		while inside(cell) and not charge_stopped(cell):
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
	var shoved: Array = []
	var steps := 0
	while steps < board_size * 2:
		steps += 1
		var front := _front_cells(enemy, forward)
		var stop := false
		for cell in front:
			if not inside(cell):
				stop = true
			elif pits.has(cell):
				# Too big to fall: it stops where it stands, at the edge of the abyss.
				stop = true
			elif _smash(cell):
				# Placed things in the lane are smashed, and the charge stops there.
				stop = true
			elif not ramming and not enemy_at(cell).is_empty() and enemy_at(cell).id != enemy.id:
				stop = true
		if stop:
			break
		if ramming:
			# Charging at the player: enemies in the way are driven ahead along with them.
			var chain := _charge_chain(enemy, forward)
			if chain.player and not hit:
				hit = true
				_hit_player(enemy)
				if terminal():
					break
			if not chain.ok:
				break
			for other in chain.enemies:
				other.cell += forward
				if pits.has(other.cell) and int(other.get("size", 1)) == 1:
					_fall(other, other.cell)
					continue
				if not shoved.has(other):
					shoved.append(other)
			if chain.player:
				player.cell += forward
				pushed = true
			events.append({"kind":"dash", "cell":enemy.cell, "id":-2, "dir":forward})
			enemy.cell += forward
			continue
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
	for other in shoved:
		if other.hp > 0 and not terminal():
			trigger_mine(other)
	# Where this charge ended, so several charges in one turn can be shown one by one.
	events.append({"kind":"charge_end", "cell":enemy.cell, "id":enemy.id, "player":player.cell})
	add_log("%sの突進" % TYPES[enemy.type].name + ("！ 壁まで押し込まれた" if hit else ""))
	check_outcome()
	if not terminal() and enemy.hp > 0:
		rook_brace(enemy)
	return true

## What a ramming charge shoves one tile this step: the player and every enemy
## packed in front of the charger. ok is false when something in that chain is
## up against the edge or terrain (the charge stops; a player in it is still hit).
func _charge_chain(charger: Dictionary, forward: Vector2i) -> Dictionary:
	var result := {"ok":true, "enemies":[], "player":false}
	var queue: Array[Vector2i] = _front_cells(charger, forward)
	var seen := {}
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if seen.has(cell):
			continue
		seen[cell] = true
		var cells: Array[Vector2i] = []
		if cell == player.cell:
			result.player = true
			cells.append(cell)
		else:
			var other := enemy_at(cell)
			if other.is_empty() or other.id == charger.id or result.enemies.has(other):
				continue
			result.enemies.append(other)
			cells = footprint(other)
		for tile in cells:
			var next: Vector2i = tile + forward
			if cells.has(next):
				continue
			if cell != player.cell and cells.size() == 1 and pits.has(next):
				# Shoved into the abyss: this enemy falls (see rook_charge).
				continue
			if not inside(next) or blocked(next):
				result.ok = false
			else:
				queue.append(next)
	return result

# --- final boss: the Prison King and his fortresses -------------------------

## Tiles touching a big unit's footprint (its reach, like a king in shogi).
func ring_of(unit: Dictionary) -> Array[Vector2i]:
	var cells := footprint(unit)
	var result: Array[Vector2i] = []
	for cell in cells:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var next: Vector2i = cell + Vector2i(dx, dy)
				if inside(next) and not cells.has(next) and not result.has(next):
					result.append(next)
	return result

## Free tiles around a unit, nearest to the player first.
func _free_ring(unit: Dictionary) -> Array[Vector2i]:
	var spots: Array[Vector2i] = ring_of(unit).filter(func(c: Vector2i) -> bool:
		return c != player.cell and not blocked(c) and enemy_at(c).is_empty() and not pits.has(c) and not mines.has(c))
	spots.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return distance(a, player.cell) < distance(b, player.cell) if distance(a, player.cell) != distance(b, player.cell) else a.y < b.y)
	return spots

## A soldier kind drawn from the fight's own seed, so look-ahead copies agree.
func _soldier_kind(unit: Dictionary, salt: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([slot_seed, round_number, int(unit.id), salt])
	return SOLDIERS[rng.randi_range(0, SOLDIERS.size() - 1)]

## Put a soldier on the free tile around `unit` nearest the player; it acts next turn.
func _spawn_soldier(unit: Dictionary, kind: String, revived: bool) -> bool:
	var spots := _free_ring(unit)
	if spots.is_empty():
		return false
	var next_id := 0
	for other in enemies:
		next_id = maxi(next_id, int(other.id) + 1)
	var soldier := make_enemy(kind, spots[0], next_id)
	soldier.ap = 0
	enemies.append(soldier)
	events.append({"kind":"summon", "cell":spots[0], "id":-2, "fx":"revive" if revived else "prison", "by":unit.id})
	return true

## Remember every soldier that fell while the king still stands.
func _note_fallen() -> void:
	if level != FINAL_LEVEL:
		return
	for king in enemies:
		if king.type == "king" and king.hp <= 0 and not king.get("fell", false):
			king.fell = true
			events.append({"kind":"king_fall", "cell":king.cell + Vector2i.ONE, "id":-2, "king":king.id})
	for enemy in enemies:
		if enemy.hp <= 0 and enemy.type in SOLDIERS and not enemy.get("noted", false):
			enemy.noted = true
			fallen.append(enemy.type)

## 監獄の王: never moves and never attacks. His reach (a shogi king's: every tile
## touching him) is only where he raises the first soldier that fell, on the free tile
## nearest the player.
## The king raises one fallen soldier every other turn (KING_REVIVE_EVERY).
func king_turn(king: Dictionary) -> void:
	king.ap = 0
	if round_number % KING_REVIVE_EVERY != 0:
		king.intent = "力を溜めている"
		return
	if fallen.is_empty():
		king.intent = "静観"
		return
	var kind: String = fallen[0]
	if _spawn_soldier(king, kind, true):
		fallen.pop_front()
		king.intent = "復活"
		add_log("監獄の王が%sを蘇らせた" % TYPES[kind].name)

## True once the Prison King has fallen to half health.
func king_enraged() -> bool:
	return enemies.any(func(e: Dictionary) -> bool: return e.type == "king" and e.hp > 0 and e.hp <= KING_RAGE_HP)

## The moment the king drops to half health he roars (once).
func _check_rage() -> void:
	for king in enemies:
		if king.type == "king" and king.hp > 0 and king.hp <= KING_RAGE_HP and not king.get("enraged", false):
			king.enraged = true
			events.append({"kind":"roar", "cell":king.cell + Vector2i.ONE, "id":-2})
			events.append({"kind":"king_rage", "cell":king.cell + Vector2i.ONE, "id":-2})
			add_log("監獄の王が怒り狂った！ 要塞監獄が兵を2体ずつ出す")

## 要塞監獄: every turn it lets out one soldier of a random kind (two once the king is enraged).
func fortress_turn(fortress: Dictionary) -> void:
	fortress.ap = 0
	for k in 2 if king_enraged() else 1:
		var kind := _soldier_kind(fortress, k)
		if _spawn_soldier(fortress, kind, false):
			fortress.intent = "出撃"
			add_log("要塞監獄から%sが出てきた" % TYPES[kind].name)

## The next soldier the king will raise, for the inspector.
func next_revival() -> String:
	return fallen[0] if not fallen.is_empty() else ""

## A charger crashing into a tile: walls, cannons, stealth fairies, the pinned
## shadow, allies and obstacles there are destroyed. Returns true if anything was in the way.
func _smash(cell: Vector2i) -> bool:
	var hit := false
	if walls.has(cell):
		walls.erase(cell)
		hit = true
	var cannon := cannon_at(cell)
	if not cannon.is_empty():
		cannons.erase(cannon)
		hit = true
	if fairies.has(cell):
		fairies.erase(cell)
		fairy_turns.erase(cell)
		hit = true
	if obstacles.has(cell):
		obstacles.erase(cell)
		hit = true
	if shadow.get("cell", Vector2i(-1, -1)) == cell:
		shadow = {}
		hit = true
	var ally := ally_at(cell)
	if not ally.is_empty():
		ally.hp = 0
		_bury_allies()
		hit = true
	if hit:
		events.append({"kind":"smash", "cell":cell, "id":-2})
		add_log("突進で障害物が砕けた")
	return hit

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

## Reel 7: the first charge always reaches the player; blockers in the way are smashed first.
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

## Reel 6: Rotorick leaves a purple hologram of itself where it stood.
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
	add_log("ロトリックが残像を残した")

## A shadow cuts a player who stands next to it, once, then fades.
func shadow_strike() -> void:
	if time_stopped():
		return
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
