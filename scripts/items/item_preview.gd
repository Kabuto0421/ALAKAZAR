extends RefCounted
## Animated examples of what each fairy does, on a small board of tiles. The battle
## panel shows them while a fairy is selected, and the reward cards show them large.
## Each example lays out its own grid of 40px tiles and is scaled into the given rect.
## They use as little text as possible: the board, the fairy's art filling its tile,
## the player (facing right), enemies, arrows and damage numbers tell the story.
## Illustrations are independent of gameplay state and never consume items or AP.

const Units = preload("res://scripts/unit_view.gd")
const Sheet = preload("res://scripts/items/direction_sheet.gd")
const FONT = preload("res://assets/fonts/DotGothic16-Regular.ttf")
const FLYING_SLASH = preload("res://assets/sprites/spirits/flying_slash.png")
const CHARGED = preload("res://assets/sprites/spirits/capacitor_fairy_charged.png")
const STEALTH = preload("res://assets/sprites/spirits/stealth_fairy.png")
const WALL = preload("res://assets/sprites/spirits/wall_fairy.png")

const C := 40.0
const RED := Color("ff6b5b")
const GOLD := Color("ffd35b")
const GREEN := Color("7dff9a")
const SILVER := Color("d8e2ee")
const PULL := Color("7ac8ff")
const PUSH := Color("ffa04a")
## A collision's burst and "−1" (as on the board).
const BUMP := Color("ffe14a")
## The examples about "where no weapon reaches" assume the player holds the silver
## general's sword (facing right): the three front tiles and the two back diagonals.
const SILVER_REACH := [Vector2i(1,-1), Vector2i(1,0), Vector2i(1,1), Vector2i(-1,-1), Vector2i(-1,1)]
## Board size of each example (columns, rows); 5x3 unless listed.
const GRIDS := {
	"slash_fairy": Vector2i(3,3),
	"axe_spirit": Vector2i(6,2),
	"gravity_fairy": Vector2i(6,3),
}

## The part of each sprite the character fills (a square around its opaque pixels),
## so the art fills its tile instead of floating in its own margin.
const CROPS := {
	"abyss_spirit": Rect2(0.072, 0.054, 0.881, 0.881),
	"acorn_fairy": Rect2(0.182, 0.152, 0.751, 0.751),
	"blessing_fairy": Rect2(0.158, 0.195, 0.678, 0.678),
	"cannon_fairy": Rect2(0.018, 0.067, 0.933, 0.933),
	"firework_fairy": Rect2(0.122, 0.096, 0.848, 0.848),
	"flying_slash": Rect2(0.049, 0.059, 0.902, 0.902),
	"freeze_fairy": Rect2(0.143, 0.186, 0.697, 0.697),
	"glutton_fairy": Rect2(0.084, 0.076, 0.893, 0.893),
	"gravity_fairy": Rect2(0.127, 0.106, 0.783, 0.783),
	"guardian_fairy": Rect2(0.021, 0.043, 0.936, 0.936),
	"holy_spirit": Rect2(0.107, 0.116, 0.754, 0.754),
	"lone_wolf_sulk": Rect2(0.153, 0.217, 0.716, 0.716),
	"magic_bolt_fairy": Rect2(0.150, 0.147, 0.699, 0.699),
	"meteor_fairy": Rect2(0.092, 0.080, 0.787, 0.787),
	"shadow_stitch": Rect2(0.098, 0.076, 0.814, 0.814),
	"slash_fairy": Rect2(0.049, 0.059, 0.902, 0.902),
	"stealth_fairy": Rect2(0.131, 0.124, 0.738, 0.738),
	"vane_cannon": Rect2(0.021, 0.076, 0.890, 0.890),
	"wall_fairy": Rect2(0.102, 0.150, 0.798, 0.798),
	"warp_fairy": Rect2(0.133, 0.148, 0.734, 0.734),
}

static var cv: CanvasItem
static var board := Vector2i(5,3)

static func grid(id: String, plus: bool) -> Vector2i:
	if id == "slash_fairy" and plus:
		return Vector2i(6,3)
	return GRIDS.get(id, Vector2i(5,3))

## Draws the example for `id` fitted into `rect` (centred, at most twice its size).
## `plus`: 1 shows the class-up version, 0 the base one, -1 whatever the model has.
static func paint(canvas: CanvasItem, model: RefCounted, id: String, time: float, rect: Rect2 = Rect2(848,228,268,100), plus: int = -1) -> void:
	if id == "knockback":
		board = Vector2i(5,1)
		_fit(canvas, rect)
		_board(Color("b8d7c5"))
		_knockback(time)
		canvas.draw_set_transform(Vector2.ZERO)
		return
	var item: Resource = model.item_definition(id)
	if item == null:
		return
	var upgraded: bool = model.is_plus(id) if plus < 0 else plus == 1
	board = grid(id, upgraded)
	_fit(canvas, rect)
	_board(item.color)
	var accent: Color = item.color
	var art: Texture2D = item.icon
	match id:
		"magic_bolt": _magic_bolt(time, accent, art)
		"stealth_fairy": _stealth(time, accent, art)
		"acorn_fairy": _acorn(time, art)
		"warp_fairy": _warp(time, accent, art)
		"wall_fairy": _wall(time, art)
		"cannon_fairy": _cannon(time, accent, art, upgraded)
		"vane_cannon": _vane(time, accent, art)
		"firework_fairy": _firework(time, accent, art)
		"capacitor_fairy": _capacitor(time, accent, art)
		"slash_fairy":
			if upgraded:
				_flying_slash(time, accent)
			else:
				_slash(time, accent, art)
		"axe_spirit": _axe(time, accent)
		"holy_spirit": _holy(time, accent)
		"shadow_stitch": _shadow(time, art)
		"lone_wolf": _wolf(time)
		"abyss_spirit": _abyss(time, accent, art)
		"gravity_fairy": _gravity(time, art)
		"freeze_fairy": _freeze(time, accent, art, upgraded)
		"blessing_fairy": _blessing(time, accent, art, upgraded)
		"meteor_fairy": _meteor(time, art, int(model.meteor_count()) + (1 if upgraded and not model.is_plus(id) else 0))
		"guardian_fairy": _guardian(time)
		"glutton_fairy": _glutton(time)
	canvas.draw_set_transform(Vector2.ZERO)

# --- The examples -------------------------------------------------------------

