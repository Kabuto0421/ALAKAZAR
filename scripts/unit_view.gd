extends Node2D

const ACORN = preload("res://assets/sprites/spirits/acorn_fairy.png")
const GLUTTON = preload("res://assets/sprites/spirits/glutton_fairy.png")
const WOLF_SHEET = preload("res://assets/sprites/spirits/lone_wolf_directions.png")
const WOLF_SULK = preload("res://assets/sprites/spirits/lone_wolf_sulk.png")
const PLAYER_ATLAS = preload("res://assets/sprites/adventurer_weapon_directions_64.png")
const SWORD_ATTACK_ATLAS = preload("res://assets/sprites/attacks/sword-attack-directions.png")
const SwordMotion = preload("res://scripts/animation/sword_motion.gd")
const ENEMY_ATLAS = preload("res://assets/sprites/enemies/police_officer_directions_28.png")
const CAVALRY_ATLAS = preload("res://assets/sprites/enemies/cavalry_hover_directions_28.png")
const ROOK_ATLAS = preload("res://assets/sprites/enemies/rook_boss_directions_56.png")
const PRISON_ATLAS = preload("res://assets/sprites/enemies/prison_directions.png")
const EXECUTIONER_ATLAS = preload("res://assets/sprites/enemies/executioner_directions.png")
const ROTORICK_ATLAS = preload("res://assets/sprites/enemies/rotorick_reel_112.png")
const ROTORICK_SHADOW = preload("res://assets/sprites/enemies/rotorick_shadow_112.png")
const HOLY_SPIRIT = preload("res://assets/sprites/spirits/holy_spirit.png")
const HOLY_KNIGHT = preload("res://assets/sprites/spirits/holy_knight_directions.png")
const AXE_DASH = preload("res://assets/sprites/spirits/axe_spirit_dash.png")
const BOSS_KINDS = ["rook", "prison", "executioner", "slot", "shadow"]
## Soldier sheets: 128 px cells, columns up/right/down/left, optional second row
## for a state (archer aiming, analyst holding a learned weapon), draw size.
const SOLDIER_SHEETS = {
	"javelin": [preload("res://assets/sprites/enemies/javelin_directions.png"), 80.0],
	"shield": [preload("res://assets/sprites/enemies/shield_soldier_directions.png"), 64.0],
	"archer": [preload("res://assets/sprites/enemies/archer_directions.png"), 66.0],
	"analyst": [preload("res://assets/sprites/enemies/analyst_directions.png"), 62.0],
}
## Second-row state for soldier sheets (archer aiming, analyst after learning).
var alt_row := false
const PLAYER_ATLAS_CELL := 362.0
const SWORD_ATTACK_CELL := 480.0
var kind := "player"
## Lone wolf inside the player's reach: it will skip its turn.
var sulking := false
## A sulking wolf turns its back on the player: true when the player is to its right.
var sulk_flip := false
var hp := 5
var weapon_row := 0
var facing := 0
var flash := 0.0
var clock := 0.0
var charge_warning := false
var attack_target := false
var hop_height := 0.0
var sword_attack_elapsed := -1.0
var sword_attack_facing := 0
var hit_elapsed := -1.0
var hit_direction := Vector2.ZERO
var status_layer: Node2D
## Tiles per side (2 for the rook and the moving prison).
var span := 1
## Rook: red braced sprite row. Rotorick: red charge panel.
var braced := false
## Rotorick's reel (0 = spinning).
var reel := 0
## Analyst: the weapon it has learned ("" = none) and its colour.
var learned_text := ""
var learned_color := Color.WHITE
const BADGE_FONT = preload("res://assets/fonts/DotGothic16-Regular.ttf")

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	status_layer = Node2D.new()
	status_layer.z_index = 4
	status_layer.draw.connect(_draw_status)
	add_child(status_layer)

func _process(delta: float) -> void:
	flash = maxf(0.0, flash-delta)
	clock += delta
	if sword_attack_elapsed >= 0.0:
		sword_attack_elapsed += delta
		if sword_attack_elapsed >= SwordMotion.duration(sword_attack_facing):
			sword_attack_elapsed = -1.0
			z_index = 2
	if hit_elapsed >= 0.0:
		hit_elapsed += delta
		if hit_elapsed >= 0.16:
			hit_elapsed = -1.0
	queue_redraw()
	status_layer.queue_redraw()

