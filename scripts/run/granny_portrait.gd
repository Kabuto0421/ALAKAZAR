extends Control
## The magic-circle granny: a hooded old woman with a staff, a violet circle
## turning behind her. Drawn in code until she gets real art.

const VIOLET := Color("9b6bff")
var time := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	time += delta
	queue_redraw()

func _draw() -> void:
	var c := size / 2.0 + Vector2(0, 10)
	# The circle behind her.
	var r := minf(size.x, size.y) * 0.44
	draw_circle(c, r, Color(VIOLET, 0.08))
	draw_arc(c, r, 0, TAU, 64, Color(VIOLET, 0.8), 3, true)
	draw_arc(c, r * 0.86, 0, TAU, 64, Color("d9c9ff", 0.5), 2, true)
	for k in 6:
		var a := time * 0.4 + k * TAU / 6
		var b := a + TAU / 3
		draw_line(c + Vector2.from_angle(a) * r * 0.86, c + Vector2.from_angle(b) * r * 0.86, Color(VIOLET, 0.6), 2)
	for k in 24:
		var a := -time * 0.6 + k * TAU / 24
		draw_line(c + Vector2.from_angle(a) * r, c + Vector2.from_angle(a) * (r - 8), Color("d9c9ff", 0.7), 2)
	var bob := sin(time * 1.6) * 2.0
	var body := c + Vector2(0, 20 + bob)
	# Robe and hood.
	draw_colored_polygon(PackedVector2Array([body + Vector2(-70, 110), body + Vector2(70, 110), body + Vector2(34, -30), body + Vector2(-34, -30)]), Color("2b1f47"))
	draw_colored_polygon(PackedVector2Array([body + Vector2(-46, -20), body + Vector2(46, -20), body + Vector2(30, -92), body + Vector2(0, -112), body + Vector2(-30, -92)]), Color("3a2a60"))
	draw_colored_polygon(PackedVector2Array([body + Vector2(-60, 110), body + Vector2(-20, 110), body + Vector2(-26, 10)]), Color("231a3a"))
	# Face in the hood's shadow.
	var face := body + Vector2(0, -52)
	draw_circle(face, 26, Color("1a1228"))
	draw_circle(face + Vector2(0, 4), 20, Color("d9b596"))
	draw_line(face + Vector2(-12, -2), face + Vector2(-4, 0), Color("3a2418"), 2)
	draw_line(face + Vector2(4, 0), face + Vector2(12, -2), Color("3a2418"), 2)
	draw_circle(face + Vector2(-8, 1), 2, Color("b9a4ff"))
	draw_circle(face + Vector2(8, 1), 2, Color("b9a4ff"))
	draw_line(face + Vector2(0, 2), face + Vector2(2, 10), Color("a57f63"), 2)
	draw_arc(face + Vector2(0, 14), 6, 0.3, PI - 0.3, 8, Color("7a4b3a"), 2)
	# Wisps of white hair.
	draw_line(face + Vector2(-18, -8), face + Vector2(-22, 12), Color("e8e4f0"), 3)
	draw_line(face + Vector2(18, -8), face + Vector2(22, 12), Color("e8e4f0"), 3)
	# Staff with a glowing orb.
	var hand := body + Vector2(52, 20)
	draw_line(hand + Vector2(0, 90), hand + Vector2(4, -110), Color("7a5230"), 6)
	var orb := hand + Vector2(4, -120)
	draw_circle(orb, 16 + sin(time * 3.0) * 2.0, Color(VIOLET, 0.35))
	draw_circle(orb, 10, Color("d9c9ff"))
	draw_circle(hand, 9, Color("d9b596"))