## Placed on a tile, fired in a chosen direction: every enemy on the line takes 1.
static func _magic_bolt(time: float, accent: Color, art: Texture2D) -> void:
	var p := _cycle(time, 2.8)
	_art(art, Vector2(0,1))
	if p < 0.25:
		_arrow(_center(Vector2(0,1)) + Vector2(16,0), _center(Vector2(1,1)) + Vector2(10,0), accent, 4)
	var k := _ph(p, 0.25, 0.6)
	if k > 0.0 and k < 1.0:
		var head := _center(Vector2(0,1)).lerp(_center(Vector2(4,1)), k)
		cv.draw_line(_center(Vector2(0,1)), head, Color(accent, 0.6), 4)
		cv.draw_circle(head, 6, accent)
	_enemy(Vector2(3,0))
	for enemy: Vector2 in [Vector2(2,1), Vector2(4,1)]:
		var hit: float = 0.25 + 0.35 * enemy.x / 4.0
		_enemy(enemy, 1.0 - _ph(p, hit + 0.1, hit + 0.25))
		_pop(enemy, "−1", _ph(p, hit, hit + 0.3))

## Blocks its tile; the first enemy to step next to it takes 1 and the fairy is gone.
static func _stealth(time: float, accent: Color, art: Texture2D) -> void:
	var p := _cycle(time, 2.8)
	for side: Vector2 in [Vector2(1,1), Vector2(3,1), Vector2(2,0), Vector2(2,2)]:
		_tint(side, Color(accent, 0.14))
	var enemy := Vector2(4,1).lerp(Vector2(3,1), _ph(p, 0.05, 0.4))
	_art(art, Vector2(2,1), 1.0 - _ph(p, 0.5, 0.65))
	if p > 0.45 and p < 0.6:
		cv.draw_line(_center(Vector2(2,1)), _center(enemy), accent, 5)
	_enemy(enemy, 1.0 - _ph(p, 0.55, 0.7))
	_pop(Vector2(3,1), "−1", _ph(p, 0.45, 0.8))

## A small ally: it walks to the nearest enemy and bites for 1.
static func _acorn(time: float, art: Texture2D) -> void:
	var p := _cycle(time, 2.8)
	var at := Vector2(1,1).lerp(Vector2(2,1), _ph(p, 0.1, 0.35))
	var lunge := sin(_ph(p, 0.45, 0.6) * PI) * 0.25
	# Where it can step or strike: the four tiles beside it.
	_ally_reach(at.round(), [Vector2(1,0), Vector2(-1,0), Vector2(0,1), Vector2(0,-1)])
	_enemy(Vector2(3,1), 1.0 - _ph(p, 0.6, 0.75))
	_art(art, at + Vector2(lunge, 0))
	_pop(Vector2(3,1), "−1", _ph(p, 0.5, 0.85))

## 0 AP: the player blinks to any free tile.
static func _warp(time: float, accent: Color, art: Texture2D) -> void:
	var p := _cycle(time, 2.6)
	var start := Vector2(0,2)
	var end := Vector2(4,0)
	_art(art, end, 1.0 - _ph(p, 0.45, 0.6))
	for portal: Vector2 in [start, end]:
		cv.draw_arc(_center(portal), 17 + sin(time * 5) * 2, 0, TAU, 24, accent, 2)
	if p < 0.45:
		_dashed(_center(start), _center(end), Color(accent, 0.8))
		_player(start)
	elif p < 0.52:
		for portal: Vector2 in [start, end]:
			cv.draw_circle(_center(portal), 16, Color(1,1,1,0.7))
	else:
		_player(end)

## A wall for five turns: nothing gets through.
static func _wall(time: float, art: Texture2D) -> void:
	var p := _cycle(time, 2.6)
	_art(art, Vector2(2,1))
	var bump := sin(_ph(p, 0.4, 0.55) * PI) * 0.18
	_enemy(Vector2(4,1).lerp(Vector2(3,1), _ph(p, 0.05, 0.35)) - Vector2(bump, 0))
	if p > 0.5:
		_cross(_center(Vector2(2.5,1)), 9)

## Hit its tile to fire down its line (two volleys once upgraded).
static func _cannon(time: float, accent: Color, art: Texture2D, plus: bool) -> void:
	var p := _cycle(time, 3.4 if plus else 2.8)
	_player(Vector2(0,1))
	if not Sheet.paint(cv, _center(Vector2(1,1)), "cannon_fairy", Vector2i.RIGHT, (C - 4) / 64.0):
		_art(art, Vector2(1,1))
	# The player's hit on the cannon's tile sets it off.
	_flash(Vector2(1,1), Color.WHITE, _ph(p, 0.1, 0.22))
	var volleys: Array[float] = [0.2]
	if plus:
		volleys.append(0.5)
	var last: float = volleys[volleys.size() - 1]
	for enemy: Vector2 in [Vector2(3,1), Vector2(4,1)]:
		_enemy(enemy, 1.0 - _ph(p, last + 0.25, last + 0.35))
	for v in volleys.size():
		var start: float = volleys[v]
		var k := _ph(p, start, start + 0.2)
		if k > 0.0 and k < 1.0:
			var head := _center(Vector2(1,1)).lerp(_center(Vector2(4.4,1)), k)
			cv.draw_line(head - Vector2(18,0), head, accent, 5)
			cv.draw_circle(head, 5, Color.WHITE)
		for enemy: Vector2 in [Vector2(3,1), Vector2(4,1)]:
			var hit: float = start + 0.2 * (enemy.x - 1) / 3.4
			_pop(enemy, "−1", _ph(p, hit, hit + 0.28), RED, v * 12.0)

## Two volleys, then it turns 90 degrees clockwise.
static func _vane(time: float, accent: Color, art: Texture2D) -> void:
	var p := _cycle(time, 4.4)
	var center := Vector2(2,1)
	var dirs: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
	var targets: Array[Vector2] = [Vector2(4,1), Vector2(2,2), Vector2(0,1), Vector2(2,0)]
	var shot := mini(int(p * 4), 3)
	var q := fmod(p * 4, 1.0)
	for k in 4:
		if k > shot:
			_enemy(targets[k])
		elif k == shot:
			_enemy(targets[k], 1.0 - _ph(q, 0.45, 0.55))
	var aim: Vector2i = dirs[shot]
	for v in 2:
		var k := _ph(q, 0.08 + v * 0.18, 0.2 + v * 0.18)
		if k > 0.0 and k < 1.0:
			cv.draw_line(_center(center), _center(center).lerp(_center(targets[shot]), k), accent, 5)
		_pop(targets[shot], "−1", _ph(q, 0.2 + v * 0.18, 0.5 + v * 0.18), RED, v * 12.0)
	# After both volleys it turns towards the next direction.
	var turn := _ph(q, 0.6, 0.9)
	var facing: Vector2i = dirs[(shot + (1 if turn >= 1.0 else 0)) % 4]
	if not Sheet.paint(cv, _center(center), "vane_cannon", facing, (C - 4) / 64.0):
		_art(art, center)
	if turn > 0.0 and turn < 1.0:
		var from := Vector2(aim).angle()
		cv.draw_arc(_center(center), 25, from, from + PI / 2 * turn, 12, Color("9ff5ff"), 3)
		cv.draw_circle(_center(center) + Vector2.from_angle(from + PI / 2 * turn) * 25, 4, Color("9ff5ff"))

