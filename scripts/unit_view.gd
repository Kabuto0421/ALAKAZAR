extends Node2D

const ACORN = preload("res://assets/sprites/spirits/acorn_fairy.png")
const WALL = preload("res://assets/sprites/spirits/wall_fairy.png")
## The Prison King and his fortresses: 256px sprite-sheet frames in one row.
const KING_SHEETS = {
	"idle": [preload("res://assets/sprites/boss/prison_king_idle.png"), 6, 5.0],
	"rage": [preload("res://assets/sprites/boss/prison_king_rage_idle.png"), 6, 8.0],
	"revive": [preload("res://assets/sprites/boss/prison_king_revive.png"), 6, 7.0],
	"hurt": [preload("res://assets/sprites/boss/prison_king_hurt.png"), 3, 10.0],
	"death": [preload("res://assets/sprites/boss/prison_king_death.png"), 8, 5.0],
}
const FORTRESS_SHEETS = {
	"idle": [preload("res://assets/sprites/boss/prison_fortress_idle.png"), 4, 4.0],
	"spawn": [preload("res://assets/sprites/boss/prison_fortress_spawn.png"), 6, 9.0],
}
const FORTRESS_DAMAGED = {
	2: preload("res://assets/sprites/boss/prison_fortress_hp2.png"),
	1: preload("res://assets/sprites/boss/prison_fortress_hp1.png"),
}
const KING_PORTRAIT = preload("res://assets/sprites/boss/prison_king_portrait.png")
const FROZEN_OVERLAY = preload("res://assets/sprites/spirits/frozen_overlay.png")
const GLUTTON = preload("res://assets/sprites/spirits/glutton_fairy.png")
const WOLF_SHEET = preload("res://assets/sprites/spirits/lone_wolf_directions.png")
const WOLF_SULK = preload("res://assets/sprites/spirits/lone_wolf_sulk.png")
const PLAYER_ATLAS = preload("res://assets/sprites/adventurer_weapon_directions_64.png")
## The player holding a hammer (ハンマー・木槌・十字槌; always facing right): standing,
## the raised windup and the strike with its impact burst. Anchors are the point
## between the feet in each frame, so the stance stays put between frames.
const HAMMER_FRAMES = [preload("res://assets/sprites/player_hammer_idle.png"), preload("res://assets/sprites/player_hammer_windup.png"), preload("res://assets/sprites/player_hammer_strike.png")]
const HAMMER_ANCHORS = [Vector2(235,555), Vector2(300,582), Vector2(225,545)]
## Scale that makes the hammer pose as tall as the other player sprites.
const HAMMER_SCALE := 0.127
## The swing: windup, then the strike. The head glides onto the tile (HAMMER_LUNGE),
## everything stops dead for a beat on contact (HAMMER_HITSTOP), then the rest plays.
const HAMMER_WINDUP := 0.2
const HAMMER_LUNGE := 0.09
const HAMMER_HITSTOP := 0.11
const HAMMER_STRIKE := 0.26

## When the head touches the tile, from the start of the swing.
static func hammer_contact() -> float:
	return HAMMER_WINDUP + HAMMER_LUNGE

static func hammer_duration() -> float:
	return HAMMER_WINDUP + HAMMER_HITSTOP + HAMMER_STRIKE

## Strike time with the hit-stop taken out: it stands still through the stop.
static func _strike_time(t: float) -> float:
	if t < HAMMER_LUNGE:
		return t
	return HAMMER_LUNGE if t < HAMMER_LUNGE + HAMMER_HITSTOP else t - HAMMER_HITSTOP
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
const GUARDIAN = preload("res://assets/sprites/spirits/guardian_fairy.png")
const HOLY_KNIGHT = preload("res://assets/sprites/spirits/holy_knight_directions.png")
const AXE_DASH = preload("res://assets/sprites/spirits/axe_spirit_dash.png")
const BOSS_KINDS = ["rook", "prison", "executioner", "slot", "shadow", "storm_shark"]
## The storm shark, a hologram (placeholder artwork until the real picture arrives).
const STORM_SHARK = preload("res://assets/sprites/boss/storm_shark.png")
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
## Hearts over the head instead of under the feet (a rider on the wheel hides the ground).
var hearts_above := false
## 0-1: how much of a hologram boss is projected (the storm shark dissolves when it dives
## and is rebuilt when it comes up); holo_goal is where it is heading.
var holo_build := 1.0
var holo_goal := 1.0
## The shark's moves: "bite" (a lunge with the jaw snapping), "dive" (nose down, sinking) and
## "surface" (leaping up out of the shadow, jaw wide); pose_t is the seconds into it.
const POSE_LENGTH := {"bite": 0.55, "dive": 0.7, "surface": 0.85}
var pose := ""
var pose_t := 0.0
## Where the hit shove left the drawing (the shark folds it into its own transform).
var _hit_off := Vector2.ZERO
var _hit_scale := Vector2.ONE