func play_sword_attack(direction: int) -> void:
	sword_attack_facing = clampi(direction, 0, 3)
	sword_attack_elapsed = 0.0
	z_index = 3
	queue_redraw()

func sword_attack_duration() -> float:
	return SwordMotion.duration(sword_attack_facing)

func sword_impact_time() -> float:
	return SwordMotion.impact_time(sword_attack_facing)

func play_hit_reaction(direction: Vector2) -> void:
	hit_direction = direction.normalized()
	hit_elapsed = 0.0
	flash = 0.12

## 金将兵・銀将兵: a living shogi piece, its point towards its front (left).
static func draw_general(canvas: CanvasItem, kind: String, tint: Color = Color.WHITE, factor: float = 1.0) -> void:
	var gold := kind == "gold"
	var metal := Color("f2c14e") if gold else Color("d6dfe9")
	var shade := Color("b0801c") if gold else Color("8e9aa8")
	var ink := Color("2a1a06") if gold else Color("1b2530")
	var outline := PackedVector2Array([Vector2(-30,-3), Vector2(-13,-27), Vector2(24,-30), Vector2(24,25), Vector2(-13,21)])
	var face := PackedVector2Array([Vector2(-26,-3), Vector2(-11,-24), Vector2(21,-27), Vector2(21,22), Vector2(-11,18)])
	var lower := PackedVector2Array([Vector2(-26,-3), Vector2(21,-3), Vector2(21,22), Vector2(-11,18)])
	for points in [outline, face, lower]:
		for i in points.size():
			points[i] *= factor
	canvas.draw_colored_polygon(outline, ink * tint)
	canvas.draw_colored_polygon(face, metal * tint)
	canvas.draw_colored_polygon(lower, shade.lerp(metal, 0.45) * tint)
	# Two glowing eyes on the point side, then the character.
	canvas.draw_circle(Vector2(-14,-9) * factor, 2.4 * factor, Color("ff4a4a"))
	canvas.draw_circle(Vector2(-14,3) * factor, 2.4 * factor, Color("ff4a4a"))
	canvas.draw_string(BADGE_FONT, Vector2(-7,9) * factor, "金" if gold else "銀", HORIZONTAL_ALIGNMENT_LEFT, -1, int(26 * factor), ink)

