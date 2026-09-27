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

## The yellow "+" badge of an upgraded fairy or forged weapon, hung on a top-right corner.
static func paint_plus(canvas: CanvasItem, corner: Vector2, side: float) -> void:
	var box := Rect2(corner - Vector2(side, 0), Vector2.ONE * side)
	canvas.draw_rect(box, Color("1a1408"))
	canvas.draw_rect(box.grow(-2), Color("ffd35b"))
	var center := box.get_center()
	var arm := (side - 4) * 0.36
	var thick := maxf(2.0, side * 0.18)
	var ink := Color("2a1f05")
	canvas.draw_rect(Rect2(center - Vector2(arm, thick / 2), Vector2(arm * 2, thick)), ink)
	canvas.draw_rect(Rect2(center - Vector2(thick / 2, arm), Vector2(thick, arm * 2)), ink)