func play_pose(name: String) -> void:
	pose = name
	pose_t = 0.0
var sulking := false
## 氷結妖精: enemy turns this unit stays frozen (0 = not frozen).
var frozen := 0
## 時の妖精: time stands still for this enemy (a small stopped clock by its head).
var time_stopped := false
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
var hammer_attack_elapsed := -1.0
var hammer_lunge := Vector2.ZERO
var sword_attack_facing := 0
var hit_elapsed := -1.0
## A blessing (守護神: HP+1): three twinkles by the hearts and the new heart popping in.
var sparkle_elapsed := -1.0
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
## A one-shot sheet animation (the king's revive/hurt/death, a fortress's spawn); "" = idle loop.
var anim := ""
var anim_time := 0.0
const BADGE_FONT = preload("res://assets/fonts/DotGothic16-Regular.ttf")

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	status_layer = Node2D.new()
	status_layer.z_index = 4
	status_layer.draw.connect(_draw_status)
	add_child(status_layer)

func sparkle() -> void:
	sparkle_elapsed = 0.0

func _process(delta: float) -> void:
	flash = maxf(0.0, flash-delta)
	holo_build = move_toward(holo_build, holo_goal, delta * 1.8)
	if pose != "":
		pose_t += delta
		if pose_t >= float(POSE_LENGTH[pose]):
			pose = ""
	clock += delta
	if sparkle_elapsed >= 0.0:
		sparkle_elapsed += delta
		if sparkle_elapsed > 1.0:
			sparkle_elapsed = -1.0
	if sword_attack_elapsed >= 0.0:
		sword_attack_elapsed += delta
		if sword_attack_elapsed >= SwordMotion.duration(sword_attack_facing):
			sword_attack_elapsed = -1.0
			z_index = 2
	if hammer_attack_elapsed >= 0.0:
		hammer_attack_elapsed += delta
		if hammer_attack_elapsed >= hammer_duration():
			hammer_attack_elapsed = -1.0
			z_index = 2
	if hit_elapsed >= 0.0:
		hit_elapsed += delta
		if hit_elapsed >= HIT_TIME:
			hit_elapsed = -1.0
	if material is ShaderMaterial:
		(material as ShaderMaterial).set_shader_parameter("white", 1.0 if hit_elapsed >= 0.0 and hit_elapsed < HIT_WHITE else 0.0)
	if anim != "":
		anim_time += delta
		# Death holds its last frame; the others drop back to the idle loop.
		if anim_time >= anim_length(anim) and anim != "death":
			anim = ""
	queue_redraw()
	status_layer.queue_redraw()

func _sheets() -> Dictionary:
	return KING_SHEETS if kind == "king" else FORTRESS_SHEETS

## Start a one-shot sheet animation; a death is never interrupted.
func play_anim(name: String) -> void:
	if anim == "death" or not _sheets().has(name):
		return
	anim = name
	anim_time = 0.0

func anim_length(name: String) -> float:
	var sheet: Array = _sheets().get(name, [null, 1, 1.0])
	return sheet[1] / sheet[2]

func anim_done() -> bool:
	return anim == "" or anim_time >= anim_length(anim)

## One frame of a sheet: a one-shot plays once, the idle loops.
func _sheet_frame(sheet: Array, time: float, once: bool) -> Rect2:
	var frame := int(time * sheet[2])
	frame = mini(frame, sheet[1] - 1) if once else frame % int(sheet[1])
	return Rect2(frame * 256, 0, 256, 256)

## `toward`: the struck tile's direction; the strike lunges that way so the head
## comes down on it.
func play_hammer_attack(toward: Vector2 = Vector2.RIGHT) -> void:
	hammer_attack_elapsed = 0.0
	hammer_lunge = toward.normalized() * 22.0
	z_index = 3
	queue_redraw()

## How far along the strike's lunge is, `t` seconds into the strike (eased out).
static func _lunge_at(t: float) -> float:
	var k := clampf(t / HAMMER_LUNGE, 0.0, 1.0)
	return 1.0 - (1.0 - k) * (1.0 - k)

func play_sword_attack(direction: int) -> void:
	sword_attack_facing = clampi(direction, 0, 3)
	sword_attack_elapsed = 0.0
	z_index = 3
	queue_redraw()

func sword_attack_duration() -> float:
	return SwordMotion.duration(sword_attack_facing)

func sword_impact_time() -> float:
	return SwordMotion.impact_time(sword_attack_facing)

