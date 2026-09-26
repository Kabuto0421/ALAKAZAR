extends Control

const Units = preload("res://scripts/unit_view.gd")
var offsets: Array[Vector2i] = []
var accent := Color("2bdcc8")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _draw() -> void:
	var step := minf(size.x,size.y)/3.0
	var origin := (size-Vector2.ONE*step*3)/2
	for y in 3:
		for x in 3:
			var offset := Vector2i(x-1,y-1)
			var rect := Rect2(origin+Vector2(x,y)*step+Vector2.ONE*2,Vector2.ONE*(step-4))
			var active := offsets.has(offset)
			draw_rect(rect,Color(accent,0.25) if active else Color("172627"))
			draw_rect(rect,accent if active else Color("3d5753"),false,2)
			if offset == Vector2i.ZERO:
				var cell := Units.PLAYER_ATLAS_CELL
				draw_texture_rect_region(Units.PLAYER_ATLAS,rect,Rect2(cell,2*cell,cell,cell))
			elif active:
				draw_circle(rect.get_center(),maxf(3,step*0.12),accent)
