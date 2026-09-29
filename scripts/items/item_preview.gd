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
		"axe_spirit":
			# The 2x2 axe sweeps right and drives the enemy into the wall.
			for i in range(6):
				_tile(canvas,Vector2(880+i*38,254),item.color,36)
				_tile(canvas,Vector2(880+i*38,292),item.color,36)
			var sweep := minf(progress/0.6,1.0)
			canvas.draw_texture_rect_region(Units.AXE_DASH,Rect2(Vector2(861+sweep*76,235),Vector2.ONE*76),Rect2(224,0,224,224))
			_enemy(canvas,Vector2(994+sweep*76,254))
			canvas.draw_line(Vector2(1091,234),Vector2(1091,312),item.color,4)
			if progress > 0.6:
				canvas._text(Vector2(1030,232),"−1 −1",17,item.color)
		"holy_spirit":
			# The holy box strikes a touching enemy; broken, two knights step out.
			var box := Vector2(930,270)
			for offset in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
				_tile(canvas,box+offset*26,item.color,50)
			if progress < 0.55:
				canvas.draw_texture_rect(Units.HOLY_SPIRIT,Rect2(box-Vector2(50,54),Vector2.ONE*100),false)
				_enemy(canvas,Vector2(1010,244))
				canvas._text(Vector2(996,212),"−1",18,item.color)
			else:
				canvas.draw_texture_rect_region(Units.HOLY_KNIGHT,Rect2(box+Vector2(-26,-26)-Vector2(24,28),Vector2.ONE*48),Rect2(256,0,128,128))
				canvas.draw_texture_rect_region(Units.HOLY_KNIGHT,Rect2(box+Vector2(26,26)-Vector2(24,28),Vector2.ONE*48),Rect2(256,0,128,128))
				canvas._text(Vector2(1000,262),"壊れると\n聖騎士×2",17,item.color)
		"wall_fairy":
			for i in range(5):
				_tile(canvas,Vector2(872+i*52,269),item.color)
			Icon.paint(canvas,Vector2(976,267),item.icon,0.7)
			_enemy(canvas,Vector2(1080-minf(progress/0.6,1.0)*52,265))
			canvas._text(Vector2(868,232),"5ターン通れない",19,item.color)
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
			# Up and down from where it is placed.
			for y in range(3):
				_tile(canvas,Vector2(976,221+y*48),item.color,34)
			Icon.paint(canvas,Vector2(976,269),item.icon,0.45)
			_enemy(canvas,Vector2(976,221))
			_enemy(canvas,Vector2(976,317))
			if progress > 0.4:
				canvas.draw_line(Vector2(976,201),Vector2(976,337),item.color,4)
		"flying_slash":
			for y in range(3):
				for x in range(5):
					_tile(canvas,Vector2(872+x*52,241+y*28),item.color,25)
			Icon.paint(canvas,Vector2(872,269),item.icon,0.4)
			_enemy(canvas,Vector2(1028,241))
			_enemy(canvas,Vector2(1080,297))
			var front := 900+progress*190
			canvas.draw_line(Vector2(front,226),Vector2(front,312),item.color,4)
		"shadow_stitch":
			# The shadow waits where no weapon reaches; one click and you trade places.
			for x in range(5):
				_tile(canvas,Vector2(876+x*50,268),item.color,40)
			var here := Vector2(876,268)
			var there := Vector2(1076,268)
			var swapped := progress >= 0.5
			Icon.paint(canvas,here if swapped else there,item.icon,0.6)
			canvas._draw_player_portrait(model.weapon,there if swapped else here,40)
			canvas._text(Vector2(930,236),"0 AP で入れ替わる",17,item.color)
		"lone_wolf":
			# Alone it closes in and bites for 2.
			for x in range(4):
				_tile(canvas,Vector2(884+x*58,270),item.color)
			Icon.paint(canvas,Vector2(884+minf(progress*2,1.0)*58,268),item.icon,0.75)
			_enemy(canvas,Vector2(1000,268))
			if progress > 0.5:
				canvas._text(Vector2(988,236),"−2",20,Color("ff8a7a"))
			canvas._text(Vector2(856,306),"ひとりなら2・群れると1",18,item.color)
		"abyss_spirit":
			# Tiles out of reach sink into the abyss; a shove drops the enemy in.
			for x in range(5):
				_tile(canvas,Vector2(876+x*50,268),item.color,40)
			canvas.draw_texture_rect(canvas.ABYSS_PIT,Rect2(Vector2(1056,248),Vector2(40,40)),false)
			canvas._draw_player_portrait(model.weapon,Vector2(976,268),40)
			if progress < 0.55:
				_enemy(canvas,Vector2(1026,268))
			canvas._text(Vector2(900,236),"届かない所が奈落",17,item.color)
		"gravity_fairy":
			# Left: pulled in inside the weapon's range. Right: blown away outside it.
			for x in range(5):
				_tile(canvas,Vector2(876+x*50,268),item.color,40)
			Icon.paint(canvas,Vector2(976,268),item.icon,0.55)
			var offset := minf(progress*2.0,1.0)*50.0
			_enemy(canvas,Vector2(876+offset,268) if progress < 0.5 else Vector2(926,268))
			canvas._text(Vector2(880,236),"範囲内→引き寄せ　範囲外→弾く",15,item.color)
		"freeze_fairy":
			# The 3x3 around it frosts over; the enemies inside stop moving.
			for y in range(3):
				for x in range(3):
					_tile(canvas,Vector2(924+x*52,221+y*48),item.color,34)
			Icon.paint(canvas,Vector2(976,269),item.icon,0.5)
			_enemy(canvas,Vector2(924,221))
			_enemy(canvas,Vector2(1028,317))
			if progress > 0.4:
				for at in [Vector2(924,221), Vector2(1028,317)]:
					canvas.draw_rect(Rect2(at-Vector2(18,18),Vector2(36,36)),Color(0.7,0.92,1.0,0.45))
				canvas._text(Vector2(880,352),"3ターン動けない",18,item.color)
		"blessing_fairy":
			# Standing in the blessed ground, a hit also lands above and below.
			for y in range(3):
				for x in range(3):
					_tile(canvas,Vector2(884+x*44,225+y*44),item.color,30)
			Icon.paint(canvas,Vector2(928,269),item.icon,0.45)
			for y in range(3):
				_tile(canvas,Vector2(1060,225+y*44),Color("ff805a"),30)
				_enemy(canvas,Vector2(1060,225+y*44))
			if progress > 0.4:
				canvas.draw_line(Vector2(1060,205),Vector2(1060,333),item.color,4)
			canvas._text(Vector2(872,352),"加護の中なら攻撃が上下にも",16,item.color)
		"meteor_fairy":
			# Random tiles in reach take a 3x3 meteor each.
			for y in range(3):
				for x in range(5):
					_tile(canvas,Vector2(872+x*52,221+y*48),item.color,34)
			var fall := clampf(progress/0.4,0.0,1.0)
			var target := Vector2(1028,269)
			if fall < 1.0:
				var rock := Vector2(880,150).lerp(target,fall)
				canvas.draw_line(rock,rock+Vector2(-50,-45),Color("c8261a"),12)
				canvas.draw_line(rock,rock+Vector2(-40,-36),Color("ff7a1a"),8)
				canvas.draw_line(rock,rock+Vector2(-24,-22),Color("fff0a0"),3)
				canvas.draw_circle(rock,10,Color("3b3431"))
			else:
				canvas.draw_rect(Rect2(target-Vector2(78,72),Vector2(156,144)),Color(1,0.48,0.1,0.4*(1.0-progress)))
				canvas._text(Vector2(1000,275),"99",26,Color("ffd35b"))
			canvas._text(Vector2(872,352),"隕石 %d個（3×3・99）" % model.meteor_count(),18,item.color)
		"glutton_fairy":
			# It runs at the nearest thing and swallows it — enemy or not.
			for x in range(4):
				_tile(canvas,Vector2(884+x*58,270),item.color)
			Icon.paint(canvas,Vector2(884+minf(progress*2,1.0)*58,268),item.icon,0.75)
			if progress < 0.55:
				_enemy(canvas,Vector2(1000,268))
			else:
				canvas._text(Vector2(978,236),"ごくん",18,item.color)
			canvas._text(Vector2(856,306),"あなたも食べられる",18,item.color)
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