## Taking damage: a white blink, then red, while the body is knocked back along the
## blow, squashes and wobbles; bigger units are knocked harder.
const HIT_TIME := 0.3
const HIT_WHITE := 0.075
const HIT_SHADER := preload("res://scripts/fx/hit_flash.gdshader")
func play_hit_reaction(direction: Vector2) -> void:
	hit_direction = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	hit_elapsed = 0.0
	flash = HIT_TIME
	if material == null:
		var shader_material := ShaderMaterial.new()
		shader_material.shader = HIT_SHADER
		material = shader_material

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

## クロス短剣: the colour of the dagger just powered up by the other (clear when there is none).
var aura := Color(0, 0, 0, 0)

## A glow and rising sparks round the character, in the powered-up dagger's colour.
func _draw_aura() -> void:
	pass  # the glow now sits on the tile and the weapon slot, not on the character

## A frame that burns (flames licking along its top and bottom edges) or, for a blue colour,
## crackles (short bright arcs running round its border). Used on the powered-up dagger's slot
## and the player's tile.
static func draw_frame_fire(canvas: CanvasItem, rect: Rect2, color: Color) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var beat := 0.5 + 0.5 * sin(t * 8.0)
	canvas.draw_rect(rect, Color(color, 0.12 + 0.1 * beat))
	canvas.draw_rect(rect, Color(color.lightened(0.2), 0.9), false, 3.0)
	if color.b > color.r + 0.2:
		# Crackling: a jittery bright line round the border, restarting often.
		var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y), rect.position]
		var ring := PackedVector2Array()
		for side in range(4):
			var from: Vector2 = corners[side]
			var to: Vector2 = corners[side + 1]
			var steps := maxi(int(from.distance_to(to) / 9.0), 2)
			for k in range(steps):
				var f := float(k) / float(steps)
				var at := from.lerp(to, f)
				var normal := (to - from).orthogonal().normalized()
				ring.append(at + normal * sin(t * 37.0 + float(k) * 4.1 + float(side) * 1.7) * 4.0)
		ring.append(ring[0])
		canvas.draw_polyline(ring, Color(color, 0.55), 6.0)
		canvas.draw_polyline(ring, Color(0.88, 0.97, 1.0, 0.95), 2.0)
		for k in range(3):
			var phase := fposmod(t * 2.0 + float(k) * 0.33, 1.0)
			var from := rect.position + Vector2(rect.size.x * fposmod(float(k) * 0.37 + t * 0.2, 1.0), 0.0)
			var tip := from + Vector2(sin(t * 20.0 + float(k)) * 6.0, -10.0 - 8.0 * phase)
			canvas.draw_line(from, tip, Color(0.88, 0.97, 1.0, 1.0 - phase), 2.0)
	else:
		var across := maxi(int(rect.size.x / 18.0), 3)
		draw_flames(canvas, Vector2(rect.get_center().x, rect.position.y + 4.0), rect.size.x, minf(rect.size.y * 0.35, 26.0), color, across, false)
		draw_flames(canvas, Vector2(rect.get_center().x, rect.end.y - 1.0), rect.size.x, minf(rect.size.y * 0.3, 20.0), color, across, false)

## A flame (or, for a blue colour, crackling lightning) rising from a base line: curved
## tongues in three layers that sway and flicker, with embers drifting up. `origin` is the
## middle of the base, `width` how far the base spreads, `height` the tallest flame.
static func draw_flames(canvas: CanvasItem, origin: Vector2, width: float, height: float, color: Color, tongues := 6, embers := true) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var electric := color.b > color.r + 0.2
	if electric:
		for i in range(maxi(tongues - 1, 2)):
			var x0 := origin.x + (float(i) / float(maxi(tongues - 2, 1)) - 0.5) * width
			var points := PackedVector2Array()
			var steps := 7
			var reach := height * (0.55 + 0.4 * absf(sin(t * 9.0 + float(i) * 2.3)))
			for k in range(steps + 1):
				var f := float(k) / float(steps)
				var jag := 0.0 if k == 0 else sin(t * 23.0 + float(i) * 5.0 + float(k) * 2.9) * 10.0 * f
				points.append(Vector2(x0 + jag, origin.y - f * reach))
			canvas.draw_polyline(points, Color(color, 0.5), 7.0)
			canvas.draw_polyline(points, Color(0.88, 0.97, 1.0, 0.95), 2.5)
	else:
		for i in range(tongues):
			var f := float(i) / float(tongues - 1)
			var x0 := origin.x + (f - 0.5) * width
			# The middle flames are tallest; each one breathes in its own time.
			var tall := height * (0.45 + 0.55 * sin(f * PI)) * (0.8 + 0.2 * sin(t * 8.0 + float(i) * 2.1))
			var wide := width / float(tongues) * 0.95
			for layer in range(3):
				var shrink := 1.0 - 0.28 * float(layer)
				var shade: Color = [color, color.lightened(0.35), Color(1.0, 0.95, 0.6)][layer]
				var alpha: float = [0.5, 0.65, 0.85][layer]
				var left := PackedVector2Array()
				var right := PackedVector2Array()
				var steps := 10
				for k in range(steps + 1):
					var h := float(k) / float(steps)
					# A teardrop: full at the foot, narrowing to a curling tip.
					var half := wide * 0.5 * shrink * pow(1.0 - h, 0.7) * (0.6 + 0.4 * sin(minf(h * 3.0, 1.0) * PI * 0.5 + 0.6))
					var sway := sin(t * 6.0 + float(i) * 1.7 + h * 3.2) * wide * 0.45 * h * h
					var y := origin.y - h * tall * shrink
					left.append(Vector2(x0 + sway - half, y))
					right.append(Vector2(x0 + sway + half, y))
				right.reverse()
				var outline := PackedVector2Array()
				outline.append_array(left)
				outline.append_array(right)
				if Geometry2D.triangulate_polygon(outline).size() >= 3:
					canvas.draw_colored_polygon(outline, Color(shade, alpha))
	for i in range(12 if embers else 0):
		var phase := fposmod(t * 0.9 + float(i) * 0.083, 1.0)
		var x := origin.x + sin(float(i) * 2.4 + t * 1.3) * width * 0.5
		var y := origin.y - phase * height * 1.15
		canvas.draw_circle(Vector2(x, y), 2.8 * (1.0 - phase) + 0.8, Color(color.lightened(0.55), 0.9 * (1.0 - phase)))