## Hit it and it bursts: 1 to everything in the 3x3 around it (you too).
static func _firework(time: float, accent: Color, art: Texture2D) -> void:
	var p := _cycle(time, 2.8)
	_player(Vector2(0,1))
	var burst := _ph(p, 0.3, 0.55)
	if burst > 0.0 and burst < 1.0:
		cv.draw_rect(Rect2(Vector2(1,0) * C, Vector2(3,3) * C), Color(PUSH, 0.35 * (1.0 - burst)))
		cv.draw_arc(_center(Vector2(2,1)), 10 + burst * 58, 0, TAU, 32, accent, 4)
	_art(art, Vector2(2,1), 1.0 - _ph(p, 0.3, 0.4))
	_flash(Vector2(2,1), Color.WHITE, _ph(p, 0.18, 0.3))
	_enemy(Vector2(4,1))
	for enemy: Vector2 in [Vector2(1,0), Vector2(3,1), Vector2(3,2)]:
		_enemy(enemy, 1.0 - _ph(p, 0.55, 0.7))
		_pop(enemy, "−1", _ph(p, 0.35, 0.7))

## Charges each turn and each hit; at 3 it discharges down all four lines.
static func _capacitor(time: float, accent: Color, art: Texture2D) -> void:
	var p := _cycle(time, 3.6)
	var at := Vector2(2,1)
	# One charge as the turn ends, then one each time the player hits it.
	var stored := 0
	if p < 0.62:
		stored = 1 if p >= 0.1 else 0
		stored += 1 if p >= 0.3 else 0
		stored += 1 if p >= 0.5 else 0
	elif p < 0.75:
		stored = 3
	_player(Vector2(1,2))
	_art(CHARGED if stored > 0 else art, at)
	for hit: float in [0.3, 0.5]:
		_flash(at, Color.WHITE, _ph(p, hit - 0.02, hit + 0.08))
		_pop(at, "+1", _ph(p, hit, hit + 0.15), GOLD, 6, 14)
	_pop(at, "+1", _ph(p, 0.1, 0.25), GOLD, 6, 14)
	# The gauge: three lamps across the top of its tile.
	for k in 3:
		var lamp := Rect2(at * C + Vector2(5 + k * 10.5, 3), Vector2(9, 6))
		cv.draw_rect(lamp.grow(1), Color("0a1112"))
		cv.draw_rect(lamp, GOLD if k < stored else Color("2a3638"))
	var zap := _ph(p, 0.62, 0.77)
	if zap > 0.0 and zap < 1.0:
		for end: Vector2 in [Vector2(4,1), Vector2(0,1), Vector2(2,0), Vector2(2,2)]:
			_bolt(_center(at), _center(end), accent)
	_enemy(Vector2(4,0))
	for enemy: Vector2 in [Vector2(4,1), Vector2(0,1), Vector2(2,0)]:
		_enemy(enemy, 1.0 - _ph(p, 0.74, 0.86))
		_pop(enemy, "−1", _ph(p, 0.64, 0.95))

## Cuts the tile above and the tile below it.
static func _slash(time: float, accent: Color, art: Texture2D) -> void:
	var p := _cycle(time, 2.4)
	_art(art, Vector2(1,1))
	var cut := _ph(p, 0.3, 0.45)
	if cut > 0.0 and cut < 1.0:
		for end: Vector2 in [Vector2(1,0), Vector2(1,2)]:
			var tip := _center(Vector2(1,1)).lerp(_center(end), cut)
			cv.draw_line(tip - Vector2(14, 0), tip + Vector2(14, 0), Color.WHITE, 4)
			cv.draw_line(_center(Vector2(1,1)), tip, accent, 3)
	for enemy: Vector2 in [Vector2(0,1), Vector2(2,1)]:
		_enemy(enemy)
	for enemy: Vector2 in [Vector2(1,0), Vector2(1,2)]:
		_enemy(enemy, 1.0 - _ph(p, 0.5, 0.65))
		_pop(enemy, "−1", _ph(p, 0.4, 0.75))

## 斬撃精霊+: pick a direction; a wave three tiles wide and five long.
static func _flying_slash(time: float, accent: Color) -> void:
	var p := _cycle(time, 2.8)
	_art(FLYING_SLASH, Vector2(0,1))
	if p < 0.22:
		_arrow(_center(Vector2(0,1)) + Vector2(16,0), _center(Vector2(1,1)) + Vector2(10,0), accent, 4)
	var k := _ph(p, 0.22, 0.65)
	var front := C * (1.0 + k * 5.0)
	if k > 0.0:
		cv.draw_rect(Rect2(Vector2(C, 2), Vector2(front - C, C * 3 - 4)), Color(accent, 0.22 * (1.0 - _ph(p, 0.65, 0.9))))
	if k > 0.0 and k < 1.0:
		cv.draw_line(Vector2(front, 4), Vector2(front, C * 3 - 4), Color.WHITE, 5)
		cv.draw_line(Vector2(front - 6, 8), Vector2(front - 6, C * 3 - 8), accent, 3)
	for enemy: Vector2 in [Vector2(2,0), Vector2(4,1), Vector2(5,2)]:
		var hit: float = 0.22 + 0.43 * enemy.x / 5.0
		_enemy(enemy, 1.0 - _ph(p, hit + 0.08, hit + 0.2))
		_pop(enemy, "−1", _ph(p, hit, hit + 0.3))

