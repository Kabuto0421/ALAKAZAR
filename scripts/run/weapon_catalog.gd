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
	{"id":"knight", "name":"桂馬剣", "short":"桂馬", "row":2, "color":"2bdcc8", "detail":"右へ2・上下へ1に跳ぶ", "offsets":[Vector2i(2,-1),Vector2i(2,1)]},
	# Odd up-and-down jumpers: variants of the vertical jump and the knights.
	{"id":"flick_down", "name":"跳下剣", "short":"跳下", "row":2, "color":"a0e6ff", "detail":"右下の1マスと上へ2マス", "offsets":[Vector2i(1,1),Vector2i(0,-2)]},
	{"id":"return_goose", "name":"帰雁剣", "short":"帰雁", "row":2, "color":"ffc9a0", "detail":"下の1マスと右上の桂馬", "offsets":[Vector2i(0,1),Vector2i(2,-1)]},
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
	{"id":"tee", "name":"丁字剣", "short":"丁字", "row":2, "color":"ffe0a0", "detail":"上・左・下の1マス", "offsets":[Vector2i(0,-1),Vector2i(-1,0),Vector2i(0,1)]},
	# Knockback: a struck enemy is shoved one tile away; if it cannot move it takes 1 more.
	{"id":"shield", "name":"盾打ち", "short":"盾", "row":2, "color":"b8d7c5", "knockback":1, "damage":0, "effect":"この武器の攻撃はダメージを与えないが、敵を右の一番奥までノックバックさせる。その先に敵がいれば、押し出した敵と押し出された敵は共に1ダメージを受ける。", "detail":"右の1マス。無傷で敵を右の奥までノックバック", "offsets":[Vector2i(1,0)]},
	{"id":"sweep", "name":"薙ぎ払い", "short":"薙払", "row":2, "color":"d7c5b8", "knockback":1, "damage":0, "effect":"この武器の攻撃はダメージを与えないが、敵を上下の一番奥までノックバックさせる。その先に敵がいれば、押し出した敵と押し出された敵は共に1ダメージを受ける。", "detail":"上・下の1マス。無傷で敵を上下の奥までノックバック", "offsets":[Vector2i(0,-1),Vector2i(0,1)]},
	{"id":"gale", "name":"突風剣", "short":"突風", "row":2, "color":"c5f0ff", "knockback":1, "damage":0, "effect":"この武器の攻撃はダメージを与えないが、敵を外側の一番奥までノックバックさせる。その先に敵がいれば、押し出した敵と押し出された敵は共に1ダメージを受ける。", "detail":"右上・右・右下。無傷で敵を外側の奥までノックバック", "offsets":[Vector2i(1,-1),Vector2i(1,0),Vector2i(1,1)]},
	# Mid-game weapons, dropped after the first boss.
	{"id":"hammer", "name":"ハンマー", "short":"槌", "row":0, "color":"c9d6e0", "tier":"mid", "damage":1, "effect":"この武器の攻撃は1ダメージを与え、叩いたマスの上下左右にも同じダメージを与える。鍛えると、叩いたマスの上下と、その右の縦3マスにも響く。", "detail":"右の1マス。叩いたマスの上下左右に響く（鍛えると上下＋右の縦3マス）", "offsets":[Vector2i(1,0)]},
	{"id":"bow", "name":"弓", "short":"弓", "row":2, "color":"b7e07a", "tier":"mid", "ranged":"bishop", "effect":"この武器は斜め4方向の直線上にいる敵を射て、1ダメージを与える。この武器では移動できない。", "detail":"斜め4方向に一直線に射る。移動はできない", "offsets":[Vector2i(-2,-2),Vector2i(-1,-1),Vector2i(1,-1),Vector2i(2,-2),Vector2i(-2,2),Vector2i(-1,1),Vector2i(1,1),Vector2i(2,2)]},