func _draw() -> void:
	if aura.a > 0.0 and kind == "player":
		_draw_aura()
	if span > 2:
		draw_circle(Vector2(0,76),52,Color(0,0,0,0.3))
	elif kind == "storm_shark":
		pass  # a hologram casts no shadow
	elif span > 1:
		draw_circle(Vector2(0,44),30,Color(0,0,0,0.3))
	elif kind == "wolf":
		# The wolf is long and low: a flat shadow under its paws.
		draw_set_transform(Vector2(0,26),0.0,Vector2(1,0.3))
		draw_circle(Vector2.ZERO,27,Color(0,0,0,0.35))
		draw_set_transform(Vector2.ZERO)
	else:
		draw_circle(Vector2(0,22),19,Color(0,0,0,0.35))
	if hit_elapsed >= 0.0:
		var k := hit_elapsed / HIT_TIME
		var shove := sin(minf(k * 2.2, 1.0) * PI) * (6.0 + 3.0 * span)
		var wobble := sin(k * PI * 6.0) * (1.0 - k) * (2.0 + span)
		var squash := 0.14 * sin(minf(k * 3.0, 1.0) * PI)
		_hit_off = (hit_direction * shove + hit_direction.orthogonal() * wobble).round()
		_hit_scale = Vector2(1.0 + squash, 1.0 - squash)
		draw_set_transform(_hit_off, 0.0, _hit_scale)
	else:
		_hit_off = Vector2.ZERO
		_hit_scale = Vector2.ONE
	var tint := Color("ff997e") if flash > 0 else Color.WHITE
	if hit_elapsed >= HIT_WHITE:
		# After the white blink the body burns red and cools back.
		tint = Color(1.0, 0.38, 0.34).lerp(Color.WHITE, (hit_elapsed - HIT_WHITE) / (HIT_TIME - HIT_WHITE))
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
		elif weapon_row == 0:
			var frame := 0
			var lunge := Vector2.ZERO
			var base := Vector2(0, -hop_height)
			if hammer_attack_elapsed >= 0.0:
				frame = 1 if hammer_attack_elapsed < HAMMER_WINDUP else 2
			if frame == 2:
				# The lunge is quick but not instant: a fast glide toward the tile, with
				# afterimages trailing behind it (and the raised pose fading where it stood).
				var raw := hammer_attack_elapsed - HAMMER_WINDUP
				var t := _strike_time(raw)
				lunge = hammer_lunge * _lunge_at(t)
				# The hit-stop: frozen on contact and lit up.
				if raw >= HAMMER_LUNGE and raw < HAMMER_LUNGE + HAMMER_HITSTOP:
					tint = Color(1.9, 1.85, 1.6, tint.a)
				var fade := clampf(1.0 - t / 0.22, 0.0, 1.0)
				if t < 0.12:
					draw_hammer_pose(self, 1, base, Color(0.75, 0.95, 1.0, 0.45 * (1.0 - t / 0.12)))
				for k in [3, 2, 1]:
					var back: float = t - k * 0.022
					if back > 0.0:
						draw_hammer_pose(self, 2, base + hammer_lunge * _lunge_at(back), Color(0.7, 0.93, 1.0, (0.55 - k * 0.13) * fade))
			draw_hammer_pose(self, frame, base + lunge, tint)
		else:
			var source := Rect2(facing*PLAYER_ATLAS_CELL,weapon_row*PLAYER_ATLAS_CELL,PLAYER_ATLAS_CELL,PLAYER_ATLAS_CELL)
			_draw_player_sprite(PLAYER_ATLAS, source, weapon_row == 2 and facing == 2, tint)
	elif kind == "acorn":
		draw_texture_rect(ACORN,Rect2(-30,-35,60,60),false,tint)
	elif kind == "wall":
		draw_texture_rect(WALL,Rect2(-32,-38,64,64),false,tint)
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
		draw_texture_rect(HOLY_SPIRIT,Rect2(Vector2(-76,-84+bob),Vector2.ONE*152),false,tint)
	elif kind == "guardian":
		# 守護神: a slow, stately float.
		var bob := sin(Time.get_ticks_msec() / 1000.0 * 1.6) * 3.0
		draw_circle(Vector2(0,-8),62,Color(0.75,0.88,1.0,0.12))
		draw_texture_rect(GUARDIAN,Rect2(Vector2(-78,-92+bob),Vector2.ONE*156),false,tint)
	elif kind == "holy_knight":
		draw_texture_rect_region(HOLY_KNIGHT,Rect2(-32,-36,64,64),Rect2(facing*128,0,128,128),tint)
	elif kind == "miner":
		_draw_drone(tint)
	elif kind in ["cavalry","horse"]:
		_draw_cavalry(tint)
	elif kind == "storm_shark":
		_draw_shark(tint)
	elif kind in BOSS_KINDS:
		draw_boss(self, kind, facing, braced, tint, 1.0, reel)
	elif SOLDIER_SHEETS.has(kind):
		draw_soldier(self, kind, facing, alt_row, tint)
	elif kind in ["gold", "silver"]:
		draw_general(self, kind, tint)
	elif kind == "king":
		# The Prison King on his throne: idle (or rage) loop, one-shots on top.
		var enraged := hp <= 5 and anim != "death"
		if enraged:
			# A red heat haze behind the enraged king.
			draw_circle(Vector2(0,-8),98+sin(clock*6.0)*6.0,Color(1,0.1,0.1,0.14))
		var sheet: Array = KING_SHEETS[anim] if anim != "" else KING_SHEETS["rage" if enraged else "idle"]
		draw_texture_rect_region(sheet[0],Rect2(-116,-136,232,232),_sheet_frame(sheet,anim_time if anim != "" else clock,anim != ""),tint)
	elif kind == "fortress":
		if anim == "spawn":
			var sheet: Array = FORTRESS_SHEETS["spawn"]
			draw_texture_rect_region(sheet[0],Rect2(-72,-84,144,144),_sheet_frame(sheet,anim_time,true),tint)
		elif FORTRESS_DAMAGED.has(hp):
			draw_texture_rect(FORTRESS_DAMAGED[hp],Rect2(-72,-84,144,144),false,tint)
		else:
			var sheet: Array = FORTRESS_SHEETS["idle"]
			draw_texture_rect_region(sheet[0],Rect2(-72,-84,144,144),_sheet_frame(sheet,clock,false),tint)
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

