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
	{"id":"leap", "name":"跳躍剣", "short":"跳躍", "row":2, "color":"ffe07a", "detail":"右へ2マス跳ぶ", "offsets":[Vector2i(2,0)]},
	{"id":"leap_back", "name":"飛退剣", "short":"飛退", "row":2, "color":"8fc4ff", "detail":"左へ2マス跳ぶ", "offsets":[Vector2i(-2,0)]},
	{"id":"knight_up", "name":"桂上剣", "short":"桂上", "row":2, "color":"2bdcc8", "detail":"右へ2・上へ1に跳ぶ", "offsets":[Vector2i(2,-1)]},
	{"id":"knight_down", "name":"桂下剣", "short":"桂下", "row":2, "color":"4fe0a8", "detail":"右へ2・下へ1に跳ぶ", "offsets":[Vector2i(2,1)]},
	{"id":"back_knight_up", "name":"逆桂上剣", "short":"逆桂上", "row":2, "color":"9d8cff", "detail":"左へ2・上へ1に跳ぶ", "offsets":[Vector2i(-2,-1)]},
	{"id":"back_knight_down", "name":"逆桂下剣", "short":"逆桂下", "row":2, "color":"c08cff", "detail":"左へ2・下へ1に跳ぶ", "offsets":[Vector2i(-2,1)]},
]
## Stages whose rewards (and the opening pick) only offer single-tile weapons.
const SINGLE_TILE_STAGES := 3
const START_CHOICE_COUNT := 3

static func is_single(index: int) -> bool:
	return index >= 0 and index < DATA.size() and DATA[index].offsets.size() == 1

## Single-tile weapons other than the starting forward/backward pair.
static func single_pool() -> Array:
	var result: Array = []
	for index in range(2, DATA.size()):
		if is_single(index):
			result.append(index)
	return result

static func offsets(index: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if index >= 0 and index < DATA.size():
		result.assign(DATA[index].offsets)
	return result