## 2x2: rushes one way, cutting what it hits for 1 and driving it ahead; slammed into
## another enemy, both take 1 more (into a wall, nothing more).
static func _axe(time: float, accent: Color) -> void:
	var p := _cycle(time, 5.6)
	var into_enemy := p >= 0.5
	var q := fmod(p * 2, 1.0)
	# First into a wall (it just stops), then into another enemy (both take 1).
	if into_enemy:
		_enemy(Vector2(5,0), 1.0 - _ph(q, 0.72, 0.85))
	else:
		_art(WALL, Vector2(5,0))
	var sweep := _ph(q, 0.1, 0.45)
	var x := sweep * 2.0
	_enemy(Vector2(minf(maxf(3.0, x + 2.0), 4.0), 0), 1.0 - _ph(q, 0.72, 0.85))
	cv.draw_texture_rect_region(Units.AXE_DASH, Rect2(Vector2(x * C + 2, 2), Vector2.ONE * (C * 2 - 4)), Rect2(224,0,224,224), Color(1,1,1,1.0 - _ph(q, 0.7, 0.85)))
	if sweep > 0.0 and sweep < 1.0:
		for k in 3:
			cv.draw_line(Vector2(x * C - 6 - k * 10, 14 + k * 24), Vector2(x * C - 20 - k * 10, 14 + k * 24), Color(accent, 0.8), 2)
	_pop(Vector2(3,0), "−1", _ph(q, 0.2, 0.5))
	_bump(Vector2(4,0), Vector2(5,0), q, 0.45, into_enemy)
	_steps(1 if into_enemy else 0, 2)

## A knockback weapon: no damage, but the enemy slides all the way until something
## stops it. Slammed into another enemy, both take 1; into a wall, nothing.
static func _knockback(time: float) -> void:
	var p := _cycle(time, 5.0)
	var into_enemy := p < 0.5
	var q := fmod(p * 2, 1.0)
	_player(Vector2(0,0))
	var swing := _ph(q, 0.1, 0.22)
	if swing > 0.0 and swing < 1.0:
		cv.draw_line(_center(Vector2(1,0)) + Vector2(-14, -14), _center(Vector2(1,0)) + Vector2(14, 14), Color.WHITE, 4)
	if into_enemy:
		_enemy(Vector2(4,0), 1.0 - _ph(q, 0.78, 0.9))
	else:
		_art(WALL, Vector2(4,0))
	var slide := _ph(q, 0.22, 0.42)
	var at := Vector2(1,0).lerp(Vector2(3,0), slide)
	if slide > 0.0 and slide < 1.0:
		for k in 3:
			cv.draw_line(_center(at) - Vector2(16 + k * 7, -8 + k * 8), _center(at) - Vector2(26 + k * 7, -8 + k * 8), Color(1,1,1,0.6), 2)
	_enemy(at, 1.0 - (_ph(q, 0.78, 0.9) if into_enemy else 0.0))
	_bump(Vector2(3,0), Vector2(4,0), q, 0.42, into_enemy)
	_steps(0 if into_enemy else 1, 2)

## The collision between two tiles at `at` (0..1 of the cycle). Into another enemy:
## a burst, "ドン", and a "−1" in the collision colour on both. Into anything else:
## just a small stop, no damage.
static func _bump(shoved: Vector2, hit: Vector2, q: float, at: float, hurt: bool) -> void:
	var k := _ph(q, at, at + 0.2)
	var contact := (_center(shoved) + _center(hit)) / 2.0
	if not hurt:
		if k > 0.0 and k < 1.0:
			cv.draw_line(contact - Vector2(0, 12), contact + Vector2(0, 12), Color(1,1,1,1.0 - k), 3)
		return
	if k > 0.0 and k < 1.0:
		for n in 8:
			var ray := Vector2.from_angle(n * TAU / 8 + 0.2) * (6 + k * 12) * (1.0 if n % 2 == 0 else 0.6)
			cv.draw_line(contact, contact + ray, BUMP, 3)
		_say(contact + Vector2(0, -C * (0.3 if board.y == 1 else 0.55)), "ドン", 13, BUMP)
	_pop(shoved, "−1", _ph(q, at + 0.08, at + 0.4), BUMP, 10)
	_pop(hit, "−1", _ph(q, at + 0.08, at + 0.4), BUMP, 10)

## A 2x2 ally that strikes what touches it; broken, two holy knights step out.
static func _holy(time: float, accent: Color) -> void:
	var p := _cycle(time, 3.4)
	if p < 0.62:
		# It strikes (or steps towards) the tiles along its edges.
		_ally_reach(Vector2(1,0), [Vector2(-1,0), Vector2(-1,1), Vector2(2,0), Vector2(2,1), Vector2(0,2), Vector2(1,2), Vector2(0,-1), Vector2(1,-1)])
		_art(Units.HOLY_SPIRIT, Vector2(1,0), 1.0, 2.0)
		_flash(Vector2(1,0), RED, _ph(p, 0.52, 0.62), 2.0)
	else:
		cv.draw_rect(Rect2(Vector2(1,0) * C + Vector2(2,2), Vector2.ONE * (C * 2 - 4)), Color(accent, 0.25 * (1.0 - _ph(p, 0.62, 0.8))))
		for knight: Vector2 in [Vector2(1,0), Vector2(2,1)]:
			_region(Units.HOLY_KNIGHT, Rect2(152,22,80,80), knight, _ph(p, 0.62, 0.72))
	_enemy(Vector2(3,1), 1.0 - _ph(p, 0.3, 0.42))
	_pop(Vector2(3,1), "−1", _ph(p, 0.18, 0.5))
	# Another enemy breaks it.
	_enemy(Vector2(3,0) - Vector2(sin(_ph(p, 0.48, 0.62) * PI) * 0.25, 0))

## Placed where no weapon reaches (here: holding silver); swap with it for 0 AP.
static func _shadow(time: float, art: Texture2D) -> void:
	var p := _cycle(time, 4.2)
	var swap := _ph(p, 0.55, 0.72)
	_reach(Vector2i(1,1) if swap < 1.0 else Vector2i(4,1))
	if p < 0.2:
		_cursor(Vector2(2,1), false)
	elif p < 0.38:
		_cursor(Vector2(4,1), true)
	if p >= 0.3:
		_art(art, Vector2(4,1).lerp(Vector2(1,1), swap), _ph(p, 0.3, 0.38))
	_player(Vector2(1,1).lerp(Vector2(4,1), swap))
	if swap > 0.0:
		_say(_center(Vector2(2.5,0)), "0 AP", 16, GOLD)