func _draw() -> void:
	if span > 1:
		draw_circle(Vector2(0,44),30,Color(0,0,0,0.3))
	elif kind == "wolf":
		# The wolf is long and low: a flat shadow under its paws.
		draw_set_transform(Vector2(0,26),0.0,Vector2(1,0.3))
		draw_circle(Vector2.ZERO,27,Color(0,0,0,0.35))
		draw_set_transform(Vector2.ZERO)
	else:
		draw_circle(Vector2(0,22),19,Color(0,0,0,0.35))
	if hit_elapsed >= 0.0:
		draw_set_transform((hit_direction * sin(hit_elapsed / 0.16 * PI) * 4.0).round())
	var tint := Color("ff997e") if flash > 0 else Color.WHITE
	if kind == "player":
		if weapon_row == 2 and sword_attack_elapsed >= 0.0:
			var frame := SwordMotion.frame_at(sword_attack_facing, sword_attack_elapsed)
			if frame < 0:
				var source := Rect2(sword_attack_facing*PLAYER_ATLAS_CELL,weapon_row*PLAYER_ATLAS_CELL,PLAYER_ATLAS_CELL,PLAYER_ATLAS_CELL)
				_draw_player_sprite(PLAYER_ATLAS, source, sword_attack_facing == 2, tint)
			else:
				var source := Rect2(frame * SWORD_ATTACK_CELL, sword_attack_facing * SWORD_ATTACK_CELL, SWORD_ATTACK_CELL, SWORD_ATTACK_CELL)
				var destination := SwordMotion.frame_rect(sword_attack_facing, frame)
				draw_texture_rect_region(SWORD_ATTACK_ATLAS, destination, source, tint)
		else:
			var source := Rect2(facing*PLAYER_ATLAS_CELL,weapon_row*PLAYER_ATLAS_CELL,PLAYER_ATLAS_CELL,PLAYER_ATLAS_CELL)
			_draw_player_sprite(PLAYER_ATLAS, source, weapon_row == 2 and facing == 2, tint)
	elif kind == "acorn":
		draw_texture_rect(ACORN,Rect2(-30,-35,60,60),false,tint)
	elif kind == "wolf":
		if sulking:
			# Curled up with its back to the player.
			draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1 if sulk_flip else 1, 1))
			draw_texture_rect(WOLF_SULK,Rect2(-34,-40,68,68),false,tint)
			draw_set_transform(Vector2.ZERO)
		else:
			draw_texture_rect_region(WOLF_SHEET,Rect2(-38,-46,76,76),Rect2(facing*256,0,256,256),tint)
		if sulking:
			draw_rect(Rect2(10,-36,28,17),Color(0.05,0.07,0.08,0.92))
			draw_rect(Rect2(10,-36,28,17),Color("b8bcd0"),false,1)
			for k in range(3):
				draw_circle(Vector2(17+k*7,-27),1.8,Color("e5e7f0"))
	elif kind == "holy":
		# A gentle bob, since the box has no facing of its own.
		var bob := sin(Time.get_ticks_msec() / 1000.0 * 2.4) * 2.0
		draw_texture_rect(HOLY_SPIRIT,Rect2(Vector2(-62,-68+bob),Vector2.ONE*124),false,tint)
	elif kind == "holy_knight":
		draw_texture_rect_region(HOLY_KNIGHT,Rect2(-32,-36,64,64),Rect2(facing*128,0,128,128),tint)
	elif kind == "miner":
		_draw_drone(tint)
	elif kind in ["cavalry","horse"]:
		_draw_cavalry(tint)
	elif kind in BOSS_KINDS:
		draw_boss(self, kind, facing, braced, tint, 1.0, reel)
	elif SOLDIER_SHEETS.has(kind):
		draw_soldier(self, kind, facing, alt_row, tint)
	elif kind in ["gold", "silver"]:
		draw_general(self, kind, tint)
	elif kind == "glutton":
		# A slight chewing bob.
		var chew := absf(sin(Time.get_ticks_msec() / 1000.0 * 5.0)) * 2.0
		draw_texture_rect(GLUTTON,Rect2(-31,-37+chew,62,62),false,tint)
	else:
		var side := 64.0 if kind == "heavy" else 56.0
		draw_texture_rect_region(ENEMY_ATLAS,Rect2(-side/2,-side/2-4,side,side),Rect2(facing*28,0,28,28),tint)
		if kind == "heavy":
			draw_rect(Rect2(-23,-6,20,30),Color("16272b"))
			draw_rect(Rect2(-21,-4,16,25),Color("78968f"))
			draw_rect(Rect2(-18,0,10,16),Color("293d42"))
			draw_rect(Rect2(-15,2,4,13),Color("b8d7c5"))
	draw_set_transform(Vector2.ZERO)

## Sheets use the game facing order: up, right, down, left.
static func draw_boss(canvas: CanvasItem, boss: String, direction: int, red: bool, tint: Color = Color.WHITE, factor: float = 1.0, reel_value: int = 0) -> void:
	match boss:
		"slot":
			# Always drawn facing front; the reel picks the frame (row-major, 8th = spinning).
			var frame: int = 7 if reel_value <= 0 else reel_value - 1
			canvas.draw_texture_rect_region(ROTORICK_ATLAS, Rect2(Vector2(-77,-82)*factor, Vector2.ONE*154*factor), Rect2((frame % 4)*112, (frame / 4)*112, 112, 112), tint)
		"shadow":
			# A flickering purple hologram: translucent, with scan lines.
			var t: float = Time.get_ticks_msec() / 1000.0
			var alpha := 0.5 + 0.12 * sin(t * 9.0)
			var jitter := Vector2(2.0 * sin(t * 23.0), 0) if int(t * 7) % 5 == 0 else Vector2.ZERO
			var rect := Rect2((Vector2(-77,-82) + jitter) * factor, Vector2.ONE * 154 * factor)
			canvas.draw_texture_rect_region(ROTORICK_SHADOW, rect, Rect2(224, 0, 112, 112), Color(0.85, 0.6, 1.0, alpha))
			for k in range(0, int(rect.size.y), 6):
				canvas.draw_line(Vector2(rect.position.x + 20 * factor, rect.position.y + k), Vector2(rect.end.x - 20 * factor, rect.position.y + k), Color(0.75, 0.45, 1.0, 0.12), 1)
		"rook":
			canvas.draw_texture_rect_region(ROOK_ATLAS, Rect2(Vector2(-62,-68)*factor, Vector2.ONE*124*factor), Rect2(direction*56, (56 if red else 0), 56, 56), tint)
		"prison":
			canvas.draw_texture_rect_region(PRISON_ATLAS, Rect2(Vector2(-62,-66)*factor, Vector2.ONE*124*factor), Rect2(direction*224, 0, 224, 224), tint)
		"executioner":
			canvas.draw_texture_rect_region(EXECUTIONER_ATLAS, Rect2(Vector2(-32,-38)*factor, Vector2.ONE*64*factor), Rect2(direction*160, 0, 160, 160), tint)

