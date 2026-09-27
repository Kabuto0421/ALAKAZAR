extends Control

const Units = preload("res://scripts/unit_view.gd")
var offsets: Array[Vector2i] = []
var accent := Color("2bdcc8")
## Tiles the current loadout already reaches: drawn faintly, so an offer shows what it adds.
var context: Array[Vector2i] = []
## Tiles that would be lost (a replacement): drawn in red.
var lost: Array[Vector2i] = []
const LOST := Color("ff6b6b")

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
	var count := span(offsets + context)
	var half := count/2
	var step := minf(size.x,size.y)/float(count)
	var origin := (size-Vector2.ONE*step*count)/2
	var inset := maxf(1.0, step*0.06)
	for y in count:
		for x in count:
			var offset := Vector2i(x-half,y-half)
			var rect := Rect2(origin+Vector2(x,y)*step+Vector2.ONE*inset,Vector2.ONE*(step-inset*2))
			var active := offsets.has(offset)
			var known := context.has(offset)
			var fill := Color("172627")
			var border := Color("3d5753")
			if lost.has(offset):
				fill = Color(LOST,0.28)
				border = LOST
			elif active and known:
				# Already reachable with the current loadout.
				fill = Color(accent,0.12)
				border = Color(accent,0.45)
			elif active:
				fill = Color(accent,0.3)
				border = accent
			elif known:
				fill = Color("25393a")
				border = Color("4b6663")
			draw_rect(rect,fill)
			draw_rect(rect,border,false,2 if step >= 20 else 1)
			if offset == Vector2i.ZERO:
				var cell := Units.PLAYER_ATLAS_CELL
				draw_texture_rect_region(Units.PLAYER_ATLAS,rect,Rect2(cell,2*cell,cell,cell))
			elif lost.has(offset):
				draw_circle(rect.get_center(),maxf(2,step*0.12),LOST)
			elif active:
				draw_circle(rect.get_center(),maxf(2,step*0.12),Color(accent,0.5) if known else accent)
			elif known:
				draw_circle(rect.get_center(),maxf(1.5,step*0.08),Color("6f8a86"))
