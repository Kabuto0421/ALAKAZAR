extends Node2D

const ACORN = preload("res://assets/sprites/spirits/acorn_fairy.png")
const PLAYER_ATLAS = preload("res://assets/sprites/adventurer_weapon_directions_64.png")
const SWORD_ATTACK_ATLAS = preload("res://assets/sprites/attacks/sword-attack-directions.png")
const SwordMotion = preload("res://scripts/animation/sword_motion.gd")
const ENEMY_ATLAS = preload("res://assets/sprites/enemies/police_officer_directions_28.png")
const CAVALRY_ATLAS = preload("res://assets/sprites/enemies/cavalry_hover_directions_28.png")
const PLAYER_ATLAS_CELL := 362.0
const SWORD_ATTACK_CELL := 480.0
var kind := "player"
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

func _draw() -> void:
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
	elif kind == "miner":
		_draw_drone(tint)
	elif kind in ["cavalry","horse"]:
		_draw_cavalry(tint)
	else:
		var side := 64.0 if kind == "heavy" else 56.0
		draw_texture_rect_region(ENEMY_ATLAS,Rect2(-side/2,-side/2-4,side,side),Rect2(facing*28,0,28,28),tint)
		if kind == "heavy":
			draw_rect(Rect2(-23,-6,20,30),Color("16272b"))
			draw_rect(Rect2(-21,-4,16,25),Color("78968f"))
			draw_rect(Rect2(-18,0,10,16),Color("293d42"))
			draw_rect(Rect2(-15,2,4,13),Color("b8d7c5"))
	draw_set_transform(Vector2.ZERO)

func _draw_status() -> void:
	var max_hp := 5 if kind == "player" else 2 if kind in ["heavy","horse"] else 1
	var total := max_hp*11.0-1.0
	for i in range(max_hp):
		_draw_heart(Vector2(-total/2+i*11+5,29),11.0,Color("ff5b62"),i < hp)
	if attack_target:
		for corner in [Vector2(-28,-27),Vector2(28,-27),Vector2(-28,24),Vector2(28,24)]:
			var inward := Vector2(-signf(corner.x),-signf(corner.y))
			status_layer.draw_line(corner,corner+Vector2(inward.x*10,0),Color("ff805a"),3)
			status_layer.draw_line(corner,corner+Vector2(0,inward.y*10),Color("ff805a"),3)
	if charge_warning:
		status_layer.draw_rect(Rect2(10,-32,22,28), Color("191e29"))
		status_layer.draw_rect(Rect2(12,-30,18,24), Color("ffbd59"))
		status_layer.draw_rect(Rect2(18,-27,6,12), Color("351e20"))
		status_layer.draw_rect(Rect2(18,-12,6,4), Color("351e20"))

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
