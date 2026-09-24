@tool
extends Node2D

const CELL := 64.0
const SIZE := 6

static func cell_at(point: Vector2) -> Vector2i:
	return Vector2i(clampi(floori(point.x/CELL),0,SIZE-1),clampi(floori(point.y/CELL),0,SIZE-1))

static func cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell)+Vector2.ONE*0.5)*CELL

func _draw() -> void:
	for y in range(SIZE):
		for x in range(SIZE):
			var rect := Rect2(Vector2(x,y)*CELL,Vector2.ONE*CELL)
			draw_rect(rect,Color("252820"))
			draw_rect(rect.grow(-3),Color("34352b"),false,2)