## Summoned where no weapon reaches (here: holding silver); it moves and bites like
## a silver general facing right. Alone it bites for 2,
## next to you or another ally for 1, and on a tile a weapon reaches it sulks.
static func _wolf(time: float) -> void:
	var p := _cycle(time, 5.4)
	var phase := mini(int(p * 3), 2)
	var q := fmod(p * 3, 1.0)
	_reach(Vector2i(1,1))
	_player(Vector2(1,1))
	match phase:
		0:
			_enemy(Vector2(4,1), 1.0 - _ph(q, 0.55, 0.7))
			# A silver bite: up-right, lunging toward the prey and back.
			var lunge := sin(_ph(q, 0.3, 0.5) * PI) * 0.3
			_wolf_art(Vector2(3,2) + Vector2(lunge, -lunge), 1)
			_pop(Vector2(4,1), "−2", _ph(q, 0.4, 0.8), RED, 0, 24)
		1:
			_enemy(Vector2(2,0))
			cv.draw_line(_center(Vector2(1,0)), _center(Vector2(1,1)), Color(GREEN, 0.8), 3)
			_wolf_art(Vector2(1,0) + Vector2(sin(_ph(q, 0.3, 0.45) * PI) * 0.25, 0), 1)
			_pop(Vector2(2,0), "−1", _ph(q, 0.35, 0.8))
		2:
			_enemy(Vector2(3,1))
			_art(Units.WOLF_SULK, Vector2(2,1))
			_say(_center(Vector2(2,1)) + Vector2(10,-12), "…", 20, Color.WHITE)
	_steps(phase)

## Called from your own tile: for five turns every empty tile (no enemy, no
## obstacle) that no weapon reaches is a pit (here: holding silver). Enemies cannot
## walk on pits; one shoved in is gone. When you move, your reach moves and the
## pits move with it: tiles you now reach close up, tiles you left open.
static func _abyss(time: float, accent: Color, art: Texture2D) -> void:
	var p := _cycle(time, 8.0)
	var step := 0 if p < 0.26 else 1 if p < 0.44 else 2 if p < 0.66 else 3
	var moved := _ph(p, 0.7, 0.8)
	var shift := _ph(p, 0.8, 0.9)
	var shove := _ph(p, 0.46, 0.54)
	var obstacle := Vector2i(4,0)
	# The pits before and after the player steps right (the obstacle and enemies stay floor).
	var taken: Array[Vector2i] = [obstacle, Vector2i(4,1)]
	if shove <= 0.0:
		taken.append(Vector2i(2,1))
	var before := _pits(Vector2i(1,1), taken)
	var after := _pits(Vector2i(2,1), taken)
	for y in board.y:
		for x in board.x:
			var cell := Vector2i(x, y)
			var delay := Vector2(cell - Vector2i(1,1)).length() * 0.025
			var open := _ph(p, 0.14 + delay, 0.2 + delay)
			var k := 0.0
			if before.has(cell) and after.has(cell):
				k = open
			elif before.has(cell):
				k = open * (1.0 - shift)
			elif after.has(cell):
				k = shift
			_rift(cell, before if shift < 0.5 else after, k)
			# Tiles that change when the reach moves blink.
			if before.has(cell) != after.has(cell) and shift > 0.0 and p < 0.96:
				var blink := 0.5 + 0.5 * sin(p * 90.0)
				cv.draw_rect(Rect2(Vector2(cell) * C + Vector2.ONE * 3, Vector2.ONE * (C - 6)), Color(accent, blink), false, 3)
	_art(WALL, Vector2(obstacle))
	_reach(Vector2i(1,1) if moved < 0.5 else Vector2i(2,1))
	_player(Vector2(1,1).lerp(Vector2(2,1), moved))
	if moved > 0.0 and moved < 1.0:
		_arrow(_center(Vector2(1,1)) + Vector2(0, 14), _center(Vector2(2,1)) + Vector2(0, 14), Color.WHITE, 3)
	# Pressing your own tile calls the spirit up out of it...
	if p < 0.08:
		_cursor(Vector2(1,1), true)
	var rise := _ph(p, 0.05, 0.12)
	if rise > 0.0 and p < 0.26:
		cv.draw_arc(_center(Vector2(1,1)), 10 + rise * 30, 0, TAU, 32, Color(accent, 0.8 * (1.0 - _ph(p, 0.18, 0.26))), 3)
		_art(art, Vector2(1,1), rise, 1.0, 1.0 + rise * 0.3)
	elif p >= 0.26:
		# ...and it stays by you (on your tile's corner, glowing) while the pits last.
		var at := Vector2(1,1).lerp(Vector2(2,1), moved) * C + Vector2(-6, -8)
		cv.draw_circle(at + Vector2.ONE * 15, 16, Color(accent, 0.35))
		cv.draw_texture_rect_region(art, Rect2(at, Vector2.ONE * 30), _crop(art))
	# An enemy cannot step onto a pit.
	_enemy(Vector2(4,1) - Vector2(sin(_ph(p, 0.28, 0.38) * PI) * 0.2, 0))
	if p > 0.33 and p < 0.44:
		_cross(_center(Vector2(3,1)), 9)
	# A shove drops another one in: gone, whatever its HP.
	if shove <= 0.0:
		_enemy(Vector2(2,1))
	else:
		var sink := _ph(p, 0.52, 0.58)
		_enemy(Vector2(2,1).lerp(Vector2(3,1), shove), 1.0 - sink, 1.0 - sink * 0.6)
	if shove > 0.0 and shove < 1.0:
		_arrow(_center(Vector2(1.6,1)), _center(Vector2(2.4,1)), Color.WHITE, 4)
	_pop(Vector2(3,1), "撃破", _ph(p, 0.54, 0.68), GOLD)
	_steps(step, 4)

## Empty tiles (not the player's, not `taken`) the silver sword does not reach from `player`.
static func _pits(player: Vector2i, taken: Array[Vector2i]) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in board.y:
		for x in board.x:
			var cell := Vector2i(x, y)
			if cell != player and not taken.has(cell) and not _reaches(player, cell):
				result.append(cell)
	return result

## One pit tile: dark, with a crumbling stone lip on the sides that meet solid floor.
static func _rift(cell: Vector2i, pits: Array[Vector2i], k: float) -> void:
	if k <= 0.0:
		return
	var pos := Vector2(cell) * C
	cv.draw_rect(Rect2(pos, Vector2.ONE * C), Color(Color("08060f"), k))
	cv.draw_rect(Rect2(pos, Vector2.ONE * C), Color(0.32, 0.24, 0.62, 0.12 * k))
	for side: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		if pits.has(cell + side):
			continue
		var lip := Rect2(pos, Vector2(C, 4)) if side == Vector2i.UP else Rect2(pos + Vector2(0, C - 4), Vector2(C, 4)) if side == Vector2i.DOWN else Rect2(pos, Vector2(4, C)) if side == Vector2i.LEFT else Rect2(pos + Vector2(C - 4, 0), Vector2(4, C))
		cv.draw_rect(lip, Color(Color("4a4233"), k))