## The storm shark with its current move: a lunge and a snapping jaw, a nose-down dive, a
## leap out of the shadow.
func _draw_shark(tint: Color) -> void:
	var flip := facing == 1
	var s := -1.0 if flip else 1.0
	var off := Vector2.ZERO
	var rot := 0.0
	var jaw := 0.0
	var dir := Vector2([Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT][clampi(facing, 0, 3)])
	if pose == "bite":
		var k := clampf(pose_t / float(POSE_LENGTH["bite"]), 0.0, 1.0)
		off = dir * sin(k * PI) * 18.0
		jaw = clampf(k / 0.3, 0.0, 1.0) if k < 0.55 else clampf((0.75 - k) / 0.2, 0.0, 1.0)
	elif pose == "dive":
		var k := clampf(pose_t / float(POSE_LENGTH["dive"]), 0.0, 1.0)
		rot = -s * k * 0.8
		off = Vector2(0, k * 34.0)
		jaw = sin(minf(k * 1.5, 1.0) * PI) * 0.5
	elif pose == "surface":
		var k := clampf(pose_t / float(POSE_LENGTH["surface"]), 0.0, 1.0)
		rot = s * (1.0 - k) * 0.6
		off = Vector2(0, (1.0 - k) * 40.0 - sin(k * PI) * 34.0)
		jaw = sin(clampf(k * 1.3, 0.0, 1.0) * PI)
	var base := Transform2D(rot, _hit_scale, 0.0, _hit_off + off)
	draw_set_transform_matrix(base)
	draw_hologram(self, STORM_SHARK, Rect2(Vector2(-78, -78), Vector2.ONE * 156), flip, tint, holo_build, jaw, base)
	draw_set_transform_matrix(Transform2D.IDENTITY)

