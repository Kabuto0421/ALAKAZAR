extends Control

const Units = preload("res://scripts/unit_view.gd")
var offsets: Array[Vector2i] = []
var accent := Color("2bdcc8")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

## 3x3 for adjacent patterns, 5x5 when a pattern reaches two tiles away.
static func span(pattern: Array) -> int:
	for offset in pattern:
		if absi(offset.x) > 1 or absi(offset.y) > 1:
			return 5
	return 3

func _draw() -> void:
	var count := span(offsets)
	var half := count/2
	var step := minf(size.x,size.y)/float(count)
	var origin := (size-Vector2.ONE*step*count)/2
	for y in count:
		for x in count:
			var offset := Vector2i(x-half,y-half)
			var rect := Rect2(origin+Vector2(x,y)*step+Vector2.ONE*2,Vector2.ONE*(step-4))
			var active := offsets.has(offset)
			draw_rect(rect,Color(accent,0.25) if active else Color("172627"))
			draw_rect(rect,accent if active else Color("3d5753"),false,2)
			if offset == Vector2i.ZERO:
				var cell := Units.PLAYER_ATLAS_CELL
				draw_texture_rect_region(Units.PLAYER_ATLAS,rect,Rect2(cell,2*cell,cell,cell))
			elif active:
				draw_circle(rect.get_center(),maxf(3,step*0.12),accent)
