extends RefCounted

# World-space offsets: the player always faces right. All weapons use sword art.
const DATA = [
	{"id":"forward", "name":"前進剣", "short":"前進", "row":2, "color":"f4d56f", "detail":"右の1マス", "offsets":[Vector2i(1,0)]},
	{"id":"backward", "name":"後退剣", "short":"後退", "row":2, "color":"94baff", "detail":"左の1マス", "offsets":[Vector2i(-1,0)]},
	{"id":"vertical", "name":"上下剣", "short":"上下", "row":2, "color":"bda0ff", "detail":"上・下の2マス", "offsets":[Vector2i(0,-1),Vector2i(0,1)]},
	{"id":"front_diagonal", "name":"前斜剣", "short":"前斜め", "row":2, "color":"ffad70", "detail":"右上・右下の2マス", "offsets":[Vector2i(1,-1),Vector2i(1,1)]},
	{"id":"back_diagonal", "name":"後斜剣", "short":"後斜め", "row":2, "color":"80dcb5", "detail":"左上・左下の2マス", "offsets":[Vector2i(-1,-1),Vector2i(-1,1)]},
	{"id":"assault", "name":"突進剣", "short":"突進", "row":2, "color":"ffbc75", "detail":"右上・右・右下", "offsets":[Vector2i(1,-1),Vector2i(1,0),Vector2i(1,1)]},
	{"id":"diagonal", "name":"交差剣", "short":"交差", "row":2, "color":"d9a0ff", "detail":"斜め4マス", "offsets":[Vector2i(-1,-1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(1,1)]},
	{"id":"upper", "name":"上弦剣", "short":"上弦", "row":2, "color":"90cfff", "detail":"左上・上・右上", "offsets":[Vector2i(-1,-1),Vector2i(0,-1),Vector2i(1,-1)]},
	{"id":"cross", "name":"十字剣", "short":"十字", "row":2, "color":"61dfcf", "detail":"縦横4マス", "offsets":[Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]},
	# Jump weapons skip over a square, so the early rule lets them take two tiles.
	{"id":"vault", "name":"縦跳剣", "short":"縦跳", "row":2, "color":"8fc4ff", "detail":"上・下へ2マス跳ぶ", "offsets":[Vector2i(0,-2),Vector2i(0,2)]},
	{"id":"knight", "name":"桂馬剣", "short":"桂馬", "row":2, "color":"2bdcc8", "detail":"右へ2・上下へ1に跳ぶ", "offsets":[Vector2i(2,-1),Vector2i(2,1)]},
	{"id":"sky_knight", "name":"天桂剣", "short":"天桂", "row":2, "color":"4fe0a8", "detail":"上へ2・左右へ1に跳ぶ", "offsets":[Vector2i(-1,-2),Vector2i(1,-2)]},
	# Odd up-and-down jumpers: variants of the vertical jump and the knights.
	{"id":"tall_knight", "name":"立桂剣", "short":"立桂", "row":2, "color":"6fe0ff", "detail":"右へ1・上下へ2に跳ぶ", "offsets":[Vector2i(1,-2),Vector2i(1,2)]},
	{"id":"twist_knight", "name":"捻桂剣", "short":"捻桂", "row":2, "color":"ff9fd0", "detail":"右上の桂馬と左下の桂馬に跳ぶ", "offsets":[Vector2i(2,-1),Vector2i(-2,1)]},
	{"id":"bolt", "name":"稲妻剣", "short":"稲妻", "row":2, "color":"fff06a", "detail":"右上2段と左下2段に跳ぶ", "offsets":[Vector2i(1,-2),Vector2i(-1,2)]},
	{"id":"fork", "name":"燕返剣", "short":"燕返", "row":2, "color":"ff8a8a", "detail":"右上・右下へ斜めに2マス跳ぶ", "offsets":[Vector2i(2,-2),Vector2i(2,2)]},
	{"id":"slant", "name":"袈裟剣", "short":"袈裟", "row":2, "color":"ffb36b", "detail":"右上と左下へ斜めに2マス跳ぶ", "offsets":[Vector2i(2,-2),Vector2i(-2,2)]},
	{"id":"crane", "name":"鶴翼剣", "short":"鶴翼", "row":2, "color":"e0c8ff", "detail":"右上へ斜め2・右下の桂馬に跳ぶ", "offsets":[Vector2i(2,-2),Vector2i(2,1)]},
	# Mixed: one neighbouring tile plus one jump.
	{"id":"goose", "name":"雁行剣", "short":"雁行", "row":2, "color":"ffd9a0", "detail":"上の1マスと右下の桂馬", "offsets":[Vector2i(0,-1),Vector2i(2,1)]},
	{"id":"flick_up", "name":"跳上剣", "short":"跳上", "row":2, "color":"ffe6a0", "detail":"右上の1マスと下へ2マス", "offsets":[Vector2i(1,-1),Vector2i(0,2)]},
	{"id":"snake", "name":"蛇行剣", "short":"蛇行", "row":2, "color":"d0ff9a", "detail":"左上の1マスと右下の桂馬", "offsets":[Vector2i(-1,-1),Vector2i(2,1)]},
	{"id":"shoulder", "name":"背負剣", "short":"背負", "row":2, "color":"ff9ad0", "detail":"左下の1マスと右上の桂馬", "offsets":[Vector2i(-1,1),Vector2i(2,-1)]},
	# Odd three-tile weapons: pre-boss rewards (and later), never as strong as a four-tile cross.
	{"id":"fan", "name":"扇剣", "short":"扇", "row":2, "color":"ffc76b", "detail":"右上・右下の1マスと、右へ2マス跳ぶ", "offsets":[Vector2i(1,-1),Vector2i(2,0),Vector2i(1,1)]},
	{"id":"scales", "name":"天秤剣", "short":"天秤", "row":2, "color":"e6d08a", "detail":"上・下の1マスと、右へ2マス跳ぶ", "offsets":[Vector2i(0,-1),Vector2i(0,1),Vector2i(2,0)]},
	{"id":"swallow", "name":"飛燕剣", "short":"飛燕", "row":2, "color":"9fe0ff", "detail":"右の1マスと、右上・右下へ斜めに2マス跳ぶ", "offsets":[Vector2i(1,0),Vector2i(2,-2),Vector2i(2,2)]},
	{"id":"glance", "name":"見返剣", "short":"見返", "row":2, "color":"c9a0ff", "detail":"右の1マスと、左の桂馬2つ", "offsets":[Vector2i(1,0),Vector2i(-2,-1),Vector2i(-2,1)]},
	{"id":"tower", "name":"城楼剣", "short":"城楼", "row":2, "color":"a0ffc8", "detail":"右の1マスと、上・下へ2マス跳ぶ", "offsets":[Vector2i(1,0),Vector2i(0,-2),Vector2i(0,2)]},
	{"id":"tee", "name":"丁字剣", "short":"丁字", "row":2, "color":"ffe0a0", "detail":"上・右・下の1マス", "offsets":[Vector2i(0,-1),Vector2i(1,0),Vector2i(0,1)]},
	# Knockback: a struck enemy is shoved one tile away; if it cannot move it takes 1 more.
	{"id":"shield", "name":"盾打ち", "short":"盾", "row":2, "color":"b8d7c5", "knockback":1, "detail":"右の1マス。攻撃した敵を右へ押し出す", "offsets":[Vector2i(1,0)]},
	{"id":"sweep", "name":"薙ぎ払い", "short":"薙払", "row":2, "color":"d7c5b8", "knockback":1, "detail":"上・下の1マス。攻撃した敵を上下へ押し出す", "offsets":[Vector2i(0,-1),Vector2i(0,1)]},
	{"id":"gale", "name":"突風剣", "short":"突風", "row":2, "color":"c5f0ff", "knockback":1, "detail":"右上・右・右下。攻撃した敵を外側へ押し出す", "offsets":[Vector2i(1,-1),Vector2i(1,0),Vector2i(1,1)]},
	# Mid-game weapons, dropped after the first boss.
	{"id":"hammer", "name":"ハンマー", "short":"槌", "row":0, "color":"c9d6e0", "tier":"mid", "damage":3, "detail":"右の1マス。攻撃は3ダメージで、横2マス＋その右3マスにも響く", "offsets":[Vector2i(1,0)]},
	{"id":"bow", "name":"弓", "short":"弓", "row":2, "color":"b7e07a", "tier":"mid", "ranged":"bishop", "detail":"斜め4方向に一直線に射る。移動はできない", "offsets":[Vector2i(-2,-2),Vector2i(-1,-1),Vector2i(1,-1),Vector2i(2,-2),Vector2i(-2,2),Vector2i(-1,1),Vector2i(1,1),Vector2i(2,2)]},
# Weapons with their own mechanics (not just a shape).
	{"id":"lance", "name":"香車槍", "short":"香車", "row":2, "color":"ffb070", "tier":"boss", "slide":[Vector2i.RIGHT], "detail":"右へ一直線に滑る。最初の敵を攻撃", "offsets":[Vector2i(1,0),Vector2i(2,0)]},
	{"id":"rook_spear", "name":"飛車槍", "short":"飛車", "row":2, "color":"ff7a7a", "tier":"late", "slide":[Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT], "detail":"縦横に滑る。最初の敵を攻撃", "offsets":[Vector2i(0,-1),Vector2i(0,-2),Vector2i(1,0),Vector2i(2,0),Vector2i(0,1),Vector2i(0,2),Vector2i(-1,0),Vector2i(-2,0)]},
	{"id":"bishop_blade", "name":"角剣", "short":"角", "row":2, "color":"7aa8ff", "tier":"late", "slide":[Vector2i(-1,-1),Vector2i(1,-1),Vector2i(1,1),Vector2i(-1,1)], "detail":"斜めに滑る。最初の敵を攻撃", "offsets":[Vector2i(-1,-1),Vector2i(-2,-2),Vector2i(1,-1),Vector2i(2,-2),Vector2i(1,1),Vector2i(2,2),Vector2i(-1,1),Vector2i(-2,2)]},
	{"id":"sickle", "name":"鎖鎌", "short":"鎖鎌", "row":2, "color":"b8c4d0", "pull":true, "detail":"縦横2マス先へ。敵は攻撃して引き寄せる", "offsets":[Vector2i(0,-2),Vector2i(2,0),Vector2i(0,2),Vector2i(-2,0)]},
	{"id":"swap_staff", "name":"入替の杖", "short":"入替", "row":2, "color":"c89bff", "swap":true, "early":true, "detail":"左右の桂馬へ跳ぶ。敵とは入れ替え（無傷）", "offsets":[Vector2i(2,-1),Vector2i(2,1),Vector2i(-2,-1),Vector2i(-2,1)]},
	# Wide reach: strong, but they leave few tiles for the loner fairies.
	{"id":"dragon_spear", "name":"竜王槍", "short":"竜王", "row":2, "color":"ff9a5a", "tier":"late", "slide":[Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT], "steps":[Vector2i(-1,-1),Vector2i(1,-1),Vector2i(1,1),Vector2i(-1,1)], "detail":"縦横に滑り、斜めにも1マス。最初の敵を攻撃", "offsets":[Vector2i(0,-1),Vector2i(0,-2),Vector2i(1,0),Vector2i(2,0),Vector2i(0,1),Vector2i(0,2),Vector2i(-1,0),Vector2i(-2,0),Vector2i(-1,-1),Vector2i(1,-1),Vector2i(1,1),Vector2i(-1,1)]},
	{"id":"horse_blade", "name":"竜馬剣", "short":"竜馬", "row":2, "color":"6fb4ff", "tier":"late", "slide":[Vector2i(-1,-1),Vector2i(1,-1),Vector2i(1,1),Vector2i(-1,1)], "steps":[Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT], "detail":"斜めに滑り、縦横にも1マス。最初の敵を攻撃", "offsets":[Vector2i(-1,-1),Vector2i(-2,-2),Vector2i(1,-1),Vector2i(2,-2),Vector2i(1,1),Vector2i(2,2),Vector2i(-1,1),Vector2i(-2,2),Vector2i(0,-1),Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0)]},
	{"id":"eight_knight", "name":"八方桂剣", "short":"八方", "row":2, "color":"3ff0c0", "tier":"mid", "detail":"桂馬の8方向すべてに跳ぶ", "offsets":[Vector2i(1,-2),Vector2i(2,-1),Vector2i(2,1),Vector2i(1,2),Vector2i(-1,2),Vector2i(-2,1),Vector2i(-2,-1),Vector2i(-1,-2)]},
	# Shogi generals (forward = right): gold has no back diagonals, silver no sides or straight back.
	{"id":"gold", "name":"金将剣", "short":"金将", "row":2, "color":"ffd35b", "tier":"mid", "detail":"右3マス・上下・左（斜め後ろ以外の6マス）", "offsets":[Vector2i(1,-1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,-1),Vector2i(0,1),Vector2i(-1,0)]},
	{"id":"silver", "name":"銀将剣", "short":"銀将", "row":2, "color":"d8e2ee", "tier":"mid", "detail":"右3マスと左斜め2マス（5マス）", "offsets":[Vector2i(1,-1),Vector2i(1,0),Vector2i(1,1),Vector2i(-1,-1),Vector2i(-1,1)]},
	{"id":"king", "name":"王将剣", "short":"王将", "row":2, "color":"ffe27a", "tier":"mid", "detail":"周囲8マス", "offsets":[Vector2i(-1,-1),Vector2i(0,-1),Vector2i(1,-1),Vector2i(-1,0),Vector2i(1,0),Vector2i(-1,1),Vector2i(0,1),Vector2i(1,1)]},
	{"id":"charge_blade", "name":"溜め大剣", "short":"溜め", "row":2, "color":"ffcf5b", "charge":2, "detail":"右1マス。使わないターンごとに攻撃+1（最大3）", "offsets":[Vector2i(1,0)]},
]
## Stages whose rewards (and the opening pick) only offer early weapons:
## one tile, or two tiles when every tile is a jump.
const SINGLE_TILE_STAGES := 3
const START_CHOICE_COUNT := 3

