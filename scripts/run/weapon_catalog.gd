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
]
const START_CHOICES = [2,3,4]

static func offsets(index: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if index >= 0 and index < DATA.size():
		result.assign(DATA[index].offsets)
	return result
