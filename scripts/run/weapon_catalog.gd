extends RefCounted

# World-space offsets: the player always faces right. All weapons use sword art.
const DATA = [
	{"id":"forward", "name":"前進剣", "short":"前進", "row":2, "color":"f4d56f", "detail":"右の1マス", "offsets":[Vector2i(1,0)]},
	{"id":"backward", "name":"後退剣", "short":"後退", "row":2, "color":"94baff", "detail":"左の1マス", "offsets":[Vector2i(-1,0)]},
	{"id":"vertical", "name":"上下剣", "short":"上下", "row":2, "color":"bda0ff", "detail":"上・下の2マス", "offsets":[Vector2i(0,-1),Vector2i(0,1)]},
	{"id":"front_diagonal", "name":"前斜剣", "short":"前斜め", "row":2, "color":"ffad70", "detail":"右上・右下の2マス", "offsets":[Vector2i(1,-1),Vector2i(1,1)]},
	{"id":"back_diagonal", "name":"後斜剣", "short":"後斜め", "row":2, "color":"80dcb5", "detail":"左上・左下の2マス", "offsets":[Vector2i(-1,-1),Vector2i(-1,1)]},
	{"id":"assault", "name":"突進剣", "short":"突進", "row":2, "color":"ffbc75", "detail":"右上・右・右下", "offsets":[Vector2i(1,-1),Vector2i(1,0),Vector2i(1,1)]},
	{"id":"retreat", "name":"離脱剣", "short":"離脱", "row":2, "color":"89c9ff", "detail":"左上・左・左下", "offsets":[Vector2i(-1,-1),Vector2i(-1,0),Vector2i(-1,1)]},
	{"id":"diagonal", "name":"交差剣", "short":"交差", "row":2, "color":"d9a0ff", "detail":"斜め4マス", "offsets":[Vector2i(-1,-1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(1,1)]},
	{"id":"upper", "name":"上弦剣", "short":"上弦", "row":2, "color":"90cfff", "detail":"左上・上・右上", "offsets":[Vector2i(-1,-1),Vector2i(0,-1),Vector2i(1,-1)]},
	{"id":"lower", "name":"下弦剣", "short":"下弦", "row":2, "color":"ff98b7", "detail":"左下・下・右下", "offsets":[Vector2i(-1,1),Vector2i(0,1),Vector2i(1,1)]},
	{"id":"cross", "name":"十字剣", "short":"十字", "row":2, "color":"61dfcf", "detail":"縦横4マス", "offsets":[Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]},
	{"id":"horizontal", "name":"往復剣", "short":"往復", "row":2, "color":"efdb9a", "detail":"左・右の2マス", "offsets":[Vector2i.LEFT,Vector2i.RIGHT]},
	# Single-tile weapons: the early build is assembled one square at a time.
	{"id":"up", "name":"上歩剣", "short":"上", "row":2, "color":"a8b8ff", "detail":"上の1マス", "offsets":[Vector2i(0,-1)]},
	{"id":"down", "name":"下歩剣", "short":"下", "row":2, "color":"ffa8c8", "detail":"下の1マス", "offsets":[Vector2i(0,1)]},
	{"id":"front_up", "name":"右上剣", "short":"右上", "row":2, "color":"ffcf70", "detail":"右上の1マス", "offsets":[Vector2i(1,-1)]},
	{"id":"front_down", "name":"右下剣", "short":"右下", "row":2, "color":"ff9e6a", "detail":"右下の1マス", "offsets":[Vector2i(1,1)]},
	{"id":"back_up", "name":"左上剣", "short":"左上", "row":2, "color":"7fd8ff", "detail":"左上の1マス", "offsets":[Vector2i(-1,-1)]},
	{"id":"back_down", "name":"左下剣", "short":"左下", "row":2, "color":"7fe6b0", "detail":"左下の1マス", "offsets":[Vector2i(-1,1)]},
	# Jump weapons skip over a square, so the early rule lets them take two tiles.
	{"id":"leap", "name":"跳躍剣", "short":"前後跳", "row":2, "color":"ffe07a", "detail":"右・左へ2マス跳ぶ", "offsets":[Vector2i(2,0),Vector2i(-2,0)]},
	{"id":"vault", "name":"縦跳剣", "short":"縦跳", "row":2, "color":"8fc4ff", "detail":"上・下へ2マス跳ぶ", "offsets":[Vector2i(0,-2),Vector2i(0,2)]},
	{"id":"knight", "name":"桂馬剣", "short":"桂馬", "row":2, "color":"2bdcc8", "detail":"右へ2・上下へ1に跳ぶ", "offsets":[Vector2i(2,-1),Vector2i(2,1)]},
	{"id":"back_knight", "name":"逆桂剣", "short":"逆桂", "row":2, "color":"9d8cff", "detail":"左へ2・上下へ1に跳ぶ", "offsets":[Vector2i(-2,-1),Vector2i(-2,1)]},
	{"id":"sky_knight", "name":"天桂剣", "short":"天桂", "row":2, "color":"4fe0a8", "detail":"上へ2・左右へ1に跳ぶ", "offsets":[Vector2i(-1,-2),Vector2i(1,-2)]},
	# Odd up-and-down jumpers: variants of the vertical jump and the knights.
	{"id":"tall_knight", "name":"立桂剣", "short":"立桂", "row":2, "color":"6fe0ff", "detail":"右へ1・上下へ2に跳ぶ", "offsets":[Vector2i(1,-2),Vector2i(1,2)]},
	{"id":"back_tall_knight", "name":"逆立桂剣", "short":"逆立桂", "row":2, "color":"b08cff", "detail":"左へ1・上下へ2に跳ぶ", "offsets":[Vector2i(-1,-2),Vector2i(-1,2)]},
	{"id":"twist_knight", "name":"捻桂剣", "short":"捻桂", "row":2, "color":"ff9fd0", "detail":"右上の桂馬と左下の桂馬に跳ぶ", "offsets":[Vector2i(2,-1),Vector2i(-2,1)]},
	{"id":"back_twist_knight", "name":"逆捻桂剣", "short":"逆捻桂", "row":2, "color":"ffc27a", "detail":"左上の桂馬と右下の桂馬に跳ぶ", "offsets":[Vector2i(-2,-1),Vector2i(2,1)]},
	{"id":"bolt", "name":"稲妻剣", "short":"稲妻", "row":2, "color":"fff06a", "detail":"右上2段と左下2段に跳ぶ", "offsets":[Vector2i(1,-2),Vector2i(-1,2)]},
	{"id":"back_bolt", "name":"逆稲妻剣", "short":"逆稲妻", "row":2, "color":"9ff0c0", "detail":"左上2段と右下2段に跳ぶ", "offsets":[Vector2i(-1,-2),Vector2i(1,2)]},
	{"id":"fork", "name":"燕返剣", "short":"燕返", "row":2, "color":"ff8a8a", "detail":"右上・右下へ斜めに2マス跳ぶ", "offsets":[Vector2i(2,-2),Vector2i(2,2)]},
	{"id":"back_fork", "name":"返燕剣", "short":"返燕", "row":2, "color":"8ab8ff", "detail":"左上・左下へ斜めに2マス跳ぶ", "offsets":[Vector2i(-2,-2),Vector2i(-2,2)]},
	{"id":"slant", "name":"袈裟剣", "short":"袈裟", "row":2, "color":"ffb36b", "detail":"右上と左下へ斜めに2マス跳ぶ", "offsets":[Vector2i(2,-2),Vector2i(-2,2)]},
	{"id":"back_slant", "name":"逆袈裟剣", "short":"逆袈裟", "row":2, "color":"7fe6d0", "detail":"左上と右下へ斜めに2マス跳ぶ", "offsets":[Vector2i(-2,-2),Vector2i(2,2)]},
	{"id":"crane", "name":"鶴翼剣", "short":"鶴翼", "row":2, "color":"e0c8ff", "detail":"右上へ斜め2・右下の桂馬に跳ぶ", "offsets":[Vector2i(2,-2),Vector2i(2,1)]},
	{"id":"heron", "name":"鷺足剣", "short":"鷺足", "row":2, "color":"c8ffe0", "detail":"右上の桂馬・右下へ斜め2に跳ぶ", "offsets":[Vector2i(2,-1),Vector2i(2,2)]},
	# Mixed: one neighbouring tile plus one jump.
	{"id":"goose", "name":"雁行剣", "short":"雁行", "row":2, "color":"ffd9a0", "detail":"上の1マスと右下の桂馬", "offsets":[Vector2i(0,-1),Vector2i(2,1)]},
	{"id":"back_goose", "name":"逆雁剣", "short":"逆雁", "row":2, "color":"a0d9ff", "detail":"下の1マスと右上の桂馬", "offsets":[Vector2i(0,1),Vector2i(2,-1)]},
	{"id":"flick_up", "name":"跳上剣", "short":"跳上", "row":2, "color":"ffe6a0", "detail":"右上の1マスと下へ2マス", "offsets":[Vector2i(1,-1),Vector2i(0,2)]},
	{"id":"flick_down", "name":"跳下剣", "short":"跳下", "row":2, "color":"a0ffe6", "detail":"右下の1マスと上へ2マス", "offsets":[Vector2i(1,1),Vector2i(0,-2)]},
	{"id":"snake", "name":"蛇行剣", "short":"蛇行", "row":2, "color":"d0ff9a", "detail":"左上の1マスと右下の桂馬", "offsets":[Vector2i(-1,-1),Vector2i(2,1)]},
	{"id":"shoulder", "name":"背負剣", "short":"背負", "row":2, "color":"ff9ad0", "detail":"左下の1マスと右上の桂馬", "offsets":[Vector2i(-1,1),Vector2i(2,-1)]},
	{"id":"earth_knight", "name":"地桂剣", "short":"地桂", "row":2, "color":"c08cff", "detail":"下へ2・左右へ1に跳ぶ", "offsets":[Vector2i(-1,2),Vector2i(1,2)]},
	# Odd three-tile weapons: pre-boss rewards (and later), never as strong as a four-tile cross.
	{"id":"fan", "name":"扇剣", "short":"扇", "row":2, "color":"ffc76b", "detail":"右上・右下の1マスと、右へ2マス跳ぶ", "offsets":[Vector2i(1,-1),Vector2i(2,0),Vector2i(1,1)]},
	{"id":"back_fan", "name":"逆扇剣", "short":"逆扇", "row":2, "color":"7bc8ff", "detail":"左上・左下の1マスと、左へ2マス跳ぶ", "offsets":[Vector2i(-1,-1),Vector2i(-2,0),Vector2i(-1,1)]},
	{"id":"scales", "name":"天秤剣", "short":"天秤", "row":2, "color":"e6d08a", "detail":"上・下の1マスと、右へ2マス跳ぶ", "offsets":[Vector2i(0,-1),Vector2i(0,1),Vector2i(2,0)]},
	{"id":"swallow", "name":"飛燕剣", "short":"飛燕", "row":2, "color":"9fe0ff", "detail":"右の1マスと、右上・右下へ斜めに2マス跳ぶ", "offsets":[Vector2i(1,0),Vector2i(2,-2),Vector2i(2,2)]},
	{"id":"glance", "name":"見返剣", "short":"見返", "row":2, "color":"c9a0ff", "detail":"右の1マスと、左の桂馬2つ", "offsets":[Vector2i(1,0),Vector2i(-2,-1),Vector2i(-2,1)]},
	{"id":"tower", "name":"城楼剣", "short":"城楼", "row":2, "color":"a0ffc8", "detail":"右の1マスと、上・下へ2マス跳ぶ", "offsets":[Vector2i(1,0),Vector2i(0,-2),Vector2i(0,2)]},
	{"id":"retreat_tower", "name":"退城剣", "short":"退城", "row":2, "color":"ffa0c8", "detail":"左の1マスと、上・下へ2マス跳ぶ", "offsets":[Vector2i(-1,0),Vector2i(0,-2),Vector2i(0,2)]},
	{"id":"tee", "name":"丁字剣", "short":"丁字", "row":2, "color":"ffe0a0", "detail":"上・右・下の1マス", "offsets":[Vector2i(0,-1),Vector2i(1,0),Vector2i(0,1)]},
	# Knockback: a struck enemy is shoved one tile away; if it cannot move it takes 1 more.
	{"id":"shield", "name":"盾打ち", "short":"盾", "row":2, "color":"b8d7c5", "knockback":1, "detail":"右の1マス。攻撃した敵を右へ押し出す", "offsets":[Vector2i(1,0)]},
	{"id":"sweep", "name":"薙ぎ払い", "short":"薙払", "row":2, "color":"d7c5b8", "knockback":1, "detail":"上・下の1マス。攻撃した敵を上下へ押し出す", "offsets":[Vector2i(0,-1),Vector2i(0,1)]},
	{"id":"gale", "name":"突風剣", "short":"突風", "row":2, "color":"c5f0ff", "knockback":1, "detail":"右上・右・右下。攻撃した敵を外側へ押し出す", "offsets":[Vector2i(1,-1),Vector2i(1,0),Vector2i(1,1)]},
	# Mid-game weapons, dropped after the first boss.
	{"id":"hammer", "name":"ハンマー", "short":"槌", "row":0, "color":"c9d6e0", "tier":"mid", "damage":3, "detail":"右の1マス。攻撃は3ダメージで、横2マス＋その右3マスにも響く", "offsets":[Vector2i(1,0)]},
	{"id":"bow", "name":"弓", "short":"弓", "row":2, "color":"b7e07a", "tier":"mid", "ranged":"bishop", "detail":"斜め4方向に一直線に射る。移動はできない", "offsets":[Vector2i(-2,-2),Vector2i(-1,-1),Vector2i(1,-1),Vector2i(2,-2),Vector2i(-2,2),Vector2i(-1,1),Vector2i(1,1),Vector2i(2,2)]},
]
## Stages whose rewards (and the opening pick) only offer early weapons:
## one tile, or two tiles when every tile is a jump.
const SINGLE_TILE_STAGES := 3
const START_CHOICE_COUNT := 3

static func is_mid(index: int) -> bool:
	return index >= 0 and index < DATA.size() and DATA[index].get("tier","") == "mid"

static func mid_pool() -> Array:
	return range(DATA.size()).filter(func(index: int) -> bool: return is_mid(index))

static func base_damage(index: int) -> int:
	return int(DATA[index].get("damage",1)) if index >= 0 and index < DATA.size() else 1

static func is_single(index: int) -> bool:
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
	return single_pool().filter(func(index: int) -> bool: return is_quirky(index) or (knockback(index) > 0 and is_single(index)))

## Only moves left/right: the starting forward/backward pair already covers that
## (knockback weapons earn their place by the shove).
static func horizontal_only(index: int) -> bool:
	return DATA[index].offsets.all(func(o: Vector2i) -> bool: return o.y == 0) and int(DATA[index].get("knockback", 0)) == 0

## Early weapons other than the starting forward/backward pair.
static func single_pool() -> Array:
	var result: Array = []
	for index in range(2, DATA.size()):
		if is_early(index) and not horizontal_only(index) and not is_mid(index):
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