## A hologram: translucent cyan with a ghost of red and blue either side, scan lines drifting
## down it, a flicker and now and then a sideways glitch. `build` (0-1) is how much of it is
## projected: it is rebuilt from the top down (and dissolves from the bottom up). `jaw` (0-1)
## opens the lower jaw of a left-facing picture; then `outer` is the transform the canvas
## already has (the jaw turns about its hinge on top of it).
static func draw_hologram(canvas: CanvasItem, texture: Texture2D, rect: Rect2, flip: bool, tint: Color, build: float, jaw: float = 0.0, outer: Transform2D = Transform2D.IDENTITY) -> void:
	if build <= 0.01:
		return
	var t: float = Time.get_ticks_msec() / 1000.0
	var alpha := (0.78 + 0.1 * sin(t * 11.0)) * tint.a
	var glitch := Vector2(rect.size.x * 0.03 * sin(t * 37.0), 0) if int(t * 6.0) % 7 == 0 else Vector2.ZERO
	var base := Color(0.72, 1.0, 1.0, alpha) * Color(tint.r, tint.g * 0.4 + 0.6, tint.b * 0.4 + 0.6, 1.0)
	var left := minf(rect.position.x, rect.end.x)
	var shown := rect.size.y * build
	if jaw > 0.01 and build > 0.99:
		var tex := texture.get_size()
		var k := rect.size / tex
		var half := rect.size / 2.0
		var local := outer * Transform2D(0.0, Vector2(-1.0 if flip else 1.0, 1.0), 0.0, rect.get_center() + glitch)
		var cut := Vector2(tex.x * 0.37, tex.y * 0.64)
		var hinge := -half + Vector2(cut.x * k.x, cut.y * k.y)
		for layer in [[Vector2(-3, 0), Color(1.0, 0.25, 0.4, alpha * 0.28)], [Vector2(3, 0), Color(0.25, 0.5, 1.0, alpha * 0.28)], [Vector2.ZERO, base]]:
			var shift: Vector2 = layer[0]
			var color: Color = layer[1]
			canvas.draw_set_transform_matrix(local * Transform2D(0.0, shift))
			canvas.draw_texture_rect_region(texture, Rect2(-half, Vector2(rect.size.x, cut.y * k.y)), Rect2(0, 0, tex.x, cut.y), color)
			canvas.draw_texture_rect_region(texture, Rect2(Vector2(hinge.x, hinge.y), Vector2((tex.x - cut.x) * k.x, (tex.y - cut.y) * k.y)), Rect2(cut.x, cut.y, tex.x - cut.x, tex.y - cut.y), color)
			canvas.draw_set_transform_matrix(local * Transform2D(0.0, shift) * Transform2D(-jaw * 0.5, hinge))
			canvas.draw_texture_rect_region(texture, Rect2(Vector2(-cut.x * k.x, 0), Vector2(cut.x * k.x, (tex.y - cut.y) * k.y)), Rect2(0, cut.y, cut.x, tex.y - cut.y), color)
		canvas.draw_set_transform_matrix(outer)
		for row in range(0, int(rect.size.y), 5):
			var y := rect.position.y + row + fposmod(t * 22.0, 5.0)
			canvas.draw_line(Vector2(left, y), Vector2(left + rect.size.x, y), Color(0.7, 1.0, 1.0, 0.16), 1)
		return
	# Only the top `build` of the picture is there; a bright line marks the edge of the projection.
	var source_h := texture.get_height() * build
	var region := Rect2(0, 0, texture.get_width(), source_h)
	var dest := Rect2(rect.position + glitch, Vector2(rect.size.x, shown))
	if flip:
		dest = Rect2(dest.position + Vector2(dest.size.x, 0), Vector2(-dest.size.x, dest.size.y))
	canvas.draw_texture_rect_region(texture, Rect2(dest.position + Vector2(-3, 0), dest.size), region, Color(1.0, 0.25, 0.4, alpha * 0.28))
	canvas.draw_texture_rect_region(texture, Rect2(dest.position + Vector2(3, 0), dest.size), region, Color(0.25, 0.5, 1.0, alpha * 0.28))
	canvas.draw_texture_rect_region(texture, dest, region, base)
	for k in range(0, int(shown), 5):
		var y := rect.position.y + k + fposmod(t * 22.0, 5.0)
		if y < rect.position.y + shown:
			canvas.draw_line(Vector2(left, y), Vector2(left + rect.size.x, y), Color(0.7, 1.0, 1.0, 0.16), 1)
	if build < 0.99:
		var edge := rect.position.y + shown
		canvas.draw_line(Vector2(left, edge), Vector2(left + rect.size.x, edge), Color(0.9, 1.0, 1.0, 0.9), 2)