## Anywhere empty: outside the weapon's reach it pulls enemies in, inside it blows
## them away (here: holding silver). No damage.
static func _gravity(time: float, art: Texture2D) -> void:
	var p := _cycle(time, 4.4)
	var inside := p >= 0.5
	var q := fmod(p * 2, 1.0)
	_reach(Vector2i(0,1))
	_player(Vector2(0,1))
	var at := Vector2(1,1) if inside else Vector2(4,1)
	var color := PUSH if inside else PULL
	var wave := _ph(q, 0.2, 0.45)
	if wave > 0.0 and wave < 1.0:
		var radius := (wave * 1.4 if inside else (1.0 - wave) * 2.2) * C
		cv.draw_arc(_center(at), maxf(radius, 4.0), 0, TAU, 32, color, 4)
	_art(art, at)
	cv.draw_rect(Rect2(at * C + Vector2(1,1), Vector2.ONE * (C - 2)), color, false, 2)
	var move := _ph(q, 0.3, 0.5)
	_enemy(Vector2(2,1).lerp(Vector2(3,1), move))
	if move > 0.0:
		_arrow(_center(Vector2(2,1)), _center(Vector2(2.8,1)), color, 3)
	_steps(1 if inside else 0, 2)

## The 3x3 around it freezes: enemies there stop for 3 turns (4 upgraded).
static func _freeze(time: float, accent: Color, art: Texture2D, plus: bool) -> void:
	var p := _cycle(time, 3.0)
	var frost := _ph(p, 0.2, 0.4)
	if frost > 0.0:
		cv.draw_rect(Rect2(Vector2(1,0) * C, Vector2(3,3) * C), Color(0.7, 0.92, 1.0, 0.22 * frost))
		cv.draw_rect(Rect2(Vector2(1,0) * C, Vector2(3,3) * C), Color(accent, frost), false, 2)
	_art(art, Vector2(2,1))
	_enemy(Vector2(4,1).lerp(Vector2(4,2), _ph(p, 0.6, 0.8)))
	for enemy: Vector2 in [Vector2(1,0), Vector2(3,2)]:
		_enemy(enemy)
		if frost >= 1.0:
			_art(Units.FROZEN_OVERLAY, enemy, 0.8)
			_say(enemy * C + Vector2(C - 8, C - 6), str(4 if plus else 3), 14, Color("c8f4ff"))

## Blessed ground for five turns: while you stand in its 3x3, your hits also land
## above and below. Step out and they do not.
static func _blessing(time: float, accent: Color, art: Texture2D, plus: bool) -> void:
	var p := _cycle(time, 5.0)
	# Classed up, the 5x5 leaves no tile to step out to on this board.
	var inside := p < 0.5 or plus
	var q := fmod(p * 2, 1.0)
	var reach := 2 if plus else 1
	var area := Rect2(Vector2(1 - reach, 1 - reach) * C, Vector2.ONE * (reach * 2 + 1) * C).intersection(Rect2(Vector2.ZERO, Vector2(5,3) * C))
	cv.draw_rect(area, Color(accent, 0.22))
	cv.draw_rect(area, accent, false, 2)
	_art(art, Vector2(1,1))
	var stand := Vector2(2,1) if inside else Vector2(3,1)
	var column := stand.x + 1
	_player(stand)
	var swing := _ph(q, 0.3, 0.45)
	if swing > 0.0 and swing < 1.0:
		var reach_px := C * (1.4 if inside else 0.4) * swing
		cv.draw_line(_center(Vector2(column,1)) - Vector2(0, reach_px), _center(Vector2(column,1)) + Vector2(0, reach_px), Color.WHITE, 4)
	for y in 3:
		var enemy := Vector2(column, y)
		var hit := inside or y == 1
		_enemy(enemy, 1.0 - (_ph(q, 0.5, 0.65) if hit else 0.0))
		if hit:
			_pop(enemy, "−1", _ph(q, 0.35, 0.7), RED if y == 1 else GOLD)
	if not inside and q > 0.5:
		for y in [0, 2]:
			_cross(_center(Vector2(column, y)), 7)
	if not plus:
		_steps(0 if inside else 1, 2)

## Called from your own tile: meteors hit random tiles in reach (here: holding
## silver), 3 to every enemy in the 3x3. You and your allies are safe.
static func _meteor(time: float, art: Texture2D, count: int) -> void:
	var p := _cycle(time, 3.4)
	_reach(Vector2i(0,1))
	_art(art, Vector2(0,0))
	_player(Vector2(0,1))
	var spots: Array[Vector2] = [Vector2(1,1), Vector2(1,0), Vector2(1,2), Vector2(1,1), Vector2(1,0)]
	var enemies: Array[Vector2] = [Vector2(2,0), Vector2(2,1), Vector2(2,2), Vector2(4,1)]
	var hits := {}
	for m in mini(count, spots.size()):
		var start := 0.12 + m * 0.1
		var fall := _ph(p, start, start + 0.18)
		var target := spots[m]
		if fall > 0.0 and fall < 1.0:
			var rock := (target * C + Vector2(C * 0.5 + 60, -60)).lerp(_center(target), fall)
			cv.draw_line(rock, rock + Vector2(34, -30), Color("c8261a"), 10)
			cv.draw_line(rock, rock + Vector2(26, -23), Color("ff7a1a"), 6)
			cv.draw_line(rock, rock + Vector2(14, -12), Color("fff0a0"), 3)
			cv.draw_circle(rock, 8, Color("3b3431"))
		var boom := _ph(p, start + 0.18, start + 0.4)
		if boom > 0.0 and boom < 1.0:
			cv.draw_rect(Rect2((target - Vector2.ONE) * C, Vector2(3,3) * C).intersection(Rect2(Vector2.ZERO, Vector2(5,3) * C)), Color(1, 0.48, 0.1, 0.45 * (1.0 - boom)))
		for enemy in enemies:
			if absf(enemy.x - target.x) <= 1 and absf(enemy.y - target.y) <= 1 and not hits.has(enemy):
				hits[enemy] = start + 0.18
	for enemy in enemies:
		var hit: float = hits.get(enemy, 2.0)
		_enemy(enemy, 1.0 - _ph(p, hit + 0.12, hit + 0.24))
		_pop(enemy, "−3", _ph(p, hit, hit + 0.35), RED, 0, 20)