static func is_mid(index: int) -> bool:
	return index >= 0 and index < DATA.size() and DATA[index].get("tier","") == "mid"

static func mid_pool() -> Array:
	return range(DATA.size()).filter(func(index: int) -> bool: return is_mid(index))

## Sliding weapons (飛車槍・角剣・竜王槍・竜馬剣): offered only after Rotorick.
static func is_late(index: int) -> bool:
	return index >= 0 and index < DATA.size() and DATA[index].get("tier","") == "late"

static func late_pool() -> Array:
	return range(DATA.size()).filter(func(index: int) -> bool: return is_late(index))

static func base_damage(index: int) -> int:
	return int(DATA[index].get("damage",1)) if index >= 0 and index < DATA.size() else 1

static func is_single(index: int) -> bool:
	if index >= 0 and index < DATA.size() and DATA[index].has("charge"):
		return false
	return index >= 0 and index < DATA.size() and DATA[index].offsets.size() == 1

static func is_jump(index: int) -> bool:
	return index >= 0 and index < DATA.size() and DATA[index].offsets.all(func(o: Vector2i) -> bool: return maxi(absi(o.x),absi(o.y)) >= 2)

## Two tiles with at least one jump: odd movement, but always weaker than a 4-tile cross.
static func is_quirky(index: int) -> bool:
	return index >= 0 and index < DATA.size() and DATA[index].offsets.size() == 2 and DATA[index].offsets.any(func(o: Vector2i) -> bool: return maxi(absi(o.x),absi(o.y)) >= 2)

