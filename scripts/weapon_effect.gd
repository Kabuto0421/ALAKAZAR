extends Node2D

const SHEETS = [
	preload("res://assets/sprites/effects/weapons/hammer-move-attack.png"),
	preload("res://assets/sprites/effects/weapons/sword-move-attack.png"),
	preload("res://assets/sprites/effects/weapons/axe-move-attack.png"),
]
const MOVE_DURATION = [0.18,0.16,0.22]
const ATTACK_DURATION = [0.20,0.18,0.22]
const MOVE_SIZE = [48.0,44.0,52.0]
const ATTACK_SIZE = [72.0,78.0,80.0]

var weapon := 0
var attacking := false
var origin := Vector2.ZERO
var destination := Vector2.ZERO
var elapsed := 0.0

func duration() -> float:
	return ATTACK_DURATION[weapon] if attacking else MOVE_DURATION[weapon]

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 3 if attacking else 1
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= duration():
		queue_free()
	else:
		queue_redraw()

func _draw() -> void:
	var progress := clampf(elapsed/duration(),0.0,0.999)
	var frame := mini(int(progress*4),3)
	var sheet: Texture2D = SHEETS[weapon]
	# Generated originals have a half-pixel cell size; keep their full alpha.
	var cell := Vector2(sheet.get_width()/4.0,sheet.get_height()/2.0)
	var source := Rect2(Vector2(frame,1 if attacking else 0)*cell,cell)
	var direction := (destination-origin).normalized()
	var side: float = ATTACK_SIZE[weapon] if attacking else MOVE_SIZE[weapon]
	var anchor := Vector2(0.5,0.7)
	var at := destination+Vector2(0,8 if attacking and weapon == 0 else -8)
	var angle := 0.0
	var opacity := 0.9 if attacking else 0.55
	if attacking:
		if weapon == 1:
			angle = direction.angle()+PI/2
			anchor = Vector2(0.5,0.55)
		elif weapon == 2:
			angle = direction.angle()-PI/2
			anchor = Vector2(0.65,0.72)
	else:
		at = (origin if frame < 2 else destination)+Vector2(0,21)
		anchor = Vector2(0.5,0.8)
		if weapon == 1:
			at = origin.lerp(destination,1.0-pow(1.0-progress,2))+Vector2(0,12)-direction*12
			angle = direction.angle()+PI/2
			anchor = Vector2(0.5,0.6)
	opacity *= 1.0-smoothstep(0.68,1.0,progress)
	draw_set_transform(at,angle)
	draw_texture_rect_region(sheet,Rect2(-anchor*side,Vector2.ONE*side),source,Color(1,1,1,opacity))
	draw_set_transform(Vector2.ZERO)