# Weapons with their own mechanics (not just a shape).
	{"id":"lance", "name":"香車槍", "short":"香車", "row":2, "color":"ffb070", "tier":"boss", "from_rotorick":true, "slide":[Vector2i.RIGHT], "effect":"この武器はふさがるまで右へ進める。", "detail":"右へ、ふさがるまで一直線に進む。最初の敵を攻撃", "offsets":[Vector2i(1,0),Vector2i(2,0)]},
	{"id":"rook_spear", "name":"飛車槍", "short":"飛車", "row":2, "color":"ff7a7a", "tier":"late", "damage":0, "no_forge":true, "slide":[Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT], "detail":"縦横4方向へ、ふさがるまで進める", "offsets":[Vector2i(0,-1),Vector2i(0,-2),Vector2i(1,0),Vector2i(2,0),Vector2i(0,1),Vector2i(0,2),Vector2i(-1,0),Vector2i(-2,0)]},
	{"id":"bishop_blade", "name":"角剣", "short":"角", "row":2, "color":"7aa8ff", "tier":"late", "damage":0, "no_forge":true, "slide":[Vector2i(-1,-1),Vector2i(1,-1),Vector2i(1,1),Vector2i(-1,1)], "detail":"斜め4方向へ、ふさがるまで進める", "offsets":[Vector2i(-1,-1),Vector2i(-2,-2),Vector2i(1,-1),Vector2i(2,-2),Vector2i(1,1),Vector2i(2,2),Vector2i(-1,1),Vector2i(-2,2)]},
	{"id":"sickle", "name":"鎖鎌", "short":"鎖鎌", "row":2, "color":"b8c4d0", "pull":true, "effect":"この武器の攻撃は1ダメージを与え、敵を自分の隣まで引き寄せる。", "detail":"縦横2マス先へ。敵は攻撃して引き寄せる", "offsets":[Vector2i(0,-2),Vector2i(2,0),Vector2i(0,2),Vector2i(-2,0)]},
	{"id":"swap_staff", "name":"入替の杖", "short":"入替", "row":2, "color":"c89bff", "swap":true, "early":true, "effect":"この武器の攻撃はダメージを与えないが、敵との位置を入れ替えることができる。", "detail":"斜め4マス。敵とは入れ替え（無傷）", "offsets":[Vector2i(-1,-1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(1,1)]},
	# Wide reach: strong, but they leave few tiles for the loner fairies.
	{"id":"eight_knight", "name":"八方桂剣", "short":"八方", "row":2, "color":"3ff0c0", "tier":"mid", "detail":"桂馬の8方向すべてに跳ぶ", "offsets":[Vector2i(1,-2),Vector2i(2,-1),Vector2i(2,1),Vector2i(1,2),Vector2i(-1,2),Vector2i(-2,1),Vector2i(-2,-1),Vector2i(-1,-2)]},
	# Shogi generals (forward = right): gold has no back diagonals, silver no sides or straight back.
	{"id":"king_staff", "name":"王将の杖", "short":"王杖", "row":2, "color":"e8c86a", "tier":"mid", "swap":true, "effect":"この武器の攻撃はダメージを与えないが、敵との位置を入れ替えることができる。", "detail":"周囲8マス。敵とは入れ替え（無傷）", "offsets":[Vector2i(-1,-1),Vector2i(0,-1),Vector2i(1,-1),Vector2i(-1,0),Vector2i(1,0),Vector2i(-1,1),Vector2i(0,1),Vector2i(1,1)]},
	{"id":"charge_blade", "name":"溜め大剣", "short":"溜め", "row":2, "color":"ffcf5b", "charge":2, "effect":"この武器の攻撃は、使わなかったターンごとにダメージが1ずつ上がる（最大3、鍛えると最大5）。攻撃すると元に戻る。", "detail":"右1マス。使わないターンごとに攻撃+1（最大3、鍛えると5）", "offsets":[Vector2i(1,0)]},
	# A rare mid-game drop: moves like the cross sword, and its blow spreads in a cross.
	{"id":"cross_hammer", "name":"十字槌", "short":"十字槌", "row":0, "color":"9fd0ff", "tier":"mid", "rare":true, "hammer":true, "area":"cross", "damage":1, "effect":"この武器の攻撃は1ダメージを与え、叩いたマスの上下左右にも同じダメージを与える。", "detail":"縦横4マス。叩いたマスの上下左右にも響く", "offsets":[Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]},
	# Added last so earlier weapon indices stay put.
	{"id":"thunder", "name":"雷剣", "short":"雷", "row":2, "color":"ffe95a", "detail":"右上と左下の1マス", "offsets":[Vector2i(1,-1),Vector2i(-1,1)]},
	# クロス短剣: two weapons sold as one set. Each slides up to three tiles along one diagonal (and
	# one tile back), attacks the first enemy up to three tiles ahead on that diagonal, and using one boosts the other.
	{"id":"thunder_dagger", "name":"雷短剣", "short":"雷短", "row":2, "color":"5cc8ff", "tier":"mid", "rare":true, "pair":"flame_dagger", "dagger":Vector2i(1,-1), "attack":[Vector2i(1,-1),Vector2i(2,-2),Vector2i(3,-3)], "effect":"クロス短剣の片方。右上へ最大3マス、左下へ1マスまで動け、そのどのマスの敵も攻撃できる（その場で、最初の敵に）。炎短剣を使った後に使うと強力で、攻撃力+1、当たった敵の斜め4マスにも同じダメージが響く。", "detail":"右上へ最大3マス・左下へ1マス。攻撃もその範囲", "offsets":[Vector2i(1,-1),Vector2i(2,-2),Vector2i(3,-3),Vector2i(-1,1)]},
	{"id":"flame_dagger", "name":"炎短剣", "short":"炎短", "row":2, "color":"ff7a4a", "tier":"mid", "rare":true, "pair":"thunder_dagger", "dagger":Vector2i(1,1), "attack":[Vector2i(1,1),Vector2i(2,2),Vector2i(3,3)], "effect":"クロス短剣の片方。右下へ最大3マス、左上へ1マスまで動け、そのどのマスの敵も攻撃できる（その場で、最初の敵に）。雷短剣を使った後に使うと強力で、攻撃力+1、当たった敵の斜め4マスにも同じダメージが響く。", "detail":"右下へ最大3マス・左上へ1マス。攻撃もその範囲", "offsets":[Vector2i(1,1),Vector2i(2,2),Vector2i(3,3),Vector2i(-1,-1)]},
	# Six more odd three-tile weapons (pre-boss rewards, uncommon): the four corners of the player's
	# 3x3 and the two forks that cut ahead on both diagonals.
	{"id":"corner_ul", "name":"左上隅剣", "short":"左上隅", "row":2, "color":"9ad0ff", "detail":"左上・上・左の3マス", "offsets":[Vector2i(-1,-1),Vector2i(0,-1),Vector2i(-1,0)]},
	{"id":"corner_ur", "name":"右上隅剣", "short":"右上隅", "row":2, "color":"ffd08a", "detail":"右上・上・右の3マス", "offsets":[Vector2i(1,-1),Vector2i(0,-1),Vector2i(1,0)]},
	{"id":"corner_dr", "name":"右下隅剣", "short":"右下隅", "row":2, "color":"ff9ab0", "detail":"右下・下・右の3マス", "offsets":[Vector2i(1,1),Vector2i(0,1),Vector2i(1,0)]},
	{"id":"corner_dl", "name":"左下隅剣", "short":"左下隅", "row":2, "color":"b0ff9a", "detail":"左下・左・下の3マス", "offsets":[Vector2i(-1,1),Vector2i(-1,0),Vector2i(0,1)]},
	{"id":"fork_up", "name":"上叉剣", "short":"上叉", "row":2, "color":"c8a0ff", "detail":"左上・右上・右の3マス", "offsets":[Vector2i(-1,-1),Vector2i(1,-1),Vector2i(1,0)]},
	{"id":"fork_down", "name":"下叉剣", "short":"下叉", "row":2, "color":"a0f0e0", "detail":"左下・右下・右の3マス", "offsets":[Vector2i(-1,1),Vector2i(1,1),Vector2i(1,0)]},
	{"id":"lower", "name":"下弦剣", "short":"下弦", "row":2, "color":"90ffcf", "detail":"左下・下・右下", "offsets":[Vector2i(-1,1),Vector2i(0,1),Vector2i(1,1)]},
	{"id":"hook_down", "name":"下鉤剣", "short":"下鉤", "row":2, "color":"ffb0d8", "detail":"左・下・右斜め下の3マス", "offsets":[Vector2i(-1,0),Vector2i(0,1),Vector2i(1,1)]},
	{"id":"hook_up", "name":"上鉤剣", "short":"上鉤", "row":2, "color":"b0d8ff", "detail":"左・上・右斜め上の3マス", "offsets":[Vector2i(-1,0),Vector2i(0,-1),Vector2i(1,-1)]},
]
## Stages whose rewards (and the opening pick) only offer early weapons:
## one tile, or two tiles when every tile is a jump.
const SINGLE_TILE_STAGES := 3
const START_CHOICE_COUNT := 3

