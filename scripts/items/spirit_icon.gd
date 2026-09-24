extends Control

var kind := "magic_bolt"
var tint := Color.WHITE
var texture: Texture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if texture != null:
		draw_texture_rect(texture,Rect2(Vector2.ZERO,size),false)

static func paint(canvas: CanvasItem, center: Vector2, sprite: Texture2D, factor: float = 1.0) -> void:
	if sprite == null:
		return
	var side := 64.0 * factor
	canvas.draw_texture_rect(sprite,Rect2(center-Vector2.ONE*side/2,Vector2.ONE*side),false)
