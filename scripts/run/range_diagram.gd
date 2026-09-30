extends Control

const Units = preload("res://scripts/unit_view.gd")
var offsets: Array[Vector2i] = []
var accent := Color("2bdcc8")
## Tiles the current loadout already reaches: drawn faintly, so an offer shows what it adds.
var context: Array[Vector2i] = []
## Directions a sliding weapon keeps going in (drawn as arrows past its tiles).
var slides: Array = []
## Hammers: the tiles the blow also reaches when it strikes the tile to the right
## (hatched), and the player is drawn holding a hammer.
var echo: Array[Vector2i] = []
var hammer := false
const ECHO := Color("ffa04a")

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
	var count := span(offsets + context + echo)
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
			var echoed := echo.has(offset)
			var fill := Color("172627")
			var border := Color("3d5753")
			if active and known:
				# Already reachable with the current loadout.
				fill = Color(accent,0.12)
				border = Color(accent,0.45)
			elif active:
				fill = Color(accent,0.3)
				border = accent
			elif known:
				fill = Color("25393a")
				border = Color("4b6663")
			if echoed and not active:
				fill = Color(ECHO,0.16)
				border = Color(ECHO,0.8)
			draw_rect(rect,fill)
			if echoed:
				# Hatched: the blow spreads here too.
				var lines := 4
				for k in range(1, lines * 2):
					var t := float(k) / lines
					var a := rect.position + Vector2(minf(t,1.0), maxf(t-1.0,0.0)) * rect.size.x
					var b := rect.position + Vector2(maxf(t-1.0,0.0), minf(t,1.0)) * rect.size.x
					draw_line(a, b, Color(ECHO,0.55), maxf(1.0, step*0.05))
			draw_rect(rect,border,false,2 if step >= 20 else 1)
			if offset == Vector2i.ZERO:
				if hammer:
					Units.draw_hammer_pose(self, 0, Vector2.ZERO, Color.WHITE, rect.size.x/64.0, rect.get_center()/(rect.size.x/64.0) + Vector2(0, 21))
				else:
					var cell := Units.PLAYER_ATLAS_CELL
					draw_texture_rect_region(Units.PLAYER_ATLAS,rect,Rect2(cell,2*cell,cell,cell))
			elif active:
				draw_circle(rect.get_center(),maxf(2,step*0.12),Color(accent,0.5) if known else accent)
			elif known:
				draw_circle(rect.get_center(),maxf(1.5,step*0.08),Color("6f8a86"))
	# Sliding weapons: an arrow on the outermost tile of each line shows it keeps going.
	for direction in slides:
		var far: Vector2i = direction * half
		var tip := origin + (Vector2(far + Vector2i(half, half)) + Vector2.ONE * 0.5) * step + Vector2(direction) * step * 0.3
		var back := tip - Vector2(direction).normalized() * step * 0.5
		var side := Vector2(-direction.y, direction.x).normalized() * step * 0.22
		draw_line(back, tip, accent, maxf(2, step * 0.1))
		draw_colored_polygon(PackedVector2Array([tip + Vector2(direction).normalized() * step * 0.12, tip - side, tip + side]), accent)