## Sheets use the game facing order: up, right, down, left.
static func draw_boss(canvas: CanvasItem, boss: String, direction: int, red: bool, tint: Color = Color.WHITE, factor: float = 1.0, reel_value: int = 0) -> void:
	match boss:
		"slot":
			# Always drawn facing front; the reel picks the frame (row-major, 8th = spinning).
			var frame: int = 7 if reel_value <= 0 else reel_value - 1
			canvas.draw_texture_rect_region(ROTORICK_ATLAS, Rect2(Vector2(-86,-94)*factor, Vector2.ONE*172*factor), Rect2((frame % 4)*112, (frame / 4)*112, 112, 112), tint)
		"shadow":
			# A flickering purple hologram: translucent, with scan lines.
			var t: float = Time.get_ticks_msec() / 1000.0
			var alpha := 0.5 + 0.12 * sin(t * 9.0)
			var jitter := Vector2(2.0 * sin(t * 23.0), 0) if int(t * 7) % 5 == 0 else Vector2.ZERO
			var rect := Rect2((Vector2(-86,-94) + jitter) * factor, Vector2.ONE * 172 * factor)
			canvas.draw_texture_rect_region(ROTORICK_SHADOW, rect, Rect2(224, 0, 112, 112), Color(0.85, 0.6, 1.0, alpha))
			for k in range(0, int(rect.size.y), 6):
				canvas.draw_line(Vector2(rect.position.x + 20 * factor, rect.position.y + k), Vector2(rect.end.x - 20 * factor, rect.position.y + k), Color(0.75, 0.45, 1.0, 0.12), 1)
		"rook":
			if red:
				# Braced, it crouches low in its frame: crop to the crouch and fill its 2x2
				# (a little taller than drawn) so it still reads as two tiles by two.
				var crop: Rect2 = [Rect2(3,25,50,31), Rect2(5,23,46,33), Rect2(4,25,47,31), Rect2(5,23,46,33)][direction]
				crop.position += Vector2(direction*56, 56)
				canvas.draw_texture_rect_region(ROOK_ATLAS, Rect2(Vector2(-60,-42)*factor, Vector2(120,106)*factor), crop, tint)
			else:
				canvas.draw_texture_rect_region(ROOK_ATLAS, Rect2(Vector2(-76,-84)*factor, Vector2.ONE*152*factor), Rect2(direction*56, 0, 56, 56), tint)
		"storm_shark":
			draw_hologram(canvas, STORM_SHARK, Rect2(Vector2(-78,-78)*factor, Vector2.ONE*156*factor), direction == 1, tint, 1.0)
		"prison":
			canvas.draw_texture_rect_region(PRISON_ATLAS, Rect2(Vector2(-76,-82)*factor, Vector2.ONE*152*factor), Rect2(direction*224, 0, 224, 224), tint)
		"executioner":
			canvas.draw_texture_rect_region(EXECUTIONER_ATLAS, Rect2(Vector2(-32,-38)*factor, Vector2.ONE*64*factor), Rect2(direction*160, 0, 160, 160), tint)

static func draw_soldier(canvas: CanvasItem, soldier: String, direction: int, alt: bool, tint: Color = Color.WHITE, factor: float = 1.0) -> void:
	var entry: Array = SOLDIER_SHEETS[soldier]
	var sheet: Texture2D = entry[0]
	var side: float = entry[1] * factor
	var row := 1 if alt and sheet.get_height() > 128 else 0
	canvas.draw_texture_rect_region(sheet, Rect2(Vector2(-side / 2, 28 * factor - side), Vector2.ONE * side), Rect2(direction * 128, row * 128, 128, 128), tint)