## A 2x2 guardian lands, and one of each fairy summoned this battle comes back
## around it with +1 HP.
static func _guardian(time: float) -> void:
	var p := _cycle(time, 3.6)
	var land := _ph(p, 0.05, 0.2)
	# Like the holy spirit: the tiles along its edges.
	_ally_reach(Vector2(2,1), [Vector2(-1,0), Vector2(-1,1), Vector2(2,0), Vector2(2,1), Vector2(0,2), Vector2(1,2), Vector2(0,-1), Vector2(1,-1)], land)
	if land > 0.0 and land < 1.0:
		cv.draw_rect(Rect2(Vector2(2 * C + 18, 0), Vector2(C * 2 - 36, C * 3 * land)), Color(1, 0.95, 0.7, 0.7))
	_art(Units.GUARDIAN, Vector2(2,1) - Vector2(0, (1.0 - land) * 0.6), land, 2.0)
	# [tile, art, sheet frame (or none), tiles wide, gets +1 HP]
	var calls := [
		[Vector2(2,0), STEALTH, Rect2(), 1.0, false],
		[Vector2(3,0), Units.ACORN, Rect2(), 1.0, true],
		[Vector2(4,1), Units.WOLF_SHEET, Rect2(800,36,192,192), 1.0, true],
		[Vector2(4,2), Units.GLUTTON, Rect2(), 1.0, true],
		[Vector2(0,1), Units.HOLY_SPIRIT, Rect2(), 2.0, true],
	]
	for k in calls.size():
		var call: Array = calls[k]
		var at: Vector2 = call[0]
		var span: float = call[3]
		var shown := _ph(p, 0.28 + k * 0.08, 0.34 + k * 0.08)
		if shown <= 0.0:
			continue
		if shown < 1.0:
			cv.draw_rect(Rect2(at * C + Vector2(C * span / 2 - 5, 0), Vector2(10, C * span)), Color(1, 0.95, 0.75, 0.8 * (1.0 - shown)))
		if call[2] == Rect2():
			_art(call[1], at, shown, span)
		else:
			_region(call[1], call[2], at, shown)
		if call[4]:
			_heart_up(at * C + Vector2(C * span - 10, 12), _ph(p, 0.4 + k * 0.08, 0.75 + k * 0.08))

## Bites the easiest thing to reach for 99, you included (you first when tied).
## It only swallows 1x1: a 2x2 is too big.
static func _glutton(time: float) -> void:
	var p := _cycle(time, 5.4)
	var phase := mini(int(p * 3), 2)
	var q := fmod(p * 3, 1.0)
	var lunge := sin(_ph(q, 0.2, 0.45) * PI) * 0.35
	# The gold general's moves, facing right: where it can step and bite.
	_ally_reach(Vector2(1,1), [Vector2(1,-1), Vector2(1,0), Vector2(1,1), Vector2(0,-1), Vector2(0,1), Vector2(-1,0)])
	match phase:
		0:
			_enemy(Vector2(2,1), 1.0 - _ph(q, 0.32, 0.4))
			_pop(Vector2(2,1), "99", _ph(q, 0.3, 0.75), GOLD, 0, 24)
			_heart_up(Vector2(1,1) * C + Vector2(C - 8, 10), _ph(q, 0.45, 0.9))
		1:
			_rook(Vector2(2,0), Vector2(sin(_ph(q, 0.3, 0.4) * PI) * 3, 0))
			if q > 0.35:
				_cross(_center(Vector2(2.5,0.5)), 14)
			lunge = sin(_ph(q, 0.2, 0.35) * PI) * 0.2
		2:
			_player(Vector2(2,1), 1.0 - _ph(q, 0.5, 0.65))
			_flash(Vector2(2,1), RED, _ph(q, 0.3, 0.55))
			_pop(Vector2(2,1), "99", _ph(q, 0.3, 0.8), RED, 0, 24)
	_art(Units.GLUTTON, Vector2(1,1) + Vector2(lunge, 0))
	_steps(phase)

# --- Pieces --------------------------------------------------------------------

## Scale the board into `rect`, centred, at most twice its size.
static func _fit(canvas: CanvasItem, rect: Rect2) -> void:
	var size := Vector2(board) * C
	var zoom := minf(minf(rect.size.x / size.x, rect.size.y / size.y), 2.0)
	canvas.draw_set_transform(rect.position + (rect.size - size * zoom) / 2.0, 0.0, Vector2.ONE * zoom)
	cv = canvas

static func _cycle(time: float, length: float) -> float:
	return fmod(time, length) / length

## 0 before `a`, 1 after `b`, linear in between.
static func _ph(p: float, a: float, b: float) -> float:
	return clampf((p - a) / (b - a), 0.0, 1.0)

static func _center(cell: Vector2) -> Vector2:
	return (cell + Vector2(0.5, 0.5)) * C

static func _board(accent: Color) -> void:
	for y in board.y:
		for x in board.x:
			var rect := Rect2(Vector2(x, y) * C + Vector2.ONE, Vector2.ONE * (C - 2))
			cv.draw_rect(rect, Color("192828"))
			cv.draw_rect(rect, Color(accent, 0.35), false, 1)

static func _tint(cell: Vector2, color: Color) -> void:
	cv.draw_rect(Rect2(cell * C + Vector2.ONE, Vector2.ONE * (C - 2)), color)

## Dots under a multi-part example: which part is playing.
static func _steps(current: int, count: int = 3) -> void:
	for k in count:
		cv.draw_circle(Vector2(C * board.x / 2.0 + (k - (count - 1) / 2.0) * 10, C * board.y - 4), 3, Color.WHITE if k == current else Color(1,1,1,0.25))

static func _reaches(player: Vector2i, cell: Vector2i) -> bool:
	return SILVER_REACH.has(cell - player)

## A summoned ally's reach: the tiles (offsets from `origin`) it can step to or strike,
## in the ally green, dashed.
static func _ally_reach(origin: Vector2, offsets: Array, alpha: float = 1.0) -> void:
	for offset: Vector2 in offsets:
		var cell := origin + offset
		if cell.x < 0 or cell.y < 0 or cell.x >= board.x or cell.y >= board.y:
			continue
		var rect := Rect2(cell * C + Vector2.ONE * 3, Vector2.ONE * (C - 6))
		cv.draw_rect(rect, Color(GREEN, 0.13 * alpha))
		var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
		for k in 4:
			var a: Vector2 = corners[k]
			var b: Vector2 = corners[(k + 1) % 4]
			var t := 0.0
			while t < 1.0:
				cv.draw_line(a.lerp(b, t), a.lerp(b, minf(t + 0.22, 1.0)), Color(GREEN, 0.85 * alpha), 2)
				t += 0.36

## The silver sword's reach from the player: the tiles a weapon reaches.
static func _reach(player: Vector2i) -> void:
	for offset: Vector2i in SILVER_REACH:
		var cell: Vector2i = player + offset
		if cell.x < 0 or cell.y < 0 or cell.x >= board.x or cell.y >= board.y:
			continue
		var rect := Rect2(Vector2(cell) * C + Vector2.ONE * 2, Vector2.ONE * (C - 4))
		cv.draw_rect(rect, Color(SILVER, 0.16))
		cv.draw_rect(rect, Color(SILVER, 0.75), false, 2)