static func draw_soldier(canvas: CanvasItem, soldier: String, direction: int, alt: bool, tint: Color = Color.WHITE, factor: float = 1.0) -> void:
	var entry: Array = SOLDIER_SHEETS[soldier]
	var sheet: Texture2D = entry[0]
	var side: float = entry[1] * factor
	var row := 1 if alt and sheet.get_height() > 128 else 0
	canvas.draw_texture_rect_region(sheet, Rect2(Vector2(-side / 2, 28 * factor - side), Vector2.ONE * side), Rect2(direction * 128, row * 128, 128, 128), tint)

func _draw_status() -> void:
	var max_hp := 5 if kind == "player" else 7 if kind == "slot" else 3 if kind == "rook" else 2 if kind in ["heavy","horse","executioner","analyst","gold"] else 1
	# A unit that grew past its usual HP (the glutton after a meal) shows every heart.
	max_hp = maxi(max_hp, hp)
	var total := max_hp*11.0-1.0
	var grow := 32.0*(span-1)
	if kind == "slot":
		_draw_rotorick_arrows()
	var heart_y := -98.0 if kind == "slot" else 29+grow
	for i in range(max_hp):
		_draw_heart(Vector2(-total/2+i*11+5,heart_y),11.0,Color("ff5b62"),i < hp)
	if attack_target:
		for corner in [Vector2(-28-grow,-27-grow),Vector2(28+grow,-27-grow),Vector2(-28-grow,24+grow),Vector2(28+grow,24+grow)]:
			var inward := Vector2(-signf(corner.x),-signf(corner.y))
			status_layer.draw_line(corner,corner+Vector2(inward.x*10,0),Color("ff805a"),3)
			status_layer.draw_line(corner,corner+Vector2(0,inward.y*10),Color("ff805a"),3)
	if not learned_text.is_empty():
		# Badge over the head naming the weapon it has analysed.
		var width := 12.0 + learned_text.length() * 14.0
		var at := Vector2(-width / 2, -52)
		status_layer.draw_rect(Rect2(at, Vector2(width, 20)), Color(0.02, 0.08, 0.08, 0.92))
		status_layer.draw_rect(Rect2(at, Vector2(width, 20)), Color("7fffd0"), false, 2)
		status_layer.draw_string(BADGE_FONT, at + Vector2(6, 16), learned_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, learned_color)
	if charge_warning:
		var at := Vector2(10+grow,-32-grow)
		status_layer.draw_rect(Rect2(at,Vector2(22,28)), Color("191e29"))
		status_layer.draw_rect(Rect2(at+Vector2(2,2),Vector2(18,24)), Color("ffbd59"))
		status_layer.draw_rect(Rect2(at+Vector2(8,5),Vector2(6,12)), Color("351e20"))
		status_layer.draw_rect(Rect2(at+Vector2(8,20),Vector2(6,4)), Color("351e20"))

## Rotorick: red chevrons outside the body point where the next charge goes.
## Jammed (reel 5, state "stun"): yellow arrows crowd in from all around instead.
func _draw_rotorick_arrows() -> void:
	var pulse := 3.0 * sin(clock * 6.0)
	if not braced:
		# Two staggered rings of yellow arrows, all pointing in.
		for ring in range(2):
			for k in range(14):
				var dir := Vector2.from_angle((k + ring * 0.5) * TAU / 14.0 + clock * 0.4)
				var at := dir * (Vector2(84, 80) + Vector2.ONE * (ring * 22 - pulse)) + Vector2(0, -6)
				_chevron(at, -dir, 12.0 - ring * 2.0, Color("ffd35b") if ring == 0 else Color("ffe98a"))
		return
	var dir := Vector2([Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT][facing])
	var reach: float = [140.0, 96.0, 98.0, 96.0][facing]
	for k in range(2):
		_chevron(dir * (reach + pulse - k * 20) + Vector2(0, -6), dir, 24.0, Color(Color("ff3b3b"), 1.0 - k * 0.3))

