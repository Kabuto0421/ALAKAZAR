extends RefCounted

const Icon = preload("res://scripts/items/spirit_icon.gd")
const Units = preload("res://scripts/unit_view.gd")

# Illustrations are independent of gameplay state and never consume items or AP.
static func paint(canvas: CanvasItem, model: RefCounted, id: String, time: float) -> void:
	var item: Resource = model.item_definition(id)
	var progress := fmod(time,2.8)/2.8
	match id:
		"magic_bolt":
			for i in range(5):
				_tile(canvas,Vector2(872+i*52,269),item.color)
			Icon.paint(canvas,Vector2(872,267),item.icon,0.65)
			_enemy(canvas,Vector2(976,265))
			_enemy(canvas,Vector2(1080,265))
			canvas.draw_line(Vector2(884,285),Vector2(1090,285),item.color,3)
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(1094,285),Vector2(1083,278),Vector2(1083,292)]),item.color)
			canvas.draw_circle(Vector2(884+progress*206,285),5,item.color)
			canvas._text(Vector2(960,245),"−1",18,item.color)
			canvas._text(Vector2(1064,245),"−1",18,item.color)
		"stealth_fairy":
			var center := Vector2(940,268)
			for offset in [Vector2.ZERO,Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
				_tile(canvas,center+offset*28,item.color,25)
			var enemy_pos := Vector2(1080-minf(progress/0.8,1.0)*112,268)
			if progress < 0.8:
				Icon.paint(canvas,center,item.icon,0.65)
				_enemy(canvas,enemy_pos)
			else:
				canvas.draw_line(center,Vector2(968,268),item.color,4)
				canvas.draw_arc(Vector2(968,268),14,0,TAU,16,item.color,3)
				canvas._text(Vector2(979,263),"−1",20,item.color)
		"warp_fairy":
			for y in range(2):
				for x in range(5):
					_tile(canvas,Vector2(876+x*50,245+y*43),item.color,38)
			var start := Vector2(876,245)
			var end := Vector2(1076,288)
			for portal in [start,end]:
				canvas.draw_arc(portal,17+sin(time*4)*2,0,TAU,20,item.color,2)
			canvas._draw_player_portrait(model.weapon,start if progress < 0.5 else end,42)

static func _tile(canvas: CanvasItem, center: Vector2, accent: Color, side: float = 46) -> void:
	var rect := Rect2(center-Vector2.ONE*side/2,Vector2.ONE*side)
	canvas.draw_rect(rect,Color("192828"))
	canvas.draw_rect(rect,Color(accent,0.5),false,1)

static func _enemy(canvas: CanvasItem, center: Vector2) -> void:
	canvas.draw_texture_rect_region(Units.ENEMY_ATLAS,Rect2(center-Vector2.ONE*21,Vector2.ONE*42),Rect2(56,0,28,28))