## Texture filling a tile (or a span x span block), square.
static func _art(texture: Texture2D, cell: Vector2, alpha: float = 1.0, span: float = 1.0, scale: float = 1.0) -> void:
	if texture == null or alpha <= 0.0:
		return
	var side := (C * span - 4) * scale
	var center := cell * C + Vector2.ONE * C * span / 2
	cv.draw_texture_rect_region(texture, Rect2(center - Vector2.ONE * side / 2, Vector2.ONE * side), _crop(texture), Color(1,1,1,alpha))

static func _crop(texture: Texture2D) -> Rect2:
	var crop: Rect2 = CROPS.get(texture.resource_path.get_file().get_basename(), Rect2(0, 0, 1, 1))
	return Rect2(crop.position * texture.get_size(), crop.size * texture.get_size())

static func _region(texture: Texture2D, source: Rect2, cell: Vector2, alpha: float = 1.0) -> void:
	if alpha <= 0.0:
		return
	cv.draw_texture_rect_region(texture, Rect2(cell * C + Vector2.ONE * 2, Vector2.ONE * (C - 4)), source, Color(1,1,1,alpha))

static func _wolf_art(cell: Vector2, facing: int) -> void:
	_region(Units.WOLF_SHEET, Rect2(facing * 256 + 32, 36, 192, 192), cell)

## A soldier, facing left towards the player's side.
static func _enemy(cell: Vector2, alpha: float = 1.0, scale: float = 1.0) -> void:
	if alpha <= 0.0:
		return
	var side := (C - 4) * scale
	cv.draw_texture_rect_region(Units.ENEMY_ATLAS, Rect2(_center(cell) - Vector2.ONE * side / 2, Vector2.ONE * side), Rect2(85,0,26,26), Color(1,1,1,alpha))

## A 2x2 boss (突進くん) with its top-left tile at `cell`.
static func _rook(cell: Vector2, shake: Vector2 = Vector2.ZERO) -> void:
	cv.draw_texture_rect_region(Units.ROOK_ATLAS, Rect2(cell * C + Vector2.ONE * 2 + shake, Vector2.ONE * (C * 2 - 4)), Rect2(168,0,56,56))

## The player, facing right.
static func _player(cell: Vector2, alpha: float = 1.0) -> void:
	if alpha <= 0.0:
		return
	var atlas := Units.PLAYER_ATLAS_CELL
	cv.draw_texture_rect_region(Units.PLAYER_ATLAS, Rect2(cell * C + Vector2.ONE * 2, Vector2.ONE * (C - 4)), Rect2(atlas + 30, 2 * atlas + 16, atlas - 44, atlas - 44), Color(1,1,1,alpha))

static func _flash(cell: Vector2, color: Color, k: float, span: float = 1.0) -> void:
	if k <= 0.0 or k >= 1.0:
		return
	cv.draw_rect(Rect2(cell * C + Vector2.ONE * 2, Vector2.ONE * (C * span - 4)), Color(color, 0.7 * (1.0 - k)))

## A number rising out of a tile (k: 0 hidden, then 0..1 over its life).
static func _pop(cell: Vector2, text: String, k: float, color: Color = RED, lift: float = 0.0, font_size: int = 18) -> void:
	if k <= 0.0 or k >= 1.0:
		return
	# On a one-row board there is no room above: numbers rise inside the tile.
	var room := 18.0 if board.y == 1 else 0.0
	_say(_center(cell) - Vector2(0, 8 + k * 8 + lift - room), text, font_size, color)

## Centred text with a dark outline so it reads over anything.
static func _say(center: Vector2, text: String, font_size: int, color: Color) -> void:
	var width := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var at := center + Vector2(-width / 2, font_size * 0.35)
	cv.draw_string_outline(FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 5, Color("0a1112"))
	cv.draw_string(FONT, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

static func _arrow(from: Vector2, to: Vector2, color: Color, width: float = 3) -> void:
	var along := (to - from).normalized()
	cv.draw_line(from, to - along * 6, color, width)
	cv.draw_colored_polygon(PackedVector2Array([to + along * 4, to - along * 8 + along.orthogonal() * 7, to - along * 8 - along.orthogonal() * 7]), color)

static func _dashed(from: Vector2, to: Vector2, color: Color) -> void:
	var length := from.distance_to(to)
	var t := 0.0
	while t < length:
		cv.draw_line(from.lerp(to, t / length), from.lerp(to, minf(t + 6, length) / length), color, 2)
		t += 11

## A red "no".
static func _cross(center: Vector2, arm: float) -> void:
	cv.draw_circle(center, arm + 5, Color("0a1112"))
	cv.draw_line(center - Vector2(arm, arm), center + Vector2(arm, arm), RED, 4)
	cv.draw_line(center + Vector2(-arm, arm), center + Vector2(arm, -arm), RED, 4)

## A placement cursor on a tile: a green check where it may go, a red cross where not.
static func _cursor(cell: Vector2, ok: bool) -> void:
	cv.draw_rect(Rect2(cell * C + Vector2.ONE * 2, Vector2.ONE * (C - 4)), GREEN if ok else RED, false, 3)
	var center := _center(cell)
	if ok:
		cv.draw_polyline(PackedVector2Array([center + Vector2(-9, 0), center + Vector2(-3, 7), center + Vector2(10, -8)]), GREEN, 4)
	else:
		_cross(center, 8)

## A heart that grows in beside a "+1" (the guardian's blessing, the glutton's meal).
static func _heart_up(at: Vector2, k: float) -> void:
	if k <= 0.0 or k >= 1.0:
		return
	var s := 6.0 + minf(k * 3, 1.0) * 4
	var points := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		points.append(at + Vector2(16 * pow(sin(a), 3), -(13 * cos(a) - 5 * cos(2 * a) - 2 * cos(3 * a) - cos(4 * a))) * s / 16)
	cv.draw_colored_polygon(points, Color("ff5b62"))
	_say(at + Vector2(0, -14), "+1", 13, GREEN)

## A jagged discharge between two points.
static func _bolt(from: Vector2, to: Vector2, color: Color) -> void:
	var points := PackedVector2Array([from])
	var normal := (to - from).normalized().orthogonal()
	for k in range(1, 6):
		points.append(from.lerp(to, k / 6.0) + normal * (5 if k % 2 == 0 else -5))
	points.append(to)
	cv.draw_polyline(points, Color.WHITE, 4)
	cv.draw_polyline(points, color, 2)