## Hammers (the mid-game hammer and the early mallet) strike an area.
## 飛車槍・角剣: 0 damage and they cannot be forged.
static func can_forge(index: int) -> bool:
	return index >= 0 and index < DATA.size() and not DATA[index].get("no_forge", false)

## Where a hammer's blow spreads, relative to the struck tile: the tiles above and
## below it and the column beyond; the cross hammer, the four tiles around it.
static func hammer_shape(index: int, forged: bool = false) -> Array[Vector2i]:
	var result: Array[Vector2i] = [Vector2i(0,0), Vector2i(0,-1), Vector2i(0,1), Vector2i(1,-1), Vector2i(1,0), Vector2i(1,1)]
	# The plain hammer starts with the cross; forging widens it to the full blow.
	if DATA[index].get("area", "") == "cross" or (DATA[index].id == "hammer" and not forged):
		result.assign([Vector2i(0,0), Vector2i(0,-1), Vector2i(0,1), Vector2i(-1,0), Vector2i(1,0)])
	return result

## The tiles a hammer's blow also reaches when it strikes the tile to its right
## (the example the range diagrams show), relative to the player.
static func hammer_echo(index: int, forged: bool = false) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not is_hammer(index):
		return result
	var target := Vector2i(1,0)
	for offset in hammer_shape(index, forged):
		if offset != Vector2i.ZERO and target + offset != Vector2i.ZERO:
			result.append(target + offset)
	return result