func _draw_status() -> void:
	if kind == "storm_shark" and holo_build < 0.6:
		return
	var max_hp := 5 if kind in ["player", "wall"] else 10 if kind == "king" else 3 if kind == "fortress" else 7 if kind == "slot" else 8 if kind == "storm_shark" else 3 if kind == "rook" else 2 if kind in ["heavy","horse","executioner","analyst","gold"] else 1
	# A unit that grew past its usual HP (the glutton after a meal) shows every heart.
	max_hp = maxi(max_hp, hp)
	var total := max_hp*11.0-1.0
	var grow := 32.0*(span-1)
	if kind == "slot":
		_draw_rotorick_arrows()
	var heart_y := -98.0 if kind == "slot" else -112.0 if kind == "king" else -52.0 if hearts_above else 29+grow
	for i in range(max_hp):
		var size := 11.0
		if sparkle_elapsed >= 0.0 and i == hp - 1:
			# The new heart pops in.
			size *= 1.0 + 0.8 * maxf(0.0, 1.0 - sparkle_elapsed / 0.25)
		_draw_heart(Vector2(-total/2+i*11+5,heart_y),size,Color("ff5b62"),i < hp)
	if sparkle_elapsed >= 0.0:
		_draw_sparkles(Vector2(-total/2+(hp-1)*11+5,heart_y))
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
	if frozen > 0:
		# 氷結: encased in a block of ice, with a snowflake badge and the turns left.
		var half := 32.0 + grow
		status_layer.draw_texture_rect(FROZEN_OVERLAY,Rect2(Vector2(-half,-half-6),Vector2(half*2,half*2)),false,Color(1,1,1,0.62))
		var badge := Vector2(-half+2,-half-2)
		status_layer.draw_rect(Rect2(badge,Vector2(26,20)),Color(0.05,0.12,0.2,0.92))
		for k in 3:
			var arm := Vector2.from_angle(k*PI/3)*6
			status_layer.draw_line(badge+Vector2(8,10)-arm,badge+Vector2(8,10)+arm,Color("bff0ff"),2)
		status_layer.draw_string(BADGE_FONT,badge+Vector2(15,16),str(frozen),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("e8fbff"))
	if time_stopped and frozen <= 0:
		var clock_at := Vector2(-22-grow,-26-grow)
		status_layer.draw_circle(clock_at,10,Color(0.12,0.09,0.03,0.92))
		status_layer.draw_arc(clock_at,10,0,TAU,20,Color("ffcf52"),2,true)
		status_layer.draw_line(clock_at,clock_at+Vector2(0,-7),Color("ffcf52"),2)
		status_layer.draw_line(clock_at,clock_at+Vector2(5,2),Color("ffcf52"),2)
	if charge_warning:
		var at := Vector2(10+grow,-32-grow)
		status_layer.draw_rect(Rect2(at,Vector2(22,28)), Color("191e29"))
		status_layer.draw_rect(Rect2(at+Vector2(2,2),Vector2(18,24)), Color("ffbd59"))
		status_layer.draw_rect(Rect2(at+Vector2(8,5),Vector2(6,12)), Color("351e20"))
		status_layer.draw_rect(Rect2(at+Vector2(8,20),Vector2(6,4)), Color("351e20"))

## キラン・キラン・キラン: three four-pointed stars flash in turn around the new heart,
## and "HP+1" floats up.
func _draw_sparkles(heart: Vector2) -> void:
	var gold := Color("fff2a8")
	for k in 3:
		var t := sparkle_elapsed - k * 0.13
		if t < 0.0 or t > 0.3:
			continue
		var size := sin(t / 0.3 * PI) * 9.0
		var at: Vector2 = heart + [Vector2(-12, -9), Vector2(11, -13), Vector2(15, 5)][k]
		status_layer.draw_line(at - Vector2(size, 0), at + Vector2(size, 0), gold, 2)
		status_layer.draw_line(at - Vector2(0, size * 1.3), at + Vector2(0, size * 1.3), gold, 2)
		status_layer.draw_circle(at, size * 0.35, Color.WHITE)
	var rise := clampf(sparkle_elapsed / 1.0, 0.0, 1.0)
	var alpha := 1.0 - maxf(0.0, (rise - 0.6) / 0.4)
	for offset in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		status_layer.draw_string(BADGE_FONT, heart + Vector2(-16, -14 - rise * 18) + offset, "HP+1", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.2, 0.08, 0, alpha))
	status_layer.draw_string(BADGE_FONT, heart + Vector2(-16, -14 - rise * 18), "HP+1", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(gold, alpha))

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

## One hammer pose with the point between its feet at `feet` (the other player
## sprites stand with their feet 21px below the tile centre), `factor` times the
## usual size.
static func draw_hammer_pose(canvas: CanvasItem, frame: int, offset: Vector2 = Vector2.ZERO, tint: Color = Color.WHITE, factor: float = 1.0, feet: Vector2 = Vector2(0, 21)) -> void:
	var texture: Texture2D = HAMMER_FRAMES[frame]
	var scale := HAMMER_SCALE * factor
	var anchor: Vector2 = HAMMER_ANCHORS[frame]
	canvas.draw_texture_rect(texture, Rect2(feet * factor + offset - anchor * scale, texture.get_size() * scale), false, tint)

func _draw_player_sprite(texture: Texture2D, source: Rect2, enlarge_down_sword: bool, tint: Color) -> void:
	var destination := Rect2(-32, -37-hop_height, 64, 64)
	if enlarge_down_sword:
		# Keep the feet on their original baseline while giving the generated front-facing pose more presence.
		destination = Rect2(-38, -49-hop_height*1.1875, 76, 76)
	draw_texture_rect_region(texture, destination, source, tint)
