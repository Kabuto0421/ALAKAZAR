extends RefCounted

const Icon = preload("res://scripts/items/spirit_icon.gd")
const Units = preload("res://scripts/unit_view.gd")
const Sheet = preload("res://scripts/items/direction_sheet.gd")

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
		"acorn_fairy":
			for i in range(4):
				_tile(canvas,Vector2(884+i*58,270),item.color)
			Icon.paint(canvas,Vector2(884+minf(progress*2,1.0)*58,268),item.icon,0.8)
			_enemy(canvas,Vector2(1000,268))
			canvas._text(Vector2(867,230),"HP 1 / AP 1",21,item.color)
			canvas._text(Vector2(856,306),"味方 → 敵の順に行動",18,item.color)
		"wall_fairy":
			for i in range(5):
				_tile(canvas,Vector2(872+i*52,269),item.color)
			Icon.paint(canvas,Vector2(976,267),item.icon,0.7)
			_enemy(canvas,Vector2(1080-minf(progress/0.6,1.0)*52,265))
			canvas._text(Vector2(868,232),"3ターン通れない",19,item.color)
		"vane_cannon":
			# Four shots in a row: after each one the aim turns 90 degrees clockwise.
			var center := Vector2(976,276)
			var shot := mini(int(progress*4),3)
			var dirs := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
			var aim: Vector2i = dirs[shot]
			for d in dirs:
				for k in range(1,3):
					_tile(canvas,center+Vector2(d)*k*20,item.color,18)
			_tile(canvas,center,item.color,18)
			var tail := fmod(progress*4.0,1.0)
			if tail < 0.55:
				canvas.draw_line(center+Vector2(aim)*10,center+Vector2(aim)*(10+tail/0.55*34),item.color,4)
			if not Sheet.paint(canvas,center,"vane_cannon",aim,0.34):
				Icon.paint(canvas,center,item.icon,0.34)
			# Clockwise hint from this aim to the next one.
			var from := Vector2(aim).angle()+0.35
			canvas.draw_arc(center,27,from,from+PI/2-0.7,12,Color("9ff5ff"),3)
			var tip := center+Vector2.from_angle(from+PI/2-0.7)*27
			var along := Vector2.from_angle(from+PI/2-0.7+PI/2)
			canvas.draw_colored_polygon(PackedVector2Array([tip+along*7,tip-along*3+along.orthogonal()*5,tip-along*3-along.orthogonal()*5]),Color("9ff5ff"))
			canvas._text(Vector2(1030,250),"%d発目" % (shot+1),16,Color("9ff5ff"))
			canvas._text(Vector2(1030,272),"時計回り",15,item.color)
			canvas._text(Vector2(1030,292),"に90度",15,item.color)
		"cannon_fairy":
			for i in range(5):
				_tile(canvas,Vector2(872+i*52,269),item.color)
			Icon.paint(canvas,Vector2(872,267),item.icon,0.65)
			_enemy(canvas,Vector2(1028,265))
			_enemy(canvas,Vector2(1080,265))
			if progress > 0.4:
				canvas.draw_line(Vector2(890,285),Vector2(1090,285),item.color,3)
			canvas._text(Vector2(856,232),"このマスを攻撃 → 発射",18,item.color)
		"firework_fairy":
			var center := Vector2(976,262)
			for y in range(-1,2):
				for x in range(-1,2):
					_tile(canvas,center+Vector2(x,y)*30,item.color,27)
			Icon.paint(canvas,center,item.icon,0.55)
			_enemy(canvas,center+Vector2(30,-30))
			_enemy(canvas,center+Vector2(-30,30))
			if progress > 0.5:
				canvas.draw_arc(center,20+(progress-0.5)*60,0,TAU,24,item.color,3)
		"capacitor_fairy":
			var center := Vector2(976,282)
			for offset in [Vector2.ZERO,Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2.UP*2,Vector2.DOWN*2,Vector2.LEFT*2,Vector2.RIGHT*2]:
				_tile(canvas,center+offset*Vector2(30,24),item.color,22)
			Icon.paint(canvas,center,item.icon,0.4)
			_enemy(canvas,center+Vector2(60,0))
			_enemy(canvas,center+Vector2(-60,0))
			var stored := mini(int(progress*4),3)
			for k in range(3):
				canvas.draw_rect(Rect2(center+Vector2(22+k*14,-22),Vector2(10,7)),Color("ffdc4a") if k < stored else Color("1a2426"))
			if stored == 3:
				for dir in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
					canvas.draw_line(center+dir*12,center+dir*Vector2(66,50),item.color,3)
		"slash_fairy":
			for x in range(3):
				_tile(canvas,Vector2(924+x*52,269),item.color,34)
			Icon.paint(canvas,Vector2(976,269),item.icon,0.45)
			_enemy(canvas,Vector2(924,269))
			_enemy(canvas,Vector2(1028,269))
			if progress > 0.4:
				canvas.draw_line(Vector2(904,269),Vector2(1048,269),item.color,4)
		"flying_slash":
			for y in range(3):
				for x in range(5):
					_tile(canvas,Vector2(872+x*52,241+y*28),item.color,25)
			Icon.paint(canvas,Vector2(872,269),item.icon,0.4)
			_enemy(canvas,Vector2(1028,241))
			_enemy(canvas,Vector2(1080,297))
			var front := 900+progress*190
			canvas.draw_line(Vector2(front,226),Vector2(front,312),item.color,4)
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
