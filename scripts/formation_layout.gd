@tool
extends Node2D

const CELL := 64.0
const SIZE := 6
@export_range(4, 6) var board_size: int = 6:
	set(value):
		board_size = value
		queue_redraw()
@export var player_start := Vector2i(2,5):
	set(value):
		player_start = value
		queue_redraw()

static func cell_at(point: Vector2, size: int = SIZE) -> Vector2i:
	return Vector2i(clampi(floori(point.x/CELL),0,size-1),clampi(floori(point.y/CELL),0,size-1))

static func cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell)+Vector2.ONE*0.5)*CELL

func _draw() -> void:
	for y in range(board_size):
		for x in range(board_size):
			var rect := Rect2(Vector2(x,y)*CELL,Vector2.ONE*CELL)
			draw_rect(rect,Color("252820"))
			draw_rect(rect.grow(-3),Color("34352b"),false,2)
	draw_rect(Rect2(Vector2(player_start)*CELL+Vector2(5,5),Vector2.ONE*(CELL-10)),Color("2bdcc8"),false,3)