func _chevron(tip: Vector2, dir: Vector2, size: float, color: Color) -> void:
	var side := Vector2(-dir.y, dir.x)
	var outer := PackedVector2Array([tip + dir * size * 0.2, tip - dir * size * 0.85 + side * size, tip - dir * size * 0.45 + side * size, tip + dir * size * 0.55, tip - dir * size * 0.45 - side * size, tip - dir * size * 0.85 - side * size])
	status_layer.draw_colored_polygon(outer, Color(0.05, 0.02, 0.02, 0.9))
	var inner := PackedVector2Array([tip, tip - dir * size * 0.7 + side * size * 0.75, tip - dir * size * 0.45 + side * size * 0.75, tip + dir * size * 0.28, tip - dir * size * 0.45 - side * size * 0.75, tip - dir * size * 0.7 - side * size * 0.75])
	status_layer.draw_colored_polygon(inner, color)

func _draw_cavalry(tint: Color, canvas: CanvasItem = null) -> void:
	if canvas == null:
		canvas = self
	# Atlas order is left, front, right, back; game facing order is up, right, down, left.
	var frame: int = [3,2,1,0][facing]
	canvas.draw_texture_rect_region(CAVALRY_ATLAS,Rect2(-32,-37,64,64),Rect2(frame*28,0,28,28),tint)

func _draw_heart(center: Vector2, size: float, color: Color, filled: bool) -> void:
	var half := size * 0.5
	var points := PackedVector2Array([
		center + Vector2(-half, -half*0.08),
		center + Vector2(-half, -half*0.38),
		center + Vector2(-half*0.68, -half*0.64),
		center + Vector2(-half*0.30, -half*0.74),
		center + Vector2(0, -half*0.36),
		center + Vector2(half*0.30, -half*0.74),
		center + Vector2(half*0.68, -half*0.64),
		center + Vector2(half, -half*0.38),
		center + Vector2(half, -half*0.08),
		center + Vector2(0, half*0.72),
	])
	status_layer.draw_colored_polygon(points,color if filled else Color("341d25"))
	status_layer.draw_polyline(points,Color("ff8b8f") if filled else Color("70434a"),0.8,true)

func _draw_drone(tint: Color, canvas: CanvasItem = null) -> void:
	if canvas == null:
		canvas = self
	var bob := roundf(sin(clock*3.0)*2.0)
	var dark := Color("13232b")*tint
	var metal := Color("587d83")*tint
	var light := Color("a2c7c4")*tint
	for x in [-24,12]:
		canvas.draw_rect(Rect2(x,-18+bob,14,6),dark)
		canvas.draw_rect(Rect2(x-3,-21+bob,20,3),light)
		canvas.draw_rect(Rect2(x+4,-15+bob,6,10),metal)
	canvas.draw_rect(Rect2(-18,-13+bob,36,18),dark)
	canvas.draw_rect(Rect2(-14,-16+bob,28,18),metal)
	canvas.draw_rect(Rect2(-10,-13+bob,20,5),light)
	canvas.draw_rect(Rect2(-6,-5+bob,12,8),Color("172e38"))
	canvas.draw_rect(Rect2(-3,-3+bob,6,4),Color("ffb84d"))
	canvas.draw_rect(Rect2(-5,6+bob,10,7),dark)
	canvas.draw_rect(Rect2(-2,9+bob,4,4),Color("ec8051"))

func _draw_player_sprite(texture: Texture2D, source: Rect2, enlarge_down_sword: bool, tint: Color) -> void:
	var destination := Rect2(-32, -37-hop_height, 64, 64)
	if enlarge_down_sword:
		# Keep the feet on their original baseline while giving the generated front-facing pose more presence.
		destination = Rect2(-38, -49-hop_height*1.1875, 76, 76)
	draw_texture_rect_region(texture, destination, source, tint)