static func is_early(index: int) -> bool:
	return is_single(index) or is_quirky(index)

static func knockback(index: int) -> int:
	return int(DATA[index].get("knockback", 0)) if index >= 0 and index < DATA.size() else 0

## Rewards of the first fights: the odd two-tile weapons, plus the one-tile shield.
static func early_reward_pool() -> Array:
	var pool := single_pool().filter(func(index: int) -> bool: return is_quirky(index) or (knockback(index) > 0 and is_single(index)))
	for index in DATA.size():
		if DATA[index].get("early", false) and not pool.has(index):
			pool.append(index)
	return pool

## Single tiles a sliding weapon also reaches (竜王槍's diagonals, 竜馬剣's sides).
static func steps(index: int) -> Array:
	return DATA[index].get("steps", []) if index >= 0 and index < DATA.size() else []

## Weapons that slide along lines until something is in the way.
static func slides(index: int) -> Array:
	return DATA[index].get("slide", []) if index >= 0 and index < DATA.size() else []

## The pre-boss reward: three-tile weapons plus the ones marked for it.
static func is_boss_reward(index: int) -> bool:
	return (offsets(index).size() == 3 and not is_mid(index) and not is_late(index)) or DATA[index].get("tier", "") == "boss"

## Only moves left/right: the starting forward/backward pair already covers that
## (knockback weapons earn their place by the shove).
static func horizontal_only(index: int) -> bool:
	var special: bool = int(DATA[index].get("knockback", 0)) > 0 or DATA[index].has("slide") or DATA[index].has("charge")
	return DATA[index].offsets.all(func(o: Vector2i) -> bool: return o.y == 0) and not special

## Early weapons other than the starting forward/backward pair.
static func single_pool() -> Array:
	var result: Array = []
	for index in range(2, DATA.size()):
		if is_early(index) and not horizontal_only(index) and not DATA[index].has("tier") and not DATA[index].has("slide"):
			result.append(index)
	return result

## Reaches both upward and downward tiles, so the player can never get stuck at an edge.
static func goes_up_and_down(index: int) -> bool:
	var offsets: Array = DATA[index].offsets
	return offsets.any(func(o: Vector2i) -> bool: return o.y < 0) and offsets.any(func(o: Vector2i) -> bool: return o.y > 0)

## Opening pick: early weapons that go both up and down.
static func opening_pool() -> Array:
	return single_pool().filter(func(index: int) -> bool: return goes_up_and_down(index))

static func offsets(index: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if index >= 0 and index < DATA.size():
		result.assign(DATA[index].offsets)
	return result