static func is_hammer(index: int) -> bool:
	return index >= 0 and index < DATA.size() and (DATA[index].id == "hammer" or DATA[index].get("hammer", false))

## クロス短剣: the pair's second half is never offered alone (the first brings it along).
static func is_pair_member(_index: int) -> bool:
	# Each dagger is offered on its own now; the pairing only decides who boosts whom.
	return false

static func is_dagger(index: int) -> bool:
	return index >= 0 and index < DATA.size() and DATA[index].has("dagger")

## The other half of a pair (-1 for a weapon that has none).
static func pair_of(index: int) -> int:
	if index < 0 or index >= DATA.size() or not DATA[index].has("pair"):
		return -1
	for other in DATA.size():
		if DATA[other].id == DATA[index].pair:
			return other
	return -1

## True for the half that is offered (it brings the other along).
static func is_pair_head(_index: int) -> bool:
	return false

## The tiles a dagger can attack: its three tiles ahead and the one behind (all of its reach).
static func attack_offsets(index: int, _forged: bool = false) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if is_dagger(index):
		result.assign(DATA[index].attack)
		result.append(-Vector2i(DATA[index].dagger))
	return result

static func is_mid(index: int) -> bool:
	return index >= 0 and index < DATA.size() and DATA[index].get("tier","") == "mid"

## 香車槍 is strong enough to wait for the reward right before Rotorick.
static func from_rotorick(index: int) -> bool:
	return index >= 0 and index < DATA.size() and DATA[index].get("from_rotorick", false)

static func mid_pool() -> Array:
	return range(DATA.size()).filter(func(index: int) -> bool: return is_mid(index))

## 飛車槍・角剣: offered only after Rotorick, and only as magic circle weapons.
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

## Plain movers: no effect of their own (the only ones a magic circle is put on).
static func is_simple(index: int) -> bool:
	return index >= 0 and index < DATA.size() and not DATA[index].has("effect") and not DATA[index].get("swap", false) and not is_late(index) and DATA[index].get("ranged", "") == ""

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

## Weapons that slide along lines until something is in the way.
static func slides(index: int) -> Array:
	return DATA[index].get("slide", []) if index >= 0 and index < DATA.size() else []

## The pre-boss reward: three-tile weapons plus the ones marked for it.
static func is_boss_reward(index: int) -> bool:
	return (offsets(index).size() == 3 and not is_mid(index) and not is_late(index)) or DATA[index].get("tier", "") == "boss"

## Only moves left/right: the starting forward/backward pair already covers that
## (knockback weapons earn their place by the shove).
static func horizontal_only(index: int) -> bool:
	var special: bool = int(DATA[index].get("knockback", 0)) > 0 or DATA[index].has("slide") or DATA[index].has("charge") or DATA[index].has("hammer")
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
